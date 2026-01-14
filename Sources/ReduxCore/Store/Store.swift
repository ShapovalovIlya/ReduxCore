//
//  Store.swift
//
//
//  Created by Илья Шаповалов on 28.10.2023.
//

import Foundation
import ReduxStream
import StoreThread

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
public final class Store<State, Action>: ObservableObject, @unchecked Sendable {
    //MARK: - Aliases
    
    /// A type alias representing the graph abstraction of the store's current state and dispatcher.
    ///
    /// `StoreGraph` is a convenience alias for `Graph<State, Action>`, encapsulating both the current state
    /// and a dispatcher for sending actions. This abstraction allows you to pass around a value type that
    /// provides read-only access to the state and the ability to dispatch actions, without exposing the full store.
    ///
    /// - Note: Use `StoreGraph` when you want to provide child components or views with access to the current state
    ///   and dispatching capabilities in a type-safe and encapsulated manner.
    ///
    /// ### Example:
    /// ```swift
    /// let graph: Store<MyState, MyAction>.GraphStore = store.graph
    /// print(graph.state) // Access the current state
    /// graph.dispatch(.increment) // Dispatch an action
    /// ```
    ///
    public typealias StoreGraph = Graph<State, Action>
    
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
    public typealias Reducer = (inout State, Action) -> Void
    
    /// A type alias for a state streamer that emits `GraphStore` (graph) state updates.
    ///
    /// `GraphStreamer` is a convenience alias for `StateStreamer<StoreGraph>`, allowing you to create
    /// asynchronous streams of ``StoreGraph`` values. This is typically used to drive state updates to
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
    public typealias GraphStreamer = StateStreamer<StoreGraph>
    
    /// `ObjectStreamer` adopter that can receive async stream of `Graph<State, Action>`
    public typealias Streamer = ObjectStreamer<StoreGraph>
    public typealias StreamerContinuation = AsyncStream<StoreGraph>.Continuation
    
    //MARK: - Public properties
    /// The internal dispatch queue used for synchronizing state updates and store operations.
    ///
    /// All state mutations, action dispatches, and subscription management are performed synchronously on this queue
    /// to ensure thread safety. The queue's quality of service (QoS) can be configured during store initialization,
    /// allowing you to control the priority of store-related tasks.
    ///
    /// - Important: Directly submitting work to this queue from outside the store is discouraged.
    ///   Use the store's public API for all interactions to maintain thread safety and data integrity.
    ///
    /// ### Example:
    /// ```swift
    /// print(store.queue.label) // Prints the label of the store's internal queue
    /// ```
    ///
    public let queue: DispatchQueue
    
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
    
    @usableFromInline
    private(set) var state: State
    
    /// A computed property that provides a ‎``StoreGraph``—an abstraction encapsulating the current state and a dispatcher for actions.
    ///
    /// The ‎`graph` property returns a new ‎``StoreGraph`` instance each time it is accessed, reflecting the store’s latest state and offering a type-safe way to dispatch actions.
    ///
    /// Importantly, accessing or passing the ‎`graph` does not create a strong reference cycle or extend the lifetime of the store.
    /// As a result, you can safely pass ‎`graph` to child components or views without risk of memory leaks or unintended retention of the store instance.
    /// Use ‎`graph` to expose just the state and dispatch capability to child components or views, without exposing the full store or its internal mechanisms.
    /// This is especially useful for unidirectional data flow architectures, where you want to allow updates via actions but keep state mutations centralized.
    ///
    /// - Returns: A ‎``StoreGraph`` containing the current state and a dispatcher closure.
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
    public var graph: StoreGraph {
        Graph(state) { [weak self] actions in
            self?.dispatcher(actions)
        }
    }
    
    //MARK: - Private properties
    @usableFromInline
    private(set) var continuations = [AnyHashable: StreamerContinuation]()
    
    
    //MARK: - init(_:)
    
    /// Initializes a new ``Store`` instance with the provided initial state, quality of service, and reducer.
    ///
    /// This initializer sets up the store with an initial state, a reducer function to handle actions,
    /// and a dedicated dispatch queue for thread-safe state updates. The queue's quality of service (QoS)
    /// can be customized to control the priority of state processing tasks.
    ///
    /// - Parameters:
    ///   - state: The initial state to be managed by the store.
    ///   - qos: The quality of service for the store's internal dispatch queue. Defaults to `.userInteractive`.
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
        initial state: State,
        qos: DispatchQoS = .userInteractive,
        reducer: @escaping Reducer
    ) {
        self.state = state
        self.reducer = reducer
        self.queue = DispatchQueue(
            label: "com.reduxCore.StoreQueue",
            qos: qos,
            autoreleaseFrequency: .workItem,
            target: .global(qos: qos.qosClass)
        )
    }
    
    //MARK: - Public methods
    @inlinable
    public subscript<T>(dynamicMember keyPath: KeyPath<StoreGraph, T>) -> T {
        graph[keyPath: keyPath]
    }
    
    //MARK: - Deprecations
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    public typealias GraphObserver = Observer<StoreGraph>
    
    @available(*, deprecated)
    private(set) var observers = Set<GraphObserver>()
    
    //MARK: - Internal methods
    @available(*, deprecated)
    func notify(_ observer: GraphObserver) {
        observer.queue.async { [graph] in
            let status = observer.observe?(graph)
            
            guard case .dead = status else { return }
            _ = self.queue.sync {
                self.observers.remove(observer)
            }
        }
    }
    
    @Sendable
    @usableFromInline
    func dispatcher(_ actions: some Collection<Action>) {
        if actions.isEmpty { return }
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        queue.sync {
            state = actions.reduce(into: state, reducer)
            let graph = graph
            continuations.forEach(yield(graph))
            
            // deprecated support
            observers.forEach(notify)
        }
    }
}

//MARK: - Public Methods
public extension Store {
    
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
        queue.sync {
            continuations.updateValue(streamer.continuation, forKey: streamer.streamerID)
            yield(graph)((streamer.streamerID, streamer.continuation))
        }
    }
    
    @inlinable
    func stateStream(
        for listener: AnyObject,
        buffering policy: AsyncStream<StoreGraph>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<StoreGraph> {
        let (stream, continuation) = AsyncStream.makeStream(of: StoreGraph.self, bufferingPolicy: policy)
        let id = ObjectIdentifier(listener)
        return queue.sync {
            continuations[id] = continuation
            continuation.yield(graph)
            return stream
        }
    }
    
    @inlinable
    func finishStream(for listener: AnyObject) {
        let id = ObjectIdentifier(listener)
        queue.sync {
            continuations.removeValue(forKey: id)?.finish()
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
    @inlinable
    @discardableResult
    func unsubscribe(_ streamer: some Streamer) -> Bool {
        queue.sync {
            continuations.removeValue(forKey: streamer.streamerID) != nil
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
    @inlinable
    func contains(streamer: some Streamer) -> Bool {
        queue.sync {
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
    /// let driver = StateStreamer<Graph<MyState, MyAction>>()
    /// store.install(driver)
    /// ```
    ///
    @inlinable
    func install(_ driver: GraphStreamer) {
        queue.sync {
            continuations[driver] = driver.continuation
            continuations[driver]?.yield(graph)
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
    ///     StateStreamer<Graph<MyState, MyAction>>()
    ///     StateStreamer<Graph<MyState, MyAction>>()
    /// }
    /// ```
    ///
    /// - Important: The store retains all installed drivers. To remove a driver, call ``uninstall(_:)`` with the specific driver instance.
    ///
    func installAll(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        let drivers = Dictionary(builder().map { ($0, $0.continuation) }) { $1 }
        queue.sync {
            self.continuations.merge(drivers) { $1 }
            drivers.forEach(yield(graph))
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
    @inlinable
    @discardableResult
    func uninstall(_ driver: GraphStreamer) -> GraphStreamer? {
        queue.sync {
            guard continuations.removeValue(forKey: driver) != nil else {
                return nil
            }
            return driver
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
    @inlinable
    func contains(driver: GraphStreamer) -> Bool {
        queue.sync { continuations[driver] != nil }
    }
    
    /// Dispatches a single action to the store for processing.
    ///
    /// This method sends the provided action to the store's reducer, which updates the state accordingly.
    /// After the state is updated, all subscribers are notified of the new state.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter action: The action to be processed by the store's reducer.
    ///
    /// ### Example:
    /// ```swift
    /// store.dispatch(.increment)
    /// ```
    ///
    @inlinable
    func dispatch(_ action: Action) {
        dispatcher(CollectionOfOne(action))
    }
    
    /// Dispatches a sequence of actions to the store for processing in order.
    ///
    /// This method sends all actions in the provided sequence to the store's reducer, applying them one after another.
    /// After all actions are processed and the state is updated, all subscribers are notified of the new state.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter s: A sequence of actions to be processed by the store's reducer, in order.
    ///
    /// ### Example
    /// ```swift
    /// store.dispatch(contentsOf: [.increment, .decrement, .reset])
    /// ```
    ///
    @inlinable
    func dispatch(contentsOf s: some Sequence<Action>) {
        dispatcher(Array(s))
    }
}

//MARK: - Private methods
private extension Store {
    func yield(_ graph: StoreGraph) -> ([AnyHashable : StreamerContinuation].Element) -> Void {
        { element in
            switch element.value.yield(graph) {
            case .terminated:
                self.continuations.removeValue(forKey: element.key)
                
            case .dropped, .enqueued:
                break
                
            @unknown default:
                assertionFailure()
            }
        }
    }
}

//MARK: - Deprecated interfaces
public extension Store {
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    func subscribe(_ observer: GraphObserver) {
        queue.sync {
            observers.insert(observer)
            notify(observer)
        }
    }
    
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    func subscribe(@SubscribersBuilder _ builder: () -> [GraphObserver]) {
        let observers = builder()
        queue.sync {
            self.observers.formUnion(observers)
            observers.forEach(notify)
        }
    }
    
    
    @available(*, deprecated, renamed: "installAll")
    func subscribe(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        installAll(builder)
    }
}
