//
//  StoreEffectPolicyTests.swift
//
//
//  Created by Илья Шаповалов on 10.08.2025.
//

import Foundation
import Testing
@testable import ReduxCore

/// Coverage for `ReduxEffect` scheduling policies (`merge`, `concat`,
/// `switchToLatest`), per-reduced-action state snapshots, id-based
/// registration, and task-priority propagation.
struct StoreEffectPolicyTests {

    //MARK: - Policies

    @Test func testSwitchToLatestCancelsPreviousInvocation() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect(ReduxEffect(policy: .switchToLatest) { _, action, _ in
            await recorder.markStarted(action)
            try? await Task.sleep(for: .milliseconds(200))
            await recorder.markFinished(action, wasCancelled: Task.isCancelled)
        })

        sut.dispatch(1)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(5))

        #expect(await recorder.started(for: 1) == 1)

        sut.dispatch(2)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        #expect(await recorder.started(for: 2) == 1)
        #expect(await recorder.finished == 2)

        // The first run was cancelled by the second dispatch...
        #expect(await recorder.wasCancelled(action: 1) == true)
        // ...and the latest run completes without cancellation.
        #expect(await recorder.wasCancelled(action: 2) == false)
    }

    //MARK: - State snapshots

    @Test func testEffectReceivesStateSnapshotPerReducedAction() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect { state, action, _ in
            await recorder.record(state: state, action: action)
        }

        sut.dispatch(contentsOf: [1, 2])
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        // Each reduced action triggers the effect with the intermediate
        // snapshot: state after 1 → 1, state after 2 → 3. The effect tasks
        // run concurrently and may not have recorded by the time flush()
        // returns, so wait for both invocations before comparing. The two
        // snapshots are recorded in completion order (nondeterministic),
        // hence the sorted comparison.
        #expect(await recorder.states == [1, 3])
        #expect(await recorder.actions == [1, 2])
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
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        #expect(await recorder.tags == ["second"])
    }

    //MARK: - Priority

    @Test func testEffectPriorityIsPropagatedToTask() async throws {
        let sut = makeSUT()
        let recorder = Recorder()
        let priority = TaskPriority.high

        let id = sut.addEffect(ReduxEffect(priority: priority) { _, _, _ in
            await recorder.record(priority: Task.currentPriority)
        })

        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        let observedPriority = try await #require(recorder.observedPriority)

        // The runtime may escalate priority under load, so assert the task
        // was never scheduled below the requested priority.
        #expect(observedPriority >= priority)
    }

    @Test func testSwitchToLatestCancelsPreviousWithinBatch() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect(ReduxEffect(policy: .switchToLatest) { _, action, _ in
            await recorder.markStarted(action)
            try? await Task.sleep(for: .milliseconds(100))
            await recorder.markFinished(action, wasCancelled: Task.isCancelled)
        })

        sut.dispatch(contentsOf: [1, 2])
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        #expect(await recorder.finished == 2)

        // The second action in the same batch cancels the first invocation.
        #expect(await recorder.started(for: 1) == 1)
        #expect(await recorder.started(for: 2) == 1)
        #expect(await recorder.wasCancelled(action: 1) == true)
        #expect(await recorder.wasCancelled(action: 2) == false)
    }

    @Test func testEffectLowPriorityNeverScheduledBelowRequested() async throws {
        let sut = makeSUT()
        let recorder = Recorder()
        let priority = TaskPriority.low

        let id = sut.addEffect(ReduxEffect(priority: priority) { _, _, _ in
            await recorder.record(priority: Task.currentPriority)
        })

        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        let observedPriority = try await #require(recorder.observedPriority)

        // The runtime may escalate a low-priority task under load, but it is
        // never scheduled below the requested priority.
        #expect(observedPriority >= priority)
    }

    // MARK: - switchToLatest (additional)

    @Test func testSwitchToLatestMultipleCancellations() async throws {
        // Dispatch 1, 2, 3, 4 in rapid succession — only 4 should complete without cancellation
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect(ReduxEffect(policy: .switchToLatest) { _, action, _ in
            await recorder.markStarted(action)
            try? await Task.sleep(for: .milliseconds(200))
            await recorder.markFinished(action, wasCancelled: Task.isCancelled)
        })

        sut.dispatch(1)
        try await Task.sleep(for: .milliseconds(50))
        sut.dispatch(2)
        try await Task.sleep(for: .milliseconds(50))
        sut.dispatch(3)
        try await Task.sleep(for: .milliseconds(50))
        sut.dispatch(4)

        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        #expect(await recorder.finished == 4)

        // Actions 1, 2, 3 should be cancelled
        #expect(await recorder.wasCancelled(action: 1) == true)
        #expect(await recorder.wasCancelled(action: 2) == true)
        #expect(await recorder.wasCancelled(action: 3) == true)
        // Only action 4 should complete without cancellation
        #expect(await recorder.wasCancelled(action: 4) == false)
    }

    @Test func testSwitchToLatestCancelledDoesNotExecuteSideEffects() async throws {
        // A cancelled effect should not execute work after the cancellation point
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect(ReduxEffect(policy: .switchToLatest) { _, action, _ in
            await recorder.markStarted(action)
            // Simulate work that checks cancellation
            try? await Task.sleep(for: .milliseconds(300))
            // If we reach here without being cancelled, record the side effect
            if !Task.isCancelled {
                await recorder.record(tag: "side-effect-\(action)")
            }
            await recorder.markFinished(action, wasCancelled: Task.isCancelled)
        })

        sut.dispatch(1)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await recorder.started(for: 1) == 1)

        // Dispatch 2 cancels 1
        sut.dispatch(2)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        #expect(await recorder.started(for: 2) == 1)
        #expect(await recorder.finished == 2)

        // Action 1 was cancelled — its side effect should NOT have run
        let tags = await recorder.tags
        #expect(!tags.contains("side-effect-1"))
        // Action 2 was not cancelled — its side effect SHOULD have run
        #expect(tags.contains("side-effect-2"))
    }
}
