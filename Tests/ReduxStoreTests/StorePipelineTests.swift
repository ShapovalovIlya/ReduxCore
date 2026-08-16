//
//  StorePipelineTests.swift
//
//
//  Created by Илья Шаповалов on 23.12.2023.
//

import Testing
@testable import ReduxCore

struct StorePipelineTests {
    
    @Test func testPermissionMiddlewareEffectPipeline() async {
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
        let id = sut.addEffect { _, _, _ in
            await recorder.increment()
        }
        
        sut.dispatch(1)
        await sut.scheduler.flush()
        await sut.runningEffects[id]?.value
        
        // State: 1 (original) + 1 (middleware) = 2
        #expect(sut.state == 2)
        // Effect fires twice (once per reduced action)
        #expect(await recorder.count == 2)
    }

}
