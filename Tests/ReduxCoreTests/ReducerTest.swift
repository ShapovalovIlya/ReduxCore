//
//  ReducerTest.swift
//  ReduxCore
//
//  Created by Илья Шаповалов on 06.07.2025.
//

import Testing
import ReducerDomain

struct CounterDomain: ReducerDomain {
    struct State: Equatable {
        var counter: Int = 0
    }
    
    enum Action: Equatable {
        case increment
        case decrement
        case delegate(save: Int)
    }
    
    var body: some ReducerOf<Self> {
        Reducer { state, action in
            switch action {
            case .increment:
                state.counter += 1
                return .delegate(save: state.counter)
                
            case .decrement:
                state.counter -= 1
                return .delegate(save: state.counter)
                
            case .delegate:
                break
            }
            return nil
        }
    }
}

struct ParentDomain: ReducerDomain {
    struct State {
        var child = CounterDomain.State()
        var saved: Int?
    }
    
    enum Action {
        case clearSaved
        case child(CounterDomain.Action)
    }
    
    var body: some ReducerOf<Self> {
        ChildReducer(
            state: \.child,
            action: { action in
                guard case let .child(childAction) = action else {
                    return nil
                }
                return childAction
            },
            reducer: CounterDomain.init
        )
        Reducer { state, action in
            switch action {
            case .clearSaved:
                state.saved = nil
                
            case .child:
                break
            }
            return nil
        }
    }
}

struct ReducerTest {
    let sut = CounterDomain()
    
    @Test func emptyReducerDoNothing() async throws {
        var state = CounterDomain.State()
        let sut: some ReducerOf<CounterDomain> = EmptyReducer()
        
        let action = sut.reduce(&state, action: .increment)
        
        #expect(state.counter == 0)
        #expect(action == nil)
    }

    @Test func reducerPoduceAction() async throws {
        var state = CounterDomain.State()
        
        let actionAfterIncrement = sut.reduce(&state, action: .increment)
        
        #expect(state.counter == 1)
        #expect(actionAfterIncrement == .delegate(save: 1))
        
        let actionAfterDecrement = sut.reduce(&state, action: .decrement)
        
        #expect(state.counter == 0)
        #expect(actionAfterDecrement == .delegate(save: 0))
    }

//    @Test func parendSaveChildCalculations() async throws {
//        var state = ParentDomain.State()
//        let sut = ParentDomain()
//        
//        sut.run(&state, action: .child(.increment))
//        #expect(state.child.counter == 1)
//        #expect(state.saved == 1)
//        
//        sut.run(&state, action: .clearSaved)
//        #expect(state.saved == nil)
//    }
}
