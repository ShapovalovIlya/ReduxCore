//
//  StateStreamer.swift
//
//
//  Created by Илья Шаповалов on 01.04.2024.
//

import Foundation

public final class StateStreamer<State> {
    //MARK: - Public properties
    public let (state, continuation) = AsyncStream.newStream(of: State.self)
    public private(set) var isActive = true
        
    //MARK: - init(_:)
    public init() {}
    
    //MARK: - Public methods
    public func invalidate() {
        isActive = false
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
