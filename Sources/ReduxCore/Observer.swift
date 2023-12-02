//
//  Observer.swift
//  MovieMagazine
//
//  Created by Илья Шаповалов on 29.10.2023.
//

import Foundation

public final class Observer<State> {
    //MARK: - Private properties
    private var state: State?
    
    //MARK: - Internal properties
    private(set) var observe: ((State) -> Status)?
    
    //MARK: - Public properties
    public let queue: DispatchQueue
    
    //MARK: - init(_:)
    ///  Create new `Observer` object. `Observer` emit only when new `State` is different than older one.
    ///  Different between old and new state compute based on selected scope.
    /// - Parameters:
    ///   - queue: Queue which used for publishing new state
    ///   - scope:  Closure result determine source of difference between old `State` and new one.
    ///   - observe:  Closure which called when `Observer` emit new `State`
    public init<Scope>(
        queue: DispatchQueue = .global(),
        scope: @escaping (State) -> Scope,
        observe: @escaping (State) -> Status
    ) where Scope: Equatable {
        self.queue = queue
        self.observe = { newState in
            guard let state = self.state else {
                self.state = newState
                return observe(newState)
            }
            
            guard scope(state) != scope(newState) else { return .active }
            
            self.state = newState
            return observe(newState)
        }
    }
    
    ///  Create new `Observer` object. `Observer` emit only when new `State` is different than older one.
    /// - Parameters:
    ///   - queue: Queue which used for publishing new state
    ///   - observe: Closure which called when `Observer` emit new `State`
    public init(
        queue: DispatchQueue = .global(),
        observe: @escaping (State) -> Status
    ) where State: Equatable {
        self.queue = queue
        self.observe = { newState in
            guard self.state != newState else {
                return .active
            }
            self.state = newState
            return observe(newState)
        }
    }

    ///  Create new `Observer` object.
    /// - Parameters:
    ///   - queue: Queue which used for publishing new state
    ///   - observe: Closure which called when `Observer` emit new `State`
    public init(
        queue: DispatchQueue = .global(),
        observe: @escaping (State) -> Status
    ) {
        self.queue = queue
        self.observe = observe
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
