//
//  LazySequence+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 20.04.2025.
//

import Foundation

public extension LazySequenceProtocol {
    @inlinable func run() -> [Element] { Array(self) }
}

public extension LazySequenceProtocol {
    
    /// Lazily removes duplicate elements using the provided identity function.
    ///
    /// Function returns a `LazyRemoveDuplicatesSequence<Self, Element>` that yields only the
    /// first occurrence of each unique element. Subsequent elements equal to one already seen
    /// (as determined by `Hashable`/`Equatable`) are skipped.
    ///
    /// - Parameter identityOf: A function mapping each element to a `Hashable` identity.
    /// - Returns: A lazy sequence that emits each distinct element once, preserving the order
    ///   of their first appearance.
    ///
    ///### Characteristics:
    ///   - Lazy: Elements are pulled on demand during iteration; the base sequence is not eagerly consumed.
    ///   - Order-preserving (first occurrence): The first encounter of each unique element is retained.
    ///   - Single-pass: Iteration consumes the base; to iterate again, recreate the sequence.
    ///
    /// - Complexity:
    ///   - Creation: O(1)
    ///   - Iteration: Amortized O(1) per element due to `Set` membership checks; total O(n).
    ///
    /// - Important:
    ///   - Requires `Element` to be `Hashable` (and typically `Equatable`) so duplicates can be detected correctly.
    ///
    ///### Example:
    /// ```swift
    /// let values = [1, 2, 2, 3, 1, 4].lazy
    /// let unique = values.removedDuplicates()
    /// Array(unique) // => [1, 2, 3, 4]
    ///
    /// // Works with non-array sequences as well:
    /// let words = ["Apple", "Banana", "Apple", "Cherry"].lazy
    /// Array(words.removedDuplicates()) // => ["Apple", "Banana", "Cherry"]
    /// ```
    @inlinable
    func removedDuplicates<T: Hashable>(
        using identityOf: @escaping (Element) -> T
    ) -> LazyRemoveDuplicatesSequence<Self, T> {
        LazyRemoveDuplicatesSequence(self, identityOf: identityOf)
    }
    
    /// Lazily groups elements of this sequence into contiguous chunks of at most `size` elements.
    ///
    /// - Parameters:
    ///   - size: The maximum number of elements per emitted chunk.
    ///
    ///### Behavior:
    ///   - Elements are pulled on demand (lazy); the base sequence is not eagerly consumed.
    ///   - Chunks preserve input order and are contiguous.
    ///
    /// - Complexity:
    ///   - Creating the sequcence: O(1)
    ///   - Iteration: O(k) per chunk where `k <= size`, total O(n) for `n` elements.
    @inlinable
    func chunked(by size: Int) -> LazyChunkedSequence<Self> {
        LazyChunkedSequence(maxSize: size, base: self)
    }
}

public extension LazySequenceProtocol where Element: Hashable {
    /// Lazily removes duplicate elements from this sequence using element equality and hashing.
    ///
    /// Function returns a `LazyRemoveDuplicatesSequence<Self, Element>` that yields only the
    /// first occurrence of each unique element. Subsequent elements equal to one already seen
    /// (as determined by `Hashable`/`Equatable`) are skipped.
    ///
    /// - Returns: A lazy sequence that emits each distinct element once, preserving the order
    ///   of their first appearance.
    ///
    ///### Characteristics:
    ///   - Lazy: Elements are pulled on demand during iteration; the base sequence is not eagerly consumed.
    ///   - Order-preserving (first occurrence): The first encounter of each unique element is retained.
    ///   - Single-pass: Iteration consumes the base; to iterate again, recreate the sequence.
    ///
    /// - Complexity:
    ///   - Creation: O(1)
    ///   - Iteration: Amortized O(1) per element due to `Set` membership checks; total O(n).
    ///
    /// - Important:
    ///   - Requires `Element` to be `Hashable` (and typically `Equatable`) so duplicates can be detected correctly.
    ///
    ///### Example:
    /// ```swift
    /// let values = [1, 2, 2, 3, 1, 4].lazy
    /// let unique = values.removedDuplicates()
    /// Array(unique) // => [1, 2, 3, 4]
    ///
    /// // Works with non-array sequences as well:
    /// let words = ["Apple", "Banana", "Apple", "Cherry"].lazy
    /// Array(words.removedDuplicates()) // => ["Apple", "Banana", "Cherry"]
    /// ```
    @inlinable
    func removedDuplicates() -> LazyRemoveDuplicatesSequence<Self, Element> {
        LazyRemoveDuplicatesSequence(self, identityOf: \.self)
    }
}
