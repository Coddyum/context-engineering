# Infrastructure and the production boundary

Database workflow, build and deploy shape, CI, and the one line that matters most when an agent has
shell access: **dev is autonomous, production is human.**

---

## The line

The agent is fully autonomous in dev and sandbox. It writes migrations *and applies them*, runs the
generator, runs tests, runs tooling. No hand-off, no asking permission for routine work — an agent
that has to ask before running `sqlc generate` is an agent that costs more than it saves.

Production is the opposite, and the boundary is mechanical rather than advisory.

| Zone | Agent | Why |
| --- | --- | --- |
| Dev database — migrate up/down, generate, schema snapshot, test DB | free | isolated branch, no real data |
| Writing migrations, queries, schema snapshots | free | that is code, and code is the job |
| Production migrations, anything naming the production DB URL | **never** | one wrong migration and the accounts are gone |
| Any preflight or task that *reads* production | **never** | reading production means holding a production credential |
| Object-storage publication, CDN invalidation | **never** | a published artefact is what live clients download |
| Hosting and database control planes (CLI, API) | **never** | deploys, environment variables, branches, plans |
| Payment provider — any change to a product, price, webhook, customer | **never** | money, and state rebuilt from an event stream |
| DNS, email routing, domain settings | **never** | breaking them breaks sign-up and contact |
| Tags, releases, workflow files, repository settings | **never** | a tag publishes a release; settings *are* the guardrails |

Building the image locally and reading versioned files is fine — neither leaves the machine.

### The escape hatch, and why its shape matters

Human authorisation is re-running the exact command with a prefix:

```bash
ALLOW_PROD=1 make up-prod
```

A command that *carries* `ALLOW_PROD=1` when the agent typed it is refused on purpose: the
authorisation never comes from the command itself. It is exported by the human in their own shell,
for a specific command they chose to run.

The agent does not ask for the hook to be lifted. It:

1. finishes everything that does **not** touch production — migration written, branch green,
   changelog entry prepared, artefact built locally;
2. states in one line what the human must run, in which order, with the exact commands;
3. leaves the task in review with those steps written down.

Enforced by `scripts/block-prod.sh` on `PreToolUse(Bash)`, exit 2, fails closed. See
[guardrails.md](../docs/guardrails.md).

---

## Database workflow

PostgreSQL, sqlc, golang-migrate. The division of labour, in full:

| Step | Who | Command |
| --- | --- | --- |
| Write a migration pair | agent | `sql/migrations/NNNN_x.{up,down}.sql` |
| Apply in **dev** | agent | `make up-dev` |
| Write a query | agent | `sql/queries/<entity>.sql` |
| Generate Go | agent | `sqlc generate` → `internal/database/` |
| Update the schema snapshot | agent | `sql/schema/` |
| Edit `internal/database/*` | **never** | it is generated |
| Apply in **production** | **human only** | `ALLOW_PROD=1 make up-prod` |

Two absolutes: **no SQL in a `.go` file**, and **never hand-edit generated code**. Both are the kind
of rule that erodes silently, which is why the `sql-workflow` skill exists and why the layering
guard runs on every edit.

### Migrations that survive a deployment

Migrations are applied **before** the new binary ships, so the old binary runs for a few minutes
against the new schema. Therefore a migration:

- **adds** (nullable column, table, index) and never renames or drops what the running code still
  uses;
- drops a column only **one version after** the code stopped reading and writing it;
- ships a `.down.sql` that goes back without losing user data;
- creates an index on a growing table with `CREATE INDEX CONCURRENTLY`, outside a transaction.

Every FK gets an index. Every column used in a `WHERE` gets one. `ON DELETE CASCADE` for user-owned
data, `ON DELETE SET NULL` for optional references.

---

## Build and deploy

The shape the reference projects converged on: **one Docker image per service.** For a Go binary
serving a statically-exported front end, that is one image for the whole product — the front is
built to static files and embedded, so there is one artefact, one deploy, and no version skew
between a front end and an API that are supposed to match.

Providers in use are ordinary managed ones — serverless Postgres with branchable databases, a
container host, S3-compatible object storage, a DNS and email edge. Nothing here depends on which:
the boundary above is about *what the agent may reach*, not about the vendor.

Local secrets live in a git-ignored `.env`. Production secrets live in the host's dashboard. **CI
has none and needs none** — which is a design constraint worth holding, because a CI that needs a
production credential is a CI that can leak one.

**Never read, print, copy or commit a `.env`, a token, a connection string or a webhook secret.**
Never put one in a task, a report, a commit message or a log line. A secret seen by accident is
reported so it can be revoked — not reused, not "just this once" to unblock something.

---

## CI

Three jobs, no secrets, nothing that touches production:

| Job | What it proves |
| --- | --- |
| `backend` | build, vet, tests, pinned linter, and the structural guards from `make lint` |
| `frontend` | typecheck and a real build |
| `image` | the Docker image builds the way the host builds it, starts against a throwaway database, and answers on `/health` |

The third one is the one that earns its keep. Build-and-test passing tells you the code compiles;
booting the actual image against a real database tells you the thing you are about to deploy starts.

Adding a step is fine. Weakening one — `continue-on-error`, removing a guard, unpinning the linter
— is a doctrine change: it gets asked about and recorded, not slipped in to make a red build green.

---

## Release flow

```
task → branch → commits → pull request → green CI → merge → changelog → tag vX.Y.Z → deploy
```

| Step | Agent | Human |
| --- | --- | --- |
| Branch from an up-to-date `main` | yes | — |
| Commits (checkpoints + Conventional Commits) | yes | — |
| `make check` + `make lint` green before handing over | yes | — |
| Push the branch | on explicit request only | yes |
| Open the PR | on explicit request only | yes |
| Merge into `main` | **never** | yes |
| Changelog, tag, release, deploy | **never** | yes |

`main` takes no direct push and no local merge: a change reaches it through a PR with green CI. An
agent that has finished a branch says so and stops there.

> Worth being honest about: in the reference project **nothing enforces this on the forge side** —
> branch protection needs a paid plan on a private repository, and that was deferred. What holds it
> is the `block-prod` hook and the written rule. For an agent the rule is absolute either way; for a
> human it is discipline. If you can turn on branch protection, do.

One version = one tag = **one deployment**, never one commit or one PR. Several merged PRs ship
under the same version.

An agent may **prepare** changelog entries under an "Unreleased" heading, written for a user rather
than for a developer. It never tags, never pushes a tag, never publishes a release.

Checkpoint commits from the autocommit hook are never squashed, amended or rewritten. Thirty stay
thirty.
