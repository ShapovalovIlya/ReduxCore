//
//  SchedulerTests.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 26.07.2026.
//

import Testing
import ReduxCore

struct SchedulerTests {

    // MARK: - Helpers

    private func makeSUT(priority: TaskPriority = .userInitiated) -> AsyncSerialScheduler {
        AsyncSerialScheduler(priority: priority)
    }

    // MARK: - Serial execution: sync work

    @Test func serialExecutionOfSyncWork() async throws {
        let sut = makeSUT()
        let accumulator = Accumulator()

        for index in 1...5 {
            sut.schedule { accumulator.append(index) }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            sut.schedule { continuation.resume() }
        }

        #expect(accumulator.values == [1, 2, 3, 4, 5])
    }

    // MARK: - Serial execution: async work

    @Test func serialExecutionOfAsyncWork() async throws {
        let sut = makeSUT()
        let accumulator = Accumulator()

        for index in 1...5 {
            sut.schedule {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 100_000...1_000_000))
                accumulator.append(index)
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            sut.schedule { continuation.resume() }
        }

        #expect(accumulator.values == [1, 2, 3, 4, 5])
    }

    // MARK: - Mixed sync and async work

    @Test func serialExecutionOfMixedWork() async throws {
        let sut = makeSUT()
        let accumulator = Accumulator()

        sut.schedule { accumulator.append(1) }
        sut.schedule {
            try? await Task.sleep(nanoseconds: 500_000)
            accumulator.append(2)
        }
        sut.schedule { accumulator.append(3) }
        sut.schedule {
            try? await Task.sleep(nanoseconds: 100_000)
            accumulator.append(4)
        }
        sut.schedule { accumulator.append(5) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            sut.schedule { continuation.resume() }
        }

        #expect(accumulator.values == [1, 2, 3, 4, 5])
    }

    // MARK: - Multiple threads

    @Test func serialExecutionFromMultipleThreads() async throws {
        let sut = makeSUT()
        let accumulator = Accumulator()

        await withTaskGroup(of: Void.self) { group in
            for index in 1...20 {
                group.addTask {
                    sut.schedule { accumulator.append(index) }
                }
            }
            await group.waitForAll()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            sut.schedule { continuation.resume() }
        }

        #expect(accumulator.values.count == 20)
        #expect(Set(accumulator.values) == Set(1...20))
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

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            scheduler.schedule { continuation.resume() }
        }

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

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            scheduler.schedule { continuation.resume() }
        }

        #expect(store.state == 50)
    }

    // MARK: - Deinit

    @Test func deinitDoesNotCrash() async throws {
        var scheduler: AsyncSerialScheduler? = AsyncSerialScheduler()
        weak let weakRef = scheduler

        scheduler?.schedule {
            try? await Task.sleep(nanoseconds: 100_000)
        }

        scheduler = nil

        try await Task.sleep(nanoseconds: 500_000)

        #expect(weakRef == nil)
    }
}

// MARK: - Helpers

private extension SchedulerTests {

    /// Thread-safe accumulator for collecting ordered values across concurrent boundaries.
    final class Accumulator: @unchecked Sendable {
        private(set) var values: [Int] = []

        func append(_ value: Int) {
            values.append(value)
        }
    }

    /// Simple mutable box for boolean state.
    final class MutableBox<T>: @unchecked Sendable {
        var value: T
        init(_ value: T) { self.value = value }
        func set(_ newValue: T) { value = newValue }
    }
}
