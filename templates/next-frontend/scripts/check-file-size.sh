#!/usr/bin/env bash
# check-file-size.sh
# Flags .ts / .tsx source files over MAX_LINES (default 300), excluding tests.
#
# A 700-line component cannot be read in one pass, so it gets edited blind and the edit lands
# next to code nobody re-read. In React the split is usually obvious once looked for: a hook,
# a sub-component, or a constants file.
#
# Usage: ./scripts/check-file-size.sh   (exit 1 when a non-baselined file is over the limit)

set -uo pipefail

cd "$(dirname "$0")/.."
source "scripts/lib/baseline.sh"

MAX_LINES="${MAX_LINES:-300}"
status=0
baseline_load "file-size"

# --others --exclude-standard keeps files that are written but not yet `git add`ed, which are
# exactly the ones worth checking before they are committed.
while IFS= read -r file; do
	case "$file" in
		*__tests__*) continue ;;
		*.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx) continue ;;
		*.d.ts) continue ;;
	esac
	[[ -f "$file" ]] || continue

	lines="$(wc -l <"$file" | tr -d ' ')"
	(( lines > MAX_LINES )) || continue

	if baseline_allows "$file"; then
		continue
	fi
	echo "TOO BIG (${lines} > ${MAX_LINES}): ${file} -> split it"
	status=1
done < <(git ls-files --cached --others --exclude-standard -- 'src/*.ts' 'src/*.tsx')

baseline_verdict "file-size" || status=1

if [[ $status -eq 0 ]]; then
	echo "check-file-size: OK (limit ${MAX_LINES})"
fi
exit $status
