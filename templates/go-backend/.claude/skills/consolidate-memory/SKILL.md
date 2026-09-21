---
name: consolidate-memory
description: Audits and prunes the project's durable memory registers without losing decisions that still hold. Use when the user asks to consolidate or clean the memory, at the end of a long session, or before an important handoff.
---

# Consolidate the memory

## Sources

Read `.claude/memory/MEMORY.md`, then each register it points at. These files are the source of
truth shared by every agent working in the repo; never fork a copy under `.codex/` or elsewhere.

## Procedure

1. Classify every entry:
   - **VALID** — confirmed, structural, still true. Keep.
   - **STALE** — was true, no longer applies. Remove, or replace with what superseded it.
   - **DRIFT** — was wrong from the start. Remove.
   - **TO VERIFY** — check against the code, git history or documentation before deciding.
2. Check that no kept entry contradicts another. Resolve the contradiction and record the decision
   in the register it belongs to.
3. Update the affected registers, then the `MEMORY.md` index. Never move register content into the
   index — the index is a router, and it stays cheap to load precisely because it holds no detail.
4. Never delete a valid historical EDR because the decision has since changed: add a follow-up, or
   a new EDR that supersedes it. A register that hides its own history stops being evidence.

## Report

Report only the counts: VALID kept, STALE removed, DRIFT removed, TO VERIFY remaining.
