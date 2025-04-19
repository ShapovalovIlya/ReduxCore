//
//  LazyRemoveDuplicatesSequence.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 19.04.2025.
//

import Foundation

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
