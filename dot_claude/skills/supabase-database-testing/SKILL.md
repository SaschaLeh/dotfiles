---
name: supabase-database-testing
description: Testing Supabase PostgreSQL databases with pgTAP. Covers unit testing functions, RLS policy verification, test assertions, simulating authenticated users, and test file organization.
---

# Supabase Database Testing with pgTAP

You are a PostgreSQL testing expert using pgTAP to write comprehensive database tests.

> **Related Skills:**
> - For RLS policy patterns to test, see `supabase-rls-policies`
> - For function patterns to test, see `supabase-database-functions`
> - For query performance testing, see `supabase-performance`

## pgTAP Setup

### Enable Extension

```sql
-- In a migration (one-time setup)
create extension if not exists pgtap with schema extensions;
```

### Test File Location

Place tests in `supabase/tests/` with `.sql` extension:

```
supabase/
├── migrations/
└── tests/
    ├── test_booking_functions.sql
    ├── test_rls_policies.sql
    └── test_triggers.sql
```

## Test File Structure

```sql
-- supabase/tests/test_example.sql

begin;

-- Declare number of tests (required)
select plan(5);

-- =============================================================================
-- TEST SETUP
-- =============================================================================

-- Create test data here...

-- =============================================================================
-- TESTS
-- =============================================================================

select ok(true, 'Test 1 description');
select ok(true, 'Test 2 description');
-- ... more tests

-- =============================================================================
-- CLEANUP
-- =============================================================================

select * from finish();
rollback;  -- Always rollback to keep DB clean
```

## pgTAP Assertion Reference

### Basic Assertions

| Function | Purpose | Example |
|----------|---------|---------|
| `ok(bool, desc)` | Value is true | `select ok(1 = 1, 'Math works');` |
| `is(got, expected, desc)` | Equality | `select is(my_fn(), 'expected');` |
| `isnt(got, expected, desc)` | Inequality | `select isnt(my_fn(), 'wrong');` |
| `matches(got, regex, desc)` | Regex match | `select matches(email, '^.+@.+$');` |

### Function Testing

| Function | Purpose | Example |
|----------|---------|---------|
| `has_function(schema, name, args)` | Function exists | `select has_function('public', 'my_fn', array['uuid']);` |
| `function_returns(schema, name, type)` | Return type | `select function_returns('public', 'my_fn', 'text');` |
| `function_lang_is(schema, name, lang)` | Language check | `select function_lang_is('public', 'my_fn', 'plpgsql');` |
| `is_definer(schema, name)` | Security definer | `select is_definer('public', 'my_fn');` |

### Query Assertions

| Function | Purpose | Example |
|----------|---------|---------|
| `lives_ok(sql, desc)` | Query succeeds | `select lives_ok($$ select my_fn() $$);` |
| `throws_ok(sql, errcode, desc)` | Query raises error | `select throws_ok($$ select my_fn(null) $$, 'P0001');` |
| `is_empty(sql, desc)` | No rows returned | `select is_empty($$ select * from t where false $$);` |
| `results_eq(sql1, sql2, desc)` | Results match | `select results_eq('select 1', 'select 1');` |
| `results_ne(sql1, sql2, desc)` | Results differ | `select results_ne('select 1', 'select 2');` |

### Table/Schema Assertions

| Function | Purpose |
|----------|---------|
| `has_table(schema, name)` | Table exists |
| `has_column(schema, table, column)` | Column exists |
| `col_type_is(schema, table, col, type)` | Column type |
| `col_not_null(schema, table, column)` | NOT NULL constraint |
| `has_index(schema, table, index)` | Index exists |

## Testing Functions

### Basic Function Test

```sql
begin;
select plan(4);

-- Test function exists
select has_function(
  'public',
  'calculate_price',
  array['uuid', 'uuid'],
  'calculate_price function exists'
);

-- Test return type
select function_returns(
  'public',
  'calculate_price',
  'numeric',
  'Returns numeric'
);

-- Test actual behavior
select is(
  public.calculate_price(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
  ),
  100.00::numeric,
  'Returns expected price'
);

-- Test error handling
select throws_ok(
  $$ select public.calculate_price(null, null) $$,
  'P0002',
  'Throws error for null input'
);

select * from finish();
rollback;
```

## Testing RLS Policies

### Simulating Authenticated Users

```sql
begin;
select plan(4);

-- =============================================================================
-- SETUP: Create test users and data
-- =============================================================================

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'user1@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'user2@test.com');

insert into public.tenants (id, name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Tenant');

insert into public.bookings (id, tenant_id, profile_id, status) values
  ('b1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'confirmed'),
  ('b2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'confirmed');

-- =============================================================================
-- TEST: User isolation
-- =============================================================================

-- Authenticate as User 1
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- User 1 should only see their own bookings
select results_eq(
  $$ select count(*)::int from public.bookings $$,
  $$ select 1 $$,
  'User 1 sees only their booking'
);

-- User 1 can create their own booking
select lives_ok(
  $$ insert into public.bookings (tenant_id, profile_id, status)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'pending') $$,
  'User 1 can create their own booking'
);

-- =============================================================================
-- TEST: Cross-user protection
-- =============================================================================

-- Switch to User 2
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

-- User 2 cannot see User 1's bookings
select results_eq(
  $$ select count(*)::int from public.bookings $$,
  $$ select 1 $$,
  'User 2 sees only their booking'
);

-- User 2 cannot modify User 1's booking
select results_ne(
  $$ update public.bookings
     set status = 'cancelled'
     where profile_id = '11111111-1111-1111-1111-111111111111'
     returning 1 $$,
  $$ values(1) $$,
  'User 2 cannot modify User 1 bookings'
);

select * from finish();
rollback;
```

### Testing Admin Access

```sql
begin;
select plan(2);

-- Setup admin user with role
insert into auth.users (id, email) values
  ('admin0000-0000-0000-0000-000000000000', 'admin@test.com');

insert into public.user_roles (user_id, tenant_id, role) values
  ('admin0000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin');

-- Authenticate as admin
set local role authenticated;
set local request.jwt.claim.sub = 'admin0000-0000-0000-0000-000000000000';

-- Admin can see all tenant bookings
select results_eq(
  $$ select count(*)::int from public.bookings
     where tenant_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  $$ select 3 $$,  -- Adjust based on test data
  'Admin sees all tenant bookings'
);

-- Admin can modify any booking in tenant
select lives_ok(
  $$ update public.bookings
     set status = 'cancelled'
     where tenant_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     limit 1 $$,
  'Admin can modify bookings'
);

select * from finish();
rollback;
```

## Testing Triggers

```sql
begin;
select plan(2);

-- Setup
insert into public.classes (id, tenant_id, title, max_attendees, current_attendees)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test', 10, 0);

-- Test: Booking trigger updates attendee count
insert into public.bookings (class_id, profile_id, tenant_id, status)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'confirmed');

select is(
  (select current_attendees from public.classes where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  1,
  'Trigger incremented attendee count'
);

-- Test: updated_at trigger
update public.classes
set title = 'Updated Title'
where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

select ok(
  (select updated_at > created_at from public.classes where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'Trigger updated updated_at timestamp'
);

select * from finish();
rollback;
```

## Test Helpers Pattern

Create reusable test helpers in a setup migration:

```sql
-- supabase/tests/00_test_helpers.sql (run first)

create schema if not exists tests;

create or replace function tests.create_test_user(p_email text)
returns uuid
language plpgsql
as $$
declare
  v_user_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email)
  values (v_user_id, p_email);
  return v_user_id;
end;
$$;

create or replace function tests.authenticate_as(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  set local role authenticated;
  execute format('set local request.jwt.claim.sub = %L', p_user_id);
end;
$$;

create or replace function tests.reset_auth()
returns void
language plpgsql
as $$
begin
  reset role;
  set local request.jwt.claim.sub = '';
end;
$$;
```

Usage in tests:

```sql
begin;
select plan(1);

-- Use helpers
select tests.authenticate_as(tests.create_test_user('test@example.com'));

select lives_ok($$ select * from public.bookings $$, 'Query works');

select tests.reset_auth();
select * from finish();
rollback;
```

## Running Tests

```bash
# Run all database tests
supabase test db

# Run specific test file
supabase test db supabase/tests/test_booking_functions.sql

# Run tests with verbose output
supabase test db --debug
```

## Test Organization Best Practices

| Pattern | Description |
|---------|-------------|
| One file per domain | `test_bookings.sql`, `test_payments.sql` |
| Prefix with `test_` | Makes test files easy to identify |
| Setup at top | Create test data before assertions |
| Always `rollback` | Keep database clean between runs |
| Use `plan(n)` | Declare expected test count |
| Descriptive messages | `'User can only see own bookings'` |

## Boundaries

**Always do**:
- Use `begin` / `rollback` to isolate tests
- Declare test count with `plan(n)`
- Create isolated test data (don't rely on existing data)
- Test both success and error cases
- Test RLS policies with multiple user contexts

**Ask first**:
- Before creating test helpers that modify auth schema
- Before testing against production-like data volumes

**Never do**:
- Commit test data to the database
- Skip RLS tests for new tables
- Use real user emails/data in tests
- Leave tests without descriptions
