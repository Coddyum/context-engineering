# Rule — naming

Referenced by `CLAUDE.md`.

| Kind | Convention | Example |
| --- | --- | --- |
| Hooks | camelCase prefixed `use` | `useStreamData.ts` |
| Reusable UI components | PascalCase | `Button.tsx`, `Input.tsx` |
| Other component files | kebab-case | `stream-card.tsx` |
| Types & interfaces | PascalCase | `StreamerProfile`, `BentoModule` |

## Semantic naming

Before writing any function, variable, state or file, ask: **is one glance enough to know what
this does?**

- Clear and direct — neither too short (`s`, `item`, `data`, `tmp`) nor biographical.
- State is named for what it holds: `isMenuOpen`, not `open`; `streamTitle`, not `title`.
- A function name describes its action: `fetchUserProfile`, not `getData`; `formatDuration`,
  not `format`.
- If a simple function needs a comment to explain what it does, the split or the name is wrong.
  Fix the name first.
- Applies to files too: `stream-card.tsx`, not `card.tsx`.

> This is a context rule as much as a style one. An agent grepping for `formatDuration` finds
> it; an agent grepping for `format` opens eleven files.
