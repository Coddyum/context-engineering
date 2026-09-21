# AGENTS.md — <PROJECT_NAME>

Instruction authority for any coding agent in this repo (Codex, openCode, Gemini CLI, …). Claude
Code reads `CLAUDE.md`, which carries the same doctrine and points at the same files — there is no
second doctrine, and no second memory.

## Mandatory session start

0. **Tracker first.** List the cards of the project the task touches, work from an existing card rather
   than opening a duplicate, and read the matching **Decisions** cards before relying on a choice. A card
   can be stale: verify any factual claim against the code. Detail: `.claude/rules/tracker-workflow.md`.
1. Read `.claude/memory/MEMORY.md`, then `.claude/memory/CONTEXT.md`.
2. Read `EDR.md`, `BLOCKERS.md`, `LEARNINGS.md` **only** if the task touches an area they
   reference. `MEMORY.md` is the router.
3. Inspect `git status --short`. Existing changes belong to the user: never overwrite them or fold
   them into another task.

## Stack and architecture

See `CLAUDE.md` — same content, same rules directory. In short: Next.js App Router, TypeScript
strict, Tailwind, TanStack Query, Zod, i18next, Vitest, pnpm only.

`app/` is routes. `features/<name>/` is self-contained and never imports a sibling feature.
Data flows `services → hooks → components`, one direction, no shortcuts.

## Mechanical guardrails (independent of which agent you are)

| Guard | What it refuses |
| --- | --- |
| `scripts/check-cross-feature-imports.sh` | a feature importing another feature |
| `scripts/check-file-size.sh` | source files past the line limit (baselined) |
| `scripts/check-sommaire.sh` | a missing or undersized header sommaire |
| `scripts/check-i18n-parity.sh` | a translation key present in one locale only |
| `scripts/check-public-routes.sh` | the auth boundary moving without a deliberate diff |
| `scripts/check-package-manager.sh` | any npm / npx / yarn / bun invocation |
| `scripts/block-dangerous-bash.sh` | `rm -rf`, force push, `reset --hard`, `clean -f` |

They run from the Claude Code hooks, and they run the same way from a shell or from CI. An agent
whose hooks do not fire is still bound by them — run them.

## Forbidden

- Keep state, plans or progress in a markdown file of the repo instead of the tracker.
- Paste code into the conversation instead of writing it to the file.
- Import one feature from another, or put business logic in an `app/` route.
- Add a dependency, or use any package manager other than pnpm.
- Hardcode user-facing text, or add a key to one locale only.
- Cast an API response (`as User`) instead of parsing it with Zod.
- Silence a lint rule inline.
- Bypass a hook or guard (`--no-verify`, commenting out a step) to force a task through.
- `git push`, merge to `main` or open a PR without an explicit request.
- Declare a task done while typecheck, lint or tests fail.

## Validation before done

`pnpm typecheck`, `pnpm lint`, `pnpm test` — plus `pnpm build` on anything non-trivial. Never
label an error "pre-existing" without reproducing it on the base state.

## State and memory

**State, tasks and decisions live on the tracker** — never in a `PROGRESS.md`, `TODO.md` or plan file, and a
decision never inside a card description. Detail: `.claude/rules/tracker-workflow.md`.

`.claude/memory/` is shared by every agent: decision → `EDR.md`, reusable learning →
`LEARNINGS.md`, friction over 30 minutes that will recur → `BLOCKERS.md`, significant session →
`ITERATION_LOG.md`, rule drift → `DRIFT-LOG.md`. Apply each register's validity test before
writing: an observation is not a learning.
