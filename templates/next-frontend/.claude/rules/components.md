# Rule — React components

Referenced by `CLAUDE.md`. Taxonomy detail: the `frontend-architect` skill's
`references/component-taxonomy.md`.

- Function components only. No class components.
- `.tsx` files **max ~60 lines**. Past that, extract sub-components into their own files and let
  the parent orchestrate.
- One component, one clear responsibility.
- `useMemo` / `useCallback` when there is a measured reason, not by reflex.

## Three tiers, explicit

| Tier | Where | Knows about the domain? |
| --- | --- | --- |
| Primitives (`Button`, `Input`, `Modal`) | `src/components/ui/` | no |
| Composites (`DataTable`, `PageHeader`) | `src/components/shared/` | no |
| Domain (`InvoiceRow`, `UserCard`) | `src/features/<x>/components/` | yes |

A prop like `isAdmin` or `isPremium` on a primitive is the tier boundary breaking. Move the
component, or move the prop.
