//
//  OSUnfairLock.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 01.02.2025.
//

import Foundation
import os

/// Wrapper for low-level `os_unfair_lock` that allows waiters to block efficiently on contention.
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
/// The name ‘unfair’ indicates that there is no attempt at enforcing acquisition fairness, e.g. an unlocker can potentially
/// immediately reacquire the lock before a woken up waiter gets an opportunity to attempt to acquire the lock.
/// This is often advantageous for performance reasons, but also makes starvation of waiters a possibility.
///
/// - Warning: `OSUnfairLock` isn’t a recursive lock. Attempting to lock an object more than once from
///             the same thread without unlocking in between, triggers a runtime exception.
public final class OSUnfairLock<State>: NSLocking, @unchecked Sendable {
    @usableFromInline let pointer: UnsafeMutablePointer<os_unfair_lock>
    @usableFromInline var state: State
    
    //MARK: - init(_:)
    @inlinable
    public init(initial state: State) {
        self.pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.pointer.initialize(to: os_unfair_lock())
        self.state = state
    }
    
    @inlinable
    public convenience init() where State == Void {
        self.init(initial: ())
    }
    
    //MARK: - deinit
    deinit {
        pointer.deinitialize(count: 1)
        pointer.deallocate()
    }
    
    //MARK: - NSLocking
    /// Locks an `OSUnfairLock`.
    @inlinable
    public func lock() {
        os_unfair_lock_lock(pointer)
    }
    
    @available(*, unavailable)
    @inlinable
    public func lock(_ flags: Flags) {
//        os_unfair_lock_lock_with_flags(pointer, <#T##flags: __os_unfair_lock_flags_t##__os_unfair_lock_flags_t#>)
    }
    
    /// Unlocks an `OSUnfairLock`.
    @inlinable
    public func unlock() {
        os_unfair_lock_unlock(pointer)
    }
}

public extension OSUnfairLock {
    //MARK: - Public methods
    @inlinable
    var unsafe: State { state }
    
    /// Asserts if the lock object fails to meet specified ownership requirements.
    /// - Parameter precondition: expected ownership status.
    ///
    /// If an `OSUnfairLock` fails to assert precondition, this function and terminates the process.
    @inlinable
    func assert(_ precondition: Ownership) {
        switch precondition {
        case .owner: os_unfair_lock_assert_owner(pointer)
        case .notOwner: os_unfair_lock_assert_not_owner(pointer)
        }
    }
    
    /// Locks an `OSUnfairLock` if it is not already locked.
    ///
    /// It is invalid to surround this function with a retry loop, if this function returns false,
    /// the program must be able to proceed without having acquired the lock,
    /// or it must call `OSUnfairLock.lock()` directly (a retry loop around `OSUnfairLock.trylock()` amounts
    /// to an inefficient implementation of `OSUnfairLock.lock()` that hides the lock waiter from the system
    /// and prevents resolution of priority inversions).
    ///
    /// - Returns: Returns true if the lock was succesfully locked and false if the lock was already locked.
    @inlinable
    func lockIfAvailable() -> Bool {
        os_unfair_lock_trylock(pointer)
    }
    
    /// Protect critical section with lock.
    /// - Parameter block: block of code
    @inlinable
    @discardableResult
    func withLock<R>(_ block: () throws -> R) rethrows -> R {
        assert(.notOwner)
        lock()
        defer {
            assert(.owner)
            unlock()
        }
        return try block()
    }
    
    /// Protect critical section with lock.
    /// - Parameter protected: block of code
    @inlinable
    @discardableResult
    func withLock<R>(_ protected: (inout State) throws -> R) rethrows -> R {
        try withLock { try protected(&state) }
    }
    
    @inlinable
    @discardableResult
    func withLockIfAvailable<R>(_ block: () throws -> R) rethrows -> R? {
        guard lockIfAvailable() else {
            return nil
        }
        assert(.owner)
        defer  {
            unlock()
            assert(.notOwner)
        }
        return try block()
    }
}

//MARK: - Ownership, Flags
public extension OSUnfairLock {
    /// Represents the ownership status of an unfair lock.
    enum Ownership { case owner, notOwner }
    
    struct Flags: OptionSet {
        public var rawValue: UInt32
        
        @inlinable
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        
    }
}
