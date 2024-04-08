//
//  Consumer.swift
//
//
//  Created by Илья Шаповалов on 01.04.2024.
//

import Foundation

public final class Consumer<State> {
    private(set) var status: Status = .active
    private(set) var continuation: AsyncStream<State>.Continuation?
    
    public private(set) lazy var stream = AsyncStream<State> { continuation in
        self.continuation = continuation
    }
    
    public func invalidate() {
        self.status = .dead
    }
    
    public init() {}
}

//MARK: - Equatable
extension Consumer: Equatable {
    public static func == (lhs: Consumer, rhs: Consumer) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

//MARK: - Hashable
extension Consumer: Hashable {
    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}

extension Consumer {
    enum Status {
        case active
        case dead
    }
}
