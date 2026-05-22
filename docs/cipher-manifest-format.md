# OnePuzzle — Daily Cipher Manifest Format

**Version:** 1.0  
**Author:** Swifty (ONE iOS Engineer) — [ONE-45](/ONE/issues/ONE-45)  
**Date:** 2026-05-22  
**Mechanic source:** [ONE-21 mechanic-recommendation](/ONE/issues/ONE-21#document-mechanic-recommendation)  
**Quote library:** [ONE-44 quote-library-v1](/ONE/issues/ONE-44#document-quote-library-v1)

---

## Overview

The daily cipher manifest is a JSON document produced by `scripts/cipher-generator.py`
and consumed by the iOS app (`DailyPuzzleService`).  It encodes one or more daily
Cipher Quote puzzles, each fully specified by its ciphertext, cipher mapping, and
associated metadata.

Two manifest variants exist:

| Variant | Contents | Intended consumer |
|---|---|---|
| **Full** | All fields including `_internal` (plaintext, author) and full `cipherMap` | CI / test / editorial review |
| **CDN-safe** | All fields except `_internal` and `cipherMap` (stripped via `--strip-internal`) | iOS app via static CDN |

The iOS app reconstructs the cipher map from `seed` at runtime using the same
deterministic algorithm as the generator, so `cipherMap` does not need to be
shipped over the network.

---

## Top-Level Schema

```json
{
  "schemaVersion": "1.0",
  "generatedAt": "2026-05-22",
  "epochDate": "2026-01-01",
  "entries": [ ... ]
}
```

| Field | Type | Description |
|---|---|---|
| `schemaVersion` | `string` | Semver of this schema.  Current: `"1.0"`. |
| `generatedAt` | `string` (ISO 8601 date) | Date the manifest was generated. |
| `epochDate` | `string` (ISO 8601 date) | Day 1 of the OnePuzzle calendar (`2026-01-01`). |
| `entries` | `Array<PuzzleEntry>` | Ordered list of daily puzzle entries, one per calendar day. |

---

## PuzzleEntry Schema

Each object in `entries` represents one day's puzzle.

### Identity fields

| Field | Type | Required | Description |
|---|---|---|---|
| `puzzleNumber` | `integer` | ✅ | 1-based day index from `epochDate`.  Day 1 = 2026-01-01. |
| `date` | `string` (ISO 8601 date) | ✅ | Calendar date this puzzle is scheduled for.  e.g. `"2026-05-22"`. |
| `quoteId` | `string` | ✅ | Quote library identifier.  e.g. `"E-01"`.  Tier prefix: `E`=Easy, `M`=Medium, `H`=Hard. |
| `seed` | `integer` (uint64) | ✅ | Deterministic seed for cipher generation.  Derived from `SHA-256(quoteId + ":" + date)`.  The iOS app recomputes the cipher map from this seed — it does NOT need `cipherMap` at runtime. |

### Cipher content fields

| Field | Type | Required | Description |
|---|---|---|---|
| `ciphertext` | `string` | ✅ | The encrypted quote.  Spaces, punctuation, and case structure preserved.  No plaintext characters visible. |
| `cipherMap` | `object` | Full only | `{ "A": "M", "B": "X", ... }` — maps each uppercase cipher letter to its uppercase plaintext letter.  26 entries.  Omitted in CDN-safe manifests. |
| `hintSequence` | `Array<string>` | ✅ | Ordered list of plaintext uppercase letters, rarest-first.  Each element is the letter the app should reveal for Hint 1, Hint 2, etc.  Length equals `distinctLetterCount`. |

### Quote metadata fields (share-card safe)

These fields describe the puzzle without leaking the plaintext or author name.

| Field | Type | Required | Description |
|---|---|---|---|
| `authorInitials` | `string` | ✅ | Author initials in `"F.L.N."` format.  `"Trad."` for Traditional/Proverb/Anonymous.  Safe to display on share card. |
| `difficulty` | `string` | ✅ | `"E"` (Easy), `"M"` (Medium), or `"H"` (Hard).  Maps to the NYT-style Mon–Sat difficulty curve. |
| `wordCount` | `integer` | ✅ | Number of words in the plaintext quote. |
| `charCount` | `integer` | ✅ | Total character count (including spaces and punctuation) of the plaintext. |
| `distinctLetterCount` | `integer` | ✅ | Number of distinct uppercase letters in the plaintext.  Range: 8–26.  The player must crack this many cipher-letter assignments to solve the puzzle. |

### Share-card fields

| Field | Type | Required | Description |
|---|---|---|---|
| `shareGridSolved` | `Array<string>` | ✅ | 26-element array, one per alphabet position A–Z.  Each element is `"solved"` or `"absent"`.  Represents the *theoretical* fully-solved share grid.  The iOS app replaces `"solved"` elements with `"hint"` for any letter revealed via hint, and tracks the solve order for animation.  This field is the baseline; the app computes the actual player-specific grid at runtime. |

### Internal fields (full manifest only, strip before CDN)

| Field | Type | Required | Description |
|---|---|---|---|
| `_internal` | `object` | Full only | Editorial metadata.  **Must be stripped before publishing to CDN.** |
| `_internal.plaintext` | `string` | Full only | The original plaintext quote.  e.g. `"The truth is rarely pure and never simple."` |
| `_internal.author` | `string` | Full only | Full author attribution.  e.g. `"Oscar Wilde"` |
| `_internal.source` | `string` | Full only | Source work and year.  e.g. `"The Importance of Being Earnest (1895)"` |
| `_internal.riskFlag` | `string` | Full only | IP risk flag from ONE-44 editorial policy: `"None"`, `"[ATT]"`, `"[SHORT]"`, or `"[ESC]"`. |

---

## Complete Example — Full Manifest (single entry)

```json
{
  "schemaVersion": "1.0",
  "generatedAt": "2026-05-22",
  "epochDate": "2026-01-01",
  "entries": [
    {
      "puzzleNumber": 142,
      "date": "2026-05-22",
      "quoteId": "E-01",
      "seed": 9120327520051608500,
      "ciphertext": "Ger gxtge wm xjxrfo atxr jpi prsrx mwqafr.",
      "cipherMap": {
        "A": "U", "B": "X", "C": "D", "D": "C", "E": "A",
        "F": "V", "G": "T", "H": "N", "I": "R", "J": "N",
        "K": "P", "L": "Z", "M": "S", "N": "I", "O": "F",
        "P": "H", "Q": "B", "R": "K", "S": "E", "T": "Y",
        "U": "L", "V": "J", "W": "Q", "X": "O", "Y": "G",
        "Z": "W"
      },
      "hintSequence": ["W", "U", "R", "L", "D", "P", "Y", "N", "H", "A", "I", "T", "S", "E"],
      "authorInitials": "O.W.",
      "difficulty": "E",
      "wordCount": 8,
      "charCount": 42,
      "distinctLetterCount": 15,
      "shareGridSolved": [
        "absent", "absent", "absent", "absent", "solved",
        "absent", "absent", "solved", "solved", "absent",
        "absent", "solved", "absent", "solved", "absent",
        "solved", "absent", "solved", "solved", "solved",
        "solved", "absent", "absent", "absent", "solved",
        "absent"
      ],
      "_internal": {
        "plaintext": "The truth is rarely pure and never simple.",
        "author": "Oscar Wilde",
        "source": "The Importance of Being Earnest (1895)",
        "riskFlag": "None"
      }
    }
  ]
}
```

---

## CDN-Safe Example (stripped)

```json
{
  "schemaVersion": "1.0",
  "generatedAt": "2026-05-22",
  "epochDate": "2026-01-01",
  "entries": [
    {
      "puzzleNumber": 142,
      "date": "2026-05-22",
      "quoteId": "E-01",
      "seed": 9120327520051608500,
      "ciphertext": "Ger gxtge wm xjxrfo atxr jpi prsrx mwqafr.",
      "hintSequence": ["W", "U", "R", "L", "D", "P", "Y", "N", "H", "A", "I", "T", "S", "E"],
      "authorInitials": "O.W.",
      "difficulty": "E",
      "wordCount": 8,
      "charCount": 42,
      "distinctLetterCount": 15,
      "shareGridSolved": [
        "absent", "absent", "absent", "absent", "solved",
        "absent", "absent", "solved", "solved", "absent",
        "absent", "solved", "absent", "solved", "absent",
        "solved", "absent", "solved", "solved", "solved",
        "solved", "absent", "absent", "absent", "solved",
        "absent"
      ]
    }
  ]
}
```

---

## Cipher Generation Algorithm

The iOS app reconstructs the cipher map from `seed` using the following algorithm.
This must match `scripts/cipher-generator.py::generate_cipher_mapping` exactly.

### Swift pseudocode

```swift
/// Reconstruct the cipher map from (quoteId, date).
/// Returns [cipherLetter: plaintextLetter] for all 26 uppercase letters.
func generateCipherMapping(quoteId: String, date: String) -> [Character: Character] {
    let raw = "\(quoteId):\(date)"
    let seed = sha256FirstUInt64(raw)          // First 8 bytes of SHA-256, big-endian
    var alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    var perm = alphabet
    seededShuffle(&perm, seed: seed)           // Fisher-Yates with LCG from seed
    removeFixedPoints(&perm, alphabet: alphabet, seed: seed)
    var result: [Character: Character] = [:]
    for i in 0..<26 {
        result[alphabet[i]] = perm[i]          // cipher[i] -> plaintext[i]
    }
    return result
}
```

### Derangement (fixed-point removal)

After the initial shuffle, any position `i` where `perm[i] == alphabet[i]` is a
fixed point.  Remove all fixed points by swapping each with a non-self, non-conflict
neighbour, using the seeded RNG for swap target selection.

The Python reference implementation in `scripts/cipher-generator.py::generate_cipher_mapping`
is the authoritative definition.  The Swift implementation in `CipherPuzzleService.swift`
must produce identical output for all inputs.

### Seed derivation

```
seed = SHA-256(quoteId + ":" + dateISO8601)[0:8], interpreted as big-endian UInt64
```

e.g. for `quoteId="E-01"` and `date="2026-05-22"`:

```
SHA-256("E-01:2026-05-22") -> first 8 bytes -> UInt64 seed
```

---

## Validation Rules

The generator enforces these constraints before emitting a manifest entry:

| Rule | Check |
|---|---|
| No fixed points | `∀i: cipherLetter[i] ≠ plaintextLetter[i]` |
| Bijection | All 26 plaintext letters appear exactly once in the mapping |
| Minimum distinct letters | `distinctLetterCount ≥ 8` |
| No non-ASCII letters | Plaintext contains only ASCII alphabetic characters |
| Risk flag | `riskFlag` must not start with `[ESC]` |
| Quote length | `4 ≤ wordCount ≤ 30` |

---

## Difficulty → Day-of-Week Schedule

| Day | Target Difficulty | Quote word count | Notes |
|---|---|---|---|
| Monday | E (Easy) | 8–10 words | Common vocab; at least one single-letter word preferred |
| Tuesday | E (Easy) | 8–10 words | |
| Wednesday | E (Easy) | 8–10 words | |
| Thursday | M (Medium) | 11–14 words | |
| Friday | M (Medium) | 11–14 words | |
| Saturday | H (Hard) | 14–18 words | Dense vocab; no single-letter anchor |
| Sunday | M (Medium) | 12 words | Themed / author-spotlight |

---

## Hint System

`hintSequence` is a pre-computed list of plaintext letters ordered by how
helpful revealing them would be, from most helpful (rarest cipher letter)
to least helpful (most frequent).

Hint tiers (iOS implementation):

| Tier | Action | Cost |
|---|---|---|
| Hint 1 | Reveal `hintSequence[0]` — the rarest-frequency cipher letter | Rewarded video (free tier) or free (Plus) |
| Hint 2 | Player taps any unsolved cipher letter to reveal it | Same as Hint 1 |
| Hint 3 (Give Up) | Reveal full mapping; game ends; share card records partial state | No hint cost; streak breaks |

The share card shows hint usage as `"solved"` vs `"hint"` cells in the alphabet grid.

---

## Quote Library Integration

The `quoteId` field references entries in the ONE-44 quote library.  Fields
that the generator reads from each library entry:

| Library field | Generator use |
|---|---|
| `id` | `quoteId` in manifest |
| `plaintext` | Source text for encryption |
| `author` | Initials computation (`authorInitials`) and same-author gap scheduling |
| `difficulty` | Bucket assignment for day-of-week scheduling |
| `risk_flag` | Escalation guard: `[ESC]` entries are never scheduled |

The library file (`quotes.json`) must be a JSON array of objects with these fields,
or a single object `{ "quotes": [...] }`.

---

## Generator Invocation

```bash
# Single-day puzzle (stdout):
python3 scripts/cipher-generator.py --quotes scripts/quotes.json --date 2026-05-22

# 90-day forward manifest (file):
python3 scripts/cipher-generator.py \
  --quotes scripts/quotes.json \
  --start 2026-05-22 --days 90 \
  --output manifests/manifest-2026-q3.json

# CDN-safe (strip plaintext / author / full map):
python3 scripts/cipher-generator.py \
  --quotes scripts/quotes.json \
  --start 2026-05-22 --days 7 \
  --strip-internal \
  --output manifests/week-2026-05-22.json

# Validate all quotes in library:
python3 scripts/cipher-generator.py --quotes scripts/quotes.json --validate

# Test a specific quote ID:
python3 scripts/cipher-generator.py --quotes scripts/quotes.json --quote-id E-01 --date 2026-05-22
```

---

## iOS Integration Notes

### `DailyPuzzleService` changes (M0 sprint)

Replace the current Wordle-style `PuzzleGenerator` with a `CipherPuzzleService` that:

1. Fetches `manifests/week-YYYY-MM-DD.json` from the CDN (or falls back to a
   bundled 7-day manifest for offline play).
2. Finds the entry where `date` matches today's ISO date string.
3. Reconstructs the `cipherMap` from `seed` using the Swift port of
   `generate_cipher_mapping`.
4. Presents `ciphertext`, `wordCount`, `difficulty`, and `authorInitials` to
   the board view.  **Never exposes `_internal.plaintext` to the view layer.**
5. Checks the player's assignments against the reconstructed cipher map to
   validate each letter guess.
6. At solve/give-up, builds the share-card grid from `shareGridSolved`,
   replacing cells with `"hint"` for any hint-revealed letters.

### Persistence (`SwiftData`)

Store per-day play state:

```swift
@Model class DailyPlay {
    var date: String          // ISO 8601
    var quoteId: String
    var puzzleNumber: Int
    var assignments: [String: String]  // cipher letter -> player's guess
    var hintsUsed: [String]            // plaintext letters revealed by hint
    var solvedAt: Date?
    var gaveUpAt: Date?
    var elapsedSeconds: Int
}
```

### Offline / bundled manifest

Bundle a 7-day manifest in `OnePuzzle/Resources/manifests/` as a JSON asset.
The app tries the network first (with a 3-second timeout), then falls back to
the bundle asset.  This ensures Day 1 play works without any network access.

---

## Dependencies on ONE-44

The following ONE-44 quote-library fields are required by the generator:

| ONE-44 field | Generator field | Notes |
|---|---|---|
| `id` | `quoteId` | Must be unique within the library |
| `plaintext` | Source text | ASCII Latin only; 8–18 words preferred |
| `author` | `authorInitials`, same-author gap | Full name used for scheduling; initials shipped |
| `difficulty` | Day-of-week bucket | `E`, `M`, or `H` |
| `risk_flag` | Escalation guard | `[ESC]` entries excluded |

Optional ONE-44 fields (not currently used by generator):

| ONE-44 field | Future use |
|---|---|
| `source` | May be shown in post-solve reveal screen |
| `pd` (public-domain rationale) | Compliance audit trail |

---

*End of spec.  For generator source, see `scripts/cipher-generator.py`.  
For quote library, see [ONE-44 quote-library-v1](/ONE/issues/ONE-44#document-quote-library-v1).*
