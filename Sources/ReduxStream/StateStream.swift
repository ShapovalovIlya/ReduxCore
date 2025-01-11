//
//  StateStreamer.swift
//
//
//  Created by Илья Шаповалов on 01.04.2024.
//

import Foundation

public final class StateStreamer<State>: @unchecked Sendable, ObjectStreamer {
    private let lock = NSLock()
    private var _isActive = false
    
    //MARK: - Public properties
    public let (state, continuation) = AsyncStream.newStream(of: State.self)
    public var isActive: Bool { lock.withLock { _isActive } }
    
    //MARK: - init(_:)
    public init() {}
    
    //MARK: - deinit
    deinit { continuation.finish() }
    
    //MARK: - Public methods
    
    /// invalidate Streamer.
    ///
    /// When a Streamer is marked as invalidated Store removes it from subscribers
    /// and no longer notifies about the new state.
    public func invalidate() {
        lock.withLock { _isActive = false }
    }
    
    /// Activate Streamer.
    ///
    /// The Store activates the Streamer when you add it as a subscriber.
    /// It unnecessary to activate Streamer manually.
    public func activate() {
        lock.withLock { _isActive = true }
    }
}

//MARK: - Equatable
extension StateStreamer: Equatable {
    @inlinable
    public static func == (lhs: StateStreamer, rhs: StateStreamer) -> Bool {
        lhs.streamerID == rhs.streamerID
    }
}

//MARK: - Hashable
extension StateStreamer: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(streamerID)
    }
}
