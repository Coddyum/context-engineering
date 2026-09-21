# CLAUDE.md — <PROJECT_NAME>

Claude Code entry point. Same doctrine as `AGENTS.md` (the agent-neutral authority) — the detailed
rules live in `.claude/rules/` and the memory in `.claude/memory/`. This file stays slim on
purpose: detail lives in the rules, and the rules are loaded only when the task touches them.

> Replace `<PROJECT_NAME>` and fill the **Project** section. Everything else is settled doctrine.

## Session start

Before any task:

- **Tracker first**: list the cards of the project the task touches, pick up an existing card rather
  than duplicating it, and read the matching **Decisions** cards before relying on a choice. Verify
  any factual claim from a card against the code — the code wins. Detail:
  `.claude/rules/tracker-workflow.md`.
- Load `.claude/memory/MEMORY.md` (index), then `CONTEXT.md`. Pull `EDR.md` / `BLOCKERS.md` /
  `LEARNINGS.md` only when the task touches a referenced area — the index is the router.
- Unknown area → the `frontend-architect` skill before editing.
- Check `git status --short` first; never overwrite the user's uncommitted changes.

## Project

> **FILL IN.** One to three sentences: what the product does, for whom, the scope of this repo.

## Stack

| Tool | Role |
| --- | --- |
| Next.js (App Router) | framework |
| TypeScript | typing — deliberate, not over-engineered |
| Tailwind CSS | styling |
| `tailwind-merge` | conditional class merging |
| TanStack Query | server state and cache — **mandatory** |
| Zod | validation — **mandatory** on every backend payload and user input |
| i18next | internationalisation — **mandatory**, zero hardcoded text |
| Vitest + Testing Library | unit tests |
| pnpm | the only package manager |

Add what the product needs on top. Do **not** add a UI kit (Radix, shadcn) unless the project
explicitly decided to — a component library is an architecture decision, not a convenience.

## Architecture

`app/` holds routes only. `features/<name>/` is self-contained and **never imports another
feature** — enforced by `scripts/check-cross-feature-imports.sh` on every edit. Shared code goes
to `components/`, `hooks/` or `queries/`. Detail: `.claude/rules/feature-structure.md`.

Components live in three explicit tiers: primitives (`components/ui/`), composites
(`components/shared/`), domain (`features/<x>/components/`).

## Data flow

```text
services (HTTP + Zod)  →  hooks (TanStack Query)  →  components
```

Each layer knows only the one below it. No `fetch` inside a component, no `as Type` after a
response, no `useState` holding server data. Detail: `.claude/rules/data-management.md`.

## File sommaire

Any `.ts`/`.tsx` with ≥ 2 top-level exports + handlers carries the `// SOMMAIRE` block. The
`PostToolUse` hook enforces it. Detail: `.claude/rules/file-sommaire.md`.

## Rules — one file per theme, read on demand

| File | Theme |
| --- | --- |
| `tracker-workflow.md` | the board: session start, cards, decisions, archive |
| `workflow-and-validation.md` | edit workflow, what needs validation |
| `feature-structure.md` | folder layout, the cross-feature rule |
| `components.md` | React components, tiers, size |
| `data-management.md` | TanStack Query, optimistic updates, Context |
| `api-auth.md` | the authenticated fetch wrapper, EventSource |
| `validation.md` | Zod |
| `i18n.md` | i18next, locale parity |
| `typescript.md` | typing, branded types, zero `any` |
| `styling.md` | Tailwind |
| `naming.md` | naming conventions, semantic naming |
| `jsdoc.md` | when a JSDoc earns its place |
| `testing.md` | Vitest — what to test, how |
| `general-principles.md` | DRY, SRP, dependencies, lint |
| `file-sommaire.md` | the header sommaire block |

## State, memory & guardrails

State, tasks and decisions live on the **tracker**, not in markdown — keep the card current, set `review`
when the human must validate, archive when really done, and record decisions in the **Decisions** project.
Detail: `.claude/rules/tracker-workflow.md`.

Registers in `.claude/memory/` (routing: decision → `EDR`, learning → `LEARNINGS`, >30-min
friction → `BLOCKERS`, session → `ITERATION_LOG`, drift → `DRIFT-LOG`). Close-out ritual at the
end of a significant session.

`PreToolUse` blocks destructive shell commands. `PostToolUse` runs the static guards (public
routes, i18n parity, file size, cross-feature imports, sommaire) and blocks on failure, then
checkpoint-commits the edited file. Run `pnpm typecheck` / `pnpm test` / `pnpm build` before
declaring a non-trivial task done.

## What Claude does not do

Keep state, plans or progress in a markdown file instead of the tracker · bury a decision in a card
description · paste code in the chat instead of writing it to the file · import a feature from another feature ·
add a dependency unrequested · touch `next.config` / `tailwind.config` / `tsconfig` without
validation · hardcode user-facing text · cast an API response instead of parsing it · silence a
lint rule inline · `git push` or open a PR without an explicit request · declare a task done while
typecheck, lint or tests fail.
