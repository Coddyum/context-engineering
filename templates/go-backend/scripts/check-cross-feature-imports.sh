#!/usr/bin/env bash
# check-cross-feature-imports.sh
# Refuses a feature importing another feature directly.
# A feature may import ONLY its own subtree internal/feature/<self>/...
# Every inter-feature dependency goes through FeatureRegistry / CoreServices.
#
# Usage: ./scripts/check-cross-feature-imports.sh  (exit 1 on violation)
# Used by `make lint` and the PostToolUse hook.

set -euo pipefail

FEATURE_ROOT="internal/feature"
# Go module path (e.g. github.com/you/project) — read from go.mod.
MODULE_PATH="$(awk '/^module /{print $2; exit}' go.mod)"

if [[ -z "${MODULE_PATH}" ]]; then
	echo "check-cross-feature-imports: no module path found in go.mod" >&2
	exit 1
fi

status=0

# For every .go file under a feature, spot imports pointing at ANOTHER feature.
while IFS= read -r -d '' file; do
	# the feature this file belongs to (the segment after internal/feature/)
	self="$(printf '%s\n' "$file" | sed -E "s#^.*${FEATURE_ROOT}/([^/]+)/.*#\1#")"

	# imports pointing at internal/feature/<other>
	while IFS= read -r imported; do
		other="$(printf '%s\n' "$imported" | sed -E "s#^.*${FEATURE_ROOT}/([^/\"]+).*#\1#")"
		if [[ -n "${other}" && "${other}" != "${self}" ]]; then
			echo "VIOLATION cross-feature import: ${file}"
			echo "    feature '${self}' imports feature '${other}' (${imported})"
			echo "    -> go through FeatureRegistry.Get(\"${other}\") or CoreServices"
			status=1
		fi
	done < <(grep -oE "\"${MODULE_PATH}/${FEATURE_ROOT}/[^\"]+\"" "$file" || true)
done < <(find "${FEATURE_ROOT}" -type f -name '*.go' ! -name '*_test.go' -print0 2>/dev/null)

if [[ $status -eq 0 ]]; then
	echo "check-cross-feature-imports: OK"
fi
exit $status
