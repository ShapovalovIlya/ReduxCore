//
//  SubscribersBuilder.swift
//
//
//  Created by Илья Шаповалов on 08.12.2023.
//

import Foundation

public extension Store {
    @resultBuilder
    enum SubscribersBuilder {
        @inlinable
        public static func buildBlock(_ components: GraphObserver...) -> [GraphObserver] {
            components
        }
        
        @inlinable
        public static func buildArray(_ components: [[GraphObserver]]) -> [GraphObserver] {
            components.flatMap { $0 }
        }
        
    }
    
    @resultBuilder
    enum StreamerBuilder {
        @inlinable
        public static func buildBlock(_ components: GraphStreamer...) -> [GraphStreamer] {
            components
        }
        
        @inlinable
        public static func buildArray(_ components: [[GraphStreamer]]) -> [GraphStreamer] {
            components.flatMap { $0 }
        }
    }

    @resultBuilder
    enum ActionBuilder {

        // Single-action statement -> one-element partial result.
        @inlinable
        public static func buildExpression(_ expression: A) -> [A] {
            [expression]
        }

        // Array-of-actions statement -> pass-through.
        @inlinable
        public static func buildExpression(_ expression: [A]) -> [A] {
            expression
        }

        // Void-valued statement (logging, side work) -> contributes nothing.
        @inlinable
        public static func buildExpression(_ expression: Void) -> [A] {
            []
        }

        // Concatenates all statements (each already [A]) in source order.
        @inlinable
        public static func buildBlock(_ components: [A]...) -> [A] {
            buildArray(components)
        }

        // Empty body -> contributes nothing.
        @inlinable
        public static func buildBlock() -> [A] {
            []
        }

        @inlinable
        public static func buildArray(_ components: [[A]]) -> [A] {
            components.flatMap(\.self)
        }

        @inlinable
        public static func buildOptional(_ component: [A]?) -> [A] {
            component ?? []
        }

        @inlinable
        public static func buildEither(first component: [A]) -> [A] {
            component
        }

        @inlinable
        public static func buildEither(second component: [A]) -> [A] {
            component
        }
    }
}
