//
//  DataDriven.swift
//
//
//  Created by Илья Шаповалов on 05.02.2024.
//

import Foundation

/// Protocol describe any action type
public protocol Action: Sendable, Hashable {}

public extension Action {
    func hash(into hasher: inout Hasher) {
        hasher.combine(String(reflecting: self))
    }
}

/// Protocol describe any state type.
public protocol DataDriven {
    mutating func reduce(_ action: some Action)
}
