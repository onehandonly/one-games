import SwiftUI

@main
struct OnePuzzleApp: App {
    @State private var puzzleService = DailyPuzzleService()
    @State private var firstRunState = FirstRunState()
    @State private var streakStore = StreakStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(puzzleService)
                .environment(firstRunState)
                .environment(streakStore)
        }
    }
}

struct RootView: View {
    @Environment(FirstRunState.self) private var firstRunState

    var body: some View {
        Group {
            if firstRunState.hasSeenHowItWorks {
                DailyPuzzleView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else if firstRunState.hasSeenWelcome {
                HowItWorksScreen()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else {
                WelcomeScreen()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
    }
}
