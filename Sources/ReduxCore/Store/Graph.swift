//
//  Graph.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 02.12.2023.
//

import Foundation

/// A value type that encapsulates application state and provides a type-safe interface for dispatching actions.
///
/// The `Graph` struct represents a snapshot of the ``Store``'s state along with a dispatcher function for sending actions.
/// It is designed to be a lightweight, sendable wrapper that can be safely passed between threads or used in
/// child components and views. The `Graph` abstraction allows consumers to read the current state and dispatch
/// actions without exposing the full store, supporting unidirectional data flow and modular architecture.
///
/// - Parameters:
///   - State: The type representing the application state.
///   - Action: The type representing actions that can be dispatched to update the state.
///
/// ### Key Features
/// - Encapsulates the current state in a value type
/// - Provides a type-safe dispatcher for sending single or multiple actions
/// - Conforms to `Sendable` for safe use in concurrent contexts
///
/// ### Usage
/// ```swift
/// let graph = store.graph
/// print(graph.state) // Access the current state
/// graph.dispatch(.increment) // Dispatch a single action
/// graph.dispatch(.increment, .decrement) // Dispatch multiple actions
/// graph.dispatch(contentsOf: [.reset, .increment])
/// ```
///
/// - Note: The dispatcher is a closure that sends actions to the underlying store. The `Graph` itself does not mutate state directly.
///
public struct Graph<State, Action>: Sendable {
    @usableFromInline
    typealias Dispatcher = @Sendable (any Collection<Action>) -> Void
    
    @usableFromInline
    let dispatcher: Dispatcher
    
    /// The current state snapshot represented by this ``Graph`` instance.
    ///
    /// This property provides read-only access to the state at the time the ``Graph`` was created.
    /// Use this property to inspect the current values of your application's state in a type-safe manner.
    ///
    /// - Note: The `state` property is immutable within the `Graph` instance.
    ///         To observe state changes over time, access the latest `Graph` from the parent ``Store``.
    /// - Note: The `Graph` instance itself does not subscribe to store updates.
    ///         To receive continuous updates, subscribe to the ``Store`` via ``Store/Streamer`` or ``Store/GraphStreamer``.
    ///
    /// ### Example:
    /// ```swift
    /// let graph = store.graph
    /// print(graph.state) // Access the current state
    /// ```
    ///
    public let state: State

    //MARK: - init(_:)
    @Sendable
    @inlinable
    init(_ state: State, dispatcher: @escaping Dispatcher) {
        self.state = state
        self.dispatcher = dispatcher
    }
    
    //MARK: - Public methods
    
    /// Dispatches a single action to the underlying ``Store``.
    ///
    /// This method sends the provided action to the store's dispatcher, which will process the action
    /// and update the state accordingly. Use this method to trigger state changes in response to user
    /// interactions or other events.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter action: The action to be dispatched to the store.
    ///
    /// ### Example:
    /// ```swift
    /// graph.dispatch(.increment)
    /// ```
    ///
    @inlinable
    @Sendable
    public func dispatch(_ action: Action) {
        dispatcher(CollectionOfOne(action))
    }
    
    /// Dispatches multiple actions to the underlying ``Store`` in the order provided.
    ///
    /// This method sends all provided actions to the store's dispatcher, which will process each action
    /// sequentially and update the state accordingly. Use this method to trigger a series of state changes
    /// in response to a single event or operation.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter actions: A variadic list of actions to be dispatched to the store, in order.
    ///
    /// ### Example:
    /// ```swift
    /// graph.dispatch(.increment, .decrement, .reset)
    /// ```
    ///
    @inlinable
    @Sendable
    public func dispatch(_ actions: Action...) {
        dispatcher(actions)
    }
    
    /// Dispatches a sequence of actions to the underlying store in the order they appear in the sequence.
    ///
    /// This method sends all actions in the provided sequence to the store's dispatcher, which will process each action
    /// sequentially and update the state accordingly. Use this method to trigger a batch of state changes efficiently.
    ///
    /// This method is thread-safe and can be called from any thread.
    ///
    /// - Parameter s: A sequence of actions to be dispatched to the store, in order.
    ///
    /// ### Example:
    /// ```swift
    /// let actions: [MyAction] = [.increment, .decrement, .reset]
    /// graph.dispatch(contentsOf: actions)
    /// ```
    ///
    @inlinable
    @Sendable
    public func dispatch(contentsOf s: some Sequence<Action>) {
        dispatcher(Array(s))
    }
}
