import Foundation
import Observation

@MainActor
@Observable
final class DailyPuzzleService {
    private let generator: PuzzleGenerator
    private(set) var board: PuzzleBoard
    private(set) var puzzleNumber: Int
    private(set) var date: Date

    var currentGuess: String = ""

    var isGameOver: Bool { board.isGameOver }
    var isSolved: Bool { board.isSolved }
    var attemptsRemaining: Int { board.attemptsRemaining }
    var keyboardMapping: [Character: GuessResult] { board.keyboardMapping }
    var guesses: [String] { board.guesses }
    var feedback: [[LetterFeedback]] { board.feedback }

    init(generator: PuzzleGenerator = PuzzleGenerator()) {
        self.generator = generator
        let today = Calendar.current.startOfDay(for: Date())
        self.date = today
        let config = generator.generate(for: today)
        self.puzzleNumber = config.puzzleNumber
        self.board = PuzzleBoard(
            targetWord: config.targetWord,
            maxAttempts: config.maxAttempts
        )
    }

    func submitGuess() -> Bool {
        guard !board.isGameOver,
              currentGuess.count == board.targetWord.count else {
            return false
        }
        let result = board.submitGuess(currentGuess)
        if result {
            currentGuess = ""
        }
        return result
    }

    func addLetter(_ letter: Character) {
        guard !board.isGameOver,
              currentGuess.count < board.targetWord.count else { return }
        currentGuess.append(letter.uppercased())
    }

    func removeLetter() {
        guard !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
    }

    func revealAnswer() {
        board.revealAnswer()
    }

    // Force a specific puzzle for previews/testing
    func loadPreview(puzzleNumber: Int, targetWord: String) {
        self.puzzleNumber = puzzleNumber
        self.board = PuzzleBoard(targetWord: targetWord, maxAttempts: 6)
    }
}
