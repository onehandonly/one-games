import Foundation
import SwiftData

@Model
final class StreakStore {
    var currentStreak: Int
    var longestStreak: Int
    var lastPlayedDate: Date?
    var totalGamesPlayed: Int
    var totalGamesWon: Int
    var guessDistribution: [Int: Int] // attempts -> count

    init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastPlayedDate: Date? = nil,
        totalGamesPlayed: Int = 0,
        totalGamesWon: Int = 0,
        guessDistribution: [Int: Int] = [:]
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastPlayedDate = lastPlayedDate
        self.totalGamesPlayed = totalGamesPlayed
        self.totalGamesWon = totalGamesWon
        self.guessDistribution = guessDistribution
    }

    func recordWin(attempts: Int) {
        totalGamesPlayed += 1
        totalGamesWon += 1
        guessDistribution[attempts, default: 0] += 1

        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastPlayedDate,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return
        }

        if let last = lastPlayedDate,
           Calendar.current.isDateInYesterday(last) {
            currentStreak += 1
        } else if lastPlayedDate == nil {
            currentStreak = 1
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastPlayedDate = today
    }

    func recordLoss() {
        totalGamesPlayed += 1
        currentStreak = 0
        lastPlayedDate = Calendar.current.startOfDay(for: Date())
    }

    var winRate: Double {
        guard totalGamesPlayed > 0 else { return 0 }
        return Double(totalGamesWon) / Double(totalGamesPlayed)
    }
}
