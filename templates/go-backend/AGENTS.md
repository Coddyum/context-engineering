# AGENTS.md — <PROJECT_NAME>

Instruction authority for any coding agent in this repo (Codex, openCode, Gemini CLI, …). Claude Code
reads `CLAUDE.md`, which imports the same rules — there is no second doctrine. The detailed rules live
in `.claude/rules/` and the shared memory in `.claude/memory/`; both are shared across all agents.

Language: this repo's doctrine is written in **English**. The one exception is **reports** (see below),
written in French.

## Mandatory session start

Before any task:

0. **Tracker first.** List the cards of the project the task touches, work from an existing card rather than
   opening a duplicate, and read the matching **Decisions** cards before relying on a choice. A card can be
   stale: verify any factual claim against the code. Detail: `.claude/rules/tracker-workflow.md`.
1. Read `.claude/memory/MEMORY.md`, then `.claude/memory/CONTEXT.md`.
2. Read `.claude/memory/DOCTRINE.md` for any change to code, architecture, security, database or agent workflow.
3. Load `.claude/memory/EDR.md`, `BLOCKERS.md`, `LEARNINGS.md` only if the task touches a referenced area. `MEMORY.md` is the router.
4. For an unknown area, read `docs/ARCHITECTURE.md` before editing (the `zoom-out` skill, if installed — see "Skills and routing").
5. Inspect `git status --short` before modifying. Existing changes belong to the user: never overwrite them or fold them into another task.

## Project

> **FILL IN.** One to three sentences: what the product does, for whom, the scope of this repo.

## Stack

Go 1.26 · PostgreSQL 17 · `net/http` (stdlib, no HTTP framework) · sqlc · golang-migrate. No ORM.
No `func init()`. No external dependency added unless requested.

## Architecture map

Hexagonal (ports & adapters) + module system.

```text
cmd/api/main.go          entry point; only place allowed to call log.Fatal
internal/core/           engine, Module/CoreServices/FeatureRegistry contracts, shared services
internal/feature/<name>/ business module: handler/ + service/ + store/
internal/store/          global contracts and cross-cutting composition
internal/database/       sqlc-generated code — never edit by hand
internal/pkg/            reusable infra (config, cache, db, crypto, monitoring, …)
sql/                     migrations, sqlc queries, schema snapshot
```

Full skeleton spec: `ARCHITECTURE-BLUEPRINT.md`. Module-system detail: `.claude/rules/module-system.md`.

## Absolute data flow

```text
handler → service → store → DB
```

- A handler calls a service only. It never knows a store, `*database.Queries` or `*sql.DB`.
- A service calls a store via a local interface. It never knows sqlc or `*sql.DB`.
- A store may use `*database.Queries`, but contains no business logic and no HTTP calls.
- For a transaction, the store exposes a `Transactor`; the DB driver never leaks into the service.

No exception. Detail: `.claude/rules/feature-structure.md` + `module-system.md`.

## Mandatory feature structure

Every feature is `handler/` + `service/` + `store/`. `service.go` and `store.go` are **contracts only**
(interface + struct + constructor, zero implementation). A file is a handler or a service, never both.
Middleware is bound once in `module.go`. Use the `new-feature` skill before creating `internal/feature/<name>`.

## Modules and dependencies

A feature never imports another feature — enforced by `scripts/check-cross-feature-imports.sh`. All
inter-feature calls go through `FeatureRegistry.Get("key")` or `CoreServices`. Central interfaces live
in `internal/core/module/module.go`; adding/changing one, the `Module` interface, or the engine is a
critical decision — validate with the user first. Use the `module-interface` skill.

## Database — autonomous in dev, human in prod

The agent is autonomous in **dev / sandbox** (dedicated dev DB, Stripe test mode, …): it writes AND applies.

- Write migration pairs `.up.sql` / `.down.sql` in `sql/migrations/`, queries in `sql/queries/`, update `sql/schema/`.
- Run `make up-dev` and `sqlc generate` yourself.
- Never hand-write `internal/database/*.go` (generated — run `sqlc generate`); never put SQL in a `.go` file.

**Production is human, always.** `make up-prod` and anything touching production (prod DB, prod deploy,
prod data) are forbidden unless the human explicitly authorizes that exact action. The `block-prod` hook
enforces it mechanically — the human's authorization is setting `ALLOW_PROD=1` for the approved command.

Use the `sql-workflow` skill for any new/changed table, column, migration or query.

## Go file sommaire

Every `.go` file with ≥ 2 top-level declarations carries the `// SOMMAIRE` block right after `package`.
Update it in the same edit; run `scripts/check-sommaire.sh <file>`. Use the `sommaire` skill. Format:
`.claude/rules/file-sommaire.md`.

## Go conventions

Wrap every error with what/where/why. `log.Fatal` only in `cmd/api/main.go`. No `panic` in business
logic. `errors.Is`/`errors.As`, small interfaces, table-driven tests. Files > 300 lines (excluding
generated and tests) get split. Detail: `.claude/rules/code-conventions.md`.

## Security

- Any control gated by config is **fail-closed**. A permissive mode requires an explicit flag, never a value inferred from empty/absent config.
- A pub/sub channel (SSE/WS) carrying a per-resource secret is keyed on that exact resource, never only its parent.
- Never read, print, edit or commit `.env` or secrets. Use `.env.example` to understand configuration.
- If an obvious vulnerability appears, add `// BUG TODO FIX: ...` (or a note in `errors.md` if cross-file) and continue — do not go hunting out of scope.

## Reports

When asked for a report (feature analysis, how X works, audit), write it to `docs/rapport/<name>.md`,
**in French, with caveman mode OFF** (full normal prose). The folder is git-ignored, so `rg`/`git grep`
miss it — list it with `scripts/reports.sh list` or `ls docs/rapport/`. Detail: `.claude/rules/reports.md`.

## Autonomy and forbidden actions

Agents are autonomous in **dev / sandbox**: run dev migrations, `sqlc generate`, tests, tools; checkpoint
commits are made automatically by the autocommit hook. Still forbidden (safety and architecture):

- touch **production** — `make up-prod`, prod DB, prod deploy — without explicit human authorization (blocked by the `block-prod` hook; the human sets `ALLOW_PROD=1` to approve a specific command);
- **merge or push to `main`** without an explicit request;
- bypass a hook, rule, test or sandbox (`--no-verify`, disabling a guardrail) to force a task through;
- hand-edit sqlc-generated code, or put SQL in a `.go` file;
- import one feature from another, or skip a handler/service/store layer;
- put implementation in `service.go` or `store.go`, or mix handler and service in one file;
- modify `internal/core/module/module.go`, the `Module` interface or the engine without user validation;
- add an external dependency without a request, or create unrequested helpers/abstractions/refactors;
- keep state, plans or progress in a markdown file of the repo instead of the tracker;
- overwrite or revert the user's existing uncommitted changes;
- `git push` or open a PR without an explicit request (local checkpoint commits are fine);
- declare a task done if required validations fail.

## Validation before done

For any Go change: `go build ./...`, `go vet ./...`, `go test ./...`, `scripts/check-cross-feature-imports.sh`,
`scripts/check-sommaire.sh` on each changed file, `make lint` if available. `make check` covers vet + tests.
Never label an error "pre-existing" without reproducing it on the base state.

## State, memory and traceability

**State, tasks and decisions live on the tracker.** Keep the card current while working, set `review` when the
human must validate, archive when really done, and record every decision as a card in the **Decisions**
project — never buried in a task description, where it disappears when the task is archived. Never keep a
`PROGRESS.md`, `TODO.md` or `NEXT-STEPS.md` beside it. Detail: `.claude/rules/tracker-workflow.md`.

The `.claude/memory/` registers are shared by all agents:

- structural decision → `EDR.md`; reusable learning → `LEARNINGS.md`; > 30-min friction that will
  recur → `BLOCKERS.md`; significant session with a change → `ITERATION_LOG.md`; rule drift → `DRIFT-LOG.md`.

Apply each register's validity test before adding an entry — no entry for a plain observation. Run the
close-out ritual at the end of a significant session (`ITERATION_LOG.md`). Use `consolidate-memory` or
`quarterly-audit` as needed.

## Skills and routing

Skills live in `.agents/skills/` (native for Codex/openCode) and `.claude/skills/` (Claude Code). Read
the triggered `SKILL.md` fully before acting.

| Situation | Skill | Source |
| --- | --- | --- |
| New feature `internal/feature/<name>` | `new-feature` | bundled |
| New inter-feature dependency | `module-interface` | bundled |
| Migration, schema or SQL query | `sql-workflow` | bundled |
| Missing/desynced Go sommaire | `sommaire` | bundled |
| Memory/doctrine audit | `consolidate-memory` / `quarterly-audit` | bundled |
| Lead mode, no code writing | `lead` | bundled |
| Explicitly requested atomic commits / branch / PR | `commit-clean` | bundled |
| Testable code requested in TDD | `tdd` | [mattpocock/skills] |
| Bug/regression, unknown cause | `diagnose` | [mattpocock/skills] |
| Unknown code area | `zoom-out` | [mattpocock/skills] |
| Design to challenge before building | `grill-me` / `grill-with-docs` | [mattpocock/skills] |
| Compacting a session for the next agent | `handoff` | [mattpocock/skills] |

`[mattpocock/skills]` = https://github.com/mattpocock/skills, installed separately and not bundled with
this template. Run its `setup-matt-pocock-skills` once per repo so those skills know this repo's issue
tracker, triage labels and docs layout. If they are not installed, the situations above fall back to
ordinary work — the doctrine and the guards still apply.

If a skill contradicts an explicit user request, the explicit request wins — except the safety and
non-destruction rules above.
