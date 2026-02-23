# Security Checklist (OWASP)

**Purpose**: Comprehensive security review checklist for code-review command.
**Load when**: Reviewing changes that touch API handlers, database queries, authentication, or sensitive data handling.

---

## Security Checks

```yaml
security_checklist:
  - check: SQL Injection
    what_to_look_for: "Only prepared statements/parameterized queries, NOT string concatenation"
    severity: blocker
    grep_pattern: "fmt.Sprintf.*SELECT|fmt.Sprintf.*INSERT|fmt.Sprintf.*UPDATE|fmt.Sprintf.*DELETE"
    pass_criteria: "All SQL via generated code or parameterized queries"

  - check: Input Validation
    what_to_look_for: "DTOs with validate tags, UUID validation"
    severity: blocker
    pass_criteria: "All user input validated at API boundary (handlers)"

  - check: Auth/AuthZ
    what_to_look_for: "Authentication middleware in use, tokens not logged"
    severity: blocker
    grep_pattern: "log.*token|log.*password|log.*secret"
    pass_criteria: "Auth validated, sensitive data not logged"

  - check: Sensitive Data
    what_to_look_for: "No passwords/tokens in logs, no hardcoded secrets"
    severity: blocker
    grep_pattern: "password.*=.*\"|token.*=.*\"|secret.*=.*\""
    pass_criteria: "No hardcoded credentials, no sensitive data in logs"

  - check: Error Info Leak
    what_to_look_for: "Internal errors not exposed in API responses"
    severity: major
    pass_criteria: "Internal errors mapped to generic messages, stack traces not exposed"
```

---

## Usage in Code Review

**When to use**: ALWAYS during PHASE 3: REVIEW, after architecture checks.

**How to use**:
1. Read this file: `Read .claude/commands/deps/code-review/security-checklist.md`
2. Run grep patterns for each check
3. Verify pass criteria for each item
4. Mark findings as [blocker] or [major] based on severity

**Example findings**:
```markdown
### Issues
#### [blocker] SQL Injection Risk
**File:** `internal/{layer}/{file}.go:42`
**Problem:** String concatenation in SQL query
**Solution:** Use parameterized queries instead of fmt.Sprintf
```

---

## OWASP Top 10 Mapping

| Check | OWASP Category |
|-------|----------------|
| SQL Injection | A03:2021 - Injection |
| Input Validation | A03:2021 - Injection |
| Auth/AuthZ | A01:2021 - Broken Access Control |
| Sensitive Data | A02:2021 - Cryptographic Failures |
| Error Info Leak | A04:2021 - Insecure Design |
