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
    init(initial: State) {
        self.state = initial
        pthread_rwlock_init(&rwLock, nil)
    }
    
    deinit { pthread_rwlock_destroy(&rwLock) }
    
    //MARK: - Public methods
    @inlinable public var unsafe: State { state }
    
    @inlinable public var identifier: ObjectIdentifier {
        ObjectIdentifier(self)
    }
    
    @inlinable public func unlock() { pthread_rwlock_unlock(&rwLock) }
    @inlinable public func lock() { pthread_rwlock_wrlock(&rwLock) }
    @inlinable public func readLock() { pthread_rwlock_rdlock(&rwLock) }
    
    @inlinable public func `try`() -> Bool {
        pthread_rwlock_trywrlock(&rwLock) == .zero
    }
    @inlinable public func tryRead() -> Bool {
        pthread_rwlock_tryrdlock(&rwLock) == .zero
    }
}

extension OSReadWriteLock where State == Void {
    convenience init() {
        self.init(initial: ())
        
    }
    
    @inlinable
    @discardableResult
    func read<R>(_ block: () throws -> R) rethrows -> R {
        try withLocking(readLock, block: block)
    }
    
    @inlinable
    @discardableResult
    func write<R>(_ block: () throws -> R) rethrows -> R {
        try withLocking(lock, block: block)
    }
}

extension OSReadWriteLock {
    @inlinable
    func withLocking<R>(
        _ lock: () -> Void,
        block: () throws -> R
    ) rethrows -> R {
        lock()
        defer { unlock() }
        return try block()
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
