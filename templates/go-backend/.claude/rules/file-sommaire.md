# Rule — file header sommaire (.go)

Referenced by `AGENTS.md` / `CLAUDE.md`. Generate/update with the `sommaire` skill.

> The marker string `// SOMMAIRE (...)` is a fixed literal sentinel, kept verbatim (not translated)
> so the `sommaire` skill and the `check-sommaire.sh` / `sync-sommaire-lines.sh` scripts all agree on
> it. Only the surrounding prose is in English.

## Principle

A `.go` file with **≥ 2 top-level declarations** (`func`/`type`) must have, right after `package xxx`,
a `// SOMMAIRE` comment block listing each declaration with a one-sentence description and its line
number. Goal: jump straight to the right passage without re-reading the whole file.

Excluded files: `internal/database/*` (sqlc-generated), files with a `// Code generated ... DO NOT EDIT` header.

## Exact format

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

- Exact start marker: `// SOMMAIRE (lire en premier, sauter directement au bon passage)`.
- End marker: a `// ====...` line (free length, ≥ a few `=`).
- One table row per top-level declaration (func, method `Type.Method`, type).
- "Ligne" column = the **final** line number (after inserting the block, so shifted).
- Description = one short sentence, written from understanding the code, not a mechanical restatement
  of the function name.

## Mandatory maintenance (non-negotiable)

On every creation, modification or deletion of a top-level declaration in a `.go` file:

1. Update the sommaire in the same session (add/remove a row, recompute shifted line numbers — the
   `sync-sommaire-lines.sh` script recomputes the line numbers for you).
2. If the file drops below 2 declarations, remove the sommaire block.
3. If a new file reaches 2 declarations, create the block.

## Automatic guardrail

A `PostToolUse` hook (after editing a `.go`) that:

- counts top-level declarations (`grep -cE '^(func |type )'`),
- if ≥ 2: checks the marker is present + the table row count == declaration count,
- fails (exit 2) → blocks.

This guardrail checks presence and structural sync, not the *quality* of the descriptions — that
stays the agent's responsibility on edit.
