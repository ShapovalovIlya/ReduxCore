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
    
    enum Action: Equatable, Sendable {
        case clearSaved
        case child(CounterDomain.Action)
        
        static var child: Prism<Self, CounterDomain.Action> {
            Prism(
                extract: { action in
                    guard case let .child(childAction) = action else {
                        return nil
                    }
                    return childAction
                },
                embed: Self.child
            )
        }
    }
    
    var body: some ReducerOf<Self> {
        ChildReducer(
            state: \.child,
            prism: Action.child,
            reducer: CounterDomain.init
        )
        Reducer { state, action in
            switch action {
            case .clearSaved:
                state.saved = nil
                
            case let .child(.delegate(toSave)):
                state.saved = toSave
                
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

    @Test func parendSaveChildCalculations() async throws {
        var state = ParentDomain.State()
        let sut = ParentDomain()
        
        let delegate = try #require(sut.reduce(&state, action: .child(.increment)))
        #expect(state.child.counter == 1)
        #expect(delegate == .child(.delegate(save: 1)))
        
        #expect(sut.reduce(&state, action: delegate) == nil)
        #expect(state.saved == 1)
        
        sut.run(&state, action: .clearSaved)
        #expect(state.saved == nil)
    }
    
    @Test func parendSaveChildCalculations_1() async throws {
        var state = ParentDomain.State()
        let sut = ParentDomain()
        
        sut.run(&state, action: .child(.increment))
        #expect(state.child.counter == 1)
        #expect(state.saved == 1)
        
        sut.run(&state, action: .clearSaved)
        #expect(state.saved == nil)
    }
}
