//
//  SequenceTest.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 16.04.2025.
//

import Testing
import SequenceFX

struct SequenceTest {

    @Test func chuckedSequenceBySize() async throws {
        let sut = (1...95).chunked(by: 10)
        
        #expect(sut.count == 10)
        sut.forEach { chunk in
            #expect(chunk.count <= 10)
        }
        #expect(sut.last?.count == 5)
    }

    @Test func chunkedCollectionBySize() async throws {
        let sut = Array(1...95).chunked(by: 10)
        
        
        #expect(sut.count == 10)
        sut.forEach { chunk in
            #expect(chunk.count <= 10)
        }
        #expect(sut.last?.count == 5)
    }
    
    @Test func removeDuplicates() async throws {
        let sut = [1,1,2,2,3,3].removedDuplicates()
        
        #expect(sut == [1,2,3])
    }
    
    @Test func lazyRemoveDuplicates() async throws {
        let sut: LazyRemoveDuplicatesSequence = [1,2,3,1,2,3].lazy
            .removedDuplicates()
        
        #expect(sut.run() == [1,2,3])
    }
}
