# Rule — styling

Referenced by `CLAUDE.md`.

- **Tailwind first.**
- Plain CSS only for something Tailwind does not cover cleanly.
- Conditional class merging through `tailwind-merge` — never string concatenation, which happily
  produces `px-2 px-4` and leaves you guessing which one won.
