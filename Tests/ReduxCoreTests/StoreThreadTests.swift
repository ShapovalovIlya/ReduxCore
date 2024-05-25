//
//  StoreThreadTests.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//

import XCTest
@testable import StoreThread

final class StoreThreadTests: XCTestCase {
    private var exp: XCTestExpectation!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        exp = XCTestExpectation()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        
        exp = nil
    }
    
    func test_thread_start() {
        let sut = StoreThread()
        
        sut.start()
        
        sut.enqueue {
            XCTAssertTrue(sut.isExecuting)
            self.exp.fulfill()
        }
        
        wait(for: [exp], timeout: 0.1)
    }
    
    func test_thread_execute_work() {
        let arr = NSMutableArray()
        let sut = StoreThread(queue: [
            { arr.add(1) },
            { arr.add(2) },
            { arr.add(3) },
            { self.exp.fulfill() }
        ])
        
        sut.start()
        
        wait(for: [exp], timeout: 0.1)
        XCTAssertEqual(arr.count, 3)
    }
    
    func test_thread_paused() {
        let sut = StoreThread(queue: [
            { XCTFail() },
            { XCTFail() },
            { XCTFail() },
        ])
        
        sut.start()
        sut.pause()
        
        XCTAssertTrue(sut.isPaused)
    }
    
    func test_thread_setSettings() {
        let stubSettings = StoreThread.Settings(
            name: "Baz",
            qos: .utility,
            stackSize: 8192,
            priority: 0.5
        )
        let sut = StoreThread(stubSettings)
        
        XCTAssertEqual(sut.name, stubSettings.name)
        XCTAssertEqual(sut.qualityOfService, stubSettings.qos)
        XCTAssertEqual(sut.stackSize, stubSettings.stackSize)
        XCTAssertEqual(sut.threadPriority, stubSettings.priority)
    }
    
    func test_thread_executeWorkInFIFO() {
        let sut = StoreThread()
        let arr = NSMutableArray()
        sut.start()
        
        sut.enqueue { arr.add(1) }
        sut.enqueue { arr.add(2) }
        sut.enqueue { arr.add(3) }
        sut.enqueue { self.exp.fulfill() }
        
        wait(for: [exp], timeout: 0.1)
        XCTAssertEqual(arr, [1,2,3])
    }
}
