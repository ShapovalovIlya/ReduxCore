//
//  AsyncSequence.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//  Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncRemoveDuplicatesSequence.swift

import Foundation

/// Namespace for custom async sequences
public enum ReduxStream {
    
}

public extension AsyncSequence where Element: Equatable {
    /// Creates an asynchronous sequence that omits repeated elements.
    func removeDuplicates() -> ReduxStream.RemoveDuplicates<Self> {
        ReduxStream.RemoveDuplicates(self) { $0 == $1 }
    }
}

public extension AsyncSequence {
    /// Creates an asynchronous sequence that omits repeated elements by testing them with a predicate.
    func removeDuplicates(
        by predicate: @escaping @Sendable (Element, Element) async -> Bool
    ) -> ReduxStream.RemoveDuplicates<Self> {
        ReduxStream.RemoveDuplicates(self, predicate: predicate)
    }
    
    /// Creates an asynchronous sequence that omits repeated elements by testing them with an error-throwing predicate.
    func removeDuplicates(
        by predicate: @escaping @Sendable (Element, Element) async throws -> Bool
    ) -> ReduxStream.ThrowingRemoveDuplicates<Self> {
        ReduxStream.ThrowingRemoveDuplicates(self, predicate: predicate)
    }
}
