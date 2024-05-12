//
//  File.swift
//  
//
//  Created by Илья Шаповалов on 12.05.2024.
//

import Foundation

@resultBuilder
public enum QueueBuilder {
    public typealias Component = StoreThread.Work
    public typealias Queue = [Component]
    
    @inlinable
    public static func buildBlock(_ components: Component...) -> Queue {
        components.compactMap { $0 }
    }
    
}
