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

extension Task where Success == Never, Failure == Never {
    
    /// Stops execution of `Task` for the specified time. Doesn't slow down the flow.
    ///
    /// The method checks the passed value for `isInfinite` and `isNaN`.
    /// If the passed value in `seconds <= 0`, then the function will exit immediately.
    ///
    /// - Parameter interval: the time for which the current `Task` should suspend its process.
    /// In seconds.
    static func sleep(seconds: TimeInterval) async throws {
        if seconds.isInfinite || seconds.isNaN {
            assertionFailure("Argument `seconds` is infinite or NaN")
            return
        }
        if seconds.isLessThanOrEqualTo(.zero) { return }
        try await sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
    }
}
