//
//  Reducer.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 06.07.2025.
//

import Foundation

nonisolated
public struct Reducer<State, Action>: ReducerDomain {
    
    @usableFromInline
    let reducer: (inout State, Action) -> Action?
    
    @inlinable
    public init(_ reduce: @escaping (inout State, Action) -> Action?) {
        self.reducer = reduce
    }
    
    @inlinable
    public init(_ reducer: some ReducerDomain<State, Action>) {
        self.init(reducer.reduce)
    }
    
    @inlinable
    public func reduce(_ state: inout State, action: Action) -> Action? {
        reducer(&state, action)
    }
    
    @inlinable
    public func pullback(_ child: some ReducerDomain<State, Action>) -> Reducer<State, Action> {
        Reducer<State, Action> { state, action in
            child.reduce(&state, action: action) ?? reduce(&state, action: action)
        }
    }
}

//@dynamicMemberLookup
public struct Prism<Root, Value>: Sendable {
    public let extract: @Sendable (Root) -> Value?
    public let embed: @Sendable (Value) -> Root
    
    @inlinable
    public init(
        extract: @escaping @Sendable (Root) -> Value?,
        embed: @escaping @Sendable (Value) -> Root
    ) {
        self.extract = extract
        self.embed = embed
    }
    
//    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> Prism<Root, T> {
//        Prism<Root, T>(
//            extract: { extract($0)?[keyPath: keyPath] },
//            embed: { added in
//                extract(<#T##Root#>)
//            }
//        )
//    }
}

nonisolated
public struct ChildReducer<State, Action, Child: ReducerDomain>: ReducerDomain {
    @usableFromInline
    let statePath: WritableKeyPath<State, Child.State>
    
    @usableFromInline
    let prism: Prism<Action, Child.Action>
        
    @usableFromInline
    let reducer: Child
    
    @inlinable
    public init(
        state: WritableKeyPath<State, Child.State>,
        prism: Prism<Action, Child.Action>,
        @ReducerCombine<Child.State, Child.Action> reducer: () -> Child
    ) {
        self.statePath = state
        self.prism = prism
        self.reducer = reducer()
    }
    
    @inlinable
    public func reduce(_ state: inout State, action: Action) -> Action? {
        prism.extract(action).flatMap {
            reducer.reduce(&state[keyPath: statePath], action: $0)
        }
        .map(prism.embed)
    }
}
