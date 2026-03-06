---
name: supabase-migrations
description: Creating Supabase database migrations with proper naming, RLS policies, security best practices, and PostgreSQL functions. Covers table creation, schema changes, security definer functions, and multi-tenant patterns.
---

# Supabase Database Migrations

You are a PostgreSQL expert creating secure, production-ready database migrations for Supabase.

> **Related Skills:**
> - For complex RLS patterns, see `supabase-rls-policies`
> - For database functions, see `supabase-database-functions`
> - For testing migrations, see `supabase-database-testing`

## Critical: Check Current Schema First

Before creating ANY migration:

1. **Read current schema**: `src/model/database.types.ts`
2. **Check existing migrations**: `supabase/migrations/` - avoid conflicts
3. **Understand tenant model**: ALL tables use `tenant_id` for isolation

## File Naming Convention

**Format**: `YYYYMMDDHHmmss_short_description.sql`

| Segment | Format | Example |
|---------|--------|---------|
| Year    | YYYY   | 2026    |
| Month   | MM     | 01      |
| Day     | DD     | 22      |
| Hour    | HH     | 14 (24h)|
| Minute  | mm     | 30      |
| Second  | ss     | 45      |

**Examples**:
```
20260122143045_create_bookmarks_table.sql
20260122150000_add_status_column_to_orders.sql
20260122160000_fix_rls_policies_for_payments.sql
```

**Location**: `supabase/migrations/`

## Migration File Template

```sql
-- ============================================================================
-- Migration: [Title]
-- Description: [What this migration does]
-- Date: YYYY-MM-DD
-- ============================================================================
--
-- Changes:
-- 1. [Change 1]
-- 2. [Change 2]
--
-- ============================================================================

-- =============================================================================
-- SECTION 1: [Section Name]
-- =============================================================================

-- [Your SQL here]

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================
```

## SQL Style Guidelines

- **Lowercase SQL**: `select`, `create table`, `alter table`
- **Explicit schema**: Always prefix with `public.` (e.g., `public.bookings`)
- **Comments**: Explain WHY, not just WHAT
- **Destructive operations**: Add prominent warnings

```sql
-- WARNING: This drops the legacy_data column permanently
-- Ensure all data has been migrated before applying
alter table public.users drop column if exists legacy_data;
```

## Table Creation Pattern

Every table MUST:
1. Enable RLS
2. Have granular policies per role and operation
3. Include `tenant_id` for multi-tenancy
4. Have appropriate indexes

```sql
-- =============================================================================
-- Create bookmarks table
-- =============================================================================

create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  created_at timestamptz not null default now(),

  -- Prevent duplicate bookmarks
  unique (tenant_id, profile_id, target_type, target_id)
);

-- Index for common query patterns
create index if not exists idx_bookmarks_profile
  on public.bookmarks(tenant_id, profile_id);
create index if not exists idx_bookmarks_target
  on public.bookmarks(tenant_id, target_type, target_id);

comment on table public.bookmarks is 'User bookmarks for various content types';

-- =============================================================================
-- RLS Policies
-- =============================================================================

alter table public.bookmarks enable row level security;

-- SELECT: Users can see their own bookmarks
create policy bookmarks_select_own
  on public.bookmarks for select
  to authenticated
  using (profile_id = auth.uid());

-- INSERT: Users can create their own bookmarks
create policy bookmarks_insert_own
  on public.bookmarks for insert
  to authenticated
  with check (profile_id = auth.uid());

-- DELETE: Users can delete their own bookmarks
create policy bookmarks_delete_own
  on public.bookmarks for delete
  to authenticated
  using (profile_id = auth.uid());

-- Service role: Full access for system operations
create policy bookmarks_all_service_role
  on public.bookmarks for all
  to service_role
  using (true)
  with check (true);
```

## RLS Policy Guidelines

**Granular policies**: One policy per operation AND role.

| Operation | Policy Naming Pattern |
|-----------|----------------------|
| SELECT    | `{table}_select_{scope}` |
| INSERT    | `{table}_insert_{scope}` |
| UPDATE    | `{table}_update_{scope}` |
| DELETE    | `{table}_delete_{scope}` |
| ALL       | `{table}_all_{role}` |

**Common scopes**: `own`, `tenant`, `admin`, `public`, `service_role`

**Policy patterns by access level**:

```sql
-- Public read (reference data)
create policy items_select_public
  on public.items for select
  to authenticated, anon
  using (true);

-- Own data only
create policy items_select_own
  on public.items for select
  to authenticated
  using (profile_id = auth.uid());

-- Tenant-scoped with role check (optimized)
create policy items_select_tenant_admin
  on public.items for select
  to authenticated
  using (
    tenant_id in (
      select ur.tenant_id
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role = 'admin'
    )
  );
```

## Function Creation Pattern

**SECURITY DEFINER functions MUST have**:
- Explicit `search_path = ''`
- Fully qualified table names (`public.tablename`)
- Parameter validation
- Explicit grants

```sql
create or replace function public.get_user_stats(
  p_tenant_id uuid,
  p_user_id uuid
)
returns table (
  booking_count bigint,
  total_spent numeric
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Validate caller has access
  if not exists (
    select 1 from public.user_roles
    where user_id = auth.uid()
      and tenant_id = p_tenant_id
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select
    count(*) as booking_count,
    coalesce(sum(amount), 0) as total_spent
  from public.bookings b
  join public.payments p on p.reference_id = b.id
  where b.tenant_id = p_tenant_id
    and b.profile_id = p_user_id
    and p.status = 'completed';
end;
$$;

grant execute on function public.get_user_stats to authenticated, service_role;
```

**SECURITY INVOKER functions** (default, safer):

```sql
create or replace function public.calculate_total(items numeric[])
returns numeric
language plpgsql
-- No SECURITY DEFINER = uses caller's permissions
as $$
begin
  return coalesce(
    (select sum(x) from unnest(items) as x),
    0
  );
end;
$$;
```

## Common Migration Patterns

### Adding a Column

```sql
alter table public.classes
  add column if not exists is_featured boolean default false;

comment on column public.classes.is_featured is 'Featured classes appear prominently in listings';
```

### Adding an Enum Type

```sql
-- Create enum if not exists
do $$
begin
  if not exists (select 1 from pg_type where typname = 'booking_source') then
    create type booking_source as enum ('web', 'mobile', 'api', 'admin');
  end if;
end $$;

-- Use the enum
alter table public.bookings
  add column if not exists source booking_source default 'web';
```

### Safe Column Removal

```sql
-- =============================================================================
-- WARNING: DESTRUCTIVE - Removing deprecated_field column
-- =============================================================================
-- This column has been replaced by new_field as of migration 20260101...
-- All data has been migrated. This is safe to drop.
-- =============================================================================

alter table public.users
  drop column if exists deprecated_field;
```

### Creating an Index

```sql
-- Improve query performance for booking lookups
create index concurrently if not exists idx_bookings_class_date
  on public.bookings(tenant_id, class_id, created_at desc);
```

## Trigger Pattern

```sql
-- Function for the trigger
create or replace function public.handle_booking_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Update attendee count
  update public.classes
  set current_attendees = current_attendees + 1
  where id = new.class_id;

  return new;
end;
$$;

-- Create trigger
drop trigger if exists on_booking_created on public.bookings;
create trigger on_booking_created
  after insert on public.bookings
  for each row
  execute function public.handle_booking_created();
```

## CLI Commands Reference

| Command | Purpose |
|---------|---------|
| `supabase migration new <name>` | Create new migration file |
| `supabase db reset` | Reset local DB, apply all migrations |
| `supabase db diff -f <name>` | Generate migration from Dashboard changes |
| `supabase migration up` | Apply pending migrations |
| `supabase migration down --last 1` | Revert last migration |
| `supabase gen types typescript --local` | Regenerate TypeScript types |

## After Migration Checklist

1. **Apply locally**: `supabase db reset`
2. **Regenerate types**: `supabase gen types typescript --local > src/model/database.types.ts`
3. **Check advisors**: Run security/performance advisors in Supabase Dashboard
4. **Test**: Verify RLS policies work as expected
5. **Build**: `npm run build` to check TypeScript types

## Boundaries

**Always do**:
- Enable RLS on every table
- Use `tenant_id` for multi-tenant isolation
- Add comments explaining complex logic
- Set `search_path = ''` on SECURITY DEFINER functions
- Create granular RLS policies (one per operation/role)

**Ask first**:
- Before creating migrations that modify existing data
- Before adding new dependencies (extensions)
- Before changing column types on large tables

**Never do**:
- Run `supabase db push` without explicit user request
- Create tables without RLS
- Use `any` in recursive RLS policies (infinite recursion risk)
- Hardcode UUIDs in migrations (use variables/lookups)
- Skip the header comment block
