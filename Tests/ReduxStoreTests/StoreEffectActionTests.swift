//
//  StoreEffectActionTests.swift
//
//
//  Created by Илья Шаповалов on 21.02.2026.
//

import Foundation
import Testing
import ReduxCore
import ReduxStream

/// Coverage for effect follow-up actions re-dispatched through the full
/// pipeline via the `ReduxEffect` run callback: chaining, per-dispatch
/// subscriber notifications, removeEffect semantics, and store lifetime.
struct StoreEffectActionTests {

    //MARK: - Re-dispatch through the full pipeline

    @Test func testActionEffectRedispatchesFollowUpAction() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect { (state: Int, action: Int, send: (Int) -> Void) in
            await recorder.record(state: state, action: action)
            guard action == 1 else { return }
            send(10)
        }

        sut.dispatch(1)

        // dispatch(1) reduces to 1; the effect re-dispatches 10 via the
        // callback, which reduces to 11.
        let reached = await waitUntil { sut.state == 11 }
        #expect(reached)
        #expect(sut.state == 11)

        // The effect receives the snapshot state and runs for every
        // reduced action (including the follow-up it produced).
        let states = await recorder.states
        let actions = await recorder.actions
        #expect(states == [1, 11])
        #expect(actions == [1, 10])
    }

    @Test func testFollowUpVisibleToSubscribers() async throws {
        let sut = makeSUT()
        let buffer = LockedTap()
        let driver = StateStreamer<Sut.Snapshot>()
        sut.install(driver)

        let collect = Task {
            for await snapshot in driver {
                buffer.record(snapshot.state)
            }
        }

        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            send(10)
        }

        sut.dispatch(1)

        // Subscribers observe the initial state, the dispatched action,
        // and the follow-up re-dispatch as separate notifications.
        let drained = await waitUntil { await buffer.values == [0, 1, 11] }
        #expect(drained)

        driver.continuation.finish()
        await collect.value
    }

    @Test func testFollowUpPassesThroughMiddleware() async throws {
        let sut = makeSUT()

        // Middleware appends an extra action when it sees the follow-up.
        sut.addMiddleware { _, action in
            if action == 10 { 100 }
        }
        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            send(10)
        }

        sut.dispatch(1)

        // dispatch(1) → 1; follow-up 10 → reducer adds 10, middleware
        // adds 100 → 1 + 10 + 100 = 111.
        let reached = await waitUntil { sut.state == 111 }
        #expect(reached)
        #expect(sut.state == 111)
    }

    @Test func testFollowUpBlockedByPermission() async throws {
        let sut = makeSUT()
        let tap = LockedTap()

        // Permission blocks the follow-up action 10.
        sut.addPermission { _, action in
            tap.record(action)
            return action != 10
        }
        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            send(10)
        }

        sut.dispatch(1)

        // Action 1 is checked twice (before and after middleware), the
        // follow-up 10 is checked once and dropped on the first gate.
        let gated = await waitUntil { tap.values == [1, 1, 10] }
        #expect(gated)
        #expect(sut.state == 1)
    }

    @Test func testEffectWithoutCallbackDispatchesNoFollowUp() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        sut.addEffect { (_: Int, action: Int, _: (Int) -> Void) in
            await recorder.record(action: action)
        }

        sut.dispatch(1)

        let effectRan = await waitUntil { await recorder.actions == [1] }
        #expect(effectRan)
        // An effect that never invokes the callback produces no follow-up:
        // state stays 1.
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(sut.state == 1)
        // The effect is never re-invoked for a follow-up that never arrives.
        #expect(await recorder.actions == [1])
    }

    //MARK: - Chaining / re-entrancy

    @Test func testEffectsChainFollowUps() async throws {
        let sut = makeSUT()

        // Effect A: 1 → 2. Effect B: 2 → 3. Re-dispatch chains both hops.
        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            send(2)
        }
        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 2 else { return }
            send(3)
        }

        sut.dispatch(1)

        // Chain terminates: effects ignore non-matching actions, so
        // no infinite loop. Final state = 1 + 2 + 3 = 6.
        let settled = await waitUntil { sut.state == 6 }
        #expect(settled)
        #expect(sut.state == 6)

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(sut.state == 6)
    }

    //MARK: - Per-dispatch notifications for multiple action effects

    @Test func testMultipleActionEffectsDispatchSeparately() async throws {
        let sut = makeSUT()
        let buffer = LockedTap()
        let driver = StateStreamer<Sut.Snapshot>()
        sut.install(driver)

        let collect = Task {
            for await snapshot in driver {
                buffer.record(snapshot.state)
            }
        }

        // Three effects with staggered delays. Each callback invocation is
        // its own dispatch; exact ordering of the follow-ups is not
        // asserted — only the deterministic guarantees below.
        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            try? await Task.sleep(nanoseconds: 30_000_000)
            send(10)
        }
        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
            send(20)
        }
        sut.addEffect { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
            send(30)
        }

        sut.dispatch(1)

        // All three follow-ups reduce: 1 + 10 + 20 + 30 = 61.
        let reached = await waitUntil { sut.state == 61 }
        #expect(reached)

        // One notification per reduction: install + dispatch(1) +
        // 3 follow-ups = 5 snapshots. Each follow-up is its own
        // dispatch, otherwise the count would be 4.
        let drained = await waitUntil { await buffer.values.count == 5 }
        #expect(drained)

        driver.continuation.finish()
        await collect.value

        let values = await buffer.values
        #expect(values.first == 0)
        #expect(values.last == 61)
        // Positive additions → every intermediate state strictly grows,
        // regardless of completion order.
        #expect(values == values.sorted())
    }

    //MARK: - removeEffect semantics

    @Test func testRemoveEffectDoesNotStopInFlightButBlocksFuture() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect { (_: Int, _: Int, _: (Int) -> Void) in
            await recorder.markStarted()
            try? await Task.sleep(nanoseconds: 100_000_000)
            await recorder.markFinished()
        }

        sut.dispatch(1)

        // Wait until the effect is actually in flight.
        let started = await waitUntil { await recorder.started == 1 }
        #expect(started)

        // Removal mid-flight does not cancel the running task.
        let removed = sut.removeEffect(withId: id)
        #expect(removed?.id == id)

        let finished = await waitUntil { await recorder.finished == 1 }
        #expect(finished)
        #expect(await recorder.started == 1)

        // A sentinel still-registered effect proves dispatch(2) was
        // processed; the removed effect must not run for it.
        sut.addEffect { (_: Int, action: Int, _: (Int) -> Void) in
            if action == 2 { await recorder.markSentinel() }
        }
        sut.dispatch(2)

        let sentinelRan = await waitUntil { await recorder.sentinel == 1 }
        #expect(sentinelRan)
        #expect(await recorder.started == 1)
        #expect(await recorder.finished == 1)
    }

    @Test func testRemoveEffectReturnsRemovedEffect() {
        let sut = makeSUT()

        let id = sut.addEffect(ReduxEffect { _, _, _ in () })
        #expect(sut.removeEffect(withId: id)?.id == id)
        #expect(sut.removeEffect(withId: id) == nil)
        #expect(sut.removeEffect(withId: UUID()) == nil)
    }

    //MARK: - Store lifetime

    @Test func testStoreDeallocatesWhileEffectInFlight() async throws {
        var sut: Store<Int, Int>? = Store(
            initial: 0,
            scheduler: AsyncSerialScheduler()
        ) { $0 += $1 }
        weak let weakSut = sut
        let recorder = Recorder()

        sut?.addEffect { (_: Int, _: Int, _: (Int) -> Void) in
            await recorder.markStarted()
            try? await Task.sleep(nanoseconds: 200_000_000)
            await recorder.markFinished()
        }

        sut?.dispatch(1)

        // Effect is in flight.
        let started = await waitUntil { await recorder.started == 1 }
        #expect(started)

        // Drop the only strong reference while the effect still runs.
        sut = nil

        // The in-flight effect completes without a crash...
        let completed = await waitUntil { await recorder.finished == 1 }
        #expect(completed)

        // ...and the store deallocates (no retain cycle, weak task capture).
        let deallocated = await waitUntil { weakSut == nil }
        #expect(deallocated)
    }

    @Test func testRemoveEffectSetsCancellationFlagOnInFlightTask() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect { (_: Int, _: Int, _: (Int) -> Void) in
            await recorder.markStarted()
            try? await Task.sleep(for: .milliseconds(100))
            await recorder.markFinished(wasCancelled: Task.isCancelled)
        }

        sut.dispatch(1)

        // Wait until the effect is actually in flight.
        let started = await waitUntil { await recorder.started == 1 }
        #expect(started)

        let removed = sut.removeEffect(withId: id)
        #expect(removed?.id == id)

        // The in-flight body runs to completion but observes the cooperative
        // cancellation flag that removal set on its task.
        let finished = await waitUntil { await recorder.finished == 1 }
        #expect(finished)
        #expect(await recorder.finishedWasCancelled == true)
    }

    @Test func testCancelledEffectCanStillDispatchFollowUp() async throws {
        let sut = makeSUT()

        // A switchToLatest effect that ignores its own cancellation still
        // dispatches: the follow-up flows through the full pipeline.
        sut.addEffect(ReduxEffect(policy: .switchToLatest) { (_: Int, action: Int, send: (Int) -> Void) in
            guard action == 1 else { return }
            try? await Task.sleep(for: .milliseconds(50))
            send(10)
        })

        sut.dispatch(contentsOf: [1, 2])

        // 1 + 2 (batch) + 10 (cancelled effect's follow-up) = 13.
        let reached = await waitUntil { sut.state == 13 }
        #expect(reached)
    }

}
