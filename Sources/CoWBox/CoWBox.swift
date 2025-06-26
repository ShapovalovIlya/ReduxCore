//
//  CoWBox.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 20.02.2025.
//

import Foundation

@dynamicMemberLookup
public struct CoWBox<Wrapped>: @unchecked Sendable, Identifiable {
    @usableFromInline var storage: Storage
    
    @inlinable
    public init(_ wrapped: Wrapped) { self.storage = Storage(wrapped) }
    
    @inlinable
    public subscript<Property>(
        dynamicMember keyPath: WritableKeyPath<Wrapped, Property>
    ) -> Property {
        get { storage.wrapped[keyPath: keyPath] }
        set {
            defer { storage.wrapped[keyPath: keyPath] = newValue }
            if Swift.isKnownUniquelyReferenced(&storage) { return }
            storage = storage.copy()
        }
    }
    
}

public extension CoWBox {
    /// Instance of the wrapped value.
    @inlinable var fold: Wrapped { storage.wrapped }
    
    @inlinable var id: ObjectIdentifier { ObjectIdentifier(storage) }
    
    @inlinable func stateEquals(_ other: Self) -> Bool where Wrapped: Equatable {
        storage.wrapped == other.storage.wrapped
    }
}

//MARK: - Storage
extension CoWBox {
    @usableFromInline
    final class Storage {
        @usableFromInline var wrapped: Wrapped
        
        @usableFromInline
        init(_ wrapped: Wrapped) { self.wrapped = wrapped }
        
        @inlinable
        func copy() -> Self { Self(wrapped) }
    }
}

extension CoWBox: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
