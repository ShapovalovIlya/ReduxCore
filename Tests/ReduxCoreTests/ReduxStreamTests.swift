//
//  ReduxStreamTests.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//

import XCTest
@testable import ReduxStream

final class ReduxStreamTests: XCTestCase {
    func test_streamerStream() async {
        let sut = StateStreamer<Int>()
        let arr = NSMutableArray()
        
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
        let sut = StateStreamer<Int>()
        let arr = NSMutableArray()
        
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
        let sut = StateStreamer<Int>()
        let arr = NSMutableArray()
        
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
