---
name: sommaire
description: Generates or resynchronises the mandatory SOMMAIRE block at the head of the project's Go files. Use when a Go file with at least two top-level declarations is created or modified, when the hook reports a missing or desynchronised sommaire, or when the user asks for one.
---

# Go file sommaire

Read `.claude/rules/file-sommaire.md` first for the exact format.

> The marker string is a fixed French literal kept verbatim — this skill, `check-sommaire.sh` and
> `sync-sommaire-lines.sh` all match on it byte for byte. Do not translate it.

## Procedure

1. Resolve the file or directory target. Exclude `internal/database/` and any generated file
   carrying a `DO NOT EDIT` header.
2. Read each file and list its top-level `func` and `type` declarations; name a method
   `Type.Method`.
3. With fewer than two declarations, remove any existing SOMMAIRE block and stop for that file.
4. With two or more declarations:
   - remove the old block before recomputing;
   - write a short description drawn from what the code actually does, never a paraphrase of the
     declaration's name;
   - include exactly one row per declaration;
   - compute the line numbers **after** the block is inserted (they shift);
   - insert the block immediately after `package`, with the prescribed markers.
5. Run `bash scripts/check-sommaire.sh <file>` on every file touched and fix any failure before
   finishing.

Never generate descriptions mechanically. The script checks structure; the agent stays responsible
for the accuracy and usefulness of each summary — a row that restates the function name costs a
line and buys nothing.
