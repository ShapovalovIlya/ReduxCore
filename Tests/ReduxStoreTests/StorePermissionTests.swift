//
//  StorePermissionTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxCore

struct StorePermissionTests {
    typealias Sut = Store<Int, Int>
    
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
}

private extension StorePermissionTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}