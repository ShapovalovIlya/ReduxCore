//
//  DataDriven.swift
//
//
//  Created by Илья Шаповалов on 05.02.2024.
//

import Foundation

//MARK: - Action

/// Protocol describe any action type
public protocol Action: Sendable, Hashable {
    
    /// Dumps `Action` underlaying type contents.
    ///
    /// Default implementation use `dump(_:name:indent:maxDepth:maxItems:)` function  from Swift standard library.
    ///
    /// - Parameters:
    ///   - maxDepth: The maximum depth to descend when writing the contents of a value that has nested components.
    ///   - maxItems: The maximum number of elements for which to write the full contents.
    /// - Returns: The instance of underlaying type.
    @discardableResult
    func dumped(maxDepth: Int, maxItems: Int) -> Self
}

public extension Action {
    func hash(into hasher: inout Hasher) {
        hasher.combine(String(reflecting: self))
    }
    
    @inlinable
    @discardableResult
    func dumped(maxDepth: Int = .max, maxItems: Int = .max) -> Self {
        dump(self, name: "Action", maxDepth: maxDepth, maxItems: maxItems)
    }
}

//MARK: - DataDriven

/// Protocol describe any state type.
public protocol DataDriven {
    
    mutating func reduce(_ action: some Action)
    
    /// Dumps `DataDriven` underlaying type contents.
    ///
    /// Default implementation use `dump(_:name:indent:maxDepth:maxItems:)` function  from Swift standard library.
    ///
    /// - Parameters:
    ///   - maxDepth: The maximum depth to descend when writing the contents of a value that has nested components.
    ///   - maxItems: The maximum number of elements for which to write the full contents.
    /// - Returns: The instance of underlaying type.
    @discardableResult
    func dumped(maxDepth: Int, maxItems: Int) -> Self
}

public extension DataDriven {
    
    @inlinable
    @discardableResult
    func dumped(maxDepth: Int = .max, maxItems: Int = .max) -> Self {
        dump(self, name: "DataDriven", maxDepth: maxDepth, maxItems: maxItems)
    }
}
