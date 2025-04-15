//
//  AsyncSequence.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//  Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncRemoveDuplicatesSequence.swift

import Foundation

/// Namespace for custom async sequences
public enum ReduxStream { }

public extension AsyncSequence where Element: Equatable {
    /// Creates an asynchronous sequence that omits repeated elements.
    func removeDuplicates() -> ReduxStream.RemoveDuplicates<Self> {
        ReduxStream.RemoveDuplicates(self) { $0 == $1 }
    }
}

public extension AsyncSequence {
    //MARK: - Custom Sequence
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
    
    /// An asynchronous sequence that combine repeated elements with weakly retained Object.
    /// - Parameter object: the object that will be passed downstream by weak reference.
    func withUnretained<Unretained: AnyObject>(
        _ object: Unretained
    ) -> ReduxStream.WithUnretained<Self, Unretained> {
        ReduxStream.WithUnretained(base: self, unretained: object)
    }
    
    /// Create a rate-limited `AsyncSequence` by emitting values at most every specified interval.
    func throttle(for interval: TimeInterval) -> ReduxStream.Throttle<Self> {
        ReduxStream.Throttle(base: self, interval: interval)
    }
    
    //MARK: - Methods
    /// Calls the given closure on each element in the async sequence in the same order as a `for-in` loop.
    /// 
    /// - Parameter body: A closure that takes an element of the sequence as a parameter.
    @inlinable
    func forEach(
        _ body: @escaping (Element) throws -> Void
    ) async rethrows {
        for try await element in self {
            try body(element)
        }
    }
    
    /// Calls the given asynchronous closure on each element in the async sequence in the same order as a `for-in` loop.
    ///
    /// - Parameter body: A asynchronous closure that takes an element of the sequence as a parameter.
    @inlinable
    func forEach(
        _ body: @escaping (Element) async throws -> Void
    ) async rethrows {
        for try await element in self {
            try await body(element)
        }
    }
    
    /// Run Iteration over given `AsyncSequence` as part of a new top-level task on behalf of the current actor and
    /// calls the closure on each element in the `async sequence` in the same order as a `for-in` loop.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from Task.currentPriority.
    ///   - body: A closure that takes an element of the sequence as a parameter.
    @available(*, unavailable)
    @inlinable
    @discardableResult
    func forEachTask(
        priority: TaskPriority? = nil,
        _ body: sending @escaping (Element) throws -> Void
    ) -> Task<Void, Error> {
        Task(priority: priority) {
            for try await element in self {
                try body(element)
            }
        }
    }
    
    /// Run Iteration over given `AsyncSequence` as part of a new top-level task on behalf of the current actor and
    /// calls the asynchronous closure on each element in the `async sequence` in the same order as a `for-in` loop.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from Task.currentPriority.
    ///   - body: A asynchronous closure that takes an element of the sequence as a parameter.
    @inlinable
    @discardableResult
    func forEachTask(
        priority: TaskPriority? = nil,
        _ body: sending @escaping (Element) async throws -> Void
    ) -> Task<Void, Error> {
        Task(priority: priority) {
            for try await element in self {
                try Task.checkCancellation()
                try await body(element)
            }
        }
    }
    
    /// Run Iteration over given `AsyncSequence` as part of a new top-level task on behalf of the current actor and
    /// calls the asynchronous closure on each element in the `async sequence` in the same order as a `for-in` loop.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from Task.currentPriority.
    ///   - onNext: A asynchronous closure that takes an element of the sequence as a parameter.
    ///   - onCancel: A asynchronous closure that will be called after sequence is terminated.
    @inlinable
    @discardableResult
    func forEachTask(
        priority: TaskPriority? = nil,
        onNext: sending @escaping (Element) async throws -> Void,
        onCancel: sending @escaping () async throws -> Void
    ) -> Task<Void, Error> {
        Task(priority: priority) {
            for try await element in self {
                try Task.checkCancellation()
                try await onNext(element)
            }
            try Task.checkCancellation()
            try await onCancel()
        }
    }

}
