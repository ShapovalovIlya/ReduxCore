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
    
    @Test func streamValues() async {
        let sut = StateStreamer<Int>()
        let expexted = Array(repeating: Int.random(in: 0...100), count: 100)
        
        let task = Task {
            await sut.reduce(into: [Int]()) { partialResult, value in
                partialResult.append(value)
            }
        }
        
        expexted.forEach {
            sut.yield($0)
        }
        sut.finish()
        
        let result = await task.value
        #expect(expexted.elementsEqual(result))
    }
    
    @Test(.disabled())
    func throttleSequence() async throws {
        let sut = StateStreamer<Date>()
        let interval = 0.3
        
        let task = Task {
            await sut
                .throttle(for: interval)
                .reduce(into: [Date]()) { partialResult, date in
                    partialResult.append(date)
                }
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
    
    @Test func withUnretained() async throws {
        let (sut, continuation) = AsyncStream.newStream(of: Int.self)
        let values = [0,1,2,3]
        
        let task = Task {
            var object: NSObject? = NSObject()
            
            return await sut
                .withUnretained(try #require(object))
                .reduce(into: [Int]()) { partialResult, pair in
                    let value = pair.1
                    partialResult.append(value)
                    if value == 2 {
                        object = nil
                    }
                }
        }
        
        values.forEach {
            continuation.yield($0)
        }
        continuation.finish()
        
        let result = try await task.value
        #expect(result != values)
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
