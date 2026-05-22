import SwiftUI
import UserNotifications

struct DailyPuzzleView: View {
    @Environment(DailyPuzzleService.self) private var puzzle
    @Environment(FirstRunState.self) private var firstRunState
    @Environment(StreakStore.self) private var streakStore
    @State private var showStats = false
    @State private var showShare = false
    @State private var showNotificationPrompt = false
    @State private var showNumberPadHint = false
    @State private var numberPadHintTask: Task<Void, Never>?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppLayout.gridSpacing), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            header

            StreakBlock(
                currentStreak: streakStore.currentStreak,
                longestStreak: streakStore.longestStreak,
                solvedStatusLast7: streakStore.solvedStatusLast7Days(),
                hasSolvedToday: streakStore.hasAlreadySolvedToday
            )
            .padding(.vertical, Spacing.sm)

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
        .sheet(isPresented: $showNotificationPrompt) {
            NotificationPrePromptSheet(
                onAllow: {
                    requestNotificationPermission()
                    firstRunState.hasShownNotificationPrePrompt = true
                },
                onDecline: {
                    firstRunState.notifPrePromptDeclinedAt = Date()
                    firstRunState.hasShownNotificationPrePrompt = true
                }
            )
        }
    }

    private var header: some View {
        HStack {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("puzzle.header", value: "Puzzle #%d", comment: "Daily puzzle number"),
                puzzle.puzzleNumber
            ))
            .font(AppFont.headline)
            .foregroundStyle(Color.appTextPrimary)

            Spacer()

            Button(action: { showStats = true }) {
                Image(systemName: "chart.bar.fill")
                    .font(.body)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(minWidth: AppLayout.tapTarget, minHeight: AppLayout.tapTarget)
            }
        }
        .padding(.vertical, AppLayout.padding)
    }

    private var puzzleGrid: some View {
        VStack(spacing: AppLayout.gridSpacing) {
            ForEach(0..<puzzle.board.maxAttempts, id: \.self) { row in
                let isActiveRow = row == puzzle.guesses.count
                GuessRowView(
                    guess: row < puzzle.guesses.count
                        ? puzzle.guesses[row]
                        : (isActiveRow ? puzzle.currentGuess : ""),
                    feedback: row < puzzle.feedback.count ? puzzle.feedback[row] : [],
                    targetLength: puzzle.board.targetWord.count,
                    isActive: isActiveRow,
                    showFirstCellHint: !firstRunState.hasShownFirstCellHint && isActiveRow
                )
            }

            if showNumberPadHint {
                Text(NSLocalizedString("hint.numberpad", value: "Tap a number", comment: "Number pad hint"))
                    .font(Typography.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .transition(.opacity)
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
                    showNumberPadHintIfNeeded()
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
            .foregroundStyle(puzzle.isSolved ? Color.appSecondary : Color.appTextPrimary)

            if !puzzle.isSolved {
                Text(puzzle.board.targetWord)
                    .font(AppFont.puzzleCell)
                    .foregroundStyle(Color.appSecondary)
            }

            Text(NSLocalizedString("puzzle.tomorrow", value: "Tomorrow's puzzle drops at midnight.", comment: "Come back tomorrow"))
                .font(Typography.caption)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    showShare = true
                } label: {
                    Label(
                        NSLocalizedString("share.title", value: "Share", comment: "Share button"),
                        systemImage: "square.and.arrow.up"
                    )
                    .font(AppFont.body)
                    .foregroundStyle(Color.white)
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
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(.vertical, AppLayout.padding)
    }

    private func recordGame() {
        if puzzle.isSolved {
            streakStore.recordWin(attempts: puzzle.guesses.count)
            if firstRunState.canShowNotificationPrePrompt {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    showNotificationPrompt = true
                }
            }
        } else {
            streakStore.recordLoss()
        }
    }

    private func showNumberPadHintIfNeeded() {
        guard !firstRunState.hasShownNumberPadHint else { return }

        firstRunState.hasShownNumberPadHint = true
        firstRunState.hasShownFirstCellHint = true

        withAnimation { showNumberPadHint = true }

        numberPadHintTask?.cancel()
        numberPadHintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showNumberPadHint = false }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted {
                DispatchQueue.main.async {
                    firstRunState.notifOSDenied = true
                }
            }
        }
    }
}
