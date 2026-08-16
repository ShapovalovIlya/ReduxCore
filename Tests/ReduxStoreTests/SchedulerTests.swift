//
//  SchedulerTests.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 26.07.2026.
//

import Testing
import ReduxCore

extension Int: @retroactive Action {}

struct SchedulerTests {

    // MARK: - Helpers

    private func makeSUT(priority: TaskPriority = .userInitiated) -> AsyncSerialScheduler {
        AsyncSerialScheduler(priority: priority)
    }

    // MARK: - Serial execution: sync work

    @Test func serialExecutionOfSyncWork() async throws {
        let sut = makeSUT()
        let accumulator = Recorder()

        for index in 1...5 {
            sut.schedule {
                await accumulator.record(action: index)
            }
        }

        await sut.flush()

        #expect(await accumulator.actions == [1, 2, 3, 4, 5])
    }

    // MARK: - Serial execution: async work

    @Test func serialExecutionOfAsyncWork() async throws {
        let sut = makeSUT()
        let accumulator = Recorder()

        for index in 1...5 {
            sut.schedule {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 100_000...1_000_000))
                await accumulator.record(action: index)
            }
        }

        await sut.flush()

        #expect(await accumulator.actions == [1, 2, 3, 4, 5])
    }

    // MARK: - Mixed sync and async work

    @Test func serialExecutionOfMixedWork() async throws {
        let sut = makeSUT()
        let accumulator = Recorder()

        sut.schedule {
            await accumulator.record(action: 1)
        }
        sut.schedule {
            try? await Task.sleep(nanoseconds: 500_000)
            await accumulator.record(action: 2)
        }
        sut.schedule {
            await accumulator.record(action: 3)
        }
        sut.schedule {
            try? await Task.sleep(nanoseconds: 100_000)
            await accumulator.record(action: 4)
        }
        sut.schedule {
            await accumulator.record(action: 5)
        }

        await sut.flush()

        #expect(await accumulator.actions == [1, 2, 3, 4, 5])
    }

    // MARK: - Multiple threads

    @Test func serialExecutionFromMultipleThreads() async throws {
        let sut = makeSUT()
        let accumulator = Recorder()

        await withTaskGroup(of: Void.self) { group in
            for index in 1...20 {
                group.addTask {
                    sut.schedule {
                        await accumulator.record(action: index)
                    }
                }
            }
            await group.waitForAll()
        }

        await sut.flush()

        let values = await accumulator.actions
        #expect(values.count == 20)
        #expect(Set(values) == Set(1...20))
    }

    // MARK: - Flush behavior

    @Test func flushWaitsForAllScheduledWork() async throws {
        let sut = makeSUT()
        let step = Recorder()

        sut.schedule {
            await step.record(action: 1)
        }
        sut.schedule {
            try? await Task.sleep(nanoseconds: 200_000)
            await step.record(action: 2)
        }
        sut.schedule {
            await step.record(action: 3)
        }

        await sut.flush()

        #expect(await step.actions == [1, 2, 3])
    }

    @Test func multipleFlushCallsInSequence() async throws {
        let sut = makeSUT()
        let step = Recorder()

        sut.schedule {
            await step.record(action: 1)
        }
        sut.schedule {
            await step.record(action: 2)
        }
        await sut.flush()
        #expect(await step.actions == [1, 2])

        sut.schedule {
            await step.record(action: 3)
        }
        sut.schedule {
            await step.record(action: 4)
        }
        await sut.flush()
        #expect(await step.actions == [1, 2, 3, 4])
    }

    // MARK: - Store integration

    @Test func storeIntegrationWithSerialScheduler() async throws {
        let scheduler = makeSUT(priority: .userInitiated)
        let store = Store<[Int], Int>(
            initial: [],
            scheduler: scheduler,
            reducer: { $0.append($1) }
        )

        store.dispatch(contentsOf: [1, 2, 3, 4, 5])

        await scheduler.flush()

        #expect(store.state == [1, 2, 3, 4, 5])
    }

    @Test func storeIntegrationWithConcurrentDispatches() async throws {
        let scheduler = makeSUT(priority: .high)
        let store = Store<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reducer: { $0 += $1 }
        )

        await withTaskGroup(of: Void.self) { group in
            for _ in 1...50 {
                group.addTask { store.dispatch(1) }
            }
            await group.waitForAll()
        }

        await scheduler.flush()

        #expect(store.state == 50)
    }

    @Test func storeIntegrationWithFlush() async throws {
        let scheduler = makeSUT()
        let store = Store<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reducer: { $0 += $1 }
        )

        store.dispatch(3)
        store.dispatch(5)
        store.dispatch(2)

        await scheduler.flush()

        #expect(store.state == 10)
    }

    @Test func storeIntegrationWithMultipleFlushes() async throws {
        let scheduler = makeSUT()
        let store = Store<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reducer: { $0 += $1 }
        )

        store.dispatch(1)
        store.dispatch(2)
        await scheduler.flush()
        #expect(store.state == 3)

        store.dispatch(3)
        store.dispatch(4)
        await scheduler.flush()
        #expect(store.state == 10)
    }

    // MARK: - Deinit

    @Test func deinitDoesNotCrash() async throws {
        var scheduler: AsyncSerialScheduler? = AsyncSerialScheduler()
        weak let weakRef = scheduler

        scheduler?.schedule {
            try? await Task.sleep(nanoseconds: 100_000)
        }

        scheduler = nil

        let deallocated = await waitUntil(timeout: .milliseconds(500)) { weakRef == nil }
        #expect(deallocated)
    }
}

