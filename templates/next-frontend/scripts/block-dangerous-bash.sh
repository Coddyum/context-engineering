#!/usr/bin/env bash
# block-dangerous-bash.sh — PreToolUse(Bash) guard.
#
# Blocks the commands whose damage cannot be undone from the repository: they destroy work that
# was never committed, or rewrite history someone else already pulled. Everything else — dev
# servers, tests, generators, package scripts — passes untouched. The point is not to make the
# agent timid; it is to make exactly one class of mistake impossible.
#
# Exit 2 blocks and feeds the reason back to the agent.

set -uo pipefail

if command -v jq >/dev/null 2>&1; then
  cmd="$(jq -r '.tool_input.command // ""')"
else
  cmd="$(sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n1)"
fi
[ -n "$cmd" ] || exit 0

if echo "$cmd" | grep -qiE '(^|[;&|][[:space:]]*)rm[[:space:]]+-rf|git[[:space:]]+push[^;&|]*(--force|-f([[:space:]]|$))|git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+branch[[:space:]]+-D|git[[:space:]]+checkout[[:space:]]+\.[[:space:]]*$|git[[:space:]]+clean[[:space:]]+-[a-z]*f'; then
  {
    echo "BLOCKED: destructive or irreversible command."
    echo "Command: $cmd"
    echo "rm -rf / git push --force / git reset --hard / git branch -D / git checkout . / git clean -f"
    echo "need explicit human validation."
    echo "If the action is legitimate, ask the user to run it themselves."
  } >&2
  exit 2
fi

exit 0
