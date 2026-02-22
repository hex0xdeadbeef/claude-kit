---
description: Code review checklist reference - architecture, security, quality, performance checks
model: sonnet
version: 1.2.0
updated: 2026-02-22
type: reference
changelog: |
  v1.2.0 — Convert to YAML-first format, add workflow, fix PROJECT-KNOWLEDGE.md ref
  v1.1.0 — Initial checklist
---

role:
  identity: "Code Review Checklist Reference"
  purpose: "Quick-access checklist for code review categories"
  output: "Display formatted checklist to user"

workflow:
  summary: "DISPLAY checklist sections relevant to user query"
  usage: "Invoke /review-checklist to display full checklist, or reference from /code-review"

architecture_checks:
  note: "Architecture checks are project-specific. SEE: PROJECT-KNOWLEDGE.md (if available) for dependency matrix, domain structure, layer separation."
  checks:
    - "Circular imports between packages"
    - "Database layer leaking into API handlers"
    - "Proper separation of concerns within each domain"

code_quality:
  checks:
    - "Functions <= 30 lines"
    - "Errors wrapped with %w"
    - "No log AND return"

security_owasp:
  reference: "Project-specific security skill for detailed grep patterns and OWASP examples (if configured)"
  checks:
    - id: sql_injection
      check: "Prepared statements / parameterized queries only"
    - id: input_validation
      check: "DTO validate tags, UUID validation"
    - id: auth_authz
      check: "Authentication validated, tokens not logged"
    - id: sensitive_data
      check: "No passwords/tokens in logs, no hardcoded secrets"
    - id: error_info_leak
      check: "Internal errors not exposed to clients"

performance:
  note: "For critical paths"
  checks:
    - "No N+1 queries"
    - "Batch operations where possible"
    - "No unbounded loops/allocations"

design_patterns:
  checks:
    - "Patterns solve real problems (KISS check)"
    - "No over-engineering"
    - "Patterns match architecture layers"

concurrency:
  when: "Code uses goroutines"
  checks:
    - "No goroutine leaks"
    - "No race conditions (go test -race)"
    - "Context passed correctly"
    - "Graceful shutdown works"

test_coverage:
  checks:
    - "New code covered by tests"
    - "Coverage not decreased (minimum 70%)"

library_usage:
  when: "New dependencies added"
  tool: "Context7"
  checks:
    - "Correct API usage per library docs"
    - "Follows best practices from documentation"
    - "Patterns are current (not deprecated)"

severity_classification:
  levels:
    - level: "[blocker]"
      meaning: "Architecture / security"
      blocks: true
    - level: "[major]"
      meaning: "Error handling, logging"
      blocks: true
    - level: "[minor]"
      meaning: "Code style, naming"
      blocks: false
    - level: "[nit]"
      meaning: "Stylistic"
      blocks: false

verdict_template: |
  ## Code Review: {branch}
  ### Verdict: APPROVED / CHANGES REQUESTED
  ### Checklist
  | Category | Status |
  |----------|--------|
  | Architecture | PASS/FAIL |
  | Error Handling | PASS/FAIL |
  ### Issues
  #### [blocker] Issue
  **File:** `path/file.go:42`
  **Problem:** ...
  **Solution:** ...
  ### What's Good
  - ...
