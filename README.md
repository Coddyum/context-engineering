# context-engineering

The setup I use to run coding agents on large, long-lived projects: how the doctrine is written,
where the memory lives, which guardrails are mechanical, and which architectures make a codebase
cheap for an agent to work in.

The organising idea, and the reason this exists as one repository rather than a gist:

> **An agent's cost is set by what it has to read, not by what it writes.**

Output is a rounding error. A substantial change is maybe two thousand tokens of diff. Getting to
the point where the agent can write those two thousand tokens *correctly* can cost fifty thousand —
reading the wrong files, re-reading files it already read, re-deriving a decision made three weeks
ago, exploring a directory it should never have opened.

Everything here is some version of one move: **write it down once, in the place the agent will
look.**

---

## What is in here

Two things, kept separate on purpose.

**[`docs/`](docs/) — the reasoning.** Why the memory is an index rather than a file, why rules are
split by theme, why a guard that takes ten seconds is a guard that gets deleted. Agent-neutral and
stack-neutral; most of it applies whatever you are building with.

**[`templates/`](templates/) — the working files.** Copy-paste-ready configuration: hooks, guard
scripts, rule files, memory registers, skills, and a complete Go architecture blueprint. Every file
here runs in production on projects that are not this one.

---

## Start here

| If you want | Read |
| --- | --- |
| The whole argument, and where every lever fits | **[docs/token-economy.md](docs/token-economy.md)** |
| A memory that routes instead of loading | [docs/memory.md](docs/memory.md) |
| A slim `CLAUDE.md` and a library of rules loaded on demand | [docs/rules.md](docs/rules.md) |
| Hooks that block, and how to write one that survives a month | [docs/guardrails.md](docs/guardrails.md) |
| The navigation block that makes big files cheap to read | [docs/file-sommaire.md](docs/file-sommaire.md) |
| Which skills are mine, which are borrowed, and how to tell | [docs/skills.md](docs/skills.md) |
| Running one doctrine across Claude Code, Codex and others | [docs/multi-agent.md](docs/multi-agent.md) |
| The tracker as the project's state, and the four levels that must not mix | [docs/task-tracking.md](docs/task-tracking.md) |
| The 14-day package quarantine, and why it fails closed | [docs/supply-chain.md](docs/supply-chain.md) |

Stack choices, and the reasoning behind each:

- [stack/backend-go.md](stack/backend-go.md) — Go, `net/http`, PostgreSQL, sqlc, golang-migrate. No
  ORM, no framework, no `func init()`.
- [stack/frontend-next.md](stack/frontend-next.md) — Next.js App Router, TypeScript strict,
  Tailwind, TanStack Query, Zod, i18next, Vitest, pnpm.
- [stack/infrastructure.md](stack/infrastructure.md) — database workflow, CI, release flow, and the
  production boundary.

---

## The seven levers, in one screen

1. **A memory that routes.** `MEMORY.md` is ~1 KB of pointers, loaded every session. The eight
   registers behind it are loaded only when the task touches them. Never move content into the
   index.
2. **Rules split by theme.** `CLAUDE.md` stays slim and carries a routing table.
   `.claude/rules/<theme>.md` is loaded by relevance. Fourteen rule files, two read per session.
3. **A file sommaire.** A fifteen-line navigation block at the head of every file with two or more
   declarations. Read the header, jump to line 30 — instead of reading the file to find out what is
   in it.
4. **Architecture with hard boundaries.** A feature that cannot import a sibling is a feature you
   can understand by reading one directory. Enforced by a blocking script, not by review.
5. **Mechanical feedback.** A `PostToolUse` hook that exits 2 turns a four-turn repair loop into a
   same-turn correction. The conversation never hears about it.
6. **A task tracker as external memory.** The same routing architecture as lever 1, applied to the
   project's live state: agents work the same board the human reads, so "where was I?" is one card
   and "why is it like this?" is one card in a Decisions project that is never archived. Four
   levels — session todo, tracker, memory registers, design docs — each answering a different
   question, never two answering the same one.
7. **Output discipline.** Never paste code into the chat: it is paid for twice and written to the
   file anyway. Compress the prose, never the technical content.

---

## The templates

### [`templates/go-backend/`](templates/go-backend/)

A complete, copy-paste-ready Go backend skeleton: hexagonal architecture with a module system,
`handler → service → store → DB` as an absolute flow, contracts-only interface files, and features
that cannot import each other.

```
ARCHITECTURE-BLUEPRINT.md   the millimetre spec — core interfaces, wiring, feature skeleton
CLAUDE.md / AGENTS.md       two entry points, one doctrine
SETUP.md                    instructions for the agent that scaffolds the repo
.claude/rules/              6 rule files, including the tracker workflow
.claude/memory/             the 8 registers, as blank templates
.claude/skills/             8 skills (mirrored in .agents/skills/)
.codex/                     Codex-native config, hooks and execpolicy
scripts/                    10 guards and hooks — also runnable from make and CI
Makefile
```

Hand `SETUP.md` to an agent and it scaffolds a compiling skeleton with every guardrail wired.

### [`templates/next-frontend/`](templates/next-frontend/)

The same treatment for a Next.js front end: 15 rule files, the 8 memory registers, the
`frontend-architect` skill with its four references, and 8 static guards wired to a post-edit hook
that deliberately runs no build.

### [`templates/shared/`](templates/shared/)

Machine-level, not repo-level. The 14-day package quarantine: a `PreToolUse` hook that refuses any
install of a version younger than 14 days (and refuses npm / npx / yarn / bun outright), plus the
pnpm config that makes the safe resolution the default one.

---

## What this is not

Worth being direct, because the alternative is implying things that are not true.

- **Not a benchmark.** No number here is measured. The mechanisms are arithmetic — a 1 KB index
  instead of a 40 KB file is a 39 KB saving, every session — but the aggregate depends entirely on
  your codebase and your task mix. Measure your own.
- **Not free.** Sommaire blocks, register hygiene and split rules are real work. They pay back over
  repeated sessions on a long-lived codebase. On a weekend project they do not.
- **Not finished.** The package quarantine has no automatic guard for Python or Go. Some rules in
  here will be wrong in six months — that is what `DRIFT-LOG.md` and the quarterly audit exist for.
- **Not universal.** One project in the reference set migrated most of its registers into a task
  tracker and kept only two locally, because that was genuinely better for how it worked. Take the
  reasoning, not the file list.

---

## Credit where it is due

A significant part of the day-to-day skill set — `tdd`, `diagnose`, `zoom-out`, `grill-me`,
`prototype`, `triage`, `to-prd`, `to-issues`, `improve-codebase-architecture`, `write-a-skill`,
`handoff` — comes from **[mattpocock/skills](https://github.com/mattpocock/skills)**. Those are
**not** redistributed here: install them from the source. [docs/skills.md](docs/skills.md) covers
which ones I use, what they cover, and how they sit alongside the architecture-specific ones in
this repo.

The TypeScript standards in the `frontend-architect` reference files lean heavily on Matt Pocock's
public work on type-level design.

---

## Using it

There is no install. Read the doc that matches the problem you have, then take the files you want:

```bash
# a Go service, whole skeleton
cp -r templates/go-backend/. path/to/your-project/
# then hand SETUP.md to your agent

# just the memory registers, into an existing repo
cp -r templates/go-backend/.claude/memory path/to/your-project/.claude/

# just the package quarantine, machine-wide
cp templates/shared/hooks/block-fresh-packages.mjs ~/.claude/hooks/
# then merge templates/shared/config/global-settings.json into ~/.claude/settings.json
```

Everything is independent. The guards do not need the memory, the memory does not need the
blueprint, and the blueprint does not need Claude Code specifically.

---

## License

MIT. See [LICENSE](LICENSE).
