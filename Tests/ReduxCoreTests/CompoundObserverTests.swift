//
//  CompoundObserverTests.swift
//  
//
//  Created by Шаповалов Илья on 19.03.2024.
//

import XCTest
@testable import ReduxCore

final class CompoundObserverTests: XCTestCase {
    func test_publishValues() {
        var result = 0
        let sut = CompoundObserver<Int>()
            .observe { state in
                result += state
                return .active
            }
        
        _ = sut.observe(1)
        _ = sut.observe(1)
        _ = sut.observe(1)
        
        XCTAssertEqual(result, 3)
    }
    
    func test_publishOnlyNewValues() {
        var counter = 0
        let sut = CompoundObserver<Int>()
            .removeDuplicates()
            .observe { _ in
            counter += 1
            return .active
        }
        
        _ = sut.observe(1)
        _ = sut.observe(1)
        _ = sut.observe(1)
        
        XCTAssertEqual(counter, 1)
    }
}
