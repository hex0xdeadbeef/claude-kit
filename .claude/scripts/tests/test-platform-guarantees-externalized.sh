#!/bin/bash
# Unit-3 (audit #5): the Platform Guarantees table is externalized OUT of always-loaded CLAUDE.md
# into .claude/docs/platform-guarantees.md, with the >= 2.1.141 floor kept inline. Contract-neutral:
# the table is descriptive version-rationale, not parsed at runtime, not in any handoff/VERDICT/
# canonical-ID surface.
set -uo pipefail
FAIL=0
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
err() { echo "FAIL: $1"; FAIL=1; }
DOC=".claude/docs/platform-guarantees.md"

# EX-1: CLAUDE.md no longer carries the full table — its Platform-Guarantees section body
# lists < 6 distinct 2.1.x versions (now just heading + pointer, not the 9-row table).
sec="$(awk '/^## Platform Guarantees Relied Upon$/{f=1;next} /^## /{f=0} f' CLAUDE.md)"
cmverc="$(printf '%s\n' "$sec" | grep -oE '2\.1\.[0-9]+' | sort -u | wc -l | tr -d ' ')"
if [[ "${cmverc:-0}" -ge 6 ]]; then
  err "EX-1 CLAUDE.md still carries the full table (${cmverc} distinct versions in its section; expected <6)"
fi

# EX-2: the >= 2.1.141 version floor stays stated inline in CLAUDE.md (not lost with the table).
grep -q '>= 2\.1\.141' CLAUDE.md || err "EX-2 CLAUDE.md no longer states the >= 2.1.141 version floor inline"

# EX-3 (structural invariant, not byte-diff against a vanished source): the doc carries
# >=9 guarantee data rows AND the full distinct version set the kit depends on.
rows="$(grep -cE '^\|.*\| 2\.1\.[0-9]+' "$DOC" 2>/dev/null || true)"
if [[ "${rows:-0}" -lt 9 ]]; then
  err "EX-3 doc has <9 guarantee rows (found ${rows:-0})"
fi
for v in 2.1.122 2.1.129 2.1.132 2.1.139 2.1.143 2.1.145 2.1.150 2.1.154; do
  grep -q "$v" "$DOC" 2>/dev/null || err "EX-3 doc missing required version ${v}"
done

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: Platform Guarantees externalized (CLAUDE.md section ${cmverc} versions; doc ${rows} rows); floor inline"
fi
exit "$FAIL"
