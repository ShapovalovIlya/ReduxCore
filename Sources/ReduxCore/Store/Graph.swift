//
//  Graph.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import Foundation

public struct Graph<State, Action>: @unchecked Sendable {
    public let state: State
    public let dispatch: (Action) -> Void
    
    init(
        _ state: State,
        dispatch: @escaping (Action) -> Void
    ) {
        self.state = state
        self.dispatch = dispatch
    }
    
    public func dispatch(_ actions: Action...) {
        actions.forEach(dispatch)
    }
}
