#!/usr/bin/env bash
# check-cross-feature-imports.sh
# Refuses a feature importing another feature directly.
#
# `src/features/<name>/` is a module boundary, not a folder. The moment feature A reaches into
# feature B's internals, moving or renaming anything in B becomes a repo-wide operation — and an
# agent asked to "change the invoice card" has to load two features instead of one. Shared code
# goes to src/components/, src/hooks/ or src/queries/, or through the feature's index.ts.
#
# Usage: check-cross-feature-imports.sh [file ...]
#   - no argument: scan all of src/features/
#   - with arguments: check only those files (used by the PostToolUse hook)

set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

violations=0

check_file() {
  local file="$1"
  case "$file" in
    src/features/*/*) ;;
    *) return 0 ;;
  esac

  local feature
  feature=$(echo "$file" | sed -E 's#^src/features/([^/]+)/.*#\1#')

  local bad
  bad=$(grep -oE '@/features/[a-zA-Z0-9_-]+' "$file" 2>/dev/null \
    | sed 's#@/features/##' \
    | sort -u \
    | grep -v "^${feature}\$" || true)

  if [ -n "$bad" ]; then
    echo "VIOLATION: $file (feature '$feature') imports directly: $bad"
    echo "  -> a feature never imports another feature."
    echo "     Go through src/components/, src/hooks/ or src/queries/."
    violations=$((violations + 1))
  fi
}

if [ "$#" -gt 0 ]; then
  for f in "$@"; do check_file "$f"; done
else
  while IFS= read -r f; do check_file "$f"; done \
    < <(find src/features -type f \( -name '*.ts' -o -name '*.tsx' \))
fi

exit $((violations > 0 ? 1 : 0))
