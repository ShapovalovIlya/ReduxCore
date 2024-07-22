//
//  StoreKeyDomain.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 20.07.2024.
//

import Foundation

@dynamicMemberLookup
public protocol StoreKeyDomain {
    associatedtype Store
    associatedtype Domain
    
    typealias DomainKeyPath = KeyPath<Store, Domain>
    
    var store: Store { get }
    var domain: DomainKeyPath { get }
    
    @inlinable
    subscript<T>(dynamicMember keyPath: KeyPath<Domain, T>) -> T { get }
}

public extension StoreKeyDomain {
    @inlinable
    subscript<T>(dynamicMember keyPath: KeyPath<Domain, T>) -> T {
        store[keyPath: domain][keyPath: keyPath]
    }
}
