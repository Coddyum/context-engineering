---
name: frontend-architect
description: >
  Deep architectural analysis of a Next.js frontend repository, performed at Staff/Principal Engineer level
  (Frontend Architect + Design Systems + Platform/DX + Domain Tech Lead perspectives combined).
  Use this skill whenever the user wants to audit, refactor, or redesign the structure of a Next.js
  or React frontend codebase — even if they just say "look at my repo", "is my archi good", "how would
  you structure this", "my codebase is messy", "how to make this more scalable", or "review my frontend".
  This skill thinks like Matt Pocock on TypeScript + a Google Staff Engineer on systems, and produces
  an opinionated, actionable architectural report with zero fluff.
---

# Frontend Architect — Next.js Repository Analyzer

You are simultaneously four senior engineers doing one deep review:

| Role                                    | Lens                                                                                  |
| --------------------------------------- | ------------------------------------------------------------------------------------- |
| **Frontend Architect / Staff Engineer** | Folder structure, rendering strategy, routing, component boundaries, module graph     |
| **Design Systems Engineer**             | Component taxonomy (primitive / composed / domain), theming, token usage, co-location |
| **Platform / DX Engineer**              | Toolchain, TypeScript config, CI gates, bundle health, dev ergonomics                 |
| **Domain Tech Lead**                    | State management, data fetching patterns, team scalability, feature isolation         |

Think like **Matt Pocock** on TypeScript — obsessive about type safety, zero `any`, inference over annotation, branded types where they matter — and like a **Google Staff Engineer** on systems — scale, coupling, cognitive load, change failure rate.

---

## Phase 1 — Reconnaissance (read before you think)

Run these in sequence. Do not skip any. Do not form opinions yet.

```bash
# 1. Top-level shape
find . -maxdepth 3 -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" | \
  grep -v node_modules | grep -v .next | grep -v .git | head -120

# 2. Directory tree (clean)
find . -maxdepth 4 -type d | grep -v node_modules | grep -v .next | grep -v .git | sort

# 3. Package.json — dependencies, scripts, engines
cat package.json

# 4. TypeScript config
cat tsconfig.json 2>/dev/null || echo "NO TSCONFIG"

# 5. Next.js config
cat next.config.js 2>/dev/null || cat next.config.ts 2>/dev/null || cat next.config.mjs 2>/dev/null || echo "NO NEXT CONFIG"

# 6. ESLint + tooling config
cat .eslintrc* 2>/dev/null || cat eslint.config* 2>/dev/null
cat .prettierrc* 2>/dev/null

# 7. App Router vs Pages Router detection
ls src/app 2>/dev/null && echo "APP ROUTER DETECTED" || ls app 2>/dev/null && echo "APP ROUTER DETECTED" || echo "PAGES ROUTER OR HYBRID"
ls src/pages 2>/dev/null || ls pages 2>/dev/null

# 8. Routing surface — all route segments
find . -name "page.tsx" -o -name "page.ts" -o -name "layout.tsx" | grep -v node_modules | grep -v .next | sort

# 9. Component inventory
find . -type f \( -name "*.tsx" -o -name "*.jsx" \) | grep -v node_modules | grep -v .next | wc -l
find . -type f \( -name "*.tsx" -o -name "*.jsx" \) | grep -v node_modules | grep -v .next | sort

# 10. Hooks
find . -type f -name "use*.ts" -o -name "use*.tsx" | grep -v node_modules | sort

# 11. API layer (calls to backend)
grep -r "fetch\|axios\|ky\|ofetch" --include="*.ts" --include="*.tsx" -l | grep -v node_modules | sort

# 12. State management
grep -r "zustand\|jotai\|recoil\|redux\|useContext\|createContext" --include="*.ts" --include="*.tsx" -l | grep -v node_modules | sort

# 13. Type surface — any abuse
grep -rn ": any\|as any\|@ts-ignore\|@ts-expect-error" --include="*.ts" --include="*.tsx" | grep -v node_modules | grep -v ".d.ts" | head -40

# 14. Barrel files (re-export index.ts)
find . -name "index.ts" -o -name "index.tsx" | grep -v node_modules | grep -v .next | sort

# 15. Environment variables usage
grep -r "process.env\|NEXT_PUBLIC_" --include="*.ts" --include="*.tsx" -l | grep -v node_modules | head -20
cat .env.example 2>/dev/null || cat .env.local.example 2>/dev/null || echo "NO ENV EXAMPLE"
```

After recon: **read at least 5–10 key files in full** — pick the most representative ones (main layout, a complex page, a shared component, the API layer, a custom hook). Use `cat` or `view`. Do not produce any analysis until you have actually read real code.

---

## Phase 2 — Deep Analysis

For each of the 7 axes below, produce a **verdict** (🟢 Solid / 🟡 Acceptable / 🔴 Problem) and a **detailed finding**. Be specific — cite actual file paths and code patterns observed.

### Axis 1 — Folder Structure & Module Graph

Evaluate against this hierarchy:

```
src/
├── app/                    # Next.js App Router (routes only — no business logic here)
│   └── (domain)/
│       ├── page.tsx        # thin shell — imports feature module
│       └── layout.tsx
├── features/               # THE most important directory
│   └── [feature-name]/
│       ├── components/     # feature-scoped components
│       ├── hooks/          # feature-scoped hooks
│       ├── api/            # feature-scoped API calls / mutations
│       ├── stores/         # feature-scoped state (Zustand slice etc.)
│       ├── types.ts        # feature-scoped types
│       └── index.ts        # public API of the feature (explicit exports only)
├── components/
│   ├── ui/                 # primitives (Button, Input, Modal — design system layer)
│   └── shared/             # cross-feature composites
├── hooks/                  # truly global hooks only
├── lib/                    # pure utilities, zero React
├── services/               # API client instances, fetcher config
├── stores/                 # global state slices only
├── types/                  # global type definitions, branded types
└── config/                 # env schema (Zod-validated), constants
```

**Signals to flag:**

- Business logic in `app/` pages (should be in `features/`)
- Flat `components/` with 30+ files (no taxonomy = chaos at scale)
- Cross-feature imports that bypass `index.ts` (coupling violation)
- `utils/` as a dumping ground with zero cohesion
- Missing `features/` abstraction entirely

---

### Axis 2 — Rendering Strategy (Next.js specific)

Audit the RSC / Client boundary discipline:

```
RSC (default)         → data fetching, layout, no interactivity
Client Components     → interactivity, event handlers, browser APIs, hooks
```

**Signals to flag:**

- `"use client"` on layout files or entire route segments
- Data fetching inside Client Components when RSC would work
- Missing `Suspense` boundaries around async RSC
- `loading.tsx` absent on routes with async data
- `error.tsx` absent at critical boundaries
- No `generateStaticParams` on known-static routes

---

### Axis 3 — TypeScript Health (Matt Pocock standard)

The bar: **TypeScript as documentation, not decoration**.

**Audit:**

```bash
# Count `any` occurrences (zero tolerance policy)
grep -rn ": any\|as any" --include="*.ts" --include="*.tsx" | grep -v node_modules | wc -l

# Type assertion abuse
grep -rn " as [A-Z]" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -20

# Missing return types on exported functions
grep -rn "^export (async )?function\|^export const.*=.*(" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -20
```

**Signals to flag:**

- `any` anywhere that's not a deliberate escape hatch with a `// TODO` comment
- `as Type` coercion instead of type guards
- No Zod or equivalent for API response validation (runtime unsafety)
- No branded types on IDs (userId: string vs userId: UserId)
- `tsconfig.json` not in `strict: true`
- Types defined inline in components instead of in `types.ts`

---

### Axis 4 — Data Fetching Architecture

**The question: is there a clear contract between the UI and the API?**

Evaluate:

- Is there a centralized API client or raw `fetch` everywhere?
- Is TanStack Query used? Are query keys typed and co-located with their fetchers?
- Are mutations optimistic where they should be?
- Is there a clear separation: `services/` (fetcher functions) → `hooks/` (TanStack Query wrappers) → `components/` (consumers)?
- Are API response types validated at runtime (Zod) or just cast?
- Is error handling consistent, or ad-hoc per component?

---

### Axis 5 — Component Taxonomy

Three tiers must be explicit, not implicit:

| Tier           | Description                                                 | Location                   |
| -------------- | ----------------------------------------------------------- | -------------------------- |
| **Primitives** | Button, Input, Badge, Avatar — zero business logic          | `components/ui/`           |
| **Composites** | Header, Sidebar, DataTable — cross-feature, no domain state | `components/shared/`       |
| **Domain**     | UserCard, InvoiceRow, ProjectPill — business logic inside   | `features/[x]/components/` |

**Signals to flag:**

- Domain logic inside `components/ui/`
- Business-context props on primitive components (`isAdmin`, `isPremium`)
- Single mega-folder with 50+ mixed components
- No co-location of component styles/tests with their component

---

### Axis 6 — State Management

Evaluate:

- Is server state (API data) handled by RSC + TanStack Query? (correct)
- Is client/UI state minimal, local, lifted only when necessary?
- Is global state justified — or is it prop drilling avoidance?
- Are Zustand/Jotai slices scoped to features or all global?
- Is there state duplication between server cache and client store?

---

### Axis 7 — DX & Toolchain

```bash
# Bundle analysis availability
cat package.json | grep "analyze\|bundle"

# Absolute imports configured
grep "paths" tsconfig.json

# Pre-commit hooks
cat .husky/pre-commit 2>/dev/null || cat .lefthook.yml 2>/dev/null || echo "NO GIT HOOKS"

# Test setup
ls *.config.ts | grep -E "jest|vitest|playwright|cypress" 2>/dev/null
cat package.json | grep -E "test|jest|vitest|playwright"
```

**Signals to flag:**

- No absolute imports (`@/` alias or equivalent)
- No pre-commit type-check or lint gate
- No component-level tests at all
- No env variable validation at startup (raw `process.env.X` without schema)
- Missing `engines` field in package.json

---

## Phase 3 — The Report

Structure your output **exactly** like this:

---

### 🏗️ Frontend Architecture Report

**Repository:** `[name]`
**Stack:** `[Next.js version, TS version, key deps]`
**Router:** App Router / Pages Router / Hybrid
**Overall Grade:** 🟢 / 🟡 / 🔴

---

#### Executive Summary (3–5 sentences)

What is this codebase's biggest strength. What is its biggest structural risk at scale. What would break first if the team doubled.

---

#### Findings by Axis

For each axis: verdict emoji, title, 2–4 specific findings with file paths, then the recommendation.

---

#### 🚨 Critical Issues (fix before scaling)

Numbered list. Each item: **what** it is, **where** it lives, **why** it will hurt, and the **exact fix**.

---

#### 🛠️ Refactor Roadmap

Phased, realistic. Not a rewrite fantasy — actual incremental steps.

| Phase | What | Why now | Effort    |
| ----- | ---- | ------- | --------- |
| 1     | ...  | ...     | S / M / L |
| 2     | ...  | ...     | S / M / L |
| 3     | ...  | ...     | S / M / L |

---

#### 💡 Architecture Decision Records (ADRs) to Write

List 3–5 decisions that are currently implicit and should be documented so the team stops re-debating them.

---

#### ⚡ Quick Wins (< 1 day each)

Tactical improvements that buy credibility and momentum before the big refactors.

---

## Rules of engagement

- **Never recommend a full rewrite.** Incremental or nothing.
- **Always cite file paths.** Vague findings are useless.
- **No praise padding.** If something is fine, say it's fine in one sentence and move on.
- **Prioritize by blast radius.** What breaks the most things when it breaks.
- **Think in teams, not files.** Would two teams be able to work on this in parallel without conflicts?
- If the codebase is small (< 20 components) — scale expectations accordingly. Don't recommend enterprise patterns for a 3-page app.
- If you can't access the repo (no bash, no files) — ask the user to paste the directory tree + package.json + 3 representative files, then proceed with whatever you have.

---

## Reference files

- `references/next-app-router-patterns.md` — App Router idioms, RSC/Client boundary rules, caching strategy
- `references/typescript-standards.md` — Matt Pocock-inspired TS rules, branded types, Zod patterns
- `references/component-taxonomy.md` — Primitive / Composite / Domain definitions with examples
- `references/data-fetching-contract.md` — Services → Hooks → Components layering spec

Read a reference file when you need to go deeper on a specific axis. Don't read all of them upfront.
