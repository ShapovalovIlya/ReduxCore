//
//  Graph.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import Foundation

public struct Graph<State, Action>: Sendable {
    public typealias Dispatcher = @Sendable (consuming Effect) -> Void
    
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
    public func dispatch(contentsOf s: some Sequence<Action>) {
        dispatcher(.multiple(Array(s)))
    }
}

public extension Graph {
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
            case let .single(action):
                var state = state
                reducer(&state, action)
                return state
                
            case let .multiple(actions):
                return actions.reduce(into: state, reducer)
            }
        }
    }
}

extension Graph.Effect: Sendable where Action: Sendable {}
extension Graph.Effect: Equatable where Action: Equatable {}
extension Graph.Effect: Hashable where Action: Hashable {}
