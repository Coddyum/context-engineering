# Rule — TypeScript

Referenced by `CLAUDE.md`. Deep dive: the `frontend-architect` skill's
`references/typescript-standards.md`.

- Strong, explicit typing on domain data, props and return values.
- **No over-engineering**: no clever generics for their own sake, no TS abstraction for the
  pleasure of it. If a plain `type` is enough, stop there.
- `strict: true` is not optional. `noUncheckedIndexedAccess` too: `array[0]` is `T | undefined`,
  and pretending otherwise is how a runtime crash gets typed as safe.
- Zero `any`. Reach for `unknown` plus a narrowing check; `as X` only at a boundary you have
  just validated.
- Branded types on IDs (`UserId`, `PostId`). Two `string`s are interchangeable; two brands are
  not, and the compiler catches the swap the reviewer would not.
