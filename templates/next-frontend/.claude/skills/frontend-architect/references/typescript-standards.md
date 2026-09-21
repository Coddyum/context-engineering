# TypeScript Standards (Matt Pocock level)

## The Philosophy

TypeScript is not just a linter. It's a **design tool**. Types should:

1. Make impossible states impossible
2. Document intent better than comments
3. Enable refactoring without fear

## tsconfig.json — Non-negotiable settings

```json
{
  "compilerOptions": {
    "strict": true, // MANDATORY — enables all strict checks
    "noUncheckedIndexedAccess": true, // array[0] is T | undefined, not T
    "exactOptionalPropertyTypes": true, // { a?: string } ≠ { a: string | undefined }
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "moduleResolution": "bundler",
    "paths": {
      "@/*": ["./src/*"] // absolute imports
    }
  }
}
```

## Branded Types — Use them on IDs

```typescript
// ❌ Weak — any string can be passed as userId
function getUser(userId: string) {}
function getPost(postId: string) {}
getUser(somePostId) // TypeScript allows this — runtime bug

// ✅ Branded — impossible to mix up
type UserId = string & { readonly __brand: 'UserId' }
type PostId = string & { readonly __brand: 'PostId' }

function createUserId(id: string): UserId {
  return id as UserId // only one `as` — at the boundary
}

function getUser(userId: UserId) {}
getUser(somePostId) // TS Error: Type 'PostId' is not assignable to type 'UserId'
```

Create a `types/branded.ts` file with all branded IDs for the project.

## Zod — Runtime validation at every external boundary

```typescript
// ❌ Type cast — runtime bomb
const user = data as User

// ✅ Zod — validated at runtime, type inferred
import { z } from 'zod'

const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  createdAt: z.coerce.date(),
})

type User = z.infer<typeof UserSchema> // type flows from schema, not the other way

// At every API call boundary:
const response = await fetch('/api/users/1')
const raw = await response.json()
const user = UserSchema.parse(raw) // throws if invalid — fail fast
```

Rules:

- Schemas live next to their types, in `features/[x]/types.ts` or `types/schemas.ts`
- Use `z.infer<typeof Schema>` — never define types separately from schemas
- Use `.safeParse()` for user input (returns `{ success, data, error }`)
- Use `.parse()` for internal/API data (throws on invalid)

## Discriminated Unions — Replace boolean flags

```typescript
// ❌ Boolean soup — 4 booleans = 16 states, most impossible
interface RequestState {
  isLoading: boolean
  isError: boolean
  isSuccess: boolean
  data?: User
  error?: Error
}

// ✅ Discriminated union — only valid states exist
type RequestState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error }

// Exhaustive handling
function render(state: RequestState<User>) {
  switch (state.status) {
    case "idle": return <IdleState />
    case "loading": return <Spinner />
    case "success": return <UserCard user={state.data} />
    case "error": return <ErrorMessage error={state.error} />
    // TypeScript will error if you miss a case
  }
}
```

## Const assertions & satisfies

```typescript
// Use `satisfies` to validate shape without widening the type
const ROUTES = {
  home: '/',
  dashboard: '/dashboard',
  settings: '/settings',
} satisfies Record<string, string>

ROUTES.home // type: "/" (literal), not string
ROUTES.nonexistent // TS Error

// Use `as const` for arrays of known values
const ALLOWED_ROLES = ['admin', 'editor', 'viewer'] as const
type Role = (typeof ALLOWED_ROLES)[number] // "admin" | "editor" | "viewer"
```

## Zero `any` Policy

Every `any` must have a comment explaining why it's necessary. In practice, there are almost no valid reasons:

| You want to...                 | Use instead                                     |
| ------------------------------ | ----------------------------------------------- |
| Unknown API shape              | `unknown` + type guard                          |
| Dynamic object keys            | `Record<string, unknown>`                       |
| Generic function               | Proper generic `<T>`                            |
| Third-party lib with bad types | `@types/[lib]` or `declare module` augmentation |
| Escape hatch                   | `unknown` then narrow                           |

```typescript
// ❌ Lazy
function process(data: any) {
  return data.value
}

// ✅ Properly typed
function process<T extends { value: unknown }>(data: T): T['value'] {
  return data.value
}
```

## Utility Types Cheat Sheet

```typescript
Partial<T> // all props optional
Required<T> // all props required
Readonly<T> // no mutation
Pick<T, K> // subset of keys
Omit<T, K> // remove keys
Record<K, V> // map type
Exclude<T, U> // remove from union
Extract<T, U> // keep from union
NonNullable<T> // remove null/undefined
ReturnType<F> // infer function return
Parameters<F> // infer function params
Awaited<T> // unwrap Promise
```

## Component Props Patterns

```typescript
// Extend native elements properly
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant: 'primary' | 'ghost' | 'danger'
  isLoading?: boolean
}

// Polymorphic components (advanced)
type AsProp<C extends React.ElementType> = { as?: C }
type PropsWithAs<C extends React.ElementType, P = {}> = P &
  AsProp<C> &
  Omit<React.ComponentPropsWithRef<C>, keyof P | 'as'>
```
