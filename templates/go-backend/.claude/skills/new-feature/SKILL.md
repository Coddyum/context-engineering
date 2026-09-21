---
name: new-feature
description: >
  TRIGGER — use BEFORE writing any feature code when the task involves creating a new
  internal/feature/<name> directory or scaffolding handler/service/store. Do NOT skip
  for "simple" features — size does not change the pattern. Covers scaffold, wiring,
  and main.go registration.
---

# New Feature Scaffold

## Structure to create

```
internal/feature/<name>/
  module.go
  handler/
    handler.go       ← struct Handler, constructor New, helpers writeJSON/writeError/claimsFromRequest
    <action>.go      ← one file per endpoint
  service/
    service.go       ← contract ONLY: Service interface, svc struct, New, types, domain errors
    <action>.go      ← one file per business action — zero methods in service.go
  store/
    store.go         ← contract ONLY: Store interface, struct, New — NO implementations
    <entity>.go      ← grouped implementations by entity
```

## Step-by-step

### 1. store/store.go — contract only

```go
package store

import (
    "context"
    "github.com/google/uuid"
    "<module>/internal/database"
)

type Store interface {
    // one method per query from sql/queries/<name>.sql
}

type <name>Store struct {
    q *database.Queries
}

func New(q *database.Queries) Store {
    return &<name>Store{q: q}
}
```

### 2. store/<entity>.go — implementations

```go
package store

func (s *<name>Store) GetByID(ctx context.Context, id uuid.UUID) (database.X, error) {
    return s.q.GetXByID(ctx, id)
}
```

### 3. service/service.go — contract only, ZERO method implementations

```go
package service

import (
    "context"
    "errors"
    "github.com/google/uuid"
    "<feature>/store"
)

var (
    ErrNotFound = errors.New("<name> not found")
)

// Input/output types — never expose database types to the handler layer

type Service interface {
    DoThing(ctx context.Context, userID uuid.UUID, req DoThingRequest) (DoThingResult, error)
}

type svc struct {
    store store.Store
}

func New(s store.Store) Service {
    return &svc{store: s}
}
```

> If a `func (s *svc) xxx(...)` appears in service.go, it is a violation. Move it to its own file.

### 4. service/<action>.go — one business action per file

```go
package service

func (s *svc) DoThing(ctx context.Context, userID uuid.UUID, req DoThingRequest) (DoThingResult, error) {
    // business logic — no *database.Queries, no *sql.DB
}
```

### 5. handler/handler.go

```go
package handler

import (
    "encoding/json"
    "net/http"
    "<module>/internal/api/middleware"
    authport "<module>/internal/core/shared/auth"
    "<feature>/service"
)

type Handler struct {
    auth authport.Service
    svc  service.Service
}

func New(auth authport.Service, svc service.Service) *Handler {
    return &Handler{auth: auth, svc: svc}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    _ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
    writeJSON(w, status, map[string]string{"error": message})
}

func claimsFromRequest(r *http.Request) *authport.Claims {
    return middleware.ClaimsFromContext(r.Context())
}
```

### 6. handler/<action>.go

```go
package handler

import "net/http"

func (h *Handler) DoThing(w http.ResponseWriter, r *http.Request) {
    claims := claimsFromRequest(r)
    if claims == nil {
        writeError(w, http.StatusUnauthorized, "unauthorized")
        return
    }
    // decode request body, call h.svc, encode response
}
```

### 7. module.go — wiring

```go
package <name>

import (
    "<module>/internal/api/middleware"
    "<module>/internal/core/module"
    "<feature>/handler"
    "<feature>/service"
    "<feature>/store"
)

type Module struct{}

func NewModule() *Module { return &Module{} }

func (m *Module) Name() string { return "<name>" }

func (m *Module) Register(router module.Router, core module.CoreServices, cfg module.ModuleConfig, features module.FeatureRegistry) {
    s := store.New(cfg.DB)
    svc := service.New(s)
    h := handler.New(core.Auth(), svc)

    requireAuth := middleware.NewAuth(core.Auth())

    router.HandleFunc("GET /api/v1/<name>",      requireAuth(h.List))
    router.HandleFunc("POST /api/v1/<name>",     requireAuth(h.Create))
    router.HandleFunc("DELETE /api/v1/<name>/{id}", requireAuth(h.Delete))
}
```

### 8. cmd/api/main.go — add to module registration block

```go
engine.Register(<name>.NewModule())
```

## Checklist before marking done

- [ ] `store/store.go` — interface + struct + `New` only, zero implementations
- [ ] `service/service.go` — interface + struct + `New` + types + errors only, zero `func (s *svc)` methods
- [ ] `handler/handler.go` — `Handler` struct with `auth authport.Service` + `svc service.Service`, helpers
- [ ] Middleware bound once in `module.go`, never inside handlers
- [ ] SQL queries in `sql/queries/<name>.sql` — run `sqlc generate`
- [ ] Module registered in `main.go`
- [ ] No cross-feature imports — inter-feature deps via `FeatureRegistry.Get()` (see `/module-interface`)
