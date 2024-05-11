//
//  Store.swift
//
//
//  Created by Илья Шаповалов on 28.10.2023.
//

import Foundation

@dynamicMemberLookup
public final class Store<State, Action> {
    //MARK: - Public properties
    public typealias GraphStore = Graph<State, Action>
    public typealias GraphObserver = Observer<GraphStore>
    public typealias GraphStreamer = StateStreamer<GraphStore>
    public typealias Reducer = (inout State, Action) -> Void
    
    public let queue: DispatchQueue = .init(label: "Store queue")
    public var graph: GraphStore { .init(state: state, dispatch: dispatch) }
    
    private(set) var observers: Set<GraphObserver> = .init()
    private(set) var streamers: Set<GraphStreamer> = .init()
    private(set) var state: State
    let reducer: Reducer
    
    private let lock = NSRecursiveLock()
    
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
        lock.withLock { graph[keyPath: keyPath] }
    }
    
    public func subscribe(_ observer: GraphObserver) {
        queue.sync {
            observers.insert(observer)
            notify(observer)
        }
    }
    
    public func subscribe(_ streamer: GraphStreamer) {
        queue.sync {
            streamers.insert(streamer)
            yield(streamer)
        }
    }
    
    public func subscribe(@SubscribersBuilder _ builder: () -> [GraphObserver]) {
        let observers = builder()
        queue.sync {
            self.observers.formUnion(observers)
            observers.forEach(notify)
        }
    }
    
    //MARK: - Internal methods
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
//        streamer.continuation.finish()
        streamers.remove(streamer)
    }
    
}
