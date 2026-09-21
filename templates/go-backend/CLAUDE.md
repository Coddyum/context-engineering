# CLAUDE.md — <PROJECT_NAME>

Claude Code entry point. Same doctrine as `AGENTS.md` (the agent-neutral authority) — the detailed
rules are shared in `.claude/rules/` and the memory in `.claude/memory/`. This file stays slim on
purpose: the detail lives in the rules, not here.

> Replace `<PROJECT_NAME>` and fill the **Project** section. Everything else is settled doctrine.

## Session start

Before any task:

- **Tracker first**: list the cards of the project the task touches, pick up an existing card instead of
  duplicating it, and read the matching **Decisions** cards before relying on a choice. Verify any factual
  claim from a card against the code — the code wins. Detail: `.claude/rules/tracker-workflow.md`.
- Load `.claude/memory/MEMORY.md` (index), then `CONTEXT.md`. Read `DOCTRINE.md` for any structural change.
  Pull `EDR.md` / `BLOCKERS.md` / `LEARNINGS.md` only when the task touches a referenced area.
- Unknown area → `docs/ARCHITECTURE.md` before editing (plus the `zoom-out` skill if installed — see Skills below).
- Check `git status --short` first; never overwrite the user's uncommitted changes.

## Project

> **FILL IN.** One to three sentences: what the product does, for whom, the scope of this repo.

## Stack

Go 1.26 · PostgreSQL 17 · `net/http` (stdlib) · sqlc · golang-migrate. No ORM, no HTTP framework, no `func init()`.

## Architecture — invariant summary

Hexagonal + module system. Data flow is absolute:

```text
handler → service → store → DB
```

| Layer | May access | Forbidden |
| --- | --- | --- |
| handler | service only | store, `*database.Queries`, `*sql.DB` |
| service | store (via interface) | `*database.Queries`, `*sql.DB` directly |
| store | `*database.Queries` | business logic, HTTP calls |

Every feature is `handler/` + `service/` + `store/`; `service.go` and `store.go` are contracts only.
Detail: `.claude/rules/module-system.md`, `feature-structure.md`. Skeleton: `ARCHITECTURE-BLUEPRINT.md`.

## File sommaire

Every `.go` with ≥ 2 top-level declarations carries the `// SOMMAIRE` block. Generate/update with the
`sommaire` skill; the `PostToolUse` hook enforces it. Detail: `.claude/rules/file-sommaire.md`.

## Database — dev autonomous, prod human

Write migrations/queries, update `sql/schema/`, and run `make up-dev` + `sqlc generate` yourself in
dev/sandbox. Never hand-edit `internal/database/*` (generated) and never put SQL in a `.go`. **Production
(`make up-prod`, prod deploy/DB) is human-only unless explicitly authorized** — the `block-prod` hook
enforces it. See the `sql-workflow` skill and the Database section of `AGENTS.md`.

## Conventions & security

Idiomatic Go, wrapped errors, `log.Fatal` only in `main.go`. Fail-closed security; never read/print/commit
`.env`. Detail: `.claude/rules/code-conventions.md` + the Security section of `AGENTS.md`.

## Reports

Report requests → `docs/rapport/<name>.md`, **in French, caveman OFF**. Git-ignored: find them with
`scripts/reports.sh list`, not `rg`. Detail: `.claude/rules/reports.md`.

## State, memory & guardrails

State, tasks and decisions live on the **tracker**, not in markdown: keep the card current while working, set
`review` when the human must validate, archive when really done, and record any decision in the **Decisions**
project. One home per kind of information — two places that both claim to hold the state means neither does.
Detail: `.claude/rules/tracker-workflow.md`.

Shared registers in `.claude/memory/` (routing: decision→EDR, learning→LEARNINGS, >30-min friction→BLOCKERS,
session→ITERATION_LOG, drift→DRIFT-LOG). Close-out ritual at the end of a significant session; `consolidate-memory`
/ `quarterly-audit` to maintain. `PostToolUse` hook runs `go build` + `go vet` + guardrails and blocks on
failure. `make check` = vet + tests; `make lint` = golangci-lint + structural guards. A task is never done
if build, vet or tests fail, or a `// SOMMAIRE` is missing/desynced.

## Skills — when to use

Skills live in `.claude/skills/` (and `.agents/skills/`, shared with Codex/openCode). Full routing table:
`AGENTS.md` → "Skills and routing". Shipped here: `new-feature` (new `internal/feature/<name>`),
`module-interface` (inter-feature dep), `sql-workflow` (any SQL), `sommaire`, `consolidate-memory` /
`quarterly-audit`, `lead`, `commit-clean`.

The general engineering skills this doctrine also assumes — `tdd`, `diagnose`, `zoom-out`, `grill-me` /
`grill-with-docs`, `handoff` — come from https://github.com/mattpocock/skills and are **not** bundled
here. Install them there, then run `setup-matt-pocock-skills` once to point them at this repo's issue
tracker and docs. The table in `AGENTS.md` marks which is which.

## What Claude does not do

Keep state, plans or progress in a markdown file instead of the tracker · bury a decision in a card
description · touch production (`make up-prod`, prod deploy/DB) without explicit human authorization · merge/push to `main`
without an explicit request · import a feature from another feature · skip a layer · put implementation in
`service.go`/`store.go` · mix handler and service in one file · modify `internal/core/module/module.go` or the
engine without validation · add external deps unrequested · overwrite the user's changes · `git push` / open a
PR without an explicit request (local checkpoint commits by the autocommit hook are fine) · declare a task done
while build/vet/tests fail.
