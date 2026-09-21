# templates/shared

Machine-level configuration, not repository-level. These files sit in `~/.claude/` and in the
package manager's global config, and they apply to every project you open.

| File | Goes to | Does what |
| --- | --- | --- |
| `hooks/block-fresh-packages.mjs` | `~/.claude/hooks/` | refuses any install of a package version younger than 14 days, and refuses npm / npx / yarn / bun outright |
| `config/global-settings.json` | `~/.claude/settings.json` | wires that hook on `PreToolUse(Bash)` |
| `config/pnpm-config.yaml` | `~/Library/Preferences/pnpm/config.yaml` | makes pnpm resolve to sufficiently-old versions by itself, pinned exactly |
| `config/global-CLAUDE.md` | `~/.claude/CLAUDE.md` | the written rule behind all three |

## Why user-level and not per-repo

A per-repo hook protects the repos you remembered to configure. That is not the set that matters:
the risky install is the one you run in a scratch directory at 23:40 while chasing something else.

## Install

```bash
mkdir -p ~/.claude/hooks
cp hooks/block-fresh-packages.mjs ~/.claude/hooks/
chmod +x ~/.claude/hooks/block-fresh-packages.mjs
# merge config/global-settings.json into your existing ~/.claude/settings.json
# merge config/global-CLAUDE.md into your existing ~/.claude/CLAUDE.md
cp config/pnpm-config.yaml ~/Library/Preferences/pnpm/config.yaml   # macOS
```

Check it fires:

```bash
echo '{"tool_input":{"command":"npm install left-pad"},"cwd":"/tmp"}' \
  | node ~/.claude/hooks/block-fresh-packages.mjs; echo "exit=$?"   # expect exit=2
```

## The one thing to keep

It **fails closed**. Registry unreachable, no publish date, version missing — all refused, not
waved through. A guard that opens when it cannot see is a guard an attacker only has to blind.
