//
//  LazyRemoveDuplicatesSequence.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 19.04.2025.
//

import Foundation

/// A lazy sequence that removes duplicate elements based on a supplied identity function.
///
/// `LazyRemoveDuplicatesSequence` iterates over a base `Sequence` and yields only the first
/// occurrence of each unique identity, as determined by `identityOf`. Subsequent elements whose
/// computed identity has already been seen are skipped.
///
/// - Characteristics:
///   - Lazy: Elements are pulled from `base` only during iteration.
///   - Order-preserving (first occurrence): The first element for each identity is yielded in the order
///     they appear in `base`.
///   - Single-pass: Iteration consumes the base sequence; restarting requires a new sequence.
///   - Configurable identity: Any `Hashable` identity can be used (e.g., a key path, ID field, normalized value).
///
/// - Example:
/// ```swift
/// struct User { let id: Int; let name: String }
/// let users = [User(id: 1, name: "A"), User(id: 2, name: "B"), User(id: 1, name: "A2")]
///
/// // Remove duplicates by user id
/// let uniqueById = LazyRemoveDuplicatesSequence(users) { $0.id }
/// Array(uniqueById) // => [User(id: 1, name: "A"), User(id: 2, name: "B")]
///
/// // Remove duplicates by case-insensitive name
/// let names = ["Apple", "banana", "BANANA", "apple", "Cherry"]
/// let uniqueNames = LazyRemoveDuplicatesSequence(names) { $0.lowercased() }
/// Array(uniqueNames) // => ["Apple", "banana", "Cherry"]
/// ```
///
/// - Complexity:
///   - Creating the sequcence: O(1) plus a `Set` allocation sized to `base.underestimatedCount`.
///   - Iteration: Amortized O(1) per element for `Set` insertion/lookup; total O(n).
///
/// - Important:
///   - The identity function must be deterministic and stable across iteration. If `identityOf` produces
///     varying results for the same element across calls, behavior is undefined.
///   - This is single-pass and not thread-safe unless `Base` and the identity function are.
///
public struct LazyRemoveDuplicatesSequence<Base: Sequence, Identity: Hashable>: LazySequenceProtocol {
    public typealias Element = Base.Element
    
    @usableFromInline let base: Base
    @usableFromInline let identityOf: (Element) -> Identity
    
    @inlinable
    public init(
        _ base: Base,
        identityOf: @escaping (Element) -> Identity
    ) {
        self.base = base
        self.identityOf = identityOf
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(base: base, identityOf: identityOf)
    }
    
}

public extension LazyRemoveDuplicatesSequence {
    struct Iterator: IteratorProtocol {
        @usableFromInline var base: Base.Iterator
        @usableFromInline var unique: Set<Identity>
        @usableFromInline let identityOf: (Element) -> Identity
        
        @inlinable
        init(base: Base, identityOf: @escaping (Element) -> Identity) {
            self.base = base.makeIterator()
            self.identityOf = identityOf
            self.unique = Set(minimumCapacity: base.underestimatedCount)
        }
        
        @inlinable
        public mutating func next() -> Element? {
            
            while let next = base.next() {
                let identity = identityOf(next)
                guard unique.insert(identity).inserted else {
                    continue
                }
                return next
            }
            
            return nil
        }
    }
}
