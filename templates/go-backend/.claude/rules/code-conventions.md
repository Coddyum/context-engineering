# Rule — code conventions

Referenced by `AGENTS.md` / `CLAUDE.md`. Detail of the "Code conventions" brick.

## Naming

> If a variable, function or file name needs a comment to be understood, the name is bad. Rename first.

- Explicit names (`userSessionStore` > `uss`, `createUserHandler` > `cuh`).
- Files named by a single, clear responsibility.

## Error handling

- A log must let you know **what** failed, **where**, and **why** without digging through the code.
- Always wrap with context: `fmt.Errorf("user store: get by id %s: %w", id, err)`.
- **`log.Fatal` forbidden outside `main.go`** and startup initialization.
- No `panic` in business logic.

## Principles

- **Performance**: no useless work, no avoidable allocation.
- **DRY**: if a pattern repeats more than twice, extract it.
- **SRP**: each file, function, type has a single responsibility.
- No over-engineering: if the simple solution is enough, it is the right one.

## General style

- Idiomatic Go (`errors.Is`/`errors.As`, small focused interfaces, table-driven tests).
- No `interface{}` / `any` unless an absolute justified need.
- No ORM.
- No `func init()`.
