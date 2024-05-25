//
//  ReduxStreamTests.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//

import XCTest
@testable import ReduxStream

final class ReduxStreamTests: XCTestCase {
    private var sut: StateStreamer<Int>!
    private var arr: NSMutableArray!
    
    override func setUp() async throws {
        try await super.setUp()
        
        sut = StateStreamer<Int>()
        arr = NSMutableArray()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        sut = nil
        arr = nil
    }
    
    func test_streamerStream() async {
        let task = Task {
            for await val in sut.state {
                arr.add(val)
            }
        }
        
        sut.continuation.yield(0)
        sut.continuation.yield(1)
        sut.continuation.yield(2)
        sut.continuation.finish()
        
        await task.value
        XCTAssertEqual(arr, [0,1,2])
    }
    
    func test_streamerRemoveDuplicates() async {
        let task = Task {
            for await val in sut.state.removeDuplicates() {
                arr.add(val)
            }
        }
        
        sut.continuation.yield(1)
        sut.continuation.yield(1)
        sut.continuation.yield(1)
        sut.continuation.finish()
        
        await task.value
        XCTAssertEqual(arr, [1])
    }
    
    func test_streamerForEach() async {
        let task = Task {
            await sut.state
                .forEach(arr.add(_:))
        }
        
        sut.continuation.yield(1)
        sut.continuation.yield(1)
        sut.continuation.yield(1)
        sut.continuation.finish()
        
        await task.value
        XCTAssertEqual(arr, [1,1,1])
    }
}

extension NSMutableArray: @unchecked Sendable {}
