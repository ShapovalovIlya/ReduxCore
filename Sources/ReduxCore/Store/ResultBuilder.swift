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
}
