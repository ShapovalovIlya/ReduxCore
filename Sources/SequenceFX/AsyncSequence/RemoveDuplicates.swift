//
//  RemoveDuplicates.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//  Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncRemoveDuplicatesSequence.swift

public extension SequenceFX {
    //MARK: - RemoveDuplicates
    
    /// An asynchronous sequence that omits repeated elements by testing them with a predicate.
    ///
    /// `RemoveDuplicates` wraps a base `AsyncSequence` and only yields elements that are not considered duplicates
    /// of the previous element, as determined by the provided predicate.
    ///
    /// - Parameters:
    /// - Base: The type of the underlying async sequence.
    /// - Predicate: A closure that takes two elements and returns `true` if they are considered duplicates.
    ///
    /// ### Example
    /// ```swift
    /// let numbers = [1, 1, 2, 2, 3].async
    /// let uniqueNumbers = ReduxStream.RemoveDuplicates(numbers) { $0 == $1 }
    /// for await number in uniqueNumbers {
    ///    print(number) // Prints: 1, 2, 3
    /// }
    /// ```
    struct RemoveDuplicates<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element
        public typealias Predicate = (Element, Element) -> Bool
        
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
        
        /// Returns an iterator that produces elements from the base sequence, omitting duplicates.
        ///
        /// - Returns: An iterator that yields unique elements.
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(iterator: base.makeAsyncIterator(), predicate: predicate)
        }
    }
}

public extension SequenceFX.RemoveDuplicates {
    //MARK: - Iterator
    
    /// The iterator for a `RemoveDuplicates` instance.
    ///
    /// This iterator yields elements from the base sequence, skipping consecutive elements
    /// that are considered duplicates according to the predicate.
    struct Iterator: AsyncIteratorProtocol {
        //MARK: - Properties
        @usableFromInline var iterator: Base.AsyncIterator
        @usableFromInline let predicate: Predicate
        @usableFromInline var last: Element?
        
        //MARK: - init(_:)
        @usableFromInline
        init(iterator: Base.AsyncIterator, predicate: @escaping Predicate) {
            self.iterator = iterator
            self.predicate = predicate
        }
        
        //MARK: - Public methods
        
        /// Returns the next unique element from the sequence, or `nil` if the sequence is finished.
        ///
        /// - Returns: The next unique element, or `nil`.
        /// - Throws: Rethrows errors from the underlying iterator.
        @inlinable
        public mutating func next() async rethrows -> Element? {
            guard let last else {
                last = try await iterator.next()
                try Task.checkCancellation()
                return last
            }
            while let element = try await iterator.next() {
                try Task.checkCancellation()
                if predicate(last, element) { continue }
                self.last = element
                return element
            }
            return nil
        }
    }
}

@available(*, unavailable)
extension SequenceFX.RemoveDuplicates.Iterator: Sendable { }
