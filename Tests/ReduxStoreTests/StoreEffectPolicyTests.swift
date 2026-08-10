//
//  StoreEffectPolicyTests.swift
//
//
//  Created by Илья Шаповалов on 10.08.2025.
//

import Foundation
import Testing
import ReduxCore

/// Coverage for `ReduxEffect` scheduling policies (`merge`, `concat`,
/// `switchToLatest`), per-reduced-action state snapshots, id-based
/// registration, and task-priority propagation.
struct StoreEffectPolicyTests {
    typealias Sut = Store<Int, Int>

    //MARK: - Policies

    @Test func testMergePolicyRunsInvocationsConcurrently() async throws {
        let sut = makeSUT()
        let recorder = Recorder()
        let gate = Gate()

        sut.addEffect(ReduxEffect(policy: .merge) { _, action, _ in
            await recorder.markStarted(action)
            await gate.wait()
            await recorder.markFinished(action)
        })

        sut.dispatch(contentsOf: [1, 2])
        await sut.scheduler.flush()

        // Both invocations start while the gate is closed: merge never
        // waits for or cancels a previous run.
        let bothStarted = await waitUntil { await recorder.started == 2 }
        #expect(bothStarted)
        #expect(await recorder.finished == 0)

        await gate.open()
        let bothFinished = await waitUntil { await recorder.finished == 2 }
        #expect(bothFinished)
    }

    @Test func testConcatPolicySerializesInvocations() async throws {
        let sut = makeSUT()
        let recorder = Recorder()
        let gate = Gate()

        sut.addEffect(ReduxEffect(policy: .concat) { _, action, _ in
            await recorder.markStarted(action)
            await gate.wait()
            await recorder.markFinished(action)
        })

        sut.dispatch(contentsOf: [1, 2])
        await sut.scheduler.flush()

        // The second invocation waits for the first: only the first run
        // has started while the gate is still closed.
        let firstStarted = await waitUntil { await recorder.started == 1 }
        #expect(firstStarted)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(await recorder.started == 1)
        #expect(await recorder.finished == 0)

        await gate.open()
        let bothDone = await waitUntil {
            let started = await recorder.started
            let finished = await recorder.finished
            return started == 2 && finished == 2
        }
        #expect(bothDone)
    }

    @Test func testSwitchToLatestCancelsPreviousInvocation() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect(ReduxEffect(policy: .switchToLatest) { _, action, _ in
            await recorder.markStarted(action)
            try? await Task.sleep(for: .milliseconds(200))
            await recorder.markFinished(action, wasCancelled: Task.isCancelled)
        })

        sut.dispatch(1)
        let firstStarted = await waitUntil { await recorder.started(for: 1) == 1 }
        #expect(firstStarted)

        sut.dispatch(2)
        let secondStarted = await waitUntil { await recorder.started(for: 2) == 1 }
        #expect(secondStarted)

        let settled = await waitUntil { await recorder.finished == 2 }
        #expect(settled)

        // The first run was cancelled by the second dispatch...
        #expect(await recorder.wasCancelled(action: 1) == true)
        // ...and the latest run completes without cancellation.
        #expect(await recorder.wasCancelled(action: 2) == false)
    }

    //MARK: - State snapshots

    @Test func testEffectReceivesStateSnapshotPerReducedAction() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect { state, action, _ in
            await recorder.record(state: state, action: action)
        }

        sut.dispatch(contentsOf: [1, 2])
        await sut.scheduler.flush()

        // Each reduced action triggers the effect with the intermediate
        // snapshot: state after 1 → 1, state after 2 → 3. The effect tasks
        // run concurrently and may not have recorded by the time flush()
        // returns, so wait for both invocations before comparing. The two
        // snapshots are recorded in completion order (nondeterministic),
        // hence the sorted comparison.
        let bothRan = await waitUntil { await recorder.actions.count == 2 }
        #expect(bothRan)

        let states = await recorder.states.sorted()
        let actions = await recorder.actions.sorted()
        #expect(states == [1, 3])
        #expect(actions == [1, 2])
    }

    //MARK: - Registration

    @Test func testAddEffectKeepsProvidedIdAndLastRegistrationWins() async throws {
        let sut = makeSUT()
        let recorder = Recorder()
        let id = UUID()

        sut.addEffect(ReduxEffect(id: id) { _, _, _ in
            await recorder.record(tag: "first")
        })
        sut.addEffect(ReduxEffect(id: id) { _, _, _ in
            await recorder.record(tag: "second")
        })

        sut.dispatch(1)
        let ran = await waitUntil { await recorder.tags == ["second"] }
        #expect(ran)

        // removeEffect returns the effect registered under the id.
        #expect(sut.removeEffect(withId: id)?.id == id)
        #expect(sut.removeEffect(withId: id) == nil)
    }

    //MARK: - Priority

    @Test func testEffectPriorityIsPropagatedToTask() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect(ReduxEffect(priority: .high) { _, _, _ in
            await recorder.record(priority: Task.currentPriority)
        })

        sut.dispatch(1)
        let ran = await waitUntil { await recorder.observedPriority != nil }
        #expect(ran)

        let priority = await recorder.observedPriority
        // The runtime may escalate priority under load, so assert the task
        // was never scheduled below the requested priority.
        #expect(priority == nil || priority! >= TaskPriority.high)
    }
}

private extension StoreEffectPolicyTests {
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}

//MARK: - Helpers

/// Suspends tasks that call `wait()` until `open()` resumes them.
private actor Gate {
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

/// Records invocations, state snapshots, cancellation and priority signals.
private actor Recorder {
    var states: [Int] = []
    var actions: [Int] = []
    var tags: [String] = []
    var started = 0
    var finished = 0
    var startedByAction: [Int: Int] = [:]
    var finishedByAction: [Int: Bool] = [:]
    var observedPriority: TaskPriority?

    func record(state: Int, action: Int) {
        states.append(state)
        actions.append(action)
    }

    func record(tag: String) { tags.append(tag) }

    func record(priority: TaskPriority) { observedPriority = priority }

    func markStarted(_ action: Int) {
        started += 1
        startedByAction[action, default: 0] += 1
    }

    func markFinished(_ action: Int, wasCancelled: Bool = false) {
        finished += 1
        finishedByAction[action] = wasCancelled
    }

    func started(for action: Int) -> Int { startedByAction[action] ?? 0 }

    func wasCancelled(action: Int) -> Bool? { finishedByAction[action] }
}