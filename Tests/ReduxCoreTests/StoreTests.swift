//
//  StoreTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import XCTest
import Testing
import ReduxStream
@testable import ReduxCore

struct StoreTestsNew {
    typealias Sut = Store<Int, Int>
    
    @Test func storeDrivers() async throws {
        let sut = makeSUT()
        let driver = StateStreamer<Sut.GraphStore>()
        
        sut.install(driver)
        
        #expect(sut.installed(driver) == true)
        
        sut.unsubscribe(driver)
        
        #expect(sut.installed(driver) == false)
    }
    
    @Test func storeStreamers() async throws {
        let sut = makeSUT()
        let streamer1 = StateStreamer<Sut.GraphStore>()
        let streamer2 = StateStreamer<Sut.GraphStore>()
        
        sut.insert(streamer1)
        sut.insert(streamer2)
        
        #expect(sut.contains(streamer1) == true)
        #expect(sut.contains(streamer2) == true)
        
        sut.remove(streamer1)
        streamer2.continuation.finish()
        
        #expect(sut.contains(streamer1) == false)
        #expect(sut.contains(streamer2) == false)
    }
}

final class StoreTests: XCTestCase {
    typealias TestStore = Store<Int, Int>.GraphStore
    
    func test_changeState() {
        let sut = makeSUT()
        
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        sut.graph.dispatch(1)
        
        XCTAssertEqual(sut.state, 3)
    }
    
    func test_dataRace() {
        let sut = makeSUT()
        
        DispatchQueue.global(qos: .userInitiated).sync {
            for _ in 0...50 {
                sut.graph.dispatch(1)
            }
        }
        
        DispatchQueue.global().sync {
            for _ in 0...50 {
                sut.graph.dispatch(1)
            }
        }
        
        XCTAssertEqual(sut.state, 102)
    }
    
    func test_subscribeStreamer() {
        let sut = makeSUT()
        let one = StateStreamer<TestStore>()
        let two = StateStreamer<TestStore>()
        let three = StateStreamer<TestStore>()
        
        sut.install(one)
        sut.install(two)
        sut.install(three)
        
        XCTAssertTrue(sut.installed(one))
        XCTAssertTrue(sut.installed(two))
        XCTAssertTrue(sut.installed(three))
    }
    
    func test_subscribeBuilder_Streamer() {
        let sut = makeSUT()
        let one = StateStreamer<TestStore>()
        let two = StateStreamer<TestStore>()
        let three = StateStreamer<TestStore>()
        
        sut.installAll {
            one
            two
            three
        }
        
        XCTAssertTrue(sut.installed(one))
        XCTAssertTrue(sut.installed(two))
        XCTAssertTrue(sut.installed(three))
    }
    
    func test_store_notifyStreamer() async throws {
        let sut = makeSUT()
        let streamer = StateStreamer<TestStore>()
        let arr = NSMutableArray()
        
        sut.install(streamer)
        
        let task = Task {
            for await value in streamer.state {
                arr.add(value.state)
            }
        }
        
        sut.dispatch(1)
        sut.dispatch(1)
        sut.dispatch(1)
        streamer.continuation.finish()

        await task.value
        XCTAssertEqual(arr, [0,1,2,3])
    }
    
}

        
fileprivate func makeSUT() -> Store<Int, Int> {
    Store(initial: 0) { (state: inout Int, action: Int) in
        state += action
    }
}


