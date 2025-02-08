//
//  Graph.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import Foundation

public struct Graph<State, Action>: @unchecked Sendable {
    public let state: State
    public let dispatcher: Dispatcher
    
    @Sendable
    init(_ state: State, dispatcher: @escaping Dispatcher) {
        self.state = state
        self.dispatcher = dispatcher
    }
    
    @inlinable
    @Sendable
    public func dispatch(_ action: Action) {
        dispatcher(.single(action))
    }
    
    @inlinable
    @Sendable
    public func dispatch(_ actions: Action...) {
        dispatcher(.multiple(actions))
    }
    
    @inlinable
    @Sendable
    public func dispatch(contentsOf actions: [Action]) {
        dispatcher(.multiple(actions))
    }
}

public extension Graph {
    typealias Dispatcher = @Sendable (Effect) -> Void
    
    enum Effect {
        case single(Action)
        case multiple([Action])
        
        @inlinable
        public func reduce(
            _ state: State,
            using reducer: (inout State, Action) -> Void
        ) -> State {
            switch self {
            case .single(let action):
                var state = state
                reducer(&state, action)
                return state
                
            case .multiple(let array):
                return array.reduce(into: state, reducer)
            }
        }
    }
}
