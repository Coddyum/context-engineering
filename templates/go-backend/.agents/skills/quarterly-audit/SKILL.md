---
name: quarterly-audit
description: Audits the doctrine, agent instructions, skills and declared stack for drift against the real code. Use when the user asks for a quarterly or rules audit, roughly every 90 days, or before an end-of-quarter consolidation.
---

# Quarterly audit — agents, skills and doctrine

A rule nobody follows is worse than no rule: it costs context on every session and buys no
behaviour. This audit exists to delete those.

## Scope

- `AGENTS.md` and `CLAUDE.md`
- `.agents/skills/*/SKILL.md` and any Claude-only skills still present
- `.claude/rules/`
- `.codex/config.toml`, hooks and execution rules
- `.claude/memory/DRIFT-LOG.md`
- declared versions against `go.mod`, the `Makefile` and the actual code

## Procedure

1. For each skill, check its mandate, trigger, file scope, exit criteria and the validity of the
   sources it cites. If you would not write it today, fix it or delete it.
2. Compare the documented stack against `go.mod`, the `Makefile` and the integrations actually
   present.
3. Check behavioural symmetry across agents: same critical prohibitions, same validations, same DB
   workflow — without duplicating the memory.
4. Read `DRIFT-LOG.md` and decide, for each drift: fix it, promote it into a skill or a systemic
   rule, demote it to contextual, or document that it stands as is.
5. Update `DRIFT-LOG.md`, apply the approved fixes, and set the next audit at +90 days. Flag any
   change to a critical file or a security rule.

## Report

- Skills audited: N (OK / adjusted / removed)
- Agent instructions: consistent, or the gaps found
- Stack: OK, or the corrections made
- Drift log: promotions, demotions, new drifts
- Next audit: YYYY-MM-DD
