# Next.js App Router Patterns

## RSC vs Client Components — Decision Tree

```
Does this component...
├── Use onClick / onChange / event handlers?         → Client
├── Use useState / useEffect / useReducer?           → Client
├── Use browser APIs (window, localStorage)?         → Client
├── Use third-party libs that require browser?       → Client
└── None of the above?                              → RSC (default)
```

**The rule**: push `"use client"` as far down the tree as possible. The boundary should be at the leaves, not the root.

### Anti-patterns

```tsx
// ❌ Entire route is client — you lose RSC benefits
"use client"
export default function DashboardPage() {
  const { data } = useQuery(...)  // server could have fetched this
  return <div>...</div>
}

// ✅ RSC fetches, client component handles interactivity
// app/dashboard/page.tsx (RSC)
export default async function DashboardPage() {
  const data = await fetchDashboardData()  // runs on server
  return <DashboardClient initialData={data} />
}

// features/dashboard/components/DashboardClient.tsx
"use client"
export function DashboardClient({ initialData }) {
  const [state, setState] = useState(initialData)
  // interactivity here
}
```

## Caching Strategy

| Pattern                                    | When to use                            |
| ------------------------------------------ | -------------------------------------- |
| `fetch(url)` with default cache            | Static data, changes rarely            |
| `fetch(url, { cache: 'no-store' })`        | Real-time data, per-request            |
| `fetch(url, { next: { revalidate: 60 } })` | ISR — fresh every N seconds            |
| `unstable_cache()`                         | Cache non-fetch async operations       |
| TanStack Query on client                   | User-specific, interactive, optimistic |

## File Conventions Checklist

Every route segment should have:

- `page.tsx` — the route (RSC by default)
- `layout.tsx` — shared UI wrapper (RSC by default)
- `loading.tsx` — Suspense fallback (shown during async RSC)
- `error.tsx` — Error boundary (`"use client"` required)
- `not-found.tsx` — 404 fallback

Critical: `loading.tsx` and `error.tsx` at the root `app/` level are non-optional for production apps.

## Parallel Routes & Intercepting Routes

Use parallel routes (`@slot`) for:

- Dashboards with independent loading states
- Modals that need their own URL (intercepting routes `(.)route`)

Do not use them prematurely — they add complexity.

## Route Groups

```
app/
├── (marketing)/        # No URL impact — grouping only
│   ├── layout.tsx      # Marketing-specific layout
│   └── about/
├── (app)/              # Authenticated section
│   ├── layout.tsx      # Auth guard layout
│   └── dashboard/
```

Use route groups to apply different layouts to different sections without affecting URLs.

## Server Actions

```tsx
// app/actions/user.ts
"use server"
export async function updateUser(formData: FormData) {
  // runs on server, can access DB directly
  const name = formData.get("name") as string
  await db.user.update(...)
  revalidatePath("/profile")
}
```

Rules:

- Always validate input with Zod inside server actions
- Never trust FormData types — always parse
- Use `revalidatePath` or `revalidateTag` to bust cache after mutations
- Prefer server actions over API routes for mutations from RSC pages
