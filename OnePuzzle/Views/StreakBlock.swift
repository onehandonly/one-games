import SwiftUI

struct StreakBlock: View {
    let currentStreak: Int
    let longestStreak: Int
    /// 7 booleans: index 0 = 6 days ago, index 6 = today.
    let solvedStatusLast7: [Bool]
    let hasSolvedToday: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotAnimated = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    var body: some View {
        if currentStreak == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(Typography.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Text(Self.dayFormatter.string(from: Date()))
                        .font(Typography.title)
                        .foregroundStyle(Color.appTextPrimary)
                }

                dotStrip
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dotAccessibilityLabel)
                    .accessibilityHint("Filled dot means you solved that day")

                streakText

                if longestStreak > currentStreak && longestStreak >= 3 {
                    Text("Personal best: \(longestStreak) days")
                        .font(Typography.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .onChange(of: hasSolvedToday) { _, newValue in
                guard newValue && !reduceMotion else { return }
                withAnimation(.spring(response: Motion.celebrate, dampingFraction: 0.6)) {
                    dotAnimated = true
                }
            }
        }
    }

    private var dotStrip: some View {
        HStack(spacing: Spacing.xs + 2) {
            ForEach(0..<7, id: \.self) { index in
                dot(solved: solvedStatusLast7[index], isToday: index == 6)
            }
        }
    }

    @ViewBuilder
    private func dot(solved: Bool, isToday: Bool) -> some View {
        let diameter: CGFloat = 10
        ZStack {
            if solved {
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(isToday && dotAnimated ? 1.05 : 1.0)
            } else if isToday {
                Circle()
                    .stroke(Color.appPrimary, lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
            } else {
                Circle()
                    .fill(Color.appBorder)
                    .frame(width: diameter, height: diameter)
            }
        }
    }

    private var streakText: some View {
        (
            Text("\(currentStreak)")
                .foregroundStyle(Color.appSecondary)
            +
            Text("-day streak")
                .foregroundStyle(Color.appTextPrimary)
        )
        .font(Typography.body)
    }

    private var dotAccessibilityLabel: String {
        let solved = solvedStatusLast7.filter { $0 }.count
        return "\(solved) of last 7 days solved"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.xl) {
        StreakBlock(
            currentStreak: 0, longestStreak: 0,
            solvedStatusLast7: Array(repeating: false, count: 7),
            hasSolvedToday: false
        )

        Divider()

        StreakBlock(
            currentStreak: 1, longestStreak: 1,
            solvedStatusLast7: [false, false, false, false, false, false, true],
            hasSolvedToday: true
        )

        Divider()

        StreakBlock(
            currentStreak: 4, longestStreak: 7,
            solvedStatusLast7: [false, false, false, true, true, true, false],
            hasSolvedToday: false
        )

        Divider()

        StreakBlock(
            currentStreak: 7, longestStreak: 7,
            solvedStatusLast7: Array(repeating: true, count: 7),
            hasSolvedToday: true
        )
    }
    .padding()
    .background(Color.appSurface)
}
