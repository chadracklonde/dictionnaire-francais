#!/usr/bin/env python3
"""Teste le moteur de référence contre engine/test/conjugation_expected.json

    python3 test_conjugation.py
"""
import json
import sys
from pathlib import Path

from conjugation_ref import Conjugator

EXPECTED = (Path(__file__).resolve().parent.parent
            / "engine" / "test" / "conjugation_expected.json")


def main():
    data = json.loads(EXPECTED.read_text(encoding="utf-8"))
    engine = Conjugator()
    checks = failures = 0

    for verb, cases in data["tests"].items():
        result = engine.conjugate(verb)
        if result is None:
            print(f"ÉCHEC {verb}: verbe inconnu")
            failures += len(cases)
            checks += len(cases)
            continue
        for key, expected in cases.items():
            path, _, index = key.partition("#")
            mood, tense = path.split(".")
            row = result["moods"][mood][tense]
            if index:
                got = row[int(index)] if int(index) < len(row) else ""
                want = expected
            else:
                got = row
                want = expected.split(" | ") if expected else []
            checks += 1
            if got != want:
                failures += 1
                print(f"ÉCHEC {verb} / {key}\n   obtenu : {got}\n   attendu: {want}")

    for verb in data.get("unknown", []):
        checks += 1
        if engine.conjugate(verb) is not None:
            failures += 1
            print(f"ÉCHEC {verb}: devrait être inconnu")

    print(f"\n{checks - failures}/{checks} vérifications réussies "
          f"({len(data['tests'])} verbes)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
