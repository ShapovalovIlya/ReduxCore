//
//  StateStreamer.swift
//
//
//  Created by Илья Шаповалов on 01.04.2024.
//

import Foundation

/// An asynchronous, thread-safe streamer for broadcasting state updates to multiple consumers.
///
/// `StateStreamer` is a generic class that provides an `AsyncStream`-based mechanism for emitting state values over time.
/// It is designed to be used in state management architectures, such as Redux-like stores, where you need to asynchronously
/// observe and react to state changes.
///
/// The streamer exposes both the `AsyncStream<State>` for consumption and its associated `Continuation`
/// for yielding new state values. It also conforms to `AsyncSequence`, allowing you to use it directly in
/// asynchronous for-await-in loops.
///
/// The buffering policy for the stream can be customized during initialization, enabling control over how many state values
/// are buffered if there are no active consumers at the time values are yielded.
///
/// When the `StateStreamer` is deinitialized or `finish()` is called, the stream is automatically finished, notifying all consumers of completion.
///
/// ### Key Features
/// - Asynchronous state streaming using `AsyncStream`
/// - Configurable buffering policy
/// - Automatic stream completion on deinitialization or manual finish
///
/// ### Usage:
/// ```swift
/// let streamer = StateStreamer<MyState>()
/// Task {
///     for await state in streamer {
///         print("Received state update: \(state)")
///     }
/// }
/// // To emit a new state:
/// streamer.yield(newState)
/// // To finish the stream:
/// streamer.finish()
/// ```
///
/// - Warning: Deprecated APIs (`isActive`, `activate()`, `invalidate()`) are retained for backward compatibility and should not be used in new code.
///
public final class StateStreamer<State>: @unchecked Sendable, AsyncSequence {
    public typealias AsyncIterator = AsyncStream<State>.Iterator
    
    private var _isActive = false
    
    //MARK: - Public properties
    
    /// The asynchronous stream of state updates emitted by the streamer.
    ///
    /// This property provides an `AsyncStream<State>` that consumers can iterate over to receive state updates
    /// as they are yielded by the streamer. Use this stream to asynchronously observe changes to the state over time,
    /// for example in a Swift Concurrency `Task` or an async context.
    ///
    /// - Note: The stream completes automatically when the `StateStreamer` is deinitialized or when `finish()` is called.
    /// - Important: Each value yielded to the stream represents a new state snapshot. Consumers should use `for await`
    ///   to process updates as they arrive.
    ///
    /// ### Example
    /// ```swift
    /// let streamer = StateStreamer<MyState>()
    /// Task {
    ///     for await state in streamer.state {
    ///         print("Received state update: \(state)")
    ///     }
    /// }
    /// streamer.continuation.yield(newState)
    /// ```
    ///
    public let state: AsyncStream<State>
    
    /// The continuation used to yield new state values to the asynchronous stream.
    ///
    /// This property provides an `AsyncStream<State>.Continuation` that allows you to emit new state values
    /// to all consumers of the `state` stream. Use the `yield(_:)` method on the continuation to send a new
    /// state update, or call `finish()` to complete the stream and notify all consumers of termination.
    ///
    /// - Note: The continuation is typically used by the owner of the `StateStreamer` to broadcast state changes.
    /// - Important: After calling `finish()`, no further values can be yielded to the stream.
    ///
    /// ### Example
    /// ```swift
    /// let streamer = StateStreamer<MyState>()
    /// streamer.continuation.yield(newState) // Emit a new state update
    /// streamer.continuation.finish()        // Complete the stream
    /// ```
    ///
    public let continuation: AsyncStream<State>.Continuation
        
    //MARK: - init(_:)
    
    /// Initializes a new ``StateStreamer`` instance with an optional buffering policy.
    ///
    /// This initializer creates an asynchronous stream and its associated continuation for broadcasting state updates.
    /// The buffering policy determines how many state values can be buffered if there are no active consumers at the time
    /// the values are yielded. By default, the buffering policy is set to `.unbounded`, allowing unlimited buffering.
    ///
    /// - Parameter buffering: The buffering policy for the stream. Defaults to `.unbounded`.
    ///
    /// ### Example
    /// ```swift
    /// // Create a streamer with the default unbounded buffering policy
    /// let streamer = StateStreamer<MyState>()
    ///
    /// // Create a streamer with a custom buffering policy
    /// let limitedStreamer = StateStreamer<MyState>(buffering: .bufferingOldest(10))
    /// ```
    ///
    /// - Note: The buffering policy can help control memory usage and backpressure in scenarios with slow or intermittent consumers.
    ///
    @inlinable
    public init(buffering: AsyncStream<State>.Continuation.BufferingPolicy = .unbounded) {
        (self.state, self.continuation) = AsyncStream.newStream(of: State.self, bufferingPolicy: buffering)
    }
    
    //MARK: - deinit
    deinit {
        continuation.finish()
    }
    
    //MARK: - Public methods
    
    /// Yields a new state value to all consumers of the asynchronous stream.
    ///
    /// This method emits the provided state value to the `state` stream, making it available to all active and future
    /// consumers. The result indicates whether the value was successfully enqueued, dropped, or if the stream has already
    /// been terminated.
    ///
    /// - Parameter state: The new state value to emit to the stream.
    /// - Returns: An `AsyncStream<State>.Continuation.YieldResult` indicating the outcome of the yield operation:
    ///   - `.enqueued`: The value was successfully enqueued for delivery to consumers.
    ///   - `.dropped`: The value was dropped due to buffering policy or lack of consumers.
    ///   - `.terminated`: The stream has already been finished and cannot accept new values.
    ///
    /// ### Example:
    /// ```swift
    /// let result = streamer.yield(newState)
    /// if result == .enqueued {
    ///     print("State update delivered to consumers.")
    /// }
    /// ```
    ///
    /// - Note: After the stream is finished (via `finish()` or deinitialization), further calls to `yield(_:)` will return `.terminated`.
    ///
    @inlinable
    @discardableResult
    public func yield(_ state: sending State) -> AsyncStream<State>.Continuation.YieldResult {
        continuation.yield(state)
    }
    
    /// Finishes the asynchronous state stream, signaling completion to all consumers.
    ///
    /// Calling this method transitions the stream into a terminal state, after which no additional state values
    /// will be emitted. All current and future consumers of the `state` stream will receive completion and
    /// iteration will end. Calling `finish()` more than once has no effect.
    ///
    /// - Note: This method is typically called when the streamer is no longer needed or is being deinitialized.
    /// - Note: If the streamer is used as a subscriber to a `Store`, calling `finish()` will also cause the store
    ///   to automatically remove the streamer from its list of subscribers, ensuring no further state updates are sent.
    /// - Important: After calling `finish()`, any further attempts to yield values to the stream will be ignored.
    ///
    /// ### Example
    /// ```swift
    /// streamer.finish() // Completes the stream and notifies all consumers
    /// ```
    ///
    @inlinable
    public func finish() {
        continuation.finish()
    }
    
    @inlinable
    public func makeAsyncIterator() -> AsyncIterator {
        state.makeAsyncIterator()
    }
}

//MARK: - Deprecated
public extension StateStreamer {
    @available(*, deprecated, message: "Doesn't used anymore")
    var isActive: Bool { _isActive }
    
    /// invalidate Streamer.
    ///
    /// When a Streamer is marked as invalidated Store removes it from subscribers
    /// and no longer notifies about the new state.
    @available(*, deprecated, message: "Doesn't used anymore")
    func invalidate() {
        _isActive = false
    }
    
    /// Activate Streamer.
    ///
    /// The Store activates the Streamer when you add it as a subscriber.
    /// It unnecessary to activate Streamer manually.
    @available(*, deprecated, message: "Doesn't used anymore")
    func activate() {
        _isActive = true
    }
    
}

//MARK: - Equatable
extension StateStreamer: Equatable {
    @inlinable
    public static func == (lhs: StateStreamer, rhs: StateStreamer) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

//MARK: - Hashable
extension StateStreamer: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
