//
//  StoreHistoryTests.swift
//

import Testing
@testable import ReduxCore

//struct StoreHistoryTests {
//    typealias Sut = Store<Int, Int>
//
//    func makeSUT() -> Sut {
//        Store(initial: 0, historyCapacity: 10) { $0 += $1 }
//    }
//
//    // MARK: - Basic recording
//
//    @Test func historyRecordsInitialState() async {
//        let sut = makeSUT()
//        let history = sut.history()
//
//        let task = Task {
//            var states: [HistoryEntryOf<Sut>] = []
//            for await entry in history {
//                states.append(entry)
//                break
//            }
//            return states
//        }
//
//        sut.dispatch(1)
//        await sut.scheduler.flush()
//
//        let records = await task.value
//        task.cancel()
//
//        #expect(records == [HistoryEntry(action: 1, state: 1)])
//    }
//
//    @Test func historyRecordsEachDispatchedAction() async {
//        let sut = makeSUT()
//        let history = sut.history()
//
//        let task = Task {
//            var states = [Int]()
//            for await entry in history {
//                states.append(entry.state)
//                if states.count == 3 { break }
//            }
//            return states
//        }
//
//        sut.dispatch(1)
//        sut.dispatch(2)
//        sut.dispatch(3)
//        await sut.scheduler.flush()
//
//        let states = await task.value
//        task.cancel()
//
//        #expect(states == [1, 3, 6])
//    }
//
//    // MARK: - historyRecord(suffix:)
//
//    @Test func historyRecord_returnsAllEntries_whenSuffixLarge() async {
//        let sut = makeSUT()
//        sut.dispatch(1)
//        sut.dispatch(2)
//        sut.dispatch(3)
//        await sut.scheduler.flush()
//
//        let records = await sut.historyRecord(suffix: 100)
//        #expect(records.map(\.state) == [1, 3, 6])
//    }
//
//    @Test func historyRecord_respectsSuffix() async {
//        let sut = makeSUT()
//        sut.dispatch(1)  // state: 1
//        sut.dispatch(2)  // state: 3
//        sut.dispatch(3)  // state: 6
//        sut.dispatch(4)  // state: 10
//        await sut.scheduler.flush()
//
//        let records = await sut.historyRecord(suffix: 2)
//        #expect(records.map(\.state) == [6, 10])
//    }
//
//    @Test func historyRecord_empty_whenNoHistoryCapacity() {
//        let sut = Store(initial: 0, historyCapacity: 0) { $0 += $1 }
//        sut.dispatch(1)
//        // No flush needed — historyRecorder.push is a no-op when capacity == 0
//        // and historyRecord is synchronous via scheduler
//
//        // historyRecord needs async, but with capacity 0 push is skipped immediately
//        // so entries stay empty regardless
//    }
//
//    // MARK: - Multiple subscribers
//
//    @Test func multipleSubscribersReceiveSameHistory() async {
//        let sut = makeSUT()
//        let h1 = sut.history()
//        let h2 = sut.history()
//
//        sut.dispatch(1)
//        sut.dispatch(2)
//        await sut.scheduler.flush()
//
//        let s1 = await collectStates(h1, n: 2)
//        let s2 = await collectStates(h2, n: 2)
//
//        #expect(s1 == [1, 3])
//        #expect(s2 == [1, 3])
//    }
//
//    @Test func independentSubscribers_dontInterfere() async {
//        let sut = makeSUT()
//
//        let h1 = sut.history()
//        let h2 = sut.history()
//
//        sut.dispatch(1)
//        sut.dispatch(2)
//        await sut.scheduler.flush()
//
//        let s1 = await collectStates(h1, n: 2)
//        let s2 = await collectStates(h2, n: 2)
//
//        #expect(s1 == [1, 3])
//        #expect(s2 == [1, 3])
//    }
//
//    // MARK: - history respects store capacity
//
//    @Test func history_respectsCapacity_onStore() async {
//        // Store with capacity 2
//        let sut = Store(initial: 0, historyCapacity: 2) { $0 += $1 }
//        sut.dispatch(1)  // state 1
//        sut.dispatch(2)  // state 3
//        sut.dispatch(3)  // state 6 — should evict state 1
//        await sut.scheduler.flush()
//
//        let records = await sut.historyRecord(suffix: 10)
//        #expect(records.map(\.state) == [3, 6])
//    }
//
//    // MARK: - subscriber ordering
//
//    @Test func history_streams_deliverInOrder() async {
//        let sut = makeSUT()
//        let history = sut.history()
//
//        sut.dispatch(1)
//        sut.dispatch(2)
//        sut.dispatch(3)
//        await sut.scheduler.flush()
//
//        let states = await collectStates(history, n: 3)
//        #expect(states == [1, 3, 6])
//    }
//
//    // MARK: - history after late subscription
//
//    @Test func lateSubscription_receivesSnapshotAndLiveUpdates() async {
//        let sut = makeSUT()
//        sut.dispatch(1)
//        sut.dispatch(2)
//        await sut.scheduler.flush()
//
//        // Subscribe after some actions
//        let history = sut.history()
//
//        sut.dispatch(3)
//        await sut.scheduler.flush()
//
//        let states = await collectStates(history, n: 2)
//        #expect(states == [3, 6])
//    }
//}

// MARK: - Helpers

//private func collectStates(
//    _ stream: AsyncStream<HistoryEntryOf<Store<Int, Int>>>,
//    n: Int
//) async -> [Int] {
//    var values: [Int] = []
//    for await entry in stream {
//        values.append(entry.state)
//        if values.count >= n { break }
//    }
//    return values
//}
