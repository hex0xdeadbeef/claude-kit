#!/bin/bash
# Hook: Notification (no matcher — fires on all notification types)
# Purpose: Send OS-native desktop notification when Claude needs user attention
# Non-blocking: exit 0 always
# Privacy: no user data logged, no network requests
#
# Notification routing:
#   permission_prompt  → "Ожидается разрешение"
#   idle_prompt        → "Ожидается ввод"
#   auth_success       → (skip — info only, no action needed)
#   elicitation_dialog → "Требуется ответ"

set -euo pipefail

INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

command -v python3 >/dev/null 2>&1 || exit 0

python3 << 'PYTHON_EOF'
import json, os, subprocess, sys, shutil

input_data = os.environ.get("_HOOK_INPUT", "{}")
try:
    hook_input = json.loads(input_data)
except Exception:
    print("notify-user: failed to parse hook input JSON", file=sys.stderr)
    sys.exit(0)

notification_type = hook_input.get("notification_type", "")
message = hook_input.get("message", "")
title = hook_input.get("title", "Claude Code")

# Validate required fields
if not notification_type or not message:
    print(f"notify-user: missing notification_type or message in input", file=sys.stderr)
    sys.exit(0)

# Route: skip auth_success (informational, no action needed)
if notification_type == "auth_success":
    sys.exit(0)

# Map notification types to user-friendly titles
TYPE_MAP = {
    "permission_prompt": "Ожидается разрешение",
    "idle_prompt": "Ожидается ввод",
    "elicitation_dialog": "Требуется ответ",
}

notify_title = TYPE_MAP.get(notification_type, f"Claude: {notification_type}")

# Truncate message to prevent notification overflow
# 200 chars is conservative for most desktop notification daemons
if len(message) > 200:
    message = message[:197] + "..."

# OS detection + native notification
# macOS: osascript (AppleScript) — single quotes + escape for injection safety
# Linux: notify-send (libnotify) — array args, safe by design
# Fallback: stderr log

sent = False

if sys.platform == "darwin":
    # macOS — osascript with single-quote escaping (prevents shell injection)
    escaped_msg = message.replace("'", "''")
    escaped_title = notify_title.replace("'", "''")
    try:
        subprocess.run(
            ["osascript", "-e",
             f"display notification '{escaped_msg}' with title '{escaped_title}'"],
            timeout=5, capture_output=True
        )
        sent = True
    except subprocess.TimeoutExpired:
        print("notify-user: osascript timeout", file=sys.stderr)
    except Exception as e:
        print(f"notify-user: osascript failed: {e}", file=sys.stderr)

elif sys.platform.startswith("linux"):
    # Linux — notify-send (array args — safe from injection)
    if shutil.which("notify-send"):
        try:
            subprocess.run(
                ["notify-send", "--urgency=normal",
                 f"Claude: {notify_title}", message],
                timeout=5, capture_output=True
            )
            sent = True
        except subprocess.TimeoutExpired:
            print("notify-user: notify-send timeout", file=sys.stderr)
        except Exception as e:
            print(f"notify-user: notify-send failed: {e}", file=sys.stderr)

if not sent:
    # Fallback: stderr (visible in terminal logs)
    print(f"[Claude Notification] {notify_title}: {message}", file=sys.stderr)

PYTHON_EOF
exit 0
