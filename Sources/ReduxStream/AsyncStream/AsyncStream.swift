//
//  AsyncStream.swift
//  
//
//  Created by Шаповалов Илья on 13.05.2024.
//  Source: https://github.com/apple/swift-evolution/blob/main/proposals/0377-parameter-ownership-modifiers.md

import Foundation

public extension AsyncStream {
    /// Initializes a new ``AsyncStream`` and an ``AsyncStream/Continuation``.
    ///
    /// - Parameters:
    ///   - elementType: The element type of the stream.
    ///   - bufferingPolicy: The buffering policy that the stream should use.
    /// - Returns: A tuple containing the stream and its continuation. The continuation should be passed to the
    /// producer while the stream should be passed to the consumer.
    @inlinable
    static func newStream(
        of elementType: Element.Type = Element.self,
        bufferingPolicy: Continuation.BufferingPolicy = .unbounded
    ) -> (stream: AsyncStream<Element>, continuation: AsyncStream<Element>.Continuation) {
        var continuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream(
            elementType,
            bufferingPolicy: bufferingPolicy,
            { continuation = $0 }
        )
        return (stream, continuation)
    }
}

public extension AsyncThrowingStream {
    /// Initializes a new ``AsyncThrowingStream`` and an ``AsyncThrowingStream/Continuation``.
    ///
    /// - Parameters:
    ///   - elementType: The element type of the stream.
    ///   - failureType: The failure type of the stream.
    ///   - bufferingPolicy: The buffering policy that the stream should use.
    /// - Returns: A tuple containing the stream and its continuation. The continuation should be passed to the
    /// producer while the stream should be passed to the consumer.
    @inlinable
    static func newStream(
        of elementType: Element.Type = Element.self,
        throwing failureType: Failure.Type = Failure.self,
        bufferingPolicy: Continuation.BufferingPolicy = .unbounded
    ) -> (stream: AsyncThrowingStream<Element, Failure>, continuation: AsyncThrowingStream<Element, Failure>.Continuation) where Failure == Error {
        var continuation: AsyncThrowingStream<Element, Failure>.Continuation!
        let stream = AsyncThrowingStream<Element, Failure>(
            elementType,
            bufferingPolicy: bufferingPolicy,
            { continuation = $0 }
        )
        return (stream, continuation!)
    }
}
