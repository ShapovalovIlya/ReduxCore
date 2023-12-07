//
//  SubscribersBuilder.swift
//
//
//  Created by Илья Шаповалов on 08.12.2023.
//

import Foundation

extension Store {
    @resultBuilder
    struct SubscribersBuilder {
        static func buildBlock(_ components: GraphObserver...) -> [GraphObserver] {
            components
        }
        
        static func buildArray(_ components: [[GraphObserver]]) -> [GraphObserver] {
            components.flatMap { $0 }
        }
        
    }
}
