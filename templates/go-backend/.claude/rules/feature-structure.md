# Rule — feature structure

Referenced by `AGENTS.md` / `CLAUDE.md`. Detail of the "Mandatory patterns" brick.
Scaffold a new feature with the `new-feature` skill.

## Uniform structure, no exception

**`handler/`**

- `handler.go` — struct, constructor, shared helpers (`writeJSON`, `writeError`, `claimsFromRequest`…).
- one file per endpoint: `create_user.go`, `delete_user.go`, etc.

**`service/`**

- `service.go` — **contract only**: the service interface, struct, constructor, internal types,
  domain errors. **No implementation method.** If a `func (s *service) xxx(...)` sits in
  `service.go`, it is a violation.
- one file per business action: `claim_slug.go`, `update_theme.go`, etc.
- if several actions form a coherent, lightweight group, a single group file is acceptable (`sections.go`).

> **CRITICAL RULE — handler / service separation:**
> A file is either a handler file or a service file. Never both.
> If a feature has a cross-cutting domain (e.g. an external provider), handlers go in
> `provider.go`, the service logic in `service_provider.go`. A `// --- service methods ---`
> block inside a handler file is an immediate violation.

**`store/`**

- `store.go` — the store interface, struct, constructor **only** — no implementation.
- methods grouped by entity in dedicated files: `profile.go`, `sections.go`, etc.
- exception: if a store implementation grows (complex transactions, heavy mapping logic), it moves
  to its own file even if it belongs to an existing group.

## Handler naming conventions

- Struct: `Handler`, constructor: `New`.
- Fields: `auth authport.Service` + `svc ResourceService`.
- Never `AuthSvc`, `authService`, `Service`, `Auth` as field names.

## Direct violations

- Implementation in `store/store.go` (contract only: interface + struct + constructor).
- Any `func (s *service) xxx(...)` in `service.go` — that file is a contract.
- Service code in a handler file, or handler code in a service file.
- Mixing several business actions in `service/service.go` (logic → separate files).
- A feature created without `handler/`, `service/`, `store/` subfolders.

## Documented exception

A feature may be **flat** (no `handler/service/store` subdirs) only if it is an explicitly documented
historical exception. Never replicate a flat feature for a new feature.
