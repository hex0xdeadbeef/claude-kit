#!/usr/bin/env bash
# R4 (F-P5): the EXPECTED `claude plugin validate` warning ("CLAUDE.md at the plugin root is not
# loaded as project context") must be documented in plugin-context.md so future audits do not
# re-investigate it. Doc-existence guard — the claude CLI may be absent in CI, so this asserts the
# documentation note, NOT the validate exit code.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
DOC=".claude/docs/plugin-context.md"
if grep -q "EXPECTED warning" "$DOC" && grep -q "plugin validate" "$DOC"; then
  echo "PASS: plugin-context.md documents the accepted plugin-validate warning"
  exit 0
else
  echo "FAIL: plugin-context.md missing the accepted plugin-validate warning note"
  exit 1
fi
