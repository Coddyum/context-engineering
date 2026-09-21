#!/usr/bin/env bash
# hook-tracker-reminder.sh — SessionStart hook. States which board is this repo's default, so the
# agent does not have to infer it from the rule file before it has loaded the rule file.
#
# One line, at session start only. A reminder that fires on every prompt becomes wallpaper and
# stops being read — if you want a recurring nudge, throttle it (see the UserPromptSubmit example
# in .claude/rules/tracker-workflow.md). Never blocks.

set -uo pipefail

# FILL IN: the team and project this repo defaults to.
TEAM="${TRACKER_TEAM:-<TEAM>}"
PROJECT="${TRACKER_PROJECT:-<PROJECT>}"

cat <<MSG
Tracker available — team ${TEAM} -> project ${PROJECT} by default for this repo.
List the project's cards before starting significant work; work from an existing card rather than
opening a duplicate; read the Decisions project before relying on a choice; archive a card when it
is really done. State and decisions live there, not in markdown.
Full rule: .claude/rules/tracker-workflow.md
MSG

exit 0
