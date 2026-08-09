# Changelog

All notable changes to this project will be documented in this file.

## [2.5]

### Added

- `ActionBuilder` for `addMiddleware(_:)` — a middleware body can now mix scalar actions, arrays of actions, Void-valued statements (e.g. logging) and `if`/`else` or `switch` branches; an empty body is allowed and contributes no actions
- Async action effects: `addEffect(_:)` with an `Effect<Action>` runs after each reduction and re-dispatches a follow-up action through the full pipeline — permissions, middleware, and the reducer — producing its own state update and notification; the void-effect flavor `Effect<Void>` remains for side work (logging, analytics, I/O)
- `Effect` closures may `throw`; errors are ignored by the runtime, so dispatch the failure as an action to observe it

### Changed

- **Breaking:** `Effect` typealias is now generic (`Effect<T>`) and may throw — previously a non-generic `(S, A) async -> Void`
- **Breaking:** `removeEffect(withId:)` now returns `Bool` — previously returned the removed `Effect` closure or `nil`
- **Breaking:** `addMiddleware(_:)` now uses a result builder: an explicit `return` statement inside the closure body no longer compiles; write the actions as the implicit result instead
- **Breaking:** `addEffect(_:)` now has two overloads — `Effect<Void>` and `Effect<Action>`
- **Breaking:** the `Store.Hook<T>` typealias was removed (the hooks API was already removed before 2.4.1; the orphaned typealias is gone)
- Doc fixes for effects and middleware

## [2.4.1]

### Changed

- `Store` now constrains its action generic parameter to `Sendable` instead of the stricter `Action` protocol, allowing `Store` to be used with custom `Sendable` action types that do not conform to `Action`
- Untracked Swift Package Manager build artifacts (`.swiftpm`) to keep the repository git index clean

## [2.4]

### Added

- `addPermission(_:)` / `removePermission(withId:)` — permission gate registration: predicates evaluated before each action reaches the reducer; all gates must pass (AND logic)
- `addMiddleware(_:)` / `removeMiddleware(withId:)` — middleware registration: intercepts dispatched actions and returns additional actions to flatten into the pipeline before reduction
- `addEffect(_:)` / `removeEffect(withId:)` — async effect registration: triggered after each reduction, running concurrently in a `TaskGroup` without blocking the reducer
- `ReduxScheduler` protocol and `AsyncSerialScheduler` — generic scheduler abstraction for Store, with async serial execution
- `flush()` on `ReduxScheduler` and `AsyncSerialScheduler` — synchronously drain pending scheduled actions

### Changed

- Store now uses `ReduxScheduler` instead of a strict GCD dependency, enabling pluggable scheduling strategies
- Migrated StoreTests from `ImmediateScheduler` to `AsyncSerialScheduler` for deterministic async testing

## [2.3]

### Added

- `AsyncSequence.last` — returns the last element of an async sequence`
- ``CLAUDE.md` — AI-assisted development guidelines for the repository

### Changed

- `README.md` — expanded documentation with detailed API usage examples, installation instructions, and quick-start guide

## [2.2]

### Added

- (previous changes)
