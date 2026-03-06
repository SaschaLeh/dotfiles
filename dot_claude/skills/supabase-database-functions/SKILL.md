---
name: supabase-database-functions
description: Creating PostgreSQL database functions for Supabase with proper security (SECURITY INVOKER/DEFINER), search_path configuration, Vault for secrets/API keys, and triggers. Covers plpgsql, SQL language functions, and RLS-aware patterns.
---

# Supabase Database Functions

You are a PostgreSQL expert creating secure database functions for Supabase.

> **Related Skills:**
> - For API-layer security and input validation, see `supabase-security`
> - For RLS policy patterns, see `supabase-rls-policies`
> - For testing functions, see `supabase-database-testing`

## Critical: Always Check First

Before creating ANY function:

1. **Check existing functions**: Search `supabase/migrations/` for similar logic
2. **Read current schema**: `src/model/database.types.ts` for table structures
3. **Understand RLS**: Functions interact with RLS policies differently based on security mode

## Security Modes

### SECURITY INVOKER (Default, Preferred)

Function runs with **caller's permissions**. RLS policies apply normally.

```sql
create or replace function public.get_user_bookings(p_limit int default 10)
returns setof public.bookings
language sql
security invoker
set search_path = ''
stable
as $$
  select *
  from public.bookings
  where profile_id = auth.uid()
  order by created_at desc
  limit p_limit;
$$;
```

**Use when**: Query functions, computed values, user-facing data access.

### SECURITY DEFINER (Use Sparingly)

Function runs with **creator's permissions** (bypasses RLS).

```sql
create or replace function public.admin_get_all_bookings(p_tenant_id uuid)
returns setof public.bookings
language plpgsql
security definer
set search_path = ''
stable
as $$
begin
  -- ALWAYS validate caller permissions manually
  if not exists (
    select 1 from public.user_roles
    where user_id = auth.uid()
      and tenant_id = p_tenant_id
      and role in ('admin', 'manager')
  ) then
    raise exception 'Access denied: insufficient permissions';
  end if;

  return query
  select * from public.bookings
  where tenant_id = p_tenant_id
  order by created_at desc;
end;
$$;

-- Always grant explicitly
grant execute on function public.admin_get_all_bookings to authenticated;
```

**Use when**: Cross-user operations, system triggers, bypassing RLS intentionally.

## Required: search_path Configuration

**ALWAYS set `search_path = ''`** and use fully qualified names:

```sql
-- CORRECT
create or replace function public.my_function()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  select * from public.bookings;    -- schema.table
  perform auth.uid();                -- schema.function
end;
$$;

-- WRONG - Security vulnerability
create or replace function public.my_function()
returns void
language plpgsql
as $$
begin
  select * from bookings;  -- Could resolve to malicious schema
end;
$$;
```

## Supabase Vault: Storing Secrets & API Keys

**Never hardcode secrets in functions.** Use Supabase Vault for encrypted storage.

### Storing Secrets

```sql
-- Using vault.create_secret (recommended)
select vault.create_secret(
  'sk_live_abc123...',           -- secret value
  'stripe_api_key',              -- unique name
  'Stripe production API key'    -- description
);

-- Direct insert (auto-encrypted)
insert into vault.secrets (secret, name, description)
values ('my_secret_value', 'external_api_key', 'API key for external service');
```

### Retrieving Secrets in Functions

```sql
create or replace function public.call_external_api(p_endpoint text)
returns jsonb
language plpgsql
security definer  -- Required to access vault
set search_path = ''
as $$
declare
  v_api_key text;
begin
  -- Retrieve decrypted secret from vault
  select decrypted_secret into v_api_key
  from vault.decrypted_secrets
  where name = 'external_api_key';

  if v_api_key is null then
    raise exception 'API key not found in vault';
  end if;

  -- Use the secret with http extension or pg_net
  -- ...
end;
$$;
```

### Vault Best Practices

| Do | Don't |
|----|-------|
| Store API keys in vault | Hardcode secrets in SQL |
| Use descriptive names | Use generic names like 'key1' |
| Access via `vault.decrypted_secrets` | Store decrypted values in tables |
| Use SECURITY DEFINER for vault access | Grant vault access to `anon` role |

## Function Language Selection

| Language | Use Case | Performance |
|----------|----------|-------------|
| `sql`    | Simple queries, single expressions | Fastest, inlinable |
| `plpgsql`| Control flow, variables, exceptions | Good, procedural |

### SQL Language (Prefer for Simple Functions)

```sql
create or replace function public.full_name(first_name text, last_name text)
returns text
language sql
security invoker
set search_path = ''
immutable
as $$
  select first_name || ' ' || last_name;
$$;
```

### PL/pgSQL (For Complex Logic)

```sql
create or replace function public.calculate_booking_price(
  p_class_id uuid,
  p_profile_id uuid
)
returns numeric
language plpgsql
security invoker
set search_path = ''
stable
as $$
declare
  v_base_price numeric;
  v_has_subscription boolean;
  v_discount numeric := 0;
begin
  select price into v_base_price
  from public.classes where id = p_class_id;

  if v_base_price is null then
    raise exception 'Class not found: %', p_class_id;
  end if;

  select exists(
    select 1 from public.subscriptions
    where profile_id = p_profile_id and status = 'active'
  ) into v_has_subscription;

  if v_has_subscription then
    v_discount := 0.10;
  end if;

  return v_base_price * (1 - v_discount);
end;
$$;
```

## Volatility Categories

| Category   | Data Changes? | Can Cache? | Use For |
|------------|---------------|------------|---------|
| `immutable`| Never         | Yes        | Pure calculations, formatting |
| `stable`   | No (in txn)   | Per-query  | Reads current data |
| `volatile` | Yes           | Never      | INSERT/UPDATE/DELETE |

## Trigger Functions

Triggers MUST return `trigger` type and use `NEW`/`OLD` records.

### BEFORE Trigger (Modify Data)

```sql
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger set_updated_at_trigger
  before update on public.bookings
  for each row
  execute function public.set_updated_at();
```

### AFTER Trigger (Side Effects)

```sql
create or replace function public.on_booking_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.classes
  set current_attendees = current_attendees + 1
  where id = new.class_id;

  insert into public.notifications (profile_id, tenant_id, type, title)
  values (new.profile_id, new.tenant_id, 'booking_confirmed', 'Booking Confirmed');

  return new;
end;
$$;

create trigger on_booking_created
  after insert on public.bookings
  for each row
  execute function public.on_booking_created();
```

### Conditional Trigger

```sql
create trigger on_booking_cancelled
  after update on public.bookings
  for each row
  when (old.status <> 'cancelled' and new.status = 'cancelled')
  execute function public.on_booking_cancelled();
```

## Error Handling Pattern

```sql
create or replace function public.safe_create_booking(p_class_id uuid, p_profile_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking_id uuid;
  v_capacity int;
  v_current int;
begin
  select max_attendees, current_attendees
  into v_capacity, v_current
  from public.classes
  where id = p_class_id
  for update;  -- Lock row

  if not found then
    raise exception 'Class not found'
      using errcode = 'P0002', hint = 'Verify class_id is correct';
  end if;

  if v_current >= v_capacity then
    raise exception 'Class is full'
      using errcode = 'P0003',
            detail = format('Capacity: %s, Current: %s', v_capacity, v_current);
  end if;

  insert into public.bookings (class_id, profile_id, status)
  values (p_class_id, p_profile_id, 'confirmed')
  returning id into v_booking_id;

  return v_booking_id;

exception
  when unique_violation then
    raise exception 'Booking already exists' using errcode = 'P0004';
end;
$$;
```

## Function Returning Tables

```sql
create or replace function public.search_classes(
  p_tenant_id uuid,
  p_search text default null,
  p_limit int default 20
)
returns table (id uuid, title text, start_time timestamptz, available_spots int)
language plpgsql
security invoker
set search_path = ''
stable
as $$
begin
  return query
  select c.id, c.title, c.start_time,
         (c.max_attendees - c.current_attendees) as available_spots
  from public.classes c
  where c.tenant_id = p_tenant_id
    and c.start_time > now()
    and (p_search is null or c.title ilike '%' || p_search || '%')
  order by c.start_time
  limit p_limit;
end;
$$;
```

## Complete Function Template

```sql
-- =============================================================================
-- Function: public.function_name
-- Description: What this function does
-- Security: INVOKER | DEFINER (explain why if DEFINER)
-- =============================================================================

create or replace function public.function_name(
  p_arg1 uuid,
  p_arg2 text default null
)
returns return_type
language plpgsql
security invoker
set search_path = ''
stable
as $$
declare
  v_result return_type;
begin
  -- Implementation
  return v_result;
exception
  when others then
    raise exception 'function_name failed: %', sqlerrm using errcode = sqlstate;
end;
$$;

grant execute on function public.function_name to authenticated;
comment on function public.function_name is 'Brief description';
```

## CLI Commands

| Command | Purpose |
|---------|---------|
| `supabase db reset` | Reset DB and re-run migrations |
| `supabase gen types typescript --local` | Regenerate types |
| `supabase secrets set KEY=value` | Store secrets for Edge Functions |

## Boundaries

**Always do**:
- Set `search_path = ''` on ALL functions
- Use fully qualified names (`public.tablename`)
- Store API keys/secrets in Supabase Vault
- Add explicit `grant` for SECURITY DEFINER functions
- Specify volatility (`immutable`, `stable`, `volatile`)

**Ask first**:
- Before using SECURITY DEFINER
- Before creating functions that modify multiple tables
- Before adding functions that bypass RLS

**Never do**:
- Hardcode API keys or secrets in function code
- Create SECURITY DEFINER without `search_path = ''`
- Skip permission validation in SECURITY DEFINER functions
- Use unqualified table/function names
- Grant vault access to `anon` or `public` roles
