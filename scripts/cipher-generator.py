#!/usr/bin/env python3
"""
cipher-generator.py
===================
Cipher Quote puzzle generator for OnePuzzle (ONE iOS game).

Reads a JSON quote library and produces a daily puzzle manifest suitable
for consumption by the iOS app (DailyPuzzleService) and the static CDN
publishing pipeline.

Mechanic: monoalphabetic substitution cipher over a short plaintext quote.
Constraints (from ONE-21 mechanic-recommendation §6):
  - No letter maps to itself (no fixed points).
  - Mapping is bijective (no two cipher letters map to the same plaintext letter).
  - Spaces, punctuation, and case structure are preserved in the cipher text.
  - Cipher text must not leak the author or plaintext in any way.
  - Generation is deterministic from (quote_id, seed).
  - Offensive-content safeguards via an allowlist/denylist pass.

Usage
-----
  # Generate today's puzzle:
  python3 cipher-generator.py --quotes quotes.json --date 2026-05-22

  # Generate a specific puzzle by quote ID:
  python3 cipher-generator.py --quotes quotes.json --quote-id E-01

  # Generate a 90-day forward manifest:
  python3 cipher-generator.py --quotes quotes.json --start 2026-05-22 --days 90 --output manifest.json

  # Validate all quotes in the library (offline QA pass):
  python3 cipher-generator.py --quotes quotes.json --validate

Output format: see docs/cipher-manifest-format.md for the full schema.

Dependencies: Python 3.9+ standard library only (hashlib, json, argparse, datetime).

Author: Swifty (ONE iOS Engineer) — ONE-45
"""

import argparse
import hashlib
import json
import random
import re
import sys
from datetime import date, timedelta
from typing import Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PUZZLE_EPOCH = date(2026, 1, 1)   # Day 1 of the OnePuzzle calendar
ALPHABET = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

# Minimum distinct letter count in plaintext for a valid cipher puzzle.
# A quote with < MIN_DISTINCT_LETTERS gives the player too little to work with.
MIN_DISTINCT_LETTERS = 8

# Maximum distinct letter count in a "short" puzzle (used for difficulty check).
# Quotes with >= FULL_ALPHABET_THRESHOLD unique letters are richest to solve.
FULL_ALPHABET_THRESHOLD = 18


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

def puzzle_number(d: date) -> int:
    """Return 1-based puzzle number from the epoch date."""
    return (d - PUZZLE_EPOCH).days + 1


def deterministic_seed(quote_id: str, d: date) -> int:
    """
    Produce a stable integer seed from (quote_id, date).
    Using SHA-256 ensures the seed is stable across platforms and Python versions.
    """
    raw = f"{quote_id}:{d.isoformat()}"
    digest = hashlib.sha256(raw.encode("utf-8")).digest()
    # Use the first 8 bytes as an unsigned 64-bit integer.
    return int.from_bytes(digest[:8], "big")


def extract_plaintext_letters(plaintext: str) -> list[str]:
    """Return the distinct uppercase letters present in the plaintext."""
    seen: set[str] = set()
    result: list[str] = []
    for ch in plaintext.upper():
        if ch.isalpha() and ch not in seen:
            seen.add(ch)
            result.append(ch)
    return result


def generate_cipher_mapping(plaintext: str, seed: int) -> dict[str, str]:
    """
    Generate a bijective, fixed-point-free monoalphabetic cipher mapping.

    Returns a dict {cipher_letter -> plaintext_letter} for all 26 uppercase
    letters.  Unused letters (not in the plaintext) are still mapped — this
    ensures the full mapping can be displayed in UI if desired.

    Algorithm:
      1. Create a random permutation of ALPHABET using the provided seed.
      2. If any position is a fixed point (permutation[i] == ALPHABET[i]),
         swap it with a neighbour until no fixed points remain.
      3. The result is a derangement of the alphabet.
      4. The mapping is: cipher_letter[i] = ALPHABET[i],
                         plaintext_letter[i] = permutation[i].
         i.e., in the ciphertext, ALPHABET[i] *represents* permutation[i].
         Equivalently: to encrypt plaintext letter permutation[i], output
         cipher letter ALPHABET[i].

    Raises ValueError if a derangement cannot be produced (should never happen
    for len >= 2).
    """
    rng = random.Random(seed)
    permutation = ALPHABET[:]
    rng.shuffle(permutation)

    # Remove fixed points by swapping with the next (wrapping) non-fixed-point
    # element.  Repeat until clean.  Worst case: O(n) passes.
    max_passes = 100
    for _ in range(max_passes):
        fixed = [i for i, (a, b) in enumerate(zip(ALPHABET, permutation)) if a == b]
        if not fixed:
            break
        for i in fixed:
            # Swap with a random non-self element.
            candidates = [j for j in range(26) if j != i and permutation[j] != ALPHABET[i]]
            if not candidates:
                raise ValueError("Cannot produce a derangement — alphabet too small.")
            j = rng.choice(candidates)
            permutation[i], permutation[j] = permutation[j], permutation[i]
    else:
        raise ValueError("Failed to produce a derangement after max passes.")

    # Verify bijectivity (permutation is already a permutation of ALPHABET, so
    # bijectivity is guaranteed, but be explicit for maintainability).
    assert sorted(permutation) == sorted(ALPHABET), "Mapping is not bijective."
    assert all(a != b for a, b in zip(ALPHABET, permutation)), "Mapping has fixed points."

    # Build the mapping: cipher_letter -> plaintext_letter
    # ALPHABET[i] (cipher) -> permutation[i] (plaintext)
    return {ALPHABET[i]: permutation[i] for i in range(26)}


def encrypt_quote(plaintext: str, cipher_map: dict[str, str]) -> str:
    """
    Encrypt the plaintext quote using the cipher mapping.

    cipher_map is {cipher_letter -> plaintext_letter}, so to encrypt we need
    the inverse: {plaintext_letter -> cipher_letter}.

    Preserves spaces, punctuation, and case structure:
      - Uppercase plaintext letters -> uppercase cipher letters.
      - Lowercase plaintext letters -> lowercase cipher letters.
      - Non-alpha characters are passed through unchanged.
    """
    # Build the inverse map: plaintext_letter -> cipher_letter
    encrypt_map = {v: k for k, v in cipher_map.items()}

    result = []
    for ch in plaintext:
        if ch.isalpha():
            upper = ch.upper()
            cipher_upper = encrypt_map.get(upper, upper)
            result.append(cipher_upper if ch.isupper() else cipher_upper.lower())
        else:
            result.append(ch)
    return "".join(result)


def compute_hint_sequence(plaintext: str, cipher_map: dict[str, str]) -> list[str]:
    """
    Compute the recommended hint reveal order for this puzzle.

    Strategy: order the plaintext letters by ascending frequency in the
    ciphertext.  The rarest cipher letter is the hardest to crack by
    letter-frequency analysis, so revealing it first gives the most help.

    Returns a list of plaintext letters in hint-reveal order (most helpful
    first, i.e., rarest cipher frequency first).
    """
    # Count cipher-letter frequencies in the ciphertext (letters only).
    cipher_text = encrypt_quote(plaintext, cipher_map)
    freq: dict[str, int] = {}
    for ch in cipher_text.upper():
        if ch.isalpha():
            freq[ch] = freq.get(ch, 0) + 1

    # For each plaintext letter, look up its cipher counterpart's frequency.
    # inverse: plaintext -> cipher
    inverse = {v: k for k, v in cipher_map.items()}

    present_letters = extract_plaintext_letters(plaintext)
    # Sort by ascending cipher frequency (rarest first).
    present_letters.sort(key=lambda pt: freq.get(inverse.get(pt, ""), 0))
    return present_letters


def compute_share_grid(plaintext: str, cipher_map: dict[str, str]) -> list[str]:
    """
    Compute the share-card alphabet grid.

    The share grid is a 26-element list, one per alphabet position (A–Z),
    value "solved" | "hint" | "absent" for a completed puzzle.  In the
    generator context, we produce a *solved* grid (all present letters solved,
    absent letters absent).  The iOS app will track hint usage and produce the
    actual per-solve grid at runtime.

    Returns list of 26 strings, each "solved" or "absent".
    """
    present = set(extract_plaintext_letters(plaintext))
    return ["solved" if letter in present else "absent" for letter in ALPHABET]


def validate_quote(q: dict) -> list[str]:
    """
    Run validation checks on a quote dict.

    Returns a list of error strings.  Empty list = valid.
    """
    errors: list[str] = []
    required_fields = ["id", "plaintext", "author", "source", "difficulty", "risk_flag"]
    for f in required_fields:
        if f not in q:
            errors.append(f"Missing required field: {f}")

    if "plaintext" not in q:
        return errors  # Can't continue without plaintext.

    text = q["plaintext"]

    # Length checks.
    word_count = len(text.split())
    if word_count < 4:
        errors.append(f"Too short ({word_count} words); minimum 4 words for a valid cipher.")
    if word_count > 30:
        errors.append(f"Too long ({word_count} words); maximum 30 words to fit on screen.")

    # Distinct letter count.
    distinct = len(extract_plaintext_letters(text))
    if distinct < MIN_DISTINCT_LETTERS:
        errors.append(
            f"Only {distinct} distinct letters; minimum {MIN_DISTINCT_LETTERS} for a solvable cipher."
        )

    # Risk-flag check: escalated quotes must not be scheduled.
    if q.get("risk_flag", "").startswith("[ESC]"):
        errors.append("Quote is escalated ([ESC]); do not schedule without CEO IP clearance.")

    # Duplicate letter check (bijection holds by construction, but verify plaintext has no
    # two identical letters occupying conflicting positions — this is not actually a concern
    # for monoalphabetic ciphers, but we flag if plaintext has non-Latin characters).
    non_latin = [ch for ch in text if ch.isalpha() and not ch.isascii()]
    if non_latin:
        errors.append(f"Non-Latin characters in plaintext: {non_latin}; cipher is ASCII-only.")

    return errors


# ---------------------------------------------------------------------------
# Puzzle manifest entry
# ---------------------------------------------------------------------------

def build_puzzle_entry(quote: dict, d: date) -> dict:
    """
    Build a single puzzle manifest entry for the given quote and date.

    Returns a dict matching the DailyPuzzleManifestEntry schema defined in
    docs/cipher-manifest-format.md.
    """
    quote_id = quote["id"]
    plaintext = quote["plaintext"]
    seed = deterministic_seed(quote_id, d)

    cipher_map = generate_cipher_mapping(plaintext, seed)
    ciphertext = encrypt_quote(plaintext, cipher_map)
    hint_sequence = compute_hint_sequence(plaintext, cipher_map)
    share_grid_solved = compute_share_grid(plaintext, cipher_map)

    distinct_letters = extract_plaintext_letters(plaintext)
    word_count = len(plaintext.split())
    char_count = len(plaintext)

    # Cipher map as a JSON-safe dict: {cipher_letter: plaintext_letter}
    # Sorted for deterministic serialization.
    cipher_map_sorted = {k: cipher_map[k] for k in sorted(cipher_map.keys())}

    entry = {
        # ---- Puzzle identity ----
        "puzzleNumber": puzzle_number(d),
        "date": d.isoformat(),
        "quoteId": quote_id,
        "seed": seed,

        # ---- Cipher content ----
        "ciphertext": ciphertext,
        "cipherMap": cipher_map_sorted,  # cipher_letter -> plaintext_letter
        "hintSequence": hint_sequence,   # Ordered list of plaintext letters (rarest-first)

        # ---- Quote metadata (safe to embed; does NOT include plaintext) ----
        "authorInitials": _initials(quote.get("author", "")),
        "difficulty": quote.get("difficulty", "M"),
        "wordCount": word_count,
        "charCount": char_count,
        "distinctLetterCount": len(distinct_letters),

        # ---- Share-card stats (no plaintext leakage) ----
        "shareGridSolved": share_grid_solved,

        # ---- Internal / editorial metadata (strip before CDN publish) ----
        "_internal": {
            "plaintext": plaintext,
            "author": quote.get("author", ""),
            "source": quote.get("source", ""),
            "riskFlag": quote.get("risk_flag", "None"),
        },
    }
    return entry


def _initials(author_name: str) -> str:
    """
    Return author initials (first letter of each word, uppercase).
    Used in share-card author attribution without leaking the full name.

    e.g. "Oscar Wilde" -> "O.W."
         "Benjamin Franklin" -> "B.F."
         "Traditional" -> "Trad."
    """
    if not author_name or author_name.lower() in ("traditional", "proverb", "anonymous"):
        return "Trad."
    parts = author_name.split()
    return ".".join(p[0].upper() for p in parts if p) + "."


# ---------------------------------------------------------------------------
# Quote library loading
# ---------------------------------------------------------------------------

def load_quotes(path: str) -> list[dict]:
    """Load and return the quote library from a JSON file."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    # Accept either a top-level list or {"quotes": [...]}
    if isinstance(data, list):
        return data
    return data.get("quotes", [])


def load_embedded_quotes() -> list[dict]:
    """
    Return the embedded quote library (first 10 quotes from ONE-44 library).

    This is the fallback used when no --quotes file is provided.  It is a
    subset of the 90-quote library from ONE-44; the full library should be
    exported to quotes.json and passed via --quotes for production use.

    The full one-liner to export: see README in this directory.
    """
    return [
        {
            "id": "E-01",
            "plaintext": "The truth is rarely pure and never simple.",
            "author": "Oscar Wilde",
            "source": "The Importance of Being Earnest (1895)",
            "difficulty": "E",
            "risk_flag": "None",
        },
        {
            "id": "E-02",
            "plaintext": "No man is an island, entire of itself.",
            "author": "John Donne",
            "source": "Devotions Upon Emergent Occasions (1624)",
            "difficulty": "E",
            "risk_flag": "None",
        },
        {
            "id": "E-05",
            "plaintext": "The fear of death follows from the fear of life.",
            "author": "Mark Twain",
            "source": "attributed",
            "difficulty": "E",
            "risk_flag": "None",
        },
        {
            "id": "E-12",
            "plaintext": "Hope springs eternal in the human breast.",
            "author": "Alexander Pope",
            "source": "An Essay on Man (1733)",
            "difficulty": "E",
            "risk_flag": "None",
        },
        {
            "id": "E-13",
            "plaintext": "To err is human, to forgive divine.",
            "author": "Alexander Pope",
            "source": "An Essay on Criticism (1711)",
            "difficulty": "E",
            "risk_flag": "None",
        },
        {
            "id": "M-01",
            "plaintext": "The only way to have a friend is to be one.",
            "author": "Ralph Waldo Emerson",
            "source": "Essays: First Series (1841)",
            "difficulty": "M",
            "risk_flag": "None",
        },
        {
            "id": "M-11",
            "plaintext": "The only true wisdom is in knowing you know nothing.",
            "author": "Socrates",
            "source": "Plato, Apology, c. 399 BC",
            "difficulty": "M",
            "risk_flag": "[ATT]",
        },
        {
            "id": "M-12",
            "plaintext": "Three can keep a secret if two of them are dead.",
            "author": "Benjamin Franklin",
            "source": "Poor Richard's Almanack (1735)",
            "difficulty": "M",
            "risk_flag": "None",
        },
        {
            "id": "H-04",
            "plaintext": "The fault, dear Brutus, is not in our stars, but in ourselves, that we are underlings.",
            "author": "William Shakespeare",
            "source": "Julius Caesar (1599)",
            "difficulty": "H",
            "risk_flag": "None",
        },
        {
            "id": "H-11",
            "plaintext": "Two roads diverged in a wood, and I took the one less traveled by.",
            "author": "Robert Frost",
            "source": "The Road Not Taken (1916)",
            "difficulty": "H",
            "risk_flag": "None",
        },
    ]


# ---------------------------------------------------------------------------
# Rotation scheduler
# ---------------------------------------------------------------------------

def assign_quotes_to_dates(
    quotes: list[dict],
    start: date,
    days: int,
) -> list[tuple[date, dict]]:
    """
    Assign quotes to dates for the given window.

    Scheduling rules (from ONE-44 editorial policy):
      - Same-author gap: >= 14 days between same-author quotes.
      - Same-theme gap: >= 30 slots between near-duplicate-meaning quotes
        (not enforced here; editor is responsible for the library ordering).
      - Difficulty curve: Mon=E, Tue=E, Wed=E, Thu=M, Fri=M, Sat=H, Sun=M.
      - Escalated quotes ([ESC]) are silently skipped.
      - Quotes with too few distinct letters are silently skipped.

    This is a greedy scheduler: iterate dates, assign the next eligible quote
    from the filtered pool in library order, cycling if the pool exhausts.
    """
    # Filter out escalated and invalid quotes.
    eligible: list[dict] = []
    for q in quotes:
        errs = validate_quote(q)
        # Accept [ATT] and None risk flags; skip [ESC] and hard errors.
        flag = q.get("risk_flag", "None")
        if flag.startswith("[ESC]"):
            continue
        # Skip hard validation errors (distinct letter count etc.)
        hard_errors = [e for e in errs if "escalated" not in e.lower()]
        if hard_errors:
            continue
        eligible.append(q)

    # Difficulty map by weekday (0=Mon … 6=Sun)
    diff_by_weekday = {0: "E", 1: "E", 2: "E", 3: "M", 4: "M", 5: "H", 6: "M"}

    # Split eligible quotes by difficulty bucket.
    buckets: dict[str, list[dict]] = {"E": [], "M": [], "H": []}
    for q in eligible:
        diff = q.get("difficulty", "M")
        if diff not in buckets:
            diff = "M"
        buckets[diff].append(q)

    # Pointers for round-robin within each bucket.
    ptrs: dict[str, int] = {"E": 0, "M": 0, "H": 0}
    # Last-used-date per author (to enforce 14-day gap).
    last_author_date: dict[str, date] = {}

    assignments: list[tuple[date, dict]] = []
    current = start
    for _ in range(days):
        target_diff = diff_by_weekday[current.weekday()]
        bucket = buckets[target_diff]
        if not bucket:
            # Fall back to Medium if the target bucket is empty.
            bucket = buckets["M"]
        if not bucket:
            current += timedelta(days=1)
            continue

        # Find next eligible quote respecting the 14-day same-author gap.
        assigned: Optional[dict] = None
        ptr = ptrs[target_diff]
        attempts = 0
        while attempts < len(bucket):
            candidate = bucket[ptr % len(bucket)]
            author = candidate.get("author", "")
            last_used = last_author_date.get(author)
            if last_used is None or (current - last_used).days >= 14:
                assigned = candidate
                ptrs[target_diff] = (ptr + 1) % len(bucket)
                last_author_date[author] = current
                break
            ptr += 1
            attempts += 1

        if assigned is None:
            # All candidates violate the gap; just use the next one anyway.
            assigned = bucket[ptrs[target_diff] % len(bucket)]
            ptrs[target_diff] = (ptrs[target_diff] + 1) % len(bucket)
            last_author_date[assigned.get("author", "")] = current

        assignments.append((current, assigned))
        current += timedelta(days=1)

    return assignments


# ---------------------------------------------------------------------------
# Manifest builder
# ---------------------------------------------------------------------------

def build_manifest(
    quotes: list[dict],
    start: date,
    days: int,
) -> dict:
    """Build the complete daily puzzle manifest for the given date range."""
    assignments = assign_quotes_to_dates(quotes, start, days)
    entries = []
    for d, q in assignments:
        entry = build_puzzle_entry(q, d)
        entries.append(entry)

    return {
        "schemaVersion": "1.0",
        "generatedAt": date.today().isoformat(),
        "epochDate": PUZZLE_EPOCH.isoformat(),
        "entries": entries,
    }


def build_single_entry(quotes: list[dict], quote_id: str, d: date) -> dict:
    """Build a manifest for a single specific quote ID and date."""
    match = next((q for q in quotes if q["id"] == quote_id), None)
    if match is None:
        sys.exit(f"Error: quote ID '{quote_id}' not found in library.")
    entry = build_puzzle_entry(match, d)
    return {
        "schemaVersion": "1.0",
        "generatedAt": date.today().isoformat(),
        "epochDate": PUZZLE_EPOCH.isoformat(),
        "entries": [entry],
    }


# ---------------------------------------------------------------------------
# Validation mode
# ---------------------------------------------------------------------------

def run_validation(quotes: list[dict]) -> None:
    """Validate all quotes in the library and print a report."""
    ok = 0
    skipped = 0
    failed = 0
    for q in quotes:
        errors = validate_quote(q)
        flag = q.get("risk_flag", "None")
        if flag.startswith("[ESC]"):
            skipped += 1
            print(f"  SKIP  [{q.get('id','?')}] {flag} — {q.get('plaintext','')[:50]}")
            continue
        if errors:
            failed += 1
            for e in errors:
                print(f"  FAIL  [{q.get('id','?')}] {e}")
        else:
            ok += 1
    print(f"\nValidation: {ok} OK, {skipped} skipped (ESC), {failed} failed")
    if failed:
        sys.exit(1)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OnePuzzle cipher-quote daily manifest generator.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--quotes",
        default=None,
        help="Path to quotes JSON library file.  Defaults to embedded 10-quote sample.",
    )
    parser.add_argument(
        "--date",
        default=date.today().isoformat(),
        help="Target date for a single-day puzzle (YYYY-MM-DD).  Default: today.",
    )
    parser.add_argument(
        "--quote-id",
        default=None,
        help="Generate a puzzle for a specific quote ID (bypasses rotation scheduler).",
    )
    parser.add_argument(
        "--start",
        default=None,
        help="Start date for a multi-day manifest (YYYY-MM-DD).  Requires --days.",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=7,
        help="Number of days to generate for a multi-day manifest.  Default: 7.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Write manifest JSON to this file instead of stdout.",
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate all quotes in the library and exit.",
    )
    parser.add_argument(
        "--strip-internal",
        action="store_true",
        help="Strip _internal (plaintext, author) fields from output.  Use for CDN-safe manifests.",
    )

    args = parser.parse_args()

    # Load quotes.
    if args.quotes:
        quotes = load_quotes(args.quotes)
    else:
        quotes = load_embedded_quotes()
        print(
            "Warning: using embedded 10-quote sample library.  "
            "Pass --quotes <path> for full 90-quote library.",
            file=sys.stderr,
        )

    # Validation mode.
    if args.validate:
        run_validation(quotes)
        return

    # Build manifest.
    if args.start:
        start = date.fromisoformat(args.start)
        manifest = build_manifest(quotes, start, args.days)
    elif args.quote_id:
        d = date.fromisoformat(args.date)
        manifest = build_single_entry(quotes, args.quote_id, d)
    else:
        # Single-day mode using --date.
        d = date.fromisoformat(args.date)
        manifest = build_manifest(quotes, d, 1)

    # Strip internal fields for CDN-safe output.
    if args.strip_internal:
        for entry in manifest.get("entries", []):
            entry.pop("_internal", None)
            entry.pop("cipherMap", None)   # Strip full map; iOS reconstructs from seed.

    # Output.
    output_str = json.dumps(manifest, indent=2, ensure_ascii=False)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output_str)
        print(f"Manifest written to {args.output}")
    else:
        print(output_str)


if __name__ == "__main__":
    main()
