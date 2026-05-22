import Foundation

// MARK: - GuessResult
enum GuessResult: Equatable {
    case correct     // letter in right position
    case misplaced   // letter in word but wrong position
    case absent      // letter not in word
}

// MARK: - LetterFeedback
struct LetterFeedback: Equatable {
    let letter: Character
    let result: GuessResult
}

// MARK: - PuzzleBoard
struct PuzzleBoard: Equatable {
    let targetWord: String
    let maxAttempts: Int
    var guesses: [String]
    var feedback: [[LetterFeedback]]
    var isSolved: Bool
    var isRevealed: Bool

    var isGameOver: Bool {
        isSolved || isRevealed || guesses.count >= maxAttempts
    }

    var attemptsRemaining: Int {
        maxAttempts - guesses.count
    }

    init(targetWord: String, maxAttempts: Int = 6) {
        self.targetWord = targetWord.uppercased()
        self.maxAttempts = maxAttempts
        self.guesses = []
        self.feedback = []
        self.isSolved = false
        self.isRevealed = false
    }

    mutating func submitGuess(_ word: String) -> Bool {
        let guess = word.uppercased()
        guard guess.count == targetWord.count,
              !isGameOver else { return false }

        let result = zip(guess, targetWord).map { (g, t) -> LetterFeedback in
            if g == t {
                return LetterFeedback(letter: g, result: .correct)
            } else if targetWord.contains(g) {
                return LetterFeedback(letter: g, result: .misplaced)
            } else {
                return LetterFeedback(letter: g, result: .absent)
            }
        }

        guesses.append(guess)
        feedback.append(result)

        if guess == targetWord {
            isSolved = true
        }

        return true
    }

    mutating func revealAnswer() {
        guard !isGameOver else { return }
        let result = targetWord.map {
            LetterFeedback(letter: $0, result: .correct)
        }
        guesses.append(targetWord)
        feedback.append(result)
        isRevealed = true
    }

    var keyboardMapping: [Character: GuessResult] {
        var mapping: [Character: GuessResult] = [:]
        for fb in feedback.flatMap({ $0 }) {
            let existing = mapping[fb.letter]
            if existing == .correct { continue }
            if fb.result == .correct {
                mapping[fb.letter] = .correct
            } else if fb.result == .misplaced, existing != .correct {
                mapping[fb.letter] = .misplaced
            } else if mapping[fb.letter] == nil {
                mapping[fb.letter] = .absent
            }
        }
        return mapping
    }
}

// MARK: - PuzzleConfig
struct PuzzleConfig {
    let puzzleNumber: Int
    let targetWord: String
    let maxAttempts: Int
    let date: Date
}
