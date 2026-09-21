---
name: commit-clean
description: Turns local changes into a branch and atomic Conventional Commits, then pushes and opens a PR if asked. Use only when the user explicitly asks to commit, clean up history, push, or open a PR.
---

# Commit clean

## Preconditions

- This skill authorises Git only within the scope explicitly requested.
- Never silently include unrelated user changes.
- Never edit `git config`, use `--no-verify`, add a `Co-Authored-By` trailer, force-push, or
  `git add .`.

## Procedure

1. Read `git status --short`, the staged and unstaged diffs, and recent history. If there is
   nothing, say so and stop.
2. Identify which files belong to the request. If unrelated changes overlap, ask for a decision
   before staging anything.
3. Create a short kebab-case branch only if asked, or if a push or PR requires one.
4. Group files into atomic commits by logical change, not merely by layer. Keep a migration, its
   schema snapshot and its queries in one commit — but never run the migration or `sqlc generate`
   as part of committing.
5. Stage each path explicitly, review the staged diff, then commit as
   `type(scope): description` (`feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`).
6. Push only if asked. Open a PR only if asked, with context, changes, validations run, and the
   points a reviewer should look at. Any remote interaction may need approval first.
7. Summarise: branch, commits, validations, push status, PR link.

> Checkpoint commits written by the autocommit hook are never squashed, amended or rewritten.
> Thirty checkpoints stay thirty — they are the record of how the work actually went.
