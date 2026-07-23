#!/bin/bash
# Hook: SubagentStart (matcher: (claude-kit:)?plan-reviewer, (claude-kit:)?code-reviewer — separate entries, bare or plugin-namespaced)
# Purpose: Inject workflow context as additionalContext for review agents
# Non-blocking: exit 0 always (context injection is additive, never blocks agent)
#
# Usage: inject-review-context.sh <agent-type>
#   agent-type: "plan-reviewer" or "code-reviewer" (passed from settings.json matcher)
#
# Data sources:
#   1. .claude/workflow-state/*-checkpoint.yaml — pipeline state
#   2. .claude/workflow-state/review-completions.jsonl — prior verdicts
#   3. .claude/prompts/*-spec.md — spec existence (L/XL)
#   4. .claude/prompts/*.md — plan existence
#
# Output: {"additionalContext": "..."} JSON on stdout (target: 1-3K chars of 10K limit)

set -euo pipefail

AGENT_TYPE="${1:-unknown}"
# P3: --sidecar-only mode writes additionalContext to a sidecar file under
# .claude/workflow-state/{name}-INJECTED-CONTEXT.md and emits no stdout JSON.
# Used by orchestrator pre-delegation for worktree-isolated code-reviewer launches
# where SubagentStart hook does NOT fire (3/3 confirmed in corpus 2026-04-29..05-02).
SIDECAR_ONLY=0
SIDECAR_NAME="${CLAUDE_SIDECAR_NAME:-code-reviewer}"
for arg in "$@"; do
    case "$arg" in
        --sidecar-only) SIDECAR_ONLY=1 ;;
        --sidecar-name=*) SIDECAR_NAME="${arg#--sidecar-name=}" ;;
    esac
done
export _SIDECAR_ONLY="$SIDECAR_ONLY"
export _SIDECAR_NAME="$SIDECAR_NAME"

# Read SubagentStart payload (or empty in sidecar mode) — need session_id for IMP-02 filtering
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
export _HOOK_INPUT="$HOOK_INPUT"

command -v python3 >/dev/null 2>&1 || {
  echo '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"[Workflow Context] python3 not available — context injection skipped"}}'
  exit 0
}

export _AGENT_TYPE="$AGENT_TYPE"

# CWD-independent lib path
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
export LIB_DIR

# stray-.claude fix (2026-07-01): anchor state to project root, never cwd (hooks run in cwd).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"
export STATE_DIR

# P5: write .iteration-in-flight for review agents so PreCompact protection
# is symmetric with the SubagentStop deletion at save-review-checkpoint.sh:725-741.
# Idempotent: overwrites any prior orchestrator STEP -1 write (same content shape).
# Best-effort: write failure logs a WARN per kit convention and proceeds with
# context injection (the harness is not blocked on sentinel write failure).
# Audit ref: .claude/prompts/workflow-hook-loop-audit.md § P5.
# Plan ref:  .claude/prompts/p5-iif-autowrite.md.
case "$AGENT_TYPE" in
  plan-reviewer|code-reviewer)
    IIF_FILE="${STATE_DIR}/.iteration-in-flight"
    IIF_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # Best-effort feature extraction from the mtime-newest checkpoint (P2 convention:
    # ls -t … | head -n1).  Fallback to "unknown" when no checkpoint exists yet
    # (e.g. plan-reviewer fires before the planner writes its first checkpoint).
    # `|| true` because `ls` returns non-zero on empty glob under `set -euo pipefail`
    # via pipefail propagation through the head; we want IIF_CP to be empty in that
    # case so the fallback feature='unknown' branch kicks in.
    IIF_CP=$(ls -t "${STATE_DIR}"/*-checkpoint.yaml 2>/dev/null | head -n1 || true)
    IIF_FEATURE="unknown"
    if [[ -n "$IIF_CP" ]]; then
      IIF_FEATURE=$(grep '^feature:' "$IIF_CP" 2>/dev/null \
        | head -n1 \
        | sed 's/^feature:[[:space:]]*//' \
        | tr -d '"' \
        | tr -d "'" \
        || echo "unknown")
      [[ -z "$IIF_FEATURE" ]] && IIF_FEATURE="unknown"
    fi
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    printf '{"agent":"%s","started_at":"%s","feature":"%s","source":"inject-review-context.sh"}\n' \
      "$AGENT_TYPE" "$IIF_NOW" "$IIF_FEATURE" \
      > "$IIF_FILE" 2>/dev/null \
      || echo "[inject-review-context] WARN: failed to write .iteration-in-flight" >&2
    ;;
esac

OUTPUT=$(python3 << 'PYTHON_EOF'
import json, os, glob, re, subprocess, sys


def _emit(ctx):
    # SubagentStart additionalContext MUST be nested under hookSpecificOutput
    # (docs: "it is not a top-level field"). shape must match the bash
    # python3-unavailable fallback echo (:~40) + caveman-suspend-for-reviewer.sh.
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": ctx}}))


def _kit_plugin_mode():
    # Env-independent plugin detection — mirror of lib/paths.sh KIT_PLUGIN_MODE. Claude Code does NOT
    # export CLAUDE_PLUGIN_ROOT to SubagentStart hook processes (anthropics/claude-code#27145, #24529).
    # LIB_DIR (= <bundled_root>/.claude/scripts/lib) is the authoritative anchor.
    if os.environ.get("CLAUDE_PLUGIN_ROOT"):
        return True
    lib_dir = os.environ.get("LIB_DIR", "")
    if not lib_dir:
        return False
    bundled_root = os.path.dirname(os.path.dirname(os.path.dirname(lib_dir)))
    project_root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    try:
        return os.path.realpath(bundled_root) != os.path.realpath(project_root)
    except Exception:
        return bundled_root != project_root


def _bundled_root_directive():
    # In plugin mode the reviewer's bundled -rules skill lives under the
    # plugin root, not the project. The reviewer runs in isolated context and never sees the
    # SessionStart inject-kit-context.sh directive, so carry it here. Plugin mode is detected via the
    # env-independent _kit_plugin_mode() (mirror of lib/paths.sh KIT_PLUGIN_MODE). Byte-identical
    # marker to inject-kit-context.sh. Empty in project mode (roots coincide) -> inert.
    if not _kit_plugin_mode():
        return ""
    lib_dir = os.environ.get("LIB_DIR", "")
    bundled_root = os.path.dirname(os.path.dirname(os.path.dirname(lib_dir))) if lib_dir else ""
    anchor = os.environ.get("CLAUDE_PLUGIN_ROOT", "") or bundled_root
    return (
        f"BUNDLED KIT ROOT: {anchor}\n"
        "Resolve every kit .claude/skills, .claude/templates, and supporting protocol file "
        "under this BUNDLED KIT ROOT — they ship inside the plugin, not your project. "
        "Project STATE (.claude/prompts, .claude/workflow-state, .claude/agent-memory) "
        "stays under your project root.\n\n"
    )


# Uniform import fallback (KD-6)
try:
    sys.path.insert(0, os.environ['LIB_DIR'])
    from state_render import _extract_yaml_section, _extract_scalar, _extract_top_level, latest_checkpoint
except Exception as _import_err:
    print(f'[inject-review-context] WARN: shared state-render unavailable — {_import_err}',
          file=sys.stderr)
    _emit(_bundled_root_directive())
    sys.exit(0)


def aggregate_pipeline_metrics(metrics_file, complexity, agent_type, session_completions=None):
    """Read pipeline-metrics.jsonl and return a brief history summary, or None.

    Returns None when:
    - session_completions is provided and has fewer than 3 entries (AC-7 gate)
    - File missing or unreadable
    - Fewer than 3 total entries (insufficient history)
    """
    if session_completions is not None and len(session_completions) < 3:
        return None
    if not os.path.isfile(metrics_file):
        return None
    try:
        entries = []
        with open(metrics_file) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        entries.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except Exception:
        return None

    if len(entries) < 3:
        return None

    # Iterations for matching complexity
    matching = [e for e in entries if e.get("complexity", {}).get("estimated") == complexity
                or e.get("complexity", {}).get("actual") == complexity]
    if not matching:
        matching = entries  # Fall back to all runs if no complexity match

    if agent_type == "plan-reviewer":
        iters = [e.get("review_iterations", {}).get("plan_review", 0) for e in matching if "review_iterations" in e]
    else:
        iters = [e.get("review_iterations", {}).get("code_review", 0) for e in matching if "review_iterations" in e]
    avg_iters = round(sum(iters) / len(iters), 1) if iters else None

    # Top issue categories across all entries
    category_counts = {}
    for e in entries:
        found = e.get("issues_found", {})
        for cat, count in found.items():
            if isinstance(count, int) and count > 0:
                category_counts[cat] = category_counts.get(cat, 0) + count
    top_categories = sorted(category_counts.items(), key=lambda x: x[1], reverse=True)[:3]

    # Anomaly: recent BLOCKER pattern (last 3 runs)
    recent = entries[-3:]
    recent_blockers = sum(1 for e in recent if e.get("issues_found", {}).get("blocker", 0) > 0)

    lines_out = ["[Pipeline history context]:"]
    n_complexity = len(matching)
    n_total = len(entries)
    scope = f"{complexity} complexity" if n_complexity < n_total else "all runs"
    if avg_iters is not None:
        review_label = "plan-review" if agent_type == "plan-reviewer" else "code-review"
        lines_out.append(f"- Avg {review_label} iterations ({scope}, {n_complexity} runs): {avg_iters}")
    if top_categories:
        cats = ", ".join(f"{cat} ({cnt})" for cat, cnt in top_categories)
        lines_out.append(f"- Top issue categories: {cats}")
    if recent_blockers >= 2:
        lines_out.append(f"- Note: {recent_blockers}/3 recent runs had BLOCKER issues — focus security/architecture checks")

    return "\n".join(lines_out) if len(lines_out) > 1 else None


def emit_delta_focus_block(lines, state_dir, feature, agent_type, content, current_iter_str, delta_mode):
    """Emit [Iter N focus — delta only] block into additionalContext lines.

    Non-blocking: any failure returns silently without modifying lines.
    mode=off never reaches here (guarded at call site).
    Missing SHA → WARN stderr + return.
    """
    try:
        iter_num = int(str(current_iter_str).split("/")[0])
    except (ValueError, AttributeError):
        return
    if iter_num < 2:
        return  # no delta on iter 1 — nothing to compare against

    block = []
    block.append(f"[Iter {iter_num} focus — delta only] (mode: {delta_mode})")

    if agent_type == "plan-reviewer":
        manifest_path = os.path.join(state_dir, f"{feature}-diff-manifest.json")
        if not os.path.isfile(manifest_path):
            return  # AC-2: no manifest → no block (normal on iter 1 or KD-6 reroute)
        try:
            with open(manifest_path) as mf:
                manifest = json.loads(mf.read())
            if not isinstance(manifest, list):
                return
        except Exception:
            return  # parse failure → graceful no-op

        # KD-5 (spec): KD-6 fallback cascade — any Part with "KD-6 fallback" reason
        kd6_active = any("KD-6 fallback" in (e.get("reason") or "") for e in manifest)
        if kd6_active:
            header = "HINT" if delta_mode == "warn" else "FOCUS"
            block.append(
                f"{header}: ALL Parts require review "
                f"(KD-6 fallback active — manifest had unmappable issue locations)"
            )
        else:
            changed = [e for e in manifest if e.get("status") in ("NEEDS_UPDATE", "NEW")]
            unchanged = [e for e in manifest if e.get("status") == "UNCHANGED"]
            if delta_mode == "warn":
                block.append("HINT: focus on changed Parts first — full plan still accessible if needed")
            else:
                block.append("FOCUS: review only changed Parts unless regression suspected")
            changed_ids = ", ".join(str(e.get("part_id", "?")) for e in changed)
            unchanged_ids = ", ".join(str(e.get("part_id", "?")) for e in unchanged)
            if changed_ids:
                block.append(f"Parts changed since iter {iter_num - 1}: {changed_ids}")
            if unchanged_ids:
                block.append(f"Parts unchanged (preservation-contract): {unchanged_ids}")

        block.append(f"Full plan: .claude/prompts/{feature}.md")

    elif agent_type == "code-reviewer":
        # Extract iteration_commit_sha[iter_num - 1] from checkpoint YAML (anchored regex)
        prior_sha = None
        sha_section = _extract_yaml_section(content, "iteration_commit_sha")  # renamed
        if sha_section:
            prior_key = str(iter_num - 1)
            for sha_line in sha_section:
                m = re.match(
                    rf'^\s*["\']?{re.escape(prior_key)}["\']?\s*:\s*["\']?([a-f0-9]{{7,40}})["\']?\s*$',
                    sha_line
                )
                if m:
                    prior_sha = m.group(1)
                    break

        if not prior_sha:
            # Graceful no-op — do not block review
            import sys as _sys
            print(
                f"[inject-review-context] WARN: iteration_commit_sha[{iter_num - 1}] "
                f"missing — code delta skipped",
                file=_sys.stderr
            )
            return

        # Run git diff for file-level delta (R-6: wrap in try/except)
        try:
            result_names = subprocess.run(
                ["git", "diff", f"{prior_sha}..HEAD", "--name-only"],
                capture_output=True, text=True, timeout=15
            )
            result_stat = subprocess.run(
                ["git", "diff", f"{prior_sha}..HEAD", "--stat"],
                capture_output=True, text=True, timeout=15
            )
            name_only = result_names.stdout.strip()
            stat_out = result_stat.stdout.strip()
        except Exception:
            return  # git failure → graceful no-op (R-6)

        if not name_only:
            return  # no files changed between iterations — skip emission

        if delta_mode == "warn":
            block.append(
                "HINT: focus on changed files first — "
                "full branch diff accessible via git diff $BASE...HEAD"
            )
        else:
            block.append(
                "FOCUS: review only changed files unless regression suspected"
            )

        prior_sha_short = prior_sha[:8] if len(prior_sha) >= 8 else prior_sha
        block.append(f"Files changed since iter {iter_num - 1} (prior_sha={prior_sha_short}..HEAD):")
        for fname in name_only.splitlines():
            if fname.strip():
                block.append(f"  {fname.strip()}")
        stat_lines = stat_out.splitlines()
        if stat_lines:
            block.append(f"Stat: {stat_lines[-1].strip()}")

        block.append("Full branch diff: git diff $BASE...HEAD")

    else:
        return  # unknown agent type → skip

    if len(block) > 1:
        lines.append("")
        lines.extend(block)


agent_type = os.environ.get("_AGENT_TYPE", "unknown")

# IMP-02: session_id from SubagentStart payload for filtering review-completions
try:
    _payload = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
    current_session_id = _payload.get("session_id", "")
except Exception:
    current_session_id = ""

state_dir = os.environ.get("STATE_DIR") or os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state")
prompts_dir = ".claude/prompts"

# --- P3: eager .verdict-block-{agent_id} TTL eviction (mirrors save-review-checkpoint) ---
def _evict_stale_verdict_blocks_inject(_dir):
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
    for f in _g.glob(os.path.join(_dir, ".verdict-block-*")):
        try:
            if (now - os.path.getmtime(f)) > ttl_seconds:
                os.remove(f)
                evicted += 1
        except OSError:
            pass
    return evicted

_evict_stale_verdict_blocks_inject(state_dir)
# --- end P3 eviction ---

# Find latest checkpoint (P2: mtime-newest via shared helper; was alphabetical sorted()[-1])
_latest_cp_path = latest_checkpoint(state_dir)
if not _latest_cp_path:
    _emit(_bundled_root_directive() + "[Workflow Context] No checkpoint found — running outside workflow or first phase.")
    raise SystemExit(0)

try:
    with open(_latest_cp_path) as f:
        content = f.read()
except Exception:
    _emit(_bundled_root_directive() + "[Workflow Context] Checkpoint unreadable — context injection skipped.")
    raise SystemExit(0)

# Extract scalars (using imported helpers — AC-2, rename: no underscore → underscore)
feature = _extract_top_level(content, "feature") or "unknown"
complexity = _extract_top_level(content, "complexity") or "?"
route = _extract_top_level(content, "route") or "?"
phase_completed = _extract_top_level(content, "phase_completed") or "?"

# Extract iteration counters
iteration_section = _extract_yaml_section(content, "iteration")
plan_review_iter = "0/3"
code_review_iter = "0/3"
if iteration_section:
    plan_review_iter = _extract_scalar(iteration_section, "plan_review") or "0/3"
    code_review_iter = _extract_scalar(iteration_section, "code_review") or "0/3"

# Determine current iteration for this agent
if agent_type == "plan-reviewer":
    current_iter = plan_review_iter
    review_phase = 2
elif agent_type == "code-reviewer":
    current_iter = code_review_iter
    review_phase = 4
elif agent_type == "verdict-recovery":
    current_iter = "recovery"
    review_phase = 4  # verdict-recovery runs after code-review phase
else:
    current_iter = "?/3"
    review_phase = 0

# Find plan and spec artifacts
plans = sorted(glob.glob(os.path.join(prompts_dir, f"{feature}.md")))
plan_path = plans[0] if plans else "not found"
specs = sorted(glob.glob(os.path.join(prompts_dir, f"{feature}-spec.md")))
spec_path = specs[0] if specs else "none"

# Context header
# NOTE: `lines` list is initialized here — this is the authoritative initialization.
lines = [
    "[Workflow Context — injected by SubagentStart hook]",
    f"Feature: {feature}",
    f"Complexity: {complexity}",
]

if agent_type == "plan-reviewer":
    lines.append(f"Route: {route}")

lines.append(f"Plan: {plan_path}")
lines.append(f"Spec: {spec_path}")
lines.append(f"Iteration: {current_iter}")

# Code-reviewer specific: verify status
if agent_type == "code-reviewer":
    verify_section = _extract_yaml_section(content, "verify_result")
    if verify_section:
        v_status = _extract_scalar(verify_section, "status") or "?"
        v_command = _extract_scalar(verify_section, "command") or "?"
        lines.append(f"Verify: {v_status} (command: {v_command})")

    # Plan-review approved_with_notes from handoff
    handoff = _extract_yaml_section(content, "handoff_payload")
    if handoff:
        in_notes = False
        notes = []
        for h_line in handoff:
            stripped = h_line.strip()
            if stripped.startswith("approved_with_notes:"):
                in_notes = True
                continue
            if in_notes:
                if stripped.startswith("- "):
                    notes.append(stripped[2:].strip().strip('"').strip("'"))
                elif stripped and not stripped.startswith("-"):
                    break
        if notes:
            lines.append("")
            lines.append("Plan-review notes:")
            for note in notes:
                lines.append(f"  - {note}")

# Prior iterations from issues_history
issues = _extract_yaml_section(content, "issues_history")
if issues:
    entries = []
    current = {}
    for line in issues:
        stripped = line.strip().lstrip("- ")
        if stripped.startswith("phase:"):
            if current:
                entries.append(current)
            current = {"phase": stripped.split(":")[1].strip()}
        elif ":" in stripped and current:
            k, _, v = stripped.partition(":")
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            if k in ("iteration", "verdict", "issues", "resolved",
                     "resolved_ids", "regression_ids", "canonical_issue_ids"):
                current[k] = v
    if current:
        entries.append(current)

    # Filter to this review phase
    phase_entries = [e for e in entries if e.get("phase") == str(review_phase)]
    if phase_entries:
        lines.append("")
        lines.append("Prior iterations:")
        for entry in phase_entries:
            iter_num = entry.get("iteration", "?")
            verdict = entry.get("verdict", "?")
            issues_str = entry.get("issues", "[]")
            resolved_str = entry.get("resolved", "[]")
            lines.append(f"  - Iteration {iter_num}: {verdict} — issues: {issues_str}")
            if resolved_str and resolved_str != "[]":
                lines.append(f"    Addressed: {resolved_str}")
            # IMP-03: auto set-diff projections from orchestrator post_delegation
            resolved_ids_str = entry.get("resolved_ids", "[]")
            regression_ids_str = entry.get("regression_ids", "[]")
            if resolved_ids_str and resolved_ids_str != "[]":
                lines.append(f"    Resolved IDs (auto set-diff): {resolved_ids_str}")
            if regression_ids_str and regression_ids_str != "[]":
                lines.append(f"    REGRESSION IDs (reappeared): {regression_ids_str}")
        # IMP-03: prominent regression alert for current phase's most recent entry
        _last_entry = phase_entries[-1] if phase_entries else None
        if _last_entry:
            _reg = _last_entry.get("regression_ids", "[]")
            if _reg and _reg != "[]":
                lines.insert(0, "")
                lines.insert(0, f"[REGRESSION ALERT] previously-resolved issues reappeared: {_reg}")
                lines.insert(0, "")

# Prior verdicts from review-completions.jsonl (IMP-02: filter by session + effective_agent_type)
# P1-3: Preserve "unknown" entries as failed_attempts metadata for orchestrator recovery decisions
# P3-3: Read from both primary and fallback locations
completions_file = os.path.join(state_dir, "review-completions.jsonl")
import tempfile
fallback_file = os.path.join(tempfile.gettempdir(), "claude-review-completions-fallback.jsonl")

comp_lines = []
for _cf in (completions_file, fallback_file):
    if os.path.isfile(_cf):
        try:
            with open(_cf) as f:
                comp_lines.extend(f.readlines())
        except Exception:
            pass

relevant = []
if comp_lines:
    try:
        failed_attempts = []
        seen = set()  # P3-3: deduplicate by (session_id, completed_at, agent)
        for cl in comp_lines:
            try:
                entry = json.loads(cl.strip())
            except json.JSONDecodeError:
                continue
            dedup_key = (entry.get("session_id", ""), entry.get("completed_at", ""), entry.get("agent", ""))
            if dedup_key in seen:
                continue
            seen.add(dedup_key)
            # IMP-02: scope to current session only
            if current_session_id and entry.get("session_id") != current_session_id:
                continue
            # IMP-05: prefer effective_agent_type, fall back to raw agent for legacy entries
            eff = entry.get("effective_agent_type") or entry.get("agent", "")
            # P1-3: Track unknown entries as failed attempts instead of discarding
            if eff == "unknown":
                failed_attempts.append(entry)
                continue
            if eff != agent_type:
                continue
            relevant.append(entry)
        if relevant:
            lines.append("")
            lines.append("Prior review completions (this pipeline):")
            # P5: per-iter summary line; embedded problem/suggestion text dropped
            # (recoverable from review-completions.jsonl on disk).
            for r in relevant[-3:]:  # Last 3
                _cids = r.get("canonical_issue_ids") or []
                _ids = [c.get("id", "?") for c in _cids if isinstance(c, dict)]
                _ids_str = " ".join(_ids[:8]) if _ids else "[]"
                if _ids and len(_ids) > 8:
                    _ids_str += f" +{len(_ids) - 8}more"
                lines.append(
                    f"  - {r.get('completed_at', '?')}: {r.get('verdict', '?')} "
                    f"ids=[{_ids_str}] n={len(_ids)}"
                )
            # No per-issue category/location detail — the IDs are referenceable;
            # full text is in review-completions.jsonl on disk.
        if failed_attempts:
            lines.append(f"prior_failed_attempts: {len(failed_attempts)}")
            lines.append(f"  Last failed at: {failed_attempts[-1].get('completed_at', '?')}")

    except Exception:
        pass

# IMP-04 delta-review-mode
_delta_mode = (
    _extract_top_level(content, "delta_review_mode")
    # Default to 'strict' in plugin mode via the env-independent
    # bundled-root detection (_kit_plugin_mode()), else 'off'. An explicit CLAUDE_DELTA_REVIEW_MODE
    # always wins (outer or).
    or (os.environ.get("CLAUDE_DELTA_REVIEW_MODE")
        or ("strict" if _kit_plugin_mode() else "off")).lower()
)
if _delta_mode in ("warn", "strict"):
    emit_delta_focus_block(
        lines, state_dir, feature, agent_type, content, current_iter, _delta_mode
    )

# Pipeline history — AC-7 gate: inject ONLY when iter >= 2 AND >= 3 session completions
# `relevant` is populated above by the JSONL filter block.
current_iter_num = 0
try:
    current_iter_num = int(str(current_iter).split("/")[0])
except Exception:
    pass

metrics_summary = None
if current_iter_num >= 2:
    metrics_summary = aggregate_pipeline_metrics(
        os.path.join(state_dir, "pipeline-metrics.jsonl"),
        complexity,
        agent_type,
        session_completions=relevant,
    )
if metrics_summary:
    lines.append("")
    lines.append(metrics_summary)

# ─────────────────────────────────────────────────────────────────────────────
# PROJECT-KNOWLEDGE.md injection (planner-genericity feature)
# Reads .claude/PROJECT-KNOWLEDGE.md (cwd-relative); appends as a labelled
# block. Reviewer agents use the slots to resolve language-neutral checks.
# Failure mode: missing PK → log record_kind="pk_missing_at_inject" + skip.
# Telemetry record carries iteration + phase + agent for analysis correlation.
# ─────────────────────────────────────────────────────────────────────────────
pk_path = ".claude/PROJECT-KNOWLEDGE.md"
pk_block_added = False
if os.path.isfile(pk_path):
    try:
        with open(pk_path, "r", encoding="utf-8") as pf:
            pk_content = pf.read()
        # Inject ONLY the reviewer-consumed slot blocks (extract_pk_slots), not a
        # blind byte prefix. Reviewers reference a fixed slot set; the raw file's
        # frontmatter / H1 / HTML comment + non-slot prose are dead injection.
        # Safety net: if extraction finds no slot (unexpected PK shape) keep the
        # full content. Per-block cap below is a backstop; the whole additionalContext
        # is bounded later by CAP=6000 (see size-cap block near end of this script).
        try:
            from pk_slots import extract_pk_slots
            pk_block = extract_pk_slots(pk_content)
        except Exception:
            pk_block = ""
        if not pk_block:
            pk_block = pk_content
        if len(pk_block) > 4096:
            pk_block = pk_block[:4096] + "\n\n... [truncated — full PK at .claude/PROJECT-KNOWLEDGE.md]"
        lines.append("")
        lines.append("## Project Knowledge (resolved slots — from .claude/PROJECT-KNOWLEDGE.md)")
        lines.append(pk_block.strip())
        pk_block_added = True
    except Exception as _pk_err:
        # Non-fatal — agent proceeds without PK; will SKIP slot-driven checks
        import sys as _sys
        print(
            f"[inject-review-context] WARN: PROJECT-KNOWLEDGE.md unreadable: {_pk_err}",
            file=_sys.stderr
        )

if not pk_block_added:
    # Telemetry — append a record to handoff-validation.jsonl (if present)
    try:
        validation_log = os.path.join(state_dir, "handoff-validation.jsonl")
        os.makedirs(state_dir, exist_ok=True)
        import datetime as _dt
        record = {
            "ts": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "record_kind": "pk_missing_at_inject",
            "agent": agent_type,
            "feature": feature,
            "iteration": current_iter,
            "phase": review_phase,
            "session_id": current_session_id,
            "note": "PROJECT-KNOWLEDGE.md missing or unreadable; reviewer will SKIP slot-driven checks and emit consolidated NIT issue"
        }
        with open(validation_log, "a", encoding="utf-8") as vf:
            vf.write(json.dumps(record) + "\n")
        # Inject a one-line hint into additionalContext so reviewer knows
        lines.append("")
        lines.append("[Project Knowledge — NOT INJECTED]")
        lines.append("PROJECT-KNOWLEDGE.md is missing. Slot-driven architecture checks will be SKIPPED.")
        lines.append("Emit ONE consolidated NIT issue listing skipped slots in your VERDICT_JSON.")
    except Exception:
        pass  # Telemetry is best-effort; never block injection

# Surface current effort level to reviewer when available.
# Reads $CLAUDE_EFFORT (v2.1.133+ hook subprocess env) first; falls back to
# effort.level from the SubagentStart hook payload. Omitted when both absent.
_eff_level = os.environ.get("CLAUDE_EFFORT", "").strip()
if not _eff_level:
    try:
        _hook_payload = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
        _eff_obj = _hook_payload.get("effort") if isinstance(_hook_payload, dict) else None
        if isinstance(_eff_obj, dict):
            _eff_level = str(_eff_obj.get("level", "")).strip()
    except Exception:
        _eff_level = ""
if _eff_level:
    lines.append("")
    lines.append(f"Effort: {_eff_level}")

text = "\n".join(lines)
text = _bundled_root_directive() + text
# P3: sidecar mode — write to file, emit empty additionalContext.
_sidecar_only = os.environ.get("_SIDECAR_ONLY", "0") == "1"
_sidecar_name = os.environ.get("_SIDECAR_NAME", "code-reviewer")
if _sidecar_only:
    _sidecar_path = os.path.join(state_dir, f"{_sidecar_name}-INJECTED-CONTEXT.md")
    try:
        os.makedirs(state_dir, exist_ok=True)
        # Atomic write: tempfile + os.rename
        import tempfile as _tempfile
        _tmp_fd, _tmp_path = _tempfile.mkstemp(prefix=f".{_sidecar_name}-INJECTED-", dir=state_dir)
        with os.fdopen(_tmp_fd, "w") as _tf:
            _tf.write(text)
        os.rename(_tmp_path, _sidecar_path)
        print(json.dumps({"additionalContext": "", "sidecar_written": _sidecar_path}))
    except Exception as _e:
        print(json.dumps({"additionalContext": f"[sidecar write failed: {_e}]"}))
else:
    _emit(text)
PYTHON_EOF
)

# Size cap — P5: lowered from 8192 → 6000 to leave 4000 chars of slack
# under Claude Code's documented 10000-char hook-output cap (code.claude.com/docs/en/hooks).
CAP=6000
SIZE=${#OUTPUT}
if [[ $SIZE -gt $CAP ]]; then
    mkdir -p "$STATE_DIR"
    OVERFLOW_FILE="${STATE_DIR}/compact-overflow-$(date -u +%s)-$$.log"
    printf '%s' "$OUTPUT" > "$OVERFLOW_FILE"
    echo "[inject-review-context] WARN: output ${SIZE} chars > ${CAP}, saved to ${OVERFLOW_FILE}" >&2
    LIB_DIR="$LIB_DIR" STATE_DIR="$STATE_DIR" python3 -c "
import sys, os; sys.path.insert(0, os.environ['LIB_DIR'])
import state_render; state_render.rotate_spillover_files(os.environ['STATE_DIR'])
"
    PREVIEW=$(printf '%s' "$OUTPUT" | head -c 1000)
    _REF="$OVERFLOW_FILE" _SIZE="$SIZE" _PREVIEW="$PREVIEW" python3 -c "
import json, os
ref = os.environ['_REF']; size = os.environ['_SIZE']; preview = os.environ['_PREVIEW']
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SubagentStart', 'additionalContext': '[Overflow] Full output (' + size + ' chars) saved to ' + ref + '. Preview:\n' + preview + '\n…'}}))
"
else
    printf '%s\n' "$OUTPUT"
fi
exit 0
