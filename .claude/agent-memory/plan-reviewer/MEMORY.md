# Plan Reviewer — Agent Memory

## Project Structure
- claude-kit: configuration framework, 140 files, mostly markdown + shell
- Layer rules: handler → service → repository → models (Go, active for internal/**/*.go)
- No runtime code in plans reviewed so far — documentation-only plans are common

## Review Patterns

### Common incomplete-fix pattern
When a plan fixes an inconsistency in file A, check if the SAME string appears in file B.
Especially watch: workflow.md (has AUTONOMY section that mirrors autonomy.md), SKILL.md files
(have Common Issues / Troubleshooting sections that can duplicate the same wording).
Reference: [review-pattern-cascade-check.md](review-pattern-cascade-check.md)

## Issues Found

See [issues-catalog.md](issues-catalog.md) for recurring issue types.
