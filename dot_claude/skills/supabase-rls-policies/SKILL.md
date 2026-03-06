---
name: supabase-rls-policies
description: Creating Row Level Security policies for Supabase PostgreSQL. Covers SELECT/INSERT/UPDATE/DELETE policies, role-based access, performance optimization with indexes, auth.uid() and auth.jwt() helpers, and multi-tenant patterns.
---

# Supabase Row Level Security Policies

You are a Supabase Postgres expert specializing in Row Level Security (RLS) policies.

## Critical: RLS is Mandatory

**Every table with user data MUST have RLS enabled.** Lack of RLS is the #1 security issue in Supabase setups.

```sql
-- ALWAYS enable RLS on tables
alter table public.my_table enable row level security;
```

## Policy Structure by Operation

### SELECT Policies

**Always use USING, never WITH CHECK.**

```sql
create policy "Users can view own records"
  on public.bookings
  for select
  to authenticated
  using ((select auth.uid()) = profile_id);
```

### INSERT Policies

**Always use WITH CHECK, never USING.**

```sql
create policy "Users can create own records"
  on public.bookings
  for insert
  to authenticated
  with check ((select auth.uid()) = profile_id);
```

### UPDATE Policies

**Use both USING (which rows) and WITH CHECK (new values valid).**

```sql
create policy "Users can update own records"
  on public.bookings
  for update
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);
```

### DELETE Policies

**Always use USING, never WITH CHECK.**

```sql
create policy "Users can delete own records"
  on public.bookings
  for delete
  to authenticated
  using ((select auth.uid()) = profile_id);
```

## Roles Reference

| Role | Description | Use Case |
|------|-------------|----------|
| `anon` | Unauthenticated requests | Public data, landing pages |
| `authenticated` | Logged-in users | User-specific data |
| `service_role` | Server-side operations | Admin functions, webhooks |

```sql
-- Target specific roles
create policy "Public data viewable by anyone"
  on public.locations
  for select
  to authenticated, anon
  using (true);

-- Authenticated only
create policy "Profiles viewable by logged-in users"
  on public.profiles
  for select
  to authenticated
  using (true);
```

## Auth Helper Functions

### auth.uid()

Returns the current user's UUID from the JWT.

```sql
-- OPTIMIZED: Wrap in select for caching
create policy "Users see own data"
  on public.bookings
  for select
  to authenticated
  using ((select auth.uid()) = profile_id);

-- NOT OPTIMIZED: Called per-row
create policy "Users see own data"
  on public.bookings
  for select
  to authenticated
  using (auth.uid() = profile_id);
```

### auth.jwt()

Access JWT claims for role-based access.

```sql
-- Check custom claims in app_metadata
create policy "Admins can view all"
  on public.bookings
  for select
  to authenticated
  using (
    (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

-- Check team membership (array in app_metadata)
create policy "Team members can view"
  on public.projects
  for select
  to authenticated
  using (
    team_id = any(
      select jsonb_array_elements_text(
        (select auth.jwt() -> 'app_metadata' -> 'teams')
      )::uuid
    )
  );
```

## Multi-Tenant Patterns

### Tenant Isolation via User Roles Table

```sql
-- User has access to tenant through a roles table
create policy "Users access tenant data"
  on public.classes
  for select
  to authenticated
  using (
    tenant_id in (
      select ur.tenant_id
      from public.user_roles ur
      where ur.user_id = (select auth.uid())
    )
  );
```

### Admin Access Within Tenant

```sql
create policy "Admins manage tenant bookings"
  on public.bookings
  for all
  to authenticated
  using (
    tenant_id in (
      select ur.tenant_id
      from public.user_roles ur
      where ur.user_id = (select auth.uid())
        and ur.role in ('admin', 'manager')
    )
  )
  with check (
    tenant_id in (
      select ur.tenant_id
      from public.user_roles ur
      where ur.user_id = (select auth.uid())
        and ur.role in ('admin', 'manager')
    )
  );
```

## Performance Optimization

### 1. Always Add Indexes

```sql
-- Index columns used in RLS policies
create index idx_bookings_profile_id
  on public.bookings(profile_id);

create index idx_user_roles_user_tenant
  on public.user_roles(user_id, tenant_id);
```

### 2. Wrap Functions with SELECT

```sql
-- FAST: Caches per-statement
using ((select auth.uid()) = profile_id)

-- SLOW: Evaluates per-row
using (auth.uid() = profile_id)
```

### 3. Avoid Joins to Source Table

```sql
-- SLOW: Joins source to target
create policy "slow_policy" on test_table
  using (
    (select auth.uid()) in (
      select user_id from team_user
      where team_user.team_id = team_id  -- joins to test_table
    )
  );

-- FAST: No join, uses set membership
create policy "fast_policy" on test_table
  using (
    team_id in (
      select team_id from team_user
      where user_id = (select auth.uid())
    )
  );
```

### 4. Specify Roles with TO Clause

```sql
-- Stops evaluation early for non-matching roles
create policy "auth_only" on test_table
  for select
  to authenticated  -- anon requests skip this policy entirely
  using ((select auth.uid()) = user_id);
```

## Policy Naming Convention

**Format:** `{table}_{operation}_{scope}`

| Operation | Scope Examples |
|-----------|---------------|
| `select` | `own`, `tenant`, `public`, `admin` |
| `insert` | `own`, `tenant`, `admin` |
| `update` | `own`, `tenant`, `admin` |
| `delete` | `own`, `tenant`, `admin` |

```sql
create policy "bookings_select_own" on public.bookings for select ...;
create policy "bookings_insert_own" on public.bookings for insert ...;
create policy "bookings_update_own" on public.bookings for update ...;
create policy "bookings_delete_own" on public.bookings for delete ...;
create policy "bookings_all_service_role" on public.bookings for all to service_role ...;
```

## Common Patterns

### Public Read, Authenticated Write

```sql
-- Anyone can read
create policy "locations_select_public"
  on public.locations
  for select
  to authenticated, anon
  using (true);

-- Only authenticated can create
create policy "locations_insert_authenticated"
  on public.locations
  for insert
  to authenticated
  with check (true);
```

### Owner-Only Access

```sql
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
```

### Service Role Bypass

```sql
-- Service role for server-side operations
create policy "bookings_all_service_role"
  on public.bookings
  for all
  to service_role
  using (true)
  with check (true);
```

### MFA Requirement

```sql
create policy "sensitive_data_requires_mfa"
  on public.payment_methods
  for select
  to authenticated
  using (
    (select auth.jwt() ->> 'aal') = 'aal2'
  );
```

## Anti-Patterns to Avoid

### Never Use FOR ALL for User Policies

```sql
-- BAD: Combines operations, harder to audit
create policy "bad_policy" on bookings for all using (...);

-- GOOD: Separate policies per operation
create policy "bookings_select_own" on bookings for select ...;
create policy "bookings_insert_own" on bookings for insert ...;
create policy "bookings_update_own" on bookings for update ...;
create policy "bookings_delete_own" on bookings for delete ...;
```

### Avoid RESTRICTIVE Policies

```sql
-- RESTRICTIVE policies require ALL to pass (AND logic)
-- PERMISSIVE policies require ANY to pass (OR logic)

-- Prefer PERMISSIVE (default) and design policies accordingly
create policy "permissive_policy" on bookings
  for select
  to authenticated
  using (...);  -- Defaults to PERMISSIVE
```

### Never Skip Role Specification

```sql
-- BAD: Applies to all roles including anon
create policy "bad_policy" on bookings
  for select
  using (auth.uid() = profile_id);

-- GOOD: Explicit role targeting
create policy "good_policy" on bookings
  for select
  to authenticated
  using ((select auth.uid()) = profile_id);
```

## Boundaries

**Always do**:
- Enable RLS on every table with user data
- Create separate policies per operation (SELECT, INSERT, UPDATE, DELETE)
- Wrap `auth.uid()` and `auth.jwt()` in `(select ...)`
- Add indexes on columns used in policy conditions
- Specify target roles with `TO` clause
- Use descriptive policy names

**Ask first**:
- Before creating RESTRICTIVE policies
- Before using `FOR ALL` (usually wrong choice)
- Before creating policies that bypass tenant isolation

**Never do**:
- Leave RLS disabled on tables with user data
- Use unindexed columns in policy conditions
- Skip the `TO` role specification
- Create recursive policies that reference the same table unsafely
