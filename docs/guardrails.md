# Guardrails

A rule an agent can skip is a suggestion. A rule that returns exit 2 is a rule.

This is the mechanical layer: hooks that run on every edit and every shell command, scripts that
run from those hooks and equally from a terminal or CI. Nothing here depends on the agent
cooperating.

---

## Why hooks and not review

The expensive failure mode is not the agent making a mistake. It is the agent making a mistake, not
knowing, building three more things on top of it, and being told four turns later. You then pay for
the four turns, the unwinding, and the re-explanation.

A `PostToolUse` hook that exits 2 collapses that into a same-turn correction: the agent sees the
compiler error attached to its own edit, fixes it, and moves on. The conversation never hears about
it.

That is the entire argument. Everything below is detail about making it survive.

---

## The wiring

`.claude/settings.json`, Go backend:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/scripts/block-prod.sh\"" }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/scripts/hook-go-postedit.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/scripts/hook-autocommit.sh\"" }
        ] }
    ],
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/scripts/hook-session-reports.sh\"" }] }
    ]
  }
}
```

Three positions, three jobs:

| Position | Job | Exit code that matters |
| --- | --- | --- |
| `PreToolUse(Bash)` | refuse commands that cannot be undone | 2 = blocked |
| `PostToolUse(Edit\|Write)` | validate what was just written | 2 = blocked, output goes back to the agent |
| `SessionStart` | surface state the agent cannot discover | always 0 |

The hook scripts live in `scripts/`, **not** in `.claude/hooks/`, so the same script runs from
`make lint` and from CI. A guard that only exists inside one agent's hook system is a guard that
disappears the moment someone uses a different tool.

---

## The four guards worth writing first

All four ship in the templates. They share a shape: read files, decide, print something actionable,
exit non-zero.

### `check-cross-feature-imports.sh` — module isolation

Refuses `internal/feature/a` importing `internal/feature/b` (Go), or `@/features/a` importing
`@/features/b` (TS). Everything inter-feature goes through the registry or shared code.

This is the guard with the largest context payoff: it is what makes "read one directory to
understand one feature" true. Without it, understanding a feature means reading its transitive
closure.

### `check-file-size.sh` — 300 lines

Flags source files past the limit, excluding generated code and tests. A file an agent must read in
full to change one function costs its full length on every session that touches it.

### `check-sommaire.sh` — the navigation block

Checks presence and structural sync: marker present, table row count equal to declaration count. It
deliberately does **not** judge description quality — that stays the agent's responsibility. A guard
that tries to evaluate prose produces false positives and gets disabled.

See [file-sommaire.md](file-sommaire.md).

### `block-prod.sh` — the irreversible set

`PreToolUse(Bash)`. Refuses production migrations, anything naming the production database URL,
pushes and merges to `main`, force pushes, `reset --hard`, `clean -fd`.

Dev autonomy is untouched: `make up-dev`, `sqlc generate`, tests and tooling all pass. The point is
not a timid agent — it is making exactly one class of mistake impossible.

**The escape hatch is the interesting part.** Human authorisation means re-running the exact command
prefixed with `ALLOW_PROD=1`:

```bash
ALLOW_PROD=1 make up-prod
```

The agent cannot grant it to itself in any useful way, because the human is the one who types the
approved command. The authorisation is an act, not a flag the agent can reason its way into.

---

## The autocommit hook

`PostToolUse`, and it never blocks. As soon as an edit leaves the code in a viable state — for Go,
`go build ./...` passes — it commits that one file:

```
checkpoint: internal/feature/billing/service/create_invoice.go
```

Not when a feature is finished. On every edit.

The value is not tidy history — it is that **every intermediate state is recoverable**. An agent
that breaks something at 14:31 can be walked back to 14:28 without anyone having remembered to
commit.

Two rules make it safe:

- **Stage only the edited file.** Never `git add -A` — the user's unrelated work-in-progress is
  not yours to commit.
- **Never squash, amend or rewrite checkpoints.** Thirty of them stay thirty. They are the record
  of how the work actually went.

Escape hatch: `export BLUEPRINT_AUTOCOMMIT=0` when you want to group commits by hand.

---

## The rule that keeps hooks alive

**A guard slower than a few seconds gets switched off, and a guard that is off guards nothing.**

This is why the frontend post-edit hook runs no package-manager command, no `tsc`, no build, no
test. A full Next build per keystroke costs tens of seconds and is gone within a day.

What it runs instead is everything establishable by reading files: public-route set, i18n key
parity, file size, cross-feature imports, sommaire. Which turns out to be the part that silently
ships — a translation key missing in one language does not crash, it renders the raw key on a
customer's screen.

Type errors and test failures belong to `pnpm typecheck` and `pnpm test`, run deliberately. They
are loud and immediate when they do run; they do not need a hook.

> If you do want typecheck-on-edit, run it on the single edited file rather than the project, and
> measure before committing to it.

---

## The baseline pattern — introducing a guard to a codebase that fails it

A guard that fails on 36 pre-existing files gets switched off on its first day. So it does not fail
on them:

```
scripts/baseline/file-size.txt      ← the paths that already violated the rule when it landed
scripts/lib/baseline.sh             ← baseline_load / baseline_allows / baseline_verdict
```

Listed paths are tolerated. Anything else fails. **The list is the debt, written down and
countable** — which is already better than the debt being invisible.

The part that makes it more than a mute button: when a listed path stops violating the rule, the
guard reports it as RESOLVED and **fails until the line is deleted.**

```
RESOLVED: src/features/editor/canvas.tsx no longer violates this rule
    -> delete that line from scripts/baseline/file-size.txt
```

The list can only shrink. Debt becomes visibly smaller instead of quietly permanent.

Implementation: [`templates/next-frontend/scripts/lib/baseline.sh`](../templates/next-frontend/scripts/lib/baseline.sh).

---

## Two guards worth stealing outright

### `check-i18n-parity.sh` — every key in every locale

Compares key **paths** across locale files, never values (an untranslated string is a translation
job, not a defect a script can see).

Why it earns a hook: a missing key does not crash. i18next renders the raw key or falls back to
another language, so the bug ships and is found by a user reading the wrong language on a real page.
Silent, cosmetic-looking, and in front of a customer — the worst shape a bug can take.

In the reference project it found a live one the day it was written: a billing key present in `en`
and absent from `fr`, on the billing screen of an annual subscription.

### `check-public-routes.sh` — pinning the auth boundary

Extracts every path literal that `src/middleware.ts` lets through without an auth cookie, and
compares it to a checked-in expected set.

That set *is* the authentication boundary of the front end. Widening it is a security change, and a
security change should never be a side effect of editing a switch statement. Pinning it means
adding a public path requires editing a second file — a deliberate act, on its own line of the
diff, reviewable.

---

## Writing a guard that lasts

From the ones that survived:

1. **Fail closed.** Registry unreachable, file not found, ambiguous parse → refuse. A guard that
   opens when it cannot see is one an attacker only has to blind.
2. **Print the fix, not just the violation.** `-> go through FeatureRegistry.Get("billing")` beats
   `VIOLATION`. The agent acts on the next line, not on your intent.
3. **Take a file argument.** `check-sommaire.sh <file>` for the hook, no argument to scan the repo
   for `make lint`. Same script, two speeds.
4. **Use `git ls-files --cached --others --exclude-standard`.** Without `--others`, git lists
   tracked files only, a freshly written file is invisible, and the guard passes on exactly the
   code it exists to refuse. That failure was found by mutation testing, not by reasoning.
5. **Explain the why in the header comment.** The person most likely to disable your guard at
   2 a.m. is you, and the comment is the only argument that will be in the room.
