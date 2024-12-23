//
//  Syncronized.swift
//  ReduxCore
//
//  Created by Шаповалов Илья on 21.10.2024.
//

import Foundation

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
///     @Syncronized var someClass = SomeClass()
///
///    func foo() async {
///         someClass.counter += 1
///    }
/// }
///
///```
///
/// Синхронизация идет с помощью `NSRecursiveLock` и безопасна для использвания в рекурсивных вызовах.
@propertyWrapper
public struct Syncronized<Wrapped>: @unchecked Sendable {
    @usableFromInline var _wrapped: Wrapped
    @usableFromInline let lock = NSRecursiveLock()
    
    //MARK: - init(_:)
    @inlinable
    public init(wrappedValue: Wrapped) { self._wrapped = wrappedValue }
    
    //MARK: - Public methods
    @inlinable
    public var wrappedValue: Wrapped {
        get { lock.withLock { _wrapped } }
        set { lock.withLock { _wrapped = newValue } }
    }
    
    @inlinable
    @discardableResult
    public mutating func sync<R>(
        _ body: (inout Wrapped) throws -> R
    ) rethrows -> R {
        try lock.withLock { try body(&_wrapped) }
    }
}

//MARK: - Equatable
extension Syncronized: Equatable where Wrapped: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._wrapped == rhs._wrapped
    }
}

//MARK: - Comparable
extension Syncronized: Comparable where Wrapped: Comparable {
    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs._wrapped < rhs._wrapped
    }
}

extension Syncronized: Hashable where Wrapped: Hashable {}
