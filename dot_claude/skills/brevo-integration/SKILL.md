---
name: brevo-integration
description: Brevo (Sendinblue) email integration for Next.js and Supabase Edge Functions. Covers transactional emails, templates, API authentication, error handling, and provider-agnostic patterns.
---

# Brevo Email Integration

You are an expert integrating Brevo (formerly Sendinblue) for transactional email in Next.js applications and Supabase Edge Functions.

## Overview

Brevo provides a REST API for sending transactional emails. Key features:
- Template-based emails with dynamic variables
- High deliverability with tracking
- Free tier: 300 emails/day
- REST API at `https://api.brevo.com/v3`

## Authentication

### API Key Setup

1. Create account at [brevo.com](https://brevo.com)
2. Navigate to **SMTP & API** section
3. Generate API key
4. Store securely in environment variables

```bash
# .env.local (Next.js)
BREVO_API_KEY=xkeysib-xxxxxxxx-xxxx

# Supabase secrets
supabase secrets set BREVO_API_KEY=xkeysib-xxxxxxxx-xxxx
```

### Request Headers

```typescript
const headers = {
  'accept': 'application/json',
  'api-key': process.env.BREVO_API_KEY,
  'content-type': 'application/json',
};
```

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v3/smtp/email` | POST | Send transactional email |
| `/v3/account` | GET | Validate API key / get account info |
| `/v3/smtp/statistics/reports` | GET | Get email statistics |
| `/v3/smtp/templates` | GET | List templates |

## Sending Transactional Emails

### Basic Request Structure

```typescript
interface BrevoEmailRequest {
  templateId: number;           // Brevo template ID
  to: { email: string; name?: string }[];
  params?: Record<string, string | number | boolean>;
  subject?: string;             // Override template subject
  sender?: { email: string; name?: string };
  replyTo?: { email: string; name?: string };
  cc?: { email: string; name?: string }[];
  bcc?: { email: string; name?: string }[];
  attachment?: { name: string; content: string; contentType: string }[];
}
```

### Response Structure

```typescript
// Success response
interface BrevoSuccessResponse {
  messageId: string;
  // or for multiple recipients:
  messageIds?: string[];
}

// Error response
interface BrevoErrorResponse {
  code: string;
  message: string;
}
```

## Next.js Implementation

### API Route Handler

```typescript
// src/app/api/email/send/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

const BREVO_API_URL = 'https://api.brevo.com/v3';

const sendEmailSchema = z.object({
  templateId: z.number(),
  to: z.array(z.object({
    email: z.string().email(),
    name: z.string().optional(),
  })).min(1),
  params: z.record(z.unknown()).optional(),
  subject: z.string().optional(),
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const validated = sendEmailSchema.parse(body);

    const response = await fetch(`${BREVO_API_URL}/smtp/email`, {
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'api-key': process.env.BREVO_API_KEY!,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        templateId: validated.templateId,
        to: validated.to,
        params: validated.params,
        subject: validated.subject,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      return NextResponse.json(
        { error: error.message || 'Email send failed' },
        { status: response.status }
      );
    }

    const result = await response.json();
    return NextResponse.json({ messageId: result.messageId });

  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Validation failed', details: error.flatten() },
        { status: 400 }
      );
    }
    console.error('Email send error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

### Email Service Module

```typescript
// src/lib/email/brevo.ts
const BREVO_API_URL = 'https://api.brevo.com/v3';
const DEFAULT_TIMEOUT = 30000;

export interface EmailRecipient {
  email: string;
  name?: string;
}

export interface SendEmailParams {
  templateId: number;
  to: EmailRecipient[];
  params?: Record<string, string | number | boolean>;
  subject?: string;
  sender?: EmailRecipient;
  replyTo?: EmailRecipient;
}

export interface SendEmailResult {
  success: boolean;
  messageId?: string;
  error?: string;
  errorCode?: string;
}

export async function sendTransactionalEmail(
  params: SendEmailParams
): Promise<SendEmailResult> {
  const apiKey = process.env.BREVO_API_KEY;

  if (!apiKey) {
    return { success: false, error: 'BREVO_API_KEY not configured' };
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT);

  try {
    const response = await fetch(`${BREVO_API_URL}/smtp/email`, {
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'api-key': apiKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        templateId: params.templateId,
        to: params.to.map(r => ({ email: r.email, name: r.name })),
        params: params.params,
        subject: params.subject,
        sender: params.sender,
        replyTo: params.replyTo,
      }),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      return {
        success: false,
        error: errorBody.message || `HTTP ${response.status}`,
        errorCode: errorBody.code || 'HTTP_ERROR',
      };
    }

    const result = await response.json();
    return {
      success: true,
      messageId: result.messageId || result.messageIds?.[0],
    };

  } catch (error) {
    clearTimeout(timeoutId);

    if (error instanceof Error && error.name === 'AbortError') {
      return { success: false, error: 'Request timeout', errorCode: 'TIMEOUT' };
    }

    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
      errorCode: 'NETWORK_ERROR',
    };
  }
}

export async function validateApiKey(): Promise<boolean> {
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) return false;

  try {
    const response = await fetch(`${BREVO_API_URL}/account`, {
      headers: {
        'accept': 'application/json',
        'api-key': apiKey,
      },
    });
    return response.ok;
  } catch {
    return false;
  }
}
```

### Usage in Server Actions

```typescript
// src/app/actions/booking.ts
'use server';

import { sendTransactionalEmail } from '@/lib/email/brevo';

export async function createBooking(data: BookingInput) {
  // ... create booking logic ...

  // Send confirmation email
  const emailResult = await sendTransactionalEmail({
    templateId: 1, // Your Brevo template ID
    to: [{ email: user.email, name: user.name }],
    params: {
      userName: user.name,
      className: classData.name,
      classDate: format(classData.startTime, 'dd.MM.yyyy'),
      classTime: format(classData.startTime, 'HH:mm'),
      location: location.name,
    },
  });

  if (!emailResult.success) {
    console.error('Failed to send booking confirmation:', emailResult.error);
    // Don't fail the booking - email is secondary
  }

  return { success: true, booking };
}
```

## Supabase Edge Function Implementation

### Provider Adapter Pattern

```typescript
// supabase/functions/email-dispatcher/adapters/brevo.ts
import type { EmailProviderAdapter, AdapterConfig } from './interface.ts';

const BREVO_API_URL = 'https://api.brevo.com/v3';
const DEFAULT_TIMEOUT = 30000;

export interface EmailSendParams {
  templateId: number;
  to: { email: string; name?: string }[];
  params: Record<string, string | number | boolean>;
  subject?: string;
  sender?: { email: string; name?: string };
  replyTo?: { email: string; name?: string };
  cc?: { email: string; name?: string }[];
  bcc?: { email: string; name?: string }[];
  attachments?: { name: string; content: string; contentType: string }[];
}

export interface EmailSendResult {
  success: boolean;
  messageId?: string;
  error?: string;
  errorCode?: string;
  providerResponse?: Record<string, unknown>;
}

export class BrevoAdapter implements EmailProviderAdapter {
  readonly name = 'brevo';
  private readonly apiKey: string;
  private readonly timeout: number;

  constructor(config: AdapterConfig) {
    if (!config.apiKey) {
      throw new Error('Brevo API key is required');
    }
    this.apiKey = config.apiKey;
    this.timeout = config.timeout || DEFAULT_TIMEOUT;
  }

  async sendTransactionalEmail(params: EmailSendParams): Promise<EmailSendResult> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(`${BREVO_API_URL}/smtp/email`, {
        method: 'POST',
        headers: {
          'accept': 'application/json',
          'api-key': this.apiKey,
          'content-type': 'application/json',
        },
        body: JSON.stringify(this.buildRequestBody(params)),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorBody = await response.json().catch(() => ({}));
        return {
          success: false,
          error: errorBody.message || 'Unknown error',
          errorCode: errorBody.code || 'HTTP_ERROR',
          providerResponse: { httpStatus: response.status, ...errorBody },
        };
      }

      const result = await response.json();
      return {
        success: true,
        messageId: result.messageId || result.messageIds?.[0],
        providerResponse: result,
      };

    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof Error && error.name === 'AbortError') {
        return {
          success: false,
          error: 'Request timeout',
          errorCode: 'TIMEOUT',
        };
      }

      return {
        success: false,
        error: error instanceof Error ? error.message : 'Network error',
        errorCode: 'NETWORK_ERROR',
      };
    }
  }

  async validateConnection(): Promise<boolean> {
    try {
      const response = await fetch(`${BREVO_API_URL}/account`, {
        headers: {
          'accept': 'application/json',
          'api-key': this.apiKey,
        },
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  private buildRequestBody(params: EmailSendParams): Record<string, unknown> {
    const body: Record<string, unknown> = {
      templateId: params.templateId,
      to: params.to.map(r => ({ email: r.email, name: r.name })),
      params: params.params,
    };

    if (params.sender) body.sender = params.sender;
    if (params.subject) body.subject = params.subject;
    if (params.replyTo) body.replyTo = params.replyTo;
    if (params.cc?.length) body.cc = params.cc;
    if (params.bcc?.length) body.bcc = params.bcc;
    if (params.attachments?.length) {
      body.attachment = params.attachments.map(a => ({
        name: a.name,
        content: a.content,
        contentType: a.contentType,
      }));
    }

    return body;
  }
}
```

### Edge Function with Brevo

```typescript
// supabase/functions/send-email/index.ts
import { createClient } from 'npm:@supabase/supabase-js@2';
import { BrevoAdapter } from './adapters/brevo.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { templateId, to, params } = await req.json();

    // Get API key from Vault or environment
    const apiKey = Deno.env.get('BREVO_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'Email provider not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const brevo = new BrevoAdapter({ apiKey });
    const result = await brevo.sendTransactionalEmail({ templateId, to, params });

    if (!result.success) {
      return new Response(
        JSON.stringify({ error: result.error, code: result.errorCode }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ messageId: result.messageId }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Email send error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

## Template Variables

### Brevo Template Syntax

In Brevo templates, use double braces for variables:

```html
<p>Hello {{ params.userName }},</p>
<p>Your booking for <strong>{{ params.className }}</strong> is confirmed.</p>
<p>Date: {{ params.classDate }}</p>
<p>Time: {{ params.classTime }}</p>
<p>Location: {{ params.location }}</p>
```

### Passing Variables

```typescript
await sendTransactionalEmail({
  templateId: 1,
  to: [{ email: 'user@example.com', name: 'John Doe' }],
  params: {
    userName: 'John',
    className: 'Morning Yoga',
    classDate: '15.01.2026',
    classTime: '09:00',
    location: 'Studio A',
  },
});
```

## Error Handling

### Common Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| `unauthorized` | Invalid API key | Check BREVO_API_KEY |
| `invalid_parameter` | Bad request data | Validate input |
| `document_not_found` | Template not found | Check templateId |
| `method_not_allowed` | Wrong HTTP method | Use POST |
| `too_many_requests` | Rate limited | Implement backoff |

### Retry Logic

```typescript
async function sendWithRetry(
  params: SendEmailParams,
  maxRetries = 3
): Promise<SendEmailResult> {
  let lastError: SendEmailResult | null = null;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const result = await sendTransactionalEmail(params);

    if (result.success) {
      return result;
    }

    // Don't retry client errors
    if (result.errorCode === 'invalid_parameter' ||
        result.errorCode === 'unauthorized' ||
        result.errorCode === 'document_not_found') {
      return result;
    }

    lastError = result;

    // Exponential backoff
    const delay = Math.pow(2, attempt) * 1000;
    await new Promise(resolve => setTimeout(resolve, delay));
  }

  return lastError!;
}
```

## Rate Limiting

Brevo has rate limits based on your plan:
- Free: 300 emails/day
- Starter: Based on plan
- Business: Based on plan

### Client-Side Rate Limiting

```typescript
class RateLimiter {
  private requests: number[] = [];
  private readonly maxRequests: number;
  private readonly windowMs: number;

  constructor(maxRequests: number, windowMs: number) {
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
  }

  canMakeRequest(): boolean {
    const now = Date.now();
    this.requests = this.requests.filter(t => now - t < this.windowMs);
    return this.requests.length < this.maxRequests;
  }

  recordRequest(): void {
    this.requests.push(Date.now());
  }
}

// Usage: 100 requests per hour
const rateLimiter = new RateLimiter(100, 3600000);

async function sendEmailWithRateLimit(params: SendEmailParams) {
  if (!rateLimiter.canMakeRequest()) {
    return { success: false, error: 'Rate limit exceeded', errorCode: 'RATE_LIMITED' };
  }

  rateLimiter.recordRequest();
  return sendTransactionalEmail(params);
}
```

## Attachments

### Calendar Invite (.ics)

```typescript
import { createEvents } from 'ics';

function generateCalendarInvite(booking: Booking): string {
  const { error, value } = createEvents([{
    start: [2026, 1, 15, 9, 0],
    duration: { hours: 1 },
    title: booking.className,
    location: booking.location,
    description: `Your booking for ${booking.className}`,
  }]);

  if (error) throw error;
  return Buffer.from(value!).toString('base64');
}

// Send with attachment
await sendTransactionalEmail({
  templateId: 1,
  to: [{ email: user.email }],
  params: { ... },
  attachments: [{
    name: 'booking.ics',
    content: generateCalendarInvite(booking),
    contentType: 'text/calendar',
  }],
});
```

## Testing

### Test Email Sending

```typescript
// src/lib/email/__tests__/brevo.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { sendTransactionalEmail } from '../brevo';

describe('sendTransactionalEmail', () => {
  beforeEach(() => {
    vi.stubEnv('BREVO_API_KEY', 'test-api-key');
  });

  it('sends email successfully', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ messageId: 'msg-123' }),
    });

    const result = await sendTransactionalEmail({
      templateId: 1,
      to: [{ email: 'test@example.com' }],
      params: { name: 'Test' },
    });

    expect(result.success).toBe(true);
    expect(result.messageId).toBe('msg-123');
  });

  it('handles API errors', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      json: () => Promise.resolve({ code: 'unauthorized', message: 'Invalid API key' }),
    });

    const result = await sendTransactionalEmail({
      templateId: 1,
      to: [{ email: 'test@example.com' }],
      params: {},
    });

    expect(result.success).toBe(false);
    expect(result.errorCode).toBe('unauthorized');
  });
});
```

## Provider-Agnostic Architecture

BookMotion uses a provider-agnostic email system. The adapter pattern allows swapping Brevo for SendGrid, Postmark, or SES:

```typescript
// src/lib/email/interface.ts
export interface EmailProviderAdapter {
  readonly name: string;
  sendTransactionalEmail(params: EmailSendParams): Promise<EmailSendResult>;
  validateConnection(): Promise<boolean>;
}

// Factory function
export function createEmailProvider(provider: string): EmailProviderAdapter {
  switch (provider) {
    case 'brevo':
      return new BrevoAdapter({ apiKey: process.env.BREVO_API_KEY! });
    case 'sendgrid':
      return new SendGridAdapter({ apiKey: process.env.SENDGRID_API_KEY! });
    default:
      throw new Error(`Unknown email provider: ${provider}`);
  }
}
```

## Boundaries

**Always do**:
- Store API keys in environment variables
- Validate email addresses before sending
- Handle errors gracefully (don't fail main operation)
- Use template-based emails for consistency
- Log email send results for debugging
- Implement retry logic for transient failures

**Ask first**:
- Before creating new Brevo templates
- Before changing email sender addresses
- Before implementing custom SMTP (non-template) emails
- Before modifying rate limits

**Never do**:
- Hardcode API keys in source code
- Send emails without user consent
- Expose raw Brevo errors to end users
- Skip validation on email addresses
- Ignore rate limits
- Send sensitive data (passwords, tokens) in emails without encryption
