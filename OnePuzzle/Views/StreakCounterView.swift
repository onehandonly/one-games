import SwiftUI

struct StreakCounterView: View {
    let value: Int
    let label: String

    @State private var animate = false

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(AppFont.streakNumber)
                .foregroundColor(.appSecondary)
                .scaleEffect(animate ? 1.1 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animate)
            Text(label)
                .font(AppFont.caption)
                .foregroundColor(.appTextSecondary)
        }
        .onAppear {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animate = false
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(label): \(value)")
    }
}
