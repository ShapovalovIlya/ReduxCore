//
//  LazySequence+.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 20.04.2025.
//

import Foundation

public extension LazySequenceProtocol {
    @inlinable func run() -> [Element] { Array(self) }
}

public extension LazySequenceProtocol {
    
    @inlinable
    func removedDuplicates<T: Hashable>(
        using identityOf: @escaping (Element) -> T
    ) -> LazyRemoveDuplicatesSequence<Self, T> {
        LazyRemoveDuplicatesSequence(self, identityOf: identityOf)
    }
}

public extension LazySequenceProtocol where Element: Hashable {
    @inlinable
    func removedDuplicates() -> LazyRemoveDuplicatesSequence<Self, Element> {
        LazyRemoveDuplicatesSequence(self, identityOf: \.self)
    }
}
