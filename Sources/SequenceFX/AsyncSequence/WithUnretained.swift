//
//  WithUnretained.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.08.2024.
//

import Foundation

public extension SequenceFX {
    //MARK: - WithUnretained

    /// An asynchronous sequence that combines each element from an upstream async sequence with a weakly retained object.
    ///
    /// `WithUnretained` wraps a base `AsyncSequence` and yields a tuple containing a weakly retained object and each element from the base sequence.
    /// The sequence automatically terminates if the upstream sequence finishes, the parent task is cancelled, or the object is released (deallocated).
    ///
    /// - Parameters:
    ///    - Base: The type of the underlying async sequence.
    ///    - Object: The type of the object to be weakly retained. Must be a class type (`AnyObject`).
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
    ///
    /// - Note: If `object` is deallocated, the sequence ends.
    struct WithUnretained<Base, Object>: AsyncSequence where Base: AsyncSequence,
                                                             Object: AnyObject {
        public typealias Element = (Object, Base.Element)
        
        //MARK: - Properties
        @usableFromInline let base: Base
        @usableFromInline weak var unretained: Object?
        
        //MARK: - init(_:)
        @inlinable init(
            base: Base,
            unretained: Object
        ) {
            self.base = base
            self.unretained = unretained
        }
        
        //MARK: - Public methods
        
        /// Returns an iterator that produces tuples of the weakly retained object and elements from the base sequence.
        ///
        /// - Returns: An iterator that yields `(Object, Base.Element)` tuples, or ends if the object is released.
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(iterator: base.makeAsyncIterator(), unretained: unretained)
        }
    }
}

public extension SequenceFX.WithUnretained {
    //MARK: - Iterator

    /// The iterator for a `WithUnretained` instance.
    ///
    /// The iterator yields tuples of the weakly retained object and each element from the base sequence.
    /// The iterator's `next()` method returns `nil` if the parent task is cancelled, the upstream iterator finishes,
    /// or the object is released (deallocated).
    struct Iterator: AsyncIteratorProtocol {
        //MARK: - Properties
        @usableFromInline var iterator: Base.AsyncIterator
        @usableFromInline weak var unretained: Object?
        
        //MARK: - init(_:)
        @usableFromInline
        init(
            iterator: Base.AsyncIterator,
            unretained: Object?
        ) {
            self.iterator = iterator
            self.unretained = unretained
        }
        
        //MARK: - Public methods
        
        /// Returns the next tuple of the weakly retained object and an element from the underlying async sequence, or `nil` if the sequence is finished.
        ///
        /// This method yields a tuple containing the current value of the weakly retained object and the next element from the base sequence.
        /// The method returns `nil` and terminates the sequence if:
        /// - The upstream iterator returns `nil` (i.e., the sequence is finished),
        /// - The weakly retained object has been deallocated,
        /// - The parent task is cancelled.
        ///
        /// - Returns: The next `(Object, Base.Element)` tuple, or `nil` if the sequence is finished or the object is released.
        /// - Throws: Rethrows errors from the underlying iterator.
        @inlinable
        public mutating func next() async rethrows -> Element? {
            guard let next = try await iterator.next(), let unretained else {
                return nil
            }
            try Task.checkCancellation()
            return (unretained, next)
        }
    }
}

extension SequenceFX.WithUnretained: Sendable where Base: Sendable, Object: Sendable {}

@available(*, unavailable)
extension SequenceFX.WithUnretained.Iterator: Sendable {}
