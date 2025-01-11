//
//  WeakObject.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 11.01.2025.
//

import Foundation
import ReduxStream

struct WeakObject<Obj: AnyObject> {
    let identifier: ObjectIdentifier
    weak var obj: Obj?
    
    @inlinable
    var isAlive: Bool { obj != nil }
    
    @inlinable
    init(obj: Obj, identifier: ObjectIdentifier) {
        self.identifier = identifier
        self.obj = obj
    }
    
    @inlinable
    init(obj: Obj) {
        self.init(obj: obj, identifier: ObjectIdentifier(obj))
    }
    
}

extension WeakObject: Sendable where Obj: Sendable {}
extension WeakObject: Equatable where Obj: Equatable {}
extension WeakObject: Hashable where Obj: Hashable {}
