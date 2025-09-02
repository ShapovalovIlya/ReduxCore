//
//  LazyChunkedSequence.swift
//  ReduxCore
//
//  Created by Шаповалов Илья on 01.09.2025.
//

import Foundation

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
            var chunk = Element()
            chunk.reserveCapacity(maxSize)
            
            while let next = base.next(), chunk.count < maxSize {
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
