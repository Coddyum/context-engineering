#!/usr/bin/env bash
# check-i18n-parity.sh
# Every translation key present in one locale must exist in the other.
#
# A missing key does not crash: i18next renders the raw key or the fallback language, so the
# bug ships and is only found by a user reading the wrong language on a real page. That is the
# worst shape a bug can have — silent, cosmetic-looking, and in front of a customer. It found
# a live one the day it was written: billing.info.per-year existed in en and not in fr, on the
# billing screen of an annual subscription.
#
# Compares key paths, never values: an untranslated string is a translation job, not a defect
# this guard can see.
#
# Usage: ./scripts/check-i18n-parity.sh   (exit 1 on divergence)

set -uo pipefail

cd "$(dirname "$0")/.."

python3 - <<'PY'
import json
import sys
from pathlib import Path

ROOT = Path("src/i18n/locales")
status = 0


def key_paths(node, prefix=""):
    if isinstance(node, dict):
        out = set()
        for key, value in node.items():
            out |= key_paths(value, f"{prefix}.{key}" if prefix else key)
        return out
    return {prefix}


def load(path):
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        print(f"VIOLATION invalid JSON: {path} ({exc})")
        return None


locales = sorted(p.name for p in ROOT.iterdir() if p.is_dir())
if len(locales) < 2:
    print(f"check-i18n-parity: fewer than two locales under {ROOT}", file=sys.stderr)
    sys.exit(1)

reference, *others = locales
ref_root = ROOT / reference

for other in others:
    other_root = ROOT / other

    ref_files = {p.relative_to(ref_root) for p in ref_root.rglob("*.json")}
    other_files = {p.relative_to(other_root) for p in other_root.rglob("*.json")}

    for missing in sorted(ref_files - other_files):
        print(f"VIOLATION missing file: {other}/{missing} (exists in {reference})")
        status = 1
    for missing in sorted(other_files - ref_files):
        print(f"VIOLATION missing file: {reference}/{missing} (exists in {other})")
        status = 1

    for rel in sorted(ref_files & other_files):
        ref_doc = load(ref_root / rel)
        other_doc = load(other_root / rel)
        if ref_doc is None or other_doc is None:
            status = 1
            continue

        ref_keys = key_paths(ref_doc)
        other_keys = key_paths(other_doc)

        for key in sorted(ref_keys - other_keys):
            print(f"VIOLATION {rel}: key '{key}' is in {reference} but not in {other}")
            status = 1
        for key in sorted(other_keys - ref_keys):
            print(f"VIOLATION {rel}: key '{key}' is in {other} but not in {reference}")
            status = 1

if status == 0:
    print(f"check-i18n-parity: OK ({', '.join(locales)})")
else:
    print("    -> add the key to every locale, even if the wording is provisional")
sys.exit(status)
PY
