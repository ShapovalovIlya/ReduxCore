//
//  Throttle.swift
//  ReduxCore
//
//  Created by Шаповалов Илья on 07.04.2025.
//

import Foundation

public extension ReduxStream {
    
    /// An `AsyncSequence` that throttles the emission of elements from its base sequence.
    ///
    /// Use `Throttle` to ensure that elements are emitted no more frequently than the specified interval.
    /// This is useful for rate-limiting events, such as user input or network requests.
    ///
    /// Example:
    /// ```
    /// let throttled = ReduxStream.Throttle(base: someAsyncSequence, interval: 0.5)
    /// for await value in throttled {
    ///     // Handle value, emitted at most every 0.5 seconds
    /// }
    /// ```
    struct Throttle<Base: AsyncSequence>: AsyncSequence {
        /// The type of element produced by the throttled sequence.
        public typealias Element = Base.Element
        
        @usableFromInline let base: Base
        @usableFromInline let interval: TimeInterval
        
        /// Creates a throttled async sequence from a base sequence and interval.
        ///
        /// - Parameters:
        ///   - base: The base async sequence to throttle.
        ///   - interval: The minimum interval (in seconds) between emitted elements.
        @inlinable init(base: Base, interval: TimeInterval) {
            self.base = base
            self.interval = interval
        }
        
        /// Returns an iterator that produces elements from the throttled sequence.
        ///
        /// - Returns: An iterator that conforms to `AsyncIteratorProtocol`.
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(interval: interval, base: base.makeAsyncIterator())
        }
    }
}

public extension ReduxStream.Throttle {
    //MARK: - AsyncIteratorProtocol
    
    /// An iterator that produces elements from a throttled async sequence.
    struct Iterator: AsyncIteratorProtocol {
        @usableFromInline let interval: TimeInterval
        @usableFromInline var base: Base.AsyncIterator
        @usableFromInline var last: Date?
        
        //MARK: - init(_:)
        
        /// Creates a new iterator for the throttled sequence.
        ///
        /// - Parameters:
        ///   - interval: The minimum interval (in seconds) between emitted elements.
        ///   - base: The base async iterator.
        @inlinable
        init(interval: TimeInterval, base: Base.AsyncIterator) {
            self.interval = interval
            self.base = base
        }
        
        //MARK: - next
        
        /// Advances to the next element in the throttled sequence, waiting as needed to enforce the interval.
        ///
        /// - Returns: The next element, or `nil` if the sequence is finished.
        @inlinable
        public mutating func next() async rethrows -> Element? {
            var cached: Element?
            let start = last ?? Date()
            
            repeat {
                switch try await base.next() {
                case .none:
                    if let last, let amount = SleepAmount(last: last, interval: interval) {
                        try await Task.sleep(seconds: amount.seconds)
                        self.last = Date()
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
        
        /// Represents the amount of time to sleep to enforce the throttle interval.
        @usableFromInline
        struct SleepAmount {
            /// The number of seconds to sleep.
            @usableFromInline let seconds: TimeInterval
            
            /// Calculates the sleep amount needed to enforce the interval.
            ///
            /// - Parameters:
            ///   - last: The timestamp of the last emitted element.
            ///   - interval: The minimum interval between elements.
            ///
            /// - Returns: A `SleepAmount` if sleeping is needed, or `nil` if the interval has already passed.
            @inlinable
            init?(last: Date, interval: TimeInterval) {
                let elapsed = last.distance(to: Date())
                let amount = interval - elapsed
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
