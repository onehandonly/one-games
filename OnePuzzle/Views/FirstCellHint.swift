import SwiftUI

struct FirstCellHint: ViewModifier {
    let isFirstCell: Bool
    let shouldShow: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isFirstCell && shouldShow {
                    if reduceMotion {
                        // Static ring — same affordance, no motion
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(Color.appPrimary, lineWidth: 1.5)
                    } else {
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(Color.appPrimary, lineWidth: 2)
                            .scaleEffect(pulsing ? 1.04 : 1.0)
                            .opacity(pulsing ? 0.85 : 1.0)
                            .animation(
                                .easeInOut(duration: Motion.standard)
                                    .repeatCount(2, autoreverses: true),
                                value: pulsing
                            )
                    }
                }
            }
            .onAppear {
                guard isFirstCell && shouldShow && !reduceMotion else { return }
                pulsing = true
            }
    }
}

extension View {
    func firstCellHint(isFirstCell: Bool, shouldShow: Bool) -> some View {
        modifier(FirstCellHint(isFirstCell: isFirstCell, shouldShow: shouldShow))
    }
}
