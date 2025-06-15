//
//  Sequence+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 16.04.2025.
//

import Foundation

public extension Collection {
    
    @inlinable func chunked(by size: Int) -> [SubSequence] {
        stride(from: .zero, to: count, by: size).lazy
            .map { offset -> Range<Self.Index> in
                let fromIndex = index(startIndex, offsetBy: offset)
                let toIndex = index(startIndex, offsetBy: Swift.min(offset + size, count))
                return fromIndex..<toIndex
            }
            .map { self[$0] }
    }
    
    @inlinable
    func removedDuplicates<T: Hashable>(
        using identityOf: (Element) throws -> T
    ) rethrows -> [Element] {
        var identities = Set<T>(minimumCapacity: count)
        return try filter { element in
            try identities.insert(identityOf(element)).inserted
        }
    }
}

public extension Collection where Element: Hashable {
    @inlinable
    func removedDuplicates() -> [Element] {
        var identities = Set<Element>(minimumCapacity: count)
        return filter { element in
            identities.insert(element).inserted
        }
    }
}

public extension Sequence {
    
    @inlinable func chunked(by size: Int) -> [[Element]] {
        guard size > 0 else {
            return .init()
        }
        
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
