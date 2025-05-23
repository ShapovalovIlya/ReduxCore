//
//  NotificationCenter.swift
//
//
//  Created by Илья Шаповалов on 15.05.2024.
//

@preconcurrency import Foundation

public extension NotificationCenter {
    
    /// Returns an asynchronous sequence of notifications produced by this center for a given notification name and optional source object.
    /// - Parameters:
    ///   - name: A notification name. The sequence includes only notifications with this name.
    ///   - object: A source object of notifications. Specify a sender object to deliver only notifications from that sender.
    ///   When nil, the notification center doesn’t consider the sender as a criteria for delivery.
    /// - Returns: An asynchronous sequence of notifications from the center.
    func stream(
        of name: Notification.Name,
        object: AnyObject? = nil
    ) -> NotificationCenter.Stream {
        Stream(self, name: name, object: object)
    }
}

public extension NotificationCenter {
    //MARK: - Stream
    /**
     An asynchronous sequence of notifications generated by a notification center.
     
     - Tip: The Notification type doesn’t conform to Sendable,
     so iterating over this asynchronous sequence produces a compiler warning.
     You can use a map(_:) or compactMap(_:) operator on the sequence to extract sendable properties of the notification
     and iterate over those instead.
     */
    final class Stream: AsyncSequence {
        public typealias Element = Notification
        
        //MARK: - Private properties
        private let center: NotificationCenter
        private let name: Notification.Name
        private let object: AnyObject?
        
        //MARK: - init(_:)
        init(
            _ center: NotificationCenter,
            name: Notification.Name,
            object: AnyObject?
        ) {
            self.center = center
            self.name = name
            self.object = object
        }
        
        //MARK: - internal methods
        @usableFromInline
        var notificationSequence: AsyncStream<Notification> {
            AsyncStream { continuation in
                let monitor = center.addObserver(forName: name, object: object, queue: .current) { notification in
                    continuation.yield(notification)
                }
                continuation.onTermination = { @Sendable _ in
                    self.center.removeObserver(monitor)
                }
            }
        }
        
        //MARK: - Public methods
        @inlinable
        public func makeAsyncIterator() -> Iterator {
            Iterator(notificationSequence.makeAsyncIterator())
        }
    }
    
}

public extension NotificationCenter.Stream {
    //MARK: - Iterator
    struct Iterator: AsyncIteratorProtocol {
        public typealias Element = Notification

        @usableFromInline var iterator: AsyncStream<Notification>.Iterator
        
        @usableFromInline
        init(_ iterator: AsyncStream<Notification>.Iterator) {
            self.iterator = iterator
        }
        
        /// Asynchronously advances to the next element and returns it, or ends the
        /// sequence if there is no next element.
        ///
        /// - Returns: The next element, if it exists, or `nil` to signal the end of
        ///   the sequence.
        public mutating func next() async -> Element? {
            while let element = await iterator.next() {
                if Task.isCancelled { return nil }
                return element
            }
            return nil
        }
    }
}
