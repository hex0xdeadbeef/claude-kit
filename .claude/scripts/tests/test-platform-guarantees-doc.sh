#!/bin/bash
# Test: CLAUDE.md documents the platform guarantees the kit relies on (IMP-4).
#
# Several Claude Code platform fixes are load-bearing for the pipeline (worktree isolation,
# 1M-context completion behaviour, compaction, settings resilience). Documenting them as explicit
# dependencies prevents a future maintainer from lowering the version floor or rolling back a
# reliance blindly. Asserts the section exists and lists >=6 distinct platform versions.
#
# Part of changelog-2153-156-opus48-uplift (IMP-4).

set -uo pipefail
FAIL=0
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
err() { echo "FAIL: $1"; FAIL=1; }

grep -q '^## Platform Guarantees Relied Upon$' CLAUDE.md \
  || err "CLAUDE.md missing '## Platform Guarantees Relied Upon' section"

# Extract the section body (heading → next H2) and count distinct 2.1.x version tokens in it.
sec="$(awk '/^## Platform Guarantees Relied Upon$/{f=1;next} /^## /{f=0} f' CLAUDE.md)"
vcount="$(printf '%s\n' "$sec" | grep -oE '2\.1\.[0-9]+' | sort -u | wc -l | tr -d ' ')"
if [[ "${vcount:-0}" -lt 6 ]]; then
  err "Platform Guarantees section lists <6 distinct versions (found ${vcount:-0}; need >=6)"
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: Platform Guarantees section present with $vcount distinct versions"
fi
exit "$FAIL"
