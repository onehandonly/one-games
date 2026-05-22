import Foundation

// MARK: - PuzzleGenerator
// Produces a deterministic daily word puzzle from a date seed.
// This is a stub: word list is small; replace with a curated dictionary
// and a proper puzzle-authoring pipeline before public launch.
//
// Chosen puzzle type: Word-Guessing (Wordle-style).
// Rationale: simplest to implement cleanly for the MVP stub;
// shares the same model/view/service architecture as any word-based
// daily puzzle. Swappable once the product vision locks the final
// mechanic (see ONE-9 product-vision §10).

struct PuzzleGenerator {
    let wordLength: Int
    let maxAttempts: Int

    private let wordList: [String]

    init(wordLength: Int = 5, maxAttempts: Int = 6) {
        self.wordLength = wordLength
        self.maxAttempts = maxAttempts
        self.wordList = Self.loadWordList(length: wordLength)
    }

    func generate(for date: Date) -> PuzzleConfig {
        let puzzleNumber = Self.puzzleNumber(from: date)
        let seed = Self.dailySeed(from: date)
        let index = abs(seed) % wordList.count
        let targetWord = wordList[index].uppercased()

        return PuzzleConfig(
            puzzleNumber: puzzleNumber,
            targetWord: targetWord,
            maxAttempts: maxAttempts,
            date: date
        )
    }

    // Deterministic puzzle index from date (epoch days)
    static func puzzleNumber(from date: Date) -> Int {
        let epoch = Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let days = Calendar(identifier: .gregorian)
            .dateComponents([.day], from: epoch, to: date)
        return days.day ?? 0
    }

    // Deterministic seed for randomness from date hash
    static func dailySeed(from date: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return (comps.year ?? 2024) * 10000
            + (comps.month ?? 1) * 100
            + (comps.day ?? 1)
    }

    // Stub word list — ~100 common 5-letter words.
    // In production, replace with a curated list of ~2k common words
    // of uniform difficulty, vetted for offensiveness and ambiguity.
    private static func loadWordList(length: Int) -> [String] {
        let words: [String] = [
            "apple", "crane", "table", "house", "piano",
            "beach", "drink", "eagle", "flame", "grape",
            "heart", "image", "jolly", "knack", "lemon",
            "mango", "noble", "ocean", "pearl", "queen",
            "rapid", "sugar", "tiger", "ultra", "vivid",
            "whale", "xenon", "yacht", "zebra", "brave",
            "crisp", "dwarf", "elite", "frost", "ghost",
            "harsh", "ivory", "joker", "kebab", "lunar",
            "minor", "nymph", "orbit", "pixel", "quota",
            "radar", "solar", "trace", "union", "valor",
            "waltz", "amend", "bloom", "candy", "daisy",
            "ember", "fable", "gamma", "haven", "index",
            "jewel", "kayak", "linen", "magic", "nanny",
            "olive", "punch", "quilt", "rinse", "snack",
            "torch", "umbra", "vocal", "wound", "yearn",
            "zonal", "arena", "bliss", "chord", "depth",
            "excel", "focal", "grain", "humor", "input",
            "jumbo", "kneel", "layer", "mirth", "ninja",
            "opera", "prism", "quasi", "rally", "scalp",
            "tempo", "uncut", "vault", "webby", "xerox",
            "youth", "zesty", "ample", "brink", "charm",
        ]
        return words.filter { $0.count == length }
    }
}
