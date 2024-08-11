//
//  TaskExtension.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.08.2024.
//

import Foundation
import Combine

public extension Task {
    /// Stores this type-erasing cancellable instance in the specified collection.
    func store(in array: inout [AnyCancellable]) {
        array.append(AnyCancellable(self.cancel))
    }
    
    /// Stores this type-erasing cancellable instance in the specified set.
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(AnyCancellable(self.cancel))
    }
}
