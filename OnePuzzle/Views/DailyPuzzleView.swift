import SwiftUI
import SwiftData

struct DailyPuzzleView: View {
    @Environment(DailyPuzzleService.self) private var puzzle
    @Environment(\.modelContext) private var modelContext
    @Query private var streakStore: [StreakStore]
    @State private var showStats = false
    @State private var showShare = false
    @State private var message = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppLayout.gridSpacing), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            header
            puzzleGrid
            Spacer()
            if puzzle.isGameOver {
                gameOverButtons
            } else {
                keyboard
            }
        }
        .padding(.horizontal, AppLayout.padding)
        .background(Color.appSurface)
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .sheet(isPresented: $showShare) {
            ShareCardView()
        }
        .onAppear {
            if streakStore.isEmpty {
                modelContext.insert(StreakStore())
            }
        }
    }

    private var header: some View {
        HStack {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("puzzle.header", value: "Puzzle #%d", comment: "Daily puzzle number"),
                puzzle.puzzleNumber
            ))
            .font(AppFont.headline)
            .foregroundColor(.appTextPrimary)

            Spacer()

            Button(action: { showStats = true }) {
                Image(systemName: "chart.bar.fill")
                    .font(.body)
                    .foregroundColor(.appTextSecondary)
                    .frame(minWidth: AppLayout.tapTarget, minHeight: AppLayout.tapTarget)
            }
        }
        .padding(.vertical, AppLayout.padding)
    }

    private var puzzleGrid: some View {
        VStack(spacing: AppLayout.gridSpacing) {
            ForEach(0..<puzzle.board.maxAttempts, id: \.self) { row in
                GuessRowView(
                    guess: row < puzzle.guesses.count ? puzzle.guesses[row] : (row == puzzle.guesses.count ? puzzle.currentGuess : ""),
                    feedback: row < puzzle.feedback.count ? puzzle.feedback[row] : [],
                    targetLength: puzzle.board.targetWord.count,
                    isActive: row == puzzle.guesses.count
                )
            }
        }
        .padding(.vertical, AppLayout.padding)
    }

    private var keyboard: some View {
        KeyboardView(
            onKeyTap: { char in
                if char == "⌫" {
                    puzzle.removeLetter()
                } else {
                    puzzle.addLetter(char)
                }
            },
            onSubmit: {
                _ = puzzle.submitGuess()
            },
            letterMapping: puzzle.keyboardMapping
        )
        .padding(.vertical, AppLayout.padding)
    }

    private var gameOverButtons: some View {
        VStack(spacing: 12) {
            Text(puzzle.isSolved
                 ? String.localizedStringWithFormat(
                    NSLocalizedString("puzzle.solved", value: "Solved in %d/%d", comment: "Solved in N attempts"),
                    puzzle.guesses.count, puzzle.board.maxAttempts
                 )
                 : NSLocalizedString("puzzle.not-solved", value: "Not quite!", comment: "Failed to solve"))
            .font(AppFont.headline)
            .foregroundColor(puzzle.isSolved ? .appSecondary : .appTextPrimary)

            if !puzzle.isSolved {
                Text(puzzle.board.targetWord)
                    .font(AppFont.puzzleCell)
                    .foregroundColor(.appSecondary)
            }

            HStack(spacing: 16) {
                Button {
                    showShare = true
                } label: {
                    Label(
                        NSLocalizedString("share.title", value: "Share", comment: "Share button"),
                        systemImage: "square.and.arrow.up"
                    )
                    .font(AppFont.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
                }

                Button {
                    recordGame()
                } label: {
                    Text(NSLocalizedString("puzzle.see-you", value: "See you tomorrow!", comment: "Dismiss puzzle"))
                        .font(AppFont.body)
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
        .padding(.vertical, AppLayout.padding)
    }

    private func recordGame() {
        guard let streak = streakStore.first else { return }
        if puzzle.isSolved {
            streak.recordWin(attempts: puzzle.guesses.count)
        } else {
            streak.recordLoss()
        }
    }
}
