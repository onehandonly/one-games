import SwiftUI

struct GuessRowView: View {
    let guess: String
    let feedback: [LetterFeedback]
    let targetLength: Int
    let isActive: Bool
    let showFirstCellHint: Bool = false

    var body: some View {
        HStack(spacing: AppLayout.gridSpacing) {
            ForEach(0..<targetLength, id: \.self) { index in
                letterCell(at: index)
            }
        }
    }

    @ViewBuilder
    private func letterCell(at index: Int) -> some View {
        let letter: Character = index < guess.count
            ? guess[guess.index(guess.startIndex, offsetBy: index)]
            : " "
        let fb: LetterFeedback? = index < feedback.count ? feedback[index] : nil
        let isFirstCell = index == 0 && guess.isEmpty && isActive

        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                .fill(backgroundColor(for: fb))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                        .stroke(isActive ? Color.appPrimary : Color.appBorder, lineWidth: isActive ? 2 : 1)
                )

            if letter != " " {
                Text(String(letter))
                    .font(AppFont.puzzleCell)
                    .foregroundColor(textColor(for: fb))
            }
        }
        .frame(maxWidth: 64)
        .minimumScaleFactor(0.6)
        .firstCellHint(isFirstCell: isFirstCell, shouldShow: showFirstCellHint)
    }

    private func backgroundColor(for fb: LetterFeedback?) -> Color {
        guard let fb else { return .clear }
        switch fb.result {
        case .correct: return .appCorrect
        case .misplaced: return .appMisplaced
        case .absent: return .appAbsent
        }
    }

    private func textColor(for fb: LetterFeedback?) -> Color {
        guard fb != nil else { return .appTextPrimary }
        return .white
    }
}
