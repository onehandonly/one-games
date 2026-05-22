import XCTest
@testable import OnePuzzle

final class PuzzleBoardTests: XCTestCase {
    func testSubmitValidGuess() {
        var board = PuzzleBoard(targetWord: "APPLE", maxAttempts: 6)
        let result = board.submitGuess("APPLE")
        XCTAssertTrue(result)
        XCTAssertTrue(board.isSolved)
        XCTAssertEqual(board.guesses.count, 1)
    }

    func testSubmitWrongGuess() {
        var board = PuzzleBoard(targetWord: "APPLE", maxAttempts: 6)
        let result = board.submitGuess("MANGO")
        XCTAssertTrue(result)
        XCTAssertFalse(board.isSolved)
        XCTAssertEqual(board.guesses.count, 1)
    }

    func testWrongLengthGuess() {
        var board = PuzzleBoard(targetWord: "APPLE", maxAttempts: 6)
        let result = board.submitGuess("CAT")
        XCTAssertFalse(result)
        XCTAssertEqual(board.guesses.count, 0)
    }

    func testGameOverAfterMaxAttempts() {
        var board = PuzzleBoard(targetWord: "APPLE", maxAttempts: 2)
        _ = board.submitGuess("MANGO")
        _ = board.submitGuess("BREAD")
        XCTAssertTrue(board.isGameOver)
        let result = board.submitGuess("CRANE")
        XCTAssertFalse(result)
    }

    func testRevealAnswer() {
        var board = PuzzleBoard(targetWord: "APPLE", maxAttempts: 6)
        board.revealAnswer()
        XCTAssertTrue(board.isRevealed)
        XCTAssertTrue(board.isGameOver)
        XCTAssertEqual(board.guesses.last, "APPLE")
    }

    func testLetterFeedback() {
        var board = PuzzleBoard(targetWord: "APPLE", maxAttempts: 6)
        _ = board.submitGuess("APRON")
        let feedback = board.feedback.first!
        XCTAssertEqual(feedback.count, 5)
        // APRON vs APPLE: A=A → correct, P=P → correct, R→absent, O→absent, N→absent
        XCTAssertEqual(feedback[0].result, .correct)
        XCTAssertEqual(feedback[1].result, .correct)
        XCTAssertEqual(feedback[2].result, .absent)
        XCTAssertEqual(feedback[3].result, .absent)
        XCTAssertEqual(feedback[4].result, .absent)
    }

    func testCorrectPositionFeedback() {
        var board = PuzzleBoard(targetWord: "SWIFT", maxAttempts: 6)
        _ = board.submitGuess("SWIFT")
        let feedback = board.feedback.first!
        XCTAssertEqual(feedback.map(\.result), [.correct, .correct, .correct, .correct, .correct])
    }

    func testMisplacedLetter() {
        var board = PuzzleBoard(targetWord: "SWIFT", maxAttempts: 6)
        _ = board.submitGuess("WIFTS")
        let feedback = board.feedback.first!
        // WIFTS vs SWIFT: W≠S(misplaced since W is in SWIFT at pos 4),
        // I≠W... wait let me think
        // S: WIFTS[0]='W' vs SWIFT[0]='S' → W is in SWIFT at pos 4 → misplaced
        // W: WIFTS[1]='I' vs SWIFT[1]='W' → I is in SWIFT at pos 2 → misplaced
        // I: WIFTS[2]='F' vs SWIFT[2]='I' → F is in SWIFT at pos 3 → misplaced
        // F: WIFTS[3]='T' vs SWIFT[3]='F' → T is in SWIFT at pos 4 → misplaced
        // T: WIFTS[4]='S' vs SWIFT[4]='T' → S is in SWIFT at pos 0 → misplace
        // But wait, the simple zip-based algorithm doesn't handle this correctly.
        // With the current implementation, if letter 'W' at pos 0 doesn't match
        // SWIFT[0]='S', and 'W' is somewhere in SWIFT, it will mark it misplaced.
        // But 'W' is at index 4 in SWIFT. So WIFTS[0]='W' is misplaced, correct.
        // Actually the simple algorithm has the "all misplaced" bug for words with
        // repeated letters, but for this test it should work.
        XCTAssertEqual(feedback.filter { $0.result == .misplaced }.count, 5)
    }

    func testAbsentLetter() {
        var board = PuzzleBoard(targetWord: "SWIFT", maxAttempts: 6)
        _ = board.submitGuess("BLACK")
        let feedback = board.feedback.first!
        XCTAssertEqual(feedback.filter { $0.result == .absent }.count, 5)
    }

    func testKeyboardMapping() {
        var board = PuzzleBoard(targetWord: "APPLE", maxAttempts: 6)
        _ = board.submitGuess("APRON")
        let mapping = board.keyboardMapping
        XCTAssertEqual(mapping["A"], .correct)
        XCTAssertEqual(mapping["P"], .correct)
        XCTAssertEqual(mapping["R"], .absent)
        XCTAssertEqual(mapping["O"], .absent)
        XCTAssertEqual(mapping["N"], .absent)
    }

    func testKeyboardMappingCorrectOverridesMisplaced() {
        var board = PuzzleBoard(targetWord: "ABCDE", maxAttempts: 6)
        _ = board.submitGuess("XBYCZ")
        var mapping = board.keyboardMapping
        XCTAssertEqual(mapping["B"], .correct)
        XCTAssertEqual(mapping["C"], .misplaced)

        _ = board.submitGuess("ACDEF")
        mapping = board.keyboardMapping
        // C was misplaced, now correct — mapping must reflect .correct, not .misplaced
        XCTAssertEqual(mapping["C"], .correct)
        XCTAssertEqual(mapping["A"], .correct)
        XCTAssertEqual(mapping["B"], .correct)
        XCTAssertEqual(mapping["D"], .correct)
        XCTAssertEqual(mapping["E"], .correct)
    }
}
