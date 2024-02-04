//
//  DataDriven.swift
//
//
//  Created by Илья Шаповалов on 05.02.2024.
//

import Foundation

/// Protocol describe any action type
public protocol Action {}

/// Protocol describe any state type.
public protocol DataDriven {
    mutating func reduce(_ action: Action)
}
