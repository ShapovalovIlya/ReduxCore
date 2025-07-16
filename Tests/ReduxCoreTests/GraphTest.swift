//
//  GraphTest.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 16.07.2025.
//

import Testing
@testable import ReduxCore

struct GraphTest {
    typealias Sut = Graph<Int, Int>
    
    @Test func accessToStateFromDifferentTasks() async throws {
        let sut = Sut(1) { _ in }
        
        let task = Task {
            await withTaskGroup { group in
                stride(from: 0, to: 10000, by: 1).forEach { _ in
                    group.addTask {
                        sut.state.description
                    }
                }
                return await group.reduce(into: [String]()) { $0.append($1) }
            }
        }
        
        let result = await task.value
        let expected = Array(repeating: 1.description, count: 10000)
        
        #expect(expected == result)
    }
    
    @Test func dispatchSingeAction() async throws {
        let (actions, continuation) = AsyncStream.newStream(of: [Int].self)
        let sut = Sut(1) { actions in
            continuation.yield(Array(actions))
        }
        
        let task = Task {
            await actions.reduce(into: [Int](), +=)
        }
        
        sut.dispatch(1)
        sut.dispatch(2)
        sut.dispatch(3)
        continuation.finish()
        
        let results = await task.value
        
        #expect([1, 2, 3] == results)
    }

    @Test func dispatchMultipleAction() async throws {
        let (actions, continuation) = AsyncStream.newStream(of: [Int].self)
        let sut = Sut(1) { actions in
            continuation.yield(Array(actions))
        }
        
        let task = Task {
            await actions.reduce(into: [Int](), +=)
        }
        
        sut.dispatch(contentsOf: [1,2])
        sut.dispatch(3, 4)
        continuation.finish()
        
        let results = await task.value
        
        #expect([1, 2, 3, 4] == results)

    }
}
