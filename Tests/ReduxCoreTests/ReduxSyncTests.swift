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
        var sut = Synchronised(state: 0)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 1...100 {
                    sut.withLock { counter in
                        counter += 1
                    }
                }
            }
            group.addTask {
                for _ in 1...100 {
                    sut.withLock { counter in
                        counter += 1
                    }
                }
            }
            await group.waitForAll()
        }
        
        #expect(sut.unsafe == 200)
    }
    
    
}
