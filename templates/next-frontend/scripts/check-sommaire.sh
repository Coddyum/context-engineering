#!/usr/bin/env bash
# check-sommaire.sh
# Checks that a .ts/.tsx file carries a SOMMAIRE block, at least in sync with its top-level
# exports plus its handleXxx handlers. See .claude/rules/file-sommaire.md.
#
# A React file often has one export but composes several internal pieces — handlers, sub-renders,
# a dropdown — each worth one row. The block is what lets an agent open the file, read fifteen
# lines, and jump to line 212 instead of reading four hundred.
#
# The marker below is a fixed French literal, shared verbatim with the tooling on the Go side of
# the same stack. Do not translate it.
#
# Usage: check-sommaire.sh <file>
#   - silent when (exports + handlers) < 2 (a sommaire would be noise)
#   - exit 1 when the block is missing or undersized

set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

file="$1"

case "$file" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

case "$file" in
  *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*.d.ts) exit 0 ;;
esac

[ -f "$file" ] || exit 0

export_count=$(grep -cE '^export (default function|function|const|class|type|interface) ' "$file" || true)
handler_count=$(grep -cE '^\s*(const|function) handle[A-Z]' "$file" || true)
total=$((export_count + handler_count))

if [ "$total" -lt 2 ]; then
  exit 0
fi

marker='// SOMMAIRE (lire en premier, sauter directement au bon passage)'

if ! grep -qF "$marker" "$file"; then
  echo "SOMMAIRE missing in $file ($export_count export(s) + $handler_count handler(s))."
  echo "-> write the // SOMMAIRE block (see .claude/rules/file-sommaire.md)."
  exit 1
fi

row_count=$(awk -v marker="$marker" '
  $0 == marker { in_block=1; next }
  in_block && /^\/\/ \|/ {
    if (header_seen && sep_seen) rows++
    if (!header_seen) { header_seen=1; next }
    if (!sep_seen) { sep_seen=1; next }
    next
  }
  in_block && /^\/\/ =+$/ { exit }
  END { print rows+0 }
' "$file")

if [ "$row_count" -lt "$total" ]; then
  echo "SOMMAIRE undersized in $file: $total export(s)/handler(s) vs $row_count row(s)."
  echo "-> update the // SOMMAIRE block (see .claude/rules/file-sommaire.md)."
  exit 1
fi

exit 0
