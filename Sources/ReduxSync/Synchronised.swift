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
@propertyWrapper
public struct Synchronised<State>: @unchecked Sendable {
    @usableFromInline var _state: State
    @usableFromInline let lock: NSLocking
    
    //MARK: - init(_:)
    @inlinable
    public init(
        wrappedValue: consuming State,
        with lock: some NSLocking = NSLock()
    ) {
        self._state = wrappedValue
        self.lock = lock
    }
    
    //MARK: - Public methods
    @inlinable
    public var wrappedValue: State {
        _read {
            lock.lock()
            defer { lock.unlock() }
            yield _state
        }
        _modify {
            lock.lock()
            defer { lock.unlock() }
            yield &_state
        }
    }
    
    @inlinable public var unsafe: State { _state }
    
    @inlinable
    public mutating func withLock<R>(
        _ protected: @Sendable (inout State) throws -> R
    ) rethrows -> R {
        try lock.withLock { try protected(&_state) }
    }
}

//MARK: - Equatable
extension Synchronised: Equatable where State: Equatable {
    @inlinable
    public static func == (lhs: Synchronised, rhs: Synchronised) -> Bool {
        lhs._state == rhs._state
        && ObjectIdentifier(lhs.lock) == ObjectIdentifier(rhs.lock)
    }
}

extension Synchronised: Hashable where State: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_state)
        hasher.combine(ObjectIdentifier(lock))
    }
}
