//
//  Store.swift
//
//
//  Created by Илья Шаповалов on 28.10.2023.
//

import Foundation
import ReduxStream
import StoreThread
import ReduxSync

/// A thread-safe, observable state container for managing application state and dispatching actions.
///
/// The `Store` class is a generic, thread-safe container that serves as the central point for state management in your application.
/// Inspired by architectures like Redux and The Composable Architecture, `Store` enables predictable, unidirectional data flow through a combination of state, actions, and reducers.
///
/// ## Core Features
/// - **Thread Safety:** All state mutations and actions are processed synchronously on a dedicated dispatch queue, ensuring safe access and mutation from any thread.
/// - **Observability:** State is published via `@Published`, making it easy to observe from SwiftUI views or Combine pipelines.
/// - **Flexible Subscriptions:** Supports both strong (drivers) and weak (streamers) subscription models for state observation.
/// - **Action Dispatching:** Actions are dispatched to the store and applied to the current state using a reducer function.
/// - **Encapsulation:** The `StoreGraph` abstraction allows you to expose only state and dispatch capability to child components, without leaking the full store.
///
/// ## Usage Example
/// ```swift
/// // Creating a Store
///
/// enum CounterAction { case increment, decrement }
///
/// struct CounterState {
///     var count: Int = 0
/// }
///
/// let reducer: Store<CounterState, CounterAction>.Reducer = { state, action in
///     switch action {
///     case .increment:
///         state.count += 1
///     case .decrement:
///         state.count -= 1
///     }
/// }
///
/// let store = Store<CounterState, CounterAction>(initial: CounterState(), reducer: reducer)
///
/// // Dispatching single Action
/// store.dispatch(.increment)
/// store.dispatch(.decrement)
///
///  // Dispatching sequence of Actions
/// store.dispatch(contentsOf: [.increment, .increment, .decrement]) // as array or set
/// store.dispatch(.increment, .increment, .decrement) // as variadic parameter
///
/// // Subscribing with a Streamer (Weak Subscription)
/// let streamer = StateStreamer<Store.StoreGraph>()
/// Task {
///     for await graph in streamer {
///         print("Streamer received count:", graph.count)
///     }
/// }
/// store.subscribe(streamer)
/// // As long as `streamer` is retained, it will receive state updates.
///
/// store.unsubscribe(streamer)
/// // or you manualy unsubscribe streamer
///
/// // Installing a Driver (Strong Subscription)
/// let driver = Store<CounterState, CounterAction>.GraphStreamer()
/// Task {
///     for await graph in driver.state {
///         print("Driver received count:", graph.count)
///     }
/// }
/// store.install(driver)
/// // The store retains `driver` until you explicitly uninstall it.
///
/// store.uninstall(driver)
///
/// ```
///
/// ## Subscription Models
/// - **Drivers (`GraphStreamer`):** Strongly-held subscribers that receive state updates until explicitly uninstalled.
/// - **Streamers (`ObjectStreamer`):** Weakly-held subscribers that receive state updates as long as they are referenced elsewhere.
///
/// ## Design Notes
/// - Reducers should be pure functions that mutate only the provided state and avoid side effects.
/// - The `graph` property provides a safe, weakly-referenced abstraction for passing state and dispatching to child components or views.
/// - Deprecated observer APIs are retained for backward compatibility but will be removed in future versions; use `StateStreamer` or `ObjectStreamer` for new code.
///
/// ## Type Parameters
/// - `State`: The type representing the state managed by the store.
/// - `Action`: The type representing actions that can be dispatched to the store.
///
/// ## Best Practices
/// - Use the store’s public API for all interactions to maintain thread safety and data integrity.
/// - Prefer drivers for long-lived, strongly-held subscriptions.
/// - Use streamers for ephemeral or weakly-held observers.
///
/// The `Store` class provides a robust foundation for scalable, predictable state management in any Swift application.
@dynamicMemberLookup
public final class Store<S, A: Action>: ReduxStore, @unchecked Sendable {

    //MARK: - Aliases
    public typealias Snapshot = StoreSnapshot<Store>
    public typealias Hook<T> = AsyncStream<(state: S, action: T)>

    /// A type alias for the reducer function that handles actions and mutates the store's state.
    ///
    /// The `Reducer` defines the signature for a pure function that takes the current state (as an inout parameter)
    /// and an action, and mutates the state in response to the action. Reducers are the core mechanism for
    /// updating state in a predictable and centralized manner within the store.
    ///
    /// - Parameters:
    ///   - state: The current state of the store, passed as an inout parameter to allow mutation.
    ///   - action: The action to be handled, which may result in a state change.
    ///
    /// - Note: Reducers should be pure functions and must not produce side effects.
    ///         All state mutations should occur exclusively within the reducer to maintain consistency.
    ///
    /// ### Example:
    /// ```swift
    /// let reducer: Store<AppState, AppAction>.Reducer = { state, action in
    ///     switch action {
    ///     case .increment:
    ///         state.count += 1
    ///     case .decrement:
    ///         state.count -= 1
    ///     }
    /// }
    /// ```
    ///
    public typealias Reducer = (inout S, A) -> Void
    
    /// A type alias for a state streamer that emits `GraphStore` (graph) state updates.
    ///
    /// `GraphStreamer` is a convenience alias for `StateStreamer<StoreGraph>`, allowing you to create
    /// asynchronous streams of ``Store/Snapshot`` values. This is typically used to drive state updates to
    /// strongly-held subscribers (drivers) within the store architecture.
    ///
    /// - Note: Use `GraphStreamer` when you want to observe or react to changes in the store's state and dispatcher
    ///   as a single, encapsulated value (`GraphStore`). The store retains strong references to installed `GraphStreamer`
    ///   instances until they are explicitly uninstalled.
    ///
    /// ### Example
    /// ```swift
    /// let driver: Store<MyState, MyAction>.GraphStreamer = .init()
    /// store.install(driver)
    /// Task {
    ///     for await graph in driver.state {
    ///         print("Received new graph state: \(graph.state)")
    ///     }
    /// }
    /// ```
    ///
    public typealias GraphStreamer = StateStreamer<Snapshot>
    
    /// `ObjectStreamer` adopter that can receive async stream of `Snapshot`s
    public typealias Streamer = ObjectStreamer<Snapshot>
    public typealias SnapshotContinuation = AsyncStream<Snapshot>.Continuation
    
    //MARK: - Public properties
    /// The internal scheduler used for synchronizing state updates and store operations.
    ///
    /// All state mutations, action dispatches, and subscription management  on this scheduler
    /// to ensure thread safety.
    ///
    /// - Important: Directly submitting work to this scheduler from outside the store is discouraged.
    ///   Use the store's public API for all interactions to maintain thread safety and data integrity.
    ///
    public let scheduler: any ReduxScheduler
    
    /// The `Reducer` function used to handle actions and mutate the store's state.
    ///
    /// The `reducer` is a pure function that takes the current state and an action as input,
    /// and mutates the state in response to the action. It is invoked internally whenever an action
    /// is dispatched to the store, ensuring that all state changes are predictable and centralized.
    ///
    /// - Note: The reducer should be a pure function and must not produce side effects.
    ///         All state mutations should occur exclusively within the reducer to maintain consistency.
    ///
    /// ### Example:
    /// ```swift
    /// let store = Store(
    ///     initial: AppState(),
    ///     reducer: { state, action in
    ///         switch action {
    ///         case .increment:
    ///             state.count += 1
    ///         case .decrement:
    ///             state.count -= 1
    ///         }
    ///     }
    /// )
    /// ```
    ///
    public let reducer: Reducer
    public var state: S { _state.withLock(\.self) }

    private var _state: OSUnfairLock<S>

    /// A computed property that provides a ‎``Snapshot``—an abstraction encapsulating the current state and a dispatcher for actions.
    ///
    /// The ‎`graph` property returns a new ‎``Snapshot`` instance each time it is accessed, reflecting the store’s latest state and offering a type-safe way to dispatch actions.
    ///
    /// Importantly, accessing or passing the ‎`graph` does not create a strong reference cycle or extend the lifetime of the store.
    /// As a result, you can safely pass ‎`graph` to child components or views without risk of memory leaks or unintended retention of the store instance.
    /// Use ‎`graph` to expose just the state and dispatch capability to child components or views, without exposing the full store or its internal mechanisms.
    /// This is especially useful for unidirectional data flow architectures, where you want to allow updates via actions but keep state mutations centralized.
    ///
    /// - Returns: A ‎``Snapshot`` containing the current state and a dispatcher closure.
    ///
    /// ### Example:
    ///```swift
    /// let graph = store.graph
    /// print(graph.state) // Access the current state
    /// graph.dispatch(.increment) // Dispatch an action
    /// ```
    ///
    /// - Note: Each access to ‎`graph` yields a fresh ‎`StoreGraph` instance with the most recent state.
    ///
    @inlinable
    @available(*, deprecated, renamed: "snapshot", message: "Use `snapshot` property")
    public var graph: Snapshot { snapshot }
    
    /// A computed property that provides a ‎``Snapshot``—an abstraction encapsulating the current state and a dispatcher for actions.
    ///
    /// The ‎`snapshot` property returns a new ‎``Snapshot`` instance each time it is accessed, reflecting the store’s latest state and offering a type-safe way to dispatch actions.
    ///
    /// Importantly, accessing or passing the ‎`snapshot` does not create a strong reference cycle or extend the lifetime of the store.
    /// As a result, you can safely pass ‎`snapshot` to child components or views without risk of memory leaks or unintended retention of the store instance.
    /// Use ‎`snapshot` to expose just the state and dispatch capability to child components or views, without exposing the full store or its internal mechanisms.
    /// This is especially useful for unidirectional data flow architectures, where you want to allow updates via actions but keep state mutations centralized.
    ///
    /// - Returns: A ‎``Snapshot`` containing the current state and a dispatcher closure.
    ///
    /// ### Example:
    ///```swift
    /// let snapshot = store.snapshot
    /// print(snapshot.state) // Access the current state
    /// snapshot.dispatch(.increment) // Dispatch an action
    /// ```
    ///
    /// - Note: Each access to ‎`snapshot` yields a fresh ‎`Snapshot` instance with the most recent state.
    ///
    @inlinable
    public var snapshot: Snapshot {
        Snapshot(store: self)
    }
    
    //MARK: - Private properties
    @usableFromInline
    private(set) var continuations = [AnyHashable: SnapshotContinuation]()
    
    @usableFromInline
    private(set) var subscribers = [AnyHashable: AsyncStream<Store>.Continuation]()

    @usableFromInline
    private(set) var hooks = [UUID: (S, A) -> Void]()

    //MARK: - init(_:)
    
    /// Initializes a new ``Store`` instance with the provided initial state, quality of service, and reducer.
    ///
    /// This initializer sets up the store with an initial state, a reducer function to handle actions,
    /// and a dedicated dispatch queue for thread-safe state updates. The queue's quality of service (QoS)
    /// can be customized to control the priority of state processing tasks.
    ///
    /// - Parameters:
    ///   - state: The initial state to be managed by the store.
    ///   - scheduler: The internal scheduler used for synchronizing state updates and store operations.
    ///   - reducer: A closure that takes the current state and an action, and mutates the state in response to the action.
    ///
    /// ### Example:
    /// ```swift
    /// let store = Store(
    ///     initial: AppState(),
    ///     qos: .userInitiated
    /// ) { state, action in
    ///     // Handle action and mutate state
    /// }
    /// ```
    ///
    public init(
        initial state: S,
        scheduler: some ReduxScheduler = AsyncSerialScheduler(),
        reducer: @escaping Reducer
    ) {
        self._state = OSUnfairLock(initial: state)
        self.reducer = reducer
        self.scheduler = scheduler
    }
    
    //MARK: - Public methods
    @inlinable
    public subscript<T>(dynamicMember keyPath: KeyPath<Snapshot, T>) -> T {
        snapshot[keyPath: keyPath]
    }
    
    //MARK: - Deprecations
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    public typealias GraphObserver = Observer<Snapshot>
    
    @available(*, deprecated)
    private(set) var observers = Set<GraphObserver>()
    
    //MARK: - Internal methods
    @available(*, deprecated)
    func notify(_ observer: GraphObserver) {
        observer.queue.async { [graph] in
            let status = observer.observe?(graph)
            
            guard case .dead = status else { return }
            _ = self.scheduler.schedule {
                self.observers.remove(observer)
            }
        }
    }
    
    @Sendable
    @usableFromInline
    func dispatcher(_ actions: some Collection<A>) {
        if actions.isEmpty { return }

        let pending = Array(actions)
        scheduler.schedule { [self] in
            let current = _state.withLock(\.self)

            let updated = pending.reduce(into: current) { updated, action in
                reducer(&updated, action)

                hooks.forEach { _, hook in
                    hook(updated, action)
                }
            }
            _state.withLock { $0 = updated }

            continuations.forEach(yield(snapshot))
            subscribers.forEach(yield)

            // deprecated support
            observers.forEach(notify)

            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
}

//MARK: - Public Methods
public extension Store {

    /// Creates an `AsyncStream` that emits state-action pairs for actions of
    /// the specified type ``Action``.
    ///
    /// Unlike ``updates(_:)`` which emits snapshots after the full action batch
    /// is processed, `addHook` fires **inside** the reduce loop — after each
    /// individual action is reduced. This allows you to observe intermediate
    /// state even when actions are dispatched as a batch via
    /// ``dispatch(contentsOf:)``.
    ///
    /// The stream only yields values when the dispatched action matches the
    /// specified type `T`. Non-matching actions are silently ignored.
    ///
    /// - Parameters:
    ///   - buffering: The buffering policy for the stream.
    ///     Defaults to `.unbounded`.
    ///   - type: The action type to observe. Only actions of this type trigger
    ///     a yield.
    /// - Returns: An `AsyncStream` of `(state: S, action: T)` tuples.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let store = Store<AppState, AppAction>(...)
    ///
    /// Task {
    ///     for await (state, action) in store.addHook(on: LoginAction.self) {
    ///         print("Login action \(action) updated state to \(state)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Performance Considerations
    /// - The hook closure runs inside the reduce loop for every dispatched
    ///   action, including each action in a batch.
    /// - A runtime type check (`action as? T`) is performed per hook per
    ///   action. This is O(1) but should be considered when registering many
    ///   hooks.
    /// - When no hooks are registered, the reduce loop has zero overhead from
    ///   hooks.
    ///
    /// ## Thread Safety
    /// - The hook closure and state values are delivered on the store's
    ///   scheduler queue, which is serial by default.
    /// - Registration and cleanup are also scheduled on the same serial queue.
    ///
    /// ## Lifecycle
    /// - The hook is automatically removed from the store when the stream
    ///   iteration ends or the stream's continuation is explicitly finished.
    /// - Abandoning the stream without finishing it will keep the hook
    ///   registered until the store is deallocated.
    ///
    /// - Important: Unlike ``updates(_:)``, this method does **not** yield an
    ///   initial value. It only emits when a matching action is dispatched.
    func addHook<T: ReduxCore.Action>(
        _ buffering: Hook<T>.Continuation.BufferingPolicy = .unbounded,
        on type: T.Type
    ) -> Hook<T> {
        addHook(buffering) { $0 as? T }
    }

    /// Creates an `AsyncStream` that emits state-action pairs for actions
    /// extracted by a custom lens closure.
    ///
    /// Unlike ``addHook(_:on:)`` which filters by action type at runtime, this
    /// overload gives you full control over the extraction logic. The `lens`
    /// closure receives every dispatched action and returns an optional
    /// extracted value. When the closure returns non-`nil`, the stream yields
    /// `(state, extractedValue)`.
    ///
    /// This is useful for:
    /// - Extracting associated values from enum actions
    /// - Observing multiple related action types via a single lens
    /// - Transforming or enriching actions before they reach the consumer
    ///
    /// - Parameters:
    ///   - buffering: The buffering policy for the stream.
    ///     Defaults to `.unbounded`.
    ///   - lens: A closure that extracts an optional value of type `T` from
    ///     an action. Return `nil` to skip the action, or a value to yield it
    ///     on the stream.
    /// - Returns: An `AsyncStream` of `(state: S, action: T)` tuples, where
    ///   `T` is the extracted value type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum AppAction {
    ///     case login(username: String)
    ///     case logout
    ///     case increment(Int)
    /// }
    ///
    /// let store = Store<AppState, AppAction>(...)
    ///
    /// // Extract associated value from an enum action
    /// Task {
    ///     for await (state, username) in store.addHook(lens: { action in
    ///         guard case .login(let name) = action else { return nil }
    ///         return name
    ///     }) {
    ///         print("User \(username) logged in, state: \(state)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Performance Considerations
    /// - The `lens` closure runs inside the reduce loop for every dispatched
    ///   action. Keep it lightweight — avoid I/O or heavy computation.
    /// - When no hooks are registered, the reduce loop has zero overhead from
    ///   hooks.
    ///
    /// ## Thread Safety
    /// - The `lens` closure and yielded values are delivered on the store's
    ///   serial scheduler queue. The closure must be `@Sendable`.
    /// - Registration and cleanup are also scheduled on the same serial queue.
    ///
    /// ## Lifecycle
    /// - The hook is automatically removed from the store when the stream
    ///   iteration ends or the stream's continuation is explicitly finished.
    /// - The store reference is `weak` inside the hook, so the store can be
    ///   deallocated even if the stream is abandoned.
    ///
    /// - SeeAlso: ``addHook(_:on:)`` for simple type-based filtering.
    func addHook<T>(
        _ buffering: Hook<T>.Continuation.BufferingPolicy = .unbounded,
        lens: @escaping @Sendable (A) -> T?
    ) -> Hook<T> {
        AsyncStream(bufferingPolicy: buffering) { continuation in
            let id = UUID()
            scheduler.schedule { [weak self] in
                self?.hooks[id] = { state, action in
                    guard let result = lens(action) else { return }
                    continuation.yield((state, result))
                }
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.scheduler.schedule {
                    self.hooks[id] = nil
                }
            }
        }
    }

    /// Creates an `AsyncStream` that emits state updates from the store.
    ///
    /// - Parameter buffering: The buffering policy for the stream.
    ///   Defaults to `.unbounded`.
    /// - Returns: An `AsyncStream` that emits state updates.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let store = Store<CounterState, CounterAction>(...)
    ///
    /// Task {
    ///     for await snapshot in store.updates() {
    ///         print("Count updated: \(snapshot.state.count)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Performance Considerations
    /// - `.unbounded` buffering can lead to high memory usage with frequent updates
    /// - Consider `.bufferingNewest(1)` for UI updates
    /// - Use `.bufferingOldest(n)` when you need to process updates in exact order
    ///
    /// ## Thread Safety
    /// - This method is thread-safe and can be called from any thread
    ///
    /// - Important: The stream yields an initial snapshot immediately when
    ///   created, so your observation loop will always start with the current
    ///   state.
    ///
    /// - Warning: Using `.unbounded` buffering with high-frequency updates
    ///   can lead to memory pressure. Consider using `.bufferingNewest(n)`
    ///   for such scenarios.
    ///
    @inlinable
    func updates(_ buffering: AsyncStream<Snapshot>.Continuation.BufferingPolicy = .unbounded) -> AsyncStream<Snapshot> {
        AsyncStream(bufferingPolicy: buffering) { continuation in
            let task = onChange
                .map(\.snapshot)
                .task(
                    onNext: { continuation.yield($0) },
                    onCancel: { _ in continuation.finish() }
                )
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Provides an `AsyncStream` that emits the store instance whenever its state changes.
    ///
    /// `onChange` returns a stream that yields the entire store instance (not just its state)
    /// each time an action is dispatched and the reducer processes it. This provides a
    /// convenient way to observe store changes while maintaining access to the full store API.
    ///
    /// ## Overview
    /// Unlike ``updates()`` which yields ``Snapshot`` objects containing only state and dispatch,
    /// `onChange` yields the complete `Store` instance. This allows observers to:
    /// - Access the current state via ``Store/state``
    /// - Dispatch new actions directly
    /// - Use dynamic member lookup on the store
    /// - Access other store properties and methods
    ///
    /// ## Buffering Behavior
    /// The stream uses `.bufferingNewest(1)` buffering policy, which means:
    /// - Only the most recent store instance is buffered
    /// - If the observer cannot keep up with updates, intermediate states may be dropped
    /// - This is optimal for UI updates where only the latest state matters
    ///
    /// - Important: The stream yields immediately when created,
    ///   so your observation loop will always start with the current store.
    ///
    /// - Warning: Because this yields the entire store, be cautious about
    ///   creating reference cycles. The store does not strongly retain observers,
    ///   but observers should use `[weak store]` if they capture the store.
    ///
    var onChange: AsyncStream<Store> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            scheduler.schedule { [self] in
                subscribers.updateValue(continuation, forKey: UUID())
                continuation.yield(self)
            }
        }
    }
    
    //MARK: - Streamer methods
    
    /// Subscribes a ``Streamer`` to receive state updates from the ``Store``.
    ///
    /// This method establishes a subscription between the provided ``Streamer`` and the ``Store``. The streamer will
    /// receive an asynchronous stream of state updates as the store's state changes.
    ///
    /// The store does **not** hold a strong reference to the streamer.
    /// if you require a strong reference, use the ``install(_:)`` method instead.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Important: The store does not retain the streamer. If the streamer is deallocated, it will automatically be unsubscribed.
    /// - Parameter streamer: The `Streamer` instance to subscribe for state updates.
    ///
    /// ### Example:
    /// ```swift
    /// let streamer = MyObjectStreamer()
    /// store.subscribe(streamer)
    /// ```
    ///
    func subscribe(_ streamer: some Streamer) {
        scheduler.schedule { [self] in
            continuations.updateValue(streamer.continuation, forKey: streamer.streamerID)
            yield(snapshot)((streamer.streamerID, streamer.continuation))
        }
    }
    
    /// Unsubscribes a ``Streamer`` from receiving state updates from the ``Store``.
    ///
    /// This method removes the subscription between the provided ``Streamer`` and the store. After calling this method,
    /// the streamer will no longer receive state updates. If the streamer was not previously subscribed, this method does nothing.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter streamer: The `Streamer` instance to unsubscribe from state updates.
    /// - Returns: `true` if the streamer was successfully unsubscribed; `false` if the streamer was not found among active subscriptions.
    ///
    /// ### Example:
    /// ```swift
    /// let streamer = MyObjectStreamer()
    /// store.unsubscribe(streamer)
    /// ```
    ///
    func unsubscribe(_ streamer: some Streamer) {
        scheduler.schedule { [self] in
            continuations.removeValue(forKey: streamer.streamerID)
        }
    }
        
    /// Checks whether a given ``Streamer`` is currently subscribed to the store.
    ///
    /// This method returns `true` if the provided streamer is actively subscribed and will receive state updates,
    /// or `false` if the streamer is not currently subscribed.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter streamer: The `Streamer` instance to check for an active subscription.
    /// - Returns: `true` if the streamer is subscribed to the store; otherwise, `false`.
    ///
    /// ### Example:
    /// ```swift
    /// if store.contains(streamer: myStreamer) {
    ///     print("Streamer is subscribed.")
    /// }
    /// ```
    ///
    func contains(streamer: some Streamer) -> Bool {
        _state.withLock {
            continuations[streamer.streamerID] != nil
        }
    }
    
    //MARK: - Driver methods
    
    /// Subscribes a ``GraphStreamer`` (driver) to receive state updates from the ``Store``.
    ///
    /// This method establishes a strong subscription between the provided driver and the store. The driver will
    /// receive state updates whenever the store's state changes.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Important: The store retains the driver for the duration of the subscription.
    ///              To remove the driver and release the reference, call ``uninstall(_:)``.
    /// - Parameter driver: The ``GraphStreamer`` instance to subscribe for state updates.
    ///
    /// ### Example
    /// ```swift
    /// let driver = StateStreamer<Snapshot<MyState, MyAction>>()
    /// store.install(driver)
    /// ```
    ///
    func install(_ driver: GraphStreamer) {
        scheduler.schedule { [self] in
            continuations[driver] = driver.continuation
            continuations[driver]?.yield(snapshot)
        }
    }
    
    /// Subscribes multiple ``GraphStreamer`` drivers to receive state updates from the ``Store``.
    ///
    /// This method allows you to install several drivers at once using a result builder for number of ``GraphStreamer`` instances.
    /// All provided drivers will be strongly retained by the store and will receive state updates whenever the store's state changes.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter builder: A  result builder, that returns an array of ``GraphStreamer`` instances to be installed.
    ///
    /// ### Example:
    /// ```swift
    /// store.installAll {
    ///     StateStreamer<Snapshot<MyState, MyAction>>()
    ///     StateStreamer<Snapshot<MyState, MyAction>>()
    /// }
    /// ```
    ///
    /// - Important: The store retains all installed drivers. To remove a driver, call ``uninstall(_:)`` with the specific driver instance.
    ///
    func installAll(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        let drivers = Dictionary(builder().map { ($0, $0.continuation) }) { $1 }
        scheduler.schedule { [self] in
            self.continuations.merge(drivers) { $1 }
            drivers.forEach(yield(snapshot))
        }
    }
    
    /// Unsubscribes a ``GraphStreamer`` (driver) from receiving state updates from the ``Store``.
    ///
    /// This method removes the specified driver from the store's set of active drivers, ending its strong subscription.
    /// After calling this method, the driver will no longer receive state updates, and the store will release its strong reference to the driver.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter driver: The `GraphStreamer` instance to remove from the store's subscriptions.
    /// - Returns: The removed `GraphStreamer` instance if it was found and unsubscribed; otherwise, `nil`.
    ///
    /// ### Example:
    /// ```swift
    /// if let removed = store.uninstall(driver) {
    ///     print("Driver was successfully uninstalled.")
    /// }
    /// ```
    ///
    func uninstall(_ driver: GraphStreamer) {
        scheduler.schedule { [self] in
            continuations.removeValue(forKey: driver)
        }
    }
    
    /// Checks whether a given ``GraphStreamer`` (driver) is currently installed and subscribed to the ``Store``.
    ///
    /// This method returns `true` if the provided driver is actively installed and will receive state updates,
    /// or `false` if the driver is not currently subscribed.
    ///
    /// - Parameter driver: The `GraphStreamer` instance to check for an active subscription.
    /// - Returns: `true` if the driver is installed and subscribed to the store; otherwise, `false`.
    ///
    /// ### Example
    /// ```swift
    /// if store.contains(driver: myDriver) {
    ///     print("Driver is currently installed and receiving updates.")
    /// }
    /// ```
    ///
    func contains(driver: GraphStreamer) -> Bool {
        _state.withLock { continuations[driver] != nil }
    }
    
    /// Dispatches a single action to the store.
    ///
    /// This method enqueues an action for processing by the store's reducer.
    /// Actions are processed synchronously on the store's internal dispatch queue,
    /// ensuring thread-safe state updates.
    ///
    /// - Parameter action: The action to dispatch.
    ///
    /// ## Usage
    /// ```swift
    /// let store = Store<CounterState, CounterAction>(...)
    ///
    /// // Dispatch a single action
    /// store.dispatch(.increment)
    /// store.dispatch(.decrement)
    /// ```
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    /// The action will be processed synchronously on the store's internal queue.
    ///
    /// ### See Also
    /// - ``dispatch(contentsOf:)`` for dispatching multiple actions
    ///
    @inlinable
    @Sendable
    func dispatch(_ action: A) {
        dispatcher(CollectionOfOne(action))
    }
    
    /// Dispatches a collection of actions to the store.
    ///
    /// This method processes multiple actions in sequence. Actions are applied
    /// in the order they appear in the collection, allowing for atomic state
    /// updates across multiple actions.
    ///
    /// - Parameter actions: A collection of actions to dispatch.
    ///
    /// ## Usage
    /// ```swift
    /// let store = Store<CounterState, CounterAction>(...)
    ///
    /// // Dispatch multiple actions from an array
    /// store.dispatch(contentsOf: [.increment, .increment, .decrement])
    ///
    /// // Dispatch actions from a set
    /// store.dispatch(contentsOf: Set([.reset, .increment]))
    /// ```
    ///
    /// ## Performance
    /// When dispatching multiple actions, this method is more efficient than
    /// calling ``dispatch(_:)`` multiple times, as it only triggers observers
    /// once after all actions are processed.
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    ///
    /// ### See Also
    /// - ``dispatch(_:)`` for dispatching single actions
    ///
    @inlinable
    @Sendable
    func dispatch(contentsOf s: some Sequence<A>) {
        dispatcher(Array(s))
    }
}

//MARK: - Private methods
private extension Store {
    func yield(_ snapshot: Snapshot) -> ([AnyHashable : SnapshotContinuation].Element) -> Void {
        { element in
            switch element.value.yield(snapshot) {
            case .terminated:
                self.continuations.removeValue(forKey: element.key)
                
            case .dropped, .enqueued:
                break
                
            @unknown default:
                assertionFailure()
            }
        }
    }
    
    func yield(_ subscriber: [AnyHashable: AsyncStream<Store>.Continuation].Element) {
        switch subscriber.value.yield(self) {
        case .terminated:
            subscribers.removeValue(forKey: subscriber.key)
            
        case .dropped, .enqueued:
            break
            
        @unknown default:
            return
        }
    }
}

//MARK: - Deprecated interfaces
public extension Store {
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    func subscribe(_ observer: GraphObserver) {
        scheduler.schedule { [self] in
            observers.insert(observer)
            notify(observer)
        }
    }
    
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    func subscribe(@SubscribersBuilder _ builder: () -> [GraphObserver]) {
        let observers = builder()
        scheduler.schedule { [self] in
            self.observers.formUnion(observers)
            observers.forEach(notify)
        }
    }
    
    
    @available(*, deprecated, renamed: "installAll")
    func subscribe(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        installAll(builder)
    }
}
