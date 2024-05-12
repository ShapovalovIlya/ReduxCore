//
//  StoreThread.swift
//
//
//  Created by Илья Шаповалов on 11.05.2024.
//

import Foundation

public final class StoreThread: Thread {
    public typealias Work = () -> Void
    
    //MARK: - Private properties
    private let condition = NSCondition()
    private var queue: [Work]
    
    //MARK: - init(_:)
    public init(
        _ settings: Settings,
        queue: [Work] = .init()
    ) {
        self.queue = queue
        super.init()
    }
    
    public init(
        _ settings: Settings,
        @QueueBuilder build: @escaping () -> [Work]
    ) {
        self.queue = build()
        super.init()
    }
    
    //MARK: - deinit
    deinit {
        
    }
    
    //MARK: - Public methods
    public override func main() {
        while true {
            condition.lock()
            
            while queue.isEmpty && !isCancelled {
                condition.wait()
            }
            
            
        }
    }
    
    public override func start() {
        
    }
}

public extension StoreThread {
    struct Settings {
        
    }
}
