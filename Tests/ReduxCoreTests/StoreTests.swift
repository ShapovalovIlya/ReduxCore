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
    typealias SutGraph = Sut.StoreGraph
    typealias Streamer = StateStreamer<SutGraph>
    
    @Test func storeDrivers() async throws {
        let sut = makeSUT()
        let driver = Streamer()
        
        sut.install(driver)
        
        #expect(sut.contains(driver: driver) == true)
        
        sut.uninstall(driver)
        
        #expect(sut.contains(driver: driver) == false)
    }
    
    @Test func storeStreamers() async throws {
        let sut = makeSUT()
        let streamer1 = Streamer()
        let streamer2 = Streamer()
        
        sut.subscribe(streamer1)
        sut.subscribe(streamer2)
        
        #expect(sut.contains(streamer: streamer1) == true)
        #expect(sut.contains(streamer: streamer2) == true)
        
        sut.unsubscribe(streamer1)
        streamer2.continuation.finish()
        
        #expect(sut.contains(streamer: streamer1) == false)
        #expect(sut.contains(streamer: streamer2) == true)
        
        sut.dispatch(1)
        
        #expect(sut.contains(streamer: streamer2) == false)
    }
    
    @Test func storeDispatchActions() async throws {
        let sut = makeSUT()
        
        sut.dispatch(1)
        sut.dispatch(1)
        
        #expect(sut.state == 2)
        
        sut.dispatch(contentsOf: [1,2,3])
        
        #expect(sut.state == 8)
    }
    
    @Test func graphDispatchSingleAction() async throws {
        let sut = makeSUT()
        
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        
        #expect(sut.state == 3)
    }
    
    @Test func graphDispatchMultipleActions() async throws {
        let sut = makeSUT()
        
        sut.graph.dispatch(1, 1, 1)
        sut.graph.dispatch(contentsOf: [1,1,1])
                
        #expect(sut.state == 6)
    }
    
    @Test func storeResistDataRace() async throws {
        let sut = makeSUT()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: .high) {
                for _ in 0...50 {
                    sut.graph.dispatch(1)
                }
            }
            group.addTask(priority: .low) {
                for _ in 0...50 {
                    sut.graph.dispatch(1)
                }
            }
            await group.waitForAll()
        }
                
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
        
        actions.forEach(sut.graph.dispatch)
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
        
        sut.graph.dispatch(contentsOf: actions)
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

        actions.forEach(sut.graph.dispatch)
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
        
        sut.graph.dispatch(contentsOf: actions)
        streamer.continuation.finish()
        
        let result = await task.value
        #expect(result == [0, 3])
    }
    
    @Test func dispatchActionsInOrder() async throws {
        let sut = Store(initial: [Int]()) { $0.append($1) }
        let actions = Array(
            repeating: Int.random(in: Int.min...Int.max),
            count: Int.random(in: 1...10000)
        )
        
        actions.forEach(sut.dispatch(_:))
        
        #expect(sut.state == actions)
    }
}

private extension StoreTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0) { $0 += $1 }
    }
}

