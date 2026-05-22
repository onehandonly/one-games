import SwiftUI
import SwiftData

@main
struct OnePuzzleApp: App {
    @State private var puzzleService = DailyPuzzleService()

    var body: some Scene {
        WindowGroup {
            DailyPuzzleView()
                .environment(puzzleService)
                .modelContainer(for: StreakStore.self)
        }
    }
}
