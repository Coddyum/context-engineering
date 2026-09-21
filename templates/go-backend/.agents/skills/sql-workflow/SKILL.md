---
name: sql-workflow
description: >
  TRIGGER — use whenever the task involves a new database table, altering an existing table,
  or adding new SQL queries. Covers migration file creation, query conventions (sqlc),
  schema update, and the division of work between the coding agent and the human.
---

# SQL Workflow

## Division of work

The agent is autonomous here — it writes AND applies. No human hand-off.

| Who | Action |
|-----|--------|
| Agent | Write migration files in `sql/migrations/` |
| Agent | Write SQL queries in `sql/queries/<feature>.sql` |
| Agent | Update `sql/schema/` to reflect new state |
| Agent | Run `make up-dev` to apply the migration |
| Agent | Run `sqlc generate` after adding/changing queries |
| Agent | Use generated types from `internal/database/` in store implementations only |

NEVER hand-write `internal/database/*.go` — it is generated; run `sqlc generate` instead.
Applying to **production** (`make up-prod`, prod deploy/DB) is **human-only** unless the human
explicitly authorizes it — the `block-prod` hook enforces this. Everything above is dev/sandbox.

## Step 1 — Migration files

Location: `sql/migrations/`  
Naming: `NNNN_<snake_case_description>.up.sql` + `NNNN_<snake_case_description>.down.sql`  
`NNNN` = next sequential number — check `ls sql/migrations/` for current max.

```sql
-- 0025_my_feature.up.sql
CREATE TABLE my_feature (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX my_feature_user_id_idx ON my_feature(user_id);
```

```sql
-- 0025_my_feature.down.sql
DROP TABLE IF EXISTS my_feature;
```

Rules:
- Always provide both `.up.sql` and `.down.sql`
- `.down.sql` must cleanly undo everything in `.up.sql`
- Add indexes for every FK and any column used in WHERE clauses
- Use `ON DELETE CASCADE` for user-owned data, `ON DELETE SET NULL` for optional refs

## Step 2 — Update sql/schema/

`sql/schema/` is the source-of-truth snapshot of the DB state. After writing the migration, update or create the relevant schema file to reflect the new table/column state.

## Step 3 — SQL queries in sql/queries/<feature>.sql

Create file if it doesn't exist. One file per feature. Never put SQL in `.go` files.

```sql
-- name: CreateMyThing :one
INSERT INTO my_feature (user_id, name)
VALUES ($1, $2)
RETURNING *;

-- name: GetMyThingByUserID :many
SELECT * FROM my_feature
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: GetMyThingByID :one
SELECT * FROM my_feature
WHERE id = $1 AND user_id = $2;

-- name: DeleteMyThing :exec
DELETE FROM my_feature
WHERE id = $1 AND user_id = $2;
```

sqlc return modifiers:
- `:one` — returns single row
- `:many` — returns slice
- `:exec` — no return
- `:execrows` — returns `int64` affected row count (use when caller needs to know if row existed)

Use `sqlc.arg('name')` for named params when positional `$1` would be ambiguous:
```sql
WHERE profile_id = sqlc.arg('profile_id') AND module_type = sqlc.arg('module_type')
```

## Step 4 — Apply

After writing migrations and queries, apply them yourself:

```
make up-dev
sqlc generate
```

Never run `make up-prod` yourself — production is human-only unless explicitly authorized (the
`block-prod` hook blocks it; the human re-runs the approved command with `ALLOW_PROD=1`).

## Step 5 — Use generated types in store only

After `sqlc generate`, `internal/database/` has new types. Use them in store implementations:

```go
// store/<entity>.go
func (s *myStore) CreateThing(ctx context.Context, params database.CreateMyThingParams) (database.MyFeature, error) {
    return s.q.CreateMyThing(ctx, params)
}
```

Store interface in `store/store.go` uses these types. Service interface in `service/service.go` must NOT — map to internal types at the service layer.

## Checklist

- [ ] Both `.up.sql` and `.down.sql` written
- [ ] Migration number is sequential, no gaps or duplicates
- [ ] `sql/schema/` updated
- [ ] Queries in `sql/queries/<feature>.sql`, not in any `.go` file
- [ ] Applied: ran `make up-dev` then `sqlc generate`
- [ ] After generate: store uses `internal/database/` types, service does not
