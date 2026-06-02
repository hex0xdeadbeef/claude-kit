# Plan: Dangling / Wrong Reference Cleanup (Batch B — F3 + F5 + F7)

```yaml
feature: dangling-ref-cleanup
complexity: M
source: ".claude/workflow-audit-2026-06-02.md findings F3, F5, F7 (GATE-2 approved)"
type: reliability-fix (dead/incorrect reference removal)
```

## Scope

```yaml
in:
  - "F3: correct context7 MCP tool ids from plugin-namespaced mcp__plugin_context7_context7__* to the real project-scoped mcp__context7__* (registered in .mcp.json, confirmed in the live deferred-tool list). Sites: planner.md:371-372, coder-rules/mcp-tools.md:20,25."
  - "F5: replace the dangling test-runner Task dispatch (coder.md:516-522, subagent_type test-runner + model sonnet — neither exists) with the real mechanism already documented in coder-rules/mcp-tools.md Pattern A: Bash run_in_background with harness auto-notify. Use the resolved {TEST_CMD} cascade var, not a hardcoded command."
  - "F7: replace the unlaunchable arch-checker subagent dispatch (architecture-checks.md:107-131; plan-reviewer has Read/Grep/Glob only, NO Task/Agent tool) with inline Grep-based guidance the reviewer can actually execute; repoint troubleshooting.md:10."
out:
  - "audit doc references to these patterns (workflow-audit-2026-06-02.md) — they are the FINDING text, must stay."
  - ".claude/worktrees/* snapshot copies — gitignored ephemeral checkouts, not canonical source."
  - "No handoff JSON / VERDICT / VERDICT_JSON / discriminator / canonical issue-ID hash / caveman boundary / env var / security hook change."
```

## Architecture Decision

```yaml
decision_F3: "Real ids are mcp__context7__resolve-library-id / mcp__context7__query-docs (project-scoped server 'context7' in .mcp.json; no .claude-plugin/ manifest exists; confirmed verbatim in the live deferred-tool list). The plugin-namespaced form names a tool that does not exist in this install. Matches the sibling sequential-thinking convention (mcp__sequential-thinking__sequentialthinking)."
decision_F5: "coder.md already loads coder-rules/mcp-tools.md (line 173) whose Monitor-workflow Pattern A is the real test-running mechanism: Bash run_in_background + harness auto-notify, no subagent. Replace the test-runner Task block with Pattern A wording using {TEST_CMD} (resolved at verify_startup) so it stays language-agnostic. Drops the nonexistent subagent_type + the stale model:sonnet line."
decision_F7: "plan-reviewer.md frontmatter grants Read/Grep/Glob/TodoWrite/Write with disallowedTools:[Bash] and NO Task/Agent tool — it CANNOT dispatch arch-checker (which also does not exist). Replace the automated_checks subagent block with inline Grep-based procedure (the operative manual path already exists at plan-review-rules/SKILL.md:69/83). Rename the section header from 'Automated Checks' to 'Inline Architecture Checks' for accuracy (header referenced nowhere else). Repoint troubleshooting.md:10 fix to the inline procedure."
contract_safety: "All edits are prose/YAML-value text in command + skill files. No handoff/verdict/caveman/env/security surface. Note: state changes are to .claude/commands + .claude/skills (NOT .claude/scripts), so protect-files.sh is irrelevant to this batch."
```

## Tests

```yaml
tdd: "Test-first, content-anchored. One combined test (same logical class: no dead/wrong references on the pipeline). Fails red now, green after edits. Full suite 99 -> 100, all green."
test_file: ".claude/scripts/tests/test-dangling-ref-cleanup.sh"
assertions:
  F3: "no mcp__plugin_context7 token in planner.md or coder-rules/mcp-tools.md; mcp__context7__resolve-library-id AND mcp__context7__query-docs present in both."
  F5: "coder.md contains no 'subagent_type: \"test-runner\"' and no 'model: \"sonnet\"'; full_testing block references Bash run_in_background (Pattern A)."
  F7: "no 'arch-checker' token in plan-review-rules/ (architecture-checks.md + troubleshooting.md); architecture-checks.md contains no 'subagent_type: \"arch-checker\"'; inline grep guidance present."
```

## Acceptance Criteria

```yaml
- "AC-F3: grep -rn mcp__plugin_context7 in .claude/commands + .claude/skills returns nothing; planner.md + coder-rules/mcp-tools.md use mcp__context7__resolve-library-id / mcp__context7__query-docs."
- "AC-F5: coder.md full_testing uses Bash(run_in_background) Pattern A with {TEST_CMD}; no test-runner subagent_type, no model:sonnet in coder.md."
- "AC-F7: no arch-checker token anywhere in plan-review-rules/; architecture-checks.md complex-plan checks are inline grep guidance (no subagent dispatch); troubleshooting.md:10 repointed to the inline procedure."
- "AC-ALL: all .claude/scripts/tests/test-*.sh pass before and after (99 -> 100)."
```

## Parts

```yaml
Part 1:
  name: "F3 — context7 tool-id correction"
  test_first: ".claude/scripts/tests/test-dangling-ref-cleanup.sh F3 group (red)"
  edits:
    - "planner.md:371-372: mcp__plugin_context7_context7__resolve-library-id -> mcp__context7__resolve-library-id; __query-docs -> mcp__context7__query-docs"
    - "coder-rules/mcp-tools.md:20,25: same two id corrections (drop plugin_context7_context7_ prefix -> context7)"

Part 2:
  name: "F5 — replace test-runner dispatch with Pattern A"
  test_first: ".claude/scripts/tests/test-dangling-ref-cleanup.sh F5 group (red)"
  edits:
    - "coder.md:514-522 full_testing: replace tool 'Task (test-runner subagent)' + the subagent_type/model/run_in_background Task example with a Bash run_in_background example using {TEST_CMD} (Pattern A from coder-rules/mcp-tools.md), tee to /tmp/verify-output.log, read tail once on auto-notify. Drop subagent_type + model lines."

Part 3:
  name: "F7 — replace arch-checker dispatch with inline grep guidance"
  test_first: ".claude/scripts/tests/test-dangling-ref-cleanup.sh F7 group (red)"
  edits:
    - "architecture-checks.md:107-131: rename header 'Automated Checks (Complex Plans)' -> 'Inline Architecture Checks (Complex Plans)'; replace automated_checks.task_tool_usage (arch-checker subagent dispatch) with an inline_checks.procedure of grep-based steps (layer imports vs LAYER_RULE, DOMAIN_PROHIBIT, ERROR_WRAP, GENERATED/MOCK scan) + a note that plan-reviewer has no Task tool."
    - "troubleshooting.md:10: fix 'Use arch-checker agent for complex plans (4+ Parts)' -> 'Run inline grep import-vs-LAYER_RULE checks for complex plans (4+ Parts) — SEE architecture-checks.md § Inline Architecture Checks'"
  verify: "bash .claude/scripts/tests/test-dangling-ref-cleanup.sh (green); full suite green"
```
