# Rule — module system

Referenced by `AGENTS.md` / `CLAUDE.md`. Detail of the "Module system" + "Imposed architecture" brick.

## Interfaces and wiring

- Interfaces live in `internal/core/module/module.go`. Wiring lives in `cmd/api/main.go`. No `func init()`.
- `CoreServices` exposes only **shared services** (e.g. `Auth()`, `Billing()`), never a feature-specific service.
- `ModuleConfig` groups all shared infra (DB, RawDB, Config, Ctx, Cache…) — a single parameter per `NewModule()`.

## Inter-module rules

- Modules **never import** other modules directly. Enforced automatically (blocking hook on edit + `make lint`).
- Any inter-feature dependency goes through `FeatureRegistry.Get("key")` or `CoreServices`.
- Adding an inter-module interface in `module.go` is a critical-file change: validate the design with the user first (see the `module-interface` skill).
- If a `FeatureRegistry` is received but never used, remove it — no dead code in core contracts.
- Map of existing interfaces: `docs/ARCHITECTURE.md`.

## Other structural rules

- **Middleware**: bound once in `module.go`, never inside handlers.
- **Config**: `NewModule(cfg module.ModuleConfig)` — never direct params (db, secret, timeout…).
- **Store**: the service receives a local interface, never `*database.Queries` directly.
- **Transactions**: expose a `Transactor` in the store — `*sql.DB` never leaks into the service.
- **Singletons**: no mutable global `var` — all state passes through `CoreServices` or `ModuleConfig`.

## File size

- A `.go` file > 300 lines (excluding generated `internal/database` and `_test.go`) → split it (SRP).
