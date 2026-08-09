//
//  StorePipelineTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
import ReduxCore

struct StorePipelineTests {
    typealias Sut = Store<Int, Int>
    
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
        sut.addEffect { _, _ in
            await recorder.increment()
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        try await Task.sleep(for: .milliseconds(100))
        
        // State: 1 (original) + 1 (middleware) = 2
        #expect(sut.state == 2)
        // Effect fires twice (once per reduced action)
        #expect(await recorder.count == 2)
    }
}

private extension StorePipelineTests {
    //MARK: - Helpers
    func makeSUT() -> Sut {
        Store(initial: 0, scheduler: AsyncSerialScheduler()) { $0 += $1 }
    }
}