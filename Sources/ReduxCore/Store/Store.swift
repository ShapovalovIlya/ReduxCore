//
//  Store.swift
//
//
//  Created by Илья Шаповалов on 28.10.2023.
//

import Foundation
import ReduxStream
import StoreThread

@dynamicMemberLookup
public final class Store<State, Action>: @unchecked Sendable {
    //MARK: - Public properties
    public typealias GraphStore = Graph<State, Action>
    public typealias Reducer = (inout State, Action) -> Void
    public typealias GraphStreamer = StateStreamer<GraphStore>
    
    /// `ObjectStreamer` adopter that can receive async stream of `Graph<State, Action>`
    public typealias Streamer = ObjectStreamer<GraphStore>
    public typealias StreamerContinuation = AsyncStream<GraphStore>.Continuation
    
    public let queue = DispatchQueue(label: "Store queue", qos: .userInteractive)
    
    private(set) var state: State
    public var graph: GraphStore { GraphStore(state, dispatcher: dispatcher) }
    
    //MARK: - Private properties
    private var drivers = Set<GraphStreamer>()
    private var continuations: [ObjectIdentifier: StreamerContinuation] = .init()
    private let lock = NSLock()
    let reducer: Reducer
    
    //MARK: - init(_:)
    public init(initial state: State, reducer: @escaping Reducer) {
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

    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    public func subscribe(_ observer: GraphObserver) {
        queue.sync {
            observers.insert(observer)
            notify(observer)
        }
    }
    
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream or ObjectStreamer")
    public func subscribe(@SubscribersBuilder _ builder: () -> [GraphObserver]) {
        let observers = builder()
        queue.sync {
            self.observers.formUnion(observers)
            observers.forEach(notify)
        }
    }
    
    
    @available(*, deprecated, renamed: "installAll")
    public func subscribe(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        let streamers = builder()
        streamers.forEach { $0.activate() }
        queue.sync {
            self.drivers.formUnion(streamers)
            streamers.forEach(yield)
        }
    }
    
    //MARK: - Streamer methods
    
    /// Create subscription between `Streamer` and `Store`.
    ///
    /// `Store` hold `Streamer`'s continuation to yield new state, and setup `.onTermination` handler to unsubscribe.
    ///
    /// - Important: `Store` doesn't hold strong reference to `Streamer`.
    ///              If you need this behaviour, use `install(_:)` method.
    ///
    /// - Parameter streamer: `Streamer` instance to subscribe
    public func subscribe(_ streamer: some Streamer) {
        streamer.continuation.onTermination = { [weak self] _ in
            self?.unsubscribe(streamer)
        }
        queue.sync {
            continuations[streamer.streamerID] = streamer.continuation
            streamer.continuation.yield(graph)
        }
    }
    
    /// Remove subscription between `Streamer` and `Store`.
    /// - Returns: return true if streamer was successfully removed, false if streamer was not subscribed.
    @discardableResult
    public func unsubscribe(_ streamer: some Streamer) -> Bool {
        lock.withLock {
            continuations.removeValue(forKey: streamer.streamerID) != nil
        }
    }
        
    /// Check if streamer is subscribed to `Store`.
    public func contains(streamer: some Streamer) -> Bool {
        lock.withLock { continuations[streamer.streamerID] != nil }
    }
    
    //MARK: - Driver methods
    
    /// Subscribe driver (`GraphStreamer` object) to state updates.
    ///
    /// `Store`  setup `driver.continuation.onTermination` handler to unsubscribe.
    ///
    /// - Important: `Store` hold strong reference to `GraphStreamer`. Use `uninstall(_:)` method to remove it.
    ///
    /// - Parameter streamer: `GraphStreamer` instance to subscribe
    public func install(_ driver: GraphStreamer) {
        driver.continuation.onTermination = { [weak self] _ in
            self?.uninstall(driver)
        }
        queue.sync {
            driver.activate()
            drivers.insert(driver)
            yield(driver)
        }
    }
    
    /// Subscribe drivers (`GraphStreamer` object) to state updates.
    ///
    /// `Store`  setup `driver.continuation.onTermination` handler to unsubscribe.
    ///
    /// - Important: `Store` hold strong reference to `GraphStreamer`. Use `uninstall(_:)` method to remove it.
    ///
    /// - Parameter builder: callback with `ResultBuilder` to collect drivers.
    public func installAll(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        let drivers = builder()
        drivers.forEach { d in
            d.continuation.onTermination = { [weak self] _ in
                self?.uninstall(d)
            }
        }
        drivers.forEach { $0.activate() }
        queue.sync {
            self.drivers.formUnion(drivers)
            drivers.forEach(yield)
        }
    }
    
    /// Remove `GraphStreamer` from `Store`'s subscription.
    ///
    /// After uninstalling, `Store` no longer hold strong reference to `GraphStreamer`
    ///
    /// - Parameter driver: `GraphStreamer` instance to remove.
    public func uninstall(_ driver: GraphStreamer) {
        lock.withLock {
            driver.invalidate()
            self.drivers.remove(driver)
        }
    }
    
    /// Check if driver is subscribed to `Store`.
    public func contains(driver: GraphStreamer) -> Bool {
        lock.withLock { drivers.contains(driver) }
    }
    
    /// Dispatch single action
    @inlinable
    public func dispatch(_ action: Action) {
        dispatcher(.single(action))
    }
    
    /// Dispatch sequence of actions
    @inlinable
    public func dispatch(contentsOf s: some Sequence<Action>) {
        dispatcher(.multiple(Array(s)))
    }
    
    //MARK: - Internal methods
    @Sendable
    @usableFromInline
    func dispatcher(_ effect: consuming GraphStore.Effect) {
        queue.sync {
            state = effect.reduce(state, using: reducer)
            drivers.forEach(yield)
            continuations.forEach { _, continuation in
                continuation.yield(graph)
            }
            // deprecated support
            observers.forEach(notify)
        }
    }
}

//MARK: - Private methods
private extension Store {
    
    func yield(_ streamer: GraphStreamer) {
        if streamer.isActive {
            streamer.continuation.yield(graph)
            return
        }
        drivers.remove(streamer)
    }
}
