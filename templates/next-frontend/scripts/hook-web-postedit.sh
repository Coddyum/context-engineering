#!/usr/bin/env bash
# hook-web-postedit.sh
# PostToolUse hook (Edit|Write|MultiEdit). Reads the hook JSON on stdin, extracts the edited
# file, and runs the guards that apply to it. Exit 2 blocks and hands the output back to the
# agent as feedback, so it fixes the problem in the same turn.
#
# Deliberately static: no package-manager command, no tsc, no next build, no vitest.
#
# A hook that runs a full Next build on every edit costs tens of seconds per keystroke and gets
# switched off within a day — and a guard that is off guards nothing. Type errors and test
# failures belong to `pnpm typecheck` and `pnpm test`, run deliberately. What is left here is
# everything checkable by reading the files, which turns out to be the part that silently ships:
# a public route that moved, a translation key that exists in one language only, a file nobody
# can read any more.
#
# If you do want typecheck-on-edit, run it on the single edited file (tsc-files) rather than the
# project, and measure the cost before committing to it.

set -uo pipefail

cd "$(dirname "$0")/.."

payload="$(cat)"

file="$(printf '%s' "$payload" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n1)"
[[ -n "$file" ]] || exit 0

repo_root="$(pwd)"
rel="${file#"$repo_root"/}"

# An edit outside this repository is not ours to judge. Without this the hook fires on sibling
# repositories whenever the session's working directory is elsewhere, and blocks on their files.
[[ "$rel" != /* ]] || exit 0

fail=0

case "$rel" in
	src/middleware.ts|scripts/expected/public-routes.txt)
		./scripts/check-public-routes.sh >&2 || fail=2
		;;
esac

case "$rel" in
	src/i18n/locales/*|src/locales/*)
		./scripts/check-i18n-parity.sh >&2 || fail=2
		;;
esac

case "$rel" in
	src/*.ts|src/*.tsx)
		./scripts/check-file-size.sh >&2 || fail=2
		./scripts/check-cross-feature-imports.sh "$rel" >&2 || fail=2
		./scripts/check-sommaire.sh "$rel" >&2 || fail=2
		;;
esac

case "$rel" in
	package.json|*.md|.github/*|*.yml|*.yaml|*.sh)
		./scripts/check-package-manager.sh >&2 || fail=2
		;;
esac

exit $fail
