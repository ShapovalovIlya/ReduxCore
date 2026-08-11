//
//  TestHelpers.swift
//
//
//  Shared helpers for the ReduxStore test target: the standard SUT factory,
//  thread-safe collectors, async gates, invocation recorders and a polling
//  utility.
//

import Foundation
@testable import ReduxCore

/// Alias for the store configuration used across ReduxStore test suites.
typealias Sut = Store<Int, Int>

/// Default store for most ReduxStore tests: an accumulating reducer so tests
/// can assert on `state` directly.
func makeSUT() -> Sut {
    Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
}

/// Thread-safe collector usable from synchronous permission gates and
/// middleware closures.
final class LockedTap: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [Int] = []

    func record(_ value: Int) {
        lock.lock()
        defer { lock.unlock() }
        _values.append(value)
    }

    var values: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }
}

/// Suspends tasks that call `wait()` until `open()` resumes them.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

/// Records invocations, state snapshots, cancellation and priority signals
/// across async boundaries. Optional arguments let one recorder serve both
/// per-action counting (`markStarted(action)`) and aggregate counting
/// (`markStarted()`), and both labelled (`record(state:action:)`) and
/// action-only (`record(action:)`) observations.
actor Recorder {
    var states: [Int] = []
    var actions: [Int] = []
    var tags: [String] = []
    var started = 0
    var finished = 0
    var finishedWasCancelled: Bool?
    var sentinel = 0
    var startedByAction: [Int: Int] = [:]
    var finishedByAction: [Int: Bool] = [:]
    var observedPriority: TaskPriority?

    func record(state: Int? = nil, action: Int) {
        if let state { states.append(state) }
        actions.append(action)
    }

    func record(tag: String) { tags.append(tag) }

    func record(priority: TaskPriority) { observedPriority = priority }

    func markStarted(_ action: Int? = nil) {
        started += 1
        if let action { startedByAction[action, default: 0] += 1 }
    }

    func markFinished(_ action: Int? = nil, wasCancelled: Bool = false) {
        finished += 1
        if let action {
            finishedByAction[action] = wasCancelled
        } else {
            finishedWasCancelled = wasCancelled
        }
    }

    func markSentinel() { sentinel += 1 }

    func started(for action: Int) -> Int { startedByAction[action] ?? 0 }

    func wasCancelled(action: Int) -> Bool? { finishedByAction[action] }
}

/// Polls `condition` until it returns true or the deadline expires.
func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return await condition()
}
