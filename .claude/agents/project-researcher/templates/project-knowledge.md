# Project Knowledge: <Project Name>

**Last Updated:** <ISO 8601 timestamp>
**Version:** <semantic version or git hash>
**Researcher:** project-researcher agent v3.0
**Analysis Method:** <AST-based | grep-based | mixed>

---

## Executive Summary

<1-2 paragraph overview of project, tech stack, architecture>

---

## Project Structure

### Module Map

**Type:** <single module | monorepo>
**Strategy:** <single | per-module | per-module-with-shared-context>

| Module | Language | Type | Dependencies |
|--------|----------|------|-------------|
| <from PHASE 1.5 DISCOVER> | <language> | <service/library/app> | <internal deps> |

---

## Architecture Deep-Dive

### Pattern: <Detected Pattern>
<Comprehensive explanation of architecture with diagrams>

### Evidence
| Indicator | Weight | Method |
|-----------|--------|--------|
| <from state.analyze.architecture_evidence> | <weight> | <AST/grep/directory> |

### Layers
<Detailed description of each layer: purpose, responsibilities, dependencies>

| Layer | Path | Packages | Interfaces | Structs | External Deps |
|-------|------|----------|------------|---------|--------------|
| <from state.analyze.layers> | <path> | <count> | <count> | <count> | <list or "none"> |

### Dependency Flow
```
<ASCII diagram of dependency flow>
```

### Dependency Violations
| From Layer | To Layer | File | Import |
|-----------|---------|------|--------|
| <from state.analyze.violations> | | | |

*(Empty = clean architecture, no violations detected)*

### Architectural Decisions

| Decision | Rationale | Date | Confidence |
|----------|-----------|------|------------|
| <Decision from analysis or git history> | <Why> | <When> | HIGH/MEDIUM/LOW |

---

## Dependency Topology (NEW v3.0)

### Graph Summary
| Metric | Value |
|--------|-------|
| Total packages | <from state.map.dependency_graph.total_packages> |
| Max depth | <max_depth> |
| Circular dependencies | <count or "none"> |
| Isolated packages | <count> |

### Hub Packages (highest fan-in)
| Package | Fan-In | Fan-Out | Role |
|---------|--------|---------|------|
| <from state.map.dependency_graph.hub_packages> | <fan_in> | <fan_out> | <core/utility/infrastructure> |

### Depth Map
```
Level 0 (core):     <packages>
Level 1 (app):      <packages>
Level 2 (ports):    <packages>
Level 3 (adapters): <packages>
Level 4 (entry):    <packages>
```

### God Packages (high fan-out, potential split candidates)
| Package | Fan-Out | Recommendation |
|---------|---------|---------------|
| <from state.map.dependency_graph.god_packages> | <fan_out> | <split/refactor/expected for DI> |

### Circular Dependencies
<List of circular dependency chains, or "None detected">

### Isolated Packages (0 fan-in)
<List of packages with no dependents — potential dead code or standalone tools>

---

## Technology Stack

### Primary Language: <Language>
- Version: <from go.mod, package.json, etc>
- Standard: <language standard/edition>

### Frameworks

| Framework | Version | Category | Purpose | Detection |
|-----------|---------|----------|---------|-----------|
| <from state.detect.frameworks> | <version> | <http/orm/grpc> | <purpose> | <manifest/ast/grep> |

### Libraries

| Library | Category | Version | Usage |
|---------|----------|---------|-------|
| <key dependencies> | <database/http/logging/etc> | <version> | <where/how used> |

---

## Core Domain

### Entities

| Entity | Location | Type | Key Fields | Relations |
|--------|----------|------|------------|-----------|
| <from state.map.core_domain.entities> | <file path> | <aggregate_root/entity/value_object> | <critical fields> | <relationships> |

### Value Objects

| Value Object | Location | Purpose | Invariants |
|--------------|----------|---------|------------|
| <if DDD detected> | <file path> | <purpose> | <validation rules> |

### Aggregates

| Aggregate Root | Location | Bounded Context | Entities | Invariants |
|----------------|----------|-----------------|----------|------------|
| <if DDD detected> | <file path> | <context> | <contained entities> | <business rules> |

### Key Interfaces

| Interface | Location | Methods | Implementations |
|-----------|----------|---------|-----------------|
| <from state.map.core_domain.interfaces> | <path> | <methods> | <impl paths> |

---

## Database Schema (from PHASE 5)

**Note:** This section is populated when PostgreSQL MCP is available.

### Tables

| Table | Columns | Primary Key | Foreign Keys | Domain Entity |
|-------|---------|-------------|--------------|---------------|
| <from state.database.tables> | <count> | <pk column> | <fk list> | <mapped entity> |

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
// Mock strategy: <mockery/gomock/manual/none>

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
| <from state.map.entry_points> | cmd/<name>/main.go | <purpose> | <key deps> |

### HTTP/gRPC Services

| Service | Location | Framework | Routes/Methods |
|---------|----------|-----------|----------------|
| <from state.map.entry_points> | <path> | <framework> | <key endpoints> |

### Workers/Jobs

| Worker | Location | Trigger | Purpose |
|--------|----------|---------|---------|
| <from state.map.entry_points> | <path> | <cron/queue/event> | <purpose> |

---

## External Integrations

### Databases

| Database | Driver | Location | Usage Pattern |
|----------|--------|----------|---------------|
| <from state.map.external_integrations> | <driver> | <config location> | <how accessed> |

### Caches

| Cache | Driver | Location | TTL Strategy |
|-------|--------|----------|--------------|
| <from state.map.external_integrations> | <driver> | <config> | <ttl pattern> |

### Message Queues

| Queue | Driver | Location | Topics/Queues |
|-------|--------|----------|---------------|
| <from state.map.external_integrations> | <driver> | <config> | <topics used> |

### External APIs

| API | Client | Location | Auth Method |
|-----|--------|----------|-------------|
| <from state.map.external_integrations> | <http client> | <where called> | <auth type> |

---

## Pattern Catalog

### Design Patterns Used

| Pattern | Location | Purpose | Example |
|---------|----------|---------|---------|
| <from state.map.design_patterns> | <file path> | <purpose> | <code ref> |

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
- **Analysis Method:** <AST-based/grep-based/mixed>
- **AST Available:** <yes/no>
- **Confidence Score:** <overall HIGH/MEDIUM/LOW>
- **Low Confidence Areas:** <list areas needing manual review>
- **Recommended Reviews:** <list sections to verify>
- **Monorepo:** <yes/no>
- **Modules Analyzed:** <count>
