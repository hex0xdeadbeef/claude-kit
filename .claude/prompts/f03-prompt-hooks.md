meta:
  task: "F-03: Add prompt-type hook for Go import matrix enforcement"
  complexity: M
  type: enhancement
  scope: "settings.json (hook config) + documentation updates"
  phase_1_only: true
  note: "Phase 1 = import matrix prompt hook. Phase 2 (future) = plan drift agent hook."

context:
  current_state: |
    All 17 hooks use type: "command" (shell scripts).
    Import matrix rules exist in .claude/rules/architecture.md but are enforced
    only at code-review time (code-reviewer agent).
    No real-time enforcement during Write/Edit.
  motivation: |
    Prompt hooks (v2.1.63) enable semantic validation via LLM — catch
    architecture violations BEFORE they land, not after.
  why_prompt_not_agent: |
    Import matrix rules are static and embeddable in prompt text.
    No file reading needed — $ARGUMENTS contains the file content.
    Prompt hooks are faster (~2-5s) and cheaper than agent hooks (~10-30s).
  why_not_plan_drift: |
    Plan drift detection requires reading the plan file (.claude/prompts/{feature}.md).
    Prompt hooks are single-turn with no tool access — can't read files.
    Plan drift needs agent hook (deferred to future iteration).

plan:
  parts:
    - id: 1
      title: "Add import matrix prompt hook to settings.json"
      files:
        - path: ".claude/settings.json"
          action: "edit"
          section: "hooks.PreToolUse"
      details: |
        Add new PreToolUse hook entry with:
        - matcher: "Write|Edit"
        - type: "prompt"
        - if: Write(internal/**/*.go) and Edit(internal/**/*.go)
        - prompt: import matrix rules + analysis instructions
        - timeout: 30

        Hook JSON structure (two entries — one per tool, matching existing pattern):
        ```json
        {
          "matcher": "Write|Edit",
          "hooks": [
            {
              "type": "prompt",
              "prompt": "PROMPT_TEXT_BELOW",
              "if": "Write(internal/**/*.go)",
              "timeout": 30
            },
            {
              "type": "prompt",
              "prompt": "PROMPT_TEXT_BELOW",
              "if": "Edit(internal/**/*.go)",
              "timeout": 30
            }
          ]
        }
        ```

        Exact prompt text (used in both entries):
        ```
        You are a Go architecture import matrix enforcer.

        RULES (strict, zero exceptions):
        1. handler layer (internal/handler/) → may import: service, controller, models. NEVER: repository
        2. service layer (internal/service/) → may import: repository, models. NEVER: handler
        3. repository layer (internal/repository/) → may import: models. NEVER: handler, service
        4. models layer (internal/models/) → stdlib only. NEVER: any internal/ package

        TASK: Analyze this tool call for import violations:

        $ARGUMENTS

        STEPS:
        1. Extract file_path from tool_input to determine the layer (handler/service/repository/models)
        2. If file is not in one of the 4 layers → respond {"permissionDecision": "allow"}
        3. If file is a test file (*_test.go) → respond {"permissionDecision": "allow"}
        4. Find import statements in tool_input.content (Write) or tool_input.new_string (Edit)
        5. If no import statements found → respond {"permissionDecision": "allow"}
        6. Check each internal/ import against the rules for that layer
        7. If violation found → respond {"permissionDecision": "deny", "reason": "Import violation: [layer] must not import [forbidden package]"}
        8. If no violations → respond {"permissionDecision": "allow"}

        Respond with ONLY the JSON object, nothing else.
        ```

    - id: 2
      title: "Update CLAUDE.md enforcement section"
      files:
        - path: "CLAUDE.md"
          action: "edit"
          section: "Enforcement"
      details: |
        Add mention of prompt hook type in the Enforcement section.
        Current text lists hooks by event type.
        Add note: "PreToolUse prompt hook for import matrix enforcement (internal/**/*.go)"

    - id: 3
      title: "Update workflow.md hooks documentation"
      files:
        - path: ".claude/commands/workflow.md"
          action: "edit"
          section: "hooks.also_active_during_workflow"
      details: |
        Add the new prompt hook to the also_active_during_workflow list.
        Format: "PreToolUse → import-matrix prompt hook [if: internal/**/*.go]"

acceptance_criteria:
  - "settings.json contains valid prompt hook entries for PreToolUse"
  - "Hook uses conditional if to target only internal/**/*.go files"
  - "Prompt text correctly encodes all 4 import matrix rules"
  - "CLAUDE.md and workflow.md reference the new hook"
  - "Existing hooks are not modified or broken"

testing:
  approach: |
    This hook targets internal/**/*.go files. The claude-kit repo has no internal/
    directory — the hook is a kit template that activates in adopting Go projects.
  validation_steps:
    - step: "JSON syntax validation"
      how: "jq validates settings.json after edit"
      automated: true
    - step: "Hook structure verification"
      how: "Verify new hook entries appear in jq '.hooks.PreToolUse' output"
      automated: true
    - step: "No regression on existing hooks"
      how: "Count PreToolUse hooks before and after — expect +1 entry"
      automated: true
    - step: "Prompt text completeness"
      how: "Verify prompt contains all 4 rules, $ARGUMENTS placeholder, and JSON output format"
      automated: false
  manual_test_procedure: |
    To live-test in a Go project that uses this kit:
    1. Write a file at internal/handler/bad.go with `import "myapp/internal/repository"`
    2. Expected: hook returns permissionDecision: deny
    3. Write a file at internal/handler/good.go with `import "myapp/internal/service"`
    4. Expected: hook returns permissionDecision: allow
    5. Edit internal/models/entity.go adding `import "myapp/internal/service"`
    6. Expected: hook returns permissionDecision: deny

risks:
  - risk: "Prompt hook may produce false positives on complex import patterns"
    severity: MEDIUM
    mitigation: "Conservative prompt — unknown layers default to allow"
  - risk: "Added latency on every Write/Edit of Go files in internal/"
    severity: LOW
    mitigation: "Conditional if limits to internal/**/*.go only; timeout 30s"
  - risk: "Token cost per hook invocation"
    severity: LOW
    mitigation: "Prompt type uses fast model by default; ~100 tokens per call"
