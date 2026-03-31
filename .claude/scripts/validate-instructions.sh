#!/bin/bash
# Hook: InstructionsLoaded
# Purpose: Validate that critical rules and CLAUDE.md loaded into context
# Non-blocking: exit 0 always (informational warning only)
#
# Input JSON (from stdin):
#   - session_id: current session identifier
#   - files: array of loaded instruction file paths (CLAUDE.md + .claude/rules/*.md)
#
# Output: JSON with additionalContext containing warnings about missing rules
# If all required rules present → no output (silent success)

set -euo pipefail

INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

command -v python3 >/dev/null 2>&1 || exit 0

python3 << 'PYTHON_EOF'
import json, sys, os, re

# Required rules — core quality guarantees
REQUIRED_RULES = {
    "architecture.md": "Import matrix, domain purity — prevents layer violations",
    "workflow.md": "Pipeline commands, agents, design rationale — global coordination",
    "go-conventions.md": "Error wrapping, concurrency, config — Go code quality",
    "testing.md": "Table-driven tests, race detector, mocks — test quality",
}

# Optional but important rules (warn at lower severity)
OPTIONAL_RULES = {
    "handler-rules.md": "Handler layer validation, HTTP codes",
    "service-rules.md": "Service layer business logic, interfaces",
    "repository-rules.md": "Repository layer SQL, resource cleanup",
    "models-rules.md": "Domain models stdlib-only, no tags",
}

# Parse hook input
input_data = os.environ.get("_HOOK_INPUT", "{}")
try:
    hook_input = json.loads(input_data)
except Exception:
    print("validate-instructions: failed to parse hook input", file=sys.stderr)
    sys.exit(0)

# Extract loaded file paths
loaded_files = hook_input.get("files", [])
if not loaded_files:
    # Fallback: check if instructions field exists with different structure
    loaded_files = hook_input.get("instructions", [])

# Normalize to basenames for matching
loaded_basenames = set()
for f in loaded_files:
    if isinstance(f, str):
        loaded_basenames.add(os.path.basename(f))
    elif isinstance(f, dict):
        path = f.get("path", f.get("file", ""))
        loaded_basenames.add(os.path.basename(path))

# Check required rules
missing_required = {}
for rule, purpose in REQUIRED_RULES.items():
    if rule not in loaded_basenames:
        missing_required[rule] = purpose

# Check optional rules
missing_optional = {}
for rule, purpose in OPTIONAL_RULES.items():
    if rule not in loaded_basenames:
        missing_optional[rule] = purpose

# Check CLAUDE.md
claude_md_missing = "CLAUDE.md" not in loaded_basenames

# Build warning if anything missing
warnings = []
if claude_md_missing:
    warnings.append("CRITICAL: CLAUDE.md not loaded — language profile, error handling, and enforcement config missing")

if missing_required:
    warnings.append("REQUIRED rules not loaded:")
    for rule, purpose in missing_required.items():
        warnings.append(f"  - .claude/rules/{rule} — {purpose}")

if missing_optional:
    warnings.append("Optional rules not loaded (may be expected if editing non-Go files):")
    for rule, purpose in missing_optional.items():
        warnings.append(f"  - .claude/rules/{rule} — {purpose}")

# Hook protocol smoke test: WorktreeCreate stdout contract (v2.1.84+)
# Static analysis — validates prepare-worktree.sh contains JSON echo
try:
    wt_script = os.path.join(".claude", "scripts", "prepare-worktree.sh")
    if os.path.isfile(wt_script):
        with open(wt_script) as f:
            script_content = f.read()
        if not re.search(r'echo\s+[\'"]?\{', script_content):
            warnings.append(
                "HOOK PROTOCOL: prepare-worktree.sh missing JSON stdout — "
                "WorktreeCreate requires echo '{}' before exit 0 (Claude Code v2.1.84+)"
            )
except Exception:
    pass  # Non-critical

if warnings:
    text = "## Instructions Validation Warning\n" + "\n".join(warnings)
    text += "\n\nHint: check .claude/rules/ directory and CLAUDE.md file exist and are readable."
    print(json.dumps({"additionalContext": text}))
# else: silent success — no output needed
PYTHON_EOF
exit 0
