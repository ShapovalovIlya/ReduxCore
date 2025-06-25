//
//  WithUnretained.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.08.2024.
//

import Foundation

public extension ReduxStream {
    //MARK: - WithUnretained
    /// An asynchronous sequence that combine repeated elements with weakly retained Object.
    ///
    /// The sequence will be canceled when the upstream is canceled or the object is released.
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
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(iterator: base.makeAsyncIterator(), unretained: unretained)
        }
    }
}

public extension ReduxStream.WithUnretained {
    //MARK: - Iterator
    /// The iterator for an `WithUnretained` instance.
    ///
    /// The iterator's `next()` method return `nil` when parent `Task` is cancelled,
    /// upstream `iterator.next()` return `nil` or unretained `object` is released.
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
        @inlinable
        public mutating func next() async throws -> (Object, Base.Element)? {        
            while let element = try await iterator.next() {
                if Task.isCancelled { return nil }
                guard let unretained else { return nil }
                return (unretained, element)
            }
            return nil
        }
    }
}

extension ReduxStream.WithUnretained: Sendable where Base: Sendable,
                                                     Object: Sendable {}

@available(*, unavailable)
extension ReduxStream.WithUnretained.Iterator: Sendable {}
