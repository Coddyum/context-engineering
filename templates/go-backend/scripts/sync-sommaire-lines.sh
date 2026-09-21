#!/usr/bin/env bash
# sync-sommaire-lines.sh
# Recomputes the "Ligne" column of // SOMMAIRE blocks from the real declaration positions.
#
# It never adds or removes a table row. If the row count does not match the declaration count,
# the file is reported and left untouched: writing the description of a new declaration, or
# dropping the row of one that is gone, is a judgement call and stays with the author. Only the
# line numbers, which are pure bookkeeping, are fixed automatically.
#
# Usage:
#   ./scripts/sync-sommaire-lines.sh            every file
#   ./scripts/sync-sommaire-lines.sh <file>     one file

set -uo pipefail

python3 - "$@" <<'PY'
import re
import sys
from pathlib import Path

MARKER = "// SOMMAIRE (lire en premier, sauter directement au bon passage)"
DECL = re.compile(r"^(func |type )")
ROW = re.compile(r"^// \|")
HEADER = re.compile(r"^// \| *Élément")
SEPARATOR = re.compile(r"^// \|[-| ]+\|?\s*$")

EXCLUDED_PARTS = ("internal/database", ".git")


def targets(argv):
    if argv:
        return [Path(a) for a in argv]
    return [
        p
        for p in Path(".").rglob("*.go")
        if not any(part in str(p) for part in EXCLUDED_PARTS)
        and not p.name.endswith("_test.go")
    ]


def sync(path):
    if not path.is_file():
        return None
    lines = path.read_text().splitlines()
    if not any(line.startswith(MARKER) for line in lines):
        return None

    rows = [
        i
        for i, line in enumerate(lines)
        if ROW.match(line) and not HEADER.match(line) and not SEPARATOR.match(line)
    ]
    decls = [i + 1 for i, line in enumerate(lines) if DECL.match(line)]

    if len(rows) != len(decls):
        return f"{path}: {len(rows)} table rows vs {len(decls)} declarations - fix by hand"

    changed = False
    for row_index, decl_line in zip(rows, decls):
        cells = lines[row_index].split("|")
        if len(cells) < 4:
            continue
        width = len(cells[-2])
        replacement = f" {decl_line}".ljust(width)
        if cells[-2] != replacement:
            cells[-2] = replacement
            lines[row_index] = "|".join(cells)
            changed = True

    if changed:
        path.write_text("\n".join(lines) + "\n")
        print(f"sommaire resynchronised: {path}")
    return None


problems = [msg for msg in (sync(p) for p in targets(sys.argv[1:])) if msg]
for msg in problems:
    print(msg, file=sys.stderr)
sys.exit(1 if problems else 0)
PY
