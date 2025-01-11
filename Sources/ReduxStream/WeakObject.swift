//
//  WeakObject.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.01.2025.
//

import Foundation

struct WeakObject<T: AnyObject> {
    let identifier: ObjectIdentifier
    weak var obj: T?
    
    @inlinable
    var isAlive: Bool { obj != nil }
    
    @inlinable
    init(obj: T, identifier: ObjectIdentifier) {
        self.identifier = identifier
        self.obj = obj
    }
    
    @inlinable
    init(obj: T) {
        self.init(obj: obj, identifier: ObjectIdentifier(obj))
    }
}

extension WeakObject: Equatable where T: Equatable { }
extension WeakObject: Hashable where T: Hashable { }
