# Repo Codex configuration

This layer is the native equivalent of `.claude/settings.json`, Claude hooks and command rules. The
doctrine is **not** duplicated: `AGENTS.md` routes Codex to the same `.claude/rules/` and
`.claude/memory/` documents that Claude Code uses.

## Activation

1. Mark the repo as **trusted** in Codex. Without it, Codex ignores `.codex/config.toml`, `.codex/hooks.json`.
2. Start a new Codex session from the repo root to load `AGENTS.md` and the project config.
3. Open `/hooks`, review and approve the project hook. Codex ties trust to the hook's hash; any future
   edit of the hook asks for re-approval.

## Mapping

| Claude Code | Codex |
| --- | --- |
| `CLAUDE.md` | `AGENTS.md` |
| `.claude/settings.json` | `.codex/config.toml` + `.codex/hooks.json` |
| `.claude/hooks/` | `.codex/hooks/` |
| `.claude/skills/` | `.agents/skills/` (shared native format) |
| `.claude/memory/` | same source of truth, loaded via `AGENTS.md` |

## ⚠️ Verify the hook actually fires (important)

`.codex/hooks.json` uses `"matcher": "apply_patch|Edit|Write"` for `PostToolUse`. Codex's edit-tool
name and hook schema have changed across versions — this matcher is **best-effort** and may not match
your Codex build. Confirm the hook runs before relying on it:

```text
codex --strict-config features list        # confirm hooks are enabled
# then make a trivial .go edit in a Codex session and check the hook status message appears
```

If it does not fire, the real guardrail is still in place: `AGENTS.md` (read natively by Codex) states
the full doctrine, and `make lint` / `make check` enforce it deterministically regardless of agent.

## Autonomy (dev) + production guard

Agents are autonomous in **dev / sandbox**: `make up-dev`, `sqlc generate`, tests and tooling are never
blocked. **Production is human-only.** Two layers enforce it:

- `.codex/rules/prod.rules` (execpolicy, Codex-native and reliable) forbids `make up-prod` and
  irreversible git (`git push --force`, `git reset --hard`, `git clean`).
- the PreToolUse `block-prod` hook (`scripts/block-prod.sh`, shared with Claude) additionally blocks the
  production DB URL and pushes/merges to `main`.

Human authorization = run the exact command prefixed with `ALLOW_PROD=1` (e.g. `ALLOW_PROD=1 make up-prod`).

## Assumed limits

- A single instruction is not a security boundary. Hooks, rules and build validations are the mechanical
  guardrails; project hooks stay disableable by a local user, unlike a managed admin policy.
- Codex `apply_patch` payload parsing in the hook depends on Codex passing the patch in
  `tool_input.command`. If that changes, update `hooks/verify-go-build.sh`.
