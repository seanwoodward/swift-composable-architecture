#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import XCTest

  final class ReducerMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        // isRecording: true,
        macros: [ReducerMacro.self]
      ) {
        super.invokeTest()
      }
    }

    func testBasics() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          struct State {
          }
          enum Action {
          }
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature {
          struct State {
          }
          @CasePathable
          enum Action {
          }
          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testEnumState() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          enum State {
          }
          enum Action {
          }
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature {
          @CasePathable @dynamicMemberLookup
          enum State {
          }
          @CasePathable
          enum Action {
          }
          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testAlreadyApplied() {
      assertMacro {
        """
        @Reducer
        struct Feature: Reducer, Sendable {
          @CasePathable
          @dynamicMemberLookup
          enum State {
          }
          @CasePathable
          enum Action {
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature: Reducer, Sendable {
          @CasePathable
          @dynamicMemberLookup
          enum State {
          }
          @CasePathable
          enum Action {
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      }
    }

    func testExistingCasePathableConformance() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          enum State: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          enum Action: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature {
          @dynamicMemberLookup
          enum State: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          enum Action: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testReduceMethodDiagnostic() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          struct State {
          }
          enum Action {
          }
          func reduce(into state: inout State, action: Action) -> EffectOf<Self> {
            .none
          }
          var body: some ReducerOf<Self> {
            Reduce(reduce)
            Reduce(reduce(into:action:))
            Reduce(self.reduce)
            Reduce(self.reduce(into:action:))
            Reduce(AnotherReducer().reduce)
            Reduce(AnotherReducer().reduce(into:action:))
          }
        }
        """
      } diagnostics: {
        """
        @Reducer
        struct Feature {
          struct State {
          }
          enum Action {
          }
          func reduce(into state: inout State, action: Action) -> EffectOf<Self> {
               ┬─────
               ╰─ 🛑 A 'reduce' method should not be defined in a reducer with a 'body'; it takes precedence and 'body' will never be invoked
            .none
          }
          var body: some ReducerOf<Self> {
            Reduce(reduce)
            Reduce(reduce(into:action:))
            Reduce(self.reduce)
            Reduce(self.reduce(into:action:))
            Reduce(AnotherReducer().reduce)
            Reduce(AnotherReducer().reduce(into:action:))
          }
        }
        """
      }
    }

    func testEnum() {
      assertMacro(record: true) {
        """
        @Reducer
        enum Destination {
          case timeline(Timeline)
          case tweet(Tweet)
          case alert(AlertState<Alert>)

          enum Alert {
            case ok
          }
        }
        """
      } expansion: {
        #"""
        enum Destination {
          case timeline(Timeline)
          case tweet(Tweet)
          case alert(AlertState<Alert>)

          enum Alert {
            case ok
          }

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: Equatable {
            case timeline(Timeline.State)
            case tweet(Tweet.State)
            case alert(AlertState<Alert>.State)
          }

          @CasePathable
          enum Action {
            case timeline(Timeline.Action)
            case tweet(Tweet.Action)
            case alert(AlertState<Alert>.Action)
          }

          init() {
            self = .timeline(Timeline())
          }

          var body: some ComposableArchitecture.Reducer<Self.State, Self.Action> {
            CombineReducers {
              ComposableArchitecture.Scope(state: \Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
              ComposableArchitecture.Scope(state: \Self.State.Cases.tweet, action: \Self.Action.Cases.tweet) {
                Tweet()
              }
              ComposableArchitecture.Scope(state: \Self.State.Cases.alert, action: \Self.Action.Cases.alert) {
                AlertState()
              }
            }
          }

          enum DestinationStore {
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case tweet(ComposableArchitecture.StoreOf<Tweet>)
            case alert(ComposableArchitecture.StoreOf<AlertState<Alert>>)
          }

          static func destination(_ store: Store<Self.State, Self.Action>) -> DestinationStore {
            switch store.state {
            case .timeline:
              return .timeline(store.scope(state: \.timeline, action: \.timeline)!)
            case .tweet:
              return .tweet(store.scope(state: \.tweet, action: \.tweet)!)
            case .alert:
              return .alert(store.scope(state: \.alert, action: \.alert)!)
            }
          }
        }

        extension Destination: ComposableArchitecture.Reducer {
        }
        """#
      }
    }
  }
#endif
