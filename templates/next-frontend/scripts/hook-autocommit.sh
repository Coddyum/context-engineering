#!/usr/bin/env bash
# hook-autocommit.sh
# PostToolUse (Edit|Write|MultiEdit). ULTRA-FREQUENT checkpoint commit: as soon as an edit lands,
# commit that one file. Do NOT wait for a feature to be finished.
#
# The value is not tidy history — it is that every intermediate state is recoverable. An agent
# that breaks something at 14:31 can be walked back to 14:28 without the human having remembered
# to commit. These checkpoints are never squashed, amended or rewritten: thirty of them stay
# thirty.
#
# Unlike the Go variant there is no build gate here: running a Next build or tsc per edit costs
# tens of seconds and the hook gets disabled. The static guards in hook-web-postedit.sh already
# blocked (exit 2) on anything readable-and-wrong before this hook runs.
#
# NEVER blocks (exit 0 everywhere). Disable: export FRONTEND_AUTOCOMMIT=0.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ "${FRONTEND_AUTOCOMMIT:-1}" == "0" ]] && exit 0

payload="$(cat)"
file="$(printf '%s' "$payload" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n1)"
[[ -n "$file" ]] || exit 0

# Only inside this repo.
case "$file" in "$ROOT"/*) ;; *) exit 0 ;; esac
# Noise / non-source.
case "$file" in */node_modules/*|*/.git/*|*/.next/*|*/scratchpad/*|*/dist/*) exit 0 ;; esac

# No commit during an in-progress merge/rebase.
gitdir="$(cd "$ROOT" && git rev-parse --git-dir 2>/dev/null)" || exit 0
[[ "$gitdir" != /* ]] && gitdir="$ROOT/$gitdir"
[[ -e "$gitdir/MERGE_HEAD" || -d "$gitdir/rebase-merge" || -d "$gitdir/rebase-apply" ]] && exit 0

cd "$ROOT" || exit 0

if git diff --quiet && git diff --cached --quiet; then
	exit 0
fi

# Stage ONLY the edited file — never `-A`. Each checkpoint = the touched file only.
git add -- "$file" >/dev/null 2>&1 || exit 0
git diff --cached --quiet && exit 0 # file was git-ignored / nothing to commit

rel="${file#"$ROOT"/}"
git commit -q \
	-m "checkpoint: ${rel}" \
	-m "Auto-commit of a single edited file — frequent checkpoint, not a finished feature." \
	>/dev/null 2>&1 || true

exit 0
