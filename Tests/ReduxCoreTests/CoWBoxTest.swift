//
//  CoWBoxTest.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 20.02.2025.
//

import Testing
import CoWBox

struct CoWBoxTest {
    struct Wrapped: Hashable { var counter = 0 }
    typealias Sut = CoWBox<Wrapped>
    
    @Test func copyOnWrite() async throws {
        let base = Sut(Wrapped())
        var sut = base
        
        #expect(base.counter == sut.counter)
        
        sut.counter = 1
        
        #expect(base.counter != sut.counter)
    }
    
    @Test func unfolded() async throws {
        let sut = CoWBox(1)
        
        #expect(sut.unfolded == 1)
    }
    
    @Test func equatable() async throws {
        let lhs = Sut(Wrapped())
        var rhs = lhs
        
        #expect(lhs == rhs)
        
        rhs.counter = 1
        
        #expect(lhs != rhs)
    }
}
