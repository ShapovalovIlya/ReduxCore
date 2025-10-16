//
//  Sequence+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 16.04.2025.
//

import Foundation

public extension Collection {
    
    /// Splits the collection into consecutive `SubSequence` chunks of length `size`.
    ///
    /// - Parameters:
    ///   - size: Maximum number of elements per chunk. Must be greater than 0.
    /// - Returns: An array of `SubSequence` chunks. The last chunk may be shorter.
    ///
    /// - Complexity: O(n).
    @inlinable
    func chunked(by size: Int) -> [SubSequence] {
        if size <= .zero {
            return []
        }
        return stride(from: .zero, to: count, by: size).map { offset in
            let start = index(startIndex, offsetBy: offset)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return self[start..<end]
        }
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
    
    @inlinable
    func chunked(by size: Int) -> [[Element]] {
        guard size > 0 else {
            return .init()
        }
        
        var result = [[Element]]()
        result.reserveCapacity((underestimatedCount / size) + 1)
        
        var chunk = [Element]()
        chunk.reserveCapacity(size)
        
        var count = 0
        for element in self {
            chunk.append(element)
            count += 1
            if count == size {
                result.append(chunk)
                chunk.removeAll(keepingCapacity: true)
                count = 0
            }
        }
        
        if !chunk.isEmpty {
            result.append(chunk)
        }
        return result
    }
    
    /// Splits the sequence into two arrays based on a predicate, preserving element order.
    ///
    /// Elements for which `predicate` returns `true` are collected into the `satisfied`
    /// array; all other elements go into the `unsatisfied` array. This is a single-pass,
    /// stable partition that does not mutate the original sequence.
    ///
    /// - Parameters:
    ///   - predicate: A throwing closure that evaluates each element and returns `true`
    ///                if the element should be placed in `satisfied`, otherwise `false`.
    ///
    /// - Returns: A tuple containing:
    ///   - `satisfied`: All elements that met the predicate.
    ///   - `unsatisfied`: All elements that did not meet the predicate.
    ///
    /// - Throws: Rethrows any error thrown by `predicate`. If an error is thrown,
    ///           iteration stops immediately and no partial result is returned.
    ///
    /// - Complexity: O(n), where n is the length of the sequence. Performs exactly one
    ///               pass with constant additional work per element.
    ///
    /// - Note: The relative order of elements within each returned array is the same
    ///         as their order in the original sequence (stable partition).
    ///
    /// ### Example
    /// ```swift
    /// let numbers = [1, 2, 3, 4, 5, 6]
    /// let result = numbers.partitioned { $0.isMultiple(of: 2) }
    /// // result.satisfied   == [2, 4, 6]
    /// // result.unsatisfied == [1, 3, 5]
    /// ```
    ///
    /// ### Example: Throwing predicate
    /// ```swift
    /// enum ValidationError: Error { case negative }
    ///
    /// let values = [1, -1, 2]
    /// do {
    ///     let res = try values.partitioned { value in
    ///         if value < 0 { throw ValidationError.negative }
    ///         return value % 2 == 0
    ///     }
    ///     // Use res.satisfied / res.unsatisfied
    /// } catch {
    ///     // Handle ValidationError.negative
    /// }
    /// ```
    @inlinable
    func partitioned(
        by predicate: (Element) throws -> Bool
    ) rethrows -> (satisfied: [Element], unsutisfied: [Element]) {
        try reduce(into: ([], [])) { partialResult, element in
            try predicate(element)
            ? partialResult.satisfied.append(element)
            : partialResult.unsutisfied.append(element)
        }
    }
}
