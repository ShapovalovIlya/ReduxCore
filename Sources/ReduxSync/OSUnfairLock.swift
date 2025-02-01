//
//  OSUnfairLock.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 01.02.2025.
//

import Foundation
import os

/// Low-level lock that allows waiters to block efficiently on contention.
///
/// `OSUnfairLock` is an appropriate lock for cases where simple and lightweight mutual exclusion is needed.
/// It can be intrusively stored inline in a datastructure without needing a separate allocation,
/// reducing memory consumption and cost of indirection.
/// For situations where something more sophisticated like condition waits or FIFO ordering is needed,
/// use appropriate higher level APIs such as those from the pthread or dispatch subsystems.
///
/// This lock must be unlocked from the same thread that locked it,
/// attempts to unlock from a different thread will cause an assertion aborting the process.
///
/// This lock must not be accessed from multiple processes or threads via shared or multiply-mapped memory,
/// because the lock implementation relies on the address of the lock value and identity of the owning process.
///
/// The name ‘unfair’ indicates that there is no attempt at enforcing acquisition fairness,  e.g. an unlocker can potentially
/// immediately reacquire the lock before a woken up waiter gets an opportunity to attempt to acquire the lock.
/// This is often advantageous for performance reasons, but also makes starvation of waiters a possibility.
public final class  OSUnfairLock<State>: NSLocking, @unchecked Sendable {
    @usableFromInline let unfairLock: UnsafeMutablePointer<os_unfair_lock>
    @usableFromInline var state: State
    
    //MARK: - init(_:)
    @inlinable
    public init(initial state: State) {
        self.unfairLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.unfairLock.initialize(to: os_unfair_lock())
        self.state = state
    }
    
    @inlinable
    public convenience init() where State == Void {
        self.init(initial: ())
    }

    //MARK: - deinit
    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }
    
    //MARK: - Public methods
    @inlinable
    public var unsafe: State { state }
    
    /// Locks an `OSUnfairLock` if it is not already locked.
    ///
    /// It is invalid to surround this function with a retry loop, if this function returns false,
    /// the program must be able to proceed without having acquired the lock,
    /// or it must call `OSUnfairLock.lock()` directly (a retry loop around `OSUnfairLock.try()` amounts
    /// to an inefficient implementation of `OSUnfairLock.lock()` that hides the lock waiter from the system
    /// and prevents resolution of priority inversions).
    ///
    /// - Returns: Returns true if the lock was succesfully locked and false if the lock was already locked.
    @inlinable
    public func `try`() -> Bool {
        os_unfair_lock_trylock(unfairLock)
    }
    
    @inlinable
    public func lock() {
        os_unfair_lock_lock(unfairLock)
    }
    
    @inlinable
    public func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
    
    @inlinable
    @discardableResult
    public func withLock<R>(
        _ protected: (inout State) throws -> R
    ) rethrows -> R {
        try withLock { try protected(&state) }
    }
}
