//
//  Task+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 04.11.2025.
//

import Foundation

/// Errors thrown by `Task.sleep(seconds:)` for invalid parameters.
///
/// These cases provide descriptive messages via `CustomStringConvertible`
/// and are equatable for testing.
///
/// - Note: All cases include the offending `TimeInterval` value for context.
public enum SleepError: Error, CustomStringConvertible, Equatable {
    /// The provided value is not finite (e.g., `+∞` or `-∞`).
    case notFinite(TimeInterval)
    
    /// The provided value is `NaN`.
    case isNaN(TimeInterval)
    
    /// The provided value is negative.
    case negative(TimeInterval)
    
    /// The provided value is too large to represent as nanoseconds.
    /// Typically occurs when `seconds * 1_000_000_000` exceeds `UInt64.max`
    /// or becomes infinite.
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
    
    /// Suspends the current task for the specified duration in seconds.
    ///
    /// This is a convenience wrapper around `Task.sleep(nanoseconds:)` that
    /// validates and converts a `TimeInterval` (seconds) to nanoseconds.
    ///
    /// - Behavior:
    ///   - If `seconds == 0`, the function returns immediately without suspension.
    ///   - Rounding uses `.toNearestOrAwayFromZero` to map fractional seconds to the nearest nanosecond in a stable way.
    ///
    /// - Parameter seconds: The duration to sleep, expressed in seconds.
    ///
    /// - Throws: A `SleepError` when the provided `seconds` is invalid.
    ///
    /// - Important: Suspension duration is approximate and subject to system scheduling.
    ///   The task may resume slightly later than requested due to timer resolution,
    ///   runtime behavior, or cooperative scheduling.
    ///
    /// - SeeAlso: `Task.sleep(nanoseconds:)`
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
