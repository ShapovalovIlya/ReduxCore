//
//  StoreTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import XCTest
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
    
    func test_subscrieBuilder() {
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
    
    func test_store_NotifyStreamer_initialState() {
        let sut = makeSUT()
        let streamer = StateStreamer<TestStore>()
        let exp = XCTestExpectation()
        
        sut.subscribe(streamer)
        stubStream(streamer) { value in
            exp.fulfill()
            XCTAssertEqual(value.state, 0)
        }
        
        wait(for: [exp], timeout: 0.1)
    }
    
    // Фейлится при запуске всех тестов разом.
    func test_store_notifyStreamer_multipleValues() {
        let sut = makeSUT()
        let streamer = StateStreamer<TestStore>()
        let exp = XCTestExpectation(description: #function)
        let arr = NSMutableArray()
        
        sut.subscribe(streamer)
        
        stubStream(streamer) { val in
            arr.add(val)
        } onCancel: {
            exp.fulfill()
        }
        
        sut.dispatch(1)
        sut.dispatch(1)
        streamer.invalidate()
        sut.dispatch(1)

        XCTAssertEqual(arr.count, 3)
        wait(for: [exp], timeout: 1)
    }
    
}

private extension StoreTests {
    func stubStream<Int>(
        _ streamer: StateStreamer<Int>,
        onNext: @escaping (Int) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        Task {
            for await value in streamer.state {
                onNext(value)
            }
        }
        streamer.continuation.onTermination = { _ in
            onCancel?()
        }
    }
    
    func makeSUT() -> Store<Int, Int> {
        Store(initial: 0) { (state: inout Int, action: Int) in
            state += action
        }
    }
}

