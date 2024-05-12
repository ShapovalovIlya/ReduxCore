//
//  ThrowingRemoveDuplicates.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//  Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncRemoveDuplicatesSequence.swift

import Foundation

public extension ReduxStream {
    //MARK: - ThrowingRemoveDuplicates
    /// An asynchronous sequence that omits repeated elements by testing them with an error-throwing predicate.
    struct ThrowingRemoveDuplicates<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element
        public typealias Predicate = @Sendable (Element, Element) async throws -> Bool
        
        //MARK: - Properties
        @usableFromInline let base: Base
        @usableFromInline let predicate: Predicate
        
        //MARK: - init(_:)
        init(
            _ base: Base,
            predicate: @escaping Predicate
        ) {
            self.base = base
            self.predicate = predicate
        }
        
        //MARK: - Public methods
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(iterator: base.makeAsyncIterator(), predicate: predicate)
        }
    }
}

extension ReduxStream.ThrowingRemoveDuplicates {
    //MARK: - Iterator
    /// The iterator for an `ThrowingRemoveDuplicates` instance.
    public struct Iterator: AsyncIteratorProtocol {
        //MARK: - Properties
        @usableFromInline var iterator: Base.AsyncIterator
        @usableFromInline let predicate: Predicate
        @usableFromInline var last: Element?
        
        //MARK: - init(:)
        @usableFromInline
        init(
            iterator: Base.AsyncIterator,
            predicate: @escaping Predicate
        ) {
            self.iterator = iterator
            self.predicate = predicate
        }
        
        //MARK: - Public methods
        @inlinable
        public mutating func next() async throws -> Element? {
            guard let last else {
                last = try await iterator.next()
                return last
            }
            while let element = try await iterator.next() {
                if try await !predicate(last, element) {
                    self.last = element
                    return element
                }
            }
            return nil
        }
    }
}

extension ReduxStream.ThrowingRemoveDuplicates: Sendable where Base: Sendable, Base.Element: Sendable { }

@available(*, unavailable)
extension ReduxStream.ThrowingRemoveDuplicates.Iterator: Sendable { }
