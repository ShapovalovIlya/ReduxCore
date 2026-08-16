//
//  StoreEffectActionTests.swift
//
//
//  Created by Илья Шаповалов on 21.02.2026.
//

import Foundation
import Testing
@testable import ReduxCore

/// Coverage for effect follow-up actions re-dispatched through the full
/// pipeline via the `ReduxEffect` run callback: chaining, per-dispatch
/// subscriber notifications, removeEffect semantics, and store lifetime.
struct StoreEffectActionTests {

    @Test func testFollowUpVisibleToSubscribers() async {
        let sut = makeSUT()
        let driver = StateStreamer<Sut.Snapshot>()
        sut.install(driver)

        let task = Task {
            await driver.reduce(into: [Int]()) {
                $0.append($1.state)
            }
        }

        let id = sut.addEffect { _, action, send in
            guard action == 1 else { return }
            send(10)
        }

        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value
        await sut.scheduler.flush()
        driver.continuation.finish()

        let collected = await task.value
        #expect(collected == [0, 1, 11])

    }

    @Test func testFollowUpPassesThroughMiddleware() async {
        let sut = makeSUT()

        // Middleware appends an extra action when it sees the follow-up.
        sut.addMiddleware { _, action in
            if action == 10 { 100 }
        }
        let id = sut.addEffect { _, action, send in
            guard action == 1 else { return }
            send(10)
        }

        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value
        await sut.scheduler.flush()

        // dispatch(1) → 1; follow-up 10 → reducer adds 10, middleware
        // adds 100 → 1 + 10 + 100 = 111.
        #expect(sut.state == 111)
    }

    @Test func testFollowUpBlockedByPermission() async {
        let sut = makeSUT()
        var tap = [Int]()

        // Permission blocks the follow-up action 10.
        sut.addPermission { _, action in
            tap.append(action)
            return action != 10
        }
        let id = sut.addEffect { _, action, send in
            guard action == 1 else { return }
            send(10)
        }

        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value
        await sut.scheduler.flush()

        // Action 1 is checked twice (before and after middleware), the
        // follow-up 10 is checked once and dropped on the first gate.
        #expect(tap == [1, 1, 10])
        #expect(sut.state == 1)
    }

    @Test func testEffectWithoutCallbackDispatchesNoFollowUp() async {
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect { _, action, _ in
            await recorder.record(action: action)
        }

        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value
        await sut.scheduler.flush()

        #expect(sut.state == 1)
        #expect(await recorder.actions == [1])
    }

    //MARK: - Chaining / re-entrancy

    @Test func testEffectsChainFollowUps() async {
        let sut = makeSUT()

        // Effect A: 1 → 2. Effect B: 2 → 3. Re-dispatch chains both hops.
        let id1 = sut.addEffect { _, action, send in
            guard action == 1 else { return }
            send(2)
        }
        let id2 = sut.addEffect { _, action, send in
            guard action == 2 else { return }
            send(3)
        }

        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id1]?.value
        await sut.scheduler.flush()
        await sut.runningEffects[id2]?.value
        await sut.scheduler.flush()

        // Chain terminates: effects ignore non-matching actions, so
        // no infinite loop. Final state = 1 + 2 + 3 = 6.
        #expect(sut.state == 6)
    }

    //MARK: - Store lifetime

    @Test func testStoreDeallocatesWhileEffectInFlight() async throws {
        var sut: Store<Int, Int>? = Store(
            initial: 0,
            scheduler: AsyncSerialScheduler()
        ) { $0 += $1 }
        weak let weakSut = sut
        let recorder = Recorder()

        let id = try #require(sut?.addEffect { _,_,_ in
            await recorder.markStarted()
            try? await Task.sleep(nanoseconds: 200_000_000)
            await recorder.markFinished()
        })

        sut?.dispatch(1)
        await sut?.scheduler.flush()

        // Effect is in flight.
        #expect(await recorder.started == 1)
        let task = try #require(sut?.runningEffects[id])

        // Drop the only strong reference while the effect still runs.
        sut = nil

        // The in-flight effect completes without a crash...
        await task.value
        #expect(await recorder.finished == 1)

        // ...and the store deallocates (no retain cycle, weak task capture).
        #expect(weakSut == nil)
    }

    @Test func testRemoveEffectSetsCancellationFlagOnInFlightTask() async throws {
        let sut = makeSUT()
        let recorder = Recorder()

        let id = sut.addEffect { _,_,_ in
            await recorder.markStarted()
            try? await Task.sleep(for: .milliseconds(100))
            await recorder.markFinished(wasCancelled: Task.isCancelled)
        }

        sut.dispatch(1)
        await sut.scheduler.flush()

        // Wait until the effect is actually in flight.
        #expect(await recorder.started == 1)

        let task = try #require(sut.runningEffects[id])
        sut.removeEffect(withId: id)
        await sut.scheduler.flush()

        // The in-flight body runs to completion but observes the cooperative
        // cancellation flag that removal set on its task.
        await task.value
        #expect(await recorder.finished == 1)
        #expect(await recorder.finishedWasCancelled == true)
    }

}


