import SwiftUI

struct WelcomeScreen: View {
    @Environment(FirstRunState.self) private var firstRunState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("◆")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color.appPrimary)
                    .accessibilityHidden(true)

                Spacer().frame(height: Spacing.xl)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("One puzzle.\nEvery day.")
                        .font(Typography.display)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("A small moment\nof focus.")
                        .font(Typography.body)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("One puzzle. Every day. A small moment of focus.")
            }
            .padding(.horizontal, Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: Spacing.sm) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: Motion.standard)) {
                        firstRunState.hasSeenWelcome = true
                    }
                } label: {
                    Text("Continue")
                        .font(Typography.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .padding(.horizontal, Spacing.lg)
                .accessibilityLabel("Continue")
                .accessibilityHint("Opens a quick explainer")

                Text("No account needed")
                    .font(Typography.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appSurface)
    }
}

#Preview {
    WelcomeScreen()
        .environment(FirstRunState())
}
