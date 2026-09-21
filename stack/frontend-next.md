# Frontend stack — Next.js

The deliberate shape: **Next.js App Router + TypeScript strict + Tailwind + TanStack Query + Zod +
i18next + Vitest, on pnpm.**

Same filter as the backend document: this is the architectural layer, the set that is identical
across every front end in the reference projects. Feature libraries — a rich-text editor, a 3D
renderer, a drag-and-drop grid, a video encoder — are out. They belong to a product.

---

## The core

| Concern | Choice | Why this one |
| --- | --- | --- |
| Framework | **Next.js**, App Router | RSC by default is the right default: the interactive part of an app is usually small, and shipping only that part is worth a lot |
| Language | **TypeScript**, `strict: true` | plus `noUncheckedIndexedAccess`. See below |
| Styling | **Tailwind CSS** | colocated, no naming problem, no dead CSS. Plain CSS only for what Tailwind does not cover cleanly |
| Class merging | **`tailwind-merge`** | string concatenation happily produces `px-2 px-4` and leaves you guessing which one won |
| Server state | **TanStack Query** | mandatory. Cache, dedup, retry, invalidation, optimistic updates |
| Validation | **Zod** | mandatory at every external boundary |
| i18n | **i18next** + `react-i18next` | zero hardcoded user-facing text |
| Tests | **Vitest** + `@testing-library/react` | fast, ESM-native, same config shape as Vite |
| Package manager | **pnpm**, exclusively | see [supply-chain.md](../docs/supply-chain.md) |

## The small, unglamorous rest

| Concern | Choice |
| --- | --- |
| Icons | `lucide-react` |
| Conditional classes | `classnames` (or `clsx`) |
| Theme (dark/light) | `next-themes` |
| Animation | `motion` |
| Toasts | `react-hot-toast` |
| Lint | `eslint` + `eslint-config-next` |
| Format | `prettier`, run through `lint-staged` on a `husky` pre-commit hook |

**No UI kit by default.** No Radix, no shadcn/ui. Not because they are bad — because adopting a
component library is an architecture decision with a long tail (their styling model, their
accessibility assumptions, their upgrade cadence), and it should be made explicitly per project
rather than inherited from a template.

---

## The three rules that carry the most weight

### TanStack Query, never `useState` + `useEffect`

The hand-rolled version re-fetches on every mount, races itself when props change, caches nothing,
and duplicates server state into client state where the two drift.

Three layers, each knowing only the one below it:

```
components          ← render. Never calls fetch.
   ↑
hooks               ← TanStack Query. Cache, loading, mutations, optimistic updates.
   ↑
services            ← HTTP + Zod parse. No React, no hooks, no state.
```

Two conventions that prevent the usual failures:

- **Query keys are typed arrays from a central object**, never bare strings. `["users"]` and
  `"users"` are different cache entries and you will not notice.
- **`staleTime` is always set explicitly.** The default is 0, which means every mount refetches.

**Optimistic updates first** on anything the user initiates: paint the change, roll back on failure.
Waiting for the server to confirm a checkbox is the difference between an app that feels alive and
one that feels remote.

### Zod at every boundary, never `as`

```ts
const user = data as User          // ❌ runtime bomb with a type-safe fuse
const user = UserSchema.parse(raw) // ✅
```

`as User` satisfies the compiler and crashes three components deep on a field the API renamed last
week. `z.infer<typeof Schema>` makes the type flow *from* the schema, so there is exactly one
declaration to keep correct instead of two that drift.

`.parse()` for data whose source you control — it throws, and you want it to. `.safeParse()` for
user input — you want to render the error, not crash.

### TypeScript as a design tool

- `strict: true`, and `noUncheckedIndexedAccess: true`. The second is the one people skip:
  `array[0]` is `T | undefined`, and pretending otherwise is how a runtime crash gets typed as
  safe.
- **Zero `any`.** `unknown` plus a narrowing check. `as X` only at a boundary you have just
  validated.
- **Branded types on IDs.** Two `string`s are interchangeable; `UserId` and `PostId` are not, and
  the compiler catches the swap the reviewer would not.
- **Discriminated unions instead of boolean soup.** Four booleans describe sixteen states, of which
  twelve are impossible. A `status` union describes four, all reachable, and the compiler enforces
  exhaustive handling.

Full reference:
[`typescript-standards.md`](../templates/next-frontend/.claude/skills/frontend-architect/references/typescript-standards.md).

---

## Project shape

```
src/
├── app/            Next.js App Router — routes only, no business logic
├── features/       one folder per feature, self-contained
│   └── <name>/{components,hooks,api,types.ts,index.ts}
├── components/
│   ├── ui/         primitives — zero business logic, could ship as a package
│   └── shared/     composites — used by 2+ features, no domain state
├── hooks/          genuinely global hooks only
├── lib/            pure utilities, zero React
├── queries/        shared TanStack Query definitions
├── types/          global types, branded IDs
└── i18n/locales/   fr/, en/ — always added together
```

**A feature never imports another feature** — enforced by
`scripts/check-cross-feature-imports.sh`, blocking on edit. Shared code moves up to `components/`,
`hooks/` or `queries/`.

Components sit in three explicit tiers. The test for tier 1: *could this ship in a public package
and be useful to a completely different app?* A prop like `isAdmin` on a `Badge` is that boundary
breaking. Full taxonomy:
[`component-taxonomy.md`](../templates/next-frontend/.claude/skills/frontend-architect/references/component-taxonomy.md).

## RSC vs client

Push `"use client"` **as far down the tree as possible**. The boundary belongs at the leaves.

```
Does this component use event handlers, hooks, or browser APIs?
├── yes → client
└── no  → RSC (the default)
```

The common anti-pattern is `"use client"` at the top of a route: the whole page becomes a client
bundle, and the server fetch that would have been free is now a waterfall.

`loading.tsx` and `error.tsx` at the root of `app/` are not optional in production. Full reference:
[`next-app-router-patterns.md`](../templates/next-frontend/.claude/skills/frontend-architect/references/next-app-router-patterns.md).

---

## Testing

Vitest in `environment: "node"` **by default**, `jsdom` opted into per file:

```ts
// @vitest-environment jsdom
```

Booting a jsdom costs roughly 3 s per file. On a suite of 157 files that was 386 seconds of pure
setup, for tests that were checking Zod schemas and URL construction. The opt-in is one line, the
failure mode when it is missing is immediate and explicit (`document is not defined`), and it made
the suite usable again.

What deserves a test: pure utilities, Zod schemas, API wrappers (URL, method, body, parse, *every*
error branch), hooks with branching or derivation, reducers and registries. What does not:
presentational components, pure types, pass-through hooks, re-export files.

Do not chase line coverage. Cover use cases: happy path plus each business branch.

---

## Version policy

Every dependency **pinned exactly**, no ranges. The 14-day quarantine is enforced automatically here
— pnpm's `minimumReleaseAge` plus the `PreToolUse` hook. See
[supply-chain.md](../docs/supply-chain.md).

---

## The auditor

[`frontend-architect`](../templates/next-frontend/.claude/skills/frontend-architect/) is a skill
that reviews a Next.js codebase across seven axes — folder structure and module graph, rendering
strategy, TypeScript health, data fetching, component taxonomy, state management, toolchain — and
produces a phased refactor roadmap rather than a rewrite proposal.

Four reference files sit beside it, loaded only when an axis needs depth.
