---
name: supabase-edge-functions
description: Creating Supabase Edge Functions with Deno. Covers function structure, CORS handling, error responses, authentication verification, environment variables, and integration with Supabase client.
---

# Supabase Edge Functions

You are an expert creating Supabase Edge Functions using the Deno runtime.

## Function Structure

### Basic Template

```typescript
// supabase/functions/my-function/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { name } = await req.json();

    return new Response(
      JSON.stringify({ message: `Hello, ${name}!` }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Invalid request' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
```

### File Organization

```
supabase/functions/
├── _shared/              # Shared utilities
│   ├── cors.ts
│   ├── supabase.ts
│   └── validation.ts
├── create-booking/
│   └── index.ts
├── send-notification/
│   └── index.ts
└── process-payment/
    └── index.ts
```

## CORS Handling

### Standard CORS Headers

```typescript
// supabase/functions/_shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
};

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  return null;
}
```

### Using CORS in Functions

```typescript
import { corsHeaders, handleCors } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  // Handle preflight first
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Your logic here...

  return new Response(
    JSON.stringify({ data: result }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
});
```

## Authentication

### Verify JWT Token

```typescript
// supabase/functions/_shared/supabase.ts
import { createClient, SupabaseClient, User } from '@supabase/supabase-js';

export function createSupabaseClient(req: Request): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    {
      global: {
        headers: { Authorization: req.headers.get('Authorization')! },
      },
      auth: { persistSession: false },
    }
  );
}

export function createServiceClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } }
  );
}

export async function getUser(req: Request): Promise<User | null> {
  const supabase = createSupabaseClient(req);
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}
```

### Protected Function

```typescript
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getUser, createSupabaseClient } from '../_shared/supabase.ts';

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Verify authentication
  const user = await getUser(req);
  if (!user) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // User is authenticated, proceed
  const supabase = createSupabaseClient(req);

  const { data, error } = await supabase
    .from('bookings')
    .select('*')
    .eq('profile_id', user.id);

  if (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  return new Response(
    JSON.stringify({ bookings: data }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
});
```

## Input Validation

### Zod Validation Pattern

```typescript
import { z } from 'zod';
import { corsHeaders, handleCors } from '../_shared/cors.ts';

const createBookingSchema = z.object({
  classId: z.string().uuid(),
  notes: z.string().max(500).optional(),
});

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const body = await req.json();
    const result = createBookingSchema.safeParse(body);

    if (!result.success) {
      return new Response(
        JSON.stringify({
          error: 'Validation failed',
          details: result.error.flatten(),
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { classId, notes } = result.data;

    // Process validated data...

  } catch {
    return new Response(
      JSON.stringify({ error: 'Invalid JSON body' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

## Error Handling

### Structured Error Responses

```typescript
interface ApiError {
  error: string;
  code?: string;
  details?: unknown;
}

function errorResponse(
  message: string,
  status: number,
  code?: string,
  details?: unknown
): Response {
  const body: ApiError = { error: message };
  if (code) body.code = code;
  if (details) body.details = details;

  return new Response(
    JSON.stringify(body),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

function successResponse<T>(data: T, status = 200): Response {
  return new Response(
    JSON.stringify(data),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

// Usage
Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // ... logic

    if (!user) {
      return errorResponse('Unauthorized', 401, 'AUTH_REQUIRED');
    }

    if (classIsFull) {
      return errorResponse('Class is full', 409, 'CLASS_FULL', { waitlistAvailable: true });
    }

    return successResponse({ booking: newBooking }, 201);

  } catch (error) {
    console.error('Unexpected error:', error);
    return errorResponse('Internal server error', 500, 'INTERNAL_ERROR');
  }
});
```

## Environment Variables

### Accessing Environment Variables

```typescript
// Built-in Supabase variables (always available)
const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Custom secrets (set via CLI or dashboard)
const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
const sendgridKey = Deno.env.get('SENDGRID_API_KEY');

if (!stripeKey) {
  throw new Error('STRIPE_SECRET_KEY not configured');
}
```

### Setting Secrets

```bash
# Set a secret
supabase secrets set STRIPE_SECRET_KEY=sk_live_...

# Set multiple secrets from .env file
supabase secrets set --env-file .env.production

# List current secrets
supabase secrets list
```

## HTTP Methods

### Handling Multiple Methods

```typescript
Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const url = new URL(req.url);
  const id = url.searchParams.get('id');

  switch (req.method) {
    case 'GET':
      return handleGet(id);

    case 'POST':
      return handlePost(await req.json());

    case 'PUT':
      if (!id) return errorResponse('ID required', 400);
      return handlePut(id, await req.json());

    case 'DELETE':
      if (!id) return errorResponse('ID required', 400);
      return handleDelete(id);

    default:
      return errorResponse('Method not allowed', 405);
  }
});
```

## Calling External APIs

### Fetch with Error Handling

```typescript
async function callExternalApi(endpoint: string, data: unknown): Promise<Response> {
  const apiKey = Deno.env.get('EXTERNAL_API_KEY');

  const response = await fetch(`https://api.example.com${endpoint}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error(`External API error: ${response.status}`, error);
    throw new Error(`External API failed: ${response.status}`);
  }

  return response;
}
```

### Stripe Integration Example

```typescript
import Stripe from 'stripe';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
});

Deno.serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const user = await getUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  try {
    const { priceId } = await req.json();

    const session = await stripe.checkout.sessions.create({
      customer_email: user.email,
      line_items: [{ price: priceId, quantity: 1 }],
      mode: 'subscription',
      success_url: `${Deno.env.get('SITE_URL')}/success`,
      cancel_url: `${Deno.env.get('SITE_URL')}/cancel`,
      metadata: { userId: user.id },
    });

    return successResponse({ url: session.url });

  } catch (error) {
    console.error('Stripe error:', error);
    return errorResponse('Payment initialization failed', 500);
  }
});
```

## Webhook Handling

### Stripe Webhook Example

```typescript
import Stripe from 'stripe';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
});

Deno.serve(async (req) => {
  // Webhooks don't need CORS (server-to-server)
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const signature = req.headers.get('stripe-signature');
  if (!signature) {
    return new Response('Missing signature', { status: 400 });
  }

  const body = await req.text();

  try {
    const event = stripe.webhooks.constructEvent(
      body,
      signature,
      Deno.env.get('STRIPE_WEBHOOK_SECRET')!
    );

    const supabase = createServiceClient();

    switch (event.type) {
      case 'checkout.session.completed':
        const session = event.data.object as Stripe.Checkout.Session;
        await supabase
          .from('subscriptions')
          .upsert({
            user_id: session.metadata?.userId,
            stripe_subscription_id: session.subscription,
            status: 'active',
          });
        break;

      // Handle other events...
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });

  } catch (error) {
    console.error('Webhook error:', error);
    return new Response('Webhook error', { status: 400 });
  }
});
```

## CLI Commands

| Command | Purpose |
|---------|---------|
| `supabase functions new <name>` | Create new function |
| `supabase functions serve` | Run locally |
| `supabase functions serve --env-file .env.local` | Run with env file |
| `supabase functions deploy <name>` | Deploy single function |
| `supabase functions deploy` | Deploy all functions |
| `supabase functions delete <name>` | Delete function |
| `supabase secrets set KEY=value` | Set secret |
| `supabase secrets list` | List secrets |

## Local Development

```bash
# Start local Supabase
supabase start

# Serve functions with hot reload
supabase functions serve --env-file .env.local

# Test with curl
curl -X POST http://localhost:54321/functions/v1/my-function \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"name": "World"}'
```

## Boundaries

**Always do**:
- Handle CORS preflight requests
- Validate all input with Zod
- Return structured JSON error responses
- Log errors with `console.error`
- Use environment variables for secrets
- Verify authentication for protected functions

**Ask first**:
- Before creating functions that bypass RLS with service_role
- Before implementing webhook handlers
- Before calling external paid APIs

**Never do**:
- Hardcode API keys or secrets
- Skip CORS headers (browser clients will fail)
- Return raw error messages to clients
- Ignore authentication for sensitive operations
- Use `SUPABASE_SERVICE_ROLE_KEY` when user client suffices
