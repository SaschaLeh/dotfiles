---
name: stripe-integration
description: Stripe payment integration for Next.js. Covers Checkout Sessions, Subscriptions, Webhooks, SEPA mandates, refunds, and multi-tenant patterns. Always use Stripe MCP tools for latest documentation.
---

# Stripe Integration for Next.js

You are a Stripe payment integration expert implementing secure, production-ready payment flows in Next.js with TypeScript.

> **CRITICAL:** Always use Stripe MCP toolcall to fetch latest documentation before implementing. Stripe APIs evolve frequently.
>
> **Related Skills:**
> - For database changes, see `supabase-migrations`
> - For RLS policies on payment tables, see `supabase-rls-policies`

## Official Documentation References

Always consult these resources for current best practices:

| Resource | URL | Use For |
|----------|-----|---------|
| Stripe API Reference | https://docs.stripe.com/api | All API endpoints, parameters |
| Checkout Sessions | https://stripe.com/docs/payments/checkout | Payment page implementation |
| Subscriptions | https://stripe.com/docs/billing/subscriptions | Recurring billing |
| Webhooks | https://stripe.com/docs/webhooks | Event handling |
| Webhook Signatures | https://stripe.com/docs/webhooks/signatures | Security verification |
| Payment Intents | https://stripe.com/docs/payments/payment-intents | Low-level payment control |
| Customer Portal | https://stripe.com/docs/billing/subscriptions/customer-portal | Self-service subscription management |
| Testing | https://stripe.com/docs/testing | Test cards, IBANs, scenarios |

**External Guides:**
- https://www.pedroalonso.net/blog/stripe-webhooks-deep-dive/
- https://www.pedroalonso.net/blog/stripe-integration-nextjs/
- https://www.pedroalonso.net/blog/stripe-subscriptions-nextjs/

## Core Principles

### 1. Always Use Checkout Sessions

**Stripe's recommendation:** Use Checkout Sessions, not direct PaymentIntent or Subscription APIs.

```typescript
// CORRECT: Checkout Sessions (recommended)
const session = await stripe.checkout.sessions.create({
  mode: 'payment', // or 'subscription'
  line_items: [...],
  success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: `${origin}/cancel`,
})

// WRONG: Direct PaymentIntent (avoid)
const paymentIntent = await stripe.paymentIntents.create({
  amount: 2000,
  currency: 'eur',
})
```

### 2. Use Dynamic Payment Methods

**Never hardcode payment methods.** Let Stripe choose based on customer location/preferences.

```typescript
// WRONG: Hardcoded payment methods
const session = await stripe.checkout.sessions.create({
  payment_method_types: ['card', 'sepa_debit'], // DON'T DO THIS
  // ...
})

// CORRECT: Let Stripe choose dynamically
const session = await stripe.checkout.sessions.create({
  // Omit payment_method_types entirely
  // Enable dynamic payment methods in Stripe Dashboard
  line_items: [...],
  // ...
})
```

Enable dynamic payment methods in Stripe Dashboard: Settings > Payment Methods.

### 3. Always Verify Webhook Signatures

**Security critical:** Never trust unverified webhook events.

```typescript
// CORRECT: Verify signature
const event = stripe.webhooks.constructEvent(
  body,           // Raw request body (string)
  signature,      // stripe-signature header
  webhookSecret   // STRIPE_WEBHOOK_SECRET
)
// Event is now cryptographically verified

// WRONG: Parse JSON directly
const event = JSON.parse(body) // NEVER DO THIS - unverified!
```

### 4. Implement Idempotency

Webhooks can be delivered multiple times. Always check for duplicates.

```typescript
// Check if already processed
const existing = await db.stripe_webhook_events
  .findFirst({ where: { stripe_event_id: event.id } })

if (existing?.processing_status === 'success') {
  return { status: 'already_processed' }
}

// Process event...

// Log for idempotency
await db.stripe_webhook_events.upsert({
  where: { stripe_event_id: event.id },
  create: {
    stripe_event_id: event.id,
    event_type: event.type,
    processing_status: 'success',
  },
  update: { processing_status: 'success' },
})
```

## BookMotion Architecture

### File Structure

```
src/lib/stripe/
├── stripe-client.ts          # Tenant-aware Stripe client
├── stripe-config.ts          # Multi-tenant configuration (Vault)
├── stripe-payments.ts        # One-time payments via Checkout
├── stripe-subscriptions.ts   # Subscription management
├── stripe-course-subscriptions.ts  # Course-specific subscriptions
├── stripe-setup-intents.ts   # SEPA mandate collection
├── stripe-webhooks.ts        # Idempotency and logging
├── stripe-customers.ts       # Customer management
├── stripe-refunds.ts         # Refund processing
├── stripe-products.ts        # Product/Price validation
├── stripe-errors.ts          # Error handling utilities
├── types.ts                  # Type definitions
└── handlers/
    ├── checkout-handler.ts   # checkout.session.* events
    ├── subscription-handler.ts
    ├── course-subscription-handler.ts
    ├── invoice-handler.ts
    ├── setup-intent-handler.ts
    └── refund-handler.ts
```

### Multi-Tenant Pattern

BookMotion uses tenant-specific Stripe accounts. **Always use tenant-aware client:**

```typescript
// CORRECT: Tenant-specific client
import { getStripeClient } from '@/lib/stripe/stripe-client'

const stripe = await getStripeClient(tenantId)
const customer = await stripe.customers.create({ email })

// WRONG in production: Environment client
import { getStripeClientFromEnv } from '@/lib/stripe/stripe-client'

const stripe = getStripeClientFromEnv() // Only for local dev!
```

**Critical in webhook handlers:** Always extract `tenantId` from metadata first, then use `getStripeClient(tenantId)`.

### Metadata Pattern

Always include tenant context in metadata:

```typescript
const session = await stripe.checkout.sessions.create({
  mode: 'payment',
  metadata: {
    tenant_id: tenantId,       // Required
    user_id: profileId,        // Required
    class_id: classId,         // Context-specific
    booking_type: 'class',     // 'class' | 'course' | 'training'
    reference_id: classId,     // For lookup
    family_member_id: familyMemberId, // If booking for family
    waitlist_entry_id: waitlistEntryId, // If from waitlist
  },
  // ...
})
```

## Checkout Sessions

### One-Time Payments

```typescript
import { getStripeClient } from '@/lib/stripe/stripe-client'
import type Stripe from 'stripe'

interface CreateCheckoutOptions {
  tenantId: string
  customerId: string
  profileId: string
  amount: number           // In cents
  currency: string         // 'eur'
  bookingType: 'class' | 'course'
  referenceId: string
  successUrl: string
  cancelUrl: string
  familyMemberId?: string
}

export async function createOneTimeCheckout(
  options: CreateCheckoutOptions
): Promise<{ sessionId: string; sessionUrl: string | null }> {
  const stripe = await getStripeClient(options.tenantId)

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    customer: options.customerId,
    line_items: [
      {
        price_data: {
          currency: options.currency,
          product_data: {
            name: options.bookingType === 'class' ? 'Trainingsbuchung' : 'Kursbuchung',
            description: `Buchung ID: ${options.referenceId}`,
          },
          unit_amount: options.amount,
        },
        quantity: 1,
      },
    ],
    metadata: {
      tenant_id: options.tenantId,
      user_id: options.profileId,
      booking_type: options.bookingType,
      reference_id: options.referenceId,
      ...(options.familyMemberId && { family_member_id: options.familyMemberId }),
    },
    success_url: options.successUrl,
    cancel_url: options.cancelUrl,
    expires_after: 1800, // 30 minutes
    allow_promotion_codes: true,
    billing_address_collection: 'auto',
  })

  return {
    sessionId: session.id,
    sessionUrl: session.url,
  }
}
```

### Subscription Checkout

```typescript
interface CreateSubscriptionCheckoutOptions {
  tenantId: string
  customerId: string
  priceId: string
  profileId: string
  subscriptionModelId: string
  courseId?: string
  familyMemberId?: string
  successUrl: string
  cancelUrl: string
  trialDays?: number
}

export async function createSubscriptionCheckout(
  options: CreateSubscriptionCheckoutOptions
): Promise<{ sessionId: string; sessionUrl: string | null }> {
  const stripe = await getStripeClient(options.tenantId)

  const metadata: Record<string, string> = {
    tenant_id: options.tenantId,
    profile_id: options.profileId,
    subscription_model_id: options.subscriptionModelId,
  }

  // Course subscriptions vs general subscriptions
  if (options.courseId) {
    metadata.course_id = options.courseId
    metadata.subscription_type = 'course'
  } else {
    metadata.subscription_type = 'general'
  }

  if (options.familyMemberId) {
    metadata.family_member_id = options.familyMemberId
  }

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer: options.customerId,
    line_items: [{ price: options.priceId, quantity: 1 }],
    subscription_data: {
      metadata,
      ...(options.trialDays && { trial_period_days: options.trialDays }),
    },
    success_url: options.successUrl,
    cancel_url: options.cancelUrl,
    allow_promotion_codes: true,
    billing_address_collection: 'auto',
  })

  return {
    sessionId: session.id,
    sessionUrl: session.url,
  }
}
```

## Webhook Handling

### App Router Webhook Endpoint

```typescript
// src/app/api/webhooks/stripe/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { headers } from 'next/headers'
import type Stripe from 'stripe'
import { getStripeClientFromEnv, getStripeClient } from '@/lib/stripe/stripe-client'
import { isEventProcessed, logWebhookEvent } from '@/lib/stripe/stripe-webhooks'

export async function POST(request: NextRequest) {
  // 1. Validate configuration
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET
  if (!webhookSecret) {
    return NextResponse.json(
      { error: 'Webhook not configured' },
      { status: 500 }
    )
  }

  // 2. Get signature
  const headersList = await headers()
  const signature = headersList.get('stripe-signature')
  if (!signature) {
    return NextResponse.json(
      { error: 'Missing stripe-signature header' },
      { status: 400 }
    )
  }

  // 3. Get raw body (MUST be string, not parsed JSON)
  const body = await request.text()

  // 4. Verify signature
  let event: Stripe.Event
  try {
    const stripe = getStripeClientFromEnv()
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret)
  } catch (err) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  // 5. Extract tenant ID from metadata
  const tenantId = extractTenantIdFromEvent(event)
  if (!tenantId) {
    return NextResponse.json(
      { error: 'Missing tenant_id in metadata' },
      { status: 400 }
    )
  }

  // 6. Check idempotency
  if (await isEventProcessed(event.id)) {
    return NextResponse.json({ status: 'already_processed' })
  }

  // 7. Process event
  try {
    await processWebhookEvent(event, tenantId)
    await logWebhookEvent(tenantId, event, 'success')
    return NextResponse.json({ received: true })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    await logWebhookEvent(tenantId, event, 'failed', message)
    // Return 500 so Stripe retries
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

function extractTenantIdFromEvent(event: Stripe.Event): string | null {
  const obj = event.data.object as any
  return obj.metadata?.tenant_id || process.env.DEFAULT_TENANT_ID || null
}
```

### Event Router

```typescript
async function processWebhookEvent(event: Stripe.Event, tenantId: string) {
  switch (event.type) {
    // One-time payments
    case 'checkout.session.completed':
      const session = event.data.object as Stripe.Checkout.Session
      if (session.mode === 'subscription') {
        // Handle in subscription events
        break
      }
      await handleCheckoutCompleted(event, tenantId)
      break

    case 'checkout.session.expired':
      await handleCheckoutExpired(event, tenantId)
      break

    // Subscriptions
    case 'customer.subscription.created':
      await handleSubscriptionCreated(event, tenantId)
      break

    case 'customer.subscription.updated':
      await handleSubscriptionUpdated(event, tenantId)
      break

    case 'customer.subscription.deleted':
      await handleSubscriptionDeleted(event, tenantId)
      break

    // Invoices
    case 'invoice.paid':
      await handleInvoicePaid(event, tenantId)
      break

    case 'invoice.payment_failed':
      await handleInvoicePaymentFailed(event, tenantId)
      break

    // Refunds
    case 'charge.refunded':
      await handleChargeRefunded(event, tenantId)
      break

    // SEPA Setup
    case 'setup_intent.succeeded':
      await handleSetupIntentSucceeded(event, tenantId)
      break

    default:
      console.log(`[Webhook] Unhandled event: ${event.type}`)
  }
}
```

### Checkout Handler Example

```typescript
// src/lib/stripe/handlers/checkout-handler.ts
import type Stripe from 'stripe'
import { getStripeClient } from '../stripe-client'

export interface CheckoutResult {
  success: boolean
  bookingId?: string
  paymentId?: string
  error?: string
}

export async function handleCheckoutCompleted(
  event: Stripe.Event,
  tenantId: string
): Promise<CheckoutResult> {
  const session = event.data.object as Stripe.Checkout.Session

  // 1. Verify payment completed
  if (session.payment_status !== 'paid') {
    return { success: false, error: `Not paid: ${session.payment_status}` }
  }

  // 2. Extract metadata
  const metadata = session.metadata || {}
  const { user_id, class_id, course_id, family_member_id } = metadata

  if (!user_id) {
    return { success: false, error: 'Missing user_id in metadata' }
  }

  // 3. Get receipt URL from charge
  let receiptUrl: string | undefined
  if (session.payment_intent) {
    try {
      const stripe = await getStripeClient(tenantId) // Use tenant client!
      const paymentIntentId = typeof session.payment_intent === 'string'
        ? session.payment_intent
        : session.payment_intent.id

      const pi = await stripe.paymentIntents.retrieve(paymentIntentId, {
        expand: ['latest_charge'],
      })

      const charge = pi.latest_charge
      if (charge && typeof charge === 'object') {
        receiptUrl = charge.receipt_url || undefined
      }
    } catch (e) {
      console.error('Failed to get receipt URL:', e)
    }
  }

  // 4. Create booking and update payment
  // ... database operations with tenantId context

  return { success: true, bookingId: 'booking-id', paymentId: 'payment-id' }
}
```

## SEPA Direct Debit

SEPA requires SetupIntents for mandate collection before charging.

### Create Setup Intent

```typescript
export async function createSepaSetupIntent(
  tenantId: string,
  customerId: string,
  profileId: string
): Promise<{ clientSecret: string }> {
  const stripe = await getStripeClient(tenantId)

  const setupIntent = await stripe.setupIntents.create({
    customer: customerId,
    payment_method_types: ['sepa_debit'],
    metadata: {
      tenant_id: tenantId,
      profile_id: profileId,
    },
    usage: 'off_session', // For recurring charges
  })

  return { clientSecret: setupIntent.client_secret! }
}
```

### Handle Setup Intent Success

```typescript
export async function handleSetupIntentSucceeded(
  event: Stripe.Event,
  tenantId: string
): Promise<{ success: boolean; paymentMethodId?: string }> {
  const setupIntent = event.data.object as Stripe.SetupIntent

  // Get the payment method
  const paymentMethodId = typeof setupIntent.payment_method === 'string'
    ? setupIntent.payment_method
    : setupIntent.payment_method?.id

  if (!paymentMethodId) {
    return { success: false }
  }

  // Set as default payment method for customer
  const stripe = await getStripeClient(tenantId)
  await stripe.customers.update(setupIntent.customer as string, {
    invoice_settings: { default_payment_method: paymentMethodId },
  })

  // Store in database for future reference
  // ...

  return { success: true, paymentMethodId }
}
```

## Subscriptions

### Key Events to Handle

| Event | When | Action |
|-------|------|--------|
| `customer.subscription.created` | Subscription starts | Create local record |
| `customer.subscription.updated` | Plan change, status change | Sync status |
| `customer.subscription.deleted` | Cancelled/expired | Mark inactive |
| `invoice.paid` | Successful payment | Record payment |
| `invoice.payment_failed` | Payment failed | Notify user, handle dunning |
| `invoice.upcoming` | Before renewal | Send reminder |

### Subscription Status Mapping

```typescript
function mapSubscriptionStatus(stripeStatus: string): LocalStatus {
  switch (stripeStatus) {
    case 'active':
    case 'trialing':
      return 'active'
    case 'past_due':
    case 'unpaid':
      return 'past_due'
    case 'canceled':
    case 'incomplete_expired':
      return 'cancelled'
    case 'incomplete':
      return 'pending'
    default:
      return 'unknown'
  }
}
```

### Cancel Subscription

```typescript
export async function cancelSubscription(
  tenantId: string,
  stripeSubscriptionId: string,
  options: { immediately?: boolean; feedback?: string } = {}
): Promise<{ success: boolean }> {
  const stripe = await getStripeClient(tenantId)

  if (options.immediately) {
    // Cancel now
    await stripe.subscriptions.cancel(stripeSubscriptionId, {
      cancellation_details: {
        comment: options.feedback,
      },
    })
  } else {
    // Cancel at period end
    await stripe.subscriptions.update(stripeSubscriptionId, {
      cancel_at_period_end: true,
      cancellation_details: {
        comment: options.feedback,
      },
    })
  }

  return { success: true }
}
```

## Refunds

```typescript
export async function createRefund(
  tenantId: string,
  paymentIntentId: string,
  options: {
    amount?: number    // Partial refund in cents
    reason?: 'duplicate' | 'fraudulent' | 'requested_by_customer'
  } = {}
): Promise<{ refundId: string; status: string }> {
  const stripe = await getStripeClient(tenantId)

  const refund = await stripe.refunds.create({
    payment_intent: paymentIntentId,
    ...(options.amount && { amount: options.amount }),
    ...(options.reason && { reason: options.reason }),
  })

  return {
    refundId: refund.id,
    status: refund.status,
  }
}
```

## Error Handling

```typescript
import Stripe from 'stripe'

interface StripeErrorResult {
  type: 'card_error' | 'rate_limit_error' | 'api_error' | 'authentication_error' | 'unknown'
  message: string           // User-friendly message
  technicalMessage: string  // For logging
  code?: string
  declineCode?: string
}

export function handleStripeError(error: unknown): StripeErrorResult {
  if (error instanceof Stripe.errors.StripeError) {
    switch (error.type) {
      case 'StripeCardError':
        return {
          type: 'card_error',
          message: getCardErrorMessage(error.code, error.decline_code),
          technicalMessage: error.message,
          code: error.code,
          declineCode: error.decline_code,
        }

      case 'StripeRateLimitError':
        return {
          type: 'rate_limit_error',
          message: 'Too many requests. Please try again.',
          technicalMessage: error.message,
        }

      case 'StripeInvalidRequestError':
        return {
          type: 'api_error',
          message: 'Invalid request. Please check your input.',
          technicalMessage: error.message,
          code: error.code,
        }

      case 'StripeAuthenticationError':
        return {
          type: 'authentication_error',
          message: 'Payment service configuration error.',
          technicalMessage: error.message,
        }

      default:
        return {
          type: 'unknown',
          message: 'Payment failed. Please try again.',
          technicalMessage: error.message,
        }
    }
  }

  return {
    type: 'unknown',
    message: 'An unexpected error occurred.',
    technicalMessage: String(error),
  }
}

function getCardErrorMessage(code?: string, declineCode?: string): string {
  switch (declineCode || code) {
    case 'insufficient_funds':
      return 'Insufficient funds. Please use a different card.'
    case 'lost_card':
    case 'stolen_card':
      return 'Card reported lost or stolen.'
    case 'expired_card':
      return 'Card has expired. Please use a different card.'
    case 'incorrect_cvc':
      return 'Incorrect security code. Please check and try again.'
    case 'processing_error':
      return 'Processing error. Please try again.'
    default:
      return 'Card declined. Please use a different payment method.'
  }
}
```

## Testing

### Test Cards

| Card Number | Scenario |
|-------------|----------|
| 4242 4242 4242 4242 | Success |
| 4000 0000 0000 0002 | Declined |
| 4000 0000 0000 9995 | Insufficient funds |
| 4000 0027 6000 3184 | 3D Secure required |

### Test IBAN (SEPA)

| Country | IBAN |
|---------|------|
| Germany | DE89370400440532013000 |
| France | FR1420041010050500013M02606 |

### Local Webhook Testing

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger test events
stripe trigger checkout.session.completed
stripe trigger customer.subscription.created
stripe trigger invoice.payment_failed
```

## Environment Variables

```env
# Required
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...

# Optional (development)
DEFAULT_TENANT_ID=your-tenant-uuid
```

## Best Practices Checklist

### Security

- [ ] Always verify webhook signatures with `constructEvent()`
- [ ] Use tenant-specific Stripe client in webhooks
- [ ] Never expose secret keys in client code
- [ ] Store API keys in environment variables or Vault
- [ ] Validate metadata matches expected tenant

### Reliability

- [ ] Implement idempotency for all webhook handlers
- [ ] Log all webhook events to database
- [ ] Return 500 on processing errors (Stripe will retry)
- [ ] Handle duplicate events gracefully

### User Experience

- [ ] Use dynamic payment methods (no hardcoding)
- [ ] Always use Checkout Sessions for consistent UX
- [ ] Store receipt URLs for customer reference
- [ ] Send confirmation notifications after payment

### Maintenance

- [ ] Keep Stripe API version updated
- [ ] Monitor webhook success rates
- [ ] Test all payment flows after updates
- [ ] Document payment method strategy

## Boundaries

### Always Do

- Use Stripe MCP toolcall for latest documentation
- Use Checkout Sessions for payments
- Verify webhook signatures
- Use tenant-specific Stripe client
- Implement idempotency

### Never Do

- Hardcode payment methods
- Trust unverified webhook events
- Use `getStripeClientFromEnv()` in production webhook handlers
- Store card numbers (use Stripe tokens)
- Skip error handling
