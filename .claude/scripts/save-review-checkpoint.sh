#!/bin/bash
# Hook: SubagentStop (matcher: plan-reviewer|code-reviewer)
# Purpose: Write marker about review agent completion + sync agent memory from worktree
# Blocking: exit 2 only if BOTH primary and fallback writes fail
# IMP-06: defensive fallback to /tmp when primary write fails — logging should not block agent
# IMP-H: verdict protection — blocks agent stop once if no verdict found (review agents only)
#
# Worktree path resolution (IMP-04 → IMP-11):
#   Delegated to resolve-worktree-path.py (shared utility).
#   Fallback chain: payload fields → .git/worktrees/ scan → git worktree list --porcelain
#
# Agent memory sync (IMP-01 + IMP-05):
#   After resolving worktree_path, delegates to sync-agent-memory.sh (standalone utility).
#   Runs BEFORE worktree cleanup (blocking hook).
#   Memory sync failure is NON_CRITICAL — logged but does not block.
#
# Verdict extraction (IMP-01, 2026-03-30):
#   SubagentStop payload MAY contain last_assistant_message (added in v2.1.47).
#   Transcript fallback: agent_transcript_path (agent-specific) checked first,
#   transcript_path (parent session) as fallback.
#   Strategy: try payload first → agent_transcript_path JSONL → transcript_path JSONL → regex for VERDICT:.
#   P0-1 (2026-04-10): agent_transcript_path is the agent's own conversation; transcript_path is the
#   parent session where agent output is a tool_result — role:assistant search finds orchestrator
#   messages, not the reviewer's VERDICT output.
#
# Agent-ID Registry (IMP-01, 2026-04-10):
#   When payload omits agent_type (e.g. code-reviewer with isolation:worktree),
#   recover it via agent-id-registry.jsonl written by track-task-lifecycle.sh at SubagentStart.
#   effective_agent_type is used for IMP-H, worktree resolution, memory sync, and marker.
#
# P0-2 worktree heuristic (2026-04-10):
#   SubagentStart does NOT fire for isolation:worktree agents (platform behavior),
#   so the registry is empty for code-reviewer. Fallback: infer code-reviewer from
#   agent_transcript_path presence in SubagentStop payload (only worktree agents have it).

set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 required for save-review-checkpoint.sh" >&2
  exit 2
}

STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}"
mkdir -p "$STATE_DIR"

# Read stdin JSON, parse once, write JSONL marker
INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF'
import json, sys, re, os
from datetime import datetime, timezone

STATE_DIR = os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state")
DEBUG_FILE = os.path.join(STATE_DIR, "worktree-events-debug.jsonl")

try:
    data = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
except Exception:
    data = {}

# IMP-07: agent_type fallback includes "name" (WorktreeCreate uses "name" field)
agent_type = (
    data.get("agent_type")
    or data.get("agent_name")
    or data.get("name")
    or "unknown"
)

agent_id = data.get("agent_id", "")
session_id = data.get("session_id", "")
timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# --- IMP-01: Agent-ID Registry lookup ---
# When payload omits agent_type, recover via registry written at SubagentStart.
def lookup_agent_registry(aid):
    if not aid:
        return None
    rf = os.path.join(STATE_DIR, "agent-id-registry.jsonl")
    if not os.path.isfile(rf):
        return None
    try:
        with open(rf) as f:
            for line in reversed(f.readlines()):
                try:
                    e = json.loads(line.strip())
                    if e.get("agent_id") == aid:
                        return e.get("agent_type")
                except json.JSONDecodeError:
                    continue
    except Exception:
        pass
    return None

effective_agent_type = agent_type
if not effective_agent_type or effective_agent_type == "unknown":
    recovered = lookup_agent_registry(agent_id)
    if recovered:
        effective_agent_type = recovered
    elif data.get("agent_transcript_path"):
        # P0-2: Worktree-based heuristic — SubagentStart does NOT fire for isolation:worktree
        # agents (platform behavior), so the registry is never populated for code-reviewer.
        # agent_transcript_path is only present for worktree agents (confirmed in all SubagentStop
        # payloads). In this pipeline, code-reviewer is the ONLY review agent with worktree
        # isolation — plan-reviewer has no worktree and its agent_type is populated correctly.
        effective_agent_type = "code-reviewer"
# --- End IMP-01 registry ---

# Review agents set — used by P1-2 backfill, P2-2 anomaly detection, IMP-H verdict protection
REVIEW_AGENTS = {"plan-reviewer", "code-reviewer", "verdict-recovery"}


# --- P1-2: Backfill registry at SubagentStop if type was recovered via heuristic ---
# Provides audit trail and self-healing: future stops for the same agent_id skip re-inference.
# Also ensures IMP-02 session filter finds a valid entry for iteration-2 context injection.
if effective_agent_type in REVIEW_AGENTS and agent_id and effective_agent_type != agent_type:
    try:
        REGISTRY_FILE = os.path.join(STATE_DIR, "agent-id-registry.jsonl")
        with open(REGISTRY_FILE, "a") as f:
            f.write(json.dumps({
                "agent_id": agent_id,
                "agent_type": effective_agent_type,
                "session_id": session_id,
                "registered_at": timestamp,
                "registration_source": "SubagentStop-backfill",
            }) + "\n")
    except Exception:
        pass  # NON_CRITICAL
# --- End P1-2 ---

# --- P2-2: Anomaly detection — log when SubagentStart didn't fire ---
# Only log anomaly when type was recovered via P0-2 heuristic (agent_transcript_path),
# NOT when recovered via IMP-01 registry (which means SubagentStart DID fire correctly).
# CR-003: registry-recovered types (effective_agent_type != agent_type but found in registry)
# are legitimate, not anomalies — avoid misleading "heuristic" message for them.
_recovered_via_heuristic = (
    effective_agent_type in REVIEW_AGENTS
    and agent_id
    and effective_agent_type != agent_type
    and lookup_agent_registry(agent_id) is None  # not in registry → was P0-2 heuristic
)
if _recovered_via_heuristic:
    try:
        anomaly = {
            "timestamp": timestamp,
            "type": "MISSING_SUBAGENT_START",
            "agent_id": agent_id,
            "effective_agent_type": effective_agent_type,
            "raw_agent_type": agent_type,
            "session_id": session_id,
            "message": "SubagentStart hook did not fire — type recovered via P0-2 heuristic (worktree isolation)",
        }
        with open(os.path.join(STATE_DIR, "anomalies.jsonl"), "a") as f:
            f.write(json.dumps(anomaly) + "\n")
    except Exception:
        pass
# --- End P2-2 ---


# --- IMP-01: Extract verdict from agent's final response ---
# Strategy 1: Try last_assistant_message from payload (may not exist in current Claude Code versions)
output = data.get("last_assistant_message", "")

# Strategy 2: Read agent_transcript_path (agent-specific) first, transcript_path (parent) as fallback.
# P0-1: agent_transcript_path contains the agent's own role:assistant messages with the VERDICT output.
# transcript_path (parent session) embeds agent output as tool_result, not as role:assistant —
# so reverse-searching role:assistant in parent finds orchestrator messages, missing the verdict.
# Note: last_assistant_message IS present in SubagentStop payload but may be empty if the
# agent's final turn was a tool call (e.g. memory save) rather than text output.
transcript_used = False
transcript_source = None
if not output:
    for _path_key in ("agent_transcript_path", "transcript_path"):
        _tp = data.get(_path_key, "")
        if not _tp or not os.path.isfile(_tp):
            continue
        try:
            with open(_tp) as f:
                lines = f.readlines()
            # Search in reverse for last assistant message
            for line in reversed(lines):
                try:
                    entry = json.loads(line.strip())
                    role = entry.get("role", "")
                    if role == "assistant":
                        content = entry.get("content", "")
                        if isinstance(content, list):
                            # Anthropic message format: [{type: "text", text: "..."}]
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "text":
                                    text = block.get("text", "")
                                    if text:
                                        output = text
                                        break
                        elif isinstance(content, str):
                            output = content
                        if output:
                            transcript_used = True
                            transcript_source = _path_key
                            break
                except (json.JSONDecodeError, KeyError):
                    continue
        except Exception as e:
            print(f"save-review-checkpoint: transcript read failed ({_path_key}): {e}", file=sys.stderr)
        if output:
            break

# --- IMP-02: Structured verdict JSON extraction (primary path) ---
import re as _re_imp02
import subprocess as _subprocess_imp02
import tempfile as _tempfile_imp02

verdict_source = "none"       # HOW the verdict was extracted (new field)
verdict_payload = None        # the parsed JSON object (if any)
verdict_mismatch_record = None

def _extract_verdict_json(text):
    """Return (parsed_dict_or_None, raw_json_str_or_None) from VERDICT_JSON:\\n```json\\n{...}\\n```.

    CR-001: use LAST match, not first. Agents may echo the instructional template
    from their prompt (agents/plan-reviewer.md and code-reviewer.md include a
    literal VERDICT_JSON example). The reviewer's actual verdict is emitted at
    the END of the response, so the last match wins; the first would pick up the
    echo and short-circuit to the template's stub values.
    """
    if not text:
        return None, None
    # Sentinel-anchored at start of line. Group 1 = JSON body between fences.
    matches = list(_re_imp02.finditer(
        r'^VERDICT_JSON:\s*\n```json\s*\n(.*?)\n```',
        str(text),
        _re_imp02.MULTILINE | _re_imp02.DOTALL,
    ))
    if not matches:
        return None, None
    raw = matches[-1].group(1)
    try:
        return json.loads(raw), raw
    except Exception:
        return None, raw  # raw for malformed-snippet logging

verdict = "UNKNOWN"
if output:
    parsed, raw_json = _extract_verdict_json(output)
    if parsed is not None and isinstance(parsed, dict) and "verdict" in parsed:
        # Write to temp file, invoke validate-handoff.sh in direct mode with timeout.
        schema_ok = False
        _tf_path = None
        try:
            with _tempfile_imp02.NamedTemporaryFile(
                mode="w", suffix="-verdict.json", delete=False
            ) as _tf:
                _tf.write(raw_json)
                _tf_path = _tf.name
            validator_rc = 1
            try:
                _result = _subprocess_imp02.run(
                    ["bash", ".claude/scripts/validate-handoff.sh", _tf_path],
                    capture_output=True, text=True, timeout=5,
                )
                validator_rc = _result.returncode
            except Exception as _e:
                # subprocess failure (timeout, missing bash, etc.) — treat as schema-invalid.
                print(f"save-review-checkpoint: validator invocation failed: {_e}", file=sys.stderr)
                validator_rc = 1
            schema_ok = (validator_rc == 0)
        finally:
            if _tf_path:
                try:
                    os.remove(_tf_path)
                except Exception:
                    pass

        if schema_ok:
            verdict = str(parsed["verdict"]).upper()
            verdict_source = "structured_json"
            verdict_payload = parsed
            # Dual-VERDICT mismatch detection — non-blocking observability signal.
            _human_m = _re_imp02.search(
                r'(?i)verdict:\s*(APPROVED_WITH_COMMENTS|APPROVED|CHANGES_REQUESTED|NEEDS_CHANGES|REJECTED)',
                str(output),
            )
            if _human_m:
                _human_v = _human_m.group(1).upper()
                if _human_v != verdict:
                    verdict_mismatch_record = {
                        "timestamp": timestamp,
                        "record_kind": "verdict_mismatch",
                        "agent": effective_agent_type,
                        "agent_id": agent_id,
                        "session_id": session_id,
                        "human_verdict": _human_v,
                        "json_verdict": verdict,
                        "preferred": "json",
                    }
        else:
            # JSON parsed but schema validation failed.
            verdict_source = "structured_json_schema_invalid"
            # Preserve malformed snippet (first 400 chars) for post-mortem.
            try:
                with open(
                    os.path.join(STATE_DIR, "handoff-validation.jsonl"),
                    "a",
                ) as _lf:
                    _lf.write(json.dumps({
                        "timestamp": timestamp,
                        "record_kind": "verdict_schema_invalid",
                        "agent": effective_agent_type,
                        "session_id": session_id,
                        "snippet": (raw_json or "")[:400],
                    }) + "\n")
            except Exception:
                pass
    elif parsed is None and raw_json is not None:
        # Sentinel + fence matched but json.loads failed. Distinct failure mode from
        # "no sentinel" — log the malformed snippet so operators can diff the payload.
        # verdict_source stays "none"; regex fallback rescues below.
        try:
            with open(
                os.path.join(STATE_DIR, "handoff-validation.jsonl"),
                "a",
            ) as _lf:
                _lf.write(json.dumps({
                    "timestamp": timestamp,
                    "record_kind": "verdict_json_decode_error",
                    "agent": effective_agent_type,
                    "session_id": session_id,
                    "snippet": raw_json[:400],
                }) + "\n")
        except Exception:
            pass
    # else: no sentinel at all — verdict_source stays "none"; regex handles it below.
# --- End IMP-02 structured extraction ---

# Short-circuit ternary: verdict is already bound to the structured-JSON value
# above if verdict_source == "structured_json"; otherwise reset to UNKNOWN so the
# regex fallback below can promote it. (The ternary's else-branch returns "UNKNOWN"
# without re-evaluating the left `verdict`.)
verdict = verdict if verdict_source == "structured_json" else "UNKNOWN"
if verdict == "UNKNOWN" and output:
    match = re.search(
        r'(?i)verdict:\s*(APPROVED_WITH_COMMENTS|APPROVED|CHANGES_REQUESTED|NEEDS_CHANGES|REJECTED)',
        str(output)
    )
    if match:
        verdict = match.group(1).upper()
        # Only promote source if we weren't already tagged schema-invalid.
        if verdict_source == "none":
            verdict_source = "regex_fallback"
        # If verdict_source == "structured_json_schema_invalid", KEEP IT — the JSON
        # was present but invalid; regex rescued the verdict but we want to preserve
        # the signal that the JSON path malfunctioned.
# verdict_source stays "none" iff both paths failed → IMP-H will block stop.

# --- End IMP-01 / IMP-02 ---

# --- IMP-H: Verdict protection — block agent stop if no verdict found ---
# Review agents (plan-reviewer, code-reviewer) MUST output a verdict.
# If verdict is UNKNOWN: block stop once to give agent another chance.
# Track attempts via marker file to avoid infinite blocking.
# Uses effective_agent_type (IMP-01) to handle payloads with empty agent_type.
# P0-3: Belt-and-suspenders — also protect unknown worktree agents (agent_transcript_path
# is only present for isolation:worktree agents). Covers the case where both registry lookup
# AND P0-2 heuristic fail to resolve effective_agent_type.

# NOTE (CR-004): The agent_transcript_path heuristic assumes all worktree agents
# are review agents. If a new non-review worktree agent is added, update
# REVIEW_AGENTS and this condition to avoid false verdict-blocking.
is_review_agent = (
    effective_agent_type in REVIEW_AGENTS
    or (effective_agent_type == "unknown" and data.get("agent_transcript_path"))
)
if verdict == "UNKNOWN" and is_review_agent and agent_id:
    block_marker = os.path.join(STATE_DIR, f".verdict-block-{agent_id}")
    if not os.path.exists(block_marker):
        # First attempt — block stop, give agent one more chance
        # Guard: only block if marker write succeeds (prevents infinite loop)
        marker_written = False
        try:
            with open(block_marker, "w") as f:
                f.write(timestamp)
            marker_written = True
        except Exception:
            print(f"save-review-checkpoint: block marker write failed, skipping block", file=sys.stderr)
        if marker_written:
            print(json.dumps({
                "decision": "block",
                "reason": (
                    "No verdict found in output. You MUST output your review verdict now. "
                    "Output VERDICT: {APPROVED|NEEDS_CHANGES|CHANGES_REQUESTED|REJECTED} "
                    "followed by a brief handoff section. Skip memory save."
                )
            }))
            sys.exit(0)
    else:
        # Second attempt — allow stop, clean up marker
        try:
            os.remove(block_marker)
        except Exception:
            pass
        print(f"save-review-checkpoint: verdict still UNKNOWN after block, allowing stop", file=sys.stderr)
# --- End IMP-H ---

# --- IMP-03: ALWAYS log SubagentStop payload for contract discovery ---
try:
    discovery = {
        "timestamp": timestamp,
        "hook": "SubagentStop",
        "agent_type": agent_type,
        "effective_agent_type": effective_agent_type,
        "session_id": session_id,
        "received_keys": sorted(data.keys()),
        "verdict_found": verdict != "UNKNOWN",
        "verdict_transcript_source": (("transcript:" + transcript_source) if transcript_used else ("payload" if data.get("last_assistant_message") else "none")),
        "agent_transcript_path_present": bool(data.get("agent_transcript_path")),
        "transcript_path_present": bool(data.get("transcript_path")),
    }
    # Include raw payload fields (excluding last_assistant_message/transcript content — too large)
    payload_sample = {
        k: str(v)[:200] for k, v in data.items()
        if k not in ("last_assistant_message",)
    }
    discovery["payload_sample"] = payload_sample
    with open(DEBUG_FILE, "a") as f:
        f.write(json.dumps(discovery) + "\n")
except Exception:
    pass
# --- End IMP-03 ---

# --- IMP-04 → IMP-11: Resolve worktree_path via shared utility ---
# Agents known to run with isolation: worktree
# Uses effective_agent_type so worktree resolution works even when payload omits agent_type.
WORKTREE_AGENTS = {"code-reviewer"}

worktree_path = None
worktree_resolution = None
if effective_agent_type in WORKTREE_AGENTS:
    import subprocess
    resolver = os.path.join(".claude", "scripts", "resolve-worktree-path.py")
    try:
        env = os.environ.copy()
        env["_CALLER"] = "save-review-checkpoint"
        result = subprocess.run(
            ["python3", resolver],
            capture_output=True, text=True, timeout=10,
            env=env
        )
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)
        if result.stdout.strip():
            resolved = json.loads(result.stdout.strip())
            worktree_path = resolved.get("worktree_path")
            worktree_resolution = resolved.get("resolution")
    except Exception as e:
        print(f"save-review-checkpoint: resolver failed: {e}", file=sys.stderr)

# --- IMP-01/IMP-05: Sync agent memory via standalone script ---
# Delegates to sync-agent-memory.sh (IMP-05: single-responsibility extraction).
# Memory sync is NON_CRITICAL — failure is logged but does not block.
memory_sync_result = None
memory_files_synced = []

if worktree_path and effective_agent_type in WORKTREE_AGENTS:
    try:
        import subprocess
        # Resolve to absolute path — CWD should be main repo, but be defensive
        script_path = os.path.abspath(os.path.join(".claude", "scripts", "sync-agent-memory.sh"))
        result = subprocess.run(
            [script_path, effective_agent_type, worktree_path],
            capture_output=True, text=True, timeout=30
        )
        # Parse structured JSON output from stdout
        try:
            sync_output = json.loads(result.stdout.strip())
            memory_sync_result = sync_output.get("result", "unknown")
            memory_files_synced = sync_output.get("files", [])
        except (json.JSONDecodeError, ValueError):
            memory_sync_result = f"parse_error: rc={result.returncode}"
        # Forward stderr for logging visibility
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)
    except Exception as e:
        memory_sync_result = f"error: {e}"
        print(f"save-review-checkpoint: memory sync script failed: {e}", file=sys.stderr)

# Log memory sync result to discovery file
if effective_agent_type in WORKTREE_AGENTS and worktree_path:
    try:
        sync_log = {
            "timestamp": timestamp,
            "hook": "SubagentStop",
            "event": "memory_sync",
            "agent_type": effective_agent_type,
            "session_id": session_id,
            "worktree_path": worktree_path,
            "worktree_resolution": worktree_resolution,
            "memory_sync_result": memory_sync_result,
            "files_synced": memory_files_synced,
        }
        with open(DEBUG_FILE, "a") as f:
            f.write(json.dumps(sync_log) + "\n")
    except Exception:
        pass

# --- End IMP-01/IMP-05 ---

# IMP-05: "agent" holds raw payload agent_type; "effective_agent_type" always
# present and reflects post-registry-recovery value. Lets consumers distinguish
# noise unknowns from recovered ones without a conditional schema.
marker = {
    "agent": agent_type,
    "effective_agent_type": effective_agent_type,
    "completed_at": timestamp,
    "session_id": session_id,
    "verdict": verdict,
    "verdict_source": verdict_source,          # IMP-02: HOW verdict was extracted
}
# IMP-02: WHERE the transcript was read from (debug-only provenance, renamed from verdict_source)
if transcript_used:
    marker["verdict_transcript_source"] = "transcript:" + (transcript_source or "unknown")
# Include worktree_path and memory sync status in marker
if worktree_path:
    marker["worktree_path"] = worktree_path
    marker["worktree_resolution"] = worktree_resolution
if memory_sync_result:
    marker["memory_sync"] = memory_sync_result
    marker["memory_files_synced"] = memory_files_synced

# --- IMP-06: Defensive fallback for marker write ---
# Primary write to review-completions.jsonl; on failure, fallback to /tmp.
# Logging failure should not block agent completion — only exit 2 if both fail.
completions_file = os.path.join(STATE_DIR, "review-completions.jsonl")
try:
    with open(completions_file, "a") as f:
        f.write(json.dumps(marker) + "\n")
except Exception as e:
    import tempfile
    fallback_file = os.path.join(tempfile.gettempdir(), "claude-review-completions-fallback.jsonl")
    try:
        with open(fallback_file, "a") as f:
            f.write(json.dumps(marker) + "\n")
        print(f"WARN: Primary write failed ({e}), wrote to fallback: {fallback_file}", file=sys.stderr)
    except Exception as e2:
        print(f"ERROR: Both primary and fallback write failed: {e} / {e2}", file=sys.stderr)
        sys.exit(2)

# --- IMP-02: Append verdict_mismatch log if dual-VERDICT mismatch detected above ---
if verdict_mismatch_record is not None:
    try:
        with open(os.path.join(STATE_DIR, "handoff-validation.jsonl"), "a") as _lf:
            _lf.write(json.dumps(verdict_mismatch_record) + "\n")
    except Exception:
        pass  # NON_CRITICAL
PYTHON_EOF
