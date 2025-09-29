//
//  ReducerDomain.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 06.07.2025.
//

import Foundation

/// A convenience typealias for referencing a `ReducerDomain` with specific state and action types.
///
/// `ReducerOf` simplifies the declaration and usage of reducers by inferring the `State` and `Action` types from a given
/// type that conforms to `ReducerDomain`. This makes type signatures more concise and expressive, especially when working
/// with generic or composed reducers.
///
/// - Parameter R: A type conforming to `ReducerDomain`.
/// - Equivalent to: `ReducerDomain<R.State, R.Action>`
///
/// ### Example
/// ```swift
/// struct CounterReducer: ReducerDomain {
///     struct State { var count: Int }
///     enum Action { case increment, decrement }
///
///     var body: ReducerOf<Self> {
///         Reducer { state, action in
///             switch action {
///             case .increment:
///                 state.count += 1
///
///             case .decrenemt:
///                 state.count -= 1
///             }
///         }
///     }
/// }
/// ```
/// 
public typealias ReducerOf<R: ReducerDomain> = ReducerDomain<R.State, R.Action>

/// A protocol for defining composable, modular reducers that handle state mutations and actions.
///
/// `ReducerDomain` provides a standardized interface for building reducers in a Redux-like application architecture.
/// Conforming types specify the associated `State` and `Action` types they operate on, and implement logic for
/// handling actions and mutating state. The protocol supports both direct reduction and composition of multiple
/// reducers using the `body` property and the `@ReducerCombine` result builder.
///
/// Reducers built using `ReducerDomain` can be composed hierarchically, enabling scalable and maintainable
/// state management in complex applications. The protocol also supports chaining actions and side effects
/// through its recursive `run` method.
///
/// - Parameters:
///   - State: The type representing the state to be mutated.
///   - Action: The type representing actions that can be dispatched to update the state.
///   - Body: The type of the composed reducer body, typically built using `@ReducerCombine`.
///
/// ### Requirements
/// - `body`: A property that composes or provides the reducer logic, using the `@ReducerCombine` result builder.
/// - `reduce(_:action:)`: Handles an action, mutates the state, and optionally returns a follow-up action for further reduction.
/// - `run(_:action:)`: Handles side effects or chained actions (default implementation provided).
///
/// ### Key Features
/// - Type-safe association of state and actions
/// - Composable reducer bodies with result builder support
/// - Optional chaining of actions for advanced reduction flows
/// - Default implementations for common scenarios
///
/// ### Example
/// ```swift
/// struct CounterReducer: ReducerDomain {
///     struct State { var count: Int }
///     enum Action { case increment, decrement }
///
///     func reduce(_ state: inout State, action: Action) -> Action? {
///         switch action {
///         case .increment: state.count += 1
///         case .decrement: state.count -= 1
///         }
///         return nil
///     }
/// }
/// ```
///
/// ### Composition Example
/// ```swift
/// struct AppReducer: ReducerDomain {
///     struct State { var counter: Int }
///     enum Action { case increment, decrement }
///
///     var body: ReducerOf<Self> {
///         Reducer { state, action in
///             switch action {
///             case .increment:
///                 state.count += 1
///
///             case .decrenemt:
///                 state.count -= 1
///             }
///         }
///     }
///
/// }
/// ```
///
/// - Note: Use `ReducerDomain` to define clear, modular, and composable business logic for your application's state management.
/// - Note: The protocol is designed to support advanced reducer composition and effect management patterns.
///
public protocol ReducerDomain<State, Action> {
    associatedtype State
    associatedtype Action
    associatedtype Body
    
    @ReducerCombine<State, Action>
    var body: Body { get }
    
    func reduce(_ state: inout State, action: Action) -> Action?
    func run(_ state: inout State, action: Action)
}

public extension ReducerDomain {
    
    @inlinable
    func run(_ state: inout State, action: Action) {
        reduce(&state, action: action).map {
            run(&state, action: $0)
        }
    }
}

public extension ReducerDomain where Body == Never {
    var body: Never {
        fatalError("\(Self.self).body has not been implemented")
    }
}

public extension ReducerDomain where Body: ReducerDomain<State, Action> {
    
    @inlinable
    func reduce(_ state: inout State, action: Action) -> Action? {
        body.reduce(&state, action: action)
    }
}



@resultBuilder
public enum ReducerCombine<State, Action> {
    public typealias Element = ReducerDomain<State, Action>
    
    @inlinable
    public static func buildExpression(_ expression: some Element) -> some Element {
        expression
    }
    
    @inlinable
    public static func buildPartialBlock(first: some Element) -> some Element {
        first
    }
    
    @inlinable
    public static func buildPartialBlock(
        accumulated: some Element,
        next: some Element
    ) -> some Element {
        Reducer(next).pullback(accumulated)
//        Reducer { state, action in
//            accumulated.run(&state, action: action)
//            return next.reduce(&state, action: action)
//        }
    }
    
    @inlinable
    public static func buildLimitedAvailability(_ component: some Element) -> some Element {
        component
    }
}
