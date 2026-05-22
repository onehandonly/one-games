#!/usr/bin/env python3
"""
test-cipher-generator.py — Algorithm validation for cipher-generator.swift
ONE Games — run this on any platform to validate generator logic.

Usage: python3 test-cipher-generator.py
"""

import json
import hashlib

# ---------------------------------------------------------------------------
# Mirror of Swift LCG + Fisher-Yates from cipher-generator.swift
# ---------------------------------------------------------------------------

def derive_seed(quote: str, date: str) -> int:
    """FNV-1a hash of '{date}|{quote.upper()}' → uint64"""
    text = f"{date}|{quote.upper()}"
    h = 14695981039346656037  # FNV offset basis
    mask = (1 << 64) - 1
    for byte in text.encode("utf-8"):
        h ^= byte
        h = (h * 1099511628211) & mask
    return h

def generate_cipher_mapping(seed: int) -> dict:
    """Deterministic bijective monoalphabetic cipher mapping. No self-maps."""
    alphabet = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    shuffled = list(alphabet)

    state = seed
    mask = (1 << 64) - 1

    def next_random():
        nonlocal state
        state = (state * 6364136223846793005 + 1442695040888963407) & mask
        return state

    # Fisher-Yates
    for i in range(len(shuffled) - 1, 0, -1):
        j = next_random() % (i + 1)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]

    # Fix self-maps
    for _ in range(10):
        has_self_map = False
        for i in range(26):
            if shuffled[i] == alphabet[i]:
                has_self_map = True
                j = (i + 1) % 26
                shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        if not has_self_map:
            break

    # Edge-case fallback
    for i in range(26):
        if shuffled[i] == alphabet[i]:
            for j in range(26):
                if j != i and shuffled[j] != alphabet[i] and shuffled[i] != alphabet[j]:
                    shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
                    break

    return {alphabet[i]: shuffled[i] for i in range(26)}

def apply_cipher(text: str, mapping: dict) -> str:
    out = []
    for ch in text:
        upper = ch.upper()
        if upper in mapping:
            cipher = mapping[upper]
            out.append(cipher if ch.isupper() else cipher.lower())
        else:
            out.append(ch)
    return "".join(out)

def validate_mapping(mapping: dict, plaintext: str) -> list:
    errors = []
    alphabet = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    missing_keys = alphabet - set(mapping.keys())
    if missing_keys:
        errors.append(f"Missing keys: {sorted(missing_keys)}")

    values = list(mapping.values())
    if len(set(values)) != 26:
        errors.append(f"Not bijective: {len(values)} values, {len(set(values))} unique")

    for k, v in mapping.items():
        if k == v:
            errors.append(f"Self-map: {k} → {v}")

    unique_letters = set(ch.upper() for ch in plaintext if ch.isalpha())
    if len(unique_letters) < 10:
        errors.append(f"Only {len(unique_letters)} unique letters in quote (min 10)")

    return errors

# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

TEST_QUOTES = [
    {
        "quoteId": "E-01",
        "plaintext": "The truth is rarely pure and never simple.",
        "author": "Oscar Wilde",
        "source": "The Importance of Being Earnest (1895)",
        "scheduledDate": "2026-06-02",
        "dayIndex": 1,
        "difficulty": "E",
        "riskFlag": "None",
    },
    {
        "quoteId": "H-04",
        "plaintext": "The fault, dear Brutus, is not in our stars, but in ourselves, that we are underlings.",
        "author": "William Shakespeare",
        "source": "Julius Caesar (1599)",
        "scheduledDate": "2026-06-07",
        "dayIndex": 6,
        "difficulty": "H",
        "riskFlag": "None",
    },
    {
        "quoteId": "E-09",
        "plaintext": "The quality of mercy is not strained.",
        "author": "William Shakespeare",
        "source": "The Merchant of Venice (1600)",
        "scheduledDate": "2026-06-08",
        "dayIndex": 7,
        "difficulty": "E",
        "riskFlag": "None",
    },
]

def run_tests():
    print("=" * 60)
    print("cipher-generator algorithm validation")
    print("=" * 60)

    all_passed = True

    for q in TEST_QUOTES:
        print(f"\n--- Testing {q['quoteId']}: \"{q['plaintext'][:40]}...\"")

        seed = derive_seed(q["plaintext"], q["scheduledDate"])
        mapping = generate_cipher_mapping(seed)
        ciphertext = apply_cipher(q["plaintext"], mapping)
        errors = validate_mapping(mapping, q["plaintext"])

        print(f"  Seed:       {seed}")
        print(f"  Ciphertext: {ciphertext[:60]}{'...' if len(ciphertext) > 60 else ''}")

        # Test 1: No validation errors
        if errors:
            print(f"  ❌ VALIDATION ERRORS: {errors}")
            all_passed = False
        else:
            print(f"  ✅ Mapping valid (bijective, no self-maps)")

        # Test 2: Determinism — same seed → same mapping
        mapping2 = generate_cipher_mapping(seed)
        if mapping != mapping2:
            print("  ❌ DETERMINISM FAILED: second generation produced different mapping")
            all_passed = False
        else:
            print("  ✅ Deterministic: same seed → same mapping")

        # Test 3: Seed is date-dependent (different date → different seed → different mapping)
        seed_other_date = derive_seed(q["plaintext"], "2099-01-01")
        mapping_other = generate_cipher_mapping(seed_other_date)
        if mapping_other == mapping:
            print("  ⚠️  WARNING: Different dates produced identical mapping (unlikely but check)")
        else:
            print("  ✅ Date-sensitive: different date → different mapping")

        # Test 4: Decipherability — apply inverse mapping to get plaintext back
        inverse = {v: k for k, v in mapping.items()}
        recovered = apply_cipher(ciphertext, inverse)
        if recovered.upper() != q["plaintext"].upper():
            print(f"  ❌ DECRYPT FAILED: recovered '{recovered}' ≠ '{q['plaintext']}'")
            all_passed = False
        else:
            print("  ✅ Invertible: decrypt(encrypt(plaintext)) == plaintext")

        # Test 5: Share-card safety — ciphertext should not contain recognizable words
        # (simple heuristic: no word > 3 letters in ciphertext matches plaintext)
        plaintext_words = set(w.upper().strip(".,!?;:'\"") for w in q["plaintext"].split() if len(w) > 3)
        cipher_words = set(w.upper().strip(".,!?;:'\"") for w in ciphertext.split())
        leaked = plaintext_words & cipher_words
        if leaked:
            print(f"  ❌ SHARE-CARD LEAK: ciphertext contains plaintext words: {leaked}")
            all_passed = False
        else:
            print("  ✅ Share-card safe: no plaintext words visible in ciphertext")

        # Show sample mapping (first 10)
        sample = {k: mapping[k] for k in sorted(mapping)[:10]}
        print(f"  Mapping sample: {sample}")

    print("\n" + "=" * 60)
    if all_passed:
        print("✅ ALL TESTS PASSED")
    else:
        print("❌ SOME TESTS FAILED — see above")
    print("=" * 60)

    return all_passed

if __name__ == "__main__":
    success = run_tests()
    exit(0 if success else 1)
