//
//  RemoveDuplicates.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//  Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncRemoveDuplicatesSequence.swift

public extension ReduxStream {
    //MARK: - RemoveDuplicates
    /// An asynchronous sequence that omits repeated elements by testing them with a predicate.
    struct RemoveDuplicates<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element
        public typealias Predicate = @Sendable (Element, Element) async -> Bool
        
        //MARK: - Properties
        @usableFromInline let base: Base
        @usableFromInline let predicate: Predicate
        
        //MARK: - init(_:)
        @inlinable init(
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

public extension ReduxStream.RemoveDuplicates {
    //MARK: - Iterator
    /// The iterator for an `RemoveDuplicates` instance.
    struct Iterator: AsyncIteratorProtocol {
        //MARK: - Properties
        @usableFromInline var iterator: Base.AsyncIterator
        @usableFromInline let predicate: Predicate
        @usableFromInline var last: Element?
        
        //MARK: - init(_:)
        @usableFromInline
        init(iterator: Base.AsyncIterator, predicate: @escaping Predicate) {
            self.iterator = iterator
            self.predicate = predicate
        }
        
        //MARK: - Public methods
        @inlinable
        public mutating func next() async rethrows -> Element? {
            guard let last else {
                last = try await iterator.next()
                if Task.isCancelled { return nil }
                return last
            }
            while let element = try await iterator.next() {
                if Task.isCancelled { return nil }
                if await predicate(last, element) { continue }
                self.last = element
                return element
            }
            return nil
        }
    }
}

extension ReduxStream.RemoveDuplicates: Sendable where Base: Sendable, Base.Element: Sendable { }

@available(*, unavailable)
extension ReduxStream.RemoveDuplicates.Iterator: Sendable { }
