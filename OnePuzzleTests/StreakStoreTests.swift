import XCTest
@testable import OnePuzzle

final class StreakStoreTests: XCTestCase {
    private var store: StreakStore!
    private var testDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "com.onepuzzle.test.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        store = StreakStore(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(store.currentStreak, 0)
        XCTAssertEqual(store.longestStreak, 0)
        XCTAssertNil(store.lastPlayedDate)
        XCTAssertEqual(store.totalGamesPlayed, 0)
        XCTAssertEqual(store.totalGamesWon, 0)
    }

    func testRecordWinStartsStreak() {
        store.recordWin(attempts: 3)
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.longestStreak, 1)
        XCTAssertEqual(store.totalGamesPlayed, 1)
        XCTAssertEqual(store.totalGamesWon, 1)
        XCTAssertNotNil(store.lastPlayedDate)
    }

    func testRecordLossDoesNotResetStreak() {
        store.recordWin(attempts: 3)
        XCTAssertEqual(store.currentStreak, 1)
        store.recordLoss()
        // Per spec §4.1: streak resets only on missed DAYS, not on a loss.
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.longestStreak, 1)
        XCTAssertEqual(store.totalGamesPlayed, 2)
        XCTAssertEqual(store.totalGamesWon, 1)
    }

    func testDoubleWinSameDayNoDoubleCount() {
        store.recordWin(attempts: 3)
        store.recordWin(attempts: 4)
        // Second win on same day is a no-op for streak.
        XCTAssertEqual(store.currentStreak, 1)
        XCTAssertEqual(store.longestStreak, 1)
        XCTAssertEqual(store.totalGamesPlayed, 2)
        XCTAssertEqual(store.totalGamesWon, 2)
    }

    func testGuessDistribution() {
        store.recordWin(attempts: 3)
        store.recordWin(attempts: 4)
        store.recordWin(attempts: 3)
        let dist = store.guessDistribution
        XCTAssertEqual(dist[3], 2)
        XCTAssertEqual(dist[4], 1)
    }

    func testWinRate() {
        store.recordWin(attempts: 3)
        store.recordWin(attempts: 4)
        store.recordLoss()
        XCTAssertEqual(store.winRate, 2.0 / 3.0, accuracy: 0.001)
    }

    func testSolvedStatusLast7Days_noSolves() {
        let status = store.solvedStatusLast7Days()
        XCTAssertEqual(status.count, 7)
        XCTAssertFalse(status.contains(true))
    }

    func testSolvedStatusLast7Days_solvedToday() {
        store.recordWin(attempts: 2)
        let status = store.solvedStatusLast7Days()
        XCTAssertEqual(status.count, 7)
        XCTAssertTrue(status[6]) // index 6 = today
    }

    func testHasAlreadySolvedToday_afterWin() {
        XCTAssertFalse(store.hasAlreadySolvedToday)
        store.recordWin(attempts: 3)
        XCTAssertTrue(store.hasAlreadySolvedToday)
    }
}
