# Data Fetching Contract

## The Three-Layer Architecture

```
┌─────────────────────────────────┐
│  Components / Pages             │  ← consumes hooks, renders UI
├─────────────────────────────────┤
│  Hooks (TanStack Query)         │  ← caching, loading states, mutations
├─────────────────────────────────┤
│  Services (API functions)       │  ← HTTP calls, Zod validation, error mapping
└─────────────────────────────────┘
```

Each layer only knows about the layer directly below it.

---

## Layer 1 — Services (`services/` or `features/[x]/api/`)

**Job**: Talk to the network. Parse the response. Throw typed errors. Know nothing about React.

```typescript
// services/api-client.ts — one wrapper around native fetch, used by every service.
//
// No HTTP library. What a library buys here — base URL, auth header, a 401 retry — is
// thirty lines, and those thirty lines are the ones you will want to read when a token
// refresh misbehaves at 2 a.m.

const BASE = process.env.NEXT_PUBLIC_API_URL

export async function fetchWithAuth(path: string, init: RequestInit = {}): Promise<Response> {
  const run = () =>
    fetch(`${BASE}${path}`, {
      ...init,
      credentials: 'include',
      headers: { 'Content-Type': 'application/json', ...init.headers },
    })

  let response = await run()

  // Refresh once on an expired token, then replay the original request. Callers write
  // no retry logic — which is the point: the fifth caller would write it differently.
  if (response.status === 401 && (await isTokenExpired(response.clone()))) {
    await refreshToken()
    response = await run()
  }

  if (!response.ok) throw new ApiError(response.status, await errorCode(response), path)
  return response
}
```

```typescript
// features/users/api/users.api.ts
import { z } from 'zod'
import { apiClient } from '@/services/api-client'

const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string(),
  createdAt: z.coerce.date(),
})

export type User = z.infer<typeof UserSchema>

// Pure async functions — no React, no hooks, no state
export async function fetchUser(userId: string): Promise<User> {
  const raw = await apiClient.get(`users/${userId}`).json()
  return UserSchema.parse(raw) // throws ApiValidationError if invalid
}

export async function updateUser(
  userId: string,
  data: Pick<User, 'name' | 'email'>
): Promise<User> {
  const raw = await apiClient.patch(`users/${userId}`, { json: data }).json()
  return UserSchema.parse(raw)
}
```

**Rules:**

- Always validate response with Zod — never `as User`
- Return domain types, not raw HTTP responses
- Throw domain errors, not raw `fetch` errors
- No `useState`, no hooks, no React imports

---

## Layer 2 — Hooks (`features/[x]/hooks/`)

**Job**: Wrap services with TanStack Query. Provide loading/error states. Handle cache invalidation.

```typescript
// features/users/hooks/useUser.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchUser, updateUser } from '../api/users.api'
import type { User } from '../api/users.api'

// Query keys — typed, centralized, never hardcoded strings
export const userQueryKeys = {
  all: ['users'] as const,
  detail: (id: string) => ['users', id] as const,
  list: (filters: UserFilters) => ['users', 'list', filters] as const,
}

export function useUser(userId: string) {
  return useQuery({
    queryKey: userQueryKeys.detail(userId),
    queryFn: () => fetchUser(userId),
    staleTime: 1000 * 60 * 5, // 5 minutes
  })
}

export function useUpdateUser() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ userId, data }: { userId: string; data: Partial<User> }) =>
      updateUser(userId, data),

    // Optimistic update
    onMutate: async ({ userId, data }) => {
      await queryClient.cancelQueries({ queryKey: userQueryKeys.detail(userId) })
      const previous = queryClient.getQueryData<User>(userQueryKeys.detail(userId))
      queryClient.setQueryData(userQueryKeys.detail(userId), (old: User) => ({
        ...old,
        ...data,
      }))
      return { previous } // for rollback
    },

    onError: (err, { userId }, context) => {
      // Rollback on error
      if (context?.previous) {
        queryClient.setQueryData(userQueryKeys.detail(userId), context.previous)
      }
    },

    onSettled: (_, __, { userId }) => {
      queryClient.invalidateQueries({ queryKey: userQueryKeys.detail(userId) })
    },
  })
}
```

**Rules:**

- Query keys are typed arrays — never bare strings like `["getUser", id]`
- `staleTime` is always set explicitly — never rely on default 0
- Mutations implement optimistic updates for UX-critical operations
- Hooks export only what components need — not internal QueryClient calls

---

## Layer 3 — Components

**Job**: Consume hooks. Render UI. No direct API calls.

```tsx
// features/users/components/UserProfile.tsx
import { useUser, useUpdateUser } from '../hooks/useUser'

interface UserProfileProps {
  userId: string
}

export function UserProfile({ userId }: UserProfileProps) {
  const { data: user, isLoading, isError } = useUser(userId)
  const { mutate: updateUser, isPending } = useUpdateUser()

  if (isLoading) return <UserProfileSkeleton />
  if (isError) return <ErrorState message="Failed to load user" />

  return (
    <div>
      <h1>{user.name}</h1>
      <button
        onClick={() => updateUser({ userId, data: { name: 'New Name' } })}
        disabled={isPending}
      >
        Update
      </button>
    </div>
  )
}
```

**Rules:**

- Never `fetch()` directly inside a component
- Never import from `services/` directly — always go through hooks
- Destructure what you need from the hook — don't spread the whole result

---

## RSC Data Fetching (App Router)

For RSC pages, bypass TanStack Query entirely for initial data:

```tsx
// app/users/[id]/page.tsx (RSC — runs on server)
import { fetchUser } from '@/features/users/api/users.api'
import { UserProfile } from '@/features/users/components/UserProfile'

export default async function UserPage({ params }: { params: { id: string } }) {
  // Direct service call — no hook needed, no loading state needed
  const user = await fetchUser(params.id)
  // Pass as prop to client component that may need interactivity
  return <UserProfile user={user} />
}
```

```tsx
// UserProfile.tsx — receives pre-fetched data
'use client'
interface UserProfileProps {
  user: User // pre-fetched by RSC
}
// Uses useUpdateUser() for mutations only — no initial fetch needed
```

---

## Error Handling Contract

Define typed API errors at the service layer:

```typescript
// types/errors.ts
export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

export class ValidationError extends Error {
  constructor(public issues: z.ZodIssue[]) {
    super('Validation failed')
    this.name = 'ValidationError'
  }
}
```

Handle at the hook layer with `onError`, and surface to users with a consistent toast/alert system — never `console.error` in production.

---

## Anti-patterns

| Pattern                                  | Problem                               | Fix                                     |
| ---------------------------------------- | ------------------------------------- | --------------------------------------- |
| `fetch()` inside `useEffect`             | Race conditions, no caching, no dedup | TanStack Query                          |
| `useState` for server data               | Duplication with server cache         | TanStack Query or RSC                   |
| `as User` after fetch                    | Runtime bomb                          | Zod `.parse()`                          |
| Query key as bare string `"users"`       | Collision risk, no type safety        | Typed array `["users", id]`             |
| Loading state in multiple components     | Waterfall                             | Co-locate with data, use Suspense       |
| `queryClient.invalidateQueries("users")` | Too broad — refreshes everything      | Specific key `userQueryKeys.detail(id)` |
