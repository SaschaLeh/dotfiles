---
name: supabase-security
description: Securing Supabase applications at the API and application layer. Covers JWT handling, input validation with Zod, SQL injection prevention, rate limiting, file upload validation, storage bucket security, and CORS configuration.
---

# Supabase Application Security

You are a security expert for Supabase applications, focusing on API and application-layer security.

> **Note:** For Row Level Security (RLS) policies, see the `supabase-rls-policies` skill.

## 1. Authentication Security

### JWT Handling

```typescript
// Edge Function: Verify JWT
import { createClient } from '@supabase/supabase-js';

export async function handler(req: Request) {
  const authHeader = req.headers.get('Authorization');

  if (!authHeader?.startsWith('Bearer ')) {
    return new Response('Unauthorized', { status: 401 });
  }

  const token = authHeader.substring(7);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } }
  );

  const { data: { user }, error } = await supabase.auth.getUser(token);

  if (error || !user) {
    return new Response('Invalid token', { status: 401 });
  }

  // User is authenticated
  return new Response(`Hello, ${user.id}`);
}
```

### Key Management

| Key | Usage | Security |
|-----|-------|----------|
| `anon` key | Client-side, public | RLS protects data |
| `service_role` key | Server-side only | Bypasses RLS |

```typescript
// CORRECT: anon key on client
const supabase = createClient(url, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);

// CORRECT: service_role on server only
const adminSupabase = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY);

// WRONG: Never expose service_role to client
// This bypasses all security!
```

### Session Management

```typescript
// Use HTTP-only cookies for sessions (Next.js example)
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        },
      },
    }
  );
}
```

## 2. Input Validation

### Zod Schema Validation

```typescript
import { z } from 'zod';

// Define schema
const bookingSchema = z.object({
  classId: z.string().uuid(),
  date: z.string().datetime(),
  notes: z.string().max(500).optional(),
  attendees: z.number().int().min(1).max(10),
});

// Validate in server action
export async function createBooking(formData: FormData) {
  const raw = {
    classId: formData.get('classId'),
    date: formData.get('date'),
    notes: formData.get('notes'),
    attendees: Number(formData.get('attendees')),
  };

  const result = bookingSchema.safeParse(raw);

  if (!result.success) {
    return { error: result.error.flatten() };
  }

  // Safe to use result.data
  const { classId, date, notes, attendees } = result.data;
  // ... create booking
}
```

### Edge Function Validation

```typescript
import { z } from 'zod';

const requestSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const result = requestSchema.safeParse(body);

    if (!result.success) {
      return new Response(
        JSON.stringify({ error: result.error.issues }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const { email, password } = result.data;
    // ... process validated data

  } catch {
    return new Response(
      JSON.stringify({ error: 'Invalid request body' }),
      { status: 400 }
    );
  }
});
```

## 3. SQL Injection Prevention

### Always Use Parameterized Queries

```typescript
// SAFE: Supabase client parameterizes automatically
const { data } = await supabase
  .from('profiles')
  .select('*')
  .eq('user_id', userId);  // userId is safely parameterized

// SAFE: Using .rpc() with parameters
const { data } = await supabase
  .rpc('search_users', { search_term: userInput });
```

```sql
-- SAFE: Database function with parameters
create function search_users(search_term text)
returns setof profiles
language sql
security invoker
set search_path = ''
as $$
  select * from public.profiles
  where name ilike '%' || search_term || '%';
$$;
```

### Never Concatenate User Input

```typescript
// DANGEROUS: SQL injection vulnerability
const query = `SELECT * FROM profiles WHERE name = '${userInput}'`;

// User input: "'; DROP TABLE profiles; --"
// Results in: SELECT * FROM profiles WHERE name = ''; DROP TABLE profiles; --'
```

## 4. Rate Limiting

### Edge Function with Upstash Redis

```typescript
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: Deno.env.get('UPSTASH_REDIS_URL')!,
  token: Deno.env.get('UPSTASH_REDIS_TOKEN')!,
});

const ratelimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '60 s'), // 10 requests per minute
});

Deno.serve(async (req) => {
  const ip = req.headers.get('x-forwarded-for') ?? '127.0.0.1';
  const { success, reset } = await ratelimit.limit(ip);

  if (!success) {
    const retryAfter = Math.ceil((reset - Date.now()) / 1000);
    return new Response('Rate limit exceeded', {
      status: 429,
      headers: { 'Retry-After': retryAfter.toString() },
    });
  }

  // Process request...
});
```

### Rate Limit by User

```typescript
// Limit per authenticated user
const userId = user?.id ?? ip;
const { success } = await ratelimit.limit(`user:${userId}`);
```

## 5. Storage Security

### Bucket Access Control

```sql
-- Private bucket: RLS on storage.objects
alter table storage.objects enable row level security;

-- Users can only access their own files
create policy "Users access own files"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars' and
    (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users upload to own folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars' and
    (storage.foldername(name))[1] = (select auth.uid())::text
  );
```

### File Upload Validation

```typescript
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

async function uploadAvatar(file: File, userId: string) {
  // Validate file type
  if (!ALLOWED_TYPES.includes(file.type)) {
    throw new Error('Invalid file type. Allowed: JPEG, PNG, WebP');
  }

  // Validate file size
  if (file.size > MAX_SIZE) {
    throw new Error('File too large. Maximum: 5MB');
  }

  // Validate file extension matches content type
  const ext = file.name.split('.').pop()?.toLowerCase();
  const expectedExts: Record<string, string[]> = {
    'image/jpeg': ['jpg', 'jpeg'],
    'image/png': ['png'],
    'image/webp': ['webp'],
  };

  if (!expectedExts[file.type]?.includes(ext ?? '')) {
    throw new Error('File extension does not match content type');
  }

  // Upload to user's folder
  const path = `${userId}/${crypto.randomUUID()}.${ext}`;

  const { error } = await supabase.storage
    .from('avatars')
    .upload(path, file, {
      contentType: file.type,
      upsert: false,
    });

  if (error) throw error;

  return path;
}
```

### Signed URLs for Private Files

```typescript
// Generate time-limited access URL
const { data, error } = await supabase.storage
  .from('documents')
  .createSignedUrl('path/to/file.pdf', 3600); // 1 hour

if (data) {
  console.log('Signed URL:', data.signedUrl);
}
```

## 6. CORS Configuration

### Edge Function CORS Headers

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': process.env.ALLOWED_ORIGIN ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
};

Deno.serve(async (req) => {
  // Handle preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // Include CORS headers in all responses
  return new Response(
    JSON.stringify({ data: 'response' }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
});
```

### Content Security Policy

```typescript
const securityHeaders = {
  'Content-Security-Policy': [
    "default-src 'self'",
    "script-src 'self' https://cdn.supabase.com",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "connect-src 'self' https://*.supabase.co",
  ].join('; '),
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
};
```

## 7. Environment Variables

### Never Hardcode Secrets

```typescript
// CORRECT: Use environment variables
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// WRONG: Hardcoded secrets
const supabase = createClient(
  'https://abc123.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
);
```

### Server vs Client Variables

```env
# .env.local

# Public (safe for client)
NEXT_PUBLIC_SUPABASE_URL=https://abc.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...

# Private (server only)
SUPABASE_SERVICE_ROLE_KEY=eyJ...
STRIPE_SECRET_KEY=sk_live_...
```

## 8. Output Encoding (XSS Prevention)

### React Auto-Escapes by Default

```tsx
// SAFE: React escapes this
function UserName({ name }: { name: string }) {
  return <div>{name}</div>;  // "<script>" becomes "&lt;script&gt;"
}

// DANGEROUS: dangerouslySetInnerHTML bypasses escaping
function RawHTML({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;  // XSS risk!
}
```

### Sanitize User-Generated HTML

```typescript
import DOMPurify from 'dompurify';

function SafeHTML({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'b', 'i', 'em', 'strong', 'a'],
    ALLOWED_ATTR: ['href'],
  });

  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

## Security Checklist

| Area | Check |
|------|-------|
| Auth | Using Supabase Auth (not custom)? |
| Auth | Service role key only on server? |
| Auth | Sessions in HTTP-only cookies? |
| Input | All input validated with Zod? |
| Input | File uploads validated (type, size)? |
| SQL | Using parameterized queries only? |
| API | Rate limiting implemented? |
| Storage | RLS enabled on storage.objects? |
| Storage | Private buckets use signed URLs? |
| Headers | CORS configured correctly? |
| Secrets | All secrets in env variables? |

## Boundaries

**Always do**:
- Validate all input with Zod schemas
- Use Supabase client's parameterized queries
- Store secrets in environment variables
- Validate file uploads (type, size, extension)
- Include CORS headers in Edge Functions

**Ask first**:
- Before disabling RLS for any operation
- Before using service_role key in new contexts
- Before implementing custom authentication

**Never do**:
- Expose service_role key to client
- Concatenate user input into SQL
- Trust file extensions without validation
- Store secrets in code or version control
- Use dangerouslySetInnerHTML with unsanitized content
