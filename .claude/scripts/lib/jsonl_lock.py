"""jsonl_lock — shared fcntl-based JSONL append helper (P4).

Imported by .claude/scripts/save-review-checkpoint.sh and track-task-lifecycle.sh
inside their python heredocs via:

    sys.path.insert(0, '.claude/scripts/lib')
    import jsonl_lock
    jsonl_lock.jsonl_append_locked(target_path, line)

Contract mirrors .claude/scripts/lib/jsonl-lock.sh:
  - CLAUDE_JSONL_APPEND_LOCK=on  -> fcntl.flock LOCK_EX | LOCK_NB, 50-attempt
    retry loop with 0.1 s sleep (5 s budget); on persistent failure:
    best-effort append + ANOMALY entry.
  - unset/off                   -> direct append (byte-identical to legacy).
  - Always returns None; never raises (NON_CRITICAL — JSONL append must not block).

Env:
  CLAUDE_JSONL_APPEND_LOCK     off (default) | on
  CLAUDE_WORKFLOW_STATE_DIR    fallback path for anomalies.jsonl
"""

from __future__ import annotations

import fcntl
import json
import os
import time
from datetime import datetime, timezone


def _ensure_newline(line: str) -> str:
    return line if line.endswith("\n") else line + "\n"


def jsonl_append_locked(target: str, line: str) -> None:
    """Append a single JSONL line to target with optional flock protection.

    Returns None always. Never raises (any failure path falls through to
    the legacy direct-append behaviour or silent best-effort).
    """
    mode = os.environ.get("CLAUDE_JSONL_APPEND_LOCK", "off")
    payload = _ensure_newline(line)

    if mode != "on":
        try:
            with open(target, "a") as f:
                f.write(payload)
        except Exception:
            pass
        return

    lockfile = target + ".lock"
    state_dir = os.environ.get(
        "CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state"
    )

    attempts = 0
    max_attempts = 50
    while attempts < max_attempts:
        try:
            with open(lockfile, "a+") as lf:
                try:
                    fcntl.flock(lf.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    attempts += 1
                    time.sleep(0.1)
                    continue
                except OSError:
                    attempts += 1
                    time.sleep(0.1)
                    continue
                with open(target, "a") as f:
                    f.write(payload)
                return
        except Exception:
            attempts += 1
            time.sleep(0.1)

    # Persistent flock failure — best-effort append + ANOMALY entry.
    try:
        with open(target, "a") as f:
            f.write(payload)
    except Exception:
        pass
    try:
        anomaly = {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "type": "JSONL_FLOCK_TIMEOUT",
            "target": target,
            "attempts": attempts,
        }
        with open(os.path.join(state_dir, "anomalies.jsonl"), "a") as f:
            f.write(json.dumps(anomaly) + "\n")
    except Exception:
        pass
