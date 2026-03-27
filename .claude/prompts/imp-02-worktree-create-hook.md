meta:
  type: "plan"
  task: "IMP-02: WorktreeCreate hook for code-reviewer worktree preparation"
  complexity: S-M
  user_override: XL
  sequential_thinking: not_required

plan:
  title: "WorktreeCreate Hook for Worktree Preparation"

  context:
    summary: |
      Add a WorktreeCreate hook (v2.1.50) that fires when code-reviewer's
      `isolation: worktree` creates a git worktree. The hook prepares the
      worktree environment: copies .env.example, downloads Go modules, and
      logs the creation event for analytics.

  scope:
    in:
      - "Create .claude/scripts/prepare-worktree.sh"
      - "Register WorktreeCreate hook in settings.json"
      - "Update workflow.md hooks documentation"
    out:
      - item: "WorktreeRemove hook (cleanup)"
        reason: "Separate task — worktrees are auto-cleaned by Claude Code"
      - item: "Modifying code-reviewer.md"
        reason: "The hook is transparent to the agent — it fires before the agent starts"

  dependencies:
    beads_issue: "N/A"
    blocks: []
    blocked_by: []

  architecture:
    decision: "Bash script with python3 for JSON stdin parsing, consistent with all existing hooks"
    alternatives:
      - option: "Pure bash without python3"
        rejected_because: "Hook stdin is JSON — python3 parsing is the established pattern (12 of 14 scripts use it)"
      - option: "Inline the logic in settings.json command field"
        rejected_because: "Too complex for inline; separate script follows kit conventions"
    chosen:
      approach: "Standalone .claude/scripts/prepare-worktree.sh + settings.json WorktreeCreate entry"
      rationale: "Follows established hook patterns. Non-blocking (exit 0 always). Language-aware via PROJECT-KNOWLEDGE.md or Makefile detection."

  parts:
    - part: 1
      name: "Create prepare-worktree.sh script"
      file: ".claude/scripts/prepare-worktree.sh"
      action: "CREATE"
      description: |
        Script structure (following kit conventions):
        1. Header: Hook type, purpose, non-blocking contract
        2. `set -euo pipefail`, drain stdin, check python3
        3. Parse stdin JSON: extract worktree path, name, branch, original repo dir
           (v2.1.69: hook events include worktree field with these properties)
        4. Change to worktree directory (cd to worktree path)
        5. Environment setup:
           a. Copy .env.example → .env (if .env.example exists and .env does not)
           b. Detect language and run dependency install:
              - Go: `go mod download` (if go.mod exists)
              - Node: (template comment only — npm ci if package-lock.json)
              - Python: (template comment only — pip install if requirements.txt)
        6. Log worktree creation event to workflow-state/worktree-events.jsonl
           (JSONL format: timestamp, worktree_name, worktree_path, branch, action: "create")
        7. exit 0 (ALWAYS — non-blocking)

        Guards:
        - Each step wrapped in try/except — no step can fail the hook
        - Timeout: subprocess.run(timeout=30) for go mod download (NOT bash `timeout` — macOS incompatible)
        - If worktree path not in stdin → log raw stdin to debug file, exit 0 (contract discovery)
        - mkdir -p STATE_DIR before writing JSONL (os.makedirs with exist_ok=True)

        Contract discovery:
        - WorktreeCreate stdin JSON structure is not fully documented in CHANGELOG.
          On parse failure or missing expected fields, dump raw stdin to
          worktree-events-debug.jsonl for offline contract verification.
          This ensures first-run produces useful diagnostics even if field names differ.

    - part: 2
      name: "Register WorktreeCreate hook in settings.json"
      file: ".claude/settings.json"
      action: "UPDATE"
      description: |
        Add WorktreeCreate entry in the hooks section:
        ```json
        "WorktreeCreate": [
          {
            "matcher": "",
            "hooks": [
              {
                "type": "command",
                "command": ".claude/scripts/prepare-worktree.sh"
              }
            ]
          }
        ]
        ```
        Insert after the SubagentStop entry (logical grouping: worktree lifecycle near agent lifecycle).

    - part: 3
      name: "Update workflow.md hooks documentation"
      file: ".claude/commands/workflow.md"
      action: "UPDATE"
      description: |
        Add to workflow_specific hooks section:
        ```yaml
        - event: WorktreeCreate
          script: ".claude/scripts/prepare-worktree.sh"
          behavior: "Prepares worktree environment (env vars, deps, analytics)"
          blocking: false
        ```

  files_summary:
    - file: ".claude/scripts/prepare-worktree.sh"
      action: "CREATE"
      description: "WorktreeCreate hook — worktree preparation and analytics (~80 lines)"
    - file: ".claude/settings.json"
      action: "UPDATE"
      description: "Register WorktreeCreate hook event"
    - file: ".claude/commands/workflow.md"
      action: "UPDATE"
      description: "Document new hook in workflow-specific hooks section"

  acceptance_criteria:
    functional:
      - "Script exits 0 in all cases (non-blocking)"
      - "Copies .env.example to .env when present and .env missing"
      - "Runs go mod download when go.mod present"
      - "Logs creation event to worktree-events.jsonl"
      - "Graceful degradation when stdin has no worktree path"
    technical:
      - "bash -n .claude/scripts/prepare-worktree.sh passes"
      - "Script follows kit conventions: set -euo pipefail, INPUT=$(cat), python3 check"
      - "settings.json remains valid JSON after edit"
    architecture:
      - "Hook registered as WorktreeCreate in settings.json"
      - "Non-blocking — never returns exit code 2"
      - "No hard dependencies beyond bash and git"

  config_changes: []

  notes: |
    - WorktreeCreate stdin JSON structure is NOT documented in CHANGELOG v2.1.50.
      The `worktree` field in v2.1.69 applies to status-line hooks, not WorktreeCreate.
      Script uses best-guess field names and logs raw stdin on parse failure for discovery.
    - go mod download uses Python subprocess.run(timeout=30) — NOT bash `timeout` (macOS ships
      `gtimeout`, not `timeout`). This matches kit conventions — no existing script uses bash timeout.
    - The script is language-aware but defaults to Go (matching kit's Language Profile).
      Non-Go projects can customize or override via settings.local.json.
