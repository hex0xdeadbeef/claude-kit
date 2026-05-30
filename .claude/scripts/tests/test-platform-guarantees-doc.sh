#!/bin/bash
# Test: the platform guarantees the kit relies on are documented (IMP-4).
# Externalized (audit #5) from CLAUDE.md to .claude/docs/platform-guarantees.md so the 9-row
# table stops loading into every session; CLAUDE.md keeps the heading + an on-demand pointer.
# This canonical consumer test now asserts the guarantee table lives in the DOC and that CLAUDE.md
# points to it — the guarantee stays genuinely enforced after the move.
set -uo pipefail
FAIL=0
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
err() { echo "FAIL: $1"; FAIL=1; }
DOC=".claude/docs/platform-guarantees.md"

# TG-1: externalized doc exists and carries the (caveman-verbatim) heading
[ -f "$DOC" ] || err "missing $DOC (platform guarantees externalized doc)"
grep -q '^## Platform Guarantees Relied Upon$' "$DOC" \
  || err "$DOC missing '## Platform Guarantees Relied Upon' heading"

# TG-2: the doc body lists >=6 distinct platform versions (table moved intact)
vcount="$(grep -oE '2\.1\.[0-9]+' "$DOC" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
if [[ "${vcount:-0}" -lt 6 ]]; then
  err "doc lists <6 distinct versions (found ${vcount:-0}; need >=6)"
fi

# TG-3: CLAUDE.md points to the externalized doc (discoverability preserved)
grep -q 'docs/platform-guarantees.md' CLAUDE.md \
  || err "CLAUDE.md missing pointer to $DOC"

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: platform guarantees documented in $DOC with $vcount versions; CLAUDE.md points to it"
fi
exit "$FAIL"
