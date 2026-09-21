#!/usr/bin/env bash
# hook-go-postedit.sh
# PostToolUse hook (Edit|Write). Reads the hook JSON on stdin, extracts the edited file.
# If it is a .go: go build + go vet + structural guards. Exit 2 blocks and hands the output
# back to the agent as feedback — which is the point: the agent fixes it in the same turn,
# instead of the human discovering it three prompts later.
#
# Wired in .claude/settings.json. Does nothing when the tool touched no .go file.

set -uo pipefail

payload="$(cat)"

# Extract the file path from the hook payload (tool_input.file_path).
file="$(printf '%s' "$payload" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n1)"

[[ -n "$file" && "$file" == *.go ]] || exit 0

fail=0

# 1. Build + vet over the whole module (an error elsewhere must block too).
if ! go build ./... 2>&1; then
	echo "hook: go build fails - fix it before continuing." >&2
	fail=2
fi
if ! go vet ./... 2>&1; then
	echo "hook: go vet fails." >&2
	fail=2
fi

# 2. Cross-feature imports (only when the file sits under a feature).
if [[ "$file" == *internal/feature/* ]]; then
	if ! ./scripts/check-cross-feature-imports.sh >&2; then
		fail=2
	fi
fi

# 3. Sommaire of the edited file.
if ! ./scripts/check-sommaire.sh "$file" >&2; then
	fail=2
fi

exit $fail
