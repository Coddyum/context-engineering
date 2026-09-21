# Skills

A skill is a procedure the agent loads when a situation matches — scaffolding a feature, writing a
migration, auditing the memory. It is the opposite trade from a rule file: a rule is short and
always available; a skill can be long because it is only loaded when its trigger fires.

That is why a skill can afford to be a complete recipe with code blocks and a checklist, and a rule
file cannot.

---

## The ones in this repo

Eight, in [`templates/go-backend/.claude/skills/`](../templates/go-backend/.claude/skills/) and
mirrored in `.agents/skills/` for agents that read that path. One more, `frontend-architect`, ships
with the Next.js template.

| Skill | Fires when | Does |
| --- | --- | --- |
| `new-feature` | a new `internal/feature/<name>` is needed | scaffolds handler/service/store, wires `module.go`, registers in `main.go` |
| `module-interface` | feature A needs to call feature B | declares the interface in `module.go`, publishes it, resolves it lazily — with a human check first |
| `sql-workflow` | any new table, column, migration or query | migration pair, sqlc conventions, schema snapshot, dev/prod division of labour |
| `sommaire` | a file's navigation block is missing or stale | generates or resynchronises it |
| `consolidate-memory` | end of a long session, before a handoff | classifies every register entry VALID / STALE / DRIFT, prunes, updates the index |
| `quarterly-audit` | every ~90 days | audits doctrine, skills and declared stack against the real code |
| `lead` | the user wants to write the code themselves | read-only mode: explain, design, challenge, never edit |
| `commit-clean` | an explicit request to commit, push or open a PR | branch, atomic Conventional Commits, PR body |
| `frontend-architect` | auditing or restructuring a Next.js codebase | seven-axis architectural review with a phased roadmap |

Four of these are architecture skills and only make sense alongside
[the Go blueprint](../templates/go-backend/ARCHITECTURE-BLUEPRINT.md). The other five are portable.

---

## What makes them work

### A trigger, not a description

```yaml
description: >
  TRIGGER — use BEFORE writing any feature code when the task involves creating a new
  internal/feature/<name> directory or scaffolding handler/service/store. Do NOT skip
  for "simple" features — size does not change the pattern.
```

The description is the only thing the agent sees before deciding whether to load the skill. A
description that says *what the skill contains* leaves the decision to inference; one that says
*when to fire* makes it mechanical.

The `Do NOT skip for "simple" features` clause is there because that is the observed failure: the
agent judges a two-endpoint feature too small to warrant the procedure, and produces something
shaped differently from every other feature in the repo.

### A checklist that ends it

Every procedural skill closes with one:

```markdown
- [ ] `store/store.go` — interface + struct + `New` only, zero implementations
- [ ] `service/service.go` — interface + struct + `New` + types + errors only, zero methods
- [ ] Middleware bound once in `module.go`, never inside handlers
- [ ] SQL queries in `sql/queries/<name>.sql` — run `sqlc generate`
- [ ] Module registered in `main.go`
```

Without it, "done" is a judgement call. With it, "done" is a list — and the parts that get skipped
(registering the module, running the generator) are exactly the boring ones a checklist catches.

### A human gate on the irreversible step

`module-interface` opens with **validate with the user first**, because it touches a shared contract
file every feature depends on. `sql-workflow` marks production migrations human-only.

A skill that encodes where the agent must stop is more useful than one that only encodes what it can
do.

### Progressive disclosure for the big ones

`frontend-architect` is 13 KB of procedure plus four reference files of 3–8 KB each. The skill body
tells the agent when to reach for each:

> Read a reference file when you need to go deeper on a specific axis. Don't read all of them
> upfront.

Same principle as the memory index, one layer down.

---

## Third-party skills — used, not vendored

A large part of the day-to-day skill set in the reference projects comes from
**[mattpocock/skills](https://github.com/mattpocock/skills)**, not from me. They are **not
redistributed here** — install them from the source.

| Skill | Fires when |
| --- | --- |
| `tdd` | building a feature or fixing a bug test-first |
| `diagnose` | a hard bug or performance regression: reproduce → minimise → hypothesise → instrument → fix → regression-test |
| `zoom-out` | an unfamiliar area of the codebase, before editing |
| `grill-me` | a plan that should be stress-tested before it is built |
| `grill-with-docs` | same, but challenged against the documented domain model and ADRs |
| `improve-codebase-architecture` | finding deepening and consolidation opportunities |
| `prototype` | a design worth throwing away once before committing to it |
| `to-prd` / `to-issues` / `triage` | turning a conversation into a PRD, then into grabbable issues |
| `handoff` | compacting a conversation for the next session |
| `write-a-skill` | writing a new skill |

`setup-matt-pocock-skills` configures them per repo: which issue tracker, which triage labels, where
the domain docs live. Run it once before first use.

**Where they fit.** They cover the general engineering loop — diagnosis, TDD, planning, triage. What
is in this repository covers the parts specific to an architecture: scaffolding *this* module
system, writing *this* migration shape, maintaining *this* memory. The two sets do not overlap, and
that is the point — do not rewrite what exists.

`caveman`, referenced in some of the reference projects' settings, is likewise a third-party plugin:
a terse-output mode. The relevant principle is documented in
[token-economy.md](token-economy.md#lever-7--output-discipline) — compress the prose, never the
technical content, and turn it off for anything a human reads later.

---

## Writing your own

Worth a skill:

- A procedure with **more than three steps** that must come out the same way every time.
- A procedure with a **step that is easy to skip** and expensive to skip (registering the module,
  updating the schema snapshot, re-running the generator).
- A procedure with a **human gate** in the middle.

Not worth a skill:

- Anything a rule file states in four lines. A skill that is a rule in a costume just adds a
  loading decision.
- Anything a script can do outright. If it is mechanical, write the script and reference it.
- Anything already in [mattpocock/skills](https://github.com/mattpocock/skills).

And put them in the quarterly audit. The question is not "is this still correct?" but **"would I
write this the same way today?"** If not, fix it or delete it.
