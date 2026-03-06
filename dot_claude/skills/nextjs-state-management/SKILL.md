# Next.js State Management

Best practices for state management in Next.js 16+ applications using React Context, Zustand, and Server State patterns.

## When to Use What

| State Type | Solution | Use Case |
|------------|----------|----------|
| Server Data | Server Components + fetch | Data from database, initial page load |
| URL State | `useSearchParams`, `usePathname` | Filters, pagination, shareable state |
| Form State | React Hook Form + Zod | Form inputs, validation |
| UI State (local) | `useState` | Toggle, modal open, component-specific |
| UI State (shared) | Zustand | Calendar selection, sidebar state |
| Auth/Identity | React Context | User session, tenant, permissions |

## Decision Flow

```
Is it server data? → Server Components
Is it in the URL? → useSearchParams/usePathname
Is it form data? → React Hook Form
Is it local to one component? → useState
Is it identity/auth data? → React Context with server hydration
Is it shared UI state? → Zustand
```

---

## Zustand Best Practices

### 1. Export Custom Hooks Only

Never export the raw store. Create wrapper hooks to prevent subscribing to the entire store.

```typescript
// ❌ BAD: Exposes raw store
export const useStore = create<StoreState>((set) => ({ ... }))

// ✅ GOOD: Export only custom hooks
const useStore = create<StoreState>((set) => ({ ... }))

export const useBears = () => useStore((state) => state.bears)
export const useFish = () => useStore((state) => state.fish)
export const useActions = () => useStore((state) => state.actions)
```

### 2. Use Atomic Selectors

Select single values to minimize re-renders.

```typescript
// ❌ BAD: Creates new object every render, always re-renders
const { bears, fish } = useStore((state) => ({
  bears: state.bears,
  fish: state.fish,
}))

// ✅ GOOD: Atomic selectors, re-renders only when value changes
const bears = useStore((state) => state.bears)
const fish = useStore((state) => state.fish)

// ✅ GOOD: Use shallow when you need multiple values
import { useShallow } from 'zustand/shallow'

const { bears, fish } = useStore(
  useShallow((state) => ({ bears: state.bears, fish: state.fish }))
)
```

### 3. Separate Actions from State

Actions are static - group them in a namespace for easy access without re-render concerns.

```typescript
interface CalendarState {
  selectedDate: Date
  displayMode: 'week' | 'month' | 'day'
}

interface CalendarActions {
  setSelectedDate: (date: Date) => void
  setDisplayMode: (mode: CalendarState['displayMode']) => void
  goToToday: () => void
}

type CalendarStore = CalendarState & { actions: CalendarActions }

const useCalendarStore = create<CalendarStore>((set, get) => ({
  // State
  selectedDate: new Date(),
  displayMode: 'week',

  // Actions namespace
  actions: {
    setSelectedDate: (date) => set({ selectedDate: date }),
    setDisplayMode: (mode) => set({ displayMode: mode }),
    goToToday: () => set({ selectedDate: new Date() }),
  },
}))

// Export hooks
export const useSelectedDate = () => useCalendarStore((s) => s.selectedDate)
export const useDisplayMode = () => useCalendarStore((s) => s.displayMode)
export const useCalendarActions = () => useCalendarStore((s) => s.actions)
```

### 4. Model Actions as Events, Not Setters

Actions should describe what happened, not imperatively set values.

```typescript
// ❌ BAD: Imperative setters
actions: {
  setItems: (items) => set({ items }),
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error }),
}

// ✅ GOOD: Event-based actions
actions: {
  addToCart: (item) => set((state) => ({
    items: [...state.items, item]
  })),
  removeFromCart: (id) => set((state) => ({
    items: state.items.filter((i) => i.id !== id)
  })),
  checkout: () => set({ items: [], checkoutComplete: true }),
}
```

### 5. Keep Stores Small and Focused

Unlike Redux, Zustand encourages multiple small stores over one monolithic store.

```typescript
// ✅ GOOD: Separate stores for different domains
const useCalendarStore = create<CalendarStore>(...)
const useFilterStore = create<FilterStore>(...)
const useCartStore = create<CartStore>(...)

// Combine in hooks when needed
export function useFilteredCalendarData() {
  const selectedDate = useCalendarStore((s) => s.selectedDate)
  const filters = useFilterStore((s) => s.activeFilters)

  return useQuery({
    queryKey: ['calendar', selectedDate, filters],
    queryFn: () => fetchCalendarData(selectedDate, filters),
  })
}
```

### 6. Slices Pattern for Larger Stores

When a store grows, use slices for organization.

```typescript
import { create, StateCreator } from 'zustand'

// Define slice types
interface DateSlice {
  selectedDate: Date
  setSelectedDate: (date: Date) => void
}

interface ViewSlice {
  displayMode: 'week' | 'month'
  setDisplayMode: (mode: ViewSlice['displayMode']) => void
}

// Create slices
const createDateSlice: StateCreator<
  DateSlice & ViewSlice,
  [],
  [],
  DateSlice
> = (set) => ({
  selectedDate: new Date(),
  setSelectedDate: (date) => set({ selectedDate: date }),
})

const createViewSlice: StateCreator<
  DateSlice & ViewSlice,
  [],
  [],
  ViewSlice
> = (set) => ({
  displayMode: 'week',
  setDisplayMode: (mode) => set({ displayMode: mode }),
})

// Combine slices
const useCalendarStore = create<DateSlice & ViewSlice>()((...a) => ({
  ...createDateSlice(...a),
  ...createViewSlice(...a),
}))
```

---

## Next.js SSR Patterns

### 1. Hydration with Server Data

Pass initial state from Server Components to avoid hydration mismatches.

```typescript
// store.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface Store {
  count: number
  increment: () => void
}

export const useStore = create<Store>()(
  persist(
    (set) => ({
      count: 0,
      increment: () => set((s) => ({ count: s.count + 1 })),
    }),
    {
      name: 'app-storage',
      skipHydration: true, // Critical for SSR
    }
  )
)
```

```typescript
// Provider component
'use client'

import { useEffect, useRef } from 'react'
import { useStore } from './store'

export function StoreHydration({ initialCount }: { initialCount: number }) {
  const initialized = useRef(false)

  useEffect(() => {
    if (!initialized.current) {
      // Rehydrate from localStorage, then override with server data if needed
      useStore.persist.rehydrate()
      initialized.current = true
    }
  }, [])

  return null
}
```

### 2. Server Component Data → Client Store

```typescript
// page.tsx (Server Component)
async function CalendarPage() {
  const initialDate = new Date()
  const classes = await getClasses(initialDate)

  return (
    <CalendarProvider
      initialDate={initialDate}
      initialClasses={classes}
    >
      <CalendarClient />
    </CalendarProvider>
  )
}
```

```typescript
// CalendarProvider.tsx (Client Component)
'use client'

import { useEffect } from 'react'
import { useCalendarStore } from './store'

interface Props {
  children: React.ReactNode
  initialDate: Date
  initialClasses: Class[]
}

export function CalendarProvider({ children, initialDate, initialClasses }: Props) {
  const setInitialState = useCalendarStore((s) => s.setInitialState)

  useEffect(() => {
    setInitialState(initialDate, initialClasses)
  }, [initialDate, initialClasses, setInitialState])

  return <>{children}</>
}
```

---

## React Context Patterns

Use Context for identity data that rarely changes and needs to be available everywhere.

### Server-Hydrated Context

```typescript
// context.tsx
'use client'

import { createContext, useContext, ReactNode } from 'react'

interface TenantContextType {
  tenant: Tenant | null
  refreshTenant: () => Promise<void>
}

const TenantContext = createContext<TenantContextType | undefined>(undefined)

interface Props {
  children: ReactNode
  initialTenant: Tenant | null  // From server
}

export function TenantProvider({ children, initialTenant }: Props) {
  // No useState needed - data comes from server, refresh via router.refresh()
  const refreshTenant = async () => {
    // Trigger server re-fetch
    window.location.reload()
  }

  return (
    <TenantContext.Provider value={{ tenant: initialTenant, refreshTenant }}>
      {children}
    </TenantContext.Provider>
  )
}

export function useTenant() {
  const context = useContext(TenantContext)
  if (!context) {
    throw new Error('useTenant must be used within TenantProvider')
  }
  return context
}

// Granular hooks prevent unnecessary re-renders
export const useTenantId = () => useTenant().tenant?.id ?? null
```

### Layout Integration

```typescript
// layout.tsx (Server Component)
export default async function Layout({ children }: { children: ReactNode }) {
  const tenant = await getTenant()
  const permissions = await getPermissions()

  return (
    <TenantProvider initialTenant={tenant}>
      <PermissionsProvider initialPermissions={permissions}>
        {children}
      </PermissionsProvider>
    </TenantProvider>
  )
}
```

---

## Anti-Patterns to Avoid

### 1. Putting Server Data in Client State

```typescript
// ❌ BAD: Duplicating server data in client store
const useStore = create((set) => ({
  users: [],
  fetchUsers: async () => {
    const users = await fetch('/api/users')
    set({ users })
  },
}))

// ✅ GOOD: Keep server data in Server Components or use React Query
async function UsersPage() {
  const users = await getUsers() // Server Component
  return <UserList users={users} />
}
```

### 2. Global Store for Everything

```typescript
// ❌ BAD: Monolithic store
const useAppStore = create((set) => ({
  user: null,
  theme: 'light',
  cart: [],
  notifications: [],
  modalOpen: false,
  sidebarOpen: true,
  // ... 50 more properties
}))

// ✅ GOOD: Separate concerns
const useThemeStore = create(...)    // UI preferences
const useCartStore = create(...)     // Shopping cart
const useUIStore = create(...)       // Transient UI state
// Auth/user → React Context with server hydration
```

### 3. Subscribing to Entire Store

```typescript
// ❌ BAD: Re-renders on ANY state change
function Component() {
  const store = useStore() // Subscribes to everything
  return <div>{store.bears}</div>
}

// ✅ GOOD: Subscribe only to what you need
function Component() {
  const bears = useStore((state) => state.bears)
  return <div>{bears}</div>
}
```

### 4. Derived State in Components

```typescript
// ❌ BAD: Calculating derived state in every component
function Component() {
  const items = useStore((s) => s.items)
  const total = items.reduce((sum, i) => sum + i.price, 0) // Recalculated every render
}

// ✅ GOOD: Compute in selector or store
function Component() {
  const total = useStore((s) =>
    s.items.reduce((sum, i) => sum + i.price, 0)
  )
}

// ✅ BETTER: Memoized selector
const selectTotal = (state: Store) =>
  state.items.reduce((sum, i) => sum + i.price, 0)

function Component() {
  const total = useStore(selectTotal)
}
```

### 5. Side Effects in Selectors

```typescript
// ❌ BAD: Side effects in selector
const data = useStore((state) => {
  console.log('Selected!') // Runs on every render
  fetch('/api/log')        // Never do this
  return state.data
})

// ✅ GOOD: Pure selectors, effects in useEffect or actions
const data = useStore((state) => state.data)

useEffect(() => {
  console.log('Data changed:', data)
}, [data])
```

---

## TypeScript Patterns

### Store with Proper Types

```typescript
import { create } from 'zustand'

// Separate state and actions interfaces
interface BookingState {
  selectedClassId: string | null
  selectedDate: Date | null
  step: 'select' | 'confirm' | 'complete'
}

interface BookingActions {
  selectClass: (classId: string) => void
  selectDate: (date: Date) => void
  nextStep: () => void
  reset: () => void
}

type BookingStore = BookingState & { actions: BookingActions }

const initialState: BookingState = {
  selectedClassId: null,
  selectedDate: null,
  step: 'select',
}

const useBookingStore = create<BookingStore>((set) => ({
  ...initialState,

  actions: {
    selectClass: (classId) => set({ selectedClassId: classId }),
    selectDate: (date) => set({ selectedDate: date }),
    nextStep: () => set((state) => {
      const steps: BookingState['step'][] = ['select', 'confirm', 'complete']
      const currentIndex = steps.indexOf(state.step)
      const nextStep = steps[currentIndex + 1] ?? state.step
      return { step: nextStep }
    }),
    reset: () => set(initialState),
  },
}))

// Typed selector hooks
export const useSelectedClassId = () => useBookingStore((s) => s.selectedClassId)
export const useSelectedDate = () => useBookingStore((s) => s.selectedDate)
export const useBookingStep = () => useBookingStore((s) => s.step)
export const useBookingActions = () => useBookingStore((s) => s.actions)
```

---

## Combining with Data Fetching

### Zustand + Server Actions

```typescript
'use client'

import { useTransition } from 'react'
import { useBookingActions, useSelectedClassId } from './store'
import { createBooking } from '@/app/actions/bookings'

export function BookButton() {
  const [isPending, startTransition] = useTransition()
  const classId = useSelectedClassId()
  const { reset } = useBookingActions()

  const handleBook = () => {
    if (!classId) return

    startTransition(async () => {
      const result = await createBooking({ classId })
      if (result.success) {
        reset()
      }
    })
  }

  return (
    <button onClick={handleBook} disabled={isPending || !classId}>
      {isPending ? 'Booking...' : 'Book Now'}
    </button>
  )
}
```

### Zustand Filters + React Query

```typescript
import { useQuery } from '@tanstack/react-query'

// Filter store
const useFilterStore = create<FilterStore>((set) => ({
  classType: null,
  location: null,
  dateRange: null,
  actions: {
    setClassType: (type) => set({ classType: type }),
    setLocation: (loc) => set({ location: loc }),
    setDateRange: (range) => set({ dateRange: range }),
    clearFilters: () => set({ classType: null, location: null, dateRange: null }),
  },
}))

// Combined hook
export function useFilteredClasses() {
  const classType = useFilterStore((s) => s.classType)
  const location = useFilterStore((s) => s.location)
  const dateRange = useFilterStore((s) => s.dateRange)

  return useQuery({
    queryKey: ['classes', { classType, location, dateRange }],
    queryFn: () => fetchClasses({ classType, location, dateRange }),
  })
}
```

---

## Summary Checklist

- [ ] Server data stays in Server Components (don't duplicate in client state)
- [ ] URL state for shareable/bookmarkable values
- [ ] Zustand for shared UI state only
- [ ] React Context for auth/identity with server hydration
- [ ] Export custom hooks, never raw stores
- [ ] Use atomic selectors (one value per selector)
- [ ] Group actions in namespace
- [ ] Keep stores small and focused
- [ ] Use `skipHydration: true` for SSR with persist middleware
- [ ] Model actions as events, not setters
