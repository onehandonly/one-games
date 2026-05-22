import SwiftUI

struct KeyboardView: View {
    let onKeyTap: (Character) -> Void
    let onSubmit: () -> Void
    let letterMapping: [Character: GuessResult]

    private let rows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M"],
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    if rowIndex == 2 {
                        enterKey
                    }
                    ForEach(rows[rowIndex], id: \.self) { key in
                        keyButton(for: Character(key))
                    }
                    if rowIndex == 2 {
                        deleteKey
                    }
                }
            }
        }
    }

    private func keyButton(for char: Character) -> some View {
        Button {
            onKeyTap(char)
        } label: {
            Text(String(char))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(textColor(for: char))
                .frame(minWidth: 28, minHeight: AppLayout.tapTarget)
                .padding(.horizontal, 4)
                .background(backgroundColor(for: char))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var enterKey: some View {
        Button {
            onSubmit()
        } label: {
            Text("Enter")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 36, minHeight: AppLayout.tapTarget)
                .padding(.horizontal, 6)
                .background(Color.appCorrect)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var deleteKey: some View {
        Button {
            onKeyTap("⌫")
        } label: {
            Image(systemName: "delete.left")
                .font(.caption)
                .foregroundColor(.appTextPrimary)
                .frame(minWidth: 36, minHeight: AppLayout.tapTarget)
                .padding(.horizontal, 6)
                .background(Color.appBorder)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func backgroundColor(for char: Character) -> Color {
        guard let result = letterMapping[char] else {
            return Color.appSurfaceElevated
        }
        switch result {
        case .correct: return .appCorrect
        case .misplaced: return .appMisplaced
        case .absent: return .appAbsent
        }
    }

    private func textColor(for char: Character) -> Color {
        guard letterMapping[char] != nil else { return .appTextPrimary }
        return .white
    }
}
