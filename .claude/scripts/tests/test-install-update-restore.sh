#!/usr/bin/env bash
# test-install-update-restore.sh — fixture-based tests for install.sh restore functions
# Usage: bash .claude/scripts/tests/test-install-update-restore.sh
# Covers: AC-1 .. AC-10 from update-restore-spec.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
INSTALL_SH="${REPO_ROOT}/install.sh"

# Source install.sh (sourcing guard skips main)
# shellcheck disable=SC1090
source "${INSTALL_SH}"

TMP_ROOT="$(mktemp -d -t install-restore-tests.XXXXXX)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

PASS=0
FAIL=0

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected=[$expected] actual=[$actual])"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local name="$1" path="$2"
    if [ -e "$path" ]; then
        echo "  PASS: $name ($path exists)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name ($path missing)"
        FAIL=$((FAIL + 1))
    fi
}

assert_grep() {
    local name="$1" pattern="$2" file="$3"
    # `--` separates options from pattern; required when pattern starts with `-`.
    if grep -Fq -- "$pattern" "$file" 2>/dev/null; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (pattern [$pattern] not in $file)"
        FAIL=$((FAIL + 1))
    fi
}

assert_grep_str() {
    local name="$1" pattern="$2" haystack="$3"
    if printf '%s\n' "$haystack" | grep -Fq -- "$pattern"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (pattern [$pattern] not in stderr capture)"
        FAIL=$((FAIL + 1))
    fi
}

# ── Fixture builder ────────────────────────────────────────────────────────────
build_fixture() {
    local fix="$1"
    rm -rf "$fix"
    # Target dir (post .claude/ install state)
    mkdir -p "$fix/target/.claude/prompts"
    mkdir -p "$fix/target/.claude/skills/code-review-rules"
    mkdir -p "$fix/target/.claude/commands"
    mkdir -p "$fix/target/.claude/agents"
    echo "fresh" > "$fix/target/.claude/prompts/fresh-template.md"
    cat > "$fix/target/.claude/agents/code-reviewer.md" <<'EOF'
---
name: code-reviewer
skills:
  - code-review-rules
---
body
EOF
    cat > "$fix/target/.claude/commands/workflow.md" <<'EOF'
---
name: workflow
---
body
EOF

    # src_dir mimics extracted new archive
    mkdir -p "$fix/src/.claude/skills/code-review-rules"
    mkdir -p "$fix/src/.claude/commands" "$fix/src/.claude/agents"
    # Same files as target (kit baseline)
    cp "$fix/target/.claude/agents/code-reviewer.md" "$fix/src/.claude/agents/"
    cp "$fix/target/.claude/commands/workflow.md" "$fix/src/.claude/commands/"

    # backup_dir mimics user's prior install with customizations
    mkdir -p "$fix/backup/prompts"
    mkdir -p "$fix/backup/skills/code-review-rules"
    mkdir -p "$fix/backup/skills/my-team-skill"
    mkdir -p "$fix/backup/commands" "$fix/backup/agents/my-team-agent"
    echo "user-plan" > "$fix/backup/prompts/in-flight-feature.md"
    echo "collide" > "$fix/backup/prompts/fresh-template.md"
    echo "team-skill" > "$fix/backup/skills/my-team-skill/SKILL.md"
    echo "user-cmd" > "$fix/backup/commands/my-cmd.md"
    echo "team-agent" > "$fix/backup/agents/my-team-agent/AGENT.md"
    cat > "$fix/backup/agents/code-reviewer.md" <<'EOF'
---
name: code-reviewer
skills:
  - code-review-rules
  - my-custom-skill
---
body
EOF
    cat > "$fix/backup/commands/workflow.md" <<'EOF'
---
name: workflow
skills:
  - my-workflow-skill
---
body
EOF
}

# ── T1: restore_prompts (AC-1) ─────────────────────────────────────────────────
echo "T1: restore_prompts"
FIX="${TMP_ROOT}/t1"; build_fixture "$FIX"
out=$(restore_prompts "$FIX/backup" "$FIX/target")
assert_eq "T1.counts" "restored=1 collisions=1" "$out"
assert_file_exists "T1.user-plan" "$FIX/target/.claude/prompts/in-flight-feature.md"
assert_file_exists "T1.collision-old" "$FIX/target/.claude/prompts/fresh-template-old.md"
# New archive file preserved unchanged
assert_eq "T1.new-preserved" "fresh" "$(cat "$FIX/target/.claude/prompts/fresh-template.md")"

# ── T2: restore_custom_skills (AC-2) ───────────────────────────────────────────
echo "T2: restore_custom_skills"
FIX="${TMP_ROOT}/t2"; build_fixture "$FIX"
out=$(restore_custom_skills "$FIX/backup" "$FIX/src" "$FIX/target")
assert_eq "T2.counts" "restored=1" "$out"
assert_file_exists "T2.custom-skill" "$FIX/target/.claude/skills/my-team-skill/SKILL.md"
# Base skill not touched
assert_eq "T2.base-untouched" "0" "$(find "$FIX/target/.claude/skills/code-review-rules" -newer "$FIX/backup/skills/code-review-rules" 2>/dev/null | wc -l | tr -d ' ')"

# ── T3: restore_custom_files (AC-3, AC-4) ──────────────────────────────────────
echo "T3: restore_custom_files"
FIX="${TMP_ROOT}/t3"; build_fixture "$FIX"
out=$(restore_custom_files "$FIX/backup" "$FIX/src" "$FIX/target")
assert_eq "T3.counts" "restored=2" "$out"
assert_file_exists "T3.custom-cmd" "$FIX/target/.claude/commands/my-cmd.md"
assert_file_exists "T3.custom-agent-dir" "$FIX/target/.claude/agents/my-team-agent/AGENT.md"

# ── T4: merge_frontmatter_skills — merge into existing skills (AC-5) ───────────
echo "T4: merge_frontmatter_skills (existing skills:)"
FIX="${TMP_ROOT}/t4"; build_fixture "$FIX"
out=$(merge_frontmatter_skills "$FIX/backup" "$FIX/src" "$FIX/target")
assert_grep_str "T4.merged-counter-positive" "merged=" "$out"
assert_grep "T4.skill-base-present" "- code-review-rules" "$FIX/target/.claude/agents/code-reviewer.md"
assert_grep "T4.skill-custom-added" "- my-custom-skill" "$FIX/target/.claude/agents/code-reviewer.md"

# ── T5: merge_frontmatter_skills — insert skills: where none existed (AC-6) ────
echo "T5: merge_frontmatter_skills (insert skills:)"
# Same fixture as T4: workflow.md target has no skills:, backup has [my-workflow-skill]
assert_grep "T5.skills-block-inserted" "skills:" "$FIX/target/.claude/commands/workflow.md"
assert_grep "T5.skill-inserted" "- my-workflow-skill" "$FIX/target/.claude/commands/workflow.md"

# ── T6: idempotency (AC-7) ─────────────────────────────────────────────────────
echo "T6: idempotency"
# Re-run merge on already-merged target
out=$(merge_frontmatter_skills "$FIX/backup" "$FIX/src" "$FIX/target")
# Count occurrences of 'my-custom-skill' in code-reviewer.md — must be exactly 1
n=$(grep -c "my-custom-skill" "$FIX/target/.claude/agents/code-reviewer.md")
assert_eq "T6.no-duplication" "1" "$n"

# ── T7: python3 absent (AC-8) ──────────────────────────────────────────────────
# Fixes:
#   - explicit `command -v python3` precondition probe in the same env -i shell
#     used for the test. If python3 is still reachable, report SKIP with reason;
#     otherwise run the real assertion.
#   - capture stderr separately and assert "python3 not found" substring (covers
#     AC-8's "warns" clause, not just counter).
echo "T7: python3 absent (graceful degradation)"
FIX="${TMP_ROOT}/t7"; build_fixture "$FIX"

if env -i PATH="/nonexistent" /bin/bash -c 'command -v python3 >/dev/null 2>&1'; then
    echo "  SKIP: T7 — python3 still reachable inside env -i (host has /nonexistent shim or builtin)"
else
    stdout_out=$(env -i PATH="/nonexistent" /bin/bash -c \
        "source '${INSTALL_SH}'; merge_frontmatter_skills '$FIX/backup' '$FIX/src' '$FIX/target'" \
        2>/dev/null)
    stderr_out=$(env -i PATH="/nonexistent" /bin/bash -c \
        "source '${INSTALL_SH}'; merge_frontmatter_skills '$FIX/backup' '$FIX/src' '$FIX/target'" \
        2>&1 >/dev/null)
    assert_eq "T7.fallback-counts" "merged=0 skills_added=0" "$stdout_out"
    assert_grep_str "T7.warn-emitted" "python3 not found" "$stderr_out"
fi

# ── T8: empty backup (AC-10) ───────────────────────────────────────────────────
echo "T8: empty backup"
FIX="${TMP_ROOT}/t8"
mkdir -p "$FIX/backup" "$FIX/src/.claude/skills" "$FIX/target/.claude/prompts"
out=$(restore_prompts "$FIX/backup" "$FIX/target")
assert_eq "T8.no-prompts" "restored=0 collisions=0" "$out"
out=$(restore_custom_skills "$FIX/backup" "$FIX/src" "$FIX/target")
assert_eq "T8.no-skills" "restored=0" "$out"
out=$(restore_custom_files "$FIX/backup" "$FIX/src" "$FIX/target")
assert_eq "T8.no-files" "restored=0" "$out"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
