//
//  GraphTest.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 09.02.2025.
//

import Testing
@testable import ReduxCore

struct GraphTest {
    typealias Sut = Graph<Int, Int>

    @Test func callbackEffects() async throws {
        var intercepted = [Sut.Effect]()
        let sut = Sut(0) { intercepted.append($0) }
        
        sut.dispatch(1)
        
        #expect(intercepted == [.single(1)])
        
        sut.dispatch(1,1)
        
        #expect(intercepted == [.single(1), .multiple([1,1])])
        
        sut.dispatch(contentsOf: [1,1])
        
        #expect(intercepted == [.single(1), .multiple([1,1]), .multiple([1,1])])
    }

}
