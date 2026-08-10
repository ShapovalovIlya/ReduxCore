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

public struct ReduxEffect<S,A>: Sendable {
    public enum Policy: Sendable {
        /// конкурентно, без ожидания и без отмены
        case merge

        /// очередь: ждать предыдущий, потом стартовать
        case concat

        /// отменить предыдущий, стартовать новый
        case switchToLatest

        /// игнорировать новый, пока предыдущий не завершился/
        case dropWhileActive
    }

    public let id: UUID
    public let priority: TaskPriority?
    public let policy: Policy
    public let run: @Sendable (S, A, (A) -> Void) async -> Void

    public init(
        id: UUID = UUID(),
        priority: TaskPriority? = nil,
        policy: Policy = .merge,
        run: @escaping @Sendable (S, A, (A) -> Void) async -> Void
    ) {
        self.id = id
        self.priority = priority
        self.policy = policy
        self.run = run
    }
}

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
public final class Store<S: Sendable, A: Sendable>: ReduxStore, @unchecked Sendable {

    //MARK: - Aliases
    public typealias Snapshot = StoreSnapshot<Store>

    /// A permission gate is a predicate that determines whether an action is allowed
    /// to reach the reducer. All installed permission gates must return `true` for the
    /// action to proceed (AND logic).
    public typealias PermissionGate = @Sendable (S, A) -> Bool

    /// A middleware function that intercepts each dispatched action and returns a list
    /// of additional actions to process. All middleware results are flat-mapped into the
    /// action pipeline before reduction.
    public typealias Middleware = @Sendable (S, A) -> [A]

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

    private var permissions = OSUnfairLock<[UUID: PermissionGate]>(initial: [:])
    private var middleware = OSUnfairLock<[UUID: Middleware]>(initial: [:])
    private var effects = OSUnfairLock<[UUID: ReduxEffect<S,A>]>(initial: [:])
    private var running = OSUnfairLock<[UUID: Task<Void, Never>]>(initial: [:])

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

    func runPermissions(state: State, action: Action) -> Bool {
        if permissions.withLock(\.isEmpty) {
            return true
        }
        return permissions.withLock(\.values).lazy
            .map { $0(state,action) }
            .allSatisfy { $0 }
    }

    func runMiddleware(state: State, action: Action) -> [Action] {
        if middleware.withLock(\.isEmpty) {
            return [action]
        }
        return middleware.withLock(\.values).lazy
            .flatMap { $0(state,action) }
            .reduce(into: [action], +=)
    }

    /// Runs every registered effect for the given action and re-dispatches the
    /// results of action effects.
    ///
    /// Both effect registries are snapshotted under lock when the task group
    /// starts, so effects removed mid-run still execute for this dispatch. The
    /// group keeps running until every registered effect — including slow void
    /// effects — completes; meanwhile each action-effect result is re-dispatched
    /// individually, in completion order (nondeterministic across concurrent
    /// effects). Every such re-dispatch is a separate scheduler pass that
    /// produces its own subscriber notification.
    func runEffects(state: State, action: Action) {
        if effects.withLock(\.isEmpty) {
            return
        }
        let updated = effects.withLock(\.values)
            .reduce(into: running.withLock(\.self)) { tasks, effect in
                let scheduling = tasks[effect.id]
                tasks[effect.id] = Task(priority: effect.priority) { [weak self] in
                    switch effect.policy {
                    case .concat:
                        if scheduling?.isCancelled == true {
                            break
                        }
                        await scheduling?.value

                    case .switchToLatest:
                        scheduling?.cancel()

                    case .dropWhileActive:
                        // TO DO: доработать
                        break

                    case .merge:
                        break
                    }

                    await effect.run(state, action) { action in
                        self?.dispatch(action)
                    }
                }
            }
        running.withLock { $0 = updated }
    }

    @Sendable
    @usableFromInline
    func dispatcher(_ actions: some Collection<A>) {
        if actions.isEmpty { return }

        let pending = Array(actions)
        scheduler.schedule { [weak self] in
            guard let self else { return }

            let current = _state.withLock(\.self)
            let effects = effects.withLock(\.self)

            let updated = pending.lazy
                .filter { self.runPermissions(state: current, action: $0) }
                .flatMap { self.runMiddleware(state: current, action: $0) }
                .filter { self.runPermissions(state: current, action: $0) }
                .reduce(into: current) { updated, action in
                    self.reducer(&updated, action)
                    self.runEffects(state: updated, action: action)
                }

            _state.withLock { $0 = updated }

            continuations.forEach(yield(snapshot))
            subscribers.forEach(yield)

            // deprecated support
            observers.forEach(notify)

            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }
}

//MARK: - Public Methods
public extension Store {
    /// Adds a permission gate to the store's action dispatch pipeline.
    ///
    /// Permission gates act as filters: before any action reaches the reducer, all
    /// installed gates are evaluated in insertion order. Every gate must return `true`
    /// for the action to proceed; if any gate returns `false`, evaluation stops
    /// immediately (short-circuit) and the action is silently dropped.
    ///
    /// - Parameter permission: A closure that receives the current state and the
    ///   pending action, returning `true` to allow the action or `false` to block it.
    /// - Returns: A `UUID` that you can pass to ``removePermission(withId:)`` to
    ///   revoke this permission gate later.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let id = store.addPermission { state, action in
    ///     state.user.isLoggedIn
    /// }
    ///
    /// // Later, remove the gate
    /// store.removePermission(withId: id)
    /// ```
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    ///
    /// ### See Also
    /// - ``removePermission(withId:)``
    ///
    @discardableResult
    func addPermission(_ permission: @escaping PermissionGate) -> UUID {
        let id = UUID()
        self.permissions.withLock { $0[id] = permission }
        return id
    }

    /// Removes a previously installed permission gate by its identifier.
    ///
    /// - Parameter id: The `UUID` returned when the permission gate was added via
    ///   ``addPermission(_:)``.
    /// - Returns: The removed `PermissionGate` closure, or `nil` if no gate was
    ///   registered under the given identifier.
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    ///
    /// ### See Also
    /// - ``addPermission(_:)``
    ///
    @discardableResult
    func removePermission(withId id: UUID) -> PermissionGate? {
        self.permissions.withLock { $0.removeValue(forKey: id) }
    }

    /// Adds a middleware function to the store's action dispatch pipeline.
    ///
    /// Each middleware receives the current state and every dispatched action, and
    /// produces additional actions to process. All middleware results are appended
    /// to the action list, re-checked against permissions, and then reduced.
    /// Middleware output is never re-routed through other middleware. The original
    /// action always flows through the pipeline — middleware can add follow-up
    /// actions but cannot suppress the action being processed.
    ///
    /// The closure body is built with the `ActionBuilder` result builder, so it can
    /// produce a single action, an array of actions, or compose the result with
    /// `if` or `switch` statements. An explicit `return` statement is not allowed
    /// inside the builder. An empty body and Void-valued statements (e.g. logging)
    /// are allowed and contribute no actions; the original action still flows
    /// through the pipeline.
    ///
    /// - Note: Because the builder is generic over the action type, implicit member
    ///   expressions like `.navigate(to: .home)` cannot be inferred inside the
    ///   body. Use fully qualified cases (`AppAction.navigate(to: .home)`) or bind
    ///   the value first via `let` with an explicit type.
    ///
    /// - Parameter middleware: A closure that receives the current state and an
    ///   action, producing additional actions to enqueue.
    /// - Returns: A `UUID` that you can pass to ``removeMiddleware(withId:)`` to
    ///   remove this middleware later.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let id = store.addMiddleware { _, action in
    ///     if case .loginSuccess = action {
    ///         AppAction.navigate(to: .home)
    ///     }
    /// }
    ///
    /// store.addMiddleware { _, action in
    ///     switch action {
    ///     case .loginSuccess:
    ///         [AppAction.navigate(to: .home), AppAction.trackEvent("login")]
    ///     case .loginFailure:
    ///         AppAction.showAlert("login.failed")
    ///     default:
    ///         AppAction.trackEvent("login_failed")
    ///     }
    /// }
    ///
    /// // Later, remove a middleware
    /// store.removeMiddleware(withId: id)
    /// ```
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    ///
    /// ### See Also
    /// - ``removeMiddleware(withId:)``
    ///
    @discardableResult
    func addMiddleware(
        @ActionBuilder _ middleware: @escaping Middleware
    ) -> UUID {
        let id = UUID()
        self.middleware.withLock { $0[id] = middleware }
        return id
    }

    /// Removes a previously installed middleware function by its identifier.
    ///
    /// - Parameter id: The `UUID` returned when the middleware was added via
    ///   ``addMiddleware(_:)``.
    /// - Returns: The removed `Middleware` closure, or `nil` if no middleware was
    ///   registered under the given identifier.
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    ///
    /// ### See Also
    /// - ``addMiddleware(_:)``
    ///
    @discardableResult
    func removeMiddleware(withId id: UUID) -> Middleware? {
        middleware.withLock { $0.removeValue(forKey: id) }
    }

    @discardableResult
    func addEffect(_ effect: ReduxEffect<S,A>) -> UUID {
        effects.withLock { $0[effect.id] = effect }
        return effect.id
    }

    /// Adds an async effect to the store.
    ///
    /// Effects are triggered after each action is reduced and the state has been
    /// updated. All active effects run concurrently in a `TaskGroup`, so they do
    /// not block the reducer or each other.
    ///
    /// This overload registers a *void effect*: it performs side work (logging,
    /// analytics, I/O, cache writes) and produces no follow-up action. To
    /// re-dispatch an action with the result of an async operation, use the
    /// action-returning overload instead.
    ///
    /// - Parameter effect: An async closure that receives the updated state and the
    ///   action that caused the change.
    /// - Returns: A `UUID` that you can pass to ``removeEffect(withId:)`` to remove
    ///   this effect later.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let id = store.addEffect { state, action in
    ///     if case .fetchData = action {
    ///         await analytics.log(.dataFetched)
    ///     }
    /// }
    ///
    /// // Later, remove the effect
    /// store.removeEffect(withId: id)
    /// ```
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Important: Effects run concurrently and should not assume any ordering
    ///   between them.
    ///
    /// - Note: Errors thrown by the effect are ignored, so a void effect that
    ///   throws is indistinguishable from one that returns normally. To handle
    ///   failures observably, dispatch the failure as an action instead of
    ///   throwing.
    ///
    /// ### See Also
    /// - ``removeEffect(withId:)``
    ///
    @discardableResult
    func addEffect(
        _ effect: @escaping @Sendable (S, A, (A) -> Void) async -> Void
    ) -> UUID {
        addEffect(ReduxEffect(run: effect))
    }

    /// Removes a previously installed effect by its identifier.
    ///
    /// - Parameter id: The `UUID` returned when the effect was added via
    ///   ``addEffect(_:)``.
    /// - Returns: `true` if a registered effect with the given identifier
    ///   existed and was removed; `false` otherwise.
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Important: Removal unregisters the effect for future dispatches only.
    ///   It does not cancel an effect that is already running — each dispatch
    ///   snapshots the registered effects when it starts, so an in-flight effect
    ///   keeps running to completion after it has been removed.
    ///
    /// ### See Also
    /// - ``addEffect(_:)``
    ///
    @discardableResult
    func removeEffect(withId id: UUID) -> ReduxEffect<S,A>? {
        running.withLock { $0.removeValue(forKey: id) }?.cancel()
        return effects.withLock { $0.removeValue(forKey: id) }
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
    func dispatch(contentsOf sequence: some Sequence<A>) {
        dispatcher(Array(sequence))
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
