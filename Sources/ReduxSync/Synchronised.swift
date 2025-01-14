//
//  Synchronised.swift
//  ReduxCore
//
//  Created by Шаповалов Илья on 21.10.2024.
//

import Foundation
import os

/// Обертка свойств для потоко-небезопастных объектов.
///
/// Решает проблемы синхронизации мутабельного состояния внутри `Sendable` объектов
/// и взаимодействия в конкурентном контексте.
///
///```swift
///
/// class SomeClass {
///     var counter = 0
/// }
///
/// struct Example: Sendable {
///     @Synchronised var someClass = SomeClass()
///
///    func foo() async {
///         someClass.counter += 1
///    }
/// }
///
///```
///
public struct Synchronised<State>: @unchecked Sendable {
    @usableFromInline var _state: State
    @usableFromInline let _lock: NSLocking
    
    //MARK: - init(_:)
    @inlinable
    public init(
        with lock: some NSLocking = NSLock(),
        state: State
    ) {
        self._state = state
        self._lock = lock
    }
    
    //MARK: - Public methods
    @inlinable public var unsafe: State { _state }
    
    @inlinable func lock() { _lock.lock() }
    @inlinable func unlock() { _lock.unlock() }
    
    @inlinable
    public mutating func withLock<R>(
        _ protected: @Sendable (inout State) throws -> R
    ) rethrows -> R {
        try _lock.withLock { try protected(&_state) }
    }
}

//MARK: - Equatable
extension Synchronised: Equatable where State: Equatable {
    @inlinable
    public static func == (lhs: Synchronised, rhs: Synchronised) -> Bool {
        lhs._state == rhs._state
    }
}

extension Synchronised: Hashable where State: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_state)
    }
}
