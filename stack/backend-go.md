# Backend stack — Go

The deliberate shape: **Go + `net/http` + PostgreSQL + sqlc + golang-migrate.** No ORM, no HTTP
framework, no dependency injection container, no `func init()`.

What follows is the set that is the same across every Go service in the reference projects — the
architectural layer. Feature-level libraries (payments, email, object storage, a Discord client, a
PDF writer) are deliberately out: they belong to a product, not to a stack.

---

## The core

| Concern | Choice | Why this one |
| --- | --- | --- |
| HTTP | `net/http` (stdlib) | since Go 1.22 the stdlib mux routes on method and path params (`POST /api/v1/users/{id}`). That was the last real reason to reach for a framework |
| Database driver | `github.com/jackc/pgx/v5` | the Postgres driver. Native protocol, real connection pooling, correct types |
| Query layer | **sqlc** (generator) | write SQL, get typed Go. The opposite of an ORM: SQL stays SQL, and the compiler checks the call site |
| Migrations | **golang-migrate** (CLI) | plain numbered `.up.sql` / `.down.sql` pairs. Nothing clever, nothing to debug at 2 a.m. |
| IDs | `github.com/google/uuid` | — |
| Config | `github.com/joho/godotenv` + a hand-written `config.Load()` | env → struct, fail fast on a missing variable |

## Auth, when the service has users

| Concern | Choice | Note |
| --- | --- | --- |
| Tokens | `github.com/golang-jwt/jwt/v5` | v5, not v4 — the older major has known issues |
| Password hashing | `github.com/alexedwards/argon2id` | Argon2id with sane defaults. Not bcrypt, not SHA-anything |
| OAuth clients | `golang.org/x/oauth2` | only when a third-party provider is involved |
| Crypto primitives | `golang.org/x/crypto` | — |

## Cross-cutting

| Concern | Choice | Note |
| --- | --- | --- |
| Rate limiting | `golang.org/x/time/rate` | token bucket, in the engine's middleware |
| In-memory cache | `github.com/patrickmn/go-cache` | behind a `ValueCache` interface in `ModuleConfig`, so it can be swapped for Redis without touching a feature |
| Goroutine leak detection | `go.uber.org/goleak` | in tests. Catches the background worker that never stops — the bug that only shows up in production, as a slow memory climb |

That is the whole architectural dependency list. Roughly ten direct dependencies for a full service.

---

## Why no ORM

The argument is not purity, it is where the failure lands.

An ORM moves query construction to runtime. A mistake surfaces as a wrong result or a slow query in
production. sqlc moves it to build time: the SQL is parsed against the real schema at generation,
and the generated function signature is checked by the compiler at every call site. A renamed column
breaks the build.

The trade is that you write SQL. Which, for anything past a `SELECT *`, you were going to end up
doing anyway — through the ORM's escape hatch, with none of the checking.

The convention that makes it work: **no SQL in a `.go` file, ever.** Queries live in
`sql/queries/<entity>.sql`, sqlc generates `internal/database/`, and that directory is never
hand-edited. See the `sql-workflow` skill.

## Why no HTTP framework

Before Go 1.22 the stdlib mux could not route on method or extract path parameters, so everyone
reached for one. That gap is closed:

```go
router.HandleFunc("POST /api/v1/invoices", requireAuth(h.CreateInvoice))
router.HandleFunc("DELETE /api/v1/invoices/{id}", requireAuth(h.DeleteInvoice))
```

Middleware is `func(http.Handler) http.Handler`, which every framework accepts anyway, so nothing is
lost in portability. What is gained is one fewer dependency with its own context type, its own error
convention, and its own major-version migration every two years.

## Why no `func init()`

Wiring happens in exactly one place, `cmd/api/main.go`, in an order you can read top to bottom. An
`init()` runs at import time, in package-initialisation order, before `main` — which means
behaviour depends on the import graph, and adding an import can change startup. It is also
untestable and unmockable.

Same reasoning behind no mutable package-level `var`: all state travels through `CoreServices` or
`ModuleConfig`.

---

## Version policy

Every dependency is **pinned exactly**. No `^`, no `~`, no floating anything.

The 14-day quarantine applies in full — **and Go has no automatic guard for it**. The hook that
enforces it covers JS only. For `go get` and `go install`, check the publish date by hand and step
back if the version is too fresh. See [supply-chain.md](../docs/supply-chain.md).

`go.sum` is the integrity check; keep it committed and never `-mod=mod` your way past a mismatch.

---

## Tooling

| Tool | Role |
| --- | --- |
| `sqlc` | generates `internal/database/` from `sql/queries/` |
| `migrate` | applies `sql/migrations/` |
| `golangci-lint` | pinned version, run from `make lint` and from CI |
| `jq` | used by the hooks to parse hook payloads |
| `python3` | used by `sync-sommaire-lines.sh` |

`make check` = `go vet` + tests. `make lint` = golangci-lint + the structural guards. A task is never
done if either is red.

---

## What is deliberately excluded here

Present in the reference projects, absent from this document, because they belong to a product
rather than to an architecture: payment SDKs, transactional email clients, S3-compatible storage
SDKs, chat-platform clients, PDF libraries, MCP server SDKs.

The line: **if removing it would change what the product does, it is a feature dependency. If
removing it would change how the code is organised, it is a stack dependency.**

---

## The architecture that goes with it

[`templates/go-backend/ARCHITECTURE-BLUEPRINT.md`](../templates/go-backend/ARCHITECTURE-BLUEPRINT.md)
— the millimetre spec: the five laws, the target tree, the exact core interfaces, the feature
skeleton, the transaction pattern, the inter-module protocol, and the compliance checklist.
