//
//  ReduxStreamTests.swift
//
//
//  Created by Илья Шаповалов on 12.05.2024.
//

import Foundation
import Testing
import SequenceFX
@testable import ReduxStream

struct ReduxStreamTest {
    
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
    
    @Test(arguments: [TimeInterval(0.3), .infinity, .nan, .zero, .greatestFiniteMagnitude, -1])
    func throttleSequence(_ interval: TimeInterval) async throws {
        let sut = StateStreamer<Date>()
        
        let task = Task {
            try await sut
                .throttle(for: interval)
                .reduce(into: [Date]()) { partialResult, date in
                    partialResult.append(date)
                }
        }
        
        for _ in 0...10 {
            try await Task.sleep(for: .seconds(Double.random(in: 0.1...0.4)))
            sut.continuation.yield(Date())
        }
        sut.finish()
        
        guard interval.isEqual(to: 0.3) || interval.isEqual(to: .zero) else {
            do {
                _ = try await task.value
            } catch {
                #expect(error is SleepError)
            }
            return
        }
        let events = try await task.value
        let intervals = dump(zip(events, events.dropFirst()).map { $1.timeIntervalSince($0) }, name: "Intervals for \(interval)")
        let leastInterval = try #require(intervals.min())
        
        #expect(interval.isLessThanOrEqualTo(leastInterval))
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
    
    @Test func removeDuplicates() async {
        let (sut, continuation) = AsyncStream.makeStream(of: Int.self)
        
        let task = Task {
            await sut
                .removeDuplicates()
                .reduce(into: [Int]()) { partialResult, value in
                    partialResult.append(value)
                }
        }
        
        continuation.yield(1)
        continuation.yield(1)
        continuation.yield(1)
        continuation.finish()
        
        let result = await task.value
        #expect(result == [1])
    }
    
    @Test func forEach() async {
        let (sut, continuation) = AsyncStream.makeStream(of: Int.self)
        
        let task = Task {
            var result = [Int]()
            await sut.forEach { result.append($0) }
            return result
        }
        
        continuation.yield(1)
        continuation.yield(1)
        continuation.yield(1)
        continuation.finish()
        
        let result = await task.value
        #expect(result == [1,1,1])
    }
}
