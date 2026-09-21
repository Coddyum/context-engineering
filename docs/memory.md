# The memory system

Eight markdown files in `.claude/memory/`, shared by every agent that works in the repo, versioned
with the code. They exist so that nothing the project has already figured out has to be figured out
again.

Templates for all eight: [`templates/go-backend/.claude/memory/`](../templates/go-backend/.claude/memory/).

---

## The shape

```
.claude/memory/
├── MEMORY.md         ← the index. Loaded every session. Holds pointers, never content.
├── CONTEXT.md        ← current state, priorities, work in progress. Loaded every session.
├── DOCTRINE.md       ← durable principles, separated from their current implementation
├── EDR.md            ← Engineering Decision Records
├── LEARNINGS.md      ← reusable learnings, patterns, traps avoided
├── BLOCKERS.md       ← problems hit + root cause + resolution
├── ITERATION_LOG.md  ← session journal
├── EVALS.md          ← quality evaluations of structural AI outputs
└── DRIFT-LOG.md      ← capitalised rules that got ignored or drifted
```

Two are loaded every session. The other six are loaded **only when the task touches something they
reference**, and `MEMORY.md` is what tells the agent whether that is the case.

That split is the whole design. `MEMORY.md` stays around a kilobyte because it holds one line per
entry — enough to decide, not enough to inform. `EDR.md` in a live project runs to twenty kilobytes,
and most sessions never open it.

**The discipline that keeps it working: never move register content into the index.** The moment
`MEMORY.md` starts summarising decisions instead of listing them, it grows, and it is loaded every
single session.

---

## What goes where — the routing question

Each register has a **trigger question** and a **validity test**. The validity test is the important
half: it is what stops the registers filling with noise.

| Register | Trigger question | Validity test |
| --- | --- | --- |
| `EDR.md` | What has been settled that commits what comes next? | If you cannot answer that clearly, it is execution, not a decision. No entry. |
| `LEARNINGS.md` | What changes how we work as soon as the next session? | If it changes nothing next session, it is an observation, not a learning. No entry. |
| `BLOCKERS.md` | What will bite again if it is not written down? | The 30-minute threshold. Below it, noise. Above it, it will recur. |
| `ITERATION_LOG.md` | Did this session change something? | No entry for exploratory or Q&A sessions with no change. |
| `EVALS.md` | Would getting this wrong be expensive and hard to reverse? | Routine changes are not evaluated. |
| `DRIFT-LOG.md` | Which rule did we write down and then not follow? | — |

A register without a validity test becomes a dumping ground within a month, and then nobody reads
it, and then it is pure cost.

---

## DOCTRINE.md — the one with an unusual shape

Most projects mix "what we believe" with "how we currently do it", and then throwing out the tool
means rewriting the belief. `DOCTRINE.md` separates them physically:

```markdown
### P3: Any config-gated control fails closed.

A permissive mode requires an explicit flag, never a value inferred from empty or absent config.

**Why**: an unset environment variable in production silently turns the control off, and nothing
in the logs says so.

**Current implementation**: `config.Load()` returns an error on a missing security variable rather
than a zero value. — disposable
```

Principle on top, stable. Implementation underneath, disposable. When the stack changes you delete
the bottom line and write a new one; the principle does not move.

The invariant *architecture* rules do not live here — they are in `.claude/rules/` and the
blueprint. `DOCTRINE.md` is for this project's durable domain, product and security principles.

---

## The close-out ritual

At the end of a significant session, three questions. Each "yes" routes to a register:

1. A decision that commits what comes next? → `EDR.md`
2. A learning that changes the next session? → `LEARNINGS.md`
3. A friction over 30 minutes that will come back? → `BLOCKERS.md`

Then one entry in `ITERATION_LOG.md`, and the one-line mirror in `MEMORY.md`.

The agent does this **without being asked** — it is in `CLAUDE.md`'s session-end instructions. The
reasoning is still in front of it and about to be thrown away; five minutes later it is gone, and
the next session pays to reconstruct it.

> "Nothing worth keeping" is a valid answer. An invented entry written to satisfy a ritual is worse
> than no entry — it makes the register less trustworthy, so it gets read less, so the real entries
> stop working too.

---

## Maintenance — because registers rot

Two skills keep the memory honest. Both ship in
[`templates/go-backend/.claude/skills/`](../templates/go-backend/.claude/skills/).

**`consolidate-memory`** — classify every entry as VALID / STALE / DRIFT / TO VERIFY, resolve
contradictions, prune, then update the index. Run at the end of a long session or before a handoff.

A valid historical EDR is never deleted because the decision later changed: it gets a follow-up, or
a new EDR that supersedes it. A register that hides its own history stops being evidence.

**`quarterly-audit`** — every ~90 days, audit the doctrine, agent instructions, skills and declared
stack against the real code. For each skill: would you write it the same way today? If not, fix it
or delete it. Read `DRIFT-LOG.md` and decide, for each drift, whether to fix it, promote it into a
systemic rule, demote it to contextual, or document that it stands.

The audit is a **deletion pass**, not a documentation ceremony. A rule nobody follows costs context
on every session and buys no behaviour.

---

## Knowing when to stop

`.claude/memory/` is not the only possible answer, and it is not always the right one.

One project in the reference set migrated `CONTEXT`, `EDR`, `DOCTRINE`, `ITERATION_LOG`,
`DRIFT-LOG` and `EVALS` onto its task tracker and deleted them, keeping only `LEARNINGS.md` and
`BLOCKERS.md` locally. State was genuinely better served by cards a human could reprioritise, and
the decision register became a dedicated **Decisions** project whose cards are never archived —
a superseded decision moves to a `Superseded` column naming its replacement. Keeping both in sync
was overhead with no reader.

What stayed local stayed for a reason: a recurring technical pitfall is not work-to-do, a board
models it badly, and its value is being greppable next to the code that caused it.

The rule that survives every variant: **two places that both claim to hold the state means neither
does.** Pick one per kind of information, and write down which. See
[task-tracking.md](task-tracking.md).
