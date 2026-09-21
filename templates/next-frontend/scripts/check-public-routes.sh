#!/usr/bin/env bash
# check-public-routes.sh
# Pins the set of paths src/middleware.ts lets through without a refresh_token.
#
# That set is the whole authentication boundary of this front end: everything not in it gets
# redirected to /auth/login. Widening it is a security change, and a security change should
# never be a side effect of editing a switch statement. The expected set lives in
# scripts/expected/public-routes.txt, so adding a public path means editing that file too —
# a deliberate act, visible in the diff, reviewable on its own line.
#
# The guard reads every path literal compared against `pathname`, whichever block it sits in:
# the static-asset passthrough at the top bypasses the cookie check just as completely as the
# switch below it does.
#
# Usage: ./scripts/check-public-routes.sh   (exit 1 when the set moved)

set -uo pipefail

cd "$(dirname "$0")/.."

MIDDLEWARE="src/middleware.ts"
EXPECTED="scripts/expected/public-routes.txt"

if [[ ! -f "$MIDDLEWARE" ]]; then
	echo "check-public-routes: ${MIDDLEWARE} not found" >&2
	exit 1
fi
if [[ ! -f "$EXPECTED" ]]; then
	echo "check-public-routes: ${EXPECTED} not found" >&2
	exit 1
fi

# Every path literal tested against `pathname`, normalised to "<operator> <literal>".
actual="$(grep -oE 'pathname[[:space:]]*(===|\.startsWith\(|\.includes\()[[:space:]]*"[^"]*"' "$MIDDLEWARE" \
	| sed -E 's/pathname[[:space:]]*/ /; s/\([[:space:]]*/ /; s/[[:space:]]+/ /g; s/^ //' \
	| sort -u)"

expected="$(grep -vE '^[[:space:]]*(#|$)' "$EXPECTED" | sort -u)"

if [[ "$actual" == "$expected" ]]; then
	echo "check-public-routes: OK ($(printf '%s\n' "$actual" | wc -l | tr -d ' ') public paths)"
	exit 0
fi

echo "VIOLATION the public route set of ${MIDDLEWARE} changed."
echo
while IFS= read -r line; do
	[[ -n "$line" ]] || continue
	echo "  ADDED   ${line}  <- now reachable without a refresh_token"
done < <(comm -23 <(printf '%s\n' "$actual") <(printf '%s\n' "$expected"))
while IFS= read -r line; do
	[[ -n "$line" ]] || continue
	echo "  REMOVED ${line}  <- now behind the login redirect"
done < <(comm -13 <(printf '%s\n' "$actual") <(printf '%s\n' "$expected"))
echo
echo "    -> if this is intended, update ${EXPECTED} in the same commit and say why."
exit 1
