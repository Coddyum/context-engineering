# The file sommaire

A navigation block at the head of every source file with two or more top-level declarations. Fifteen
lines that let an agent open a 300-line file, read the header, and jump straight to line 30.

It is the most mechanical saving in this repository, and the one people drop first — which is why it
is enforced by a blocking hook rather than left as a convention.

---

## The block

Go:

```go
package service

// SOMMAIRE (lire en premier, sauter directement au bon passage)
//
// | Élément    | Résumé                                       | Ligne |
// |------------|----------------------------------------------|-------|
// | NewService | Creates the service with its dependencies    | 14    |
// | CreateUser | Inserts a user and returns its ID            | 30    |
//
// Fin du sommaire.
// =====================================================================

import (
	...
)
```

TypeScript:

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

> **The marker string is a fixed literal, in French, kept verbatim.** It is a sentinel: the
> `sommaire` skill, `check-sommaire.sh` and `sync-sommaire-lines.sh` all match on it byte for byte.
> Translating it silently breaks all three. Everything around it is in whatever language you write
> the rest of the project in.

---

## Why it pays

An agent that needs `CreateUser` in a 300-line file has two options.

Without the block: read the file. Roughly 3 000–4 000 tokens, of which maybe 300 were relevant. And
it does this again next session, and the session after.

With the block: read fifteen lines, learn that `CreateUser` starts at line 30, read lines 30–70.
Roughly 400 tokens.

The saving is unremarkable on one file. It compounds across every file, every session, for the life
of the codebase — which is what makes it the highest-leverage convention in the set despite being
the least interesting one.

There is a second-order effect worth noting: writing the block forces someone to state, in one
sentence, what each declaration actually does. Declarations that resist that sentence are usually
declarations doing two things.

---

## The threshold, and why handlers count

- **Go**: ≥ 2 top-level `func` or `type` declarations. A method counts as `Type.Method`.
- **TypeScript**: ≥ 2 (top-level exports + `handleXxx` handlers).

The TS threshold includes handlers on purpose. A React file often has one export but composes
several internal pieces — handlers, sub-renders, a dropdown — and those are exactly what someone
navigates to. Counting exports alone would leave the 400-line components, the ones that most need
the block, without one.

Excluded everywhere: generated code (`internal/database/*`, anything with a
`Code generated ... DO NOT EDIT` header), tests, `.d.ts`.

Below the threshold the block is **forbidden**, not optional. A two-line file with a sommaire is
noise, and the guard reports it.

---

## Maintenance

On every creation, change or deletion of a top-level declaration:

1. Update the block in the same edit — add or remove the row, recompute the shifted line numbers.
2. If the file drops below 2 declarations, remove the block.
3. If a new file reaches 2, create it.

Two pieces of tooling carry the mechanical half:

**`scripts/sync-sommaire-lines.sh`** recomputes the "Ligne" column from the real declaration
positions. It never adds or removes a row: if the row count does not match the declaration count,
it reports the file and leaves it untouched. Writing the description of a new declaration, or
dropping the row of one that is gone, is a judgement call and stays with the author. Only the line
numbers, which are pure bookkeeping, are fixed automatically.

**The `sommaire` skill** generates and resynchronises blocks, writing descriptions from what the
code actually does.

---

## The guard, and what it deliberately does not check

`check-sommaire.sh` checks two things: the marker is present, and the table row count equals the
declaration count. Exit 2 on failure, which blocks the edit.

It does **not** judge description quality. A guard that tries to evaluate prose produces false
positives, and a guard with false positives gets disabled — at which point you have no guard at all.
So the split is deliberate: the script owns structure, the agent owns meaning.

The failure mode this leaves open is real — mechanically generated descriptions that restate the
function name:

```
// | CreateUser | Creates a user | 30 |
```

That row costs a line and buys nothing. Both the rule and the skill say so explicitly, and it is
the kind of thing worth catching in the quarterly audit.

---

## Two mechanisms, do not confuse them

| | Code files | Memory and doc files |
| --- | --- | --- |
| Marker | `// SOMMAIRE (...)` | `# SOMMAIRE (...)` |
| Threshold | ≥ 2 declarations | roughly > 80 lines |
| Columns | Élément / Résumé / Ligne | Titre / Résumé / Ligne |
| Enforced by | `PostToolUse` hook | nothing — maintained on request |

Long markdown files get the same treatment for the same reason. It is simply not worth a hook.

---

## Files

- Go rule: [`templates/go-backend/.claude/rules/file-sommaire.md`](../templates/go-backend/.claude/rules/file-sommaire.md)
- TS rule: [`templates/next-frontend/.claude/rules/file-sommaire.md`](../templates/next-frontend/.claude/rules/file-sommaire.md)
- Skill: [`templates/go-backend/.claude/skills/sommaire/SKILL.md`](../templates/go-backend/.claude/skills/sommaire/SKILL.md)
- Guards: `scripts/check-sommaire.sh`, `scripts/sync-sommaire-lines.sh` in both templates
