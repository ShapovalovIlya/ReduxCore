//
//  NotificationStreamTests.swift
//  
//
//  Created by Илья Шаповалов on 15.05.2024.
//

import XCTest
import ReduxStream

final class NotificationStreamTests: XCTestCase {
    private var notifications: NotificationCenter!
    
    override func setUp() async throws {
        try await super.setUp()
        
        notifications = .default
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        notifications = nil
    }
    
    func test_emitNotification() async {
        let notify = Notification.Name("baz")
        let sut = notifications.stream(of: notify)
        let arr = NSMutableArray()
        
        let task = Task {
            for await name in sut.map(\.name) {
                arr.add(name)
            }
        }
        
        notifications.post(name: notify, object: nil)
        notifications.post(name: notify, object: nil)
        notifications.post(name: notify, object: nil)
        
        await task.value
        XCTAssertEqual(arr, [notify, notify, notify])
    }
}
