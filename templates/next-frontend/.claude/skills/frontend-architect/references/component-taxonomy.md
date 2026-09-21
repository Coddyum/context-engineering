# Component Taxonomy

## The Three Tiers — Non-Negotiable

```
components/
├── ui/           Tier 1 — Primitives
└── shared/       Tier 2 — Composites

features/
└── [name]/
    └── components/ Tier 3 — Domain components
```

---

## Tier 1 — Primitives (`components/ui/`)

**Definition**: Stateless, style-only, zero business logic, no domain vocabulary.

**Test**: Could this component ship in a public npm package and be useful to a completely different app? If yes → Primitive.

```
Button, Input, Textarea, Select, Checkbox, Radio
Badge, Tag, Chip
Avatar, Icon
Modal, Dialog, Drawer, Sheet
Tooltip, Popover
Spinner, Skeleton, Progress
Card (layout only, no content)
Table (layout only)
Tabs, Accordion
Alert, Toast (structure only)
```

**Rules:**

- Props must be generic (`variant`, `size`, `disabled`) — never domain-specific (`isAdmin`, `isPremium`)
- No `fetch` calls, no store access
- No domain type imports
- Must have a `className` / style override escape hatch
- Must be fully accessible (ARIA roles, keyboard nav)

```tsx
// ✅ Primitive — pure, reusable
interface BadgeProps {
  variant: 'success' | 'warning' | 'error' | 'neutral'
  size?: 'sm' | 'md'
  children: React.ReactNode
  className?: string
}

// ❌ Not a primitive — has domain knowledge
interface BadgeProps {
  status: UserStatus // domain type leaked into primitive
  isPremium: boolean // business logic in UI layer
}
```

---

## Tier 2 — Composites (`components/shared/`)

**Definition**: Compose multiple primitives, may have local UI state, no domain-specific API calls, cross-feature reusable.

**Test**: Is this component used by 2+ different features? Does it only use primitive props + generic callbacks? → Composite.

```
PageHeader (title + breadcrumb + actions slot)
DataTable (columns config + pagination + sorting)
SearchInput (Input + debounce + clear button)
FileUploader (drag & drop + preview + progress)
EmptyState (icon + title + description + optional CTA)
ConfirmDialog (Modal + confirm/cancel callbacks)
CommandPalette (search + keyboard nav + configurable items)
SidebarNav (nav structure + active state — layout only)
```

**Rules:**

- Props should accept render props or slots for customization (`renderActions`, `footer`)
- May use local `useState` for UI state (open/closed, filter query)
- No direct API calls — pass data as props, pass callbacks for mutations
- Types are generic or use utility types, not domain models

```tsx
// ✅ Composite — generic DataTable
interface DataTableProps<T> {
  data: T[]
  columns: ColumnDef<T>[]
  isLoading?: boolean
  onRowClick?: (row: T) => void
}

// ❌ Not a composite — domain coupled
interface UserTableProps {
  // Acceptable ONLY inside features/users/components/
  users: User[]
  onBanUser: (userId: UserId) => void
}
```

---

## Tier 3 — Domain Components (`features/[name]/components/`)

**Definition**: Business logic inside, domain types, may call feature-scoped hooks, scoped to one feature.

**Test**: Does this component know what a `User`, `Invoice`, `Project` is? Does it use feature-specific hooks? → Domain component.

```
features/users/components/
  UserCard.tsx        (displays user data with role badge)
  UserTable.tsx       (uses useUsers() hook)
  UserEditForm.tsx    (uses useMutation, knows UserSchema)
  UserAvatar.tsx      (fetches user avatar from store)

features/billing/components/
  InvoiceRow.tsx
  PlanComparisonCard.tsx
  PaymentMethodBadge.tsx
```

**Rules:**

- Can import from `features/[same-feature]/` freely
- Can import Tier 1 and Tier 2 components
- **Cannot** import from `features/[other-feature]/` directly — use shared types or props
- Must be exported from `features/[name]/index.ts` if used outside the feature

---

## The Index.ts Public API Pattern

```typescript
// features/users/index.ts — ONLY export what other features need
export { UserCard } from './components/UserCard'
export { UserAvatar } from './components/UserAvatar'
export type { User, UserId } from './types'

// Do NOT export internal implementation:
// ❌ export { useUserMutation } from "./hooks/useUserMutation"
// ❌ export { userQueryKeys } from "./api/queryKeys"
```

This is the **module boundary**. If another feature imports from inside `features/users/` bypassing `index.ts`, that's a coupling violation.

Enforce this with ESLint:

```json
// eslint rule: import/no-internal-modules
{
  "rules": {
    "import/no-internal-modules": ["error", { "forbid": ["features/*/!(index)*"] }]
  }
}
```

---

## Component File Structure (co-location)

```
features/users/components/UserCard/
├── UserCard.tsx          # component
├── UserCard.test.tsx     # tests co-located
├── UserCard.stories.tsx  # Storybook if used
└── index.ts              # re-export (avoids deep imports)
```

For simple components, single file is fine. Split into folder when you have tests + stories.

---

## Red Flags

| Pattern                                                           | Problem                                     |
| ----------------------------------------------------------------- | ------------------------------------------- |
| `components/UserDashboardAdminPanelCard.tsx`                      | No taxonomy, naming encodes hierarchy badly |
| `components/Button.tsx` imports from `features/users/`            | Primitive has domain dependency             |
| `features/billing/` imports directly from `features/users/hooks/` | Cross-feature coupling                      |
| 1 file with 400 lines and 3 exported components                   | Missing decomposition                       |
| Props like `mode="create" \| "edit" \| "view"` on one component   | Should be 3 components                      |
