//
//  SyncronizedTests.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 22.12.2024.
//

import Foundation
import Testing
import ReduxStream

struct SyncronizedTests {
    @Test func raceCondition() async throws {
        @Syncronized var sut = 0
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: .high) {
                for _ in 0...1_000_000 {
                    _sut.sync { $0 += 1 }
//                    sut += 1
                }
            }
            group.addTask(priority: .low) {
                for _ in 0...1_000_000 {
                   _sut.sync { $0 += 1 }
//                    sut += 1
                }
            }
            await group.waitForAll()
        }
        
        #expect(sut == 2_000_002)
    }
}
