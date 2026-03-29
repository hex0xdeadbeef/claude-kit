plan:
  title: "Fix code-reviewer turn drain & missing verdict"

  context:
    summary: |
      code-reviewer agent (worktree isolation, 45 maxTurns) frequently exhausts all turns on
      memory-file operations instead of reviewing code. Root cause: Write/Edit to
      .claude/agent-memory/ triggers PostToolUse hooks (yaml-lint, check-references,
      check-plan-drift) which produce actionable feedback. Agent tries to fix feedback →
      more hooks → loop. When turns exhaust, no verdict is returned, and output_validation
      relies on SendMessage which is unavailable as a deferred tool.

  scope:
    in:
      - "Add agent-memory path guard to 3 PostToolUse hook scripts"
      - "Harden RULE_5 in code-reviewer.md with turn-25 self-check and turn-33 hard abort"
      - "Fix output_validation fallback in workflow.md (replace SendMessage with re-launch)"
    out:
      - item: "Memory architecture changes"
        reason: "Agent keeps Write/Edit tools and memory save capability — per designer decision"
      - item: "plan-reviewer changes"
        reason: "Same hooks apply but plan-reviewer doesn't write memory files"
      - item: "Hook behavior for non-agent-memory .claude/ paths"
        reason: "yaml-lint/check-references/check-plan-drift must still fire for artifacts"

  architecture:
    chosen:
      approach: "Script-level path guards + RULE_5 hardening + orchestrator resilience"
      rationale: "Fixes root cause (hooks), makes agent self-correcting (turn budget), and adds system-level resilience (re-launch fallback). Three independent fixes that compound."

  parts:
    - part: 1
      name: "yaml-lint.sh — agent-memory guard"
      file: ".claude/agents/meta-agent/scripts/yaml-lint.sh"
      action: "UPDATE"
      description: "Add early exit for agent-memory paths before any validation runs"
      code: |
        #!/usr/bin/env bash
        # yaml-lint.sh — PostToolUse hook (Edit/Write)
        # Deterministic YAML validation after any edit to .claude/ artifacts.
        #
        # Hook contract:
        #   stdin: JSON {"tool_name":"Edit","tool_input":{"file_path":"..."},"tool_result":{"content":"..."}}
        #   stdout: validation messages (informational, PostToolUse cannot block)
        #   exit 0 always
        #
        # Checks:
        #   1. YAML frontmatter syntax (if present)
        #   2. Balanced braces/brackets in YAML-style content
        #   3. Indentation consistency
        #   4. No tab characters (YAML requires spaces)

        set -euo pipefail

        INPUT=$(cat)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

        # Skip agent-memory paths — avoid hook amplification loop during agent memory saves
        if [[ "$FILE_PATH" == *"agent-memory"* ]]; then
          exit 0
        fi

        # Only check .claude/ artifact files with .md extension
        if [[ ! "$FILE_PATH" =~ \.claude/ ]] || [[ ! "$FILE_PATH" =~ \.md$ ]]; then
          exit 0
        fi

        if [[ ! -f "$FILE_PATH" ]]; then
          exit 0
        fi

        ERRORS=()

        # Check 1: No tab characters
        if grep -Pn '\t' "$FILE_PATH" > /dev/null 2>&1; then
          TAB_LINES=$(grep -Pn '\t' "$FILE_PATH" | head -5 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
          ERRORS+=("YAML_LINT: Tab characters found at lines: ${TAB_LINES}. YAML requires spaces for indentation.")
        fi

        # Check 2: Unbalanced braces (common in YAML inline maps)
        OPEN_BRACES=$(grep -o '{' "$FILE_PATH" | wc -l)
        CLOSE_BRACES=$(grep -o '}' "$FILE_PATH" | wc -l)
        if (( OPEN_BRACES != CLOSE_BRACES )); then
          ERRORS+=("YAML_LINT: Unbalanced braces — { count: ${OPEN_BRACES}, } count: ${CLOSE_BRACES}")
        fi

        # Check 3: Unbalanced brackets
        OPEN_BRACKETS=$(grep -o '\[' "$FILE_PATH" | wc -l)
        CLOSE_BRACKETS=$(grep -o '\]' "$FILE_PATH" | wc -l)
        if (( OPEN_BRACKETS != CLOSE_BRACKETS )); then
          ERRORS+=("YAML_LINT: Unbalanced brackets — [ count: ${OPEN_BRACKETS}, ] count: ${CLOSE_BRACKETS}")
        fi

        # Check 4: Duplicate top-level keys (common copy-paste error)
        # Extract lines that look like top-level YAML keys (no leading whitespace, ends with :)
        DUPES=$(grep -n '^[a-zA-Z_][a-zA-Z0-9_]*:' "$FILE_PATH" | cut -d: -f2 | sort | uniq -d)
        if [[ -n "$DUPES" ]]; then
          ERRORS+=("YAML_LINT: Duplicate top-level keys: ${DUPES}")
        fi

        # Check 5: Trailing whitespace (cleanup)
        TRAILING=$(grep -Pcn ' +$' "$FILE_PATH" 2>/dev/null || true)
        if (( TRAILING > 5 )); then
          ERRORS+=("YAML_LINT: ${TRAILING} lines with trailing whitespace")
        fi

        # Output results
        if (( ${#ERRORS[@]} > 0 )); then
          echo "⚠️ YAML validation issues in ${FILE_PATH}:"
          for err in "${ERRORS[@]}"; do
            echo "  - ${err}"
          done
          echo "Fix these issues to maintain artifact quality."
        else
          echo "✅ YAML validation passed: ${FILE_PATH}"
        fi

    - part: 2
      name: "check-references.sh — agent-memory guard"
      file: ".claude/agents/meta-agent/scripts/check-references.sh"
      action: "UPDATE"
      description: "Add early exit for agent-memory paths before reference validation"
      code: |
        # INSERT after line 19 (after FILE_PATH extraction), BEFORE line 22 (existing .claude/ check):

        # Skip agent-memory paths — avoid hook amplification loop during agent memory saves
        if [[ "$FILE_PATH" == *"agent-memory"* ]]; then
          exit 0
        fi

    - part: 3
      name: "check-plan-drift.sh — agent-memory guard"
      file: ".claude/agents/meta-agent/scripts/check-plan-drift.sh"
      action: "UPDATE"
      description: "Add early exit for agent-memory paths before drift analysis"
      code: |
        # INSERT after line 29 (after FILE_PATH extraction), BEFORE line 32 (existing .claude/ guard):

        # Skip agent-memory paths — avoid hook amplification loop during agent memory saves
        if [[ "$FILE_PATH" == *"agent-memory"* ]]; then
          exit 0
        fi

    - part: 4
      name: "code-reviewer.md — RULE_5 turn budget hardening"
      file: ".claude/agents/code-reviewer.md"
      action: "UPDATE"
      description: "Replace single-line RULE_5 with multi-tier turn countdown"
      code: |
        ## Rules (CRITICAL)
        - RULE_1 No Fix: Do NOT fix code, only recommend
        - RULE_2 No Approve Blockers: NEVER approve with BLOCKER issues
        - RULE_3 Tests First: Do NOT start review without LINT && TEST passing (trusted from coder VERIFY if verify_status in handoff, otherwise re-run)
        - RULE_4 Check Architecture: ALWAYS verify the import matrix
        - RULE_5 Output First — Turn Budget (3-tier enforcement):
          - **TIER 1 (turn 25):** Self-check — "Have I started REVIEW phase?" If NO (still in memory/lint/setup) → IMMEDIATELY abandon current work, skip to GET CHANGES. Do NOT fix any lint or memory issues — they are not your job.
          - **TIER 2 (turn 33):** Hard abort — If REVIEW sections not yet complete, output `VERDICT: CHANGES_REQUESTED` with note "Review incomplete — turn budget exhausted on non-review work. Re-run recommended." Form minimal handoff.
          - **TIER 3 (turn 40):** Memory deadline — If verdict already output, save memory in remaining turns. If verdict NOT yet output, skip memory entirely and output verdict NOW.
          - **General:** Memory is OPTIONAL; verdict + handoff is MANDATORY. NEVER spend turns fixing lint feedback on your own memory files — these hooks are not meant for you.

    - part: 5
      name: "workflow.md — output_validation fallback"
      file: ".claude/commands/workflow.md"
      action: "UPDATE"
      description: "Replace SendMessage-dependent recovery with re-launch fallback"
      code: |
        # REPLACE lines 299-304 (on_incomplete_output section) with:

        on_incomplete_output:
          step_1: "Check if verdict can be extracted from SubagentStop hook output (review-completions.jsonl may contain verdict extracted by save-review-checkpoint.sh)"
          step_2: "If verdict found in review-completions.jsonl → use it, proceed with minimal handoff (verdict only, no detailed issues)"
          step_3: "If no verdict in hook output → re-launch code-reviewer agent with minimal prompt: 'The previous code review did not return a verdict. Run git diff to see changes. Output ONLY: VERDICT: {verdict} followed by brief handoff. Do NOT save memory. Do NOT fix lint issues.'"
          step_4: "If re-launch also fails → WARN user, show what information is available, ask for manual verdict decision"
          max_retries: 1
          note: "Step 1 leverages save-review-checkpoint.sh which already extracts verdict via regex. Step 3 is a fresh agent launch (not SendMessage) — simpler and always available."

  files_summary:
    - file: ".claude/agents/meta-agent/scripts/yaml-lint.sh"
      action: "UPDATE"
      description: "Add agent-memory path guard (3 lines after FILE_PATH extraction)"
    - file: ".claude/agents/meta-agent/scripts/check-references.sh"
      action: "UPDATE"
      description: "Add agent-memory path guard (3 lines after FILE_PATH extraction)"
    - file: ".claude/agents/meta-agent/scripts/check-plan-drift.sh"
      action: "UPDATE"
      description: "Add agent-memory path guard (3 lines after FILE_PATH extraction)"
    - file: ".claude/agents/code-reviewer.md"
      action: "UPDATE"
      description: "Replace RULE_5 single line with 3-tier turn budget enforcement"
    - file: ".claude/commands/workflow.md"
      action: "UPDATE"
      description: "Replace SendMessage-based output_validation fallback with hook-check + re-launch"

  acceptance_criteria:
    functional:
      - "Agent Write/Edit to .claude/agent-memory/**/*.md produces zero hook stdout"
      - "Agent Write/Edit to .claude/rules/**/*.md still triggers all 3 hooks normally"
      - "code-reviewer RULE_5 mentions turn 25, turn 33, turn 40 thresholds"
      - "workflow.md output_validation does not reference SendMessage"
      - "workflow.md output_validation step_1 checks review-completions.jsonl"
    technical:
      - "shellcheck passes on all 3 modified scripts"
      - "No existing hook behavior changed for non-agent-memory paths"

  notes: |
    Testing approach: pipe test JSON through each script to verify guard works:
      echo '{"tool_input":{"file_path":".claude/agent-memory/code-reviewer/test.md"}}' | bash yaml-lint.sh
      # Expected: silent exit 0 (no output)
      echo '{"tool_input":{"file_path":".claude/rules/test.md"}}' | bash yaml-lint.sh
      # Expected: normal lint output
