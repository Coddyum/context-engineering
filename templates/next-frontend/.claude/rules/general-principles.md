# Rule — general principles

Referenced by `CLAUDE.md`.

- **DRY** — anything that repeats becomes a reusable component or a utility function.
- **Single responsibility** — short functions, focused files.
- Functions **max ~60 lines**. Past that, split.
- Never import a dependency the project does not already have. If a new library looks necessary,
  say so and wait for validation.
- Never silence a lint rule inline (`// eslint-disable`). If a rule is wrong for this project,
  turn it off in the config, with the reason written next to it — a repo-level decision someone
  can review, not a line-level escape nobody will ever revisit.

> The template's original disables `react-hooks/exhaustive-deps` and
> `react-hooks/set-state-in-effect` at the config level: the query library covers fetching,
> `useState` setters are stable, mount effects with `[]` are legitimate, and
> `set-state-in-effect` is too strict for state initialised from URL params (it forces lazy
> initialisers that then hydrate-mismatch). Decide this for your own project — the rule here is
> that the decision is explicit and central.
