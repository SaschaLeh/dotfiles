---
name: supabase-performance
description: Optimizing Supabase PostgreSQL query performance. Covers indexing strategies, pagination, selective columns, realtime subscriptions, caching patterns, connection pooling, and batch operations.
---

# Supabase Performance Optimization

You are a PostgreSQL performance expert optimizing Supabase applications.

## 1. Query Optimization

### Select Only Required Columns

```sql
-- GOOD: Select specific columns
select id, name, email from users where age > 25;

-- BAD: Select all columns
select * from users where age > 25;
```

```typescript
// JavaScript equivalent
const { data } = await supabase
  .from('users')
  .select('id, name, email')  // Only what you need
  .gt('age', 25);
```

### Optimize WHERE Clauses

**Use indexed columns with equality and range operators.**

```sql
-- FAST: Equality + range on indexed columns
select * from products
where category_id = 123
  and price between 10 and 50;

-- Create supporting index
create index idx_products_category_price
  on products(category_id, price);
```

```typescript
const { data } = await supabase
  .from('products')
  .select('*')
  .eq('category_id', 123)
  .gte('price', 10)
  .lte('price', 50);
```

**Avoid leading wildcards in LIKE:**

```sql
-- SLOW: Full table scan
select * from products where name like '%widget%';

-- FASTER: Use full-text search instead
select * from products
where to_tsvector('english', name) @@ to_tsquery('widget');
```

### Use EXISTS Instead of COUNT

```sql
-- FAST: Stops at first match
select exists (select 1 from users where email = 'test@example.com');

-- SLOW: Counts all matches
select count(*) from users where email = 'test@example.com';
```

```typescript
// Check existence efficiently
const { count } = await supabase
  .from('users')
  .select('id', { count: 'exact', head: true })
  .eq('email', 'test@example.com');

const exists = count > 0;
```

## 2. Indexing Strategies

### Index Types

| Type | Use Case | Example |
|------|----------|---------|
| B-tree (default) | Equality, range, sorting | `create index idx_email on users(email);` |
| Hash | Equality only | `create index idx_session using hash(session_id);` |
| GIN | Arrays, JSONB, full-text | `create index idx_tags using gin(tags);` |
| GiST | Geometric, full-text | `create index idx_location using gist(coordinates);` |

### Index Columns Used in RLS Policies

```sql
-- If your RLS policy uses profile_id, index it
create policy "users_select_own" on bookings
  for select using ((select auth.uid()) = profile_id);

-- Supporting index
create index idx_bookings_profile on bookings(profile_id);
```

### Multi-Column Indexes

```sql
-- Order matters: most selective first
create index idx_bookings_tenant_date
  on bookings(tenant_id, created_at desc);

-- Supports queries filtering on:
-- 1. tenant_id alone
-- 2. tenant_id AND created_at
-- Does NOT efficiently support: created_at alone
```

### Concurrent Index Creation

```sql
-- For production: doesn't lock the table
create index concurrently idx_bookings_status
  on bookings(status);
```

## 3. Pagination

### Use range() for Offset Pagination

```typescript
const page = 3;
const pageSize = 10;
const start = (page - 1) * pageSize;

const { data } = await supabase
  .from('orders')
  .select('*')
  .range(start, start + pageSize - 1);
```

### Cursor-Based Pagination (Better for Large Datasets)

```typescript
// First page
const { data: firstPage } = await supabase
  .from('orders')
  .select('*')
  .order('created_at', { ascending: false })
  .limit(10);

// Next page using cursor
const lastItem = firstPage[firstPage.length - 1];
const { data: nextPage } = await supabase
  .from('orders')
  .select('*')
  .order('created_at', { ascending: false })
  .lt('created_at', lastItem.created_at)
  .limit(10);
```

```sql
-- SQL equivalent with index support
create index idx_orders_created_desc on orders(created_at desc);

select * from orders
where created_at < '2024-01-15T10:00:00Z'
order by created_at desc
limit 10;
```

## 4. Realtime Optimization

### Selective Subscriptions

```typescript
// GOOD: Filter to specific data
supabase
  .channel('room-messages')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'messages',
    filter: 'room_id=eq.123'  // Only this room
  }, handleChange)
  .subscribe();

// BAD: Subscribe to entire table
supabase
  .channel('all-messages')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'messages'  // No filter = all messages
  }, handleChange)
  .subscribe();
```

### Debounce Client Updates

```typescript
import debounce from 'lodash.debounce';

const saveSearch = debounce(async (term: string) => {
  await supabase
    .from('search_history')
    .upsert({ user_id: userId, term, updated_at: new Date() });
}, 300);

// Call on input change
searchInput.addEventListener('input', (e) => {
  saveSearch(e.target.value);
});
```

### Optimistic Updates

```typescript
function LikeButton({ postId, initialLikes }: Props) {
  const [likes, setLikes] = useState(initialLikes);

  const handleLike = async () => {
    // Optimistic update
    setLikes(prev => prev + 1);

    const { error } = await supabase
      .from('posts')
      .update({ likes: likes + 1 })
      .eq('id', postId);

    if (error) {
      // Revert on failure
      setLikes(prev => prev - 1);
    }
  };

  return <button onClick={handleLike}>Like ({likes})</button>;
}
```

## 5. Batch Operations

### Batch Inserts

```typescript
async function batchInsert(records: Message[]) {
  const batchSize = 100;

  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);

    const { error } = await supabase
      .from('messages')
      .insert(batch);

    if (error) throw error;
  }
}
```

### Batch Upserts

```typescript
const { data, error } = await supabase
  .from('inventory')
  .upsert(
    items.map(item => ({
      sku: item.sku,
      quantity: item.quantity,
      updated_at: new Date()
    })),
    { onConflict: 'sku' }
  );
```

## 6. Data Types

### Use Appropriate Types

```sql
-- GOOD: Specific types
create table products (
  id uuid primary key default gen_random_uuid(),
  name varchar(255) not null,    -- Known max length
  price numeric(10, 2) not null, -- Precise decimals
  metadata jsonb,                -- JSONB for queries
  created_at timestamptz default now()
);

-- BAD: Overly generic
create table products (
  id serial primary key,
  name text,           -- No length hint
  price float,         -- Precision issues
  metadata json,       -- JSON can't be indexed
  created_at timestamp -- Missing timezone
);
```

### JSONB vs JSON

```sql
-- JSONB: Binary, indexable, slower writes
-- Use for: Queried data, filtered data
create index idx_products_metadata on products using gin(metadata);
select * from products where metadata @> '{"featured": true}';

-- JSON: Text, not indexable, faster writes
-- Use for: Write-heavy logs, rarely queried
```

## 7. Connection Management

Supabase manages connection pooling automatically via Supavisor. Best practices:

```typescript
// GOOD: Reuse client instance
const supabase = createClient(url, key);

// In server components, use createClient once per request
export async function getData() {
  const supabase = await createClient();
  return supabase.from('items').select();
}
```

### Transaction Pooling Mode

For serverless/Edge Functions, use transaction pooling:

```typescript
// Use the pooler connection string for Edge Functions
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY,
  {
    db: {
      schema: 'public'
    }
  }
);
```

## 8. Query Analysis

### EXPLAIN ANALYZE

```sql
-- Analyze query performance
explain analyze
select * from bookings
where tenant_id = 'abc-123'
  and status = 'confirmed'
order by created_at desc
limit 10;

-- Look for:
-- - Seq Scan (bad on large tables)
-- - Index Scan (good)
-- - High "actual time" values
```

### Identify Missing Indexes

```sql
-- Find slow queries in pg_stat_statements
select query, calls, mean_exec_time, total_exec_time
from pg_stat_statements
order by mean_exec_time desc
limit 10;
```

## Performance Checklist

| Check | Action |
|-------|--------|
| Selecting `*`? | Select only needed columns |
| Missing index? | Add index on filtered/sorted columns |
| Large offset pagination? | Switch to cursor-based |
| LIKE with leading `%`? | Use full-text search |
| Realtime on full table? | Add subscription filters |
| Many small writes? | Batch operations |
| COUNT for existence? | Use EXISTS instead |

## Boundaries

**Always do**:
- Select only required columns
- Add indexes for RLS policy columns
- Use pagination for large datasets
- Filter realtime subscriptions
- Batch bulk operations

**Ask first**:
- Before adding indexes on frequently-updated columns
- Before implementing complex caching strategies
- Before denormalizing for performance

**Never do**:
- Use `select *` in production code
- Skip indexes on columns used in WHERE/ORDER BY
- Subscribe to entire tables without filters
- Send database updates on every keystroke
