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
    
    /**
     Returns an initialized `StoreThread` object.
     - Parameter settings: object that contains necessary settings for thread.
     - Parameter queue: Array of `Work` items, that represent code block that need to be executed on this thread.
     */
    public init(
        _ settings: Settings = .default,
        queue: [Work] = .init()
    ) {
        self.queue = queue
        super.init()
        
        settings.stackSize.map { size in
            stackSize = size
        }
        settings.priority.map { p in
            threadPriority = p
        }
        qualityOfService = settings.qos
        name = settings.name
    }
    
    /**
     
     */
    public convenience init(
        _ settings: Settings = .default,
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
    
    /**
     Add a closure to invoke on the thread.
     - Parameter work: code block to run.
     
     Blocks invoke in FIFO.
     */
    public func enqueue(_ work: @escaping Work) {
        condition.protect {
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
        condition.protect(super.start)
    }
    
    /**
     Cancels the thread.
     - Warning: Don't start thread again after it has been cancelled/stopped. Use .pause() instead.
     - SeeAlso: `.start()`
     - SeeAlso: `.pause()`
     */
    public override func cancel() {
        condition.protect(super.cancel)
    }
    
    /**
     Pause the thread. To completely stop it (i.e. remove it from the run-time), use `.cancel()`
     - Warning: Thread is still running,
     - SeeAlso: `.start()`
     - SeeAlso: `.cancel()`
     */
    public func pause() {
        condition.protect { isPaused = true }
    }
    
    /**
     Resume the execution of blocks from the queue on the thread.
     - Warning: Can't resume if thread was cancelled/stopped.
     - SeeAlso: `.start()`
     - SeeAlso: `.cancel()`
     */
    public func resume() {
        condition.protect { isPaused = false }
    }
    
    /**
     Empty the queue for any blocks that hasn't been run yet.
     
     - SeeAlso:
     - `.enqueue(_ work: Work)`
     - `.cancel()`
     */
    public func emptyQueue() {
        condition.protect {
            queue.removeAll(keepingCapacity: true)
        }
    }
}

public extension StoreThread {
    
    /// Represent `StoreThread` settings.
    ///
    /// Might be useful when you need custom behavior of `StoreThread` object.
    struct Settings {
        public let name: String
        public let qos: QualityOfService
        public let stackSize: Int?
        public let priority: Double?
        
        init(
            name: String,
            qos: QualityOfService,
            stackSize: Int?,
            priority: Double?
        ) {
            self.name = name
            self.qos = qos
            self.stackSize = stackSize.map { max(16384, $0) }
            self.priority = priority
        }
        
        /// Default settings instructions
        public static let `default` = Settings(
            name: "StoreThread",
            qos: .default,
            stackSize: nil,
            priority: nil
        )
    }
}
