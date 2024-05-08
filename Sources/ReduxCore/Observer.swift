//
//  Observer.swift
//  MovieMagazine
//
//  Created by Илья Шаповалов on 29.10.2023.
//

import Foundation

public final class Observer<State> {
    //MARK: - Private properties
    @usableFromInline let lock = NSLock()
    @usableFromInline var state: State?
    
    //MARK: - Internal properties
    @usableFromInline 
    private(set) var observe: ((State) -> Status)?
    
    //MARK: - Public properties
    public let queue: DispatchQueue
    
    //MARK: - init(_:)
    ///  Create new `Observer` object.
    /// - Parameters:
    ///   - queue: Queue which used for publishing new state
    ///   - observe: Closure which called when `Observer` emit new `State`
    public init(
        queue: DispatchQueue = .init(label: "ObserverQueue"),
        observe: @escaping (State) -> Status
    ) {
        self.queue = queue
        self.observe = observe
    }
    
    ///  Create new `Observer` object. `Observer` emit only when new `State` is different than older one.
    /// - Parameters:
    ///   - queue: Queue which used for publishing new state
    ///   - observe: Closure which called when `Observer` emit new `State`
    public init(
        queue: DispatchQueue = .init(label: "ObserverQueue"),
        observe: @escaping (State) -> Status
    ) where State: Equatable {
        self.queue = queue
        self.observe = { [weak self] newState in
            guard let self = self else { return .dead }
            return self.process(newState) { self.state == $0 } ?? observe(newState)
        }
    }
    
    ///  Create new `Observer` object. `Observer` emit only when new `State` is different than older one.
    ///  Different between old and new state compute based on selected scope.
    /// - Parameters:
    ///   - queue: Queue which used for publishing new state
    ///   - scope:  Closure result determine source of difference between old `State` and new one.
    ///   - observe:  Closure which called when `Observer` emit new `State`
    public init<Scope>(
        queue: DispatchQueue = .init(label: "ObserverQueue"),
        scope: @escaping (State) -> Scope,
        observe: @escaping (State) -> Status
    ) where Scope: Equatable {
        self.queue = queue
        self.observe = { [weak self] newState in
            guard let self = self else { return .dead }
            return self.process(newState) { self.state.map(scope) == scope($0) } ?? observe(newState)
        }
    }
    
    ///  Create new `Observer` object. `Observer` emit only when new `ScopedState` is different than older one.
    ///  Different between old and new state compute based on selected scope.
    /// - Parameters:
    ///   - queue: Queue which used for publishing new state
    ///   - scope:  Closure result determine source of difference between old `State` and new one.
    ///   - observeScope:  Closure which called when `Observer` emit new `ScopedState`
    public init<Scope>(
        queue: DispatchQueue = .init(label: "ObserverQueue"),
        scope: @escaping (State) -> Scope,
        observeScope: @escaping (Scope) -> Status
    ) where Scope: Equatable {
        self.queue = queue
        self.observe = { [weak self] newState in
            guard let self = self else { return .dead }
            let scoped = scope(newState)
            return self.process(newState) { self.state.map(scope) == scope($0) } ?? observeScope(scoped)
        }
    }
    
    //MARK: - Methods
    @inlinable
    @inline(__always)
    func process(
        _ newState: State,
        isEqual: (State) -> Bool
    ) -> Status? {
        if isEqual(newState) { return .active }
        lock.withLock { state = newState }
        return nil
    }

}

public extension Observer {
    //MARK: - Status
    enum Status: Equatable {
        case active
        case dead
        case postponed(Int)
    }
}

//MARK: - Hashable
extension Observer: Hashable {
    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}

//MARK: - Equatable
extension Observer: Equatable {
    public static func ==(lhs: Observer, rhs: Observer) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}
