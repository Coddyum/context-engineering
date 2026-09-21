# SETUP.md — scaffold this architecture (instructions for an AI agent)

You are an AI coding agent (Claude Code, Codex, openCode, …). This repo is an **architecture
blueprint** for a Go hexagonal backend. Your job: turn it into a working, building skeleton — then
hand it to the human to fill the domain. Follow these steps in order. Do not invent business features.

> This blueprint is **skeleton + doctrine + guardrails only**. The domain is project-specific and is
> NOT described here. Your output of this setup is: a compiling `cmd/api` that mounts an example
> feature, with every guardrail wired.

## 0. Prerequisites (check, report if missing — do not auto-install)

- Go 1.26+ · PostgreSQL 17 · `sqlc` · `golang-migrate` (`migrate` CLI) · `jq` (used by hooks) · `python3` (used by `sync-sommaire-lines.sh`).

## 1. Read the doctrine first

- `AGENTS.md` (if you are Codex/openCode) **or** `CLAUDE.md` (if you are Claude Code) — same doctrine.
- `ARCHITECTURE-BLUEPRINT.md` — the millimeter spec. **This is the canonical source for the core
  interfaces and wiring.** Reproduce its §3 (`internal/core/module/module.go`) and §4 (`cmd/api/main.go`) exactly.
- `.claude/rules/` — module-system, feature-structure, code-conventions, file-sommaire, reports.
- Skills you will use: `new-feature` (scaffold a feature), `sql-workflow` (any SQL). Read the `SKILL.md` before acting.

> If the `new-feature` skill and `ARCHITECTURE-BLUEPRINT.md` disagree on the module signature,
> **follow `ARCHITECTURE-BLUEPRINT.md`** — it is the canonical spec.

## 2. Fill the placeholders

Ask the human for two values, then replace everywhere:

- `<PROJECT_NAME>` — the product/repo name. Appears in: `AGENTS.md`, `CLAUDE.md`, `Makefile`, `.claude/memory/*.md`.
- `<module>` — the Go module path (e.g. `github.com/you/proj`). Appears in `go.mod` (you create it) and code samples.

Fill the **Project** section of `AGENTS.md` + `CLAUDE.md` (1–3 sentences) and `CONTEXT.md` priorities from what the human tells you.

## 3. Generate the Go skeleton (from ARCHITECTURE-BLUEPRINT.md)

Create, reproducing the spec exactly:

```
go.mod                              # module <module>; go 1.26
cmd/api/main.go                     # §4 wiring — the ONLY log.Fatal
internal/core/module/module.go      # §3 — Module, CoreServices, FeatureRegistry, ModuleConfig
internal/core/engine/               # module registration loop + root router + global middleware
internal/pkg/{config,database}/     # config.Load (env→struct, fail fast) + DB connect
sql/{migrations,queries,schema}/    # empty dirs, ready
sqlc.yaml                           # schema from sql/migrations, queries from sql/queries, out internal/database
```

Then scaffold ONE example feature with the `new-feature` skill (e.g. `health` or `ping`) so the wiring
is exercised end to end and `cmd/api` builds and mounts it.

## 4. Wire the guardrails

```
chmod +x scripts/*.sh .codex/hooks/*.sh
```

- Claude Code: `.claude/settings.json` is already wired (PostToolUse build/vet + autocommit, SessionStart reports). Skills + memory are auto-discovered.
- Codex: mark the repo **trusted**, start a session from root (loads `AGENTS.md`), approve the hook in `/hooks`. Read `.codex/README.md` — **verify the hook matcher fires on your Codex version.**
- Other agents: they read `AGENTS.md`; `make lint` / `make check` are the deterministic guardrails regardless of agent.

## 5. Verify (a task is not done until these pass)

```
go build ./...
go vet ./...
make check            # vet + tests
make lint             # golangci-lint + structural guards
```

## Autonomy & conventions (reminders)

- You are **autonomous in dev/sandbox**: run dev migrations (`make up-dev`), `sqlc generate`, tests, tooling yourself.
- **Production is human**: `make up-prod`, prod deploy/DB, and merging/pushing to `main` are forbidden unless the
  human explicitly authorizes it — the `block-prod` hook enforces prod + irreversible git.
- Never hand-edit `internal/database/*` (generated). Never put SQL in a `.go`. Never import one feature from another.
- Reports the human asks for → `docs/rapport/<name>.md`, **in French, caveman OFF** (git-ignored; list with `scripts/reports.sh list`).
- Checkpoint commits happen automatically (autocommit hook). Do not `git push` or open a PR without an explicit request.
