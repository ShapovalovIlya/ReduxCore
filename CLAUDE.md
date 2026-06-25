# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReduxCore is a Swift package implementing a Redux-style, unidirectional state management system. It provides a thread-safe `Store<State, Action>` as the core abstraction, inspired by Redux and The Composable Architecture.

- **Swift tools version:** 6.3 (also compatible with 5.8, 6.0, 6.2)
- **Platforms:** iOS 13+, macOS 10.15+
- **Swift Concurrency:** StrictConcurrency is enabled as an experimental feature on ReduxCore, ReduxSync, and ReduxStream targets

## Package Structure

The package exports 4 library products and includes 3 internal utility targets:

| Product | Target | Description |
|---------|--------|-------------|
| ReduxCore | ReduxCore | Main store, snapshot, scheduler, observer APIs |
| ReduxStream | ReduxStream | AsyncStream-based state streaming (`StateStreamer`) |
| ReduxSync | ReduxSync | Thread-safety primitives (`OSUnfairLock`, `OSReadWriteLock`, `@Synchronised`) |
| ReducerDomain | ReducerDomain | Composable reducer protocol and result builder (`@ReducerCombine`) |
| — | CoWBox | Copy-on-Write boxed value type |
| — | SequenceFX | AsyncSequence/Sequence extensions (throttle, removeDuplicates, withUnretained) |
| — | StoreThread | Dedicated NSThread-based work queue with pause/resume |

**Dependency graph:** ReduxCore depends on all other targets. ReduxStream depends on SequenceFX.

## Core Architecture

### Store<State, Action>
- Thread-safe state container using `OSUnfairLock<State>` for state access and a `ReduxScheduler` (default: serial `DispatchQueue` at `.userInteractive` QoS) for action dispatch.
- Conforms to `@dynamicMemberLookup` so `store.someProperty` forwards to `snapshot.someProperty`.
- Actions are reduced in-batch: `dispatch(contentsOf:)` applies multiple actions and notifies subscribers only once.

### StoreSnapshot<Store>
- Lightweight, immutable snapshot of state with a weak store reference (no retain cycles).
- Supports `@dynamicMemberLookup` for ergonomic property access.
- Equality is O(1) based on internal `Storage` identity, not state content.

### Subscription Models
- **Drivers** (`GraphStreamer` = `StateStreamer<Snapshot>`): strongly retained by the store via `install(_:)` / `uninstall(_:)`.
- **Streamers** (`ObjectStreamer<Snapshot>`): weakly retained via `subscribe(_:)` / `unsubscribe(_:)`.
- **AsyncStream**: `store.updates()` returns an `AsyncStream<Snapshot>` for one-off `for await` consumption.

### ReducerDomain Protocol
- Defines composable reducers via `reduce(_ state: inout State, action: Action) -> Action?`.
- Returns an optional follow-up action for chaining.
- Compose multiple reducers with `@ReducerCombine` result builder on `var body`.

## Development Commands

```bash
swift build          # Build all targets
swift test           # Run all 37 tests (7 suites)
swift test --filter ReduxCoreTests.StoreTests   # Run a single test suite
```

Tests are in `Tests/ReduxCoreTests/` and cover: Store behavior, thread safety, reducer composition, stream/sequence utilities, sync primitives, and StoreThread.

## Key Design Notes

- Reducers should be pure functions mutating only the `inout State` parameter.
- `snapshot` property (not deprecated `graph`) is the way to get an immutable state + dispatch handle.
- The `Observer` API is deprecated; prefer `StateStreamer`, `ObjectStreamer`, or `store.updates()`.
- `ScopedStore` exists but is not yet public — it projects a subset of state/actions from a base store.
- All targets use `@inlinable` extensively for performance-critical paths.
