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
    /// - Behavior:
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
    @inlinable
    func removedDuplicates() -> LazyRemoveDuplicatesSequence<Self, Element> {
        LazyRemoveDuplicatesSequence(self, identityOf: \.self)
    }
}
