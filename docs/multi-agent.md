# One doctrine, several agents

Claude Code reads `CLAUDE.md`. Codex and openCode read `AGENTS.md`. Others read something else. The
temptation is to write the doctrine twice, and then maintain two copies that diverge within a month
— usually on exactly the rule that mattered.

The arrangement here: **two entry points, one body of rules, one memory.**

---

## The mapping

| Claude Code | Codex / openCode | Shared? |
| --- | --- | --- |
| `CLAUDE.md` | `AGENTS.md` | no — two entry points, same doctrine |
| `.claude/settings.json` | `.codex/config.toml` + `.codex/hooks.json` | no — different formats |
| `.claude/hooks/` | `.codex/hooks/` | both call `scripts/` |
| `.claude/skills/` | `.agents/skills/` | same content, mirrored |
| `.claude/rules/` | `.claude/rules/` | **yes — one copy, `AGENTS.md` points at it** |
| `.claude/memory/` | `.claude/memory/` | **yes — one copy, one source of truth** |

The path `.claude/rules/` looks Claude-specific and is not. It is simply where the rules live;
`AGENTS.md` sends every other agent to the same files. Renaming it to something neutral would be
tidier and would break every existing reference — not worth it.

**Never fork the memory.** Two agents with two memories is two projects. The registers are the
written source of truth for every agent in the repo, and `consolidate-memory` assumes there is one
of them.

---

## The two entry points differ in framing, not in content

`CLAUDE.md` is slim: the invariants, a map, a routing table into the rules, and the list of things
the agent does not do. It leans on Claude Code's own behaviours — skills are auto-discovered,
`settings.json` is already wired.

`AGENTS.md` is the **agent-neutral authority**. It spells out more, because it cannot assume a hook
system is present at all:

> They run from the Claude Code hooks, and they run the same way from a shell or from CI. An agent
> whose hooks do not fire is still bound by them — run them.

That sentence is the load-bearing one. Which is why the guards live in `scripts/` rather than inside
any agent's hook directory: `make lint` and `make check` enforce the same rules deterministically,
whoever is driving.

---

## Codex specifics

[`templates/go-backend/.codex/`](../templates/go-backend/.codex/) carries the native layer.

**`config.toml`** — deliberately sets neither model nor personality; user preferences stay in
charge. It sets the approval policy, the sandbox mode, and tells Codex to fall back to `CLAUDE.md`
if `AGENTS.md` is absent.

**`rules/prod.rules`** — Codex's native execpolicy, which is the reliable half of the production
guard:

```python
prefix_rule(
    pattern = ["make", "up-prod"],
    decision = "forbidden",
    justification = "Production migrations are human-only.",
    match = ["make up-prod"],
)
```

**`hooks.json`** — calls the same `scripts/block-prod.sh` and a Codex-flavoured post-edit hook.

### The honest caveat

Codex's edit-tool name and hook schema have changed across versions. The `PostToolUse` matcher
(`"apply_patch|Edit|Write"`) is best-effort and may not match your build. The `.codex/README.md`
says so, and says how to check:

```bash
codex --strict-config features list
# then make a trivial .go edit in a Codex session and confirm the hook status message appears
```

If it does not fire, the doctrine still holds — `AGENTS.md` is read natively, and `make lint` /
`make check` are deterministic. That is the design: **the hook is the fast path, not the only
path.**

---

## Behavioural symmetry is an audit item

The `quarterly-audit` skill checks it explicitly:

> Check behavioural symmetry across agents: same critical prohibitions, same validations, same DB
> workflow — without duplicating the memory.

Drift here is quiet and expensive. `CLAUDE.md` gains a rule, `AGENTS.md` does not, and six weeks
later a Codex session does the thing the Claude sessions stopped doing.

---

## What does not need duplicating

Worth being explicit, because the instinct is to mirror everything:

- **The memory.** One copy. Never a `.codex/memory/`.
- **The rules.** One copy, referenced from both entry points.
- **The guards.** One copy in `scripts/`, called from both hook systems and from `make`.

Only the **wiring** is per-agent: which file is the entry point, which config format, which hook
schema. That is a handful of small files, and it is the only part that should ever exist twice.
