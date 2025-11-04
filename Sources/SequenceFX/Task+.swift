//
//  Task+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 04.11.2025.
//

import Foundation
@_exported import class Combine.AnyCancellable

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

public extension Task {
    /// Returns an `AnyCancellable` that cancels this task when the cancellable is deinitialized
    /// or explicitly canceled.
    ///
    /// The returned cancellable simply calls `Task.cancel()` on this task.
    ///
    /// - Important:
    ///   - Canceling the `AnyCancellable` cancels the underlying task.
    ///   - The cancellable does not wait for task completion; it only triggers cancellation.
    ///   - You are responsible for retaining the cancellable for as long as you want the task
    ///     to be cancelable.
    ///
    /// - Returns: A type-erased cancellable bound to this task's `cancel()` action.
    @inlinable
    var asCancellable: AnyCancellable {
        AnyCancellable(self.cancel)
    }
    
    /// Stores this task’s `AnyCancellable` representation in the given array.
    ///
    /// This is a convenience for managing task cancellations with a collection of cancellables.
    ///
    /// - Parameter array: A mutable array of `AnyCancellable` in which the task’s cancellable
    ///   will be appended.
    ///
    /// - Note: The task will be canceled when an item referencing it in `array` is canceled
    ///   or deinitialized. Keep the array alive  for consistent lifetime management.
    @inlinable
    func store(in array: inout Array<AnyCancellable>) {
        array.append(self.asCancellable)
    }
    
    /// Stores this task’s `AnyCancellable` representation in the given set.
    ///
    /// Use this when you prefer a set for unique membership semantics. The set will retain the
    /// cancellable, and cancel the underlying task when the stored `AnyCancellable` is canceled
    /// or deinitialized.
    ///
    /// - Parameter set: A mutable set of `AnyCancellable` in which the task’s cancellable
    ///   will be inserted.
    ///
    /// - Important: `AnyCancellable` conforms to `Hashable`, but uniqueness is based on its identity.
    ///   Inserting multiple cancellables from different tasks will store them as distinct entries.
    @inlinable
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(self.asCancellable)
    }
}
