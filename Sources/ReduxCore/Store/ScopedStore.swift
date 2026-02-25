//
//  ScopedStore.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 08.02.2026.
//

import Foundation

@dynamicMemberLookup
/*public */final class ScopedStore<Base, State, Action>: ReduxStore, @unchecked Sendable where Base: ReduxStore {
    private var cancellables = Set<AnyCancellable>()
    
    @usableFromInline let base: Base
    @usableFromInline let scope: @Sendable (Base.State) -> State
    @usableFromInline let embedAction: @Sendable (Action) -> Base.Action
    
    @usableFromInline
    init(
        base: Base,
        scope: @escaping @Sendable (Base.State) -> State,
        embedAction: @escaping @Sendable (Action) -> Base.Action
    ) {
        self.base = base
        self.scope = scope
        self.embedAction = embedAction
        
        base.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
}

/*public*/ extension ScopedStore {
    
    @inlinable
    var state: State {
        scope(base.state)
    }
    
    @inlinable
    subscript<T>(dynamicMember keyPath: KeyPath<State,T>) -> T {
        state[keyPath: keyPath]
    }
    
    @inlinable
    var onChange: AsyncStream<ScopedStore> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            Task { [weak self] in
                defer {
                    continuation.finish()
                }
                try await self?.base.onChange.forEach { _ in
                    guard let self else {
                        throw CancellationError()
                    }
                    continuation.yield(self)
                }
            }
        }
    }

    @inlinable
    func dispatch(contentsOf s: some Sequence<Action>) {
        base.dispatch(contentsOf: s.lazy.map(embedAction))
    }
    
}
