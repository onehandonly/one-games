# ONE Games — Scripts

This directory contains tooling for ONE Games' daily puzzle content pipeline.

## cipher-generator.swift

Swift command-line script that generates **daily cipher puzzle manifests** conforming to the `DailyPuzzleManifest` JSON schema (v1). Intended to be run server-side or by a CI job to produce one manifest JSON file per scheduled puzzle day.

### Requirements

- Swift 5.9+ (`swift` CLI available)
- No external dependencies

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

### Manifest schema

See `--schema` output or the `DailyPuzzleManifest` struct in `cipher-generator.swift`. Key fields:

| Field | Safe to expose | Notes |
|-------|----------------|-------|
| `quoteCiphertext` | ✅ Player sees this | Encrypted text |
| `shareCardStats` | ✅ Share-card safe | No plaintext leakable |
| `quotePlaintext` | ❌ Server-only | Never send to client |
| `cipherMapping` | ❌ Server-only | Never send to client |
| `hints` | ⚠️ Hint-gate only | Send only when player earns hint |
| `quoteAuthor` | ⚠️ Post-solve only | Reveal after puzzle complete |

### Algorithm

1. **Seed derivation:** FNV-1a hash over `{scheduledDate}|{PLAINTEXT_UPPERCASE}` → `UInt64`.
2. **Shuffle:** Fisher-Yates with a linear-congruential PRNG (Knuth MMIX constants) seeded from above.
3. **Self-map resolution:** Any letter that maps to itself is swapped with its cyclic neighbor.
4. **Validation:** bijective (26→26), no self-maps, ≥10 unique letters in quote.
5. **Determinism:** same inputs → same mapping every time. Server can recompute without storing the mapping.

### test-cipher-generator.py

Cross-platform Python test that mirrors the Swift algorithm and verifies correctness on any platform:

```bash
python3 scripts/test-cipher-generator.py
```

Tests: bijective mapping, no self-maps, determinism, invertibility, share-card safety.

### sample-quotes.json

A sample batch input file with 6 quotes from the ONE-44 quote library. Use this as a template for the production schedule.
