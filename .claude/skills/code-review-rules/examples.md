# Code Review: Examples & Search Patterns

**Purpose**: Bad/good code examples and automated grep patterns for code-review command.
**Load when**: PHASE 3: REVIEW — after architecture checks, before verdict.

# ════════════════════════════════════════════════════════════════════════════════
# Code Completeness Examples
# ════════════════════════════════════════════════════════════════════════════════
#
# Principle: Full function body, error context propagated per {ERROR_WRAP},
# explicit return types and values, no truncation.
#
# reference_shapes — single canonical source:
#   resolved_from: "PROJECT-KNOWLEDGE.md → LANGUAGE"
#   location: "../planner-rules/code-shapes/<LANGUAGE>.md"
#   fallback: "../planner-rules/code-shapes/_default.md"
#   invariants: "../planner-rules/code-shapes/INVARIANTS.md"

---

# ════════════════════════════════════════════════════════════════════════════════
# Kit Dogfood Reference (Go-only — for kit maintainers)
# Non-Go projects MUST refer to ../planner-rules/code-shapes/<LANGUAGE>.md instead.
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
          return fmt.Errorf("context: %w", err)  // {ERROR_WRAP} kit Go default
      }
    why: "[blocker] log AND return creates duplicate logs in error chain. Use {ERROR_WRAP} per PROJECT-KNOWLEDGE.md. SKIP if slot unset."
    severity: blocker

  architecture_violation:
    bad: |
      // {api_layer}/handler.go
      import "{data_access_package}"  // API imports data layer directly
    good: |
      // {api_layer}/handler.go
      import "{service_package}"   // API imports service/usecase layer
    why: "[blocker] Per {LAYER_RULE} — when {ARCHITECTURE_STYLE} == 'layered'. SKIP-with-NIT if slot unset or non-layered architecture (canonical SKIP)."
    severity: "BLOCKER (when LAYER_RULE set + ARCHITECTURE_STYLE=layered) | NIT (when slot unset/non-layered, consolidated)"

  security_token_leak:
    bad: |
      log.Info("user authenticated", "token", token)
    good: |
      log.Info("user authenticated", "user_id", userID)
    why: "[blocker] Never log tokens, passwords, or secrets — language-agnostic security rule"
    severity: blocker

---

# ════════════════════════════════════════════════════════════════════════════════
# SEARCH PATTERNS (automated checks — language-neutral grep regex)
# ════════════════════════════════════════════════════════════════════════════════
search_patterns:
  log_and_return:
    pattern: 'log\.(Error|Warn|Info).*\n.*return'
    severity: blocker
    use_case: "Detect log AND return anti-pattern (kit Go-style logger; adapt regex per project logger)"

  import_layer_violation:
    pattern: "Adapt to project's {LAYER_RULE}"
    path: "{LAYERS} list — handler/API layer files when ARCHITECTURE_STYLE = layered"
    severity: blocker
    use_case: "Cross-layer import (e.g. handler → repository direct). SKIP if slot unset/non-layered."

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
4. Mark findings with appropriate severity (BLOCKER/MAJOR/MINOR/NIT)

## Canonical emission shape (P4)

Code-reviewer output order is fixed (see code-reviewer.md § Output Format):

1. `VERDICT: <enum>` (first line — regex fallback anchor).
2. `VERDICT_JSON:` followed by fenced ` ```json` block (second — structured-source primary).
3. `## REVIEW` narrative + per-issue commentary (last — fungible under 32 K subagent token cap).

This ordering survives subagent truncation: if the agent runs out of output budget mid-narrative, both the regex and structured extractors still find the verdict above. Verified by `test-verdict-ordering-first.sh`.

## SEE ALSO

- `security-checklist.md` — OWASP security checks
- [examples.md] in coder-rules skill — Implementation-side examples
- `../planner-rules/code-shapes/<LANGUAGE>.md` — per-language canonical shapes
