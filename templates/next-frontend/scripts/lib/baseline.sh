#!/usr/bin/env bash
# baseline.sh
# Shared helpers for guards that must tolerate existing debt while refusing new debt.
#
# A guard that fails on 36 pre-existing files gets switched off on its first day. A baseline
# file lists the paths that already violate the rule at the moment the guard is introduced:
# those are tolerated, anything else fails. The list is the debt, written down and countable.
#
# The list also has to shrink honestly, so a path that no longer violates the rule is reported
# as resolved and fails the guard too — the only fix is to delete the line, which is how the
# debt becomes visibly smaller instead of quietly permanent.
#
# Usage from a guard script:
#
#   source "$(dirname "$0")/lib/baseline.sh"
#   baseline_load cross-feature-imports
#   ...
#   baseline_allows "$file" || { echo "VIOLATION ..."; status=1; }
#   baseline_verdict cross-feature-imports || status=1

set -uo pipefail

BASELINE_ENTRIES=()
BASELINE_HIT=()

# baseline_load <name> — read scripts/baseline/<name>.txt, ignoring blanks and # comments.
baseline_load() {
	local name="$1"
	local path="scripts/baseline/${name}.txt"
	BASELINE_ENTRIES=()
	BASELINE_HIT=()

	[[ -f "$path" ]] || return 0

	local line
	while IFS= read -r line; do
		line="${line%%#*}"
		line="$(printf '%s' "$line" | tr -d '[:space:]')"
		[[ -n "$line" ]] || continue
		BASELINE_ENTRIES+=("$line")
		BASELINE_HIT+=("no")
	done <"$path"
}

# baseline_allows <path> — 0 when the path is known debt (and marks it as still violating).
baseline_allows() {
	local candidate="$1"
	local i
	for i in "${!BASELINE_ENTRIES[@]}"; do
		if [[ "${BASELINE_ENTRIES[$i]}" == "$candidate" ]]; then
			BASELINE_HIT[$i]="yes"
			return 0
		fi
	done
	return 1
}

# baseline_verdict <name> — 1 when a baselined path stopped violating and must be delisted.
baseline_verdict() {
	local name="$1"
	local stale=0
	local i
	for i in "${!BASELINE_ENTRIES[@]}"; do
		if [[ "${BASELINE_HIT[$i]}" == "no" ]]; then
			echo "RESOLVED: ${BASELINE_ENTRIES[$i]} no longer violates this rule"
			echo "    -> delete that line from scripts/baseline/${name}.txt"
			stale=1
		fi
	done
	return $stale
}
