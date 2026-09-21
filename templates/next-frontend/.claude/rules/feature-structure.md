# Rule — feature structure

Referenced by `CLAUDE.md`.

## Layout

```
src/
├── app/            Next.js App Router — routes only, no business logic
├── features/       THE important directory — one folder per feature, self-contained
│   └── <name>/
│       ├── components/   feature-scoped components
│       ├── hooks/        feature-scoped hooks
│       ├── api/          feature-scoped API functions
│       ├── types.ts
│       └── index.ts      the feature's public API — explicit exports only
├── components/
│   ├── ui/         primitives (design-system layer)
│   └── shared/     cross-feature composites
├── hooks/          genuinely global hooks only
├── lib/            pure utilities, zero React
├── queries/        shared TanStack Query definitions
├── types/          global types, branded IDs
└── i18n/locales/   translation files
```

## The one hard rule

**A feature never imports another feature.** Enforced by
`scripts/check-cross-feature-imports.sh`, which blocks on edit.

Shared code goes to `src/components/`, `src/hooks/` or `src/queries/`. If two features genuinely
need the same domain logic, that logic was never feature-scoped — promote it.

> Business logic living in `app/` pages is the other common drift. A `page.tsx` is a thin shell
> that imports a feature; when it starts holding state and fetching, the feature boundary has
> quietly moved into the router.
