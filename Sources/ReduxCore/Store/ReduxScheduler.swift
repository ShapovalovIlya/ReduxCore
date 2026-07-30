//
//  ReduxScheduler.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 10.06.2026.
//

import Foundation

/// A protocol that abstracts work scheduling to enable deterministic behavior in different environments.
///
/// Use `ReduxScheduler` to decouple your Redux store from specific dispatch queues or threads.
/// This abstraction is critical for testing, allowing you to swap asynchronous production queues
/// with synchronous or controlled execution pipelines in your test suite.
///
/// ## Overview
/// The protocol defines two overloads of ``schedule(_:)`` — one for synchronous closures
/// and one for asynchronous closures. Implementations must preserve the architectural
/// guarantees of the store, most importantly **serial execution order**.
///
/// ### Thread Safety
/// Implementations must ensure that work blocks are executed in accordance with the architectural
/// guarantees of the store (e.g., preserving serial execution order for actions).
///
/// ## Choosing an Overload
/// - Use the synchronous overload when the work closure does not call `await`.
/// - Use the asynchronous overload when the work closure needs to perform Swift
///   Concurrency operations (network calls, database queries, etc.).
///
/// ## Built-in Implementations
/// - ``DispatchQueue`` — the original GCD-backed scheduler. Its asynchronous overload
///   uses a semaphore-based bridge that blocks the dispatch thread during suspension.
/// - ``AsyncSerialScheduler`` — the recommended scheduler for async workloads. It uses
///   an `AsyncStream` consumed by a single `Task` loop, never blocking a thread.
public protocol ReduxScheduler {

    /// Schedules a synchronous block of work for execution.
    ///
    /// Use this overload when the work does not require Swift Concurrency.
    /// The block is executed according to the scheduler's execution policy
    /// (typically serial for store-related operations).
    ///
    /// - Parameter work: The closure containing the operations to be executed.
    func schedule(_ work: @escaping @Sendable () -> Void)

    /// Schedules an asynchronous block of work for execution.
    ///
    /// Use this overload when the work needs to `await` asynchronous operations
    /// such as network requests, database queries, or other Swift Concurrency tasks.
    /// The scheduler is responsible for preserving the serial execution order of
    /// work items, even across suspension points.
    ///
    /// - Parameter work: An async closure to be scheduled for execution.
    func schedule(_ work: @escaping @Sendable () async -> Void)

    /// Waits for all previously scheduled work to complete.
    ///
    /// This method suspends until every work item submitted via ``schedule(_:)``
    /// (both sync and async overloads) prior to the call has finished execution.
    /// It guarantees **serial drain order**: scheduled items added after `flush()`
    /// are not waited on.
    ///
    /// ## When to Use
    /// - **Testing** — ensure the scheduler has settled before asserting state.
    /// - **Barrier points** — in async code that needs to observe the effects of
    ///   all prior scheduled work before proceeding.
    ///
    /// ## Implementation Requirements
    /// Conforming types must preserve the serial execution guarantee: after
    /// `flush()` returns, any work that was scheduled before the call must be
    /// fully executed. Work scheduled concurrently with or after `flush()` may
    /// or may not be included, but the implementation must not deadlock.
    ///
    /// - Important: This method is `async`. It does not block the calling thread;
    ///   it suspends until the drain completes.
    func flush() async
}

extension DispatchQueue: ReduxScheduler {
    
    /// The default dedicated serial queue used for state mutations and action processing.
    ///
    /// This queue is configured with highly aggressive performance traits suited for predictable UI updates:
    /// - **QoS (`.userInteractive`)**: Ensures that state reductions are prioritized alongside animations and user input.
    /// - **Autorelease Frequency (`.workItem`)**: Cleans up temporary allocations immediately after each reduced action, preventing memory spikes.
    /// - **Target Queue (`.global`)**: Relies on the global system thread pool to optimize OS resource allocation.
    ///
    /// ### Usage
    /// ```swift
    /// let store = ReduxStore(
    ///     initialState: AppState(),
    ///     scheduler: DispatchQueue.storeScheduler
    /// )
    /// ```
    public static let storeScheduler = DispatchQueue(
        label: "com.reduxCore.StoreQueue",
        qos: .userInteractive,
        autoreleaseFrequency: .workItem,
        target: .global(qos: .userInteractive)
    )

    /// Schedules asynchronous work while preserving serial execution order.
    ///
    /// This implementation uses a `DispatchSemaphore` bridge to block the serial
    /// queue's current work item until the async operation completes. This ensures
    /// that the next item in the queue does not start before the previous async
    /// work finishes.
    ///
    /// ## Thread-Blocking Tradeoff
    /// - **Pros:** Strict serial ordering is preserved for async closures without
    ///   requiring architectural changes.
    /// - **Cons:** The dispatch thread is blocked (though not spinning) while the
    ///   async work is suspended. This ties up a system thread for the duration of
    ///   the async operation, which may reduce overall throughput under heavy
    ///   async workloads.
    ///
    /// For most store use-cases this overhead is negligible because actions are
    /// reduced quickly. For high-throughput async scenarios, prefer
    /// ``AsyncSerialScheduler``, which uses Swift Concurrency's cooperative
    /// thread pool and never blocks a thread during suspension.
    ///
    /// - Parameter work: An async closure to execute on this queue. The closure
    ///   is wrapped in an unstructured `Task` and its completion is awaited via
    ///   a semaphore before the next queue item is dequeued.
    public func schedule(_ work: @escaping @Sendable () async -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        schedule {
            Task {
                defer {
                    semaphore.signal()
                }
                await work()
            }
            semaphore.wait()
        }
    }

    public func flush() async {
        await withCheckedContinuation { continuation in
            schedule { continuation.resume() }
        }
    }
}

/// A scheduler that executes work items strictly serially with full async/await support.
///
/// `AsyncSerialScheduler` is the recommended scheduler for ``Store`` when you need
/// asynchronous reducers, side effects, or middleware, while preserving the
/// architectural guarantee that actions are processed one at a time.
///
/// ## Overview
/// Unlike `DispatchQueue`-based schedulers, `AsyncSerialScheduler` never blocks a
/// thread during async suspension. Instead, it uses an internal `AsyncStream`
/// consumed by a single Swift Concurrency `Task` running a `for await` loop:
///
/// ```
/// ┌──────────┐   yield()   ┌──────────────────┐   for await   ┌──────────────┐
/// │ dispatch │ ──────────▶ │  AsyncStream     │ ────────────▶ │  Task Loop   │
/// │  call    │             │  (unbounded)     │               │  (serial)    │
/// └──────────┘             └──────────────────┘               └──────┬───────┘
///                                                                    │
///                                                         await work() ──▶ next
/// ```
///
/// ## Strict Serial Execution
/// The `for await` loop processes one work item at a time and does not start
/// the next item until the previous one completes — including any `await`
/// suspensions inside the work closure. This is fundamentally different from
/// bridging async work through a `DispatchQueue` (which blocks a thread or
/// loses ordering), and from unstructured `Task` groups (which may execute
/// concurrently).
///
/// ## Priority
/// The scheduler creates its backing `Task` with the priority specified at
/// initialisation. The default is `.userInitiated`, which maps to the same
/// QoS band as `.userInteractive` in Dispatch. Work items inherit this
/// priority throughout their async execution, including any subtasks they
/// spawn.
///
/// ## Thread Safety
/// `AsyncSerialScheduler` is explicitly `Sendable`.. This means
/// ``schedule(_:)`` can be invoked from synchronous contexts (like a dispatch
/// from a non-`async` function) without special handling.
///
/// ## Memory and Lifecycle
/// - **Buffering:** The underlying `AsyncStream` uses an unbounded buffering
///   policy. All scheduled work items are retained until the loop processes
///   them. Under extreme backpressure (producing faster than the async work
///   can complete), memory may grow. For typical store dispatches this is
///   not a concern.
/// - **Deinitialization:** When the scheduler is deallocated, the stream
///   continuation is finished and the backing task is cancelled. Any work
///   item currently executing is allowed to complete (Swift Concurrency
///   cooperative cancellation applies), but remaining enqueued items are
///   discarded.
///
/// ## Usage
/// ```swift
/// // As the store's scheduler (recommended)
/// let store = Store(
///     initial: AppState(),
///     scheduler: AsyncSerialScheduler(),
///     reducer: { state, action in /* ... */ }
/// )
///
/// // With custom priority
/// let highPriorityScheduler = AsyncSerialScheduler(priority: .userInteractive)
/// ```
///
/// ## Comparing Scheduler Strategies
/// | Aspect | DispatchQueue (semaphore bridge) | AsyncSerialScheduler |
/// |--------|----------------------------------|----------------------|
/// | Thread blocking | Blocks dispatch thread during async suspension | No blocking — thread is released |
/// | Serial ordering | ✅ Guaranteed | ✅ Guaranteed |
/// | Async context | ⚠️ Via semaphore bridge | ✅ Native Task loop |
/// | Priority model | DispatchQoS | TaskPriority |
/// | Backpressure | Serial queue (max one pending) | Unbounded stream |
///
/// - Important: `AsyncSerialScheduler` is designed for the store's internal
///   scheduling. It is not a general-purpose task executor and does not
///   provide features such as concurrent execution, delayed dispatch, or
///   cancellation by identifier.
///
public final class AsyncSerialScheduler: ReduxScheduler, Sendable {
    public typealias Work = @Sendable () async -> Void
    private let (stream, continuation) = AsyncStream.makeStream(of: Work.self)
    private let task: Task<Void, Never>

    /// Creates an `AsyncSerialScheduler` with the specified task priority.
    ///
    /// The scheduler spawns a single `Task` that runs a `for await` loop over
    /// an internal `AsyncStream`. Every work item submitted via
    /// ``schedule(_:)`` is enqueued into this stream and executed one at a time.
    ///
    /// - Parameter priority: The `TaskPriority` for the backing task and all
    ///   work items it executes. The default is `.userInitiated`, which Swift
    ///   maps to the same QoS band as `DispatchQoS.userInteractive`.
    public init(priority: TaskPriority = .userInitiated) {
        self.task = Task(priority: priority) { [stream] in
            for await work in stream {
                await work()
            }
        }
    }

    deinit {
        continuation.finish()
        task.cancel()
    }

    /// Schedules a synchronous closure for execution on the serial async loop.
    ///
    /// The closure is bridged into an async context by wrapping it in `{ work() }`
    /// and yielding it to the internal stream. Serial ordering is guaranteed:
    /// the next scheduled item will not begin until this closure returns.
    ///
    /// - Parameter work: A synchronous closure to execute. It is invoked from
    ///   within the backing task's `for await` loop.
    public func schedule(_ work: @escaping @Sendable () -> Void) {
        continuation.yield { work() }
    }

    /// Schedules an asynchronous closure for execution on the serial async loop.
    ///
    /// The closure is yielded directly to the internal stream. Because the
    /// consuming `for await` loop awaits each work item, the closure may
    /// contain arbitrary `await` calls without breaking serial ordering or
    /// blocking a system thread.
    ///
    /// - Parameter work: An async closure to execute. The closure runs with
    ///   the scheduler's configured `TaskPriority`.
    public func schedule(_ work: @escaping @Sendable () async -> Void) {
        continuation.yield(work)
    }

    /// Waits for all previously scheduled work to complete.
    ///
    /// `flush()` enqueues a sentinel work item at the end of the internal
    /// `AsyncStream` and suspends until it executes. Because the backing
    /// `Task` loop processes items serially (``schedule(_:)``), this guarantees
    /// that every work item enqueued before the `flush()` call has finished
    /// before the method returns.
    ///
    /// ## Mechanism
    /// ```
    /// schedule(work1) ──┐
    /// schedule(work2) ──┤
    /// flush():          │
    ///   schedule(resume)─┤──→ for await ──→ work1() → work2() → resume()
    ///                    │                              └── continuation.resume()
    ///                  FIFO ─── serial order ───▶
    /// ```
    ///
    /// ## Usage
    /// ```swift
    /// let scheduler = AsyncSerialScheduler()
    /// scheduler.schedule { print("first") }
    /// scheduler.schedule { print("second") }
    /// await scheduler.flush()
    /// // Both closures have completed at this point.
    /// ```
    ///
    /// ## Thread Safety
    /// This method is thread-safe and can be called from any task or thread.
    /// It uses ``withCheckedContinuation`` under the hood, which resumes on
    /// the same executor as the scheduler's backing task.
    ///
    /// - Note: Work scheduled **after** `flush()` is not waited on. Call
    ///   `flush()` again if you need to drain subsequent work.
    public func flush() async {
        await withCheckedContinuation { continuation in
            schedule { continuation.resume() }
        }
    }
}
