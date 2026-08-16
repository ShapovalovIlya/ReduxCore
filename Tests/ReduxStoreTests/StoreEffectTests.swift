//
//  StoreEffectTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
@testable import ReduxCore

struct StoreEffectTests {
    
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
        
        let id = sut.addEffect { state, action, _ in
            await recorder.record(state, action)
        }
        
        sut.dispatch(5)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        await #expect(recorder.states.count == 1)
        await #expect(recorder.states == [5])
        await #expect(recorder.actions == [5])
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
        for (_, task) in sut.runningEffects {
            await task.value
        }
        
        await #expect(recorder.count == 2)
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

        sut.removeEffect(withId: id)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        await #expect(recorder.count == 0)
    }

    @Test func testPermissionBlockedActionDoesNotTriggerEffect() async throws {
        let sut = makeSUT()

        actor Counter {
            var count = 0
            func increment() { count += 1 }
        }
        let counter = Counter()

        sut.addPermission { _, _ in false }
        sut.addEffect { _, _, _ in
            await counter.increment()
        }

        sut.dispatch(1)
        await sut.scheduler.flush()

        // The action never reaches the reducer, so no effect may run.
        #expect(sut.state == 0)
        #expect(await counter.count == 0)
    }

    @Test func testEffectRunsForNoopAction() async throws {
        let sut = Store<Int, Int>(initial: 0, scheduler: AsyncSerialScheduler()) { _, _ in () }

        actor SnapshotRecorder {
            var states: [Int] = []
            var actions: [Int] = []
            func record(_ state: Int, _ action: Int) {
                states.append(state)
                actions.append(action)
            }
        }
        let recorder = SnapshotRecorder()

        let id = sut.addEffect { state, action, _ in
            await recorder.record(state, action)
        }

        sut.dispatch(5)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value

        // Effects fire per reduced action even when the reducer leaves the
        // state untouched; the effect sees the unchanged state.
        await #expect(recorder.states.count == 1)
        await #expect(recorder.states == [0])
        await #expect(recorder.actions == [5])
    }

}
