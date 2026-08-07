//
//  StoreTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxStream
import ReduxCore

//MARK: - StoreDispatchTests

struct StoreDispatchTests {
    typealias Sut = Store<Int, Int>
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

private extension StoreDispatchTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}

//MARK: - StoreSubscriptionTests

struct StoreSubscriptionTests {
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
}

private extension StoreSubscriptionTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}

//MARK: - StoreExtensionTests

struct StoreExtensionTests {
    typealias Sut = Store<Int, Int>
    typealias SutGraph = Sut.Snapshot
    typealias Streamer = StateStreamer<SutGraph>
    
    //MARK: - Permission Tests
    
    @Test func testPermissionAllowsAction() async throws {
        let sut = makeSUT()
        
        sut.addPermission { _, _ in true }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }
    
    @Test func testPermissionBlocksAction() async throws {
        let sut = makeSUT()
        
        sut.addPermission { _, _ in false }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 0)
    }
    
    @Test func testMultiplePermissionsAllMustPass() async throws {
        let sut = makeSUT()
        
        sut.addPermission { _, _ in true }
        sut.addPermission { _, _ in true }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
        
        // Now add a blocking permission
        sut.addPermission { _, _ in false }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }
    
    @Test func testRemovePermissionRestoresAccess() async throws {
        let sut = makeSUT()
        
        let id = sut.addPermission { _, _ in false }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 0)
        
        sut.removePermission(withId: id)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }
    
    //MARK: - Middleware Tests
    
    @Test func testMiddlewareAddsActions() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in [1] }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 2)
    }
    
    @Test func testMultipleMiddlewareAccumulate() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in [1] }
        sut.addMiddleware { _, _ in [1] }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 3)
    }
    
    @Test func testRemoveMiddlewareStopsInterception() async throws {
        let sut = makeSUT()
        
        let id = sut.addMiddleware { _, _ in [1] }
        
        sut.removeMiddleware(withId: id)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }
    
    //MARK: - Effect Tests
    
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
        
        sut.addEffect { state, action in
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
        
        sut.addEffect { _, _ in
            await recorder.increment()
        }
        sut.addEffect { _, _ in
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
        
        let id = sut.addEffect { _, _ in
            await recorder.increment()
        }
        
        sut.removeEffect(withId: id)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(await recorder.count == 0)
    }
    
    //MARK: - Updates Stream Tests
    
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
    
    //MARK: - Combined Pipeline Tests
    
    @Test func testPermissionMiddlewareEffectPipeline() async throws {
        let sut = makeSUT()
        
        actor Recorder {
            var count = 0
            func increment() { count += 1 }
        }
        let recorder = Recorder()
        
        // Permission allows
        sut.addPermission { _, _ in true }
        // Middleware adds extra action
        sut.addMiddleware { _, _ in [1] }
        // Effect records
        sut.addEffect { _, _ in
            await recorder.increment()
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(100))
        
        // State: 1 (original) + 1 (middleware) = 2
        #expect(sut.state == 2)
        // Effect fires twice (once per reduced action)
        #expect(await recorder.count == 2)
    }
}

private extension StoreExtensionTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}

//MARK: - String: Action conformance for addHook tests
extension String: @retroactive Action {}
