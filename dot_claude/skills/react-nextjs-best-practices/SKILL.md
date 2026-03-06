---
name: react-nextjs-best-practices
description: React 19 and Next.js 16 App Router best practices. Covers Server/Client Components, data fetching, Server Actions, caching, performance optimization, bundle size reduction, waterfall elimination, accessibility, and production readiness.
---

# React & Next.js Best Practices

You are an expert React and Next.js engineer focused on performance, maintainability, and modern patterns.

## Core Philosophy

1. **"Don't give me your garbage"** — Minimize data sent to clients
2. **"Don't make me wait"** — Optimize perceived speed
3. **Server-first by default** — Use Server Components unless interactivity requires otherwise
4. **Measure before optimizing** — Profile to find actual bottlenecks
5. **Compose, don't modify** — Extend shadcn/ui components through composition

---

## 1. Server & Client Component Composition

### When to Use Server Components (Default)

- Data fetching from databases or APIs
- Accessing backend resources directly
- Keeping sensitive data (tokens, keys) server-side
- Heavy dependencies that don't need client-side interactivity

### When to Use Client Components (`'use client'`)

- Interactive UI (onClick, onChange, onSubmit)
- useState, useReducer, useEffect hooks
- Browser-only APIs (localStorage, geolocation)
- Custom hooks that depend on state/effects

### Composition Patterns

```tsx
// ✅ CORRECT: Server Component wrapping Client Components
// app/products/page.tsx (Server Component)
import { ProductList } from './product-list'
import { getProducts } from '@/lib/data'

export default async function ProductsPage() {
  const products = await getProducts() // Server-side fetch

  return (
    <main>
      <h1>Products</h1>
      <ProductList products={products} /> {/* Client Component */}
    </main>
  )
}
```

```tsx
// ✅ CORRECT: Client Component receiving serializable data
// app/products/product-list.tsx
'use client'

interface Props {
  products: Product[] // Serializable data from server
}

export function ProductList({ products }: Props) {
  const [filter, setFilter] = useState('')

  const filtered = products.filter(p =>
    p.name.toLowerCase().includes(filter.toLowerCase())
  )

  return (
    <>
      <input value={filter} onChange={e => setFilter(e.target.value)} />
      <ul>
        {filtered.map(p => <li key={p.id}>{p.name}</li>)}
      </ul>
    </>
  )
}
```

```tsx
// ❌ WRONG: Fetching in Client Component when Server Component works
'use client'

export function BadProductList() {
  const [products, setProducts] = useState([])

  useEffect(() => {
    fetch('/api/products').then(r => r.json()).then(setProducts)
  }, [])

  return <ul>{products.map(p => <li key={p.id}>{p.name}</li>)}</ul>
}
```

### Passing Server Components as Children

```tsx
// ✅ CORRECT: Server Component as children prop
// app/dashboard/layout.tsx
import { Sidebar } from './sidebar' // Client Component with state
import { UserStats } from './user-stats' // Server Component

export default function DashboardLayout({ children }) {
  return (
    <Sidebar>
      <UserStats /> {/* Server Component passed as children */}
      {children}
    </Sidebar>
  )
}
```

---

## 2. Data Fetching Patterns

### Caching Strategies

```typescript
// lib/data.ts

// Static data - cached indefinitely (default)
export async function getStaticContent() {
  const res = await fetch('https://api.example.com/content', {
    cache: 'force-cache', // Default, can be omitted
  })
  return res.json()
}

// Dynamic data - never cached
export async function getDynamicData() {
  const res = await fetch('https://api.example.com/data', {
    cache: 'no-store',
  })
  return res.json()
}

// Time-based revalidation
export async function getRevalidatedData() {
  const res = await fetch('https://api.example.com/data', {
    next: { revalidate: 3600 }, // Revalidate every hour
  })
  return res.json()
}

// Tag-based revalidation (for on-demand invalidation)
export async function getTaggedData() {
  const res = await fetch('https://api.example.com/products', {
    next: { tags: ['products'] },
  })
  return res.json()
}
```

### Parallel Data Fetching (CRITICAL)

```tsx
// ✅ CORRECT: Parallel fetches
export default async function DashboardPage() {
  // Start all fetches simultaneously
  const [user, posts, stats] = await Promise.all([
    getUser(),
    getPosts(),
    getStats(),
  ])

  return <Dashboard user={user} posts={posts} stats={stats} />
}
```

```tsx
// ❌ WRONG: Sequential fetches (waterfall)
export default async function DashboardPage() {
  const user = await getUser()       // Wait...
  const posts = await getPosts()     // Then wait...
  const stats = await getStats()     // Then wait again...

  return <Dashboard user={user} posts={posts} stats={stats} />
}
```

### Streaming with Suspense

```tsx
// ✅ CORRECT: Streaming slow data
import { Suspense } from 'react'

export default async function Page() {
  return (
    <main>
      <h1>Dashboard</h1>

      {/* Fast content renders immediately */}
      <QuickStats />

      {/* Slow content streams in */}
      <Suspense fallback={<ChartSkeleton />}>
        <SlowChart />
      </Suspense>

      <Suspense fallback={<TableSkeleton />}>
        <SlowDataTable />
      </Suspense>
    </main>
  )
}
```

---

## 3. Server Actions

### Form Handling with Zod Validation

```tsx
// app/actions.ts
'use server'

import { revalidatePath, revalidateTag } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'

const CreateProductSchema = z.object({
  name: z.string().min(1).max(100),
  price: z.coerce.number().positive(),
})

type ActionState = {
  errors?: { name?: string[]; price?: string[] }
  message?: string
} | null

export async function createProduct(
  prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  // 1. Validate input
  const parsed = CreateProductSchema.safeParse({
    name: formData.get('name'),
    price: formData.get('price'),
  })

  if (!parsed.success) {
    return { errors: parsed.error.flatten().fieldErrors }
  }

  // 2. Perform mutation
  const product = await db.products.create({ data: parsed.data })

  // 3. Revalidate cache
  revalidateTag('products')

  // 4. Redirect (optional)
  redirect(`/products/${product.id}`)
}
```

### Client Component Integration with useActionState

```tsx
// ✅ CORRECT: Using Server Action in Client Component
'use client'

import { useActionState } from 'react'
import { createProduct } from '@/app/actions'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

export function ProductForm() {
  const [state, formAction, isPending] = useActionState(createProduct, null)

  return (
    <form action={formAction} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="name">Product Name</Label>
        <Input id="name" name="name" disabled={isPending} />
        {state?.errors?.name && (
          <p className="text-sm text-destructive">{state.errors.name[0]}</p>
        )}
      </div>

      <div className="space-y-2">
        <Label htmlFor="price">Price</Label>
        <Input id="price" name="price" type="number" step="0.01" disabled={isPending} />
        {state?.errors?.price && (
          <p className="text-sm text-destructive">{state.errors.price[0]}</p>
        )}
      </div>

      <Button type="submit" disabled={isPending}>
        {isPending ? 'Creating...' : 'Create Product'}
      </Button>
    </form>
  )
}
```

### Optimistic Updates with useOptimistic

```tsx
'use client'

import { useOptimistic } from 'react'
import { addMessage } from '@/app/actions'

type Message = { id: string; text: string; pending?: boolean }

export function MessageThread({ messages }: { messages: Message[] }) {
  const [optimisticMessages, addOptimisticMessage] = useOptimistic<Message[], string>(
    messages,
    (state, newMessage) => [...state, { id: crypto.randomUUID(), text: newMessage, pending: true }]
  )

  const formAction = async (formData: FormData) => {
    const text = formData.get('message') as string
    addOptimisticMessage(text)
    await addMessage(text)
  }

  return (
    <div>
      {optimisticMessages.map((m) => (
        <div key={m.id} className={m.pending ? 'opacity-50' : ''}>
          {m.text}
        </div>
      ))}
      <form action={formAction}>
        <input type="text" name="message" />
        <button type="submit">Send</button>
      </form>
    </div>
  )
}
```

---

## 4. shadcn/ui Component Patterns

### Component Organization

```
src/components/
├── ui/                    # shadcn/ui base components (DO NOT MODIFY)
│   ├── button.tsx
│   ├── card.tsx
│   └── ...
├── domain/                # Domain-specific composed components
│   ├── booking/
│   │   ├── booking-card.tsx
│   │   ├── booking-form.tsx
│   │   └── index.ts
│   └── user/
│       ├── user-profile.tsx
│       └── index.ts
└── shared/                # Shared composed components
    ├── data-table.tsx
    └── confirm-dialog.tsx
```

### Composing shadcn/ui Components

```tsx
// ✅ CORRECT: Compose shadcn/ui components, don't modify them
// components/domain/booking/booking-button.tsx
import { Button, ButtonProps } from '@/components/ui/button'
import { CalendarIcon } from 'lucide-react'

interface BookingButtonProps extends ButtonProps {
  bookingDate?: Date
}

export function BookingButton({ bookingDate, children, ...props }: BookingButtonProps) {
  return (
    <Button variant="default" size="lg" {...props}>
      <CalendarIcon className="mr-2 h-4 w-4" />
      {children || 'Book Now'}
    </Button>
  )
}
```

```tsx
// ❌ WRONG: Modifying shadcn/ui components directly in /ui folder
// Never edit files in src/components/ui/ directly
```

### Using class-variance-authority (cva)

```tsx
// components/shared/status-badge.tsx
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const badgeVariants = cva(
  'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold',
  {
    variants: {
      status: {
        confirmed: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
        pending: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
        cancelled: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
      },
    },
    defaultVariants: {
      status: 'pending',
    },
  }
)

interface StatusBadgeProps extends VariantProps<typeof badgeVariants> {
  className?: string
  children: React.ReactNode
}

export function StatusBadge({ status, className, children }: StatusBadgeProps) {
  return (
    <span className={cn(badgeVariants({ status }), className)}>
      {children}
    </span>
  )
}
```

### Direct Imports (Tree Shaking)

```tsx
// ✅ CORRECT: Direct imports for tree shaking
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardHeader, CardContent } from '@/components/ui/card'

// ❌ WRONG: Barrel imports pull in everything
import { Button, Input, Card } from '@/components/ui'
```

---

## 5. Performance Optimization

### Eliminating Waterfalls (CRITICAL)

```tsx
// ❌ WRONG: Waterfall - each await blocks the next
export async function getPageData() {
  const user = await getUser()
  if (!user) return null // Early return is fine

  const profile = await getProfile(user.id)  // Waterfall!
  const settings = await getSettings(user.id) // More waterfall!

  return { user, profile, settings }
}

// ✅ CORRECT: Defer awaits until needed
export async function getPageData() {
  const userPromise = getUser()
  const user = await userPromise
  if (!user) return null

  // Now fetch dependent data in parallel
  const [profile, settings] = await Promise.all([
    getProfile(user.id),
    getSettings(user.id),
  ])

  return { user, profile, settings }
}
```

### Dynamic Imports for Heavy Components

```tsx
import dynamic from 'next/dynamic'

// Heavy chart library - only load when needed
const HeavyChart = dynamic(() => import('./heavy-chart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // Skip SSR if component uses browser APIs
})

// Rich text editor
const RichTextEditor = dynamic(
  () => import('@/components/shared/rich-text-editor'),
  { ssr: false }
)
```

### Re-render Optimization

```tsx
// ✅ CORRECT: Lazy state initialization
function SearchResults() {
  // Parse only once on mount
  const [filters] = useState(() => JSON.parse(localStorage.getItem('filters') || '{}'))

  return <Results filters={filters} />
}

// ❌ WRONG: Parse on every render
function SearchResults() {
  const [filters] = useState(JSON.parse(localStorage.getItem('filters') || '{}'))
  // ...
}
```

```tsx
// ✅ CORRECT: Memoization when profiling shows need
const ExpensiveList = memo(function ExpensiveList({ items, onSelect }) {
  return (
    <ul>
      {items.map(item => (
        <li key={item.id} onClick={() => onSelect(item)}>
          {item.name}
        </li>
      ))}
    </ul>
  )
})

// Use useCallback for handlers passed to memoized children
function Parent() {
  const [selected, setSelected] = useState(null)

  const handleSelect = useCallback((item) => {
    setSelected(item)
  }, [])

  return <ExpensiveList items={items} onSelect={handleSelect} />
}
```

---

## 6. State Management

### When to Use What

| Scenario                     | Solution                          |
| ---------------------------- | --------------------------------- |
| Component-local UI state     | `useState`                        |
| Complex component logic      | `useReducer`                      |
| Shared UI state (modals)     | React Context or Zustand          |
| Server data with caching     | Server Components or TanStack Query |
| Global app state             | Zustand or Jotai                  |
| Form state                   | React Hook Form                   |

### Colocation Principle

```tsx
// ✅ CORRECT: State close to where it's used
function SearchInput() {
  const [query, setQuery] = useState('')
  return <input value={query} onChange={e => setQuery(e.target.value)} />
}

// ❌ WRONG: Lifting state unnecessarily high
function App() {
  const [searchQuery, setSearchQuery] = useState('') // Used only in SearchInput!
  return (
    <>
      <Header />
      <SearchInput query={searchQuery} setQuery={setSearchQuery} />
      <Footer />
    </>
  )
}
```

### Context for Deeply Nested Data

```tsx
// ✅ CORRECT: Context for deeply nested data
const UserContext = createContext<User | null>(null)

export function UserProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)

  return (
    <UserContext.Provider value={user}>
      {children}
    </UserContext.Provider>
  )
}

export function useUser() {
  const context = useContext(UserContext)
  if (context === undefined) {
    throw new Error('useUser must be used within UserProvider')
  }
  return context
}
```

---

## 7. Advanced Routing Patterns

### Parallel Routes

```tsx
// app/layout.tsx - Slots for parallel routes
export default function Layout({
  children,
  modal,
  sidebar,
}: {
  children: React.ReactNode
  modal: React.ReactNode
  sidebar: React.ReactNode
}) {
  return (
    <div className="flex">
      <div className="w-64">{sidebar}</div>
      <main className="flex-1">
        {children}
        {modal}
      </main>
    </div>
  )
}

// app/@modal/(.)photo/[id]/page.tsx - Intercepted route as modal
import { Modal } from '@/components/ui/dialog'
import { PhotoDetail } from '@/components/photo-detail'

export default function PhotoModal({ params }: { params: { id: string } }) {
  return (
    <Modal>
      <PhotoDetail id={params.id} />
    </Modal>
  )
}
```

### generateStaticParams for Dynamic Routes

```tsx
// app/courses/[slug]/page.tsx
import { notFound } from 'next/navigation'
import { getCourse, getAllCourses } from '@/lib/data'

export async function generateStaticParams() {
  const courses = await getAllCourses()
  return courses.map((course) => ({ slug: course.slug }))
}

export async function generateMetadata({ params }: { params: { slug: string } }) {
  const course = await getCourse(params.slug)
  if (!course) return {}

  return {
    title: course.title,
    description: course.description,
    openGraph: { images: [course.image] },
  }
}

export default async function CoursePage({ params }: { params: { slug: string } }) {
  const course = await getCourse(params.slug)
  if (!course) notFound()

  return <CourseDetail course={course} />
}
```

---

## 8. Error Handling & Loading States

### Error Boundaries

```tsx
// app/products/error.tsx
'use client'

import { Button } from '@/components/ui/button'
import { AlertCircle } from 'lucide-react'

export default function ProductsError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-4 py-12">
      <AlertCircle className="h-12 w-12 text-destructive" />
      <h2 className="text-xl font-semibold">Something went wrong!</h2>
      <p className="text-muted-foreground">{error.message}</p>
      <Button onClick={reset}>Try again</Button>
    </div>
  )
}
```

### Loading States with Skeletons

```tsx
// app/products/loading.tsx
import { Skeleton } from '@/components/ui/skeleton'
import { Card, CardContent, CardHeader } from '@/components/ui/card'

export default function ProductsLoading() {
  return (
    <div className="grid grid-cols-3 gap-4">
      {Array.from({ length: 6 }).map((_, i) => (
        <Card key={i}>
          <CardHeader>
            <Skeleton className="h-4 w-2/3" />
          </CardHeader>
          <CardContent>
            <Skeleton className="h-32 w-full" />
            <Skeleton className="mt-2 h-4 w-1/2" />
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
```

---

## 9. Image & Asset Optimization

### Next.js Image Component

```tsx
import Image from 'next/image'

// For regular images
function ProductImage({ product }: { product: Product }) {
  return (
    <Image
      src={product.imageUrl}
      alt={product.name}
      width={300}
      height={200}
      placeholder="blur"
      blurDataURL={product.blurDataUrl}
      className="rounded-lg object-cover"
    />
  )
}

// For LCP (Largest Contentful Paint) images - use priority
function HeroImage() {
  return (
    <div className="relative h-96 w-full">
      <Image
        src="/hero.jpg"
        alt="Hero"
        fill
        priority // Preload for LCP
        sizes="100vw"
        className="object-cover"
      />
    </div>
  )
}
```

### Font Optimization

```tsx
// app/layout.tsx
import { Inter } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
})

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans">{children}</body>
    </html>
  )
}
```

---

## 10. Accessibility

### Semantic HTML First

```tsx
// ✅ CORRECT: Semantic elements
<nav aria-label="Main navigation">
  <ul>
    <li><Link href="/">Home</Link></li>
    <li><Link href="/courses">Courses</Link></li>
  </ul>
</nav>

<main>
  <article>
    <header>
      <h1>{post.title}</h1>
      <time dateTime={post.publishedAt}>{formattedDate}</time>
    </header>
    <section>{post.content}</section>
  </article>
</main>

// ❌ WRONG: Div soup
<div className="nav">
  <div className="nav-item">Home</div>
</div>
```

### Accessible Form Components

```tsx
// Using shadcn/ui Form components for accessibility
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'

function AccessibleInput({ id, label, error }: { id: string; label: string; error?: string }) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <Input
        id={id}
        name={id}
        aria-invalid={!!error}
        aria-describedby={error ? `${id}-error` : undefined}
      />
      {error && (
        <p id={`${id}-error`} className="text-sm text-destructive" role="alert">
          {error}
        </p>
      )}
    </div>
  )
}
```

---

## 11. Security

### Environment Variables

```bash
# .env.local (never commit)
DATABASE_URL=postgresql://...
STRIPE_SECRET_KEY=sk_...

# Client-safe variables (prefixed with NEXT_PUBLIC_)
NEXT_PUBLIC_APP_URL=https://...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_...
```

### Server Action Security

```tsx
// ✅ CORRECT: Validate everything in Server Actions
'use server'

import { auth } from '@/lib/auth'
import { z } from 'zod'

const UpdateProfileSchema = z.object({
  name: z.string().min(1).max(100),
  bio: z.string().max(500).optional(),
})

export async function updateProfile(prevState: any, formData: FormData) {
  // 1. Authenticate
  const session = await auth()
  if (!session) {
    throw new Error('Unauthorized')
  }

  // 2. Validate input
  const parsed = UpdateProfileSchema.safeParse({
    name: formData.get('name'),
    bio: formData.get('bio'),
  })

  if (!parsed.success) {
    return { errors: parsed.error.flatten().fieldErrors }
  }

  // 3. Authorize (user can only update own profile)
  // 4. Perform mutation
  await db.profiles.update({
    where: { userId: session.user.id },
    data: parsed.data,
  })

  revalidatePath('/profile')
  return { success: true }
}
```

---

## 12. Production Checklist

### Before Deployment

- [ ] Run `next build` locally to catch errors
- [ ] Run `next start` to test production behavior
- [ ] Run Lighthouse in incognito mode
- [ ] Check bundle size with `@next/bundle-analyzer`
- [ ] Verify all environment variables are set
- [ ] Test error pages (`error.tsx`, `not-found.tsx`)
- [ ] Test loading states (`loading.tsx`)
- [ ] Verify SEO metadata and Open Graph images
- [ ] Check Core Web Vitals (LCP, INP, CLS)

### Metadata Setup

```tsx
// app/layout.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: {
    default: 'BookMotion',
    template: '%s | BookMotion',
  },
  description: 'Sports and course booking platform',
  openGraph: {
    title: 'BookMotion',
    description: 'Sports and course booking platform',
    url: 'https://bookmotion.app',
    siteName: 'BookMotion',
    locale: 'en_US',
    type: 'website',
  },
}
```

### Sitemap & Robots

```tsx
// app/sitemap.ts
export default async function sitemap() {
  const courses = await getCourses()

  return [
    { url: 'https://bookmotion.app', lastModified: new Date() },
    { url: 'https://bookmotion.app/courses', lastModified: new Date() },
    ...courses.map(c => ({
      url: `https://bookmotion.app/courses/${c.slug}`,
      lastModified: c.updatedAt,
    })),
  ]
}

// app/robots.ts
export default function robots() {
  return {
    rules: { userAgent: '*', allow: '/' },
    sitemap: 'https://bookmotion.app/sitemap.xml',
  }
}
```

---

## Boundaries

### Always Do

- Use Server Components by default
- Fetch data in parallel with `Promise.all`
- Validate all inputs in Server Actions with Zod
- Use `date-fns` for date operations (never native Date)
- Run `npm run build` and `npm run lint` after changes
- Add loading and error states
- Compose shadcn/ui components, never modify them directly
- Use direct imports for tree shaking

### Ask First

- Before adding new npm dependencies
- Before using `'use client'` on a large component tree
- Before implementing complex caching strategies
- Before using experimental features
- Before modifying shadcn/ui base components

### Never Do

- Fetch data in `useEffect` when Server Component works
- Use barrel imports that defeat tree-shaking
- Skip input validation in Server Actions
- Forget to handle loading and error states
- Pass sensitive data to Client Components
- Use `any` type in TypeScript
- Modify files in `src/components/ui/` directly
