# Rule — file header sommaire (.ts / .tsx)

Referenced by `CLAUDE.md`. Enforced by `scripts/check-sommaire.sh` via the `PostToolUse` hook.

> The marker string `// SOMMAIRE (...)` is a fixed literal sentinel, kept verbatim (not
> translated) so the guard script and any tooling agree on it byte for byte. Only the surrounding
> prose is in English.

## Principle

A `.ts`/`.tsx` file where **top-level exports + `handleXxx` handlers ≥ 2** carries a `// SOMMAIRE`
block right after the imports: one row per element, a one-sentence description, and its line
number.

The goal is navigation, not documentation. An agent opens the file, reads fifteen lines, and jumps
to line 212 — instead of reading four hundred lines to find one function. On a 300-line component
that is the difference between spending 4 000 tokens and spending 400.

A React file often has a single export but composes several internal pieces — handlers,
sub-renders, a dropdown. Each is worth a row; that is why handlers count towards the threshold.

Excluded: `*.test.*`, `*.spec.*`, `*.d.ts`.

## Exact format

```ts
import { useState } from "react"

// SOMMAIRE (lire en premier, sauter directement au bon passage)
//
// | Section          | Résumé                                          | Ligne |
// |------------------|-------------------------------------------------|-------|
// | StreamCard       | Card shell, owns the open/closed state          | 24    |
// | handleToggle     | Toggles the panel and persists the preference   | 58    |
// | StreamCardFooter | Footer with the live badge and viewer count     | 81    |
//
// Fin du sommaire.
// =====================================================================
```

- Exact start marker: `// SOMMAIRE (lire en premier, sauter directement au bon passage)`.
- End marker: a `// ====...` line.
- One row per top-level export and per `handleXxx` handler.
- "Ligne" = the **final** line number, after the block is inserted (everything shifts down).
- The description is written from reading the code, not from restating the name. A row that says
  "handleToggle — toggles" costs a line and buys nothing.

## Mandatory maintenance

On every creation, change or deletion of a top-level element:

1. Update the sommaire in the same edit.
2. If the file drops below 2 elements, remove the block.
3. If a file reaches 2 elements, create it.

## Two mechanisms, do not confuse them

- **Memory and doc files** (`.claude/memory/*.md`, any `docs/*.md` over ~80 lines): a
  `# SOMMAIRE` block at the top, table `Title | Summary | Line`, maintained on request, no hook.
- **Code** (`.ts` / `.tsx`): the `// SOMMAIRE` block described above, enforced by the hook.
