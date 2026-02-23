# Code Review: Examples & Search Patterns

**Purpose**: Bad/good code examples and automated grep patterns for code-review command.
**Load when**: PHASE 3: REVIEW — after architecture checks, before verdict.

---

# ════════════════════════════════════════════════════════════════════════════════
# EXAMPLES (bad/good/why)
# ════════════════════════════════════════════════════════════════════════════════
examples:
  log_and_return:
    bad: |
      if err != nil {
          log.Error("failed", "err", err)
          return err  // duplicate log in error chain
      }
    good: |
      if err != nil {
          return fmt.Errorf("context: %w", err)
      }
    why: "[blocker] log AND return creates duplicate logs in error chain"
    severity: blocker

  architecture_violation:
    bad: |
      // {api_layer}/handler.go
      import "{data_access_package}"  // API imports data layer directly
    good: |
      // {api_layer}/handler.go
      import "{service_package}"   // API imports service/usecase layer
    why: "[blocker] API layer must not import data access layer directly (SEE: PROJECT-KNOWLEDGE.md, if available)"
    severity: blocker

  security_token_leak:
    bad: |
      log.Info("user authenticated", "token", token)
    good: |
      log.Info("user authenticated", "user_id", userID)
    why: "[blocker] Never log tokens, passwords, or secrets"
    severity: blocker

---

# ════════════════════════════════════════════════════════════════════════════════
# SEARCH PATTERNS (automated checks)
# ════════════════════════════════════════════════════════════════════════════════
search_patterns:
  log_and_return:
    pattern: 'log\.(Error|Warn|Info).*\n.*return'
    severity: blocker
    use_case: "Detect log AND return anti-pattern"

  import_layer_violation:
    pattern: "Adapt to project's import matrix"
    path: "Handler/API layer files"
    severity: blocker
    use_case: "Handler layer must not import data access layer directly"

  token_in_log:
    pattern: 'log\..*(token|password|secret|credential)'
    severity: blocker
    use_case: "Sensitive data in logs"

  hardcoded_secret:
    pattern: '(password|token|secret)\s*[:=]\s*"[^"]+"'
    severity: blocker
    use_case: "Hardcoded credentials"

---

## Usage

1. During PHASE 3: REVIEW, load this file
2. Run each `search_patterns` grep against the diff
3. Cross-reference findings with `examples` for issue descriptions
4. Mark findings with appropriate severity

## SEE ALSO

- `security-checklist.md` — OWASP security checks
- `deps/coder/examples.md` — Implementation-side examples
