#!/usr/bin/env bash
# block-prod.sh — PreToolUse(Bash) guard. Blocks production-touching, main-merge and irreversible-git
# commands. Dev/sandbox autonomy is UNAFFECTED (up-dev, sqlc, tests, dev tooling all pass).
#
# Human authorization = run the exact command prefixed with ALLOW_PROD=1
#   e.g.  ALLOW_PROD=1 make up-prod
# Exit 2 blocks and feeds the reason back to the agent.

set -uo pipefail

payload="$(cat)"
if command -v jq >/dev/null 2>&1; then
	cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.cmd // ""' 2>/dev/null || true)"
else
	cmd="$(printf '%s' "$payload" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n1)"
fi
[ -n "$cmd" ] || exit 0

# Human escape hatch: explicit authorization for this command.
case "$cmd" in *ALLOW_PROD=1*) exit 0 ;; esac
[ "${ALLOW_PROD:-0}" = "1" ] && exit 0

blocked() {
	{
		echo "BLOCKED (block-prod): $1"
		echo "Command: $cmd"
		echo "Production, merges/pushes to main, and irreversible git are human-only."
		echo "If the human authorized this exact command, re-run it prefixed with ALLOW_PROD=1."
	} >&2
	exit 2
}

printf '%s\n' "$cmd" | grep -qiE '(^|[;&|[:space:]])make[[:space:]]+up-prod([[:space:]]|$)' && blocked "make up-prod (production migration)"
printf '%s\n' "$cmd" | grep -q  'DATABASE_URL_PROD'                                          && blocked "references the production database"
printf '%s\n' "$cmd" | grep -qiE 'migrate[[:space:]].*(force|drop)([[:space:]]|$)'           && blocked "irreversible migrate (force/drop)"
printf '%s\n' "$cmd" | grep -qiE 'git[[:space:]]+push[^;&|]*[[:space:]]main([[:space:]]|$)'  && blocked "push to main"
printf '%s\n' "$cmd" | grep -qiE 'git[[:space:]]+merge[^;&|]*[[:space:]]main([[:space:]]|$)' && blocked "merge to main"
printf '%s\n' "$cmd" | grep -qiE 'git[[:space:]]+push[^;&|]*(--force([^-]|$)|[[:space:]]-f([[:space:]]|$))' && blocked "force push"
printf '%s\n' "$cmd" | grep -qiE 'git[[:space:]]+reset[[:space:]]+[^;&|]*--hard'             && blocked "git reset --hard"
printf '%s\n' "$cmd" | grep -qiE 'git[[:space:]]+clean[[:space:]]+[^;&|]*-[a-z]*[fd]'        && blocked "git clean -fd"

exit 0
