//
//  TaskTests.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 12.01.2025.
//

import Testing
import Foundation
import ReduxStream

struct TaskTests {

    @Test func sleepForEstimatedTime() async throws {
        let expected = TimeInterval(1)
        let sleeps = try await ContinuousClock().measure {
            try await Task.sleep(seconds: expected)
        }
        
        #expect(sleeps.components.seconds == Int(expected))
    }

}
