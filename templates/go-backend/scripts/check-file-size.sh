#!/usr/bin/env bash
# check-file-size.sh
# Flags .go files over MAX_LINES (default 300), excluding generated code and _test.go.
# An oversized file is a signal to split (SRP) — and a file an agent must read in full
# to change one function is a file that costs context on every single session.
#
# Usage: ./scripts/check-file-size.sh  (exit 1 when over)

set -euo pipefail

MAX_LINES="${MAX_LINES:-300}"
status=0

while IFS= read -r -d '' file; do
	# Exclusions: sqlc-generated code, files marked DO NOT EDIT.
	case "$file" in
		*/internal/database/*) continue ;;
	esac
	if head -n 3 "$file" | grep -q 'Code generated .* DO NOT EDIT'; then
		continue
	fi

	lines="$(wc -l < "$file" | tr -d ' ')"
	if (( lines > MAX_LINES )); then
		echo "TOO BIG (${lines} > ${MAX_LINES}): ${file} -> split it"
		status=1
	fi
done < <(find . -type f -name '*.go' ! -name '*_test.go' -print0)

if [[ $status -eq 0 ]]; then
	echo "check-file-size: OK (limit ${MAX_LINES})"
fi
exit $status
