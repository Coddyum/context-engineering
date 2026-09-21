#!/usr/bin/env bash
# reports.sh — manage git-ignored reports under docs/rapport/.
# Reports are written in <REPORT_LANGUAGE>, with every compression mode OFF.
# See .claude/rules/reports.md.
#
#   reports.sh list          list existing reports
#   reports.sh new <name>    create docs/rapport/<name>.md (French stub)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/docs/rapport"
cmd="${1:-list}"

case "$cmd" in
	list)
		mkdir -p "$DIR"
		if ls "$DIR"/*.md >/dev/null 2>&1; then
			echo "Reports in docs/rapport/ (git-ignored):"
			for f in "$DIR"/*.md; do echo "  - ${f#"$ROOT"/}"; done
		else
			echo "No report yet in docs/rapport/."
		fi
		;;
	new)
		name="${2:-}"; [[ -n "$name" ]] || { echo "usage: reports.sh new <name>" >&2; exit 1; }
		name="${name%.md}"
		mkdir -p "$DIR"
		f="$DIR/${name}.md"
		[[ -e "$f" ]] && { echo "already exists: ${f#"$ROOT"/}" >&2; exit 1; }
		printf '# Report — %s\n\n> Written in <REPORT_LANGUAGE>, compression modes off.\n\n' "$name" > "$f"
		echo "created: ${f#"$ROOT"/}"
		;;
	*)
		echo "usage: reports.sh [list|new <name>]" >&2; exit 1 ;;
esac
