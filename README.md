# ReduxCore: Unidirectional State Management for Swift

A thread-safe, observable state container for Swift applications. Inspired by Redux and The Composable Architecture, ReduxCore provides a robust foundation for managing application state and dispatching actions in a predictable, unidirectional data flow.

- **Predictable State:** All changes driven by actions and pure reducer functions
- **Thread Safety:** Mutations on a dedicated scheduler, safe from any thread
- **Async Observation:** `for await` state streams with Swift Concurrency
- **Flexible Subscriptions:** Strong (drivers) and weak (streamers) models
- **Encapsulation:** `StoreSnapshot` exposes only state + dispatch to child components
- **Composable Reducers:** `@ReducerCombine` result builder for modular logic

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ShapovalovIlya/ReduxCore.git", branch: "main")
]
```

Or via Xcode: **File > Add Package Dependencies...**

The package provides four library products:

| Product | Description |
|---------|-------------|
| `ReduxCore` | Main store, snapshot, and scheduler APIs |
| `ReduxStream` | `StateStreamer` for async state broadcasting |
| `ReduxSync` | Thread-safety primitives (`OSUnfairLock`, `@Synchronised`) |
| `ReducerDomain` | Composable reducer protocol and `@ReducerCombine` builder |

## Quick Start

```swift
import ReduxCore

// 1. Define actions and state
enum CounterAction { case increment, decrement }

struct CounterState {
    var count: Int = 0
}

// 2. Create a reducer
let reducer: Store<CounterState, CounterAction>.Reducer = { state, action in
    switch action {
    case .increment:  state.count += 1
    case .decrement:  state.count -= 1
    }
}

// 3. Initialize the store
let store = Store<CounterState, CounterAction>(initial: CounterState(), reducer: reducer)

// 4. Dispatch actions
store.dispatch(.increment)
store.dispatch(contentsOf: [.increment, .decrement])

// 5. Read state — @dynamicMemberLookup lets you skip `.state`
print(store.count) // 0
```

## Observing State

### AsyncStream — one-off observation

```swift
Task {
    for await snapshot in store.updates() {
        print("Count: \(snapshot.count)")
    }
}
store.dispatch(.increment) // triggers the loop
```

### Drivers — strong subscription

```swift
let driver = Store<CounterState, CounterAction>.GraphStreamer()
store.install(driver)

Task {
    for await snapshot in driver {
        print("Driver saw count: \(snapshot.count)")
    }
}
// ... later
store.uninstall(driver)
```

### Streamers — weak subscription

```swift
let streamer = StateStreamer<StoreSnapshot<Store<CounterState, CounterAction>>>()
store.subscribe(streamer)

Task {
    for await snapshot in streamer {
        print("Streamer saw count: \(snapshot.count)")
    }
}
// Automatically unsubscribed when `streamer` is deallocated
```

## StoreSnapshot

`StoreSnapshot` is a lightweight, immutable snapshot of the store's state with a weak reference back to the store. It's safe to pass to child components without creating retain cycles.

```swift
let snapshot = store.snapshot
print(snapshot.state)           // Access the current state
print(snapshot.count)           // @dynamicMemberLookup
snapshot.dispatch(.increment)   // Dispatch actions
snapshot.dispatch(.increment, .decrement) // Multiple actions
```

> **Note:** Snapshots do not auto-update. Get a fresh `store.snapshot` or use one of the observation methods above to react to changes.

## Composable Reducers

`ReducerDomain` + `@ReducerCombine` let you build modular, hierarchical reducer logic:

```swift
struct CounterFeature: ReducerDomain {
    struct State { var count: Int = 0 }
    enum Action { case increment, decrement }

    var body: ReducerOf<Self> {
        Reducer { state, action in
            switch action {
            case .increment:  state.count += 1
            case .decrement:  state.count -= 1
            }
        }
    }
}
```

Multiple reducers compose with the `@ReducerCombine` result builder — later reducers handle actions first, falling back to earlier ones.

## Thread Safety

All state access is protected by `OSUnfairLock`. Action dispatch is serialized through a `ReduxScheduler` (default: a serial `DispatchQueue` at `.userInteractive` QoS). Custom schedulers can be injected for testing:

```swift
let testScheduler: any ReduxScheduler = MySynchronousScheduler()
let store = Store(initial: state, scheduler: testScheduler, reducer: reducer)
```

## StateStreamer

`StateStreamer<State>` is a standalone, async, thread-safe broadcaster for any state type. It wraps `AsyncStream` with automatic completion on deinitialization:

```swift
let streamer = StateStreamer<MyState>()

// Consume
Task {
    for await state in streamer {
        print("Received: \(state)")
    }
}

// Emit
streamer.yield(newState)

// Complete
streamer.finish()
```

> **Note:** After `finish()` or deinitialization, no further values can be yielded.
