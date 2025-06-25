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
/// - **Drivers** (`GraphStreamer`): Strongly held subscribers that receive state updates until explicitly uninstalled.
/// - **Streamers** (`ObjectStreamer`): Weakly held subscribers that receive state updates as long as they are retained elsewhere.
///
/// State updates are performed synchronously on a dedicated dispatch queue to ensure thread safety. Actions are
/// dispatched to the store, which applies them to the current state using a reducer function. After each state
/// update, all subscribers are notified with the new state.
///
/// ### Usage
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
/// - Synchronous and asynchronous state streaming
/// - Strong and weak subscription models
/// - Action dispatching with reducer
/// - Dynamic member lookup for convenient state access
///
@dynamicMemberLookup
public final class Store<State, Action>: ObservableObject, @unchecked Sendable {
    //MARK: - Public properties
    public typealias GraphStore = Graph<State, Action>
    public typealias Reducer = (inout State, Action) -> Void
    
    /// StateStreamer object that produce sequence of GraphStore models
    public typealias GraphStreamer = StateStreamer<GraphStore>
    
    /// `ObjectStreamer` adopter that can receive async stream of `Graph<State, Action>`
    public typealias Streamer = ObjectStreamer<GraphStore>
    public typealias StreamerContinuation = AsyncStream<GraphStore>.Continuation
    
    public let queue = DispatchQueue(label: "Store queue", qos: .userInteractive)
    
    @Published private(set) var state: State
    
    public var graph: GraphStore { GraphStore(state, dispatcher: dispatcher) }
    
    //MARK: - Private properties
    private var drivers = Set<GraphStreamer>()
    private var continuations: [ObjectIdentifier: StreamerContinuation] = .init()
    
    let reducer: Reducer
    
    //MARK: - init(_:)
    public init(
        initial state: State,
        reducer: @escaping Reducer
    ) {
        self.state = state
        self.reducer = reducer
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
            state = autoreleasepool { effect.reduce(state, using: reducer) }
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
    
    /// Create subscription between ``Store/Streamer`` and ``Store``.
    ///
    /// - Important: `Store` doesn't hold strong reference to ``Store/Streamer``.
    ///              If you need this behaviour, use ``Store/install(_:)`` method.
    ///
    /// - Parameter streamer: ``Store/Streamer`` instance to subscribe
    func subscribe(_ streamer: some Streamer) {
        queue.sync {
            continuations.updateValue(streamer.continuation, forKey: streamer.streamerID)
            yield((streamer.streamerID, streamer.continuation))
        }
    }
    
    /// Remove subscription between ``Store/Streamer`` and ``Store``.
    @discardableResult
    func unsubscribe(_ streamer: some Streamer) -> Bool {
        queue.sync {
            continuations.removeValue(forKey: streamer.streamerID) != nil
        }
    }
        
    /// Check if streamer is subscribed to `Store`.
    func contains(streamer: some Streamer) -> Bool {
        queue.sync {
            continuations[streamer.streamerID] != nil
        }
    }
    
    //MARK: - Driver methods
    
    /// Subscribe driver (``Store/GraphStreamer`` object) to state updates.
    ///
    /// - Important: `Store` hold strong reference to ``Store/GraphStreamer``.
    ///              Use ``Store/uninstall(_:)`` method to remove it.
    ///
    /// - Parameter streamer: `GraphStreamer` instance to subscribe
    func install(_ driver: GraphStreamer) {
        queue.sync {
            drivers.insert(driver)
            yield(driver)
        }
    }
    
    /// Subscribe drivers (`GraphStreamer` object) to state updates.
    ///
    /// - Important: `Store` hold strong reference to ``Store/GraphStreamer``.
    /// Use ``Store/uninstall(_:)`` method to remove it.
    ///
    /// - Parameter builder: callback with `ResultBuilder` to collect drivers.
    func installAll(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        queue.sync { [drivers = builder()] in
            self.drivers.formUnion(drivers)
            drivers.forEach(yield)
        }
    }
    
    /// Remove ``Store/GraphStreamer`` from `Store`'s subscription.
    ///
    /// After uninstalling, `Store` no longer hold strong reference to ``Store/GraphStreamer``
    ///
    /// - Parameter driver: ``Store/GraphStreamer`` instance to remove.
    @discardableResult
    func uninstall(_ driver: GraphStreamer) -> GraphStreamer? {
        queue.sync { drivers.remove(driver) }
    }
    
    /// Check if driver is subscribed to `Store`.
    func contains(driver: GraphStreamer) -> Bool {
        queue.sync { drivers.contains(driver) }
    }
    
    /// Dispatch single action
    @inlinable
    func dispatch(_ action: Action) {
        dispatcher(.single(action))
    }
    
    /// Dispatch sequence of actions
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
