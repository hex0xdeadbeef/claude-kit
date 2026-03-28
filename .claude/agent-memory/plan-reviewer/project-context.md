---
name: project-context
description: Layer structure and review priorities for claude-kit project
type: project
---

This project is a Claude Code configuration kit — not application code. Most plans touch `.claude/` markdown/JSON/shell files, not Go source.

**When a plan is config_change or documentation type:**
- Import matrix, domain purity, error handling checks are N/A
- Architecture review focuses on JSON/YAML correctness and hook contract compliance
- Security check: verify security hooks (protect-files.sh, block-dangerous-commands.sh) remain unconditional
- Layer checks: not applicable

**Plan template sections are still required even for config-only plans.**
The three most commonly missing sections in config/doc plans are:
1. Scope (IN/OUT) — frequently omitted
2. Files Summary — frequently omitted (files listed inline per Part instead)
3. Acceptance Criteria — Part verification checklists are NOT equivalent; need functional/technical/architecture structure

**Complexity label:** User may assign complexity labels (e.g., XL user-requested). If actual content is S/M, note the mismatch but do not block — treat as MINOR unless Sequential Thinking is genuinely needed for correctness.
