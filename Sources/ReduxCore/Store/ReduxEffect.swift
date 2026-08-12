//
//  ReduxEffect.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 12.08.2026.
//

import Foundation

/// An async side-effect handler that runs after each action is reduced.
///
/// Effects observe the updated state and the action that caused the change,
/// then perform asynchronous work such as network requests, database writes,
/// or analytics. Effects can dispatch follow-up actions back into the store
/// via the provided callback, enabling multi-step action pipelines.
///
/// Effects are registered with the store via ``Store/addEffect(_:)`` and
/// identified by a unique `UUID`. Each effect has a scheduling ``Policy``
/// that determines how concurrent invocations are handled.
///
/// ### Discussion:
/// Effects run after the reducer has mutated the state. They receive the
/// post-reduction state snapshot, the triggering action, and a dispatch
/// callback for follow-up actions. All effects are launched as async tasks
/// managed by the store's internal registry.
///
/// ### Example:
/// ```swift
/// let effect = ReduxEffect<AppState, AppAction> { state, action, dispatch in
///     if case .fetchData = action {
///         let result = await api.fetchData()
///         dispatch(.dataReceived(result))
///     }
/// }
/// store.addEffect(effect)
/// ```
public struct ReduxEffect<S,A>: Sendable {
    /// Determines how a new invocation of an effect is scheduled when a
    /// previous invocation is still running.
    ///
    /// The policy is evaluated each time an action triggers the effect.
    /// If no previous task exists, or the previous task was already cancelled,
    /// the effect runs immediately regardless of policy.
    ///
    /// ### Cases
    /// - ``merge``: Run concurrently with any in-flight invocation.
    /// - ``concat``: Wait for the previous task to finish, then run.
    /// - ``switchToLatest``: Cancel the previous task and run immediately.
    public enum Policy: Sendable {
        /// Run the new invocation concurrently with any in-flight task.
        ///
        /// The previous task continues running in the background and is not
        /// cancelled. Both invocations execute in parallel, which is suitable
        /// for fire-and-forget effects like analytics or logging.
        case merge

        /// Wait for the previous task to finish before running the new invocation.
        ///
        /// Creates a sequential queue of effect invocations. Use this when the
        /// order of execution matters and you want every invocation to complete.
        case concat

        /// Cancel the previous task and run the new invocation immediately.
        ///
        /// The previous task is cancelled via its `Task.isCancelled` flag.
        /// Your effect should check for cancellation in long-running loops
        /// to respond promptly. Use this for search-as-you-type or any
        /// scenario where only the latest result matters.
        case switchToLatest
    }

    public let id: UUID
    public let priority: TaskPriority?
    public let policy: Policy
    public let run: @Sendable (S, A, (A) -> Void) async -> Void

    /// Creates a new effect with the specified identifier, priority, scheduling policy, and execution closure.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the effect. Defaults to a new `UUID()`.
    ///     Use this to later remove the effect via ``Store/removeEffect(withId:)``.
    ///   - priority: The `TaskPriority` for the async task. Defaults to `nil`,
    ///     which inherits the priority of the calling context.
    ///   - policy: How to handle new invocations when a previous one is still
    ///     running. Defaults to ``Policy/merge``.
    ///   - run: An async closure that receives the updated state, the triggering
    ///     action, and a dispatch callback. Call the callback to dispatch
    ///     follow-up actions back into the store.
    ///
    /// ### Example:
    /// ```swift
    /// let effect = ReduxEffect<AppState, AppAction>(
    ///     id: UUID(),
    ///     priority: .userInitiated,
    ///     policy: .switchToLatest
    /// ) { state, action, dispatch in
    ///     if case .fetchData = action {
    ///         let result = await api.fetch()
    ///         dispatch(.dataReceived(result))
    ///     }
    /// }
    /// ```
    public init(
        id: UUID = UUID(),
        priority: TaskPriority? = nil,
        policy: Policy = .merge,
        run: @escaping @Sendable (S, A, (A) -> Void) async -> Void
    ) {
        self.id = id
        self.priority = priority
        self.policy = policy
        self.run = run
    }
}
