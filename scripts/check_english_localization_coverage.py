"""Report untranslated Chinese string literals in released iOS presentation code."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESENTATION_ROOTS = (ROOT / "MoveFit" / "Features", ROOT / "MoveFit" / "App")
STRINGS_FILE = ROOT / "MoveFit" / "Resources" / "en.lproj" / "Localizable.strings"
LITERAL = re.compile(r'"(?:[^"\\]|\\.)*"')
HAN = re.compile(r"[\u3400-\u9fff]")


def english_keys() -> set[str]:
    converted = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(STRINGS_FILE)],
        check=True,
        capture_output=True,
        text=True,
    )
    return set(json.loads(converted.stdout))


def missing_literals() -> list[tuple[str, int, str]]:
    keys = english_keys()
    missing: list[tuple[str, int, str]] = []
    for directory in PRESENTATION_ROOTS:
        for path in sorted(directory.rglob("*.swift")):
            for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                for match in LITERAL.finditer(line):
                    value = match.group()[1:-1]
                    if HAN.search(value) and value not in keys:
                        missing.append((str(path.relative_to(ROOT)), line_number, value))
    return missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true", help="Report gaps without failing")
    arguments = parser.parse_args()
    missing = missing_literals()
    for path, line_number, value in missing:
        print(f"{path}:{line_number}: {value}")
    print(f"Untranslated Chinese presentation literals: {len(missing)}")
    return 0 if arguments.report or not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
