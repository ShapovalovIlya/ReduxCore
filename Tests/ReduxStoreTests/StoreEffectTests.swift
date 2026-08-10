//
//  StoreEffectTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxCore

struct StoreEffectTests {
    typealias Sut = Store<Int, Int>
    
    @Test func testEffectRunsAfterAction() async throws {
        let sut = makeSUT()
        
        actor Recorder {
            var states: [Int] = []
            var actions: [Int] = []
            func record(_ state: Int, _ action: Int) {
                states.append(state)
                actions.append(action)
            }
        }
        let recorder = Recorder()
        
        sut.addEffect { state, action, _ in
            await recorder.record(state, action)
        }
        
        sut.dispatch(5)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(100))
        
        let states = await recorder.states
        let actions = await recorder.actions
        #expect(states == [5])
        #expect(actions == [5])
    }
    
    @Test func testMultipleEffectsRunConcurrently() async throws {
        let sut = makeSUT()
        
        actor Recorder {
            var count = 0
            func increment() { count += 1 }
        }
        let recorder = Recorder()
        
        sut.addEffect { _,_,_ in
            await recorder.increment()
        }
        sut.addEffect { _,_,_ in
            await recorder.increment()
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(await recorder.count == 2)
    }
    
    @Test func testRemoveEffectStopsExecution() async throws {
        let sut = makeSUT()
        
        actor Recorder {
            var count = 0
            func increment() { count += 1 }
        }
        let recorder = Recorder()
        
        let id = sut.addEffect { _,_,_ in
            await recorder.increment()
        }
        
        // Removal returns the registered effect.
        let removed = sut.removeEffect(withId: id)
        #expect(removed?.id == id)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(await recorder.count == 0)
    }
}

private extension StoreEffectTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}
