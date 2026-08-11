//
//  StorePermissionTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Foundation
import Testing
import ReduxCore

struct StorePermissionTests {
    
    @Test func testPermissionAllowsAction() async throws {
        let sut = makeSUT()
        
        sut.addPermission { _, _ in true }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }
    
    @Test func testPermissionBlocksAction() async throws {
        let sut = makeSUT()
        
        sut.addPermission { _, _ in false }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 0)
    }
    
    @Test func testMultiplePermissionsAllMustPass() async throws {
        let sut = makeSUT()
        
        sut.addPermission { _, _ in true }
        sut.addPermission { _, _ in true }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
        
        // Now add a blocking permission
        sut.addPermission { _, _ in false }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }
    
    @Test func testRemovePermissionRestoresAccess() async throws {
        let sut = makeSUT()
        
        let id = sut.addPermission { _, _ in false }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 0)
        
        sut.removePermission(withId: id)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }

    @Test func testPermissionShortCircuitsOnFirstFalse() async throws {
        let sut = makeSUT()
        let tap = LockedTap()

        sut.addPermission { _, _ in
            tap.record(1)
            return false
        }
        sut.addPermission { _, _ in
            tap.record(2)
            return false
        }

        sut.dispatch(1)
        await sut.scheduler.flush()

        // Evaluation stops at the first `false`: exactly one gate is invoked,
        // regardless of Dictionary iteration order (both gates return false).
        #expect(sut.state == 0)
        #expect(tap.values.count == 1)
    }

    @Test func testPermissionSeesPreBatchState() async throws {
        let sut = makeSUT()
        let tap = LockedTap()

        sut.addPermission { state, _ in
            tap.record(state)
            return true
        }

        sut.dispatch(contentsOf: [1, 1])
        await sut.scheduler.flush()

        // Every gate check in a batch sees the pre-batch state (0), never the
        // intermediate state after the first action was reduced. Each action
        // is gate-checked twice: before and after middleware.
        #expect(sut.state == 2)
        #expect(tap.values == [0, 0, 0, 0])
    }

    @Test func testRemovePermissionReturnsRemovedGate() async throws {
        let sut = makeSUT()

        let id = sut.addPermission { _, _ in false }

        let removed = sut.removePermission(withId: id)
        #expect(removed != nil)
        #expect(removed?(0, 1) == false)
        #expect(sut.removePermission(withId: id) == nil)
        #expect(sut.removePermission(withId: UUID()) == nil)
    }

    @Test func testPermissionRegistryConcurrentMutation() async throws {
        let sut = Store(initial: 0) { $0 += $1 }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 0..<200 {
                    sut.dispatch(1)
                }
            }
            group.addTask {
                for _ in 0..<200 {
                    let id = sut.addPermission { _, _ in true }
                    _ = sut.removePermission(withId: id)
                }
            }
            await group.waitForAll()
        }

        await sut.scheduler.flush()

        // Every churned gate permits actions, so concurrent add/remove must
        // not lose or duplicate any dispatch: 0 + 200.
        #expect(sut.state == 200)
    }
}
