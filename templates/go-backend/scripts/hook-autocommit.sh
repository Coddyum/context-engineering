#!/usr/bin/env bash
# hook-autocommit.sh
# PostToolUse (Edit|Write|MultiEdit). ULTRA-FREQUENT checkpoint commit: as soon as an edit leaves the
# code in a VIABLE state (it compiles), commit a checkpoint. Do NOT wait for a feature to be finished.
# If it does not compile → no commit (history stays green).
#
# Viability by edited zone:
#   - *.go                 → `go build ./...` must pass.
#   - docs / sql / config  → viable as-is (text), commit.
#
# NEVER blocks (exit 0 everywhere). Disable: export BLUEPRINT_AUTOCOMMIT=0.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Escape hatch (e.g. when you want grouped manual commits).
[[ "${BLUEPRINT_AUTOCOMMIT:-1}" == "0" ]] && exit 0

payload="$(cat)"
file="$(printf '%s' "$payload" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n1)"
[[ -n "$file" ]] || exit 0

# Only inside this repo.
case "$file" in "$ROOT"/*) ;; *) exit 0 ;; esac
# Noise / non-source.
case "$file" in */node_modules/*|*/.git/*|*/scratchpad/*|*/bin/*) exit 0 ;; esac

# No commit during an in-progress merge/rebase.
gitdir="$(cd "$ROOT" && git rev-parse --git-dir 2>/dev/null)" || exit 0
[[ "$gitdir" != /* ]] && gitdir="$ROOT/$gitdir"
[[ -e "$gitdir/MERGE_HEAD" || -d "$gitdir/rebase-merge" || -d "$gitdir/rebase-apply" ]] && exit 0

# Viability check by zone.
ok=1
case "$file" in
	*.go) ( cd "$ROOT" && go build ./... ) >/dev/null 2>&1 || ok=0 ;;
	*) : ;; # docs / sql / config: viable as-is.
esac
[[ "$ok" == "1" ]] || exit 0

cd "$ROOT" || exit 0

# Nothing to commit?
if git diff --quiet && git diff --cached --quiet; then
	exit 0
fi

# Stage ONLY the edited file — never `-A`. Each checkpoint = the touched file only.
git add -- "$file" >/dev/null 2>&1 || exit 0
git diff --cached --quiet && exit 0 # file was git-ignored / nothing to commit

rel="${file#"$ROOT"/}"
git commit -q \
	-m "checkpoint: ${rel}" \
	-m "Auto-commit of a viable (compiling) state after edit — frequent checkpoint, not a finished feature.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" >/dev/null 2>&1 || true

exit 0
