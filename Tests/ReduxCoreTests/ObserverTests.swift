//
//  ObserverTests.swift
//
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import XCTest
@testable import ReduxCore

final class ObserverTests: XCTestCase {
    func test_publishNewValues() {
        var result = 0
        let sut = Observer<Int> { state in
            result = state
            return .active
        }
        
        _ = sut.observe?(1)
        
        XCTAssertEqual(result, 1)
        
        _ = sut.observe?(2)
        
        XCTAssertEqual(result, 2)
        
        _ = sut.observe?(3)
        
        XCTAssertEqual(result, 3)
    }
    
    func test_publishOnlyNewValues() {
        var counter = 0
        let sut = Observer<Int> { _ in
            counter += 1
            return .active
        }
        
        _ = sut.observe?(1)
        _ = sut.observe?(1)
        _ = sut.observe?(1)
        
        XCTAssertEqual(counter, 1)
    }
    
    func test_publishUniqueStateWithGlobalScope() {
        var counter = 0
        let sut = Observer<Int>(scope: { $0 }, observe: { _ in
            counter += 1
            return .active
        })
        
        _ = sut.observe?(1)
        _ = sut.observe?(1)
        _ = sut.observe?(1)
        
        XCTAssertEqual(counter, 1)
    }
    
    func test_publishUniqueScopedState() {
        var counter = 0
        let sut = Observer<Int>(scope: { $0 * 2 }, observeScope: { multiplied in
            counter += multiplied
            return .active
        })
        
        _ = sut.observe?(1)
        _ = sut.observe?(1)
        
        XCTAssertEqual(counter, 2)
    }
    
    func test_publishStateWithNestedScopeOnlyOnce() {
        var counter = 0
        let sut = Observer<MockState>(scope: { $0.nested }, observe: { _ in
            counter += 1
            return .active
        })
        
        _ = sut.observe?(.init(value: 1, nested: .init(value: 1)))
        _ = sut.observe?(.init(value: 2, nested: .init(value: 1)))
        _ = sut.observe?(.init(value: 3, nested: .init(value: 1)))
        
        XCTAssertEqual(counter, 1)
    }
    
    func test_publishStateWithNestedScopeMultipleTimes() {
        var counter = 0
        let sut = Observer<MockState>(scope: { $0.nested }, observe: { _ in
            counter += 1
            return .active
        })
        
        _ = sut.observe?(.init(value: 1, nested: .init(value: 1)))
        _ = sut.observe?(.init(value: 1, nested: .init(value: 2)))
        _ = sut.observe?(.init(value: 1, nested: .init(value: 3)))
        
        XCTAssertEqual(counter, 3)
    }
    
    func test_dataRace() {
        var counter = 0
        let sut = Observer<Int> { state in
            counter = state
            return .active
        }
        
        DispatchQueue.global(qos: .background).sync {
            for i in 0...50 {
                _ = sut.observe?(i)
            }
        }
        
        DispatchQueue.global(qos: .utility).sync {
            for i in 0...50 {
                _ = sut.observe?(i)
            }
        }
        XCTAssertEqual(counter, 50)
    }
    
    func test_deadlock() {
        var counter = 0
        let sut = Observer<Int> { state in
            counter = state
            return .active
        }
        
        for i in 0...50 {
            sut.queue.sync {
                _ = sut.observe?(i)
            }
        }
        
        XCTAssertEqual(counter, 50)
    }

}

private struct NestedState: Equatable {
    let value: Int
}

private struct MockState {
    let value: Int
    let nested: NestedState
}


