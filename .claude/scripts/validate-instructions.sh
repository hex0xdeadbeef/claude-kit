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
    print("[validate-instructions] ERROR: failed to parse hook input", file=sys.stderr)
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

# CLAUDE.md static checks (P0-01, P1-03): version floor + cache policy
try:
    if os.path.isfile("CLAUDE.md"):
        with open("CLAUDE.md") as f:
            claude_md_text = f.read()
        # Version floor check (P0-01): CLAUDE.md must retain the >= 2.1.113 marker
        if "2.1.113" not in claude_md_text:
            warnings.append(
                "VERSION FLOOR: CLAUDE.md does not mention Claude Code >= 2.1.113 — "
                "exec-wrapper deny-rule matching (env/sudo/watch/ionice/setsid) requires this version. "
                "Re-add the minimum version note to the Soft Prerequisites section."
            )
        # Cache policy check (P1-03): cache policy documented (v2.1.108)
        if "Prompt Cache Policy" not in claude_md_text:
            warnings.append(
                "CACHE POLICY: CLAUDE.md does not contain the 'Prompt Cache Policy' section — "
                "v2.1.108 introduced ENABLE_PROMPT_CACHING_1H and FORCE_PROMPT_CACHING_5M "
                "which this section documents for XL workflows. "
                "Re-add the section after Soft Prerequisites."
            )
except Exception:
    pass  # Non-critical

# Hook stderr format check (P1-06): all echo >&2 lines must use [basename] LABEL: format
# Regression guard — fails if a new non-conforming line is added to any hook script.
try:
    import subprocess as _sp, re as _re
    if not os.path.isdir('.claude/scripts'):
        raise RuntimeError('scripts dir absent')
    _grep = _sp.run(
        ['grep', '-rn', '--include=*.sh', '--exclude-dir=tests', r'>&2[[:space:]]*$', '.claude/scripts/'],
        capture_output=True, text=True
    )
    _pattern = _re.compile(r'\[[a-zA-Z0-9_-]+\]\s+(INFO|WARN|ERROR|FATAL|SKIP|PASS|FAIL|BLOCKING):')
    _bad = []
    for _line in _grep.stdout.splitlines():
        # Format: path:linenum:content
        _parts = _line.split(':', 2)
        _content = _parts[2] if len(_parts) >= 3 else _line
        if not _pattern.search(_content):
            _file = _parts[0].split('/')[-1] if _parts else '?'
            _lnum = _parts[1] if len(_parts) > 1 else '?'
            _bad.append(f"{_file}:{_lnum}")
    if _bad:
        warnings.append(
            f"HOOK STDERR FORMAT: {len(_bad)} echo >&2 line(s) do not follow "
            "'[basename] LABEL: message' convention (v2.1.98 — first stderr line surfaced in transcript). "
            f"Non-conforming: {', '.join(_bad[:5])}"
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
