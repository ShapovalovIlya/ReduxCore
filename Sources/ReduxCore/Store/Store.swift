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
/// The `Store` class is a generic, thread-safe container that holds application state and provides mechanisms
/// for observing state changes, dispatching actions, and managing subscriptions. It is designed to be the
/// central point of state management in an application, following principles similar to Redux or The Composable Architecture.
///
/// `Store` supports both strong and weak subscription models:
/// - **Drivers** (``GraphStreamer``): Strongly held subscribers that receive state updates until explicitly uninstalled.
/// - **Streamers** (``ObjectStreamer``): Weakly held subscribers that receive state updates as long as they are retained elsewhere.
///
/// State updates are performed synchronously on a dedicated dispatch queue to ensure thread safety. Actions are
/// dispatched to the store, which applies them to the current state using a reducer function. After each state
/// update, all subscribers are notified with the new state.
///
/// The current state is also published via the `@Published` property, making it easy to observe from `SwiftUI` and updates `View` or Combine-based UIs.
///
/// ### Usage:
/// ```swift
/// let store = Store<MyState, MyAction>(initial: MyState(), reducer: myReducer)
/// store.dispatch(.increment)
/// ```
///
/// - Important: Deprecated observer APIs are retained for backward compatibility but will be removed in future versions. Use `StateStreamer` or `ObjectStreamer` for new code.
///
/// - Parameters:
///   - State: The type representing the state managed by the store.
///   - Action: The type representing actions that can be dispatched to the store.
///
/// ### Key Features:
/// - Thread-safe state access and mutation
/// - Observable state via `@Published` for SwiftUI/Combine integration
/// - Synchronous and asynchronous state streaming
/// - Strong and weak subscription models
/// - Action dispatching with reducer
/// - Dynamic member lookup for convenient state access
///
@dynamicMemberLookup
public final class Store<State, Action>: ObservableObject, @unchecked Sendable {
    //MARK: - Aliases
    
    /// A type alias representing the graph abstraction of the store's current state and dispatcher.
    ///
    /// `GraphStore` is a convenience alias for `Graph<State, Action>`, encapsulating both the current state
    /// and a dispatcher for sending actions. This abstraction allows you to pass around a value type that
    /// provides read-only access to the state and the ability to dispatch actions, without exposing the full store.
    ///
    /// - Note: Use `GraphStore` when you want to provide child components or views with access to the current state
    ///   and dispatching capabilities in a type-safe and encapsulated manner.
    ///
    /// ### Example:
    /// ```swift
    /// let graph: Store<MyState, MyAction>.GraphStore = store.graph
    /// print(graph.state) // Access the current state
    /// graph.dispatch(.increment) // Dispatch an action
    /// ```
    ///
    public typealias GraphStore = Graph<State, Action>
    
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
    /// `GraphStreamer` is a convenience alias for `StateStreamer<GraphStore>`, allowing you to create
    /// asynchronous streams of `GraphStore` values. This is typically used to drive state updates to
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
    public typealias GraphStreamer = StateStreamer<GraphStore>
    
    /// `ObjectStreamer` adopter that can receive async stream of `Graph<State, Action>`
    public typealias Streamer = ObjectStreamer<GraphStore>
    public typealias StreamerContinuation = AsyncStream<GraphStore>.Continuation
    
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
    
    @Published private(set) var state: State
    
    /// A computed property that provides a ``GraphStore`` (graph) representation of the current state and dispatcher.
    ///
    /// The `graph` property exposes the current state of the store wrapped in a ``Graph`` structure, which also
    /// includes a dispatcher for sending actions. This allows consumers to interact with the state and dispatch
    /// actions in a type-safe and encapsulated manner.
    ///
    /// The ``Graph`` abstraction is useful for passing state and dispatching capabilities to child components or views without exposing the entire ``Store``.
    ///
    /// - Returns: A ``GraphStore`` instance containing the current state and a dispatcher for actions.
    ///
    /// ### Example:
    /// ```swift
    /// let graph = store.graph
    /// print(graph.state) // Access the current state
    /// graph.dispatch(.increment) // Dispatch an action
    /// ```
    ///
    /// - Note: Each access to `graph` returns a new `GraphStore` instance reflecting the latest state.
    ///
    public var graph: GraphStore { GraphStore(state, dispatcher: dispatcher) }
    
    //MARK: - Private properties
    private var drivers = Set<GraphStreamer>()
    private var continuations: [ObjectIdentifier: StreamerContinuation] = .init()
    
    
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
    public subscript<T>(dynamicMember keyPath: KeyPath<GraphStore, T>) -> T {
        graph[keyPath: keyPath]
    }
    
    //MARK: - Deprecations
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    public typealias GraphObserver = Observer<GraphStore>
    
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
    func dispatcher(_ effect: consuming GraphStore.Effect) {
        queue.sync {
            state = effect.reduce(state, using: reducer)
            drivers.forEach(yield)
            continuations.forEach(yield)
            
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
            yield((streamer.streamerID, streamer.continuation))
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
    func install(_ driver: GraphStreamer) {
        queue.sync {
            drivers.insert(driver)
            yield(driver)
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
        queue.sync { [drivers = builder()] in
            self.drivers.formUnion(drivers)
            drivers.forEach(yield)
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
    @discardableResult
    func uninstall(_ driver: GraphStreamer) -> GraphStreamer? {
        queue.sync { drivers.remove(driver) }
    }
    
    /// Check if driver is subscribed to `Store`.
    func contains(driver: GraphStreamer) -> Bool {
        queue.sync { drivers.contains(driver) }
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
        dispatcher(.single(action))
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
        dispatcher(.multiple(Array(s)))
    }
}

//MARK: - Private methods
private extension Store {
    func yield(_ element: [ObjectIdentifier : StreamerContinuation].Element) {
        switch element.value.yield(graph) {
        case .terminated:
            continuations.removeValue(forKey: element.key)
            
        case .dropped, .enqueued:
            break
            
        @unknown default:
            assertionFailure()
        }
    }
    
    func yield(_ streamer: GraphStreamer) {
        switch streamer.continuation.yield(graph) {
        case .terminated:
            drivers.remove(streamer)
            
        case .dropped, .enqueued:
            break
            
        @unknown default:
            assertionFailure()
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
        queue.sync { [streamers = builder()] in
            self.drivers.formUnion(streamers)
            streamers.forEach(yield)
        }
    }
}
