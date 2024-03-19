//
//  CompoundObserver.swift
//  
//
//  Created by Шаповалов Илья on 19.03.2024.
//

import Foundation

public final class CompoundObserver<State> {
    @usableFromInline
    private(set) var state: State?
    
    @usableFromInline
    private(set) var observe: ((State) -> Observer<State>.Status)
    
    @usableFromInline
    private(set) var queue: DispatchQueue
    
    public init(
        queue: DispatchQueue = .init(label: "CompoundObserver"),
        observe: @escaping ((State) -> Observer<State>.Status) = { _ in .dead }
    ) {
        self.queue = queue
        self.observe = observe
    }
}

public extension CompoundObserver where State: Equatable {
    @inlinable
    func removeDuplicates() -> Self {
        observe = { [weak self] newState in
            guard let self = self else { return .dead }
            if self.state == newState { return .active }
            
            queue.async { self.state = newState }
            return self.observe(newState)
        }
        return self
    }
}

public extension CompoundObserver {
    @inlinable
    func queue(_ q: DispatchQueue) -> Self {
        queue = q
        return self
    }
    
    @inlinable
    func observe(_ observation: @escaping (State) -> Observer<State>.Status) -> Self {
        
        return self
    }
}


