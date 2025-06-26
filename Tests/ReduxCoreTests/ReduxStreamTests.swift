//
//  ReduxStreamTests.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//

import XCTest
import Testing
@testable import ReduxStream

struct ReduxStreamTests_new {
    @Test(.disabled())
    func throttleSequence() async throws {
        let sut = StateStreamer<Date>()
        let interval = 0.3
        
        let task = Task {
            var intervals = [Date]()
            
            for await date in sut.state.throttle(for: interval) {
                intervals.append(date)
            }
            
            return intervals
        }
        
        for _ in 0...10 {
            try await Task.sleep(for: .seconds(Double.random(in: 0.1...0.4)))
            sut.continuation.yield(Date())
        }
        sut.continuation.finish()
                
        var events = await task.value
        var intervals = [TimeInterval]()
        
        let start = events.removeFirst()
        
        _ = events
            .reduce(start) { prev, next in
                intervals.append(prev.distance(to: next))
                return next
            }
        
        let least = try #require(intervals.min())
        
        #expect(least >= interval)
    }
}

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
            for await val in sut {
                arr.add(val)
            }
        }
        
        sut.yield(0)
        sut.yield(1)
        sut.yield(2)
        sut.finish()
        
        await task.value
        XCTAssertEqual(arr, [0,1,2])
    }
    
    func test_streamerRemoveDuplicates() async {
        let task = Task {
            for await val in sut.removeDuplicates() {
                arr.add(val)
            }
        }
        
        sut.yield(1)
        sut.yield(1)
        sut.yield(1)
        sut.finish()
        
        await task.value
        XCTAssertEqual(arr, [1])
    }
    
    func test_streamerForEach() async {
        let task = Task {
            await sut.forEach(arr.add(_:))
        }
        
        sut.yield(1)
        sut.yield(1)
        sut.yield(1)
        sut.finish()
        
        await task.value
        XCTAssertEqual(arr, [1,1,1])
    }
    
    func test_forEachTask() async throws {
        let task = sut.forEachTask(arr.add)
        
        sut.yield(1)
        sut.yield(1)
        sut.yield(1)
        sut.finish()
        
        try await task.value
        XCTAssertEqual(arr, [1,1,1])
    }
    
    func test_forEachTaskAsync() async throws {
        let task = sut.forEachTask(asyncAdd)
        
        sut.yield(1)
        sut.yield(1)
        sut.yield(1)
        sut.finish()

        try await task.value
        XCTAssertEqual(arr, [1,1,1])
    }
    
    private func asyncAdd(_ val: Int) async {
        arr.add(val)
    }
}

extension NSMutableArray: @unchecked @retroactive Sendable {}
