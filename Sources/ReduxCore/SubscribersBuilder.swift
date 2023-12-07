//
//  SubscribersBuilder.swift
//
//
//  Created by Илья Шаповалов on 08.12.2023.
//

import Foundation

public extension Store {
    @resultBuilder
    struct SubscribersBuilder {
        public static func buildBlock(_ components: GraphObserver...) -> [GraphObserver] {
            components
        }
        
        public static func buildArray(_ components: [[GraphObserver]]) -> [GraphObserver] {
            components.flatMap { $0 }
        }
        
    }
}
