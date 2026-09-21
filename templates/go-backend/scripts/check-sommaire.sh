#!/usr/bin/env bash
# check-sommaire.sh
# Checks that every .go file with >= 2 top-level declarations carries a synchronised
# // SOMMAIRE block. Structure only (presence + table row count == declaration count),
# NOT the quality of the descriptions — that stays the agent's job.
#
# The marker below is a fixed French literal, shared verbatim with the `sommaire` skill
# and sync-sommaire-lines.sh. Do not translate it.
#
# Usage:
#   ./scripts/check-sommaire.sh            scan the whole repo (make lint)
#   ./scripts/check-sommaire.sh <file>     a single file (PostToolUse hook)
# Exit 2 (blocking) when missing or desynchronised, so it can be used as a hook.

set -euo pipefail

MARKER='// SOMMAIRE (lire en premier, sauter directement au bon passage)'
status=0

check_one() {
	local file="$1"
	[[ "$file" == *.go ]] || return 0
	[[ -f "$file" ]] || return 0

	# Exclusions: sqlc-generated, DO NOT EDIT, tests.
	case "$file" in
		*/internal/database/*) return 0 ;;
		*_test.go) return 0 ;;
	esac
	if head -n 3 "$file" | grep -q 'Code generated .* DO NOT EDIT'; then
		return 0
	fi

	# Top-level declarations: lines starting with "func " or "type ".
	local decls
	decls="$(grep -cE '^(func |type )' "$file" || true)"

	if (( decls < 2 )); then
		# The block is forbidden below 2 declarations: present means desynchronised.
		if grep -qF "$MARKER" "$file"; then
			echo "SOMMAIRE not needed (${decls} declaration): ${file} -> remove the block"
			echo "    → /sommaire ${file}"
			status=2
		fi
		return 0
	fi

	# >= 2 declarations: the marker is mandatory.
	if ! grep -qF "$MARKER" "$file"; then
		echo "SOMMAIRE missing (${decls} declarations): ${file}"
		echo "    → /sommaire ${file}"
		status=2
		return 0
	fi

	# Count the block's table rows: lines '// | ... | ... | ... |',
	# excluding the header row (| Élément |) and the separator (|---|).
	local rows
	rows="$(grep -E '^// \|' "$file" \
		| grep -vE '^// \| *Élément' \
		| grep -vE '^// \|[-| ]+\|?[[:space:]]*$' \
		| grep -c '|' || true)"

	if (( rows != decls )); then
		echo "SOMMAIRE desynchronised: ${file} (${rows} table rows vs ${decls} declarations)"
		echo "    → /sommaire ${file}"
		status=2
	fi
}

if [[ $# -gt 0 ]]; then
	for f in "$@"; do check_one "$f"; done
else
	while IFS= read -r -d '' f; do check_one "$f"; done \
		< <(find . -type f -name '*.go' -print0)
fi

if [[ $status -eq 0 ]]; then
	echo "check-sommaire: OK"
fi
exit $status
