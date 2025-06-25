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
    @inlinable
    func removeDuplicates() -> ReduxStream.RemoveDuplicates<Self> {
        ReduxStream.RemoveDuplicates(self) { $0 == $1 }
    }
}

public extension AsyncSequence {
    //MARK: - Custom Sequence
    /// Creates an asynchronous sequence that omits repeated elements by testing them with a predicate.
    @inlinable
    func removeDuplicates(
        by predicate: @escaping @Sendable (Element, Element) async -> Bool
    ) -> ReduxStream.RemoveDuplicates<Self> {
        ReduxStream.RemoveDuplicates(self, predicate: predicate)
    }
    
    /// Creates an asynchronous sequence that omits repeated elements by testing them with an error-throwing predicate.
    @inlinable
    func removeDuplicates(
        by predicate: @escaping @Sendable (Element, Element) async throws -> Bool
    ) -> ReduxStream.ThrowingRemoveDuplicates<Self> {
        ReduxStream.ThrowingRemoveDuplicates(self, predicate: predicate)
    }
    
    /// An asynchronous sequence that combine repeated elements with weakly retained Object.
    /// - Parameter object: the object that will be passed downstream by weak reference.
    @inlinable
    func withUnretained<Unretained: AnyObject>(
        _ object: Unretained
    ) -> ReduxStream.WithUnretained<Self, Unretained> {
        ReduxStream.WithUnretained(base: self, unretained: object)
    }
    
    /// Create a rate-limited `AsyncSequence` by emitting values at most every specified interval.
    @inlinable
    func throttle(for interval: TimeInterval) -> ReduxStream.Throttle<Self> {
        ReduxStream.Throttle(base: self, interval: interval)
    }
    
    //MARK: - Methods
    /// Asynchronously performs the given closure on each element of the asynchronous sequence, in the same order as a `for-in` loop.
    ///
    /// This method iterates over each element in the asynchronous sequence, invoking the provided closure
    /// for each element. If the task is cancelled during iteration, the method returns early and no further
    /// elements are processed.
    ///
    /// - Parameter body: An asynchronous closure that takes an element of the sequence as its parameter.
    /// - Throws: Rethrows any error thrown by the closure, the sequence’s asynchronous iterator, or if the task is cancelled.
    /// - Important: If the surrounding task is cancelled, this method throws `CancellationError` and stops processing further elements.
    ///
    /// ### SeeAlso:
    /// - ``forEachTask(priority:_:)`` for a version that runs Iteration as part of a new top-level task on behalf of the current actor.
    ///
    /// ### Example:
    /// ```swift
    /// try await asyncSequence.forEach { element in
    ///     print(element)
    /// }
    /// ```
    ///
    @inlinable
    func forEach(
        _ body: @escaping (Element) async throws -> Void
    ) async rethrows {
        for try await element in self {
            try Task.checkCancellation()
            try await body(element)
        }
    }
    
    /// Launches a new asynchronous task to perform the given closure on each element of the asynchronous sequence.
    ///
    /// This method creates and returns a ``_Concurrency/Task`` that iterates over each element in the asynchronous sequence,
    /// invoking the provided closure for each element.
    ///
    /// - Parameters:
    ///   - priority: The priority of the created task. Defaults to `nil`, which uses the default priority.
    ///   - body: An asynchronous, sendable closure that takes an element of the sequence as its parameter.
    /// - Returns: The created `Task<Void, Error>`, which can be awaited or cancelled as needed.
    /// - Important: If the task is cancelled, iteration stops and a `CancellationError` is thrown.
    /// - Note: The returned task might be managed by the caller or discarded
    ///
    /// ### Example:
    ///   ```swift
    ///   let task = asyncSequence.forEachTask { element in
    ///       print(element)
    ///   }
    ///   // Optionally await or cancel the task
    ///   try await task.value
    ///   ```
    ///
    @inlinable
    @discardableResult
    func forEachTask(
        priority: TaskPriority? = nil,
        _ body: @escaping @Sendable (Element) async -> Void
    ) -> Task<Void, Error> {
        Task(priority: priority) {
            try await self.forEach(body)
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
        _ body: @escaping @Sendable (Element) async throws -> Void
    ) -> Task<Void, Error> {
        Task(priority: priority) {
            try await self.forEach(body)
        }
    }
    
    /// Run Iteration over given `AsyncSequence` as part of a new top-level task on behalf of the current actor and
    /// calls the asynchronous closure on each element in the `async sequence` in the same order as a `for-in` loop.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from Task.currentPriority.
    ///   - onNext: A asynchronous closure that takes an element of the sequence as a parameter.
    ///   - onCancel: A asynchronous closure that will be called after sequence is terminated.
    
    /// Launches a new asynchronous task to process each element of the asynchronous sequence, with custom cancellation handling.
    ///
    /// This method creates and returns a ``_Concurrency/Task`` that iterates over each element in the asynchronous sequence,
    /// invoking the `onNext` closure for each element.
    /// After processing all elements,  the `onCancel` closure is invoked to allow for custom cancellation or cleanup logic.
    ///
    /// - Parameters:
    ///   - priority: The priority of the created task. Defaults to `nil`, which uses the default priority.
    ///   - onNext: An asynchronous, sendable closure that is called for each element in the sequence.
    ///   - onCancel: An asynchronous, sendable closure that is called after processing all elements.
    /// - Returns: The created `Task<Void, Error>`, which can be awaited or cancelled as needed.
    /// - Throws: Rethrows any error thrown by `onNext`, `onCancel`, or the sequence’s asynchronous iterator.
    /// - Important: If the task is cancelled manualy or element processing throws error, `onCancel` is never be invoked.
    /// - Note: The returned task might be managed by the caller or discarded.
    /// .
    /// ### Example:
    ///   ```swift
    ///   let task = asyncSequence.forEachTask(
    ///       onNext: { element in
    ///           print(element)
    ///       },
    ///       onCancel: {
    ///           print("Task completed.")
    ///       }
    ///   )
    ///   // Optionally await or cancel the task
    ///   try await task.value
    ///   ```
    ///
    @inlinable
    @discardableResult
    func forEachTask(
        priority: TaskPriority? = nil,
        onNext: @escaping @Sendable (Element) async throws -> Void,
        onCancel: @escaping @Sendable () async throws -> Void
    ) -> Task<Void, Error> {
        Task(priority: priority) {
            try await self.forEach(onNext)
            try Task.checkCancellation()
            try await onCancel()
        }
    }

}
