# Architecture Blueprint — Go back-end, hexagonal + modules

Millimeter spec to reproduce this architecture on a **new project**. Written for an agent (Claude,
Codex, openCode…) scaffolding the repo. Frozen stack: Go 1.26 / net/http stdlib / Postgres 17 / sqlc /
golang-migrate. No ORM, no HTTP framework, no `func init()`.

> The business domain is NOT described here — it is project-specific. This document describes only the
> invariant **structural skeleton**. Replace the `<placeholder>` tokens (`<module>` = Go module path,
> `<name>` = feature name).

---

## 1. Invariant principles (the 5 laws)

1. **Strict flow**: `handler → service → store → DB`. Never skip a layer.
2. **Contracts vs implementation**: `service.go` and `store.go` contain ONLY interface + struct +
   constructor. Zero implementation method in them.
3. **One file = handler OR service, never both.**
4. **Isolated modules**: a feature never imports another feature. Everything goes through
   `FeatureRegistry` or `CoreServices`.
5. **Grouped config**: `ModuleConfig` carries all shared infra and is handed to each module via
   `Register(...)` — never scatter infra as loose params.

If one of these laws is violated, the scaffold is wrong. No exception "because it is small".

---

## 2. Target tree

```
.
├── cmd/
│   └── api/
│       └── main.go              ← entry point, the ONLY place with log.Fatal
├── internal/
│   ├── core/
│   │   ├── module/
│   │   │   └── module.go        ← Module, Router, CoreServices, FeatureRegistry, ModuleConfig,
│   │   │                          Starter/Stopper + inter-module interfaces
│   │   ├── server/
│   │   │   └── engine.go        ← module registration loop, root router, global middleware, shutdown
│   │   ├── impl/                ← FeatureRegistry impl + CoreServices impl
│   │   └── shared/              ← shared service ports (auth, billing…)
│   ├── feature/
│   │   └── <name>/
│   │       ├── module.go        ← NewModule, Name(), Register() — wiring + middleware bound once
│   │       ├── handler/
│   │       │   ├── handler.go   ← struct Handler + New + helpers (writeJSON, writeError)
│   │       │   ├── create_x.go  ← 1 endpoint per file
│   │       │   └── delete_x.go
│   │       ├── service/
│   │       │   ├── service.go   ← CONTRACT: interface + struct + New + domain errors
│   │       │   ├── create_x.go  ← 1 business action per file
│   │       │   └── delete_x.go
│   │       └── store/
│   │           ├── store.go     ← CONTRACT: interface + struct + New
│   │           └── <entity>.go  ← store impl grouped by entity
│   ├── store/                   ← global store interfaces / cross-feature composition
│   ├── database/                ← sqlc-GENERATED — never hand-edit
│   └── pkg/                     ← cache, config, crypto, cookies, database, monitoring
├── sql/
│   ├── migrations/              ← golang-migrate
│   ├── queries/                 ← sqlc reads here, NEVER SQL in a .go
│   └── schema/                  ← source of truth for the model, updated after each migration
├── docs/
│   ├── ARCHITECTURE.md          ← domain map + inter-module interfaces
│   └── rapport/                 ← git-ignored reports (French, caveman off)
├── .claude/                     ← rules/ + memory/ + skills/ + settings.json
├── .agents/skills/              ← same skills, native for Codex/openCode
├── .codex/                      ← Codex config + hooks
├── AGENTS.md  CLAUDE.md  SETUP.md
├── Makefile
├── sqlc.yaml
└── go.mod
```

---

## 3. The core interfaces — `internal/core/module/module.go`

Exact skeleton to reproduce (adapt the shared services to the project):

```go
package module

import (
	"context"
	"database/sql"
	"net/http"

	"<module>/internal/core/shared/auth"
	"<module>/internal/database"
	"<module>/internal/pkg/cache"
	"<module>/internal/pkg/config"
)

// Module — every feature implements this. Do NOT change without human validation.
type Module interface {
	Name() string                                                       // unique key in the FeatureRegistry
	Register(router Router, core CoreServices, cfg ModuleConfig, features FeatureRegistry) // mounts routes
}

// Router — the subset of http.ServeMux exposed to modules for route registration.
type Router interface {
	Handle(pattern string, handler http.Handler)
	HandleFunc(pattern string, handler http.HandlerFunc)
}

// ModuleConfig — ALL shared infra, handed to every module at Register time.
type ModuleConfig struct {
	DB     *database.Queries // sqlc handle
	RawDB  *sql.DB           // for transactions (via a Transactor in the store)
	Config *config.Config
	Ctx    context.Context   // server-lifetime context, cancelled on shutdown
	Cache  cache.ValueCache
	// add shared infra clients here as the project needs them (object storage, telegram…)
}

// CoreServices — shared, cross-cutting service ports exposed to all modules.
// Never a feature-specific service.
type CoreServices interface {
	Auth() auth.Service
	// Billing() billing.Service  // add shared services here
}

// FeatureRegistry — lazy access to another registered feature, no direct import.
// Features only read via Get; the engine publishes via a Set exposed through a cast (see §7).
type FeatureRegistry interface {
	Get(name string) any
}

// Starter — optional: a module with background work to run after all modules are
// registered but before the server accepts requests. ctx is cancelled on shutdown.
type Starter interface {
	Start(ctx context.Context) error
}

// Stopper — optional: a module with fire-and-forget goroutines to drain before exit.
type Stopper interface {
	Stop()
}

// Inter-module contracts (interfaces published by one feature, consumed by another)
// are also declared in this file. See §7.
```

Rules:
- `Module`, `CoreServices`, `FeatureRegistry` and the engine are **critical files**: any change is
  validated with the human.
- No `func init()` anywhere.
- `CoreServices` holds only shared cross-cutting services (auth, billing…), never one feature's service.

---

## 4. The wiring — `cmd/api/main.go`

The only place allowed to call `log.Fatal`. Typical sequence:

```go
func main() {
	ctx := context.Background()
	cfg := config.Load()                         // env → struct, fail fast

	pool, err := database.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)                           // OK here, nowhere else
	}
	defer pool.Close()
	queries := database.New(pool.DB)

	registry := coreimpl.NewRegistry()
	core := coreimpl.NewCoreServices(cfg /*, shared svcs */) // instantiate shared services
	modCfg := module.ModuleConfig{
		DB: queries, RawDB: pool.DB, Config: cfg, Cache: cache.New(),
	}

	engine := server.NewEngineWithRegistry(cfg, core, modCfg, registry)

	// One line per feature. NewModule() takes nothing — infra arrives via Register().
	engine.Register(featureA.NewModule())
	engine.Register(featureB.NewModule())

	log.Fatal(engine.Run())
}
```

`engine.Run()` loops the modules: it calls each `m.Register(engine, core, modCfg, registry)`, then
`registry.Set(m.Name(), m)`, then any `Starter.Start(ctx)`. It mounts the global middleware
(recover, logging, CORS, rate limit) and a `/health` route, then serves and handles graceful shutdown.
Middleware lives in the engine, not in the handlers.

---

## 5. Feature anatomy — complete skeletons

### 5.1 `feature/<name>/module.go`

```go
package <name>

// Module holds optional module-level state (external sessions, clients). Often empty.
type Module struct{}

func NewModule() *Module { return &Module{} }

func (m *Module) Name() string { return "<name>" }

// Register wires the feature: store → service → handler, publishes any inter-module API,
// and binds the middleware ONCE.
func (m *Module) Register(router module.Router, core module.CoreServices, cfg module.ModuleConfig, features module.FeatureRegistry) {
	st := store.New(cfg.DB)                 // store gets Queries (+ cfg.RawDB when it needs transactions)
	svc := service.New(st)                  // service gets the store interface, never Queries
	h := handler.New(core.Auth(), svc)      // handler gets shared services + the service interface

	// Publish an inter-module API (if any). FeatureRegistry exposes Set only via a cast (see §7):
	if r, ok := features.(interface{ Set(string, any) }); ok {
		r.Set("<name>.<role>", svc)
	}

	requireAuth := middleware.NewAuth(core.Auth())      // middleware bound once, here
	router.HandleFunc("POST /api/v1/<name>", requireAuth(h.CreateX))
	router.HandleFunc("DELETE /api/v1/<name>/{id}", requireAuth(h.DeleteX))
}

// Optional lifecycle — implement only if the module has background work:
// func (m *Module) Start(ctx context.Context) error { ... }  // module.Starter
// func (m *Module) Stop()                          { ... }  // module.Stopper
```

### 5.2 `handler/handler.go` — struct + helpers only

```go
package handler

// SOMMAIRE (see file-sommaire.md) required from 2 declarations on.

type Handler struct {
	auth authport.Service        // shared service
	svc  ResourceService         // THIS feature's service interface
}

func New(auth authport.Service, svc ResourceService) *Handler {
	return &Handler{auth: auth, svc: svc}
}

// shared helpers — writeJSON, writeError, claimsFromRequest, decodeBody…
func (h *Handler) writeJSON(w http.ResponseWriter, code int, v any) { ... }
func (h *Handler) writeError(w http.ResponseWriter, code int, msg string) { ... }
```

### 5.3 `handler/create_x.go` — one endpoint

```go
package handler

// CreateX validates input, calls the service, returns the response. NO business logic here.
func (h *Handler) CreateX(w http.ResponseWriter, r *http.Request) {
	var in CreateXInput
	if err := h.decodeBody(r, &in); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	out, err := h.svc.CreateX(r.Context(), in)     // service only
	if err != nil {
		// map domain errors → HTTP code via errors.Is
		h.writeError(w, http.StatusInternalServerError, "create x")
		return
	}
	h.writeJSON(w, http.StatusCreated, out)
}
```

### 5.4 `service/service.go` — CONTRACT ONLY, zero implementation

```go
package service

// SOMMAIRE required.

// ResourceService — the contract the handler consumes. The impl lives in the other files.
type ResourceService interface {
	CreateX(ctx context.Context, in CreateXInput) (CreateXOutput, error)
	DeleteX(ctx context.Context, id string) error
}

// service — concrete struct, depends on the store interface (never sqlc).
type service struct {
	store Store          // local store interface
}

func New(store Store) ResourceService {
	return &service{store: store}
}

// Domain errors (declared here, used via errors.Is).
var (
	ErrNotFound  = errors.New("<name>: not found")
	ErrForbidden = errors.New("<name>: forbidden")
)

// I/O types.
type CreateXInput struct  { ... }
type CreateXOutput struct { ... }

// ⚠️ NO func (s *service) ... HERE. Every method goes in an action file.
```

### 5.5 `service/create_x.go` — one business action

```go
package service

// CreateX applies the business rule then persists via the store.
func (s *service) CreateX(ctx context.Context, in CreateXInput) (CreateXOutput, error) {
	// business validation, invariants, authorization…
	id, err := s.store.InsertX(ctx, ...)
	if err != nil {
		return CreateXOutput{}, fmt.Errorf("<name> service: create x: %w", err)
	}
	return CreateXOutput{ID: id}, nil
}
```

### 5.6 `store/store.go` — CONTRACT ONLY

```go
package store

// SOMMAIRE required.

// Store — interface consumed by the service. Impl in per-entity files.
type Store interface {
	InsertX(ctx context.Context, ...) (string, error)
	DeleteX(ctx context.Context, id string) error
	// Transactor            // add when the service needs atomic multi-writes (§6)
}

type store struct {
	q *database.Queries
	// db *sql.DB            // add when the store needs transactions
}

func New(q *database.Queries) Store {
	return &store{q: q}
}

// ⚠️ NO impl here.
```

### 5.7 `store/<entity>.go` — implementation

```go
package store

// InsertX runs the generated sqlc query and maps the result. No business logic.
func (s *store) InsertX(ctx context.Context, ...) (string, error) {
	row, err := s.q.InsertX(ctx, database.InsertXParams{...})
	if err != nil {
		return "", fmt.Errorf("<name> store: insert x: %w", err)
	}
	return row.ID, nil
}
```

---

## 6. Transactions — the Transactor pattern

`*sql.DB` never leaks into the service. When a store needs atomic multi-writes it takes `cfg.RawDB`
(`store.New(cfg.DB, cfg.RawDB)`) and exposes a transactional method:

```go
// In store: Transactor lets the service compose several writes atomically
// without ever seeing *sql.DB.
type Transactor interface {
	WithTx(ctx context.Context, fn func(Store) error) error
}

func (s *store) WithTx(ctx context.Context, fn func(Store) error) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil { return err }
	txStore := &store{q: s.q.WithTx(tx), db: s.db}
	if err := fn(txStore); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}
```

The service calls `s.store.WithTx(ctx, func(st Store) error { ... })`. It still only knows the interface.

---

## 7. Inter-module interface (feature A calls feature B)

Forbidden: `import "<module>/internal/feature/B"` from A.

Allowed pattern:

1. **B publishes** a contract: the interface is declared in `internal/core/module/module.go`, with a
   godoc stating who registers it, the registry key, who calls it, why.
2. **B registers** it in its `Register(...)` — `FeatureRegistry` only exposes `Get` publicly, so publish via a cast:

```go
if r, ok := features.(interface{ Set(string, any) }); ok {
	r.Set("B.role", bPublicAPI)   // bPublicAPI is B's service implementing the module interface
}
```

3. **A resolves** it (guard for nil/absent — any module can be missing):

```go
if b, ok := features.Get("B.role").(module.BInterface); ok {
	res, err := b.DoThing(ctx, ...)
	// ...
}
```

Adding an inter-module interface to `module.go` = **mandatory human validation**. Document each one in
`docs/ARCHITECTURE.md`. Use the `module-interface` skill.

---

## 8. Database — division of roles (autonomy in dev, human in prod)

The agent is **autonomous in dev / sandbox** (dedicated dev DB, Stripe test mode, etc.). Anything that
touches **production** is human-only unless the human explicitly authorizes it.

| Step                          | Who                                      | Where                     |
| ----------------------------- | ---------------------------------------- | ------------------------- |
| Write a migration             | Agent                                    | `sql/migrations/`         |
| Apply a **dev** migration     | Agent                                    | `make up-dev`             |
| Write a query                 | Agent                                    | `sql/queries/*.sql`       |
| `sqlc generate`               | Agent                                    | → `internal/database/`    |
| Update `sql/schema/`          | Agent                                    | after each migration      |
| Edit `internal/database/*`    | NEVER (generated)                        | —                         |
| Apply a **prod** migration    | **Human only** — unless explicitly authorized | `make up-prod`      |

Typical sqlc query (`sql/queries/<entity>.sql`):

```sql
-- name: InsertX :one
INSERT INTO x (col_a, col_b) VALUES ($1, $2) RETURNING id;

-- name: DeleteX :exec
DELETE FROM x WHERE id = $1;
```

No SQL query in a `.go` file, ever.

---

## 9. File header sommaire

Every `.go` with ≥ 2 top-level declarations carries a `// SOMMAIRE` block after `package`. The marker
string is a fixed literal, kept verbatim. Format and maintenance: `.claude/rules/file-sommaire.md`.
Excluded: `internal/database/*` generated. Generate/update with the `sommaire` skill;
`scripts/sync-sommaire-lines.sh` recomputes the line numbers.

---

## 10. Automatic guardrails (hooks + Makefile)

Reproduce these controls so the doctrine is **executed**, not just written:

- **PostToolUse hook (`.go` edit)**: `go build` + `go vet` + reject cross-feature imports + sommaire
  check. Exit 2 (blocks) if broken. (`scripts/hook-go-postedit.sh`)
- **Autocommit hook**: checkpoint-commit the edited file when it compiles (`scripts/hook-autocommit.sh`,
  toggle `BLUEPRINT_AUTOCOMMIT=0`).
- **`make check`** = `go vet` + tests.
- **`make lint`** = golangci-lint + cross-feature imports + file size (>300 lines) + sommaire checks.

Scripts in `scripts/`:
- `check-cross-feature-imports.sh` — grep `internal/feature/*` imports from another feature.
- `check-file-size.sh` — flag `.go` > 300 lines (excluding generated and `_test.go`).
- `check-sommaire.sh` — presence + count of the sommaire block.
- `sync-sommaire-lines.sh` — recompute the sommaire line numbers.

Golden rule: **a task is never done if `go build`, `go vet` or the tests fail.**

---

## 11. Compliance checklist (pass before saying "done")

- [ ] Each feature has `handler/` + `service/` + `store/` (or is flat + documented as an exception).
- [ ] `service.go` and `store.go` = interface + struct + constructor, zero impl.
- [ ] No file mixes handler and service.
- [ ] No feature imports another feature.
- [ ] `NewModule()` takes nothing; infra arrives via `Register(router, core, cfg, features)`.
- [ ] Middleware bound once in `module.go`.
- [ ] No SQL query in a `.go`. No manual edit of `internal/database/`.
- [ ] No `log.Fatal` outside `main.go`. No `func init()`. No mutable global `var`.
- [ ] `// SOMMAIRE` block present and in sync wherever ≥ 2 declarations.
- [ ] `go build`, `go vet`, tests pass.
