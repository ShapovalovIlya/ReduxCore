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

    @Test func testConcatPolicySerializesSeparateDispatches() async throws {
        let sut = makeSUT()
        let recorder = Recorder()
        let gate = Gate()

        sut.addEffect(ReduxEffect(policy: .concat) { _, action, _ in
            await recorder.markStarted(action)
            await gate.wait()
            await recorder.markFinished(action)
        })

        sut.dispatch(1)
        let firstStarted = await waitUntil { await recorder.started(for: 1) == 1 }
        #expect(firstStarted)

        // The second dispatch's invocation waits for the first: nothing
        // starts while the gate is still closed.
        sut.dispatch(2)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(await recorder.started(for: 2) == 0)

        await gate.open()
        let bothDone = await waitUntil { await recorder.finished == 2 }
        #expect(bothDone)
        #expect(await recorder.started(for: 1) == 1)
        #expect(await recorder.started(for: 2) == 1)
    }

    @Test func testSwitchToLatestCancelsPreviousWithinBatch() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect(ReduxEffect(policy: .switchToLatest) { _, action, _ in
            await recorder.markStarted(action)
            try? await Task.sleep(for: .milliseconds(100))
            await recorder.markFinished(action, wasCancelled: Task.isCancelled)
        })

        sut.dispatch(contentsOf: [1, 2])

        let settled = await waitUntil { await recorder.finished == 2 }
        #expect(settled)

        // The second action in the same batch cancels the first invocation.
        #expect(await recorder.started(for: 1) == 1)
        #expect(await recorder.started(for: 2) == 1)
        #expect(await recorder.wasCancelled(action: 1) == true)
        #expect(await recorder.wasCancelled(action: 2) == false)
    }

    @Test func testEffectLowPriorityNeverScheduledBelowRequested() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect(ReduxEffect(priority: .low) { _, _, _ in
            await recorder.record(priority: Task.currentPriority)
        })

        sut.dispatch(1)
        let ran = await waitUntil { await recorder.observedPriority != nil }
        #expect(ran)

        let priority = await recorder.observedPriority
        // The runtime may escalate a low-priority task under load, but it is
        // never scheduled below the requested priority.
        #expect(priority == nil || priority! >= TaskPriority.low)
    }

    @Test func testEffectDefaultPriorityInheritsSchedulerPriority() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect { _, _, _ in
            await recorder.record(priority: Task.currentPriority)
        }

        sut.dispatch(1)
        let ran = await waitUntil { await recorder.observedPriority != nil }
        #expect(ran)

        let priority = await recorder.observedPriority
        // Default priority inherits from the scheduler task (.userInitiated
        // for AsyncSerialScheduler); escalation is allowed, downgrade is not.
        #expect(priority == nil || priority! >= TaskPriority.userInitiated)
    }

}
