//
//  ThrowingRemoveDuplicates.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//  Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncRemoveDuplicatesSequence.swift

import Foundation

public extension SequenceFX {
    //MARK: - ThrowingRemoveDuplicates
    
    /// An asynchronous sequence that omits repeated elements by testing them with an error-throwing predicate.
    ///
    /// `ThrowingRemoveDuplicates` wraps a base `AsyncSequence` and yields only elements that are not considered duplicates
    /// of the previous element, as determined by the provided predicate. The predicate can throw errors, which will be
    /// propagated to the consumer of the sequence.
    ///
    /// - Parameters:
    ///    - Base: The type of the underlying async sequence.
    ///    - Predicate: A closure that takes two elements and returns `true` if they are considered duplicates, or throws an error.
    ///
    /// ### Example
    /// ```swift
    /// let numbers = [1, 1, 2, 2, 3].async
    /// let uniqueNumbers = ReduxStream.ThrowingRemoveDuplicates(numbers) { lhs, rhs in
    ///     if lhs < 0 || rhs < 0 { throw MyError.negativeValue }
    ///     return lhs == rhs
    /// }
    /// for try await number in uniqueNumbers {
    ///     print(number) // Prints: 1, 2, 3
    /// }
    /// ```
    struct ThrowingRemoveDuplicates<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element
        public typealias Predicate = (Element, Element) throws -> Bool
        
        //MARK: - Properties
        @usableFromInline let base: Base
        @usableFromInline let predicate: Predicate
        
        //MARK: - init(_:)
        @inlinable init(
            _ base: Base,
            predicate: @escaping Predicate
        ) {
            self.base = base
            self.predicate = predicate
        }
        
        //MARK: - Public methods
        
        /// Returns an iterator that produces elements from the base sequence, omitting duplicates as determined by the throwing predicate.
        ///
        /// - Returns: An iterator that yields unique elements, or throws errors from the predicate.
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(iterator: base.makeAsyncIterator(), predicate: predicate)
        }
    }
}

extension SequenceFX.ThrowingRemoveDuplicates {
    //MARK: - Iterator
    
    /// The iterator for a `ThrowingRemoveDuplicates` instance.
    ///
    /// This iterator yields elements from the base sequence, skipping consecutive elements
    /// that are considered duplicates according to the throwing predicate. Errors thrown by the predicate
    /// are propagated to the consumer.
    public struct Iterator: AsyncIteratorProtocol {
        //MARK: - Properties
        @usableFromInline var iterator: Base.AsyncIterator
        @usableFromInline let predicate: Predicate
        @usableFromInline var last: Element?
        
        //MARK: - init(:)
        @usableFromInline
        init(
            iterator: Base.AsyncIterator,
            predicate: @escaping Predicate
        ) {
            self.iterator = iterator
            self.predicate = predicate
        }
        
        //MARK: - Public methods
        
        /// Returns the next unique element from the sequence, or `nil` if the sequence is finished.
        ///
        /// - Returns: The next unique element, or `nil`.
        /// - Throws: Rethrows errors from the underlying iterator or the predicate.
        @inlinable
        public mutating func next() async throws -> Element? {
            guard let last else {
                last = try await iterator.next()
                try Task.checkCancellation()
                return last
            }
            while let element = try await iterator.next() {
                try Task.checkCancellation()
                if try predicate(last, element) { continue }
                self.last = element
                return element
            }
            return nil
        }
    }
}

@available(*, unavailable)
extension SequenceFX.ThrowingRemoveDuplicates.Iterator: Sendable { }
