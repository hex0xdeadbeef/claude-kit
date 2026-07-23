#!/usr/bin/env bash
# Test (DE-1): /designer has a Phase 3.5 CRITIQUE sub-phase between PROPOSE (3) and
# WRITE SPEC (4), it loads critique-lenses.md just-in-time, references the disposition forcing
# function, and the SKILL.md + design-checklist.md are wired for it. Asserts AC1.1.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
DES=".claude/commands/designer.md"
SKILL=".claude/skills/design-rules/SKILL.md"
CHECK=".claude/skills/design-rules/design-checklist.md"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# S-1: designer.md has a phase 3.5 block
if grep -qE '^\s*-?\s*phase:\s*3\.5\s*$' "$DES"; then pass "S-1 designer.md has phase 3.5"; else fail "S-1 designer.md missing phase 3.5"; fi

# S-2: the 3.5 block is a CRITIQUE / RED-TEAM phase
if grep -qiE 'CRITIQUE|RED-TEAM' "$DES"; then pass "S-2 CRITIQUE/RED-TEAM phase named"; else fail "S-2 no CRITIQUE/RED-TEAM name"; fi

# S-3: 3.5 region loads critique-lenses.md (extract region between phase 3.5 and phase 4)
P35="$(awk '/phase:[[:space:]]*3\.5/{f=1} /phase:[[:space:]]*4[^.]/{if(f){exit}} f' "$DES")"
if printf '%s' "$P35" | grep -q "critique-lenses.md"; then pass "S-3 Phase 3.5 loads critique-lenses.md"; else fail "S-3 Phase 3.5 does not load critique-lenses.md"; fi

# S-4: 3.5 region references the disposition forcing function
if printf '%s' "$P35" | grep -qiE 'disposition|accepted-risk'; then pass "S-4 Phase 3.5 references dispositions"; else fail "S-4 Phase 3.5 no disposition wording"; fi

# S-5: pipeline.flow includes a CRITIQUE step
if grep -qiE 'EXPLORE.*CLARIFY.*PROPOSE.*CRITIQUE.*SPEC.*GATE' "$DES"; then pass "S-5 pipeline.flow updated with CRITIQUE"; else fail "S-5 pipeline.flow missing CRITIQUE"; fi

# S-6: SKILL.md has a phase-driven load trigger for critique-lenses.md
if grep -q "critique-lenses.md" "$SKILL"; then pass "S-6 SKILL.md references critique-lenses.md"; else fail "S-6 SKILL.md no critique-lenses.md trigger"; fi

# S-7: design-checklist.md has a Phase 3.5 CRITIQUE section
if grep -qiE 'Phase 3\.5|CRITIQUE' "$CHECK"; then pass "S-7 design-checklist has Phase 3.5 CRITIQUE"; else fail "S-7 design-checklist missing Phase 3.5"; fi

[ "$rc" -eq 0 ] && echo "ALL PASS: test-design-critique-subphase" || echo "SOME FAILED: test-design-critique-subphase"
exit "$rc"
