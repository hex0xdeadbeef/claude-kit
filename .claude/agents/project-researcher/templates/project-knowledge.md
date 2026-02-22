# Project Knowledge: <Project Name>

**Last Updated:** <ISO 8601 timestamp>
**Version:** <semantic version or git hash>
**Researcher:** project-researcher agent

---

## Executive Summary

<1-2 paragraph overview of project, tech stack, architecture>

---

## Architecture Deep-Dive

### Pattern: <Detected Pattern>
<Comprehensive explanation of architecture with diagrams>

### Layers
<Detailed description of each layer: purpose, responsibilities, dependencies>

### Dependency Flow
```
<ASCII diagram of dependency flow>
```

### Architectural Decisions

| Decision | Rationale | Date | Confidence |
|----------|-----------|------|------------|
| <Decision from analysis or git history> | <Why> | <When> | HIGH/MEDIUM/LOW |

---

## Technology Stack

### Primary Language: <Language>
- Version: <from go.mod, package.json, etc>
- Standard: <language standard/edition>

### Frameworks

| Framework | Version | Purpose | Usage Pattern |
|-----------|---------|---------|---------------|
| <from PHASE 2 detection> | <version> | <purpose> | <how it's used> |

### Libraries

| Library | Category | Version | Usage |
|---------|----------|---------|-------|
| <key dependencies> | <database/http/logging/etc> | <version> | <where/how used> |

---

## Core Domain

### Entities

| Entity | Location | Purpose | Key Fields | Relations |
|--------|----------|---------|------------|-----------|
| <from PHASE 4 analysis> | <file path> | <business purpose> | <critical fields> | <relationships> |

### Value Objects

| Value Object | Location | Purpose | Invariants |
|--------------|----------|---------|------------|
| <if DDD detected> | <file path> | <purpose> | <validation rules> |

### Aggregates

| Aggregate Root | Location | Bounded Context | Entities | Invariants |
|----------------|----------|-----------------|----------|------------|
| <if DDD detected> | <file path> | <context> | <contained entities> | <business rules> |

---

## Database Schema (from PHASE 4.5)

**Note:** This section is populated when PostgreSQL MCP is available.

### Tables

| Table | Columns | Primary Key | Foreign Keys | Domain Entity |
|-------|---------|-------------|--------------|---------------|
| <from mcp__postgres__list_tables> | <count> | <pk column> | <fk list> | <mapped entity> |

### Column Details

#### <table_name>

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| <from mcp__postgres__describe_table> | <type> | <yes/no> | <default> | <purpose> |

### Indexes

| Table | Index Name | Columns | Type | Purpose |
|-------|------------|---------|------|---------|
| <table> | <index_name> | <columns> | btree/hash/gin | <why needed> |

### Entity-Table Alignment

| Domain Entity | DB Table | Status | Mismatches |
|---------------|----------|--------|------------|
| entity.{Entity1} | {table_1} | ALIGNED | - |
| entity.{Entity2} | {table_2} | ALIGNED | - |

### Data Statistics

| Table | Row Count | Avg Row Size | Last Analyzed |
|-------|-----------|--------------|---------------|
| <table> | <count from query> | <size> | <timestamp> |

---

## Conventions Catalog

### Naming Conventions

```go
// File naming
<detected pattern with examples>

// Type naming
<detected pattern with examples>

// Function naming
<detected pattern with examples>

// Variable naming
<detected pattern with examples>
```

### Code Structure Patterns

```go
// Function length: <avg> lines (max <max> recommended)
// Nesting depth: <avg> levels (max <max> recommended)
// Early returns: <yes/no pattern detected>

// Example from codebase:
<actual code showing patterns>
```

### Testing Conventions

```go
// Test file pattern: <pattern>
// Test function pattern: <pattern>
// Table-driven: <yes/no/percentage>
// Testing framework: <testify/standard/other>
// Mock strategy: <pattern>

// Example from codebase:
<actual test code>
```

### Error Handling Conventions

```go
// Error creation: <pattern>
// Error wrapping: <pattern>
// Error types: <custom types/sentinel/plain>
// Logging + return: <yes/no/pattern>

// Example from codebase:
<actual error handling code>
```

### Logging Conventions

```go
// Logger: <slog/logrus/zap/other>
// Log levels: <pattern>
// Structured logging: <yes/no>
// Context propagation: <pattern>

// Example from codebase:
<actual logging code>
```

---

## Entry Points Map

### CLI

| Binary | Location | Purpose | Main Dependencies |
|--------|----------|---------|-------------------|
| <from PHASE 4> | cmd/<name>/main.go | <purpose> | <key deps> |

### HTTP/gRPC Services

| Service | Location | Framework | Routes/Methods |
|---------|----------|-----------|----------------|
| <from PHASE 4> | <path> | <framework> | <key endpoints> |

### Workers/Jobs

| Worker | Location | Trigger | Purpose |
|--------|----------|---------|---------|
| <from PHASE 4> | <path> | <cron/queue/event> | <purpose> |

---

## External Integrations

### Databases

| Database | Driver | Location | Usage Pattern |
|----------|--------|----------|---------------|
| <from PHASE 4> | <driver> | <config location> | <how accessed> |

### Caches

| Cache | Driver | Location | TTL Strategy |
|-------|--------|----------|--------------|
| <from PHASE 4> | <driver> | <config> | <ttl pattern> |

### Message Queues

| Queue | Driver | Location | Topics/Queues |
|-------|--------|----------|---------------|
| <from PHASE 4> | <driver> | <config> | <topics used> |

### External APIs

| API | Client | Location | Auth Method |
|-----|--------|----------|-------------|
| <from PHASE 4> | <http client> | <where called> | <auth type> |

---

## Pattern Catalog

### Design Patterns Used

| Pattern | Location | Purpose | Example |
|---------|----------|---------|---------|
| <Factory/Strategy/Repository/etc> | <file path> | <purpose> | <code ref> |

### DI Strategy

```go
// Composition Root: <location>
// DI Framework: <wire/dig/fx/manual>
// Interface location: <port/ or domain/>

// Example:
<actual DI code>
```

---

## Decision Log

**Track major decisions from git history and code analysis**

| Date | Decision | Rationale | Impact | Status |
|------|----------|-----------|--------|--------|
| <from git commits> | <what changed> | <commit message/PR> | <impact> | Active/Deprecated |

---

## Technical Debt

**Detected from code analysis**

| Area | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| <from analysis> | <what's wrong> | HIGH/MEDIUM/LOW | <how to fix> |

---

## Change History

### <Current Version> - <Date>

**Changes detected:**
- <list from git analysis in UPDATE mode>

**Sections updated:**
- <list of updated sections>

**New patterns detected:**
- <new conventions/patterns found>

---

## Metadata

- **Analysis Mode:** <CREATE/AUGMENT/UPDATE>
- **Confidence Score:** <overall HIGH/MEDIUM/LOW>
- **Low Confidence Areas:** <list areas needing manual review>
- **Recommended Reviews:** <list sections to verify>
