//
//  StoreTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import XCTest
import ReduxStream
@testable import ReduxCore

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
    
    func test_subscribeObserver() {
        let sut = makeSUT()
        let observer0 = Observer<Store<Int, Int>.GraphStore>(observe: { _ in .active })
        let observer1 = Observer<Store<Int, Int>.GraphStore>(observe: { _ in .active })
        let observer2 = Observer<Store<Int, Int>.GraphStore>(observe: { _ in .active })

        sut.subscribe(observer0)
        sut.subscribe(observer1)
        sut.subscribe(observer2)
        
        XCTAssertTrue(sut.observers.contains(observer0))
        XCTAssertTrue(sut.observers.contains(observer1))
        XCTAssertTrue(sut.observers.contains(observer2))
    }
    
    func test_subscrieBuilder_Observer() {
        let sut = makeSUT()
        let observer0 = Observer<TestStore>(observe: { _ in .active })
        let observer1 = Observer<TestStore>(observe: { _ in .active })
        let observer2 = Observer<TestStore>(observe: { _ in .active })

        sut.subscribe {
            observer0
            observer1
            observer2
        }
                
        XCTAssertTrue(sut.observers.contains(observer0))
        XCTAssertTrue(sut.observers.contains(observer1))
        XCTAssertTrue(sut.observers.contains(observer2))
    }
    
    func test_subscribeStreamer() {
        let sut = makeSUT()
        let one = StateStreamer<TestStore>()
        let two = StateStreamer<TestStore>()
        let three = StateStreamer<TestStore>()
        
        sut.subscribe(one)
        sut.subscribe(two)
        sut.subscribe(three)
        
        XCTAssertTrue(sut.streamers.contains(one))
        XCTAssertTrue(sut.streamers.contains(two))
        XCTAssertTrue(sut.streamers.contains(three))
    }
    
    func test_subscribeBuilder_Streamer() {
        let sut = makeSUT()
        let one = StateStreamer<TestStore>()
        let two = StateStreamer<TestStore>()
        let three = StateStreamer<TestStore>()
        
        sut.subscribe {
            one
            two
            three
        }
        
        XCTAssertTrue(sut.streamers.contains(one))
        XCTAssertTrue(sut.streamers.contains(two))
        XCTAssertTrue(sut.streamers.contains(three))

    }
    
    func test_store_notifyStreamer() async throws {
        let sut = makeSUT()
        let streamer = StateStreamer<TestStore>()
        let arr = NSMutableArray()
        
        sut.subscribe(streamer)
        
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

private extension StoreTests {
        
    func makeSUT() -> Store<Int, Int> {
        Store(initial: 0) { (state: inout Int, action: Int) in
            state += action
        }
    }
}

