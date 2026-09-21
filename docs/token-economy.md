# Token economy

The organising idea of this whole repository: **an agent's cost is set by what it has to read, not
by what it writes.**

Output is a rounding error. A substantial code change is maybe two thousand tokens of diff. Getting
to the point where the agent can write those two thousand tokens correctly can cost fifty thousand
— reading the wrong files, re-reading files it already read, re-deriving a decision that was made
three weeks ago, exploring a directory it should never have opened.

Every convention in this repo exists to shrink that number. Not by making the agent read less
carefully — by making the *right* read short and the *wrong* read unnecessary.

---

## Where the tokens actually go

On a large project, a session's input cost splits roughly into six buckets:

| Bucket | What it is | What makes it big |
| --- | --- | --- |
| **Standing instructions** | `CLAUDE.md` + rules, injected every session | one fat file holding every rule for every situation |
| **Orientation** | finding out where the relevant code lives | no map, flat directories, names that need a grep to disambiguate |
| **Reading code** | opening files to understand before editing | 700-line files where 40 lines were relevant |
| **Re-deriving context** | working out why something is the way it is | decisions that live only in a closed PR, or in nobody's head |
| **Re-deriving state** | working out where the last session stopped, and what the other repo does | state that lives only in the conversation that produced it |
| **Repair loops** | the agent breaks something, is told, tries again | no mechanical feedback, so errors surface three prompts later |

Each bucket has a lever. None of the levers is clever — they are all some version of *write it down
once, in the place the agent will look.*

---

## Lever 1 — a routed memory, not a loaded one

The naive approach to project memory is one big file the agent reads at session start. It works
until it is 40 KB, at which point you are paying 10 000 tokens on every session to carry context
that ninety percent of tasks do not need.

The fix is an **index that routes**:

```
.claude/memory/MEMORY.md      ← loaded always. ~1 KB. Holds no content, only pointers.
.claude/memory/CONTEXT.md     ← loaded always. Current state, priorities. Kept short.
.claude/memory/EDR.md         ← loaded ON DEMAND, when the task touches a decision it records
.claude/memory/LEARNINGS.md   ← on demand
.claude/memory/BLOCKERS.md    ← on demand
...
```

`MEMORY.md` mirrors each entry as a one-line title. That is enough for the agent to decide whether
the full register is worth opening. Most sessions it is not.

The discipline that keeps this working: **never move register content into the index.** The index
is cheap precisely because it holds nothing. Full detail: [memory.md](memory.md).

## Lever 2 — rules split by theme, loaded by relevance

Same principle one level up. `CLAUDE.md` stays deliberately slim: the invariants, a map, and a
table pointing at `.claude/rules/*.md`, one file per theme.

A task about translations loads `i18n.md` (1 KB). It does not load the testing rules, the styling
rules, or the SQL workflow. In the reference frontend that split is fourteen rule files totalling
~35 KB, of which a typical session reads two.

The counter-intuitive part: **splitting makes the rules stricter, not looser.** A single-file
doctrine gets skimmed. A 1 KB file on exactly the thing you are doing right now gets read.

Full detail: [rules.md](rules.md).

## Lever 3 — the file sommaire

A navigation block at the top of every source file with two or more top-level declarations:

```go
// SOMMAIRE (lire en premier, sauter directement au bon passage)
//
// | Élément    | Résumé                                       | Ligne |
// |------------|----------------------------------------------|-------|
// | NewService | Creates the service with its dependencies    | 14    |
// | CreateUser | Inserts a user and returns its ID            | 30    |
//
// Fin du sommaire.
// =====================================================================
```

Fifteen lines that let an agent open a 300-line file, read the header, and jump straight to line 30.
Instead of reading the file to find out what is in it, it reads the file it needs.

This is the single most mechanical saving in the set, and it compounds: every file, every session,
forever. It is also the one people drop first, which is exactly why it is enforced by a blocking
hook rather than a convention. Full detail: [file-sommaire.md](file-sommaire.md).

## Lever 4 — an architecture with hard boundaries

The Go blueprint's five laws — strict `handler → service → store → DB` flow, contracts-only
interface files, no feature importing another feature — are usually argued as software design. They
are also, and maybe primarily, a context argument.

If a feature can only be reached through its own `handler/`, `service/` and `store/`, then
understanding it means reading one directory. If features import each other freely, understanding
one means reading the transitive closure of everything it touches — and an agent asked to change an
invoice line ends up loading the user module, the billing module and the notification module to be
sure it has not broken anything.

**Enforced isolation is bounded reading.** That is why it is a blocking script
(`check-cross-feature-imports.sh`) and not a code-review preference.

Same logic behind the 300-line file limit. A file an agent must read in full to change one function
is a file that costs its full length on every single session that touches it.

## Lever 5 — mechanical feedback instead of conversational repair

The expensive failure mode is not the agent making a mistake. It is the agent making a mistake, not
knowing, continuing to build on it, and being told four turns later. Now you pay for the four turns,
plus the unwinding, plus the re-explanation.

A `PostToolUse` hook that runs `go build` + `go vet` + the structural guards and exits 2 turns that
into a same-turn correction. The agent sees the compiler error attached to its own edit, fixes it,
moves on. Nothing reaches the conversation.

The rule of thumb that keeps hooks alive: **a guard slower than a few seconds gets switched off, and
a guard that is off guards nothing.** That is why the frontend hook is deliberately static — no
build, no `tsc`, no test run — and checks only what can be established by reading files. Full
detail: [guardrails.md](guardrails.md).

## Lever 6 — a task tracker as external memory

Anything the agent has to reconstruct, it pays for. Decisions are the worst case: "why is auth
handled in the store and not the middleware?" is either one line somewhere, or twenty minutes of
code archaeology, every time.

Levers 1 and 2 solve that for doctrine, with an index that routes. **A tracker is the same
architecture applied to the project's live state** — and it externalises more than a paragraph. It
holds what is left to do, what is in progress, what is waiting on a human, and every decision in
force. None of that sits in the context window until something asks for it.

The arrangement that survived is not an agent-only backlog running beside a human one. It is
**agents working the same board the human reads** — one set of cards, written so a person can
reprioritise them and an agent can pick one up cold.

The tracker in use is [Flowlio](https://flowlio.me).

> **Disclosure:** Flowlio is one of my own projects. It is named here because that is what these
> patterns were built against — not as a recommendation. The shape is the point, and it generalises
> to Linear, Jira or GitHub Issues; read the rows below for the mechanism, not the tool.

### Where it actually saves

| Without it | With it |
| --- | --- |
| "Where was I?" → re-read the git log, re-read the diffs, re-explore the feature | open the card: what is done, what is left, what was decided, written by the last session |
| "Why is it built this way?" → read the code and infer, or ask | one card in the **Decisions** project, with what was rejected |
| "Is this finished?" → a round-trip with the human | the card's `## Done when` is checkable criteria, so the agent answers it |
| The board grows into a wall of finished work re-read every session | finished cards are archived — the live listing carries only live work |
| Progress mirrored into a `PROGRESS.md` that drifts from reality | one home per kind of information, so nothing needs reconciling |

The second row is the one that compounds. A decision buried in a card description dies when the card
is archived, and the next session re-derives it — or worse, re-decides it differently. A dedicated
Decisions project, where cards are **never archived** and a superseded decision moves to a
`Superseded` column naming its replacement, turns "why is it like this?" into one listing call.

Two structural properties carry most of the rest:

- **Nothing is deleted, only archived or superseded.** Past context stays queryable without sitting
  in the active listing. Exactly the `MEMORY.md` trade, one level up: available on demand, absent by
  default.
- **Cards are organised by product area, not by code layer.** A change touching the API, the front
  end and a tooling script is one card. A board split by layer makes whoever picks the work up
  reassemble it first, every time.

And one real cost, stated plainly: ids are resolved by name every session — teams, then projects,
then columns — which is three calls before the useful one. That is the price of a board a human is
free to rearrange. Hardcoding an id is cheaper right up until it silently points somewhere else.

### The four levels, which must not mix

| Level | Lives in | Lifetime | Answers |
| --- | --- | --- | --- |
| Session | the agent's own todo list | dies with the conversation | what am I doing in the next ten minutes |
| Project state and decisions | **the tracker** | survives sessions | what is left to do, and why it is like this |
| Recurring technical pitfalls | **`.claude/memory/`** — `LEARNINGS`, `BLOCKERS` | survives sessions, versioned | what will bite again |
| Design | the repo's `docs/` | versioned with the code | how it is supposed to fit together |

Where the remaining registers (`CONTEXT`, `EDR`, `DOCTRINE`, `ITERATION_LOG`, `DRIFT-LOG`, `EVALS`)
live is a real choice, and both answers work: on the board, or in `.claude/memory/` as
[memory.md](memory.md) describes. The most recent project moved them onto the board and deleted the
files, because holding the same state in two places was work with no reader.

What does not vary: **two places that both claim to hold the state means neither does.**

### The cost side, honestly

A tool call is not free. It is cheap against re-derivation — a few hundred tokens against several
thousand — but the arithmetic only holds if the tracker carries what survives the session and
nothing else. Mirroring the fine-grained todo list into it inverts the trade: every step becomes a
round trip, and the agent pays tracker calls to remember what it was going to do ninety seconds from
now.

The line: **a card is what survives the session, not what happens inside it.**

Full detail — board shape, session ritual, how to write a card, the status vocabulary, the archive
discipline, and when a second agent-only surface is and is not worth it:
[task-tracking.md](task-tracking.md). The rule file that encodes it for the agent ships in both
templates: [`tracker-workflow.md`](../templates/go-backend/.claude/rules/tracker-workflow.md).

## Lever 7 — output discipline

Two rules that sound cosmetic and are not:

- **Never paste code into the chat.** Code shown in conversation is paid for twice — once as output,
  then again as input on every subsequent turn — and then written to the file anyway. Write to the
  file; the file is the deliverable.
- **Compress the prose, never the technical content.** Dropping articles and pleasantries from
  agent responses costs nothing in precision. Reports and commit messages are the explicit
  exception: written once, read by a human later, where ambiguity costs more than tokens.

---

## What this does not do

Worth being direct about the limits.

- **This is not a benchmark.** No numbers here are measured. The mechanisms are arithmetic — a
  1 KB index instead of a 40 KB file is a 39 KB saving, every session — but the aggregate depends
  entirely on your codebase and your task mix. Measure your own.
- **It costs discipline up front.** Sommaire blocks, register hygiene and split rules are real work.
  They pay back on repeated sessions over a long-lived codebase. On a weekend project they do not.
- **Rules rot.** A rule nobody follows is worse than no rule: you pay for it on every session and
  get no behaviour for it. That is the entire reason for `DRIFT-LOG.md` and the `quarterly-audit`
  skill — a scheduled deletion pass, not a documentation ceremony.

---

## Where to go next

| You want | Read |
| --- | --- |
| The memory registers and how they route | [memory.md](memory.md) |
| How rules are split and loaded | [rules.md](rules.md) |
| The hooks, and how to write one that survives | [guardrails.md](guardrails.md) |
| The sommaire convention | [file-sommaire.md](file-sommaire.md) |
| Skills: what is mine, what is borrowed | [skills.md](skills.md) |
| Running the same doctrine across agents | [multi-agent.md](multi-agent.md) |
| A task tracker as external memory, and the four levels | [task-tracking.md](task-tracking.md) |
| The 14-day package quarantine | [supply-chain.md](supply-chain.md) |
