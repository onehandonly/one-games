import SwiftUI

struct NotificationPrePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAllow: () -> Void = {}
    var onDecline: () -> Void = {}

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer().frame(height: Spacing.md)

            VStack(spacing: Spacing.md) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appPrimary)
                    .accessibilityHidden(true)

                Text("Nudge for tomorrow's\npuzzle?")
                    .font(Typography.title)
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("One quiet notification a day, at the time you usually play. That's it.")
                    .font(Typography.body)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            VStack(spacing: Spacing.sm) {
                Button {
                    onAllow()
                    dismiss()
                } label: {
                    Text("Sure, nudge me")
                        .font(Typography.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .padding(.horizontal, Spacing.lg)
                .accessibilityLabel("Sure, nudge me")
                .accessibilityHint("Enables a daily notification for the puzzle")

                Button {
                    onDecline()
                    dismiss()
                } label: {
                    Text("Not right now")
                        .font(Typography.body)
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .padding(.horizontal, Spacing.lg)
                .accessibilityLabel("Not right now")
            }
            .padding(.bottom, Spacing.lg)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(Color.appSurface)
    }
}

#Preview {
    NotificationPrePromptSheet()
}
