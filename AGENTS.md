# Behavioral guidelines merged with project-specific instructions

**Tradeoff:** Bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them. Don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't improve adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it. Don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" means "Write tests for invalid inputs, then make them pass"
- "Fix the bug" means "Write a test that reproduces it, then make it pass"
- "Refactor X" means "Ensure tests pass before and after"

For multi-step tasks, state a brief plan with verification steps.

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
