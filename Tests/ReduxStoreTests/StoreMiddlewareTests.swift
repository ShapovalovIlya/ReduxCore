//
//  StoreMiddlewareTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxCore

struct StoreMiddlewareTests {
    typealias Sut = Store<Int, Int>
    
    @Test func testMiddlewareAddsActions() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in [1] }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 2)
    }
    
    @Test func testMultipleMiddlewareAccumulate() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in [1] }
        sut.addMiddleware { _, _ in 1 }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 3)
    }
    
    @Test func testRemoveMiddlewareStopsInterception() async throws {
        let sut = makeSUT()
        
        let id = sut.addMiddleware { _, _ in [1] }
        
        sut.removeMiddleware(withId: id)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 1)
    }
    
    @Test func testMiddlewareCanReturnSingleAction() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in 1 }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 2)
    }
    
    @Test func testMiddlewareBuilderConditionalIfElse() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, action in
            if action == 1 { 2 } else { 3 }
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        #expect(sut.state == 3)
        
        sut.dispatch(2)
        await sut.scheduler.flush()
        #expect(sut.state == 8)
    }
    
    @Test func testMiddlewareBuilderOptionalIf() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, action in
            if action == 1 { 2 }
        }
        
        sut.dispatch(2)
        await sut.scheduler.flush()
        #expect(sut.state == 2)
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        #expect(sut.state == 5)
    }
    
    @Test func testMiddlewareBuilderSwitch() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, action in
            switch action {
            case 1: [2, 3]
            case 2: 4
            default: 0
            }
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        #expect(sut.state == 6)
        
        sut.dispatch(2)
        await sut.scheduler.flush()
        #expect(sut.state == 12)
    }
    
    @Test func testMiddlewareBuilderMultipleComponents() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in
            1
            2
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        #expect(sut.state == 4)
    }
    
    @Test func testMiddlewareOutputIsCheckedByPermissions() async throws {
        let sut = makeSUT()
        
        // Middleware echoes the dispatched action and adds an extra action.
        sut.addMiddleware { _, action in action }
        sut.addMiddleware { _, _ in 2 }
        // A permission that blocks only the action the middleware adds.
        sut.addPermission { _, action in action != 2 }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        // [1, 1] reduced: the original action passes the permission, the echo
        // passes it again, but the middleware's extra 2 is dropped on the
        // second permission check. Middleware output is not re-run through
        // middleware.
        #expect(sut.state == 2)
    }
    
    @Test func testMiddlewareEmptyBodyContributesNothing() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        // The empty body produces no middleware actions; the original
        // action still flows through the pipeline and is reduced once.
        #expect(sut.state == 1)
    }
    
    @Test func testMiddlewareVoidStatementContributesNothing() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in logDebug("middleware ran") }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        // A Void-valued statement (e.g. logging) contributes no actions;
        // the original action still flows through the pipeline.
        #expect(sut.state == 1)
    }
    
    @Test func testMiddlewareMixedScalarAndArrayConcatenation() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, _ in
            1
            [2, 3]
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        
        // Middleware produces [1, 2, 3] in flatMap source order, plus the
        // original action 1: 0 + 1 + 1 + 2 + 3 = 7.
        #expect(sut.state == 7)
    }
    
    @Test func testMiddlewareBranchesWithTrailingScalar() async throws {
        let sut = makeSUT()
        
        sut.addMiddleware { _, action in
            if action == 1 { [2] } else { [3] }
            4
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        // Original 1 + branch [2] + trailing 4 = 7.
        #expect(sut.state == 7)
        
        sut.dispatch(2)
        await sut.scheduler.flush()
        // State 7 + original 2 + branch [3] + trailing 4 = 16.
        #expect(sut.state == 16)
    }
}

private extension StoreMiddlewareTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
    
    // A Void-valued helper used to prove Void statements are allowed in the
    // ActionBuilder body.
    func logDebug(_ message: String) { }
}