# ONE Games — Scripts

This directory contains tooling for ONE Games' daily Cipher Quote puzzle pipeline.

## Files

| File | Purpose |
|---|---|
| `cipher-generator.swift` | Swift CLI generator (primary — runs on macOS/Linux with `swift`) |
| `cipher-generator.py` | Python 3.9+ generator (cross-platform reference implementation) |
| `test-cipher-generator.py` | Python test harness that verifies cipher correctness |
| `sample-quotes.json` | Sample batch input with 6 quotes from ONE-44 |
| `quotes.json` | Full 90-quote library from ONE-44 (not committed; see ONE-44 for content) |

For the full manifest schema, see `docs/cipher-manifest-format.md`.

---

## cipher-generator.swift (primary)

Swift 5.9+ command-line script that generates `DailyPuzzleManifest` JSON.
No external dependencies; runs with `swift`.

### Usage

**Single puzzle:**
```bash
swift scripts/cipher-generator.swift \
  --quote "The truth is rarely pure and never simple." \
  --author "Oscar Wilde" \
  --source "The Importance of Being Earnest (1895)" \
  --quote-id E-01 \
  --date 2026-06-02 \
  --day-index 1 \
  --difficulty E \
  --risk-flag None
```

**Batch generation from JSON input:**
```bash
swift scripts/cipher-generator.swift \
  --batch scripts/sample-quotes.json \
  --output manifests/
```

**Verify an existing manifest:**
```bash
swift scripts/cipher-generator.swift --verify manifests/cipher-20260602-E-01.json
```

**Print JSON schema documentation:**
```bash
swift scripts/cipher-generator.swift --schema
```

### Algorithm (Swift)

1. **Seed derivation:** FNV-1a hash over `{scheduledDate}|{PLAINTEXT_UPPERCASE}` → `UInt64`.
2. **Shuffle:** Fisher-Yates with a linear-congruential PRNG (Knuth MMIX constants).
3. **Self-map resolution:** Any letter that maps to itself is swapped with its cyclic neighbor.
4. **Validation:** bijective (26→26), no self-maps, ≥10 unique letters in quote.
5. **Determinism:** same inputs → same mapping every time.

---

## cipher-generator.py (Python reference)

Python 3.9+ generator (stdlib only) that reads a quote library JSON and produces
a multi-day manifest with scheduling (difficulty curve, 14-day same-author gap).

```bash
# Single-day puzzle to stdout:
python3 scripts/cipher-generator.py --date 2026-05-22

# Generate next 7 days (writes to file):
python3 scripts/cipher-generator.py \
  --quotes scripts/quotes.json \
  --start 2026-05-22 --days 7 \
  --output manifests/week-2026-05-22.json

# CDN-safe (strip plaintext/author from output):
python3 scripts/cipher-generator.py \
  --quotes scripts/quotes.json \
  --start 2026-05-22 --days 7 \
  --strip-internal

# Validate all quotes in library:
python3 scripts/cipher-generator.py --quotes scripts/quotes.json --validate

# Test a specific quote ID:
python3 scripts/cipher-generator.py --quote-id E-01 --date 2026-05-22
```

### Algorithm (Python)

1. **Seed derivation:** SHA-256(`{quoteId}:{date}`) → first 8 bytes as big-endian UInt64.
2. **Shuffle:** `random.shuffle` seeded from above (Fisher-Yates).
3. **Fixed-point removal:** Iterative swap until no position maps to itself.
4. **Validation:** bijective, no fixed points, ≥8 distinct letters, no `[ESC]` flags.

> **Note:** The Python and Swift generators use different seed algorithms (SHA-256 vs FNV-1a).
> They produce different cipher mappings for the same input.  The iOS app must use the
> same algorithm as whichever generator produces the manifest being consumed.  Pick one
> for production and document the choice in `docs/cipher-manifest-format.md`.

---

## test-cipher-generator.py

Cross-platform Python test that mirrors the Swift algorithm and verifies correctness:

```bash
python3 scripts/test-cipher-generator.py
```

Tests: bijective mapping, no self-maps, determinism, invertibility, share-card safety.

---

## sample-quotes.json / quotes.json format

```json
[
  {
    "id": "E-01",
    "plaintext": "The truth is rarely pure and never simple.",
    "author": "Oscar Wilde",
    "source": "The Importance of Being Earnest (1895)",
    "difficulty": "E",
    "risk_flag": "None"
  }
]
```

The 90 canonical quotes are in ONE-44 (document: `quote-library-v1`).
Export them to `scripts/quotes.json` before running the Python generator in production.

---

## Manifest schema summary

| Field | Safe to expose | Notes |
|---|---|---|
| `ciphertext` / `quoteCiphertext` | ✅ Player sees this | Encrypted text only |
| `shareGridSolved` / `shareCardStats` | ✅ Share-card safe | No plaintext leakable |
| `_internal.plaintext` / `quotePlaintext` | ❌ Server-only | Never send to client |
| `cipherMap` / `cipherMapping` | ❌ Server-only | Reconstructed from seed on device |
| `hintSequence` / `hints` | ⚠️ Hint-gate only | Send only when player earns hint |
| `authorInitials` / `quoteAuthor` | ⚠️ Post-solve | Reveal after puzzle complete |

For the full schema, see `docs/cipher-manifest-format.md`.
