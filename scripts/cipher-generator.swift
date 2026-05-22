#!/usr/bin/env swift
//
// cipher-generator.swift
// ONE Games — Daily Cipher Puzzle Generator
//
// Usage:
//   swift cipher-generator.swift --quote "The truth is rarely pure." --author "Oscar Wilde" \
//       --date 2026-06-01 --difficulty E
//
//   swift cipher-generator.swift --batch quotes.json --output manifests/
//
//   swift cipher-generator.swift --verify manifest.json
//
// Output: JSON puzzle manifests conforming to the DailyPuzzleManifest schema.
//
// Requirements:
//   - Swift 5.9+ (run with `swift cipher-generator.swift ...` or compile with swiftc)
//   - No external dependencies
//

import Foundation

// ---------------------------------------------------------------------------
// MARK: - Types
// ---------------------------------------------------------------------------

/// Difficulty tier for the daily cipher puzzle.
enum Difficulty: String, Codable {
    case easy   = "E"
    case medium = "M"
    case hard   = "H"
}

/// Risk flags for editorial compliance (mirrors ONE-44 quote-library conventions).
enum RiskFlag: String, Codable {
    case none     = "None"
    case att      = "ATT"   // Attribution uncertain; acceptable
    case short_   = "SHORT" // Under 8 words; cipher may be too short
    case esc      = "ESC"   // Escalate to CEO; do not schedule
}

/// Hint metadata for the player hint system.
struct HintMetadata: Codable {
    /// Letters revealed (in plaintext) when player uses hint level 1.
    let level1RevealedLetters: [String]
    /// Letters revealed (in plaintext) when player uses hint level 2.
    let level2RevealedLetters: [String]
    /// Maximum number of hints available per puzzle.
    let maxHints: Int
}

/// Statistics safe to include on the share-card. Contains NO plaintext, author, or word count.
struct ShareCardStats: Codable {
    /// Day index in the rotation schedule (opaque; does not leak date of publish).
    let dayIndex: Int
    /// Number of cipher letters used in the puzzle (i.e., distinct ciphertext letters).
    let cipherLetterCount: Int
    /// Total character length of the plaintext (spaces + punctuation included).
    let totalCharCount: Int
    /// Difficulty tier code ("E", "M", or "H").
    let difficultyTag: String
    /// True if the puzzle has any single-letter words (anchor clues for player).
    let hasSingleLetterWords: Bool
}

/// The daily puzzle manifest produced by this generator.
/// All fields are required; optional fields are marked with a comment.
struct DailyPuzzleManifest: Codable {
    // --- Scheduling metadata ---
    /// Unique puzzle identifier: "cipher-YYYYMMDD" or an opaque UUID.
    let puzzleId: String
    /// ISO-8601 date this puzzle is scheduled to run, e.g. "2026-06-01".
    let scheduledDate: String
    /// Day index counter (1-based, monotonically increasing across the app's life).
    let dayIndex: Int

    // --- Quote metadata ---
    /// Quote ID from the ONE-44 quote library (e.g. "E-01").
    let quoteId: String
    /// Plaintext of the quote, spaces and punctuation preserved, Unicode-normalized to NFC.
    let quotePlaintext: String
    /// Author attribution string, e.g. "Oscar Wilde" or "Traditional".
    let quoteAuthor: String
    /// Optional source/work citation, e.g. "The Importance of Being Earnest (1895)".
    let quoteSource: String?
    /// Word count of the plaintext (for editorial validation; not exposed in share-card).
    let wordCount: Int

    // --- Cipher mapping ---
    /// Bijective substitution mapping: keys are plaintext UPPERCASE letters (A–Z),
    /// values are the corresponding ciphertext UPPERCASE letters.
    /// Invariants: no self-maps (k != v), no duplicate values (bijective).
    let cipherMapping: [String: String]
    /// Ciphertext of the quote, derived by applying cipherMapping to each letter.
    let quoteCiphertext: String

    // --- Difficulty and hints ---
    /// Difficulty tier: "E" | "M" | "H".
    let difficulty: String
    /// Hint metadata for the hint system.
    let hints: HintMetadata

    // --- Share-card safe stats (no plaintext leaks) ---
    let shareCardStats: ShareCardStats

    // --- Editorial compliance ---
    /// Risk flag from the ONE-44 editorial policy.
    let riskFlag: String
    /// ISO-8601 datetime this manifest was generated.
    let generatedAt: String
    /// Version of the manifest schema.
    let schemaVersion: Int
}

// ---------------------------------------------------------------------------
// MARK: - Cipher Generation
// ---------------------------------------------------------------------------

/// Generates a deterministic, valid monoalphabetic substitution cipher mapping.
///
/// - Parameters:
///   - seed: Deterministic seed derived from the quote text + scheduled date.
/// - Returns: A dictionary mapping each UPPERCASE plaintext letter to a unique
///            UPPERCASE ciphertext letter, with no self-maps.
///
/// Algorithm (Fisher-Yates with linear-congruential PRNG seeded from `seed`):
/// 1. Start with alphabet A-Z.
/// 2. Shuffle using an LCG PRNG seeded deterministically.
/// 3. Fix any self-maps using cyclic rotation of adjacent positions.
/// 4. Verify: bijective, no self-maps, all 26 letters covered.
func generateCipherMapping(seed: UInt64) -> [String: String] {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    var shuffled = alphabet

    // Linear-Congruential Generator (constants from Knuth / MMIX)
    var state = seed
    func nextRandom() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    // Fisher-Yates shuffle
    for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
        let j = Int(nextRandom() % UInt64(i + 1))
        shuffled.swapAt(i, j)
    }

    // Resolve self-maps: if shuffled[i] == alphabet[i], swap with next (wrapping)
    // Repeat until no self-maps remain (in practice 0–1 passes needed).
    var maxPasses = 10
    while maxPasses > 0 {
        var hasSelfMap = false
        for i in 0..<alphabet.count {
            if shuffled[i] == alphabet[i] {
                hasSelfMap = true
                let j = (i + 1) % alphabet.count
                shuffled.swapAt(i, j)
            }
        }
        if !hasSelfMap { break }
        maxPasses -= 1
    }

    // Edge case: if still has self-map after passes, force-fix by swapping with a non-self-map neighbor
    for i in 0..<alphabet.count {
        if shuffled[i] == alphabet[i] {
            for j in 0..<alphabet.count where j != i {
                if shuffled[j] != alphabet[i] && shuffled[i] != alphabet[j] {
                    shuffled.swapAt(i, j)
                    break
                }
            }
        }
    }

    var mapping: [String: String] = [:]
    for (i, letter) in alphabet.enumerated() {
        mapping[String(letter)] = String(shuffled[i])
    }
    return mapping
}

/// Derives a deterministic UInt64 seed from a quote string and an ISO-8601 date string.
///
/// The seed is computed via FNV-1a over the UTF-8 bytes of "\(date)|\(uppercasedQuote)".
/// This ensures the same seed is produced regardless of host platform byte order.
func deriveSeed(quote: String, date: String) -> UInt64 {
    let input = "\(date)|\(quote.uppercased())"
    let bytes = Array(input.utf8)
    var hash: UInt64 = 14695981039346656037
    for byte in bytes {
        hash ^= UInt64(byte)
        hash = hash &* 1099511628211
    }
    return hash
}

/// Applies a cipher mapping to a plaintext string, substituting only A–Z letters.
/// Spaces, punctuation, digits, and non-ASCII characters are preserved unchanged.
/// Case is preserved: uppercase maps to uppercase; lowercase maps to lowercase.
func applyCipher(_ text: String, mapping: [String: String]) -> String {
    return String(text.unicodeScalars.map { scalar -> Character in
        let char = Character(scalar)
        let upper = String(char).uppercased()
        if let cipherUpper = mapping[upper] {
            // Preserve original case
            return char.isUppercase ? Character(cipherUpper) : Character(cipherUpper.lowercased())
        }
        return char
    })
}

/// Validates a cipher mapping for correctness.
/// Returns a list of validation error strings; empty array means valid.
func validateMapping(_ mapping: [String: String], plaintext: String) -> [String] {
    var errors: [String] = []

    // 1. All 26 letters must be present as keys
    let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) })
    let keys = Set(mapping.keys)
    let missingKeys = alphabet.subtracting(keys)
    if !missingKeys.isEmpty {
        errors.append("Missing plaintext keys: \(missingKeys.sorted().joined(separator: ", "))")
    }

    // 2. All 26 letters must appear exactly once as values (bijective)
    let values = Array(mapping.values)
    let valueSet = Set(values)
    if valueSet.count != 26 {
        errors.append("Mapping is not bijective: \(values.count) values, \(valueSet.count) unique")
    }
    let missingValues = alphabet.subtracting(valueSet)
    if !missingValues.isEmpty {
        errors.append("Missing ciphertext values: \(missingValues.sorted().joined(separator: ", "))")
    }

    // 3. No self-maps
    for (k, v) in mapping where k == v {
        errors.append("Self-map detected: \(k) → \(v)")
    }

    // 4. Minimum unique plaintext letters in quote (cipher must be non-trivial)
    let uniquePlaintextLetters = Set(plaintext.uppercased().filter { $0.isLetter })
    if uniquePlaintextLetters.count < 10 {
        errors.append("Quote has fewer than 10 unique letters (\(uniquePlaintextLetters.count)); cipher may be too short")
    }

    return errors
}

/// Computes the hint levels: level 1 reveals the 3 highest-frequency letters,
/// level 2 reveals 3 more (next highest frequency). Letters are returned in plaintext.
func computeHints(plaintext: String, maxHints: Int = 3) -> HintMetadata {
    var freq: [String: Int] = [:]
    for char in plaintext.uppercased() where char.isLetter {
        let key = String(char)
        freq[key, default: 0] += 1
    }
    let sorted = freq.sorted { $0.value > $1.value }.map { $0.key }
    let level1 = Array(sorted.prefix(3))
    let level2 = Array(sorted.dropFirst(3).prefix(3))
    return HintMetadata(level1RevealedLetters: level1, level2RevealedLetters: level2, maxHints: maxHints)
}

// ---------------------------------------------------------------------------
// MARK: - Manifest Assembly
// ---------------------------------------------------------------------------

func buildManifest(
    quoteId: String,
    plaintext: String,
    author: String,
    source: String?,
    scheduledDate: String,
    dayIndex: Int,
    difficulty: Difficulty,
    riskFlag: RiskFlag
) throws -> DailyPuzzleManifest {

    let seed = deriveSeed(quote: plaintext, date: scheduledDate)
    let mapping = generateCipherMapping(seed: seed)

    // Validate before proceeding
    let errors = validateMapping(mapping, plaintext: plaintext)
    if !errors.isEmpty {
        throw GeneratorError.validationFailed(errors)
    }

    let ciphertext = applyCipher(plaintext, mapping: mapping)

    let wordCount = plaintext.split(whereSeparator: { $0.isWhitespace }).count
    let totalChars = plaintext.count
    let hasSingleLetterWords = plaintext.split(whereSeparator: { $0.isWhitespace })
        .contains { $0.filter({ $0.isLetter }).count == 1 }
    let cipherLetterCount = Set(ciphertext.uppercased().filter { $0.isLetter }).count

    let hints = computeHints(plaintext: plaintext)

    let shareStats = ShareCardStats(
        dayIndex: dayIndex,
        cipherLetterCount: cipherLetterCount,
        totalCharCount: totalChars,
        difficultyTag: difficulty.rawValue,
        hasSingleLetterWords: hasSingleLetterWords
    )

    let puzzleId = "cipher-\(scheduledDate.replacingOccurrences(of: "-", with: ""))-\(quoteId)"

    let formatter = ISO8601DateFormatter()
    let generatedAt = formatter.string(from: Date())

    return DailyPuzzleManifest(
        puzzleId: puzzleId,
        scheduledDate: scheduledDate,
        dayIndex: dayIndex,
        quoteId: quoteId,
        quotePlaintext: plaintext,
        quoteAuthor: author,
        quoteSource: source,
        wordCount: wordCount,
        cipherMapping: mapping,
        quoteCiphertext: ciphertext,
        difficulty: difficulty.rawValue,
        hints: hints,
        shareCardStats: shareStats,
        riskFlag: riskFlag.rawValue,
        generatedAt: generatedAt,
        schemaVersion: 1
    )
}

// ---------------------------------------------------------------------------
// MARK: - Error Types
// ---------------------------------------------------------------------------

enum GeneratorError: LocalizedError {
    case validationFailed([String])
    case malformedQuote(String)
    case missingArgument(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .validationFailed(let errs):
            return "Cipher validation failed:\n" + errs.map { "  • \($0)" }.joined(separator: "\n")
        case .malformedQuote(let msg):
            return "Malformed quote: \(msg)"
        case .missingArgument(let arg):
            return "Missing required argument: --\(arg)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Batch input schema
// ---------------------------------------------------------------------------

struct BatchQuoteEntry: Codable {
    let quoteId: String
    let plaintext: String
    let author: String
    let source: String?
    let scheduledDate: String
    let dayIndex: Int
    let difficulty: String
    let riskFlag: String?
}

// ---------------------------------------------------------------------------
// MARK: - CLI Argument Parsing
// ---------------------------------------------------------------------------

struct CLI {
    var mode: Mode = .single
    var quote: String = ""
    var author: String = ""
    var source: String? = nil
    var quoteId: String = "manual"
    var date: String = ""
    var dayIndex: Int = 1
    var difficulty: Difficulty = .medium
    var riskFlag: RiskFlag = .none
    var batchFile: String = ""
    var outputDir: String = "."
    var verifyFile: String = ""

    enum Mode {
        case single, batch, verify, printSchema
    }
}

func parseArgs(_ args: [String]) throws -> CLI {
    var cli = CLI()
    var i = 1 // skip argv[0]
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--quote":
            i += 1; cli.quote = args[i]; cli.mode = .single
        case "--author":
            i += 1; cli.author = args[i]
        case "--source":
            i += 1; cli.source = args[i]
        case "--quote-id":
            i += 1; cli.quoteId = args[i]
        case "--date":
            i += 1; cli.date = args[i]
        case "--day-index":
            i += 1; cli.dayIndex = Int(args[i]) ?? 1
        case "--difficulty":
            i += 1
            if let d = Difficulty(rawValue: args[i].uppercased()) {
                cli.difficulty = d
            }
        case "--risk-flag":
            i += 1
            if let r = RiskFlag(rawValue: args[i]) {
                cli.riskFlag = r
            }
        case "--batch":
            i += 1; cli.batchFile = args[i]; cli.mode = .batch
        case "--output":
            i += 1; cli.outputDir = args[i]
        case "--verify":
            i += 1; cli.verifyFile = args[i]; cli.mode = .verify
        case "--schema":
            cli.mode = .printSchema
        default:
            break
        }
        i += 1
    }
    return cli
}

// ---------------------------------------------------------------------------
// MARK: - JSON output helpers
// ---------------------------------------------------------------------------

func prettyJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? "{}"
}

// ---------------------------------------------------------------------------
// MARK: - Verify mode
// ---------------------------------------------------------------------------

func verifyManifest(at path: String) throws {
    guard let data = FileManager.default.contents(atPath: path) else {
        throw GeneratorError.fileNotFound(path)
    }
    let manifest = try JSONDecoder().decode(DailyPuzzleManifest.self, from: data)

    var issues: [String] = []

    // 1. Validate mapping constraints
    issues += validateMapping(manifest.cipherMapping, plaintext: manifest.quotePlaintext)

    // 2. Verify ciphertext matches re-application of mapping
    let recomputed = applyCipher(manifest.quotePlaintext, mapping: manifest.cipherMapping)
    if recomputed != manifest.quoteCiphertext {
        issues.append("Ciphertext does not match re-application of mapping")
        issues.append("  Stored:     \(manifest.quoteCiphertext)")
        issues.append("  Recomputed: \(recomputed)")
    }

    // 3. Verify seed determinism
    let seed = deriveSeed(quote: manifest.quotePlaintext, date: manifest.scheduledDate)
    let recomputedMapping = generateCipherMapping(seed: seed)
    if recomputedMapping != manifest.cipherMapping {
        issues.append("Cipher mapping does not match deterministic re-generation from seed")
    }

    // 4. Check riskFlag is not ESC (ESC puzzles must not be in manifests)
    if manifest.riskFlag == RiskFlag.esc.rawValue {
        issues.append("FATAL: riskFlag is ESC — this puzzle must not be scheduled")
    }

    // 5. Word count sanity
    let actualWordCount = manifest.quotePlaintext.split(whereSeparator: { $0.isWhitespace }).count
    if actualWordCount != manifest.wordCount {
        issues.append("wordCount mismatch: stored \(manifest.wordCount), actual \(actualWordCount)")
    }

    if issues.isEmpty {
        print("✅ VALID: \(manifest.puzzleId)")
        print("   Quote:  \"\(manifest.quotePlaintext)\"")
        print("   Author: \(manifest.quoteAuthor)")
        print("   Date:   \(manifest.scheduledDate)  Difficulty: \(manifest.difficulty)  Risk: \(manifest.riskFlag)")
    } else {
        print("❌ INVALID: \(manifest.puzzleId)")
        for issue in issues {
            print("   \(issue)")
        }
        exit(1)
    }
}

// ---------------------------------------------------------------------------
// MARK: - Schema documentation
// ---------------------------------------------------------------------------

let schemaDoc = """
# DailyPuzzleManifest — JSON Schema v1
# Generated by cipher-generator.swift (ONE Games)

{
  "schemaVersion": 1,                    // Int — always 1 for this version
  "puzzleId": "cipher-20260601-E-01",    // String — unique ID; format: cipher-{YYYYMMDD}-{quoteId}
  "scheduledDate": "2026-06-01",         // String — ISO-8601 date (YYYY-MM-DD)
  "dayIndex": 1,                         // Int — 1-based day counter

  // Quote metadata
  "quoteId": "E-01",                     // String — ID from ONE-44 quote library
  "quotePlaintext": "The truth is...",   // String — NFC-normalized plaintext (KEEP SERVER-SIDE ONLY)
  "quoteAuthor": "Oscar Wilde",          // String — attribution string
  "quoteSource": "The Importance...",    // String? — optional source/work citation
  "wordCount": 10,                       // Int — word count of plaintext

  // Cipher mapping
  "cipherMapping": {                     // Object<String,String> — 26 entries, bijective, no self-maps
    "A": "Q", "B": "X", ...
  },
  "quoteCiphertext": "Rjw xdfjq ...",    // String — ciphertext (safe to expose to player/share-card)

  // Difficulty and hints
  "difficulty": "E",                     // String — "E" | "M" | "H"
  "hints": {
    "level1RevealedLetters": ["E","T","A"],  // Array<String> — plaintext letters revealed at hint 1
    "level2RevealedLetters": ["O","I","N"],  // Array<String> — plaintext letters revealed at hint 2
    "maxHints": 3                            // Int — maximum hints available
  },

  // Share-card safe stats — no plaintext leaks
  "shareCardStats": {
    "dayIndex": 1,                       // Int — opaque day counter
    "cipherLetterCount": 22,             // Int — distinct ciphertext letters used
    "totalCharCount": 44,                // Int — total characters including spaces/punctuation
    "difficultyTag": "E",               // String — "E" | "M" | "H"
    "hasSingleLetterWords": true        // Bool — true if any single-letter words exist (anchor clues)
  },

  // Editorial compliance
  "riskFlag": "None",                    // String — "None" | "ATT" | "SHORT" | (never "ESC")
  "generatedAt": "2026-05-22T14:00:00Z" // String — ISO-8601 generation timestamp
}

## Security / Privacy Notes
- quotePlaintext, quoteAuthor, quoteSource, cipherMapping, and hints MUST be stored
  server-side or in an encrypted local store. They MUST NOT appear in the share-card payload.
- shareCardStats is safe for share-card; it contains no recoverable plaintext.
- The ciphertext (quoteCiphertext) is safe to expose; it is meaningless without the mapping.

## Determinism
- The cipher mapping is deterministically derived from: scheduledDate + quotePlaintext (uppercased)
- Running the generator twice with the same inputs produces identical output.
- This enables server-side recomputation for integrity checks without storing the mapping.
"""

// ---------------------------------------------------------------------------
// MARK: - main()
// ---------------------------------------------------------------------------

func main() throws {
    let args = CommandLine.arguments
    let cli = try parseArgs(args)

    switch cli.mode {

    case .printSchema:
        print(schemaDoc)

    case .verify:
        if cli.verifyFile.isEmpty {
            throw GeneratorError.missingArgument("verify <path>")
        }
        try verifyManifest(at: cli.verifyFile)

    case .single:
        // Validate required args
        if cli.quote.isEmpty { throw GeneratorError.missingArgument("quote") }
        if cli.author.isEmpty { throw GeneratorError.missingArgument("author") }
        if cli.date.isEmpty { throw GeneratorError.missingArgument("date") }
        if cli.quote.count < 10 {
            throw GeneratorError.malformedQuote("Quote is too short (< 10 characters)")
        }

        let manifest = try buildManifest(
            quoteId: cli.quoteId,
            plaintext: cli.quote,
            author: cli.author,
            source: cli.source,
            scheduledDate: cli.date,
            dayIndex: cli.dayIndex,
            difficulty: cli.difficulty,
            riskFlag: cli.riskFlag
        )
        print(try prettyJSON(manifest))

    case .batch:
        if cli.batchFile.isEmpty { throw GeneratorError.missingArgument("batch <path>") }
        guard let data = FileManager.default.contents(atPath: cli.batchFile) else {
            throw GeneratorError.fileNotFound(cli.batchFile)
        }
        let entries = try JSONDecoder().decode([BatchQuoteEntry].self, from: data)
        let fm = FileManager.default
        if !fm.fileExists(atPath: cli.outputDir) {
            try fm.createDirectory(atPath: cli.outputDir, withIntermediateDirectories: true)
        }
        var successCount = 0
        var errorCount = 0
        for entry in entries {
            do {
                let difficulty = Difficulty(rawValue: entry.difficulty.uppercased()) ?? .medium
                let riskFlagStr = entry.riskFlag ?? "None"
                if riskFlagStr == RiskFlag.esc.rawValue {
                    fputs("SKIP \(entry.quoteId): riskFlag is ESC — not scheduled\n", stderr)
                    continue
                }
                let riskFlag = RiskFlag(rawValue: riskFlagStr) ?? .none
                let manifest = try buildManifest(
                    quoteId: entry.quoteId,
                    plaintext: entry.plaintext,
                    author: entry.author,
                    source: entry.source,
                    scheduledDate: entry.scheduledDate,
                    dayIndex: entry.dayIndex,
                    difficulty: difficulty,
                    riskFlag: riskFlag
                )
                let json = try prettyJSON(manifest)
                let filename = "\(cli.outputDir)/\(manifest.puzzleId).json"
                try json.write(toFile: filename, atomically: true, encoding: .utf8)
                print("✅ \(manifest.puzzleId) → \(filename)")
                successCount += 1
            } catch {
                fputs("❌ \(entry.quoteId): \(error.localizedDescription)\n", stderr)
                errorCount += 1
            }
        }
        print("\nBatch complete: \(successCount) generated, \(errorCount) errors")
    }
}

do {
    try main()
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
