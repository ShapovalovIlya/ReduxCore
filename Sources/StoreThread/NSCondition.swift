//
//  NSCondition.swift
//
//
//  Created by Илья Шаповалов on 13.05.2024.
//

import Foundation

extension NSCondition {
    
    /// Protect critical section of code from being executed simultaneously by separate threads.
    /// - Parameter block: A block of code that should be protected
    @inlinable
    @discardableResult
    func protect<R>(_ block: () throws -> R) rethrows -> R {
        lock()
        defer {
            signal()
            unlock()
        }
        return try block()
    }
}
