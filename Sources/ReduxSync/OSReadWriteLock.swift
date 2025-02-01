//
//  OSReadWriteLock.swift
//  ReduxStream
//
//  Created by Илья Шаповалов on 29.12.2024.
//

import Foundation
import pthread

public final class OSReadWriteLock<State>: NSLocking, @unchecked Sendable {
    //MARK: - internal properties
    @usableFromInline let readWriteLock: UnsafeMutablePointer<pthread_rwlock_t>
    @usableFromInline var state: State
    
    //MARK: - init(_:)
    public init(initial: State) {
        self.state = initial
        self.readWriteLock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
        self.readWriteLock.initialize(to: pthread_rwlock_t())
        pthread_rwlock_init(readWriteLock, nil)
    }
    
    //MARK: - deinit
    deinit {
        pthread_rwlock_destroy(readWriteLock)
        readWriteLock.deinitialize(count: 1)
        readWriteLock.deallocate()
    }
    
    //MARK: - Public methods
    @inlinable
    public func unlock() {
        pthread_rwlock_unlock(readWriteLock)
    }
    
    @inlinable
    public func lock() {
        pthread_rwlock_wrlock(readWriteLock)
    }
}

public extension OSReadWriteLock {
    @inlinable
    var unsafe: State { state }
    
    @inlinable
    var identifier: ObjectIdentifier { ObjectIdentifier(self) }
    
    /// The function acquires a read lock on `OSReadWriteLock`,
    /// provided that rwlock is not presently held for writing and no writer threads are presently blocked on the lock.
    /// If the read lock cannot be immedi-ately immediately acquired, the calling thread blocks until it can acquire the lock.
    @inlinable
    func readLock() {
        pthread_rwlock_rdlock(readWriteLock)
    }
    
    @inlinable
    func `try`() -> Bool {
        pthread_rwlock_trywrlock(readWriteLock) == .zero
    }
    @inlinable
    func tryRead() -> Bool {
        pthread_rwlock_tryrdlock(readWriteLock) == .zero
    }
    
    @inlinable
    func withLock<R>(_ block: (inout State) throws -> R) rethrows -> R {
        try withLocking(lock, block: block)
    }
}

public extension OSReadWriteLock where State == Void {
    @inlinable
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
