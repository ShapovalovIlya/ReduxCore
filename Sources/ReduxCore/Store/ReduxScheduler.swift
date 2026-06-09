//
//  ReduxScheduler.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 10.06.2026.
//

import Foundation

/// A protocol that abstracts work scheduling to enable deterministic behavior in different environments.
///
/// Use `ReduxScheduler` to decouple your Redux store from specific dispatch queues or threads.
/// This abstraction is critical for testing, allowing you to swap asynchronous production queues
/// with synchronous or controlled execution pipelines in your test suite.
///
/// ### Thread Safety
/// Implementations must ensure that work blocks are executed in accordance with the architectural
/// guarantees of the store (e.g., preserving serial execution order for actions).
public protocol ReduxScheduler {
    
    /// Schedules a block of work for execution.
    ///
    /// - Parameter work: The closure containing the operations to be executed.
    func schedule(_ work: @escaping () -> Void)
}

extension DispatchQueue: ReduxScheduler {
    
    /// The default dedicated serial queue used for state mutations and action processing.
    ///
    /// This queue is configured with highly aggressive performance traits suited for predictable UI updates:
    /// - **QoS (`.userInteractive`)**: Ensures that state reductions are prioritized alongside animations and user input.
    /// - **Autorelease Frequency (`.workItem`)**: Cleans up temporary allocations immediately after each reduced action, preventing memory spikes.
    /// - **Target Queue (`.global`)**: Relies on the global system thread pool to optimize OS resource allocation.
    ///
    /// ### Usage
    /// ```swift
    /// let store = ReduxStore(
    ///     initialState: AppState(),
    ///     scheduler: DispatchQueue.storeScheduler
    /// )
    /// ```
    public static let storeScheduler = DispatchQueue(
        label: "com.reduxCore.StoreQueue",
        qos: .userInteractive,
        autoreleaseFrequency: .workItem,
        target: .global(qos: .userInteractive)
    )
}
