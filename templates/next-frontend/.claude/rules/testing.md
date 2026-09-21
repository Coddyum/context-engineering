# Rule — unit tests

Referenced by `CLAUDE.md`. See also `general-principles.md`.

## Principle

Any new code carrying **testable logic** gets a unit test **in the same session** it was written
— not in a "later" task. A green typecheck does not prove behaviour; a test does. The golden rule
holds: never declare a task done while the test suite is red.

Do not chase line coverage. Cover **use cases**: the happy path plus each business branch (error,
boundary value, empty or invalid input) of every exported function.

## Stack & location

- Vitest + `@testing-library/react` (`renderHook`, `render`, `act`, `waitFor`).
- Tests in `test/`, mirroring `src/` by domain: `test/api/`, `test/lib/`, `test/schemas/`,
  `test/features/`, `test/hooks/`.
- Import source through the `@/` alias — never `../../src`.
- One test file per source module, kebab-case: `create-module.test.ts`.

## Environment: `node` by default, `jsdom` on demand

Run Vitest with `environment: "node"`. Booting a jsdom costs roughly 3 s per file — on a suite of
157 files that was 386 s of pure setup — and buys nothing for an API, schema or utility test.

A file needs `jsdom` the moment it uses `render` / `renderHook`, or touches `document`, `window`,
`localStorage`, `matchMedia`, `ResizeObserver`, `requestAnimationFrame`. In that case, **first
line of the file**, before the imports:

```ts
// @vitest-environment jsdom
```

The symptom when it is missing is immediate and explicit (`document is not defined`). There is no
automatic switch, on purpose.

## Does it deserve a test?

| Deserves one | Do NOT test (noise) |
| --- | --- |
| Pure utility (transform, parse, format, compute) | Purely presentational component |
| Zod schema | Static config with no derivation |
| API wrapper — URL, method, body, parse, errors | Pure type / interface |
| Hook with branching, state, derivation or a side effect | Pass-through hook with no `select` |
| Codec, registry, reducer, store, business-rule resolver | Constants, presets |
| Detection / resolution / patch logic (optimistic updates) | `index.ts` re-export file |

Grey area → test it. A catalogue **with a getter, finder or builder** is tested through that
derivation, not through "the data exists". If a hook genuinely has no branch to assert, note it
and skip — no fragile test for the sake of a number.

## Writing conventions

- `describe` per unit, `it` per case, described by behaviour ("throws INVALID_CREDENTIALS on
  401", not "test login").
- API tests: mock the fetch wrapper, reset in `beforeEach`, assert the exact URL (dynamic id
  segments included), method, serialised body, return shape, and **every** error branch.
- Schemas: valid parse, `safeParse().success === false` on invalid, defaults, coercion, bounds.
- Hooks: `renderHook` + `act`, a real (or minimal) provider when Context is required. Stub
  browser APIs **locally** in the file, restored in `afterEach` — never in the global setup file.
- Type your mocks. A bare `vi.fn()` gives `mock.calls[0]` as an empty tuple, which fails `tsc`
  outside Vitest.

## Do not forget

- A test is code: it goes through the same PostToolUse guards. Type-correct and lint-clean, not
  just green.
- Never modify source code to make it testable without validation first.
