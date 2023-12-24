//
//  StoreTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import XCTest
@testable import ReduxCore

protocol Action {}

final class StoreTests: XCTestCase {
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
        let observer0 = Observer<Store<Int, Int>.GraphStore>(observe: { _ in .active })
        let observer1 = Observer<Store<Int, Int>.GraphStore>(observe: { _ in .active })
        let observer2 = Observer<Store<Int, Int>.GraphStore>(observe: { _ in .active })

        sut.subscribe {
            observer0
            observer1
            observer2
        }
                
        XCTAssertTrue(sut.observers.contains(observer0))
        XCTAssertTrue(sut.observers.contains(observer1))
        XCTAssertTrue(sut.observers.contains(observer2))
    }
    
}

private extension StoreTests {
    func makeSUT() -> Store<Int, Int> {
        Store(initial: 0) { (state: inout Int, action: Int) in
            state += action
        }
    }
}

