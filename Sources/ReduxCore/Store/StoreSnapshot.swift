//
//  StoreSnapshot.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import Foundation

/// A lightweight, immutable snapshot of store state with safe action dispatch capability.
///
/// `StoreSnapshot` provides a thread-safe, value-type wrapper that encapsulates a frozen
/// state snapshot along with a reference to dispatch actions back to the originating store.
///
/// Equality is based on internal storage identity, not state content. The "==" operation is O(1)
///
/// ## Overview
/// - **Immutable**: Contains a frozen copy of state at creation time
/// - **Thread-safe**: Can be safely passed between threads
/// - **Lightweight**: Copying is cheap due to internal reference semantics
/// - **Type-safe**: Maintains full type safety for both state and actions
///
/// ## When to Use
/// Use `StoreSnapshot` when you need to:
/// - Pass state to child components without exposing the full store
/// - Provide read-only state access with controlled mutation capability
/// - Avoid reference cycles in view hierarchies
/// - Work in concurrent contexts safely
///
/// ## Example
/// ```swift
/// // Create from a store
/// let snapshot = store.snapshot
///
/// // Access immutable state
/// let currentCount = snapshot.state.count
///
/// // Dispatch actions safely
/// snapshot.dispatch(.increment)
/// snapshot.dispatch(.increment, .decrement) // Multiple actions
/// ```
///
/// - Note: `StoreSnapshot` does not automatically update when state changes.
///   Retrieve a new snapshot from the store to get current state.
/// - Important: The `store` reference is weak, so snapshots don't prevent store deallocation.
///
@dynamicMemberLookup
public struct StoreSnapshot<Store> where Store: ReduxStore {
    @usableFromInline
    final class Storage {
        
        @usableFromInline
        let wrapped: Store.State
        
        @inlinable
        init(_ wrapped: Store.State) { self.wrapped = wrapped }
    }
    
    @usableFromInline
    let storage: Storage
    
    @usableFromInline
    weak var store: Store?
    
    //MARK: - init(_:)
    @inlinable
    init(store: Store) {
        self.store = store
        self.storage = Storage(store.state)
    }
}

public extension StoreSnapshot {
    
    /// The immutable state captured when this snapshot was created.
    ///
    /// Access is thread-safe and returns the same value for the snapshot's lifetime.
    @inlinable
    var state: Store.State {
        storage.wrapped
    }
    
    @inlinable
    var isDetached: Bool {
        store == nil
    }
    
    @inlinable
    subscript<T>(dynamicMember keyPath: KeyPath<Store.State, T>) -> T {
        state[keyPath: keyPath]
    }
    
    //MARK: - Public methods
    
    /// Dispatches a single action to the underlying ``Store``.
    ///
    /// Triggers state changes in response to user interactions or events.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter action: The action to be dispatched to the store.
    @inlinable
    func dispatch(_ action: Store.Action) {
        store?.dispatch(action)
    }
    
    /// Dispatches multiple actions to the underlying ``Store`` in the order provided.
    ///
    /// Use to trigger a series of state changes.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter actions: A variadic list of actions to be dispatched to the store, in order.
    @inlinable
    func dispatch(_ actions: Store.Action...) {
        store?.dispatch(contentsOf: actions)
    }
    
    /// Dispatches a sequence of actions to the underlying store in the order they appear in the sequence.
    ///
    /// Use to efficiently batch state changes.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter s: A sequence of actions to be dispatched to the store, in order.
    @inlinable
    func dispatch(contentsOf s: some Sequence<Store.Action>) {
        store?.dispatch(contentsOf: s)
    }
}

extension StoreSnapshot: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        ObjectIdentifier(lhs.storage) == ObjectIdentifier(rhs.storage)
    }
}

extension StoreSnapshot.Storage: Sendable where Store.State: Sendable {}
extension StoreSnapshot: Sendable where Store.State: Sendable {}
