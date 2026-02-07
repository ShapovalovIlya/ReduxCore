//
//  Snapshot.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import Foundation

public extension Store {
    /// A lightweight, value-type snapshot of application state with a type-safe action dispatcher.
    ///
    /// ‎`Snapshot` provides read-only access to a snapshot of the application’s state and a closure for dispatching actions.
    /// It is designed to be safely passed between threads and used in child components or views, supporting unidirectional data flow.
    ///
    /// ‎`Snapshot` instances are cheap to copy and pass around, making them suitable for use in performance-sensitive or highly modular code.
    ///
    /// - Parameters:
    ///   - State: The type representing the application state.
    ///   - Action: The type representing actions that can be dispatched to update the state.
    ///
    /// ## Features
    /// - Encapsulates a snapshot of state in a value type.
    /// - Provides a type-safe, thread-safe dispatcher for single or multiple actions.
    /// - Conforms to ‎`Sendable` for safe use in concurrent contexts.
    ///
    /// ## Usage
    /// ```swift
    /// let graph = store.graph
    /// print(graph.state) // Access the current state snapshot
    /// graph.dispatch(.increment) // Dispatch a single action
    /// graph.dispatch(.increment, .decrement) // Dispatch multiple actions
    /// graph.dispatch(contentsOf: [.reset, .increment])
    /// ```
    ///
    /// - Note: ‎`Snapshot` does not subscribe to state changes. To observe updates, access the latest ‎`Graph` from the parent ‎`Store`.
    struct Snapshot {
        @usableFromInline
        typealias Dispatcher = @Sendable (any Collection<Action>) -> Void
        
        @usableFromInline
        final class Storage {
            
            @usableFromInline
            let wrapped: State
            
            @inlinable
            init(_ wrapped: State) { self.wrapped = wrapped }
        }
        
        @usableFromInline
        let storage: Storage
        
        @usableFromInline
        let dispatcher: Dispatcher
        
        //MARK: - init(_:)
        @inlinable
        init(_ state: State, dispatcher: @escaping Dispatcher) {
            self.storage = Storage(state)
            self.dispatcher = dispatcher
        }
        
        @inlinable
        init(store: Store<State, Action>) {
            self.init(store.state) { [weak store] actions in
                store?.dispatcher(actions)
            }
        }
    }
}

public extension Store.Snapshot {
    
    /// The current state snapshot represented by this `Graph` instance.
    ///
    /// This property is immutable and reflects the state at the time the `Graph` was created.
    /// To observe state changes, retrieve a new `Graph` from the parent `Store`.
    ///
    /// - Note: The `Graph` instance itself does not subscribe to store updates.
    ///         To receive continuous updates, subscribe to the ``Store`` via ``Store/Streamer`` or ``Store/GraphStreamer``.
    ///
    /// ### Example:
    /// ```swift
    /// let graph = store.graph
    /// print(graph.state) // Access the current state
    /// ```
    ///
    @inlinable
    var state: State {
        storage.wrapped
    }
    
    //MARK: - Public methods
    
    /// Dispatches a single action to the underlying ``Store``.
    ///
    /// Triggers state changes in response to user interactions or events.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter action: The action to be dispatched to the store.
    @inlinable
    func dispatch(_ action: Action) {
        dispatcher(CollectionOfOne(action))
    }
    
    /// Dispatches multiple actions to the underlying ``Store`` in the order provided.
    ///
    /// Use to trigger a series of state changes.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter actions: A variadic list of actions to be dispatched to the store, in order.
    @inlinable
    func dispatch(_ actions: Action...) {
        dispatcher(actions)
    }
    
    /// Dispatches a sequence of actions to the underlying store in the order they appear in the sequence.
    ///
    /// Use to efficiently batch state changes.
    ///
    /// - Note: This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter s: A sequence of actions to be dispatched to the store, in order.
    @inlinable
    func dispatch(contentsOf s: some Sequence<Action>) {
        dispatcher(Array(s))
    }
}

extension Store.Snapshot: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        ObjectIdentifier(lhs.storage) == ObjectIdentifier(rhs.storage)
    }
}

extension Store.Snapshot.Storage: Sendable where State: Sendable {}
extension Store.Snapshot: Sendable where State: Sendable {}
