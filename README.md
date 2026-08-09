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
    .package(url: "https://github.com/ShapovalovIlya/ReduxCore.git", from: "2.4.1")
]
```

> **Note:** Latest stable: `2.4.1`. For the latest changes, you can opt into `branch: "main"` explicitly.

Or via Xcode: **File > Add Package Dependencies...**

**Requirements:** iOS 13+, macOS 10.15+.

The package provides four library products:

| Product | Description |
| --------- | ------------- |
| `ReduxCore` | Main store, snapshot, and scheduler APIs |
| `ReduxStream` | `StateStreamer` for async state broadcasting |
| `ReduxSync` | Thread-safety primitives (`OSUnfairLock`, `OSReadWriteLock`, `@Synchronised`) |
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
print(store.count) // 1  (0 → 1 → 2 → 1)
```

> **Note:** Dispatch is asynchronous by default. In real code, observe state reactively (snapshots, drivers, or streams below) instead of reading it immediately after `dispatch`.

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

`ReducerDomain` + `@ReducerCombine` let you build modular, hierarchical reducer logic. `ReducerDomain` is a separate library product — add it to your dependencies alongside `ReduxCore`:

```swift
import ReducerDomain

struct CounterFeature: ReducerDomain {
    struct State { var count: Int = 0 }
    enum Action { case increment, decrement }

    var body: ReducerOf<Self> {
        Reducer { state, action in
            switch action {
            case .increment:  state.count += 1
            case .decrement:  state.count -= 1
            }
            return nil
        }
    }
}
```

Multiple reducers compose with the `@ReducerCombine` result builder — reducers are tried in declaration order: earlier reducers get the first chance to handle an action, and later ones act as a fallback for actions the earlier reducers return `nil` for.

## Thread Safety

All state access is protected by `OSUnfairLock`. Action dispatch is serialized through a `ReduxScheduler` — by default `AsyncSerialScheduler`, a serial Swift Concurrency task loop that never blocks a thread. `DispatchQueue.storeScheduler` (serial, `.userInteractive` QoS) is available for GCD-based setups. Custom schedulers can be injected for testing:

```swift
let store = Store(
    initial: state,
    scheduler: DispatchQueue.storeScheduler, // or a custom ReduxScheduler for tests
    reducer: reducer
)
```

## StateStreamer

`StateStreamer<State>` (from the `ReduxStream` product) is a standalone, thread-safe broadcaster for any state type. It wraps `AsyncStream` with automatic completion on deinitialization:

```swift
let streamer = StateStreamer<MyState>()

Task {
    for await state in streamer { print("Received: \(state)") }
}

streamer.yield(newState)   // Emit
streamer.finish()          // Complete
```

> **Note:** After `finish()` or deinitialization, no further values can be yielded.
