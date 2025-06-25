//
//  Throttle.swift
//  ReduxCore
//
//  Created by Шаповалов Илья on 07.04.2025.
//

import Foundation

public extension ReduxStream {
    
    struct Throttle<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element
        
        @usableFromInline let base: Base
        @usableFromInline let interval: TimeInterval
        
        @inlinable init(base: Base, interval: TimeInterval) {
            self.base = base
            self.interval = interval
        }
        
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(interval: interval, base: base.makeAsyncIterator())
        }
    }
}

public extension ReduxStream.Throttle {
    //MARK: - AsyncIteratorProtocol
    struct Iterator: AsyncIteratorProtocol {
        @usableFromInline let interval: TimeInterval
        @usableFromInline var base: Base.AsyncIterator
        @usableFromInline var last: Date?
        
        //MARK: - init(_:)
        @inlinable
        init(interval: TimeInterval, base: Base.AsyncIterator) {
            self.interval = interval
            self.base = base
        }
        
        //MARK: - next
        @inlinable
        public mutating func next() async rethrows -> Element? {
            var cached: Element?
            let start = last ?? Date()
            
            repeat {
                switch try await base.next() {
                case .none:
                    if let last, let amount = SleepAmount(last: last, interval: interval) {
                        try await Task.sleep(seconds: amount.seconds)
                    }
                    return cached
                    
                case let .some(next):
                    let now = Date()
                    if start.distance(to: now) >= interval || last == nil {
                        last = now
                        return next
                    }
                    cached = next
                }
            } while true
        }
        
        //MARK: - SleepAmount
        @usableFromInline
        struct SleepAmount {
            @usableFromInline let seconds: TimeInterval
            
            @inlinable
            init?(last: Date, interval: TimeInterval) {
                let amount = interval - last.distance(to: Date())
                guard amount > .zero else {
                    return nil
                }
                self.seconds = amount
            }
        }
    }
}

extension ReduxStream.Throttle: Sendable where Base: Sendable, Element: Sendable {}

@available(*, unavailable)
extension ReduxStream.Throttle.Iterator: Sendable {}
