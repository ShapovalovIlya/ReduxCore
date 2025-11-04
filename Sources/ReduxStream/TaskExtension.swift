//
//  TaskExtension.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.08.2024.
//

import Foundation
@_exported import class Combine.AnyCancellable

public extension Task {
    
    /// Wraps ``_Concurrency/Task`` in to `AnyCancellable` object.
    @inlinable var asCancellable: AnyCancellable {
        AnyCancellable(self.cancel)
    }
    
    /// Stores this type-erasing cancellable instance in the specified collection.
    @inlinable
    func store(in array: inout Array<AnyCancellable>) {
        array.append(self.asCancellable)
    }
    
    /// Stores this type-erasing cancellable instance in the specified set.
    @inlinable
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(self.asCancellable)
    }
}
