---
name: Shell Script Review Conventions
description: Patterns for reviewing bash scripts in claude-kit — subshell isolation, set -euo pipefail, trap scope
type: project
---

# Shell Script Review Conventions

Recurring patterns found correct in claude-kit shell scripts (verified 2026-03-30):

## Subshell Python isolation

```bash
(python3 << 'PYTHON_EOF' || true)
...
PYTHON_EOF
echo '{}'
exit 0
```

This correctly isolates Python failures from the parent shell even with `set -euo pipefail`. The `|| true` catches non-zero exit from the subgroup. The `echo '{}'` runs unconditionally in the parent shell.

## trap scope for tmp_dir cleanup

In bash functions, `trap` cannot reference `local` variables after the function returns. The correct pattern is to declare `tmp_dir` without `local` in the calling function so it persists in the EXIT trap scope:

```bash
main() {
    # NO "local tmp_dir" here — needed for trap
    tmp_dir=$(some_function)
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM
}
```

## set -euo pipefail + || true

`|| true` on a command or subshell is the idiomatic way to "tolerate failures" without disabling `set -e` globally. Prefer this over disabling `set +e` for targeted error suppression.

## Stdin via env var

Pattern for passing stdin to Python heredoc: `export _HOOK_INPUT="$INPUT"` then `os.environ.get("_HOOK_INPUT", "{}")` inside Python. This avoids stdin redirection conflicts with heredocs and is consistent across claude-kit scripts.
