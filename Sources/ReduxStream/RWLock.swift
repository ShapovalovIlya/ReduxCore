//
//  RWLock.swift
//  ReduxStream
//
//  Created by Илья Шаповалов on 29.12.2024.
//

import pthread

@usableFromInline
final class RWLock: @unchecked Sendable {
    private lazy var identifier = ObjectIdentifier(self)
    
    @usableFromInline var lock = pthread_rwlock_t()
    
    init() { pthread_rwlock_init(&lock, nil) }
    deinit { pthread_rwlock_destroy(&lock) }
    
    @inlinable func unlock() { pthread_rwlock_unlock(&lock) }
    
    @inlinable func readLock() { pthread_rwlock_rdlock(&lock) }
    
    @inlinable func writeLock() { pthread_rwlock_wrlock(&lock) }
    
    @inlinable
    func withLocking<R>(
        _ lock: () -> Void,
        block: () throws -> R
    ) rethrows -> R {
        lock()
        defer { unlock() }
        return try block()
    }
    
    @inlinable
    @discardableResult
    func read<R>(_ block: () throws -> R) rethrows -> R {
        try withLocking(readLock, block: block)
    }
    
    @inlinable
    @discardableResult
    func write<R>(_ block: () throws -> R) rethrows -> R {
        try withLocking(writeLock, block: block)
    }
}

extension RWLock: Equatable, Hashable {
    @usableFromInline
    static func == (lhs: RWLock, rhs: RWLock) -> Bool {
        lhs.identifier == rhs.identifier
    }
    
    @usableFromInline
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
