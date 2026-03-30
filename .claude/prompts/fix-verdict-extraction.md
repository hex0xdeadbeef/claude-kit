---
feature: fix-verdict-extraction
status: approved
complexity: S
task_type: bug_fix
created: 2026-03-30
---

# Fix verdict extraction in save-review-checkpoint.sh

## Context
`save-review-checkpoint.sh` reads `last_assistant_message` from SubagentStop payload to extract verdict.
This field does NOT exist in the payload. Result: verdict is always UNKNOWN (100% of entries in review-completions.jsonl).

The payload DOES contain `transcript_path` — a path to the agent's JSONL transcript file.
The verdict can be extracted by reading the last assistant message from the transcript.

## Part 1: Add transcript_path fallback to save-review-checkpoint.sh

**File:** `.claude/scripts/save-review-checkpoint.sh`

**Change:** After the existing `output = data.get("last_assistant_message", "")` line,
add a fallback that reads the transcript file when `last_assistant_message` is empty.

**Logic:**
1. If `output` is empty → get `transcript_path` from payload
2. If transcript file exists → read lines in reverse order
3. Find first entry with `role == "assistant"`
4. Extract `content` (handle both string and list formats)
5. Use extracted text for verdict regex

**Also:** Add debug logging for SubagentStop payload (received_keys, verdict_found, transcript_path_present)
to `worktree-events-debug.jsonl` for IMP-03 observability.

**Also:** Add `name` field to agent_type fallback chain (IMP-07) since WorktreeCreate uses `name`.

## Acceptance Criteria
- [ ] Verdict extracted from transcript when `last_assistant_message` absent
- [ ] SubagentStop payload logged to debug JSONL
- [ ] agent_type fallback includes `name` field
- [ ] No regression: existing `last_assistant_message` path still works if field ever appears
