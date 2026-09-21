#!/usr/bin/env bash
# hook-session-reports.sh — SessionStart hook. Prints existing git-ignored reports so the agent knows
# they exist (rg/git grep skip git-ignored files, so agents "lose" earlier reports). Never blocks.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/docs/rapport"

if ls "$DIR"/*.md >/dev/null 2>&1; then
	echo "Existing reports (docs/rapport/, git-ignored — French, caveman off):"
	for f in "$DIR"/*.md; do echo "  - ${f#"$ROOT"/}"; done
	echo "Manage with scripts/reports.sh (list | new <name>)."
fi

exit 0
