//
//  StorePipelineTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxCore

struct StorePipelineTests {
    
    @Test func testPermissionMiddlewareEffectPipeline() async throws {
        let sut = makeSUT()
        
        actor Recorder {
            var count = 0
            func increment() { count += 1 }
        }
        let recorder = Recorder()
        
        // Permission allows
        sut.addPermission { _, _ in true }
        // Middleware adds extra action
        sut.addMiddleware { _, _ in [1] }
        // Effect records
        sut.addEffect { _, _, _ in
            await recorder.increment()
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        await waitUntil { await recorder.count == 2 }
        
        // State: 1 (original) + 1 (middleware) = 2
        #expect(sut.state == 2)
        // Effect fires twice (once per reduced action)
        #expect(await recorder.count == 2)
    }

    @Test func testStoreDeallocatesWithInstalledRegistries() async throws {
        var sut: Store<Int, Int>? = Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
        weak var weakSut = sut

        if let s = sut {
            s.addPermission { _, _ in true }
            s.addMiddleware { _, _ in [Int]() }
            s.addEffect { _, _, _ in () }
            s.dispatch(1)
            await s.scheduler.flush()
        }

        #expect(sut?.state == 1)

        // Drop the only strong reference: registry closures that do not
        // capture the store must not prevent deallocation.
        sut = nil
        let deallocated = await waitUntil { weakSut == nil }
        #expect(deallocated)
    }

}
