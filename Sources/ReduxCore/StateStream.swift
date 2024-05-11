//
//  StateStreamer.swift
//
//
//  Created by Илья Шаповалов on 01.04.2024.
//

import Foundation

public final class StateStreamer<State> {
    private(set) var isActive = true
    
    public let (state, continuation) = AsyncStream.makeStream(of: State.self)
    
    public func invalidate() {
        isActive = false
    }
    
    public init() {}
    deinit {
        continuation.finish()
    }
}

//MARK: - Equatable
extension StateStreamer: Equatable {
    public static func == (lhs: StateStreamer, rhs: StateStreamer) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

//MARK: - Hashable
extension StateStreamer: Hashable {
    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}
