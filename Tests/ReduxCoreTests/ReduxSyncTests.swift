//
//  SyncronizedTests.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 22.12.2024.
//

import Foundation
import Testing
import ReduxSync

struct ReduxSyncTests {

    @Test
    func synchronised() async throws {
        await withTaskGroup(of: Void.self) { group in
            @Synchronised var sut = 0
            group.addTask {
                for _ in 1...100 {
                    sut += 1
                }
            }
            group.addTask {
                for _ in 1...100 {
                    sut += 1
                }
            }
            await group.waitForAll()
            #expect(sut == 200)
        }
    }
    
    @Test func rwlock() async throws {
        let sut = OSReadWriteLock(initial: 1)
        
        
    }
}
