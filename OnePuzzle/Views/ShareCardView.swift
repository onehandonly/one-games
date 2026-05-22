import SwiftUI

struct ShareCardView: View {
    @Environment(DailyPuzzleService.self) private var puzzle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cardContent
                    .padding(24)

                ShareLink(
                    item: shareText,
                    subject: Text(verbatim: "OnePuzzle #\(puzzle.puzzleNumber)"),
                    message: Text(verbatim: "I solved today's puzzle!")
                ) {
                    Label(
                        NSLocalizedString("share.to-social", value: "Share Result", comment: "Share puzzle result"),
                        systemImage: "square.and.arrow.up"
                    )
                    .font(AppFont.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
                }
                .padding(.horizontal, AppLayout.padding)
                .padding(.bottom, AppLayout.padding)
            }
            .background(Color.appSurface)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", value: "Close", comment: "Close button")) {
                        dismiss()
                    }
                    .foregroundColor(.appTextSecondary)
                }
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 16) {
            Text("OnePuzzle")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(.appPrimary)

            Text(String.localizedStringWithFormat(
                NSLocalizedString("share.puzzle-number", value: "Puzzle #%d", comment: "Share puzzle number"),
                puzzle.puzzleNumber
            ))
            .font(AppFont.caption)
            .foregroundColor(.appTextSecondary)

            // Emoji grid — no answer leak
            VStack(spacing: 4) {
                ForEach(Array(puzzle.feedback.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, fb in
                            Text(emoji(for: fb.result))
                                .font(.system(.title3))
                        }
                    }
                }
                if !puzzle.isSolved {
                    HStack(spacing: 4) {
                        ForEach(0..<(puzzle.feedback.first?.count ?? 5), id: \.self) { _ in
                            Text("⬛")
                                .font(.system(.title3))
                        }
                    }
                }
            }

            Divider()
                .foregroundColor(.appBorder)

            Text(String.localizedStringWithFormat(
                puzzle.isSolved
                    ? NSLocalizedString("share.solved-in", value: "Solved in %d/%d", comment: "Solved in N/M")
                    : NSLocalizedString("share.not-solved", value: "Not solved", comment: "Failed to solve"),
                puzzle.guesses.count, puzzle.board.maxAttempts
            ))
            .font(AppFont.body)
            .foregroundColor(.appTextSecondary)
        }
        .padding(24)
        .background(Color.appSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }

    private var shareText: String {
        var text = "OnePuzzle #\(puzzle.puzzleNumber)\n"
        for row in puzzle.feedback {
            text += row.map { emoji(for: $0.result) }.joined()
            text += "\n"
        }
        if !puzzle.isSolved {
            text += String(repeating: "⬛", count: puzzle.feedback.first?.count ?? 5)
            text += "\n"
        }
        text += "\nhttps://onepuzzle.app"
        return text
    }

    private func emoji(for result: GuessResult) -> String {
        switch result {
        case .correct: return "🟩"
        case .misplaced: return "🟨"
        case .absent: return "⬛"
        }
    }
}
