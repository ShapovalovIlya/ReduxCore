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
    ) -> AsyncStream<Notification> {
        AsyncStream { continuation in
            let monitor = addObserver(forName: name, object: object, queue: nil) { notification in
                if Task.isCancelled {
                    continuation.finish()
                    return
                }
                continuation.yield(notification)
            }
            continuation.onTermination = { @Sendable _ in
                self.removeObserver(monitor)
            }
        }
    }
}
