//
//  OSReadWriteLock.swift
//  ReduxStream
//
//  Created by Илья Шаповалов on 29.12.2024.
//

import Foundation
import pthread

public final class OSReadWriteLock<State>: @unchecked Sendable, NSLocking {
    //MARK: - internal properties
    @usableFromInline var state: State
    @usableFromInline var rwLock = pthread_rwlock_t()
    
    //MARK: - init(_:)
    public init(initial: State) {
        self.state = initial
        pthread_rwlock_init(&rwLock, nil)
    }
    
    deinit { pthread_rwlock_destroy(&rwLock) }
    
    //MARK: - Public methods
    @inlinable
    public func unlock() {
        pthread_rwlock_unlock(&rwLock)
    }
    
    @inlinable
    public func lock() {
        pthread_rwlock_wrlock(&rwLock)
    }
}

public extension OSReadWriteLock {
    @inlinable
    var unsafe: State { state }
    
    @inlinable
    var identifier: ObjectIdentifier { ObjectIdentifier(self) }
    
    @inlinable
    func readLock() {
        pthread_rwlock_rdlock(&rwLock)
    }
    
    @inlinable
    func `try`() -> Bool {
        pthread_rwlock_trywrlock(&rwLock) == .zero
    }
    @inlinable
    func tryRead() -> Bool {
        pthread_rwlock_tryrdlock(&rwLock) == .zero
    }
    
    @inlinable
    func withLock<R>(_ block: (inout State) throws -> R) rethrows -> R {
        try withLocking(lock, block: block)
    }
}

public extension OSReadWriteLock where State == Void {
    convenience init() {
        self.init(initial: ())
        
    }
    
    @inlinable
    @discardableResult
    func read<R>(_ block: () throws -> R) rethrows -> R {
        try withLocking(readLock) { _ in try block() }
    }
    
    @inlinable
    @discardableResult
    func write<R>(_ block: () throws -> R) rethrows -> R {
        try withLocking(lock) { _ in try block() }
    }
}

extension OSReadWriteLock {
    @inlinable
    func withLocking<R>(
        _ lock: () -> Void,
        block: (inout State) throws -> R
    ) rethrows -> R {
        lock()
        defer { unlock() }
        return try block(&state)
    }
}

extension OSReadWriteLock: Equatable, Hashable where State: Hashable {
    @inlinable
    public static func == (lhs: OSReadWriteLock, rhs: OSReadWriteLock) -> Bool {
        lhs.state == rhs.state
        && lhs.identifier == rhs.identifier
    }
    
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(state)
        hasher.combine(identifier)
    }
}
