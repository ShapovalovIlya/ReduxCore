## Core Architecture

### Store<State, Action>

- Actions are reduced in-batch: `dispatch(contentsOf:)` applies multiple actions and notifies subscribers only once.

### StoreSnapshot<Store>

- Equality is O(1) based on internal `Storage` identity, not state content.

### Subscription Models

- `GraphStreamer` is an alias for `StateStreamer<Snapshot>` (the driver variant).

### ReducerDomain Protocol

- Defines composable reducers via `reduce(_ state: inout State, action: Action) -> Action?`.
- Returns an optional follow-up action for chaining.

## Development Commands

```bash
swift build          # Build all targets
swift test           # Run all tests
swift test --filter ReduxCoreTests.StoreTests   # Run a single test suite
```

Tests are in `Tests/ReduxCoreTests/` and cover: Store behavior, thread safety, reducer composition, stream/sequence utilities, sync primitives, and StoreThread.

## Key Design Notes

- Reducers should be pure functions mutating only the `inout State` parameter.
- `snapshot` property (not deprecated `graph`) is the way to get an immutable state + dispatch handle.
- The `Observer` API is deprecated; prefer `StateStreamer`, `ObjectStreamer`, or `store.updates()`.
- `ScopedStore` exists but is not yet public — it projects a subset of state/actions from a base store.
