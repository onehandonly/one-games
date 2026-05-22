import Foundation
import Observation

@Observable
final class StreakStore {
    private(set) var currentStreak: Int
    private(set) var longestStreak: Int
    private(set) var lastPlayedDate: Date?
    private(set) var totalGamesPlayed: Int
    private(set) var totalGamesWon: Int
    private(set) var guessDistribution: [Int: Int]
    private(set) var recentSolvedDays: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentStreak = defaults.integer(forKey: StreakDefaults.currentStreak)
        self.longestStreak = defaults.integer(forKey: StreakDefaults.longestStreak)
        self.lastPlayedDate = defaults.object(forKey: StreakDefaults.lastSolvedDate) as? Date
        self.totalGamesPlayed = defaults.integer(forKey: StreakDefaults.daysPlayedTotal)
        self.totalGamesWon = defaults.integer(forKey: "onepuzzle.totalGamesWon")
        self.recentSolvedDays = Set(defaults.stringArray(forKey: "onepuzzle.recentSolvedDays") ?? [])

        if let data = defaults.data(forKey: "onepuzzle.guessDistribution"),
           let raw = try? JSONDecoder().decode([String: Int].self, from: data) {
            var dict = [Int: Int]()
            for (k, v) in raw { if let i = Int(k) { dict[i] = v } }
            self.guessDistribution = dict
        } else {
            self.guessDistribution = [:]
        }
    }

    var hasAlreadySolvedToday: Bool {
        guard let last = lastPlayedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    var winRate: Double {
        guard totalGamesPlayed > 0 else { return 0 }
        return Double(totalGamesWon) / Double(totalGamesPlayed)
    }

    func recordWin(attempts: Int) {
        totalGamesPlayed += 1
        totalGamesWon += 1
        guessDistribution[attempts, default: 0] += 1
        saveGuessDistribution()

        let today = Calendar.current.startOfDay(for: Date())
        let todayStr = Self.dateString(for: today)

        guard !hasAlreadySolvedToday else {
            persist()
            return
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        if let last = lastPlayedDate, Calendar.current.isDate(last, inSameDayAs: yesterday) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastPlayedDate = today
        recentSolvedDays.insert(todayStr)
        pruneOldDays(before: today)
        persist()
    }

    // A loss doesn't affect the streak — only missed calendar days do.
    func recordLoss() {
        totalGamesPlayed += 1
        defaults.set(totalGamesPlayed, forKey: StreakDefaults.daysPlayedTotal)
    }

    // Returns a 7-element array: index 0 = 6 days ago, index 6 = today.
    func solvedStatusLast7Days() -> [Bool] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).map { daysAgo in
            let day = Calendar.current.date(byAdding: .day, value: -(6 - daysAgo), to: today)!
            return recentSolvedDays.contains(Self.dateString(for: day))
        }
    }

    private func pruneOldDays(before today: Date) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: today)!
        recentSolvedDays = recentSolvedDays.filter { str in
            guard let date = Self.date(from: str) else { return false }
            return date >= cutoff
        }
    }

    private func persist() {
        defaults.set(currentStreak, forKey: StreakDefaults.currentStreak)
        defaults.set(longestStreak, forKey: StreakDefaults.longestStreak)
        defaults.set(lastPlayedDate, forKey: StreakDefaults.lastSolvedDate)
        defaults.set(totalGamesPlayed, forKey: StreakDefaults.daysPlayedTotal)
        defaults.set(totalGamesWon, forKey: "onepuzzle.totalGamesWon")
        defaults.set(Array(recentSolvedDays), forKey: "onepuzzle.recentSolvedDays")
    }

    private func saveGuessDistribution() {
        var raw = [String: Int]()
        for (k, v) in guessDistribution { raw[String(k)] = v }
        if let data = try? JSONEncoder().encode(raw) {
            defaults.set(data, forKey: "onepuzzle.guessDistribution")
        }
    }

    static func dateString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: string)
    }
}

enum StreakDefaults {
    static let currentStreak    = "onepuzzle.currentStreak"
    static let longestStreak    = "onepuzzle.longestStreak"
    static let lastSolvedDate   = "onepuzzle.lastSolvedDate"
    static let daysPlayedTotal  = "onepuzzle.daysPlayedTotal"
}
