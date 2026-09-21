# Rule — runtime validation (Zod)

Referenced by `CLAUDE.md`.

- **Zod is mandatory** for every piece of data coming from the backend and every user input.
- Schemas live in `src/lib/schemas/` (or beside the feature's API functions).
- `z.infer<typeof Schema>` — the type flows from the schema, never the other way round. Two
  hand-kept declarations diverge; one inferred type cannot.
- `.parse()` for data you control the source of (it throws, and you want it to).
  `.safeParse()` for user input (you want to render the error, not crash).

> `as User` after a `fetch` is a runtime bomb with a type-safe fuse: the compiler is satisfied,
> and the app crashes three components deep on a field the API renamed last week.
