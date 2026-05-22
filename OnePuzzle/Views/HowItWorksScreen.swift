import SwiftUI

struct HowItWorksScreen: View {
    @Environment(FirstRunState.self) private var firstRunState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Static 4x4 example grid: 0 means empty cell
    private let exampleGrid: [[Int]] = [
        [1, 0, 0, 3],
        [0, 0, 2, 0],
        [0, 4, 0, 0],
        [2, 0, 0, 0],
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.standard)) {
                        firstRunState.hasSeenWelcome = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Back")
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text("How it works")
                        .font(Typography.title)
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(.horizontal, Spacing.lg)

                    // Mini puzzle — static, non-interactive
                    miniPuzzle
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Example puzzle: 4 by 4 grid with some numbers filled in")

                    // Rules
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        rule("Each row, column, and block holds 1–4 once.")
                        rule("Tap a cell, then a number to place it.")
                        rule("One puzzle a day. Take your time.")
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.standard)) {
                    firstRunState.hasSeenHowItWorks = true
                }
            } label: {
                Text("Start today's")
                    .font(Typography.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
            .background(Color.appSurface)
            .accessibilityLabel("Start today's puzzle")
            .accessibilityHint("Opens the daily puzzle")
        }
        .background(Color.appSurface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var miniPuzzle: some View {
        VStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { col in
                        miniCell(value: exampleGrid[row][col])
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.appSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .shadow(color: .black.opacity(0.04), radius: Elevation.e1, x: 0, y: 1)
        .frame(maxWidth: 240)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
    }

    private func miniCell(value: Int) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.appSurfaceElevated)
                .overlay(
                    Rectangle()
                        .stroke(Color.appBorder, lineWidth: 1)
                )

            if value != 0 {
                Text("\(value)")
                    .font(Typography.puzzleDigit)
                    .foregroundStyle(Color.appPrimary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(Color.appPrimary)
                .frame(width: 4, height: 4)
                .padding(.top, 8)

            Text(text)
                .font(Typography.body)
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HowItWorksScreen()
        .environment(FirstRunState())
}
