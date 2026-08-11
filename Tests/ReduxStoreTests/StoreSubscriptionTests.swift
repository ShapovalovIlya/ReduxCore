//
//  StoreSubscriptionTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxStream
import ReduxCore

struct StoreSubscriptionTests {
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
