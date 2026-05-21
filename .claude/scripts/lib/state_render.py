"""Shared state renderer for Claude Kit workflow hooks.

Public API:
  CONTEXT_SIZE_CAP: int = 6000  -- shared cap constant (P5: lowered from 8192; hooks enforce in bash)
  latest_checkpoint(state_dir) -> str | None  -- mtime-newest checkpoint selector (P2 fix)
  load_state(state_dir, prompts_dir) -> dict  -- loads workflow state
  render(state, include, **kwargs) -> str  -- renders additionalContext sections
  rotate_spillover_files(state_dir, keep=5) -> None  -- LRU cleanup

Shared helpers (imported directly by complex hooks):
  _extract_yaml_section(text, section_name) -> list | None
  _extract_scalar(lines, key) -> str | None
  _extract_top_level(content, key) -> str | None
"""

import glob
import hashlib
import json
import os
import subprocess
import sys

CONTEXT_SIZE_CAP: int = 6000  # P5: lowered from 8192 to leave 4 000 chars of slack under Claude Code's 10 000-char hook-output cap

# ---------------------------------------------------------------------------
# Shared YAML helpers — migrated from inject-review-context.sh,
# save-progress-before-compact.sh, verify-state-after-compact.sh (3x copies)
# ---------------------------------------------------------------------------

def _extract_yaml_section(text: str, section_name: str) -> "list | None":
    """Extract lines belonging to a top-level YAML section (indent-based)."""
    lines = text.splitlines()
    in_section = False
    base_indent = -1
    result = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            if in_section:
                result.append("")
            continue
        indent = len(line) - len(line.lstrip())
        if not in_section:
            if stripped.startswith(section_name + ":"):
                in_section = True
                base_indent = indent
                val = stripped[len(section_name) + 1:].strip()
                if val:
                    result.append(val)
            continue
        if indent <= base_indent:
            break
        result.append(stripped)
    return result if result else None


def _extract_scalar(lines: list, key: str) -> "str | None":
    """Extract a scalar value from parsed YAML section lines."""
    for line in lines:
        stripped = line.strip().lstrip("- ")
        if stripped.startswith(key + ":"):
            return stripped[len(key) + 1:].strip().strip('"').strip("'")
    return None


def _extract_top_level(content: str, key: str) -> "str | None":
    """Extract a top-level scalar from checkpoint YAML (zero-indent keys only)."""
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith(key + ":") and not stripped.startswith("#"):
            if len(line) - len(line.lstrip()) == 0:
                return stripped[len(key) + 1:].strip().strip('"').strip("'")
    return None


# ---------------------------------------------------------------------------
# State loader
# ---------------------------------------------------------------------------

_CHECKPOINT_SCALAR_KEYS = {
    "phase_name", "phase_completed", "complexity", "route",
    "verdict", "session_type", "file_reads_in_sub_phase", "budget_threshold",
}


def latest_checkpoint(state_dir: str) -> "str | None":
    """Return the absolute path of the mtime-most-recent checkpoint, or None.

    Selection is by file mtime (descending), not by filename (alphabetical),
    so two checkpoints whose alphabetical and mtime orders diverge resolve
    deterministically.  Matches the semantics of notify-workflow-complete.sh
    (the only pre-existing correct site).

    Ties on identical mtimes resolve by alphabetically-larger name (stable,
    deterministic).  Returns None on no candidates or on OSError reading
    mtimes (e.g. permission denied on the state dir).

    Audit ref: .claude/prompts/workflow-hook-loop-audit.md § P2.
    """
    try:
        candidates = glob.glob(os.path.join(state_dir, "*-checkpoint.yaml"))
        if not candidates:
            return None
        candidates.sort(key=lambda p: (os.path.getmtime(p), p), reverse=True)
        return candidates[0]
    except OSError:
        return None


def _load_checkpoint(state: dict) -> None:
    """Populate checkpoint_*, feature, phase, iteration_* fields in state."""
    try:
        path = latest_checkpoint(state["state_dir"])
        if not path:
            return
        state["checkpoint_path"] = path
        with open(path) as f:
            content = f.read()
        state["checkpoint_content"] = content
        state["feature"] = os.path.basename(path).replace("-checkpoint.yaml", "")

        # Flat scalar extraction — zero-indent top-level keys only
        for line in content.splitlines():
            s = line.strip()
            if not s or s.startswith("#") or ":" not in s:
                continue
            if len(line) - len(line.lstrip()) != 0:
                continue
            k, _, v = s.partition(":")
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            # "current" → sub_phase_current (avoids collision with
            # implementation_progress.current_part) — matches enrich-context.sh
            if k == "current":
                state["sub_phase_current"] = v
            elif k in _CHECKPOINT_SCALAR_KEYS:
                state[k] = v

        iter_section = _extract_yaml_section(content, "iteration")
        if iter_section:
            pr = _extract_scalar(iter_section, "plan_review")
            cr = _extract_scalar(iter_section, "code_review")
            if pr:
                state["iteration_plan_review"] = pr
            if cr:
                state["iteration_code_review"] = cr
    except Exception:
        pass


def _load_plans(state: dict) -> None:
    """Populate plans_list in state.

    Filter matches enrich-context.sh: exclude -evaluate.md, include -spec.md.
    Golden-test invariant depends on exact match.
    """
    try:
        plans = sorted(glob.glob(os.path.join(state["prompts_dir"], "*.md")))
        state["plans_list"] = [
            os.path.basename(p) for p in plans
            if not p.endswith("-evaluate.md")
        ]
    except Exception:
        pass


def _load_completions(state: dict) -> None:
    """Populate review_completions_lines in state."""
    try:
        completions_file = os.path.join(state["state_dir"], "review-completions.jsonl")
        if os.path.isfile(completions_file):
            with open(completions_file) as f:
                state["review_completions_lines"] = f.readlines()
    except Exception:
        pass


def load_state(state_dir: str = ".claude/workflow-state",
               prompts_dir: str = ".claude/prompts") -> dict:
    """Load workflow state from filesystem. Returns state dict.

    Keys populated:
      state_dir, prompts_dir, checkpoint_path, checkpoint_content, feature,
      phase_name, phase_completed, complexity, route, verdict, session_type,
      iteration_plan_review, iteration_code_review,
      sub_phase_current, file_reads_in_sub_phase, budget_threshold,
      plans_list, review_completions_lines
    """
    state: dict = {
        "state_dir": state_dir,
        "prompts_dir": prompts_dir,
        "checkpoint_path": None,
        "checkpoint_content": None,
        "feature": None,
        "phase_name": None,
        "phase_completed": None,
        "complexity": None,
        "route": None,
        "verdict": "null",
        "session_type": "ad-hoc",
        "iteration_plan_review": "0/3",
        "iteration_code_review": "0/3",
        "sub_phase_current": None,
        "file_reads_in_sub_phase": None,
        "budget_threshold": None,
        "plans_list": [],
        "review_completions_lines": [],
    }
    _load_checkpoint(state)
    _load_plans(state)
    _load_completions(state)
    return state


# ---------------------------------------------------------------------------
# Spillover rotation
# ---------------------------------------------------------------------------

def rotate_spillover_files(state_dir: str, keep: int = 5) -> None:
    """LRU-5 rotation: delete oldest compact-overflow-*.log files beyond keep limit.

    All 4 hooks share filename pattern compact-overflow-{ts}-{pid}.log.
    Attribution is in the stderr WARN line ([hook.sh] prefix), not the filename.
    """
    try:
        pattern = os.path.join(state_dir, "compact-overflow-*.log")
        files = sorted(glob.glob(pattern))  # sorted by ts prefix → oldest first
        to_delete = files[:-keep] if len(files) > keep else []
        for f_path in to_delete:
            try:
                os.remove(f_path)
            except OSError:
                pass
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Section renderers (private)
# ---------------------------------------------------------------------------

def _render_checkpoint_oneliner(state: dict) -> "str | None":
    """One-liner: Checkpoint: feature | Phase: name (N/5) | ..."""
    feature = state.get("feature")
    if not feature:
        return None
    phase = state.get("phase_name", "unknown")
    phase_num = state.get("phase_completed", "?")
    complexity = state.get("complexity", "?")
    route = state.get("route", "?")
    verdict = state.get("verdict", "null")
    session_type = state.get("session_type", "ad-hoc")
    return (
        f"Checkpoint: {feature} | Phase: {phase} ({phase_num}/5) | "
        f"Complexity: {complexity} | Route: {route} | "
        f"Verdict: {verdict} | Session: {session_type}"
    )


def _render_plans(state: dict) -> "str | None":
    names = state.get("plans_list", [])
    if not names:
        return None
    return "Plans: " + ", ".join(names)


def _render_review_completions_brief(state: dict) -> "str | None":
    """Last 3 completions as 'agent @ ts' one-liners (enrich-context style)."""
    lines = state.get("review_completions_lines", [])
    if not lines:
        return None
    recent = lines[-3:] if len(lines) > 3 else lines
    reviews = []
    for line in recent:
        try:
            entry = json.loads(line.strip())
            agent = entry.get("agent", "unknown")
            ts = entry.get("completed_at", "?")
            reviews.append(f"{agent} @ {ts}")
        except json.JSONDecodeError:
            pass
    return ("Recent reviews: " + "; ".join(reviews)) if reviews else None


def _render_budget(state: dict) -> "str | None":
    """Budget bar from sub_phase checkpoint data."""
    reads_str = state.get("file_reads_in_sub_phase", "")
    if not reads_str or not str(reads_str).isdigit():
        return None
    reads = int(reads_str)
    sub_phase_name = (state.get("sub_phase_current") or "unknown").upper()
    cp_complexity = (state.get("complexity") or "M").upper()
    cp_phase = (state.get("phase_name") or "").lower()

    BUDGET_LIMITS = {
        ("planning", "S"): 5, ("planning", "M"): 10,
        ("planning", "L"): 20, ("planning", "XL"): 30,
        ("implementation", "S"): 3, ("implementation", "M"): 6,
        ("implementation", "L"): 12, ("implementation", "XL"): 18,
    }
    cp_threshold = state.get("budget_threshold", "")
    if cp_threshold and str(cp_threshold).isdigit():
        limit = int(cp_threshold)
    else:
        limit = BUDGET_LIMITS.get((cp_phase, cp_complexity), 20)
    if limit <= 0:
        return None
    pct = min(int(reads / limit * 100), 999)
    line = f"Budget: {reads}/{limit} ({pct}%) — {sub_phase_name}"
    if pct > 80:
        line += " — consider transitioning"
    return line


def _render_git_branch(state: dict) -> "str | None":
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True, timeout=2
        )
        branch = result.stdout.strip()
        return f"Branch: {branch}" if branch else None
    except Exception:
        return None


def _render_handoff_context(state: dict) -> "str | None":
    content = state.get("checkpoint_content")
    if not content:
        return None
    handoff = _extract_yaml_section(content, "handoff_payload")
    if not handoff:
        return None
    return "## Handoff Context\n" + "\n".join(f"  {l}" for l in handoff if l)


def _render_issues_history_text(state: dict) -> "str | None":
    content = state.get("checkpoint_content")
    if not content:
        return None
    issues = _extract_yaml_section(content, "issues_history")
    if not issues:
        return None
    return "## Issues History\n" + "\n".join(f"  {l}" for l in issues if l)


def _render_implementation_progress_text(state: dict) -> "str | None":
    content = state.get("checkpoint_content")
    if not content:
        return None
    progress = _extract_yaml_section(content, "implementation_progress")
    if not progress:
        return None
    return "## Implementation Progress\n" + "\n".join(f"  {l}" for l in progress if l)


def _render_checkpoint_ref(state: dict) -> "str | None":
    """Reference-link only (no YAML body) — replaces full checkpoint dump.

    KD-7 (spec): PostCompact hook reads checkpoint file from disk on recovery;
    in-context copy is pure overhead of 5–50 KB per PreCompact invocation.
    """
    feature = state.get("feature")
    state_dir = state.get("state_dir", ".claude/workflow-state")
    if not feature:
        return None
    phase = state.get("phase_completed", "?")
    return (
        f"## Workflow Checkpoint\n"
        f"File: {state_dir}/{feature}-checkpoint.yaml\n"
        f"Resume: /workflow --from-phase {phase}"
    )


def _render_recent_completions_summary(state: dict) -> "str | None":
    """Last 5 completions as one-line summaries (P5).

    Per-completion line: '{verdict} {agent}@{ts} ids=[CR-xxxx CR-yyyy] n={N}'
    Hard cap: 200 chars/line. Embedded `problem` text is dropped (recoverable from JSONL).
    """
    lines = state.get("review_completions_lines", [])
    tail = lines[-5:] if len(lines) > 5 else lines
    if not tail:
        return None
    summaries = []
    for raw in tail:
        try:
            entry = json.loads(raw.strip())
        except (json.JSONDecodeError, AttributeError):
            continue
        agent = entry.get("effective_agent_type") or entry.get("agent", "unknown")
        ts = entry.get("completed_at", "?")
        verdict = entry.get("verdict", "?")
        cids = entry.get("canonical_issue_ids") or []
        ids = [c.get("id", "?") for c in cids if isinstance(c, dict)]
        ids_str = " ".join(ids[:8]) if ids else "[]"
        if ids and len(ids) > 8:
            ids_str += f" +{len(ids) - 8}more"
        line = f"{verdict} {agent}@{ts} ids=[{ids_str}] n={len(ids)}"
        if len(line) > 200:
            line = line[:197] + "..."
        summaries.append(line)
    if not summaries:
        return None
    return "## Recent Review Completions\n" + "\n".join(summaries)


# Backward-compat shim: keep old name dispatching to the new renderer so any
# external caller importing _render_recent_completions_5 directly does not break.
_render_recent_completions_5 = _render_recent_completions_summary


# ---------------------------------------------------------------------------
# Public render API
# ---------------------------------------------------------------------------

_SECTIONS = {
    # enrich-context sections
    "checkpoint_oneliner": _render_checkpoint_oneliner,
    "plans": _render_plans,
    "review_completions_brief": _render_review_completions_brief,
    "budget": _render_budget,
    "branch": _render_git_branch,
    # save-progress-before-compact sections
    "handoff_context": _render_handoff_context,
    "issues_history_text": _render_issues_history_text,
    "implementation_progress_text": _render_implementation_progress_text,
    "checkpoint_ref": _render_checkpoint_ref,         # KD-7: reference-link
    "recent_completions_5": _render_recent_completions_summary,    # backward-compat key
    "recent_completions_summary": _render_recent_completions_summary,  # canonical key (P5)
}


def render(state: dict, include: list, **kwargs) -> str:
    """Render additionalContext string from the given section list.

    Args:
        state: dict from load_state()
        include: list of section keys (see _SECTIONS for valid keys)
        **kwargs: reserved — ignored (forward-compatible API extension)

    Returns:
        Assembled string; empty sections silently omitted.
    """
    parts = []
    for section in include:
        renderer = _SECTIONS.get(section)
        if renderer is None:
            continue
        try:
            result = renderer(state)
            if result:
                parts.append(result)
        except Exception:
            pass
    return "\n".join(parts)
