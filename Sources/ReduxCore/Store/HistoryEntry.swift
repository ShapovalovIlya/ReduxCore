//
//  HistoryEntry.swift
//  ReduxCore
//

import Foundation

/// A single transition recorded by the store's history buffer.
///
/// Contains the ``action`` that caused the transition and the resulting ``state``.
@dynamicMemberLookup
public struct HistoryEntry<S, A>: Sendable where S: Sendable, A: Sendable {
    /// The action that caused this transition.
    public let action: A

    /// The store state after this transition was applied.
    public let state: S

    /// Dynamic member lookup — forwards property access to ``state``.
    ///
    /// Example: `entry.count` when `State` has a `count` property.
    @inlinable
    public subscript<T>(dynamicMember keyPath: KeyPath<S, T>) -> T {
        state[keyPath: keyPath]
    }
}

extension HistoryEntry: Equatable where S: Equatable, A: Equatable {}

/// A typed alias for ``HistoryEntry`` bound to a specific ``ReduxStore``.
///
/// Use this when you need to refer to the history entry type associated with a
/// particular store, without explicitly spelling out its state and action types.
public typealias HistoryEntryOf<S: ReduxStore> = HistoryEntry<S.State, S.Action>
