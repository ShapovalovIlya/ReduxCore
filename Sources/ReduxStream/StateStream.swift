//
//  StateStreamer.swift
//
//
//  Created by Илья Шаповалов on 01.04.2024.
//

import Foundation

public final class StateStreamer<State>: @unchecked Sendable {
    private let lock = RWLock()
    private var _isActive = false
    
    //MARK: - Public properties
    public let (state, continuation) = AsyncStream.newStream(of: State.self)
    public var isActive: Bool { lock.read { _isActive } }
    
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
        lock.write { _isActive = false }
    }
    
    /// Activate Streamer.
    ///
    /// The Store activates the Streamer when you add it as a subscriber.
    /// It unnecessary to activate Streamer manually.
    public func activate() {
        lock.write { _isActive = true }
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
        ObjectIdentifier(self).hash(into: &hasher)
    }
}
