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
    
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream")
    public typealias GraphObserver = Observer<GraphStore>
    public typealias GraphStreamer = StateStreamer<GraphStore>
    
    public let queue = DispatchQueue(label: "Store queue", qos: .userInteractive)
    public var graph: GraphStore { GraphStore(state, dispatch: dispatch) }
    
    //MARK: - Private properties
    private(set) var observers = Set<GraphObserver>()
    private(set) var streamers = Set<GraphStreamer>()
    private(set) var state: State
    private let lock = NSRecursiveLock()
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
    public subscript<T>(dynamicMember keyPath: KeyPath<GraphStore, T>) -> T {
        graph[keyPath: keyPath]
    }
    
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream")
    public func subscribe(_ observer: GraphObserver) {
        queue.sync {
            observers.insert(observer)
            notify(observer)
        }
    }
    
    public func subscribe(_ streamer: GraphStreamer) {
        queue.sync {
            streamer.activate()
            streamers.insert(streamer)
            yield(streamer)
        }
    }
    
    @available(*, deprecated, message: "Observer is deprecated for future versions. Use StateStream")
    public func subscribe(@SubscribersBuilder _ builder: () -> [GraphObserver]) {
        let observers = builder()
        queue.sync {
            self.observers.formUnion(observers)
            observers.forEach(notify)
        }
    }
    
    public func subscribe(@StreamerBuilder _ builder: () -> [GraphStreamer]) {
        let streamers = builder()
        streamers.forEach { $0.activate() }
        queue.sync {
            self.streamers.formUnion(streamers)
            streamers.forEach(yield)
        }
    }
    
    public func unsubscribe(_ streamer: GraphStreamer) {
        queue.sync {
            streamer.invalidate()
            self.streamers.remove(streamer)
        }
    }
    
    public func contains(_ streamer: GraphStreamer) -> Bool {
        lock.withLock { streamers.contains(streamer) }
    }
    
    //MARK: - Internal methods
    @Sendable
    func dispatch(_ action: Action) {
        queue.sync {
            reducer(&state, action)
            observers.forEach(notify)
            streamers.forEach(yield)
        }
    }
    
}

//MARK: - Private methods
private extension Store {
    func notify(_ observer: GraphObserver) {
        observer.queue.async { [graph] in
            let status = observer.observe?(graph)
            
            guard case .dead = status else { return }
            _ = self.queue.sync {
                self.observers.remove(observer)
            }
        }
    }
    
    func yield(_ streamer: GraphStreamer) {
        if streamer.isActive {
            streamer.continuation.yield(graph)
            return
        }
        streamers.remove(streamer)
    }
    
}
