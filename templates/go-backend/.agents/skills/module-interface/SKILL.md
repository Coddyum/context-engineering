---
name: module-interface
description: >
  TRIGGER — use when a feature needs to call into another feature without importing it directly.
  Covers declaring the interface in module.go, registering it from the publisher, and resolving
  it lazily in the consumer. module.go is a critical file — always validate design with the user
  before adding a new interface.
---

# Inter-Module Interface

## When to use

Feature A needs a capability from feature B. Direct import is forbidden (no cross-feature imports).
Pattern: declare interface in `module.go`, B registers it, A resolves via `FeatureRegistry.Get`.

## Step-by-step

### 1. Validate with user first

Adding to `module.go` is a shared contract change. Confirm:
- Is there no simpler way (CoreServices, passing via ModuleConfig)?
- Is the interface minimal — only the methods the consumer actually needs?

### 2. Declare in `internal/core/module/module.go`

```go
// XyzNotifier is optionally registered by the xyz feature under the key
// "xyz.notifier". The <consumer> feature calls it to <describe purpose>.
type XyzNotifier interface {
    NotifyX(ctx context.Context, userID uuid.UUID, data string) error
}
```

Rules:
- Godoc comment must state: who registers it, registry key, who calls it, why
- Interface methods: minimal — only what the consumer actually uses
- Group near related interfaces in the file (by feature domain)

### 3. Register in the publisher (feature B's module.go)

```go
func (m *Module) Register(..., features module.FeatureRegistry) {
    svc := service.New(...)

    if r, ok := features.(interface{ Set(string, any) }); ok {
        r.Set("xyz.notifier", svc)
    }
}
```

The `Set` cast is required because `FeatureRegistry` only exposes `Get` publicly.
The service struct must implement the interface — Go will catch this at compile time.

### 4. Resolve in the consumer

**Option A — resolve at registration time** (B always registers before A, or B is mandatory):
```go
// In feature A's module.go
var notifier module.XyzNotifier
if n, ok := features.Get("xyz.notifier").(module.XyzNotifier); ok {
    notifier = n
}
svc := serviceA.New(s, notifier) // notifier may be nil — guard in service
```

**Option B — lazy resolution** (B may register after A, or is optional):
```go
// In feature A's service/service.go — local mirror to avoid importing module package
type xyzNotifier interface {
    NotifyX(ctx context.Context, userID uuid.UUID, data string) error
}

type featureRegistry interface {
    Get(name string) any
}

type svc struct {
    store    store.Store
    features featureRegistry
}

// In the action file, resolve on first use:
func (s *svc) DoThing(ctx context.Context, ...) error {
    if n, ok := s.features.Get("xyz.notifier").(xyzNotifier); ok {
        _ = n.NotifyX(ctx, ...)
    }
    // ...
}
```

The local mirror interface (`xyzNotifier`) avoids importing the `module` package from a feature service.

### 5. Always guard for nil

```go
if notifier != nil {
    notifier.NotifyX(ctx, ...)
}
```

Never assume the publisher is registered — any module can be absent.

## Shapes this pattern takes

Three recurring shapes, to recognise which one you are writing:

- **Notifier** — feature A finishes something, feature B wants to hear about it.
  `module.XNotifier`, key `"x.notifier"`, one fire-and-forget method returning only an error.
- **Cleaner** — feature A owns a resource feature B creates references to. B calls A before
  deleting, so the resource does not outlive its last reference. Key `"x.cleaner"`.
- **Initializer** — feature A must seed state in feature B the first time an entity exists
  (a user, a workspace). Called once, idempotent. Key `"x.initializer"`.

Record each one you add in `docs/ARCHITECTURE.md` — the file is the map of what the registry holds.

## Checklist

- [ ] Design validated with user before touching `module.go`
- [ ] Interface declared with full godoc comment (who, key, caller, why)
- [ ] Registry key follows pattern `"<feature>.<role>"` (e.g. `"billing.notifier"`)
- [ ] Publisher uses `features.(interface{ Set(string, any) })` cast
- [ ] Consumer guards for nil / absent interface
- [ ] Local mirror interface used in service layer (avoids module package import)
