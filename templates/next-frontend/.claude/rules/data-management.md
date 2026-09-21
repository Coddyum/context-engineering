# Rule — data management

Referenced by `CLAUDE.md`. Full contract: the `frontend-architect` skill's
`references/data-fetching-contract.md`.

- **TanStack Query is mandatory** for anything coming from the backend. Never `useState` +
  `useEffect` for fetching — that pattern re-fetches on every mount, races itself, and caches
  nothing.
- Three layers, each knowing only the one below: `services/` (HTTP + Zod) → `hooks/` (query,
  cache, mutations) → components (render).
- Query keys are typed arrays from a central object, never bare strings. `["users"]` and
  `"users"` are different cache entries, and you will not notice.
- `staleTime` is always set explicitly. The default is 0, which means every mount refetches.
- **Optimistic updates first** on anything the user initiates: paint the change, roll back on
  failure. Waiting for the server to confirm a checkbox is the difference between an app that
  feels alive and one that feels remote.
- Keep React Context to the strict minimum. Most Context is prop-drilling avoidance wearing a
  costume, and it re-renders the whole subtree.
