//
//  StoreUpdateStreamTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxCore

struct StoreUpdateStreamTests {
    typealias Sut = Store<Int, Int>
    typealias SutGraph = Sut.Snapshot
    
    @Test func testUpdatesStream() async throws {
        let sut = makeSUT()
        
        let stream = sut.updates()
        try await Task.sleep(for: .milliseconds(50))
        
        let task = Task {
            var snapshots: [SutGraph] = []
            for await snapshot in stream {
                snapshots.append(snapshot)
                if snapshots.count == 3 { break }
            }
            return snapshots
        }
        
        sut.dispatch(1)
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

private extension StoreUpdateStreamTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}