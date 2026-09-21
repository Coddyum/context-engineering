# Rules: a slim entry point and a loaded-on-demand library

`CLAUDE.md` is injected into every session. Whatever is in it, you pay for it every time. So the
question for every line is not "is this true?" — it is "does this need to be in front of the agent
on *every* task?"

For most rules the answer is no.

---

## The two-layer split

```
CLAUDE.md                    ← slim. Invariants, a map, and a routing table.
.claude/rules/<theme>.md     ← one file per theme. Loaded when the task touches it.
```

`CLAUDE.md` carries what is true regardless of the task:

- how to start a session (which memory files, in which order)
- what the project is, in three sentences
- the stack
- the architecture invariants — the data flow, the layer table, the one hard boundary
- a **table pointing at the rules**, one line each
- what the agent never does, without asking

Everything else is a rule file. The reference frontend has fifteen, totalling ~43 KB. A typical
session reads two.

Concretely: a task about translations loads `i18n.md` — one kilobyte, entirely about i18n. It does
not load the testing conventions, the Tailwind policy, or the tracker workflow.

---

## Why splitting makes rules stricter

The intuition runs the other way — surely one file everyone reads beats fifteen files nobody
opens? In practice the opposite holds.

A single-file doctrine gets **skimmed**. It is long, most of it is irrelevant to the task at hand,
and the agent (like a human) pattern-matches its way through. The rule about optimistic updates is
in there somewhere, between the naming conventions and the deployment notes.

A one-kilobyte file about exactly the thing you are doing right now gets **read**. All of it.

The routing table in `CLAUDE.md` is what makes this work: it is the agent's index, and it costs
fifteen lines.

---

## Anatomy of a good rule file

From the reference set:

```markdown
# Rule — runtime validation (Zod)

Referenced by `CLAUDE.md`.

- **Zod is mandatory** for every piece of data coming from the backend and every user input.
- Schemas live in `src/lib/schemas/`.
- `z.infer<typeof Schema>` — the type flows from the schema, never the other way round.
- `.parse()` for data you control the source of. `.safeParse()` for user input.

> `as User` after a `fetch` is a runtime bomb with a type-safe fuse: the compiler is satisfied,
> and the app crashes three components deep on a field the API renamed last week.
```

Four properties:

1. **Names its parent.** "Referenced by `CLAUDE.md`" — the rule is not free-floating.
2. **Imperative, not descriptive.** "Zod is mandatory", not "we generally use Zod".
3. **Says where.** A rule an agent cannot act on without a second lookup is half a rule.
4. **Carries the why for the counter-intuitive part.** Not every line needs justification, but
   the one an agent would otherwise work around does. That is what makes it survive contact with
   a deadline.

What to leave out: anything the code already says. A rule file restating the directory structure
that `ls` would show costs tokens and goes stale.

---

## Guard the rules that matter mechanically

A rule and a guard are not the same instrument, and the distinction is worth being deliberate
about.

| | Rule file | Guard script |
| --- | --- | --- |
| Cost | tokens, each session it is loaded | milliseconds, only when it runs |
| Catches | judgement calls | exactly one mechanical property |
| Fails | silently | loudly, exit 2 |

The rules worth spending a *guard* on are the ones that are cheap to check and expensive to miss:
a feature importing a sibling, a translation key in one locale only, a missing sommaire, an npm
invocation. See [guardrails.md](guardrails.md).

The rules that stay prose are the ones needing judgement: what deserves a test, when a component
should be split, whether a name is clear. No script decides those.

Ideally a rule file **names its guard**, so the agent knows the check exists and is not optional:

> Parity is enforced mechanically by `scripts/check-i18n-parity.sh`.

---

## Keeping the set honest

Rules accumulate. Nothing removes them by default, and a rule nobody follows is worse than no rule
— you pay for it on every session and get no behaviour for it.

Two mechanisms:

- **`DRIFT-LOG.md`** records rules that were written down and then ignored. Not to shame anyone —
  to distinguish "the agent missed it" (make it a guard) from "the rule is wrong" (delete it).
- **`quarterly-audit`**, every ~90 days: for each rule and each skill, would you write it the same
  way today? If not, fix it or delete it. Compare the documented stack against `go.mod`,
  `package.json` and the actual code.

The audit's output is usually deletions. That is the sign it is working.

---

## Templates

- Go backend: [`templates/go-backend/CLAUDE.md`](../templates/go-backend/CLAUDE.md) +
  [`.claude/rules/`](../templates/go-backend/.claude/rules/) (6 rules)
- Next.js frontend: [`templates/next-frontend/CLAUDE.md`](../templates/next-frontend/CLAUDE.md) +
  [`.claude/rules/`](../templates/next-frontend/.claude/rules/) (15 rules)
