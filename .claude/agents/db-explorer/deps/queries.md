# DB Explorer — Common SQL Queries

Reference file for db-explorer command.
**Load when:** PHASE 2: EXPLORE

---

## Schema Exploration

### List tables with row counts

```sql
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public';
```

### Table structure with constraints

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = '<table>';
```

### Indexes

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = '<table>';
```

### Foreign keys

```sql
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = '<table>';
```

---

## Data Analysis

### Sample data

```sql
SELECT * FROM <table> LIMIT 10;
```

### Count with grouping

```sql
SELECT <column>, COUNT(*) as count
FROM <table>
GROUP BY <column>
ORDER BY count DESC
LIMIT 10;
```

### Date range

```sql
SELECT DATE(created_at) as date, COUNT(*)
FROM <table>
GROUP BY DATE(created_at)
ORDER BY date DESC
LIMIT 30;
```

---

## Integrity Checks

### Orphan records (FK not enforced)

```sql
SELECT child.*
FROM <child_table> child
LEFT JOIN <parent_table> parent ON child.<fk> = parent.id
WHERE parent.id IS NULL;
```

### Duplicate detection

```sql
SELECT <column>, COUNT(*) as count
FROM <table>
GROUP BY <column>
HAVING COUNT(*) > 1;
```

### NULL analysis

```sql
SELECT
    COUNT(*) as total,
    COUNT(<column>) as non_null,
    COUNT(*) - COUNT(<column>) as null_count
FROM <table>;
```
