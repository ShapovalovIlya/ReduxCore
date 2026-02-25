//
//  ReduxStore.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 08.02.2026.
//

import Foundation

public protocol ReduxStore: ObservableObject, Sendable {
    associatedtype State
    associatedtype Action
    associatedtype Snapshot = StoreSnapshot<Self>
    
    var state: State { get }
    var snapshot: Snapshot { get }
    var onChange: AsyncStream<Self> { get }
    
    func updates(
        _ buffering: AsyncStream<Snapshot>.Continuation.BufferingPolicy
    ) -> AsyncStream<Snapshot>
    
    func updates() -> AsyncStream<Snapshot>
    
    func dispatch(_ action: Action)
    func dispatch(_ actions: Action...)
    func dispatch(contentsOf s: some Sequence<Action>)
    
//    func scoped<S,A>(
//        _ scope: @escaping @Sendable (State) -> S,
//        action: @escaping @Sendable (A) -> Action
//    ) -> ScopedStore<Self, S,A>
}

public extension ReduxStore {
    
    @inlinable
    var snapshot: StoreSnapshot<Self> {
        StoreSnapshot(store: self)
    }
    
    @inlinable
    func dispatch(_ action: Action) {
        dispatch(contentsOf: CollectionOfOne(action))
    }
    
    @inlinable
    func dispatch(_ actions: Action...) {
        dispatch(contentsOf: actions)
    }
    
    func updates(
        _ buffering: AsyncStream<Snapshot>.Continuation.BufferingPolicy
    ) -> AsyncStream<Snapshot> {
        AsyncStream(bufferingPolicy: buffering) { continuation in
            Task {
                await onChange.map(\.snapshot).forEach {
                    continuation.yield($0)
                }
                continuation.finish()
            }
        }
    }
    
    @inlinable
    func updates() -> AsyncStream<Snapshot> {
        updates(.unbounded)
    }
    
//    @inlinable
//    func scoped<S,A>(
//        _ scope: @escaping @Sendable (State) -> S,
//        action: @escaping @Sendable (A) -> Action
//    ) -> ScopedStore<Self, S,A> {
//        ScopedStore(base: self, scope: scope, embedAction: action)
//    }
}
