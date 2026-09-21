#!/usr/bin/env bash
# check-package-manager.sh
# pnpm is the only package manager allowed here. This refuses npm, npx, yarn and bun anywhere
# a human or an agent would copy a command from: package.json scripts, documentation, CI.
#
# It is not a style rule. Running `npm install` against a repository locked with pnpm resolves
# the tree afresh instead of honouring pnpm-lock.yaml, which is exactly how a freshly published
# compromised version gets in. The repository also pins every dependency to an exact version
# and holds new releases for 14 days (.npmrc); an npm invocation walks past both.
#
# Usage: ./scripts/check-package-manager.sh   (exit 1 on a forbidden invocation)

set -uo pipefail

cd "$(dirname "$0")/.."

status=0

# Word-boundary on the left so "pnpm add" never reads as "npm add", and a subcommand on the
# right so prose like "the npm registry" is not a false positive.
#
# npx, bunx and `bun x` are matched on ANY argument, with no subcommand list. Their first
# argument is not a verb, it is a package name: `npx tsx` downloads and executes a package just
# as much as `npm install` does. A verb list let `npx tsx` through until a mutation caught it.
FORBIDDEN='(^|[^a-zA-Z.-])(npm|yarn|bun)[[:space:]]+(install|ci|add|run|exec|dlx|update|upgrade|remove|uninstall|test|build|start)'
FORBIDDEN_RUNNER='(^|[^a-zA-Z.-])(npx|bunx)[[:space:]]+[^[:space:]]|(^|[^a-zA-Z.-])bun[[:space:]]+x[[:space:]]'

while IFS= read -r file; do
	[[ -f "$file" ]] || continue
	case "$file" in
		pnpm-lock.yaml|scripts/check-package-manager.sh) continue ;;
		*/node_modules/*) continue ;;
	esac

	# No exemption, for any file type, ever.
	#
	# An earlier version let a .md line name a banned command when it also named the pnpm
	# replacement, so that CLAUDE.md could carry a migration table. That was the wrong trade:
	# documentation is the single most likely place for someone to copy a command from, so it
	# is the last place that should be allowed to contain one. The table was rewritten by
	# intent instead ("to install the locked tree -> pnpm install"), which reads better AND
	# removed the need for the exemption. Two problems, one deletion.
	#
	# This script is itself excluded above, since it necessarily contains the patterns.
	while IFS= read -r hit; do
		echo "VIOLATION forbidden package manager: ${file}:${hit}"
		echo "    -> use pnpm (pnpm install / pnpm add / pnpm <script> / pnpm dlx)"
		status=1
	done < <(grep -nE "${FORBIDDEN}|${FORBIDDEN_RUNNER}" "$file" || true)
done < <(git ls-files --cached --others --exclude-standard -- \
	'package.json' '*.md' '.github/**' '*.yml' '*.yaml' '*.sh')

if [[ $status -eq 0 ]]; then
	echo "check-package-manager: OK (pnpm only)"
fi
exit $status
