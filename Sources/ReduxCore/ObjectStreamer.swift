//
//  ObjectStreamer.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.01.2025.
//

import Foundation

public protocol ObjectStreamer<State>: AnyObject, Sendable, Hashable {
    associatedtype State
    typealias Stream = AsyncStream<State>

    var streamerID: ObjectIdentifier { get }
    var continuation: Stream.Continuation { get }
    static func makeStateStream(
        _ policy: Stream.Continuation.BufferingPolicy
    ) -> (stream: Stream, continuation: Stream.Continuation)

}

public extension ObjectStreamer {
    var streamerID: ObjectIdentifier { ObjectIdentifier(self) }
    
    @inlinable
    static func makeStateStream(
        _ policy: Stream.Continuation.BufferingPolicy = .unbounded
    ) -> (stream: Stream, continuation: Stream.Continuation) {
        AsyncStream.makeStream(of: State.self, bufferingPolicy: policy)
    }
    
    @inlinable
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.streamerID == rhs.streamerID
    }
    
    @inlinable
    func hash(into hasher: inout Hasher) {
        hasher.combine(streamerID)
    }
}
