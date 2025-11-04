//
//  Task+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 04.11.2025.
//

import Foundation

/// Errors for invalid sleep parameters.
public enum SleepError: Error, CustomStringConvertible, Equatable {
    case notFinite(TimeInterval)
    case isNaN(TimeInterval)
    case negative(TimeInterval)
    case overflow(TimeInterval)
    
    @inlinable
    public var description: String {
        switch self {
        case let .notFinite(v):
            return "Parameter must be a finite. Got \(v)."
        case let .isNaN(v):
            return "Parameter must not be NaN. Got \(v)"
        case let .negative(v):
            return "Parameter must be ≥ 0. Got \(v)."
        case let .overflow(v):
            return "Parameter is too large to represent as nanoseconds. Got \(v) seconds."
        }
    }
}

public extension Task where Success == Never, Failure == Never {
    
    /// Stops execution of `Task` for the specified time. Doesn't slow down the flow.
    ///
    /// The method checks the passed value for `isInfinite` and `isNaN`.
    /// If the passed value in `seconds <= 0`, then the function will exit immediately.
    ///
    /// - Parameter interval: the time for which the current `Task` should suspend its process.
    /// In seconds.
    @inlinable
    static func sleep(seconds: TimeInterval) async throws {
        if seconds.isEqual(to: .zero) {
            return
        }
        if seconds.isInfinite {
            throw SleepError.notFinite(seconds)
        }
        if seconds.isNaN {
            throw SleepError.isNaN(seconds)
        }
        
        if seconds.isLess(than: .zero) {
            throw SleepError.negative(seconds)
        }
        
        let nanosec = seconds * 1_000_000_000
        
        if nanosec.isInfinite || nanosec > Double(UInt64.max) {
            throw SleepError.overflow(seconds)
        }
        
        let fair = UInt64.init(nanosec.rounded(.toNearestOrAwayFromZero))
        
        try await sleep(nanoseconds: fair)
    }
}
