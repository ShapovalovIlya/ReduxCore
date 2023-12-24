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
    public typealias Reducer = (inout State, Action) -> Void
    
    public let queue: DispatchQueue = .init(label: "Store queue")
    public var graph: GraphStore { .init(state: state, dispatch: dispatch) }
    
    @usableFromInline private(set) var observers: Set<GraphObserver> = .init()
    @usableFromInline private(set) var state: State
    @usableFromInline let reducer: Reducer
    
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
    
    @inlinable
    public func subscribe(_ observer: GraphObserver) {
        queue.sync {
            observers.insert(observer)
            notify(observer)
        }
    }
    
    @inlinable
    public func subscribe(@SubscribersBuilder _ builder: () -> [GraphObserver]) {
        let observers = builder()
        queue.sync {
            self.observers.formUnion(observers)
            observers.forEach(notify)
        }
    }
    
    //MARK: - Internal methods
    @inlinable
    @inline(__always)
    func dispatch(_ action: Action) {
        queue.sync {
            reducer(&state, action)
            observers.forEach(notify)
        }
    }
    
    @inlinable
    @inline(__always)
    func notify(_ observer: GraphObserver) {
        observer.queue.async { [graph] in
            let status = observer.observe?(graph)
            
            guard case .dead = status else { return }
            _ = self.queue.sync {
                self.observers.remove(observer)
            }
        }
    }
}
