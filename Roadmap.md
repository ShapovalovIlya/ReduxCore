# ReduxCore Library Evolution Roadmap

## Introduction

**Current status: v2.4.1.** The library already ships with permission gates, middleware, async effects, pluggable schedulers (`ReduxScheduler` / `AsyncSerialScheduler` with `flush()`), stream-based subscriptions (drivers / streamers), an `AsyncStream` observation layer, and a committed `ReducerDomain` module.

Remaining strategic work is concentrated in three areas:

- **Effect system** — effects cannot re-dispatch actions and cannot be cancelled.
- **ScopedStore** — finished code exists but is frozen: not public, glued to Combine + `DispatchQueue.main`.
- **Developer experience** — no devtools (history / diff / time-travel), no memoized selectors, no state persistence.

---

## Phase 1: Async Effects — Critical ✅

Registration and concurrent execution are already done (v2.4). The remaining gaps:

### Task 1.1 — Effects can return follow-up actions
Returned actions are re-dispatched into the store through the **full pipeline** (permissions → middleware → reducer). This makes network → load-result flows expressible:

### Task 1.2 — Effect cancellation with `UUID`
### Task 1.3 — Bounded effect concurrency

---

## Phase 2: State Isolation — High

### Task 2.1 — Public ScopedStore API

Code exists in `Sources/ReduxCore/Store/ScopedStore.swift` but is **not shipped**:

- `/*public */` access modifiers throughout; `scoped(_:action:)` is **commented out** in the `ReduxStore` protocol.
- Hard-wired to Combine (`base.objectWillChange.receive(on: .main).sink`) and `DispatchQueue.main` — a hidden main-thread dependency and an extra framework requirement.
- Zero tests.

Target API:

```swift
func scoped<S, A>(
    _ scope: @escaping @Sendable (State) -> S,
    action embed: @escaping @Sendable (A) -> Action
) -> ScopedStore<Self, S, A>
```

Work items:

1. Make `ScopedStore` public; add `scoped(_:action:)` to `ReduxStore` with a default implementation `ScopedStore(base:scope:embedAction:)`.
2. Replace the Combine `sink` + `receive(on: .main)` with `onChange` / `ReduxScheduler`-based observation — the existing `ScopedStore.onChange` property already sketches the correct shape.
3. Emit only when the projected slice actually changes, avoiding unnecessary downstream updates.
4. Type-safe boundary: parent state/action types must not leak through the scoped handle.
5. Tests: projection, action embedding, slice-change-only emission, parent-store lifecycle (no retain cycles — cancellables must not keep the parent alive).

📝 `ChildReducer` + `Prism` (in `ReducerDomain`) are the reducer-side counterpart — scoped stores are the view-side counterpart. Ship them together in docs/examples.

---

## Phase 3: Developer Experience — High

The library already ships debug helpers (`Action.dumped()`, `DataDriven.dumped()`); make them part of a real devtools story.

### Task 3.1 — Transition history + diff logging

Record ordered triples `(action, oldState, newState)`. The hook point already exists: `dispatcher` holds both `current` (pre-reduction) and `updated` (post-reduction) in one place.

- `store.history()` returns `AsyncStream<HistoryEntry<S, A>>`; keep a bounded ring buffer (e.g. last 200 entries).
- `HistoryEntry` exposes the `StoreSnapshot` after the transition — the same value that time-travel restores.

### Task 3.2 — Time-travel restore

```swift
let entry = await store.history().first { $0.action == .resetToImport }
store.restore(entry.snapshotAfter)
```

Trivial in this architecture: `StoreSnapshot` is already immutable and `_state` lives in an `OSUnfairLock` — `restore` = write the value + notify subscribers once. Enables undo/redo and a devtools UI without new machinery.

### Task 3.3 — Diffable output

For `Equatable` states, print only the changed fields (sibling-path diff); otherwise fall back to `dumped()`. Feed this into the devtools log and `#if DEBUG` console tracing.

### Task 3.4 — Memoized selectors

```swift
for await name in store.select(\.user.name) { ... }
```

`select(_:)` returns an `AsyncStream` of the projected value that yields **only when it actually changes** by reusing the existing `SequenceFX.removeDuplicates` machinery (~20 lines). Removes the need for every subscriber to dedupe manually.

---

## Phase 4: State Persistence — Medium

```swift
public protocol PersistableState: Codable {
    var persistenceKey: String { get }
}
```

States conforming to `PersistableState` are automatically serialized to disk on change and restored on store creation. The library provides a `PersistenceMiddleware` that watches state changes, serializes conforming slices, and hydrates them on initialization. Non-conforming states remain ephemeral. The persistence layer is pluggable — the default writer uses `UserDefaults` or file-based storage, but consumers can provide custom backends.

---

## Phase 5: Cleanup & Lifecycle — Low

### Task 5.1 — Remove deprecated `Observer` API

`GraphObserver`, `observers`, `notify(_:)`, and the deprecated `subscribe(GraphObserver)` overloads. Deprecated since v1; carry a release-note migration path to `StateStreamer` / `ObjectStreamer`.

### Task 5.2 — Finish `graph` → `snapshot` migration

`graph` is deprecated and renamed to `snapshot`. Remove the alias in a future minor and warn about the rename pattern in the docs.

### Task 5.3 — Streamer lifecycle hardening

Verify deinit-cleanup for every subscription kind: `StateStreamer.deinit` finishes the continuation — confirm the store always drops the entry (including `.terminated` yields in `dispatcher`), and that `finish()` semantics on an installed driver don't leave stale entries behind.

---

## Summary

| Phase | Task | Priority |
|-------|------|----------|
| 1 — Async Effects | 1.1 Re-dispatch of returned actions | Critical |
| 1 — Async Effects | 1.2 `EffectID` cancellation + lifecycle | Critical |
| 1 — Async Effects | 1.3 Bounded effect concurrency | Medium |
| 2 — State Isolation | 2.1 Public `ScopedStore` | High |
| 3 — DevTools | 3.1 History + diff logging | High |
| 3 — DevTools | 3.2 Time-travel restore | High |
| 3 — DevTools | 3.3 Diffable output | Medium |
| 3 — DevTools | 3.4 Memoized `select(_:)` | Medium |
| 4 — Persistence | 4.1 `PersistableState` | Medium |
| 5 — Cleanup | 5.1–5.3 Deprecation & lifecycle hardening | Low |

**Execution order:** start with 1.1 + 1.2 (effect re-dispatch + cancellation) — the highest-value functional gap and a prerequisite for clean debounce/network flows. Then 2.1 (ScopedStore) which is largely written already and unblocks module-boundary adoption. Devtools (Phase 3) can proceed in parallel and should be demoed with the new effect API. Phase 5 is release-hygiene before a 3.0.
