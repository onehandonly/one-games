import XCTest
@testable import OnePuzzle

final class PuzzleGeneratorTests: XCTestCase {
    var generator: PuzzleGenerator!

    override func setUp() {
        super.setUp()
        generator = PuzzleGenerator()
    }

    func testPuzzleNumberIsDeterministic() {
        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        let config1 = generator.generate(for: date1)
        let config2 = generator.generate(for: date2)

        XCTAssertEqual(config1.puzzleNumber, config2.puzzleNumber)
        XCTAssertEqual(config1.targetWord, config2.targetWord)
    }

    func testDifferentDaysGiveDifferentPuzzles() {
        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 16))!

        let config1 = generator.generate(for: date1)
        let config2 = generator.generate(for: date2)

        XCTAssertNotEqual(config1.puzzleNumber, config2.puzzleNumber)
    }

    func testPuzzleNumberStartsFrom2024() {
        let launchDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let config = generator.generate(for: launchDate)
        XCTAssertEqual(config.puzzleNumber, 0)
    }

    func testPuzzleConfigOutput() {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let config = generator.generate(for: date)

        XCTAssertEqual(config.targetWord.count, 5)
        XCTAssertEqual(config.maxAttempts, 6)
        XCTAssertFalse(config.targetWord.isEmpty)
        XCTAssertTrue(config.targetWord.allSatisfy { $0.isLetter })
    }

    func testSeedConsistency() {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let seed1 = PuzzleGenerator.dailySeed(from: date)
        let seed2 = PuzzleGenerator.dailySeed(from: date)
        XCTAssertEqual(seed1, seed2)
    }
}
