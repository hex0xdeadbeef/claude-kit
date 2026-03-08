# Context Isolation

**Rule:** Review phases (plan-review, code-review) MUST be launched as Task subagents.

**Severity:** CRITICAL

**Enforcement:** REQUIRED — review as subagent is NOT optional.
- Subagent gets a clean context window (~5–10K tokens) instead of inheriting parent context (~30–100K tokens)
- Net savings: 67% context reduction for review phases (source: JetBrains NeurIPS 2025)

**Exception:** ONLY if Task tool is unavailable or errors out — fallback to re-read artifact from file in same context. Log: "⚠️ FALLBACK: Task tool unavailable, running review in parent context."

**Narrative casting:** Pass reviewer WHAT was done (key decisions, risks, focus areas) without HOW (debug sessions, rejected approaches, intermediate thoughts). Source: `handoff_output` from previous phase.

**What reviewer receives:**
- plan-review: `.claude/prompts/{feature}.md` + narrative context block
- code-review: `git diff master...HEAD` + narrative context block
