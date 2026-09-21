#!/usr/bin/env bash
# Codex PostToolUse hook: validate the Go files touched by an apply_patch before continuing.
# Autonomy-friendly — it never blocks commands, only bad code (broken build/vet, cross-feature
# import, missing sommaire). Exit 2 blocks and feeds the message back to Codex.
set -euo pipefail

payload=$(cat)
root=$(git rev-parse --show-toplevel)
cd "$root"

# The Codex sandbox cannot write user Go caches. Build cache goes to the allowed temp dir;
# -buildvcs=false avoids writing the main module stat cache into GOMODCACHE; -mod=readonly
# guarantees the hook does not touch go.mod/go.sum.
go_cache_dir="${TMPDIR:-/tmp}/blueprint-go-build-cache"
mkdir -p "$go_cache_dir"
export GOCACHE="$go_cache_dir"
export GOFLAGS="${GOFLAGS:-} -mod=readonly -buildvcs=false"

# Codex passes the patch in tool_input.command. Extract Add/Update/Delete paths.
patch=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')
paths=$(printf '%s\n' "$patch" \
  | sed -nE 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p' \
  | sed "s#^${root}/##" \
  | sort -u)

go_files=""
while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue
  case "$file_path" in
    *.go) go_files="${go_files}${file_path}"$'\n' ;;
  esac
done <<EOF
$paths
EOF

[ -n "$go_files" ] || exit 0

while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue

  if ! cross_output=$(./scripts/check-cross-feature-imports.sh "$file_path" 2>&1); then
    { echo "$cross_output"; echo "Fix the cross-feature import before continuing."; } >&2
    exit 2
  fi

  if [ -f "$file_path" ] && ! sommaire_output=$(./scripts/check-sommaire.sh "$file_path" 2>&1); then
    { echo "$sommaire_output"; echo "Rule .claude/rules/file-sommaire.md: use the sommaire skill."; } >&2
    exit 2
  fi
done <<EOF
$go_files
EOF

if ! build_output=$(go build ./... 2>&1); then
  { echo "BUILD BROKEN after Go edit"; echo "$build_output"; echo "Fix before continuing or declaring done."; } >&2
  exit 2
fi

if ! vet_output=$(go vet ./... 2>&1); then
  { echo "go vet failed after Go edit"; echo "$vet_output"; echo "Fix before continuing or declaring done."; } >&2
  exit 2
fi

exit 0
