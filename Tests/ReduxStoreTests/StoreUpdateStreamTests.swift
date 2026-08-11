//
//  StoreUpdateStreamTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxCore

struct StoreUpdateStreamTests {
    typealias SutGraph = Sut.Snapshot

    @Test func testUpdatesStream() async throws {
        let sut = makeSUT()

        let task = Task {
            var snapshots: [SutGraph] = []
            for await snapshot in sut.updates() {
                snapshots.append(snapshot)
                if snapshots.count == 3 { break }
            }
            return snapshots
        }

        // Let the subscription (and the initial snapshot) settle before
        // dispatching. `onChange` buffers only the newest value, so two
        // back-to-back dispatches may drop the intermediate state otherwise.
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(50))
        await sut.scheduler.flush()

        sut.dispatch(1)
        await sut.scheduler.flush()
        sut.dispatch(2)
        await sut.scheduler.flush()

        let snapshots = await task.value
        task.cancel()

        #expect(snapshots.count == 3)
        #expect(snapshots[0].state == 0)
        #expect(snapshots[1].state == 1)
        #expect(snapshots[2].state == 3)
    }
}
