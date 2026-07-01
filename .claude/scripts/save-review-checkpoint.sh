#!/bin/bash
# Hook: SubagentStop (matcher: (claude-kit:)?(plan-reviewer|code-reviewer|verdict-recovery))
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
  echo "[save-review-checkpoint] ERROR: python3 required but not found" >&2
  exit 2
}

# stray-.claude fix (2026-07-01): anchor state to project root, never cwd (hooks run in cwd).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"
export STATE_DIR
mkdir -p "$STATE_DIR"

# Read stdin JSON, parse once, write JSONL marker
INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF'
import json, sys, re, os
from datetime import datetime, timezone

STATE_DIR = os.environ.get("STATE_DIR") or os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state")
DEBUG_FILE = os.path.join(STATE_DIR, "worktree-events-debug.jsonl")

# --- P3: eager .verdict-block-{agent_id} TTL eviction ---
# Sentinels created on IMP-H first attempt are only removed if the agent retries
# (saving the second attempt). When the user does not retry, sentinels orphan
# indefinitely and prevent re-injection.
# CLAUDE_VERDICT_BLOCK_TTL_HOURS=6 (default) evicts files older than 6 h.
# Setting it to 0 disables eviction (pre-Part-4 behaviour).
def _evict_stale_verdict_blocks(state_dir):
    import time as _t, glob as _g
    try:
        ttl_hours = int(os.environ.get("CLAUDE_VERDICT_BLOCK_TTL_HOURS", "6"))
    except (ValueError, TypeError):
        ttl_hours = 6
    if ttl_hours <= 0:
        return 0
    ttl_seconds = ttl_hours * 3600
    now = _t.time()
    evicted = 0
    for f in _g.glob(os.path.join(state_dir, ".verdict-block-*")):
        try:
            age = now - os.path.getmtime(f)
            if age > ttl_seconds:
                os.remove(f)
                evicted += 1
        except OSError:
            pass
    if evicted > 0:
        try:
            with open(os.path.join(state_dir, "pipeline-metrics.jsonl"), "a") as _pm:
                _pm.write(json.dumps({
                    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "event": "verdict_blocks_evicted",
                    "count": evicted,
                    "ttl_hours": ttl_hours,
                }) + "\n")
        except OSError:
            pass
    return evicted

_evict_stale_verdict_blocks(STATE_DIR)
# --- end P3 ---

try:
    data = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
except Exception:
    data = {}

# I-04: defensive normalization of subagent_type. Platform v2.1.140 made the Agent-tool
# subagent_type match case/separator-insensitive; this hardens the SubagentStop payload
# compare the same way. agent_type is NOT part of the canonical-ID hash
# (sha256(category|location|problem)), so normalization cannot affect issue-ID byte-stability.
# It is identity on already-canonical inputs ("code-reviewer"/"plan-reviewer"), so marker
# fields stay byte-identical for canonical payloads.
def _normalize_agent_type(s):
    if not s:
        return s
    s = s.strip().lower().replace(" ", "-").replace("_", "-")
    # R2 (F-P3): strip a leading plugin namespace ('claude-kit:code-reviewer' -> 'code-reviewer').
    # agent_type is NOT a canonical-ID hash input, so this cannot affect issue-ID stability;
    # identity on already-bare names (no ':' present).
    if ":" in s:
        s = s.rsplit(":", 1)[-1]
    return s

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

effective_agent_type = _normalize_agent_type(agent_type)  # I-04: canonical on variant casing; identity on canonical
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
canonical_issue_ids = []      # IMP-03: populated in normalization block below;
                              # stays [] on regex_fallback / no structured JSON paths

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


def _compute_canonical_id(prefix, category, location, problem):
    """Deterministic content-addressed ID with input normalization (P2 fix).

    Canonical form: {prefix}{sha256(norm(category) + '|' + norm(location or '') + '|' + norm(problem))[:8]}
      where norm(s) = NFKC -> strip -> collapse internal whitespace -> lowercase -> strip terminal [.;:,]+

    Rationale: corpus shows 50/50 unique IDs across 15 multi-iter reviews — meaning the same
    logical issue is hashed to a fresh ID after any whitespace, case, or trailing-punctuation
    drift between iterations. IMP-03/IMP-04 delta-mode is silently a no-op without normalization.

    Backwards compatibility: CLAUDE_ISSUE_ID_NORMALIZE_VERSION=1 reverts to the v1 (raw) hash.
    Default v2 is the normalized hash. Pre-cutover IDs in review-completions.jsonl are NOT
    rewritten — enrich-context.sh tail-3 self-heals within 3 iterations.

    The '|' separator prevents field-boundary ambiguity (hash('ab'+'cd') != hash('a'+'bcd')).
    """
    import hashlib as _hashlib
    import os as _os
    import re as _re
    import unicodedata as _unicodedata

    def _norm(s):
        if s is None:
            return ""
        s = _unicodedata.normalize("NFKC", str(s))
        s = s.strip()
        s = _re.sub(r"\s+", " ", s)
        s = s.lower()
        s = _re.sub(r"[.;:,]+$", "", s)
        return s

    version = _os.environ.get("CLAUDE_ISSUE_ID_NORMALIZE_VERSION", "2")
    if version == "1":
        src = f"{category}|{location or ''}|{problem}"
    else:
        src = f"{_norm(category)}|{_norm(location)}|{_norm(problem)}"
    h = _hashlib.sha256(src.encode("utf-8")).hexdigest()[:8]
    return f"{prefix}{h}"


def _resolve_prefix(verdict_contract):
    """Map $verdict_contract discriminator to canonical ID prefix."""
    return {
        "plan_review_verdict": "PR-",
        "code_review_verdict": "CR-",
    }.get(verdict_contract, "XX-")  # XX- is a sentinel for schema FAIL in strict mode


verdict = "UNKNOWN"
if output:
    parsed, raw_json = _extract_verdict_json(output)
    if parsed is not None and isinstance(parsed, dict) and "verdict" in parsed:

        # --- IMP-03: Normalize issues[].id to canonical sha256-prefixed form ---
        # Must run BEFORE validate-handoff.sh so the schema sees canonical IDs.
        # Collision dedup: if two issues hash to the same canonical ID, keep the
        # first in canonical_issue_ids and log an id_collision record.
        #
        # CRITICAL CR-004 regression guard: do NOT move the insertion point outside
        # the `if parsed is not None and isinstance(parsed, dict) and "verdict" in parsed:`
        # block (lines 274-331 of the pre-IMP-03 file). The normalization mutates
        # parsed["issues"][*]["id"] and re-serialises raw_json so the tempfile write
        # and validate-handoff.sh below operate on canonical IDs.
        _issues = parsed.get("issues")
        if isinstance(_issues, list) and _issues:
            _prefix = _resolve_prefix(parsed.get("$verdict_contract", ""))
            _seen_ids = {}
            for _issue in _issues:
                if not isinstance(_issue, dict):
                    continue
                _cat = _issue.get("category", "")
                _loc = _issue.get("location", "")
                _prob = _issue.get("problem", "")
                _cid = _compute_canonical_id(_prefix, _cat, _loc, _prob)
                _issue["id"] = _cid  # overwrite advisory id — schema sees canonical
                if _cid in _seen_ids:
                    _seen_ids[_cid] += 1
                else:
                    _seen_ids[_cid] = 1
                    canonical_issue_ids.append({
                        "id": _cid,
                        "category": _cat,
                        "location": _loc,
                        "problem": _prob,
                    })
            # Dedup signalling — R-4 mitigation
            _dup_ids = [cid for cid, count in _seen_ids.items() if count > 1]
            if _dup_ids:
                try:
                    with open(
                        os.path.join(STATE_DIR, "handoff-validation.jsonl"),
                        "a",
                    ) as _lf:
                        for _dup in _dup_ids:
                            _lf.write(json.dumps({
                                "timestamp": timestamp,
                                "record_kind": "id_collision",
                                "agent": effective_agent_type,
                                "session_id": session_id,
                                "canonical_id": _dup,
                                "count": _seen_ids[_dup],
                            }) + "\n")
                except Exception:
                    pass  # NON_CRITICAL
            # Re-serialise raw_json so the tempfile written below contains the
            # normalised IDs. validate-handoff.sh will now see canonical form.
            try:
                raw_json = json.dumps(parsed)
            except Exception as _e:
                print(
                    f"save-review-checkpoint: re-serialise after normalization failed: {_e}",
                    file=sys.stderr,
                )
        # --- End IMP-03 normalization ---

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
        # CC 2.1.163: surface the no-verdict outcome in-context (ALLOW path — no decision:block).
        # Forward-compatible: pre-2.1.163 ignores the unknown field. Best-effort feedback; on the
        # rare double-write-failure path that ends in sys.exit(2) below, Claude Code ignores stdout
        # and this is dropped (acceptable — additionalContext carries no contract obligation).
        # additionalContext text is never a canonical issue-ID hash input.
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "SubagentStop", "additionalContext": f"Reviewer {effective_agent_type} produced no parseable VERDICT after a retry; checkpoint saved with verdict UNKNOWN. Orchestrator: invoke verdict-recovery or re-dispatch the reviewer."}}))
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
# P3: when raw agent_type is empty or "unknown" but the registry/heuristic recovered
# effective_agent_type (e.g. code-reviewer via P0-2 worktree heuristic), promote
# the marker's "agent" field too. Without this, downstream consumers (inject-review-
# context.sh on the next iteration) read 'unknown' and skip session-relevant entries.
_agent_marker = agent_type
if (not agent_type or agent_type == "unknown") and effective_agent_type and effective_agent_type != "unknown":
    _agent_marker = effective_agent_type
marker = {
    "agent": _agent_marker,
    "agent_raw": agent_type,                   # P3: keep the raw payload value for forensic
    "effective_agent_type": effective_agent_type,
    "completed_at": timestamp,
    "session_id": session_id,
    "verdict": verdict,
    "verdict_source": verdict_source,          # IMP-02: HOW verdict was extracted
    "canonical_issue_ids": canonical_issue_ids,  # IMP-03: dedup'd canonical IDs
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

# --- P0-04: Clear .iteration-in-flight on review agent completion ---
# Runs on the successful-completion path only. IMP-H's first-attempt block (sys.exit(0)
# above) never reaches here, so the flag stays alive while the agent is being retried.
# Deletion fires when the agent truly stops: verdict found, second IMP-H attempt, or
# verdict-recovery stop. Failure is NON_CRITICAL — stale check in save-progress-before-
# compact.sh self-heals within 30 min.
_iter_file = os.path.join(STATE_DIR, ".iteration-in-flight")
if os.path.isfile(_iter_file):
    try:
        os.remove(_iter_file)
        with open(DEBUG_FILE, "a") as _df:
            _df.write(json.dumps({
                "timestamp": timestamp,
                "hook": "SubagentStop",
                "event": "iteration_in_flight_cleared",
                "effective_agent_type": effective_agent_type,
                "session_id": session_id,
            }) + "\n")
    except Exception as _e:
        print(
            f"save-review-checkpoint: failed to clear .iteration-in-flight: {_e}",
            file=sys.stderr,
        )
# --- End P0-04 ---
PYTHON_EOF
