//
//  StoreDispatchTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxStream
import ReduxCore

struct StoreDispatchTests {
    typealias SutGraph = Sut.Snapshot
    typealias Streamer = StateStreamer<SutGraph>
    
    @Test func storeDispatchActions() async throws {
        let sut = makeSUT()
        
        sut.dispatch(1)
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 2)
        
        sut.dispatch(contentsOf: [1,2,3])
        await sut.scheduler.flush()
        
        #expect(sut.state == 8)
    }
    
    @Test func graphDispatchSingleAction() async throws {
        let sut = makeSUT()
        
        sut.snapshot.dispatch(1)
        sut.snapshot.dispatch(1)
        sut.snapshot.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 3)
    }
    
    @Test func graphDispatchMultipleActions() async throws {
        let sut = makeSUT()
        
        sut.snapshot.dispatch(1, 1, 1)
        sut.snapshot.dispatch(contentsOf: [1,1,1])
        await sut.scheduler.flush()
                
        #expect(sut.state == 6)
    }
    
    @Test func storeResistDataRace() async throws {
        let sut = Store(initial: 0) { $0 += $1 }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: .high) {
                for _ in 0...50 {
                    sut.snapshot.dispatch(1)
                }
            }
            group.addTask(priority: .low) {
                for _ in 0...50 {
                    sut.snapshot.dispatch(1)
                }
            }
            await group.waitForAll()
        }
        
        await sut.scheduler.flush()
                
        #expect(sut.state == 102)
    }
    
    @Test func dispatchActionsInOrder() async throws {
        let sut = Store(initial: [Int](), scheduler: AsyncSerialScheduler()) { $0.append($1) }
        let actions = Array(
            repeating: Int(Int8.random(in: Int8.min...Int8.max)),
            count: Int.random(in: 1...10000)
        )
        
        actions.forEach(sut.dispatch(_:))
        await sut.scheduler.flush()
        
        #expect(sut.state.count == actions.count)
        #expect(sut.state == actions)
    }
}
