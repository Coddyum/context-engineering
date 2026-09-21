# templates

Working files, not examples. Everything in here runs in production on projects that are not this
one.

The folders are independent: the guards do not need the memory, the memory does not need the
blueprint, and none of it requires Claude Code specifically.

> These folders are meant to be copied *into* a project, so they deliberately contain no `README.md`
> of their own — that slot belongs to your project. This file is the map.

---

## [`go-backend/`](go-backend/)

A complete Go backend skeleton: hexagonal architecture with a module system, `handler → service →
store → DB` as an absolute flow, contracts-only interface files, features that cannot import each
other.

```
ARCHITECTURE-BLUEPRINT.md   the millimetre spec — the five laws, target tree, core interfaces,
                            feature skeleton, transaction pattern, inter-module protocol, checklist
CLAUDE.md                   Claude Code entry point — slim, routes into the rules
AGENTS.md                   the agent-neutral authority — same doctrine, spelled out further
SETUP.md                    instructions for the agent that scaffolds the repo from this
Makefile                    run, build, check, lint, sqlc, migrations
.claude/rules/              code-conventions · feature-structure · file-sommaire · module-system ·
                            reports · tracker-workflow
.claude/memory/             the 8 registers, as blank templates
.claude/skills/             new-feature · module-interface · sql-workflow · sommaire ·
                            consolidate-memory · quarterly-audit · lead · commit-clean
.agents/skills/             the same skills, at the path Codex and openCode read
.codex/                     Codex config, hooks, and native execpolicy rules
scripts/                    block-prod · check-cross-feature-imports · check-file-size ·
                            check-sommaire · sync-sommaire-lines · hook-go-postedit ·
                            hook-autocommit · hook-session-reports · hook-tracker-reminder ·
                            reports
.claudeignore  .gitignore
```

**Use it:**

```bash
cp -r templates/go-backend/. path/to/your-project/
cd path/to/your-project && chmod +x scripts/*.sh .codex/hooks/*.sh
```

Then hand `SETUP.md` to your agent. It fills the placeholders (`<PROJECT_NAME>`, `<module>`,
`<REPORT_LANGUAGE>`), generates the Go skeleton from the blueprint, scaffolds one example feature
end to end, and verifies that `go build`, `go vet`, `make check` and `make lint` pass.

Then fill `.claude/rules/tracker-workflow.md` — the board map, and the one-home-per-kind-of-information
table — or delete the rule, `scripts/hook-tracker-reminder.sh` and its `SessionStart` entry if this
project has no tracker.

Prerequisites: Go 1.26+, PostgreSQL 17+, `sqlc`, `golang-migrate`, `jq`, `python3`.

---

## [`next-frontend/`](next-frontend/)

The same treatment for a Next.js front end.

```
CLAUDE.md                   entry point — stack table, architecture, rules routing table
AGENTS.md                   agent-neutral authority + the guard table
.claude/rules/              15 files — tracker-workflow · workflow · feature-structure ·
                            components · data-management · api-auth · validation · i18n ·
                            typescript · styling · naming · jsdoc · testing ·
                            general-principles · file-sommaire
.claude/memory/             the same 8 registers
.claude/skills/             frontend-architect + 4 reference files
scripts/                    hook-web-postedit · hook-autocommit · hook-tracker-reminder ·
                            block-dangerous-bash · check-cross-feature-imports · check-file-size ·
                            check-sommaire · check-i18n-parity · check-public-routes ·
                            check-package-manager
scripts/lib/baseline.sh     the baseline helper — tolerate existing debt, refuse new debt
scripts/baseline/           the debt, written down and countable
scripts/expected/           the pinned public-route set
```

**Use it:**

```bash
cp -r templates/next-frontend/. path/to/your-project/
cd path/to/your-project && chmod +x scripts/*.sh scripts/lib/*.sh
```

Then:

1. Fill `<PROJECT_NAME>` and the **Project** section in `CLAUDE.md` and `AGENTS.md`.
2. Fill `scripts/expected/public-routes.txt` from your middleware, and run
   `./scripts/check-public-routes.sh` once to confirm it matches.
3. Leave `scripts/baseline/file-size.txt` empty on a new project. On an existing one, seed it with
   the files that already fail — the list can then only shrink.
4. Adjust the locale path in `check-i18n-parity.sh` if yours is not `src/i18n/locales/`.
5. Fill `.claude/rules/tracker-workflow.md` (board map, one home per kind of information) and set
   `TRACKER_TEAM` / `TRACKER_PROJECT` in `scripts/hook-tracker-reminder.sh` — or delete both and the
   `SessionStart` entry if this project has no tracker.

The post-edit hook runs no build and no test by design — see
[docs/guardrails.md](../docs/guardrails.md) for why.

---

## [`shared/`](shared/)

Machine-level, not repo-level: the 14-day package quarantine. A `PreToolUse` hook that refuses any
install of a version published less than 14 days ago (and refuses npm / npx / yarn / bun outright),
plus the pnpm config that makes the safe resolution the default one.

User-level on purpose: a per-repo hook protects the repos you remembered to configure, which is not
the set that matters.

Install instructions in [`shared/README.md`](shared/README.md).

---

## Placeholders

| Token | Means | Appears in |
| --- | --- | --- |
| `<PROJECT_NAME>` | the product or repo name | `CLAUDE.md`, `AGENTS.md`, `Makefile`, every memory register |
| `<module>` | the Go module path, e.g. `github.com/you/proj` | `go.mod`, blueprint code samples |
| `<name>` | a feature name | blueprint and skill code samples |
| `<REPORT_LANGUAGE>` | the language reports are written in | `.claude/rules/reports.md`, `scripts/reports.sh` |
| `<TEAM>` / `<PROJECT>` | this repo's default board and project | `scripts/hook-tracker-reminder.sh`, `.claude/rules/tracker-workflow.md` |

---

## What the guards need

Both templates call their guards from Claude Code hooks **and** from `make` / CI. That is
deliberate: a guard that only exists inside one agent's hook system disappears the moment someone
uses a different tool.

If your agent's hooks do not fire, the guards still hold — run them.
