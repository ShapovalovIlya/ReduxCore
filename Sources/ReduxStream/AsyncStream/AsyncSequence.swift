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
    
    /// Returns an asynchronous sequence that omits consecutive duplicate elements, using equality (`==`) for comparison.
    ///
    /// This method creates a ``ReduxStream/ReduxStream/RemoveDuplicates`` sequence from the current async sequence,
    /// yielding only elements that are not equal to the immediately preceding element.
    ///
    /// - Returns: An async sequence that yields only unique consecutive elements from the original sequence.
    ///
    /// ### Example
    /// ```swift
    /// let numbers = [1, 1, 2, 2, 3].async
    /// for await number in numbers.removeDuplicates() {
    ///     print(number) // Prints: 1, 2, 3
    /// }
    /// ```
    @inlinable
    func removeDuplicates() -> ReduxStream.RemoveDuplicates<Self> {
        ReduxStream.RemoveDuplicates(self) { $0 == $1 }
    }
}

public extension AsyncSequence {
    //MARK: - Custom Sequence
    
    /// Returns an asynchronous sequence that omits consecutive duplicate elements, using the provided predicate for comparison.
    ///
    /// This method creates a ``ReduxStream/ReduxStream/RemoveDuplicates`` sequence from the current async sequence,
    /// yielding only elements that are not considered duplicates of the immediately preceding element,
    /// as determined by the given predicate.
    ///
    /// - Parameter predicate: A closure that takes two elements and returns `true` if they are considered duplicates.
    /// - Returns: An async sequence that yields only unique consecutive elements from the original sequence, according to the predicate.
    ///
    /// ### Example
    /// ```swift
    /// let words = ["apple", "Apple", "banana", "banana"].async
    /// for await word in words.removeDuplicates(by: { $0.lowercased() == $1.lowercased() }) {
    ///     print(word) // Prints: "apple", "banana"
    /// }
    /// ```
    @inlinable
    func removeDuplicates(
        by predicate: @escaping (Element, Element) -> Bool
    ) -> ReduxStream.RemoveDuplicates<Self> {
        ReduxStream.RemoveDuplicates(self, predicate: predicate)
    }
    
    /// Returns an asynchronous sequence that omits consecutive duplicate elements, using the provided error-throwing predicate for comparison.
    ///
    /// This method creates a ``ReduxStream/ReduxStream/ThrowingRemoveDuplicates`` sequence from the current async sequence,
    /// yielding only elements that are not considered duplicates of the immediately preceding element,
    /// as determined by the given predicate. If the predicate throws an error, the sequence terminates with that error.
    ///
    /// - Parameter predicate: A closure that takes two elements and returns `true` if they are considered duplicates, or throws an error.
    /// - Returns: An async sequence that yields only unique consecutive elements from the original sequence, according to the predicate.
    /// - Throws: Rethrows errors from the predicate during iteration.
    ///
    /// ### Example
    /// ```swift
    /// let numbers = [1, 1, 2, 2, 3].async
    /// for try await number in numbers.removeDuplicates(by: { lhs, rhs in
    ///     if lhs < 0 || rhs < 0 { throw MyError.negativeValue }
    ///     return lhs == rhs
    /// }) {
    ///     print(number) // Prints: 1, 2, 3
    /// }
    /// ```
    @inlinable
    func removeDuplicates(
        by predicate: @escaping (Element, Element) throws -> Bool
    ) -> ReduxStream.ThrowingRemoveDuplicates<Self> {
        ReduxStream.ThrowingRemoveDuplicates(self, predicate: predicate)
    }
    
    /// Returns an asynchronous sequence that combines each element from the current sequence with a weakly retained object.
    ///
    /// This method creates a ``ReduxStream/ReduxStream/WithUnretained`` sequence from the current async sequence and the provided object.
    /// Each element yielded by the resulting sequence is a tuple containing the object and the corresponding element from the base sequence.
    /// The sequence automatically terminates if the upstream sequence finishes, the parent task is cancelled, or the object is deallocated.
    ///
    /// - Note: If `object` is deallocated, the sequence ends.
    ///
    /// - Parameter object: The object to be weakly retained and combined with each element of the sequence.
    /// - Returns: An async sequence yielding tuples of the object and each element from the original sequence. The sequence ends if the object is released.
    ///
    /// ### Example
    /// ```swift
    /// class MyClass {}
    /// let object = MyClass()
    /// let numbers = [1, 2, 3].async
    /// for await (obj, number) in numbers.withUnretained(object) {
    ///     print(obj, number)
    /// }
    /// ```
    @inlinable
    func withUnretained<Unretained: AnyObject>(
        _ object: Unretained
    ) -> ReduxStream.WithUnretained<Self, Unretained> {
        ReduxStream.WithUnretained(base: self, unretained: object)
    }
    
    /// Returns a throttled asynchronous sequence that emits elements no more frequently than the specified interval.
    ///
    /// This method creates a ``ReduxStream/ReduxStream/Throttle`` sequence from the current async sequence.
    /// Use this method to limit the rate at which elements are emitted from the sequence.
    /// Only one element will be emitted per interval, even if the base sequence produces more elements.
    ///
    /// - Parameter interval: The minimum interval (in seconds) between emitted elements.
    /// - Returns: A sequence that emits elements at most once per specified interval.
    ///
    /// Example:
    /// ```swift
    /// let throttledSequence = someAsyncSequence.throttle(for: 1.0)
    /// for await value in throttledSequence {
    ///     print(value) // Values are printed at most once per second
    /// }
    /// ```
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
            if Task.isCancelled { return }
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
    @available(*, deprecated, renamed: "task")
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
    ///   let task = asyncSequence.task { element in
    ///       print(element)
    ///   }
    ///   // Optionally await or cancel the task
    ///   try await task.value
    ///   ```
    ///
    @inlinable
    @discardableResult
    func task(
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
    @available(*, deprecated, renamed: "task")
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
    ///   let task = asyncSequence.task(
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
    func task(
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
