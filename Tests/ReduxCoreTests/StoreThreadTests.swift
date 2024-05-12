//
//  StoreThreadTests.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//

import XCTest
@testable import StoreThread

final class StoreThreadTests: XCTestCase {
    func test_thread_start() {
        let sut = StoreThread(.default)
        let exp = XCTestExpectation()
        
        sut.start()
        
        sut.enqueue {
            XCTAssertTrue(sut.isExecuting)
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 0.1)
    }
}
