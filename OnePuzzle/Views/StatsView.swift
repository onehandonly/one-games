import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var streakStore: [StreakStore]
    @Environment(\.dismiss) private var dismiss
    @Environment(DailyPuzzleService.self) private var puzzle

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                streakSection
                Divider()
                    .foregroundColor(.appBorder)
                statsGrid
                Divider()
                    .foregroundColor(.appBorder)
                guessDistribution
            }
            .padding(AppLayout.padding)
            .background(Color.appSurface)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", value: "Close", comment: "Close")) {
                        dismiss()
                    }
                    .foregroundColor(.appTextSecondary)
                }
            }
        }
    }

    private var streakSection: some View {
        HStack(spacing: 48) {
            StreakCounterView(
                value: streakStore.first?.currentStreak ?? 0,
                label: NSLocalizedString("stats.current-streak", value: "Current", comment: "Current streak")
            )
            StreakCounterView(
                value: streakStore.first?.longestStreak ?? 0,
                label: NSLocalizedString("stats.longest-streak", value: "Best", comment: "Longest streak")
            )
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 24) {
            statItem(
                value: "\(streakStore.first?.totalGamesPlayed ?? 0)",
                label: NSLocalizedString("stats.played", value: "Played", comment: "Games played")
            )
            statItem(
                value: "\(Int((streakStore.first?.winRate ?? 0) * 100))%",
                label: NSLocalizedString("stats.win-rate", value: "Win %", comment: "Win rate")
            )
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.streakNumber)
                .foregroundColor(.appTextPrimary)
            Text(label)
                .font(AppFont.caption)
                .foregroundColor(.appTextSecondary)
        }
    }

    private var guessDistribution: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("stats.guess-distribution", value: "Guess Distribution", comment: "Stats heading"))
                .font(AppFont.headline)
                .foregroundColor(.appTextPrimary)

            let dist = streakStore.first?.guessDistribution ?? [:]
            ForEach(1..<7, id: \.self) { attempt in
                let count = dist[attempt] ?? 0
                let maxCount = dist.values.max() ?? 1
                HStack(spacing: 8) {
                    Text("\(attempt)")
                        .font(AppFont.caption)
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 16)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appBorder)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appPrimary)
                                .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            if count > 0 {
                                Text("\(count)")
                                    .font(AppFont.caption)
                                    .foregroundColor(.white)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
    }
}
