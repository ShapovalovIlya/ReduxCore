//
//  Store.swift
//  MovieMagazine
//
//  Created by Илья Шаповалов on 28.10.2023.
//

import Foundation

public final class Store<State, Action> {
    //MARK: - Public properties
    public typealias StoreGraph = Graph<State, Action>
    public typealias GraphObserver = Observer<StoreGraph>
    public typealias Reducer = (inout State, Action) -> Void
    
    public let queue: DispatchQueue = .init(label: "Store queue")
    public var graph: StoreGraph { .init(state: state, dispatch: dispatch) }
    
    //MARK: - Private properties
    private var observers: Set<GraphObserver> = .init()
    private(set) var state: State
    private let reducer: Reducer
    
    //MARK: - init(_:)
    public init(
        initial state: State,
        reducer: @escaping Reducer
    ) {
        self.state = state
        self.reducer = reducer
    }
    
    //MARK: - Public methods
    public func dispatch(_ action: Action) {
        queue.sync {
            reducer(&state, action)
            observers.forEach(notify)
        }
    }
    
    public func subscribe(_ observer: GraphObserver) {
        queue.sync {
            observers.insert(observer)
            notify(observer)
        }
    }
    
}

private extension Store {
    func notify(_ observer: GraphObserver) {
        observer.queue.async { [graph] in
            let status = observer.observe?(graph)
            
            guard case .dead = status else { return }
            self.queue.async {
                self.observers.remove(observer)
            }
        }
    }
}
