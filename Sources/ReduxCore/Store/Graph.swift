//
//  Graph.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import Foundation

public struct Graph<State, Action>: @unchecked Sendable {
    @usableFromInline let dispatcher: Dispatcher
    public let state: State

    //MARK: - init(_:)
    @Sendable
    init(_ state: State, dispatcher: @escaping Dispatcher) {
        self.state = state
        self.dispatcher = dispatcher
    }
    
    //MARK: - Public methods
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
    typealias Dispatcher = @Sendable (consuming Effect) -> Void
    
    //MARK: - Effect
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

extension Graph.Effect: Sendable where Action: Sendable {}
extension Graph.Effect: Equatable where Action: Equatable {}
extension Graph.Effect: Hashable where Action: Hashable {}
