//
//  StoreTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxStream
import ReduxCore

struct StoreTests {
    typealias Sut = Store<Int, Int>
    typealias SutGraph = Sut.Snapshot
    typealias Streamer = StateStreamer<SutGraph>
    
    @Test func storeDrivers() async throws {
        let sut = makeSUT()
        let driver = Streamer()
        
        sut.install(driver)
        await sut.scheduler.flush()
        
        #expect(sut.contains(driver: driver) == true)
        
        sut.uninstall(driver)
        await sut.scheduler.flush()
        
        #expect(sut.contains(driver: driver) == false)
    }
    
    @Test func storeStreamers() async throws {
        let sut = makeSUT()
        let streamer1 = Streamer()
        let streamer2 = Streamer()
        
        sut.subscribe(streamer1)
        sut.subscribe(streamer2)
        await sut.scheduler.flush()
        
        #expect(sut.contains(streamer: streamer1) == true)
        #expect(sut.contains(streamer: streamer2) == true)
        
        sut.unsubscribe(streamer1)
        await sut.scheduler.flush()
        streamer2.continuation.finish()
        
        #expect(sut.contains(streamer: streamer1) == false)
        #expect(sut.contains(streamer: streamer2) == true)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.contains(streamer: streamer2) == false)
    }
    
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
    
    @Test func subscribeStreamer() async throws {
        let sut = makeSUT()
        let one = Streamer()
        let two = Streamer()
        let three = Streamer()
        
        sut.install(one)
        sut.install(two)
        sut.install(three)
        await sut.scheduler.flush()
        
        #expect(sut.contains(driver: one) == true)
        #expect(sut.contains(driver: two) == true)
        #expect(sut.contains(driver: three) == true)
    }

    @Test func subscribeStreamerUsingBuilder() async throws {
        let sut = makeSUT()
        let one = Streamer()
        let two = Streamer()
        let three = Streamer()
        
        sut.installAll {
            one
            two
            three
        }
        await sut.scheduler.flush()
        
        #expect(sut.contains(driver: one) == true)
        #expect(sut.contains(driver: two) == true)
        #expect(sut.contains(driver: three) == true)
    }

    @Test func notifyDriverMultipleTimes() async throws {
        let sut = makeSUT()
        let driver = Streamer()
        let actions = Array(repeating: 1, count: 3)
        
        sut.install(driver)
        
        let task = Task {
            await driver
                .map(\.state)
                .reduce(into: [Int]()) { result, element in
                    result.append(element)
                }
        }
        
        actions.forEach(sut.snapshot.dispatch)
        await sut.scheduler.flush()
        driver.continuation.finish()
        
        let result = await task.value
        #expect(result == [0,1,2,3])
    }
    
    @Test func dispatchMultipleActionsNotifyDriverOnce() async throws {
        let sut = makeSUT()
        let driver = Streamer()
        let actions = Array(repeating: 1, count: 3)
        
        sut.install(driver)
        
        let task = Task {
            await driver
                .map(\.state)
                .reduce(into: [Int]()) { $0.append($1) }
        }
        
        sut.snapshot.dispatch(contentsOf: actions)
        await sut.scheduler.flush()
        driver.continuation.finish()
        
        let result = await task.value
        #expect(result == [0, 3])
    }
    
    @Test func dispatchActionNotifyStreamer() async throws {
        let sut = makeSUT()
        let streamer = Streamer()
        let actions = Array(repeating: 1, count: 3)
        
        sut.subscribe(streamer)
        
        let task = Task {
            await streamer
                .map(\.state)
                .reduce(into: [Int]()) { $0.append($1) }
        }

        actions.forEach(sut.snapshot.dispatch)
        await sut.scheduler.flush()
        streamer.continuation.finish()
        
        let result = await task.value
        #expect(result == [0,1,2,3])
    }
    
    @Test func dispatchMultipleActionsNotifyStreamerOnce() async throws {
        let sut = makeSUT()
        let streamer = Streamer()
        let actions = Array(repeating: 1, count: 3)
        
        sut.subscribe(streamer)
        
        let task = Task {
            await streamer.reduce(into: [Int]()) { result, action in
                result.append(action.state)
            }
        }
        
        sut.snapshot.dispatch(contentsOf: actions)
        await sut.scheduler.flush()
        streamer.continuation.finish()
        
        let result = await task.value
        #expect(result == [0, 3])
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

//MARK: - String: Action conformance for addHook tests
extension String: @retroactive Action {}

//MARK: - addHook Tests
extension StoreTests {
    
    @Test func addHookFiresOnMatchingAction() async throws {
        let sut = makeSUT()
        let hook = sut.addHook(on: Int.self)

        await sut.scheduler.flush()
        let task = Task {
            var results: [(state: Int, action: Int)] = []
            for await element in hook {
                results.append(element)
                if results.count == 1 { break }
            }
            return results
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()

        let results = await task.value
        #expect(results.count == 1)
        #expect(results[0].state == 1)
        #expect(results[0].action == 1)
    }
    
    @Test func addHookDoesNotFireOnNonMatchingAction() async throws {
        let sut = makeSUT()
        
        let task = Task {
            var results: [(state: Int, action: String)] = []
            for await element in sut.addHook(on: String.self) {
                results.append(element)
                break
            }
            return results
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        // Grace period to confirm no events arrive for non-matching type
        task.cancel()
        
        let results = await task.value
        #expect(results.isEmpty == true)
    }
    
    @Test func addHookMultipleHooksOnSameTypeAllFire() async throws {
        let sut = makeSUT()
        let hook1 = sut.addHook(on: Int.self)
        let hook2 = sut.addHook(on: Int.self)

        await sut.scheduler.flush()
        let task1 = Task {
            var results: [(state: Int, action: Int)] = []
            for await element in hook1 {
                results.append(element)
                if results.count == 1 { break }
            }
            return results
        }
        
        let task2 = Task {
            var results: [(state: Int, action: Int)] = []
            for await element in hook2 {
                results.append(element)
                if results.count == 1 { break }
            }
            return results
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        let results1 = await task1.value
        let results2 = await task2.value
        
        #expect(results1.count == 1)
        #expect(results1[0].state == 1)
        #expect(results1[0].action == 1)
        #expect(results2.count == 1)
        #expect(results2[0].state == 1)
        #expect(results2[0].action == 1)
    }
    
    @Test func addHookFiresPerActionInBatch() async throws {
        let sut = makeSUT()
        let hook = sut.addHook(on: Int.self)

        await sut.scheduler.flush()
        let task = Task {
            var results: [(state: Int, action: Int)] = []
            for await element in hook {
                results.append(element)
                if results.count == 3 { break }
            }
            return results
        }
        
        sut.dispatch(contentsOf: [1, 2, 3])
        await sut.scheduler.flush()
        
        let results = await task.value
        #expect(results.count == 3)
        #expect(results[0].state == 1)
        #expect(results[0].action == 1)
        #expect(results[1].state == 3)
        #expect(results[1].action == 2)
        #expect(results[2].state == 6)
        #expect(results[2].action == 3)
    }
    
    @Test func addHookCleanupOnStreamTermination() async throws {
        let sut = makeSUT()
        let hook = sut.addHook(on: Int.self)

        await sut.scheduler.flush()
        let task = Task {
            var results: [(state: Int, action: Int)] = []
            for await element in hook {
                results.append(element)
                if results.count == 1 { break }
            }
            return results
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        _ = await task.value // stream consumed and terminated
        
        // After stream termination, dispatch again — no crash, state updates still work
        sut.dispatch(2)
        await sut.scheduler.flush()
        
        #expect(sut.state == 3) // 0 + 1 + 2
    }
    
    @Test func addHookWithCustomBufferingPolicy() async throws {
        let sut = makeSUT()
        let hook = sut.addHook(.bufferingNewest(1), on: Int.self)

        await sut.scheduler.flush()
        let task = Task {
            var results: [(state: Int, action: Int)] = []
            for await element in hook {
                results.append(element)
                if results.count == 1 { break }
            }
            return results
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        let results = await task.value
        #expect(results.count == 1)
        #expect(results[0].state == 1)
        #expect(results[0].action == 1)
    }
}

private extension StoreTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}

