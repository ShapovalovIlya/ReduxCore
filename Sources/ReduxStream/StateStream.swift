//
//  StateStreamer.swift
//
//
//  Created by Илья Шаповалов on 01.04.2024.
//

import Foundation

public final class StateStreamer<State> {
    //MARK: - Public properties
    public let (state, continuation) = AsyncStream.makeStream(of: State.self)
    public private(set) var isActive = true
        
    //MARK: - init(_:)
    public init() {}
    deinit {
        continuation.finish()
    }
    
    //MARK: - Public methods
    public func invalidate() {
        isActive = false
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
