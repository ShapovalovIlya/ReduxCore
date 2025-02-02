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

//    @Test
//    func synchronised() async throws {
//        await withTaskGroup(of: Void.self) { group in
//            @Synchronised var sut = 0
//            group.addTask {
//                for _ in 1...100 {
//                    sut += 1
//                }
//            }
//            group.addTask {
//                for _ in 1...100 {
//                    sut += 1
//                }
//            }
//            await group.waitForAll()
//            #expect(sut == 200)
//        }
//    }
    
    @Test func rwlockDataRace() async throws {
        let sut = OSReadWriteLock(initial: 0)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 1...100 {
                    sut.withLock { $0 += 1 }
                }
            }
            group.addTask {
                for _ in 1...100 {
                    sut.withLock { $0 += 1 }
                }
            }
            await group.waitForAll()
        }
        
        #expect(sut.unsafe == 200)
    }
    
    @Test func rwLockTryLock() async throws {
        let sut = OSReadWriteLock()
        
        sut.withLock {
            #expect(sut.try() == false)
        }
        #expect(sut.try() == true)
    }
    
    @Test func unfairLockDataRace() async throws {
        let sut = OSUnfairLock(initial: 0)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 1...100 {
                    sut.withLock { $0 += 1 }
                }
            }
            group.addTask {
                for _ in 1...100 {
                    sut.withLock { $0 += 1 }
                }
            }
            await group.waitForAll()
        }
        
        #expect(sut.unsafe == 200)
    }
    
    @Test func unfairLockTryLock() async throws {
        let sut = OSUnfairLock()
        
        sut.withLock {
            #expect(sut.lockIfAvailable() == false)
        }
        #expect(sut.lockIfAvailable() == true)
    }
    
    @Test func unfairLockIfAvailable() async throws {
        let sut = OSUnfairLock()
        var counter = 0
        
        sut.withLockIfAvailable {
            counter += 1
        }
        
        sut.lock()
        sut.withLockIfAvailable {
            counter += 1
        }
        sut.unlock()
        
        #expect(counter == 1)
    }
}
