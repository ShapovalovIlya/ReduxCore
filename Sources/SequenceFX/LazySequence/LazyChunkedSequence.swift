//
//  LazyChunkedSequence.swift
//  ReduxCore
//
//  Created by Шаповалов Илья on 01.09.2025.
//

import Foundation

/// A lazy sequence that groups elements from a base sequence into fixed-size chunks.
///
/// `LazyChunkedSequence` consumes a base `Sequence` and yields arrays (`[Base.Element]`)
/// of up to `maxSize` elements per iteration. The last chunk may contain fewer elements
/// if the base sequence ends before filling it.
///
///### Characteristics:
///   - Lazy: Elements are pulled from `base` only when iterating.
///   - Non-owning: Does not copy the entire base sequence; it reads via the base iterator.
///   - Fixed upper bound: Each emitted chunk has `count <= maxSize`.
///   - Order-preserving: Elements retain their original order within chunks.
///   - Single-pass: Iteration consumes the base sequence; restarting requires a new sequence.
///
///### Example:
/// ```swift
/// let numbers = 1...10
/// let chunks = LazyChunkedSequence(maxSize: 3, base: numbers)
/// for chunk in chunks {
///     // Emits: [1,2,3], [4,5,6], [7,8,9], [10]
///     print(chunk)
/// }
/// ```
///
/// - Important:
///   - `maxSize` must be greater than zero. Passing `maxSize <= 0` results in every `next()` producing
///     an empty chunk and iteration ending immediately.
///   - Since this is based on `Sequence`/`IteratorProtocol`, it is single-pass and not guaranteed to be
///     reentrant or thread-safe unless `Base` is.
///
public struct LazyChunkedSequence<Base: Sequence>: LazySequenceProtocol {
    public typealias Element = [Base.Element]
    
    //MARK: - Iterator
    public struct Iterator: IteratorProtocol {
        @usableFromInline let maxSize: Int
        @usableFromInline var base: Base.Iterator
        
        //MARK: - init
        @inlinable
        init(maxSize: Int, base: Base.Iterator) {
            self.maxSize = maxSize
            self.base = base
        }
        
        @inlinable
        public mutating func next() -> Element? {
            if maxSize < 1 {
                return nil
            }
            var chunk = Element()
            chunk.reserveCapacity(maxSize)
            
            while chunk.count < maxSize, let next = base.next() {
                chunk.append(next)
            }
            if chunk.isEmpty {
                return nil
            }
            return chunk
        }
    }
    
    @usableFromInline let maxSize: Int
    @usableFromInline let base: Base
    
    //MARK: - init
    @inlinable
    init(maxSize: Int, base: Base) {
        self.maxSize = maxSize
        self.base = base
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(maxSize: maxSize, base: base.makeIterator())
    }
}
