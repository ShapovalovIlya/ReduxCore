//
//  StoreThread.swift
//
//
//  Created by Илья Шаповалов on 11.05.2024.
//  Source: http://stackoverflow.com/a/22091859

import Foundation

public final class StoreThread: Thread {
    public typealias Work = () -> Void
    
    //MARK: - Private properties
    private let condition = NSCondition()
    private var queue: [Work]
    
    //MARK: - Public properties
    public private(set) var isPaused = false
    
    //MARK: - init(_:)
    public init(
        _ settings: Settings,
        queue: [Work] = .init()
    ) {
        self.queue = queue
        super.init()
        
        stackSize = settings.stackSize
        
    }
    
    public convenience init(
        _ settings: Settings,
        @QueueBuilder build: @escaping () -> [Work]
    ) {
        self.init(settings, queue: build())
    }
    
    //MARK: - deinit
    deinit {
        
    }
    
    //MARK: - Public methods
    /**
     The main entry point routine for the thread.
     You should never invoke this method directly. You should always start your thread by invoking the `.start()` method.
     */
    public override func main() {
        while true {
            condition.lock()
            
            while (queue.isEmpty || isPaused) && !isCancelled {
                condition.wait()
            }
            
            if isCancelled {
                condition.unlock()
                return
            }
            
            let work = queue.removeFirst()
            condition.unlock()
            work()
        }
    }
    
    /// Add a closure to invoke on the thread.
    /// - Parameter work: code block to run.
    ///
    /// Blocks invoke in FIFO.
    public func enqueue(_ work: @escaping Work) {
        condition.withLock {
            queue.append(work)
        }
    }
    
    /**
     Start the thread.
     - Warning: Don't start thread again after it has been cancelled/stopped.
     - SeeAlso: `.start()`
     - SeeAlso: `.pause()`
     */
    public override func start() {
        condition.withLock(super.start)
    }
    
    /**
     Cancels the thread.
     - Warning: Don't start thread again after it has been cancelled/stopped. Use .pause() instead.
     - SeeAlso: `.start()`
     - SeeAlso: `.pause()`
     */
    public override func cancel() {
        condition.withLock(super.cancel)
    }
    
    /**
     Pause the thread. To completely stop it (i.e. remove it from the run-time), use `.cancel()`
     - Warning: Thread is still runnin,
     - SeeAlso: `.start()`
     - SeeAlso: `.cancel()`
     */
    public func pause() {
        condition.withLock { isPaused = true }
    }
    
    /**
     Resume the execution of blocks from the queue on the thread.
     - Warning: Can't resume if thread was cancelled/stopped.
     - SeeAlso: `.start()`
     - SeeAlso: `.cancel()`
     */
    public func resume() {
        condition.withLock { isPaused = false }
    }
    
    /**
     Empty the queue for any blocks that hasn't been run yet.
     - SeeAlso:
     - `.enqueue(_ work: Work)`
     - `.cancel()`
     */
    final func emptyQueue() {
        condition.withLock {
            queue.removeAll(keepingCapacity: true)
        }
    }
}

public extension StoreThread {
    struct Settings {
        public let stackSize: Int
    }
}
