# Rule — JSDoc

Referenced by `CLAUDE.md`.

Write JSDoc on utilities and hooks whose name alone does not carry the behaviour — typically
detection, transformation, resolution, or anything encoding a non-obvious business rule.

Do **not** write it on React components, or on functions whose name plus types already say
everything. A comment that restates the signature costs tokens on every read and carries nothing.

Expected shape:

- `@param` for each non-trivial argument
- `@returns` describing what comes back, with a concrete example where it helps
