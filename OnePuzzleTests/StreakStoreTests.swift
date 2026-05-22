import XCTest
@testable import OnePuzzle

final class StreakStoreTests: XCTestCase {
    func testInitialState() {
        let store = StreakStore()
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.longestStreak, 0)
        XCTAssertNil(store.lastPlayedDate)
        XCTAssertEqual(store.totalGamesPlayed, 0)
        XCTAssertEqual(store.totalGamesWon, 0)
    }

    func testRecordWinStartsStreak() {
        let store = StreakStore()
        store.recordWin(attempts: 3)
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.longestStreak, 1)
        XCTAssertEqual(store.totalGamesPlayed, 1)
        XCTAssertEqual(store.totalGamesWon, 1)
    }

    func testRecordLossResetsStreak() {
        let store = StreakStore()
        store.recordWin(attempts: 3)
        store.recordWin(attempts: 4)
        XCTAssertEqual(store.currentStreak, 2)
        store.recordLoss()
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.longestStreak, 2)
        XCTAssertEqual(store.totalGamesPlayed, 3)
        XCTAssertEqual(store.totalGamesWon, 2)
    }

    func testGuessDistribution() {
        let store = StreakStore()
        store.recordWin(attempts: 3)
        store.recordWin(attempts: 4)
        store.recordWin(attempts: 3)
        let dist = store.guessDistribution
        XCTAssertEqual(dist[3], 2)
        XCTAssertEqual(dist[4], 1)
    }

    func testWinRate() {
        let store = StreakStore()
        store.recordWin(attempts: 3)
        store.recordWin(attempts: 4)
        store.recordLoss()
        XCTAssertEqual(store.winRate, 2.0 / 3.0, accuracy: 0.001)
    }
}
