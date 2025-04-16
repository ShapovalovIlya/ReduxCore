//
//  Sequence+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 16.04.2025.
//

import Foundation

public extension Collection {
    
    @inlinable func chunked(by size: Int) -> [Self.SubSequence] {
        stride(from: .zero, to: count, by: size)
            .lazy
            .map { offset -> Range<Self.Index> in
                let fromIndex = index(startIndex, offsetBy: offset)
                let toIndex = index(startIndex, offsetBy: Swift.min(offset + size, count))
                return fromIndex..<toIndex
            }
            .map { self[$0] }
    }
}

public extension Sequence {
    
    @inlinable func chunked(by size: Int) -> [[Element]] {
        if size <= .zero { return .init() }
        
        var result = [[Element]]()
        result.reserveCapacity((underestimatedCount / size) + 1)
        
        var chunk = [Element]()
        chunk.reserveCapacity(size)
        
        for (offset, element) in self.enumerated() {
            if offset < size || (offset % size) != .zero {
                chunk.append(consume element)
                continue
            }
            result.append(chunk)
            chunk.removeAll(keepingCapacity: true)
            chunk.append(consume element)
        }
        
        if chunk.isEmpty == false {
            result.append(consume chunk)
        }
        return result
    }
}
