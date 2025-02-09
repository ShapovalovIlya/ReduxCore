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
    typealias SutGraph = Sut.GraphStore
    
    @Test func storeDrivers() async throws {
        let sut = makeSUT()
        let driver = StateStreamer<SutGraph>()
        
        sut.install(driver)
        
        #expect(sut.contains(driver: driver) == true)
        
        sut.uninstall(driver)
        
        #expect(sut.contains(driver: driver) == false)
    }
    
    @Test func storeStreamers() async throws {
        let sut = makeSUT()
        let streamer1 = StateStreamer<SutGraph>()
        let streamer2 = StateStreamer<SutGraph>()
        
        sut.subscribe(streamer1)
        sut.subscribe(streamer2)
        
        #expect(sut.contains(streamer: streamer1) == true)
        #expect(sut.contains(streamer: streamer2) == true)
        
        sut.unsubscribe(streamer1)
        streamer2.continuation.finish()
        
        #expect(sut.contains(streamer: streamer1) == false)
        #expect(sut.contains(streamer: streamer2) == false)
    }
    
    @Test func dispatchSingle() async throws {
        let sut = makeSUT()
        
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        
        #expect(sut.state == 3)
    }
    
    @Test func dispatchMultiple() async throws {
        let sut = makeSUT()
        
        sut.graph.dispatch(1, 1, 1)
        sut.graph.dispatch(contentsOf: [1,1,1])
                
        #expect(sut.state == 6)
    }
    
    @Test func dataRace() async throws {
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
        let one = StateStreamer<SutGraph>()
        let two = StateStreamer<SutGraph>()
        let three = StateStreamer<SutGraph>()
        
        sut.install(one)
        sut.install(two)
        sut.install(three)
        
        #expect(sut.contains(driver: one) == true)
        #expect(sut.contains(driver: two) == true)
        #expect(sut.contains(driver: three) == true)
    }

    @Test func subscribeStreamerUsingBuilder() async throws {
        let sut = makeSUT()
        let one = StateStreamer<SutGraph>()
        let two = StateStreamer<SutGraph>()
        let three = StateStreamer<SutGraph>()
        
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
        let streamer = StateStreamer<SutGraph>()
        var arr = [Int]()
        
        sut.install(streamer)
        
        let task = Task {
            for await value in streamer.state {
                arr.append(value.state)
            }
        }
        
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        streamer.continuation.finish()
        
        await task.value
        #expect(arr == [0,1,2,3])
    }
    
    @Test func notifyDriverSingleTime() async throws {
        let sut = makeSUT()
        let streamer = StateStreamer<SutGraph>()
        let actions = Array(repeating: 1, count: 3)
        var arr = [Int]()
        
        sut.install(streamer)
        
        let task = Task {
            for await value in streamer.state {
                arr.append(value.state)
            }
        }
        
        sut.graph.dispatch(contentsOf: actions)
        streamer.continuation.finish()
        
        await task.value
        #expect(arr == [0, 3])
    }
    
    @Test func notifyStreamerMultipleTimes() async throws {
        let sut = makeSUT()
        let streamer = StateStreamer<SutGraph>()
        var arr = [Int]()
        
        sut.subscribe(streamer)
        
        let task = Task {
            for await value in streamer.state {
                arr.append(value.state)
            }
        }
        
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        streamer.continuation.finish()
        
        await task.value
        #expect(arr == [0,1,2,3])
    }
    
    @Test func notifyStreamerSingleTime() async throws {
        let sut = makeSUT()
        let streamer = StateStreamer<SutGraph>()
        let actions = Array(repeating: 1, count: 3)
        var arr = [Int]()
        
        sut.subscribe(streamer)
        
        let task = Task {
            for await value in streamer.state {
                arr.append(value.state)
            }
        }
        
        sut.graph.dispatch(contentsOf: actions)
        streamer.continuation.finish()
        
        await task.value
        #expect(arr == [0, 3])
    }
    
}

private extension StoreTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0) { $0 += $1 }
    }
}

