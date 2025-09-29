//
//  EmptyReducer.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 06.07.2025.
//

import Foundation

public struct EmptyReducer<State, Action>: ReducerDomain {
    
    @usableFromInline
    init(empty: Void) {}
    
    @inlinable
    public init() {
        self.init(empty: ())
    }
    
    @inlinable
    public func reduce(_ state: inout State, action: Action) -> Action? {
        nil
    }
}
