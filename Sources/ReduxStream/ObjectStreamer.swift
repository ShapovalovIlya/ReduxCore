//
//  ObjectStreamer.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.01.2025.
//

import Foundation

public protocol ObjectStreamer: AnyObject {
    associatedtype State

    var streamerID: ObjectIdentifier { get }
    var continuation: AsyncStream<State>.Continuation { get }
}

public extension ObjectStreamer {
    var streamerID: ObjectIdentifier { ObjectIdentifier(self) }
}
