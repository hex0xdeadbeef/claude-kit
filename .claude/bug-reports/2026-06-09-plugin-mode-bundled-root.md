# claude-kit bug report — Plugin-mode bundled-file resolution

**Date:** 2026-06-09
**Reporter:** Claude (Opus 4.8), during a `/workflow` run (Outbox Worker M3.T7) in **Plugin mode**.
**Repo under work:** `b2b-store-notifications` at `/Users/dmitriym/Desktop/mds/b2b-store-notifications`.
**Kit checkout (plugin source):** `/Users/dmitriym/Desktop/claude-kit/.claude`.

## TL;DR

Two bugs hit during one `/workflow` run. **They share a single root cause:** in Plugin mode, **no `BUNDLED KIT ROOT` directive is injected into the model's context** (neither the main session nor the spawned subagents), so every bundled-kit file that a skill body references by a project-relative `.claude/...` path **fails to resolve** — because the project's own `.claude/skills/` ships a *different* skill set (the project's Go skills) and does **not** contain the kit's `workflow-protocols/`, `plan-review-rules/`, `code-review-rules/`, `templates/`, etc.

- **Bug A (severity: MEDIUM — recoverable):** plan-template + `workflow-protocols` files could not be read at their referenced project paths. I recovered by *guessing* the plugin root from the environment's "additional working directories". A less careful run would silently proceed **without** the orchestration protocols / plan template → degraded output.
- **Bug B (severity: HIGH — pipeline-fatal):** the `code-reviewer` subagent **could not resolve its rubric** (`code-review-rules/SKILL.md`) and returned **`VERDICT: REJECTED`** (a *workflow STOP*) on what was actually a clean implementation. Without manual intervention the whole pipeline would have halted on a false negative. The `plan-reviewer` hit the *same* missing-anchor condition but behaved **differently** (loaded from the sibling checkout with a WARN and proceeded) — so the two reviewers are **inconsistent**.

Everything else in the pipeline worked (designer → planner → coder → VERIFY → commit → push all succeeded), so this report is scoped to the two path-resolution failures plus minor notes.

---

## Environment facts (verified this session)

- `git ls-files` / `Read` confirmed: the project repo's `.claude/skills/` exists but contains the **project's** skills (`go-idioms`, `error-handling`, `code-style`, …) — **not** the kit's `workflow-protocols`, `plan-review-rules`, `code-review-rules`, or `templates`.
- The kit's bundled files exist **only** at `/Users/dmitriym/Desktop/claude-kit/.claude/...` (e.g. `skills/code-review-rules/SKILL.md` = 6543 bytes; `templates/plan-template.md` = 165 lines; `skills/workflow-protocols/orchestration-core.md` present).
- The session's "additional working directories" included `/Users/dmitriym/Desktop/claude-kit/.claude/scripts/tests` and `/Users/dmitriym/Desktop/claude-kit/.claude/prompts` — which is the **only** signal I had to infer the plugin root. There was **no explicit `BUNDLED KIT ROOT` directive** anywhere in context.

---

## Bug A — bundled-file paths don't resolve in Plugin mode

### A1. Plan template (no `plugin_path_note` at all)

The `/planner` skill body, STARTUP **step 2**:

```yaml
- step: 2
  action: Read
  file: ".claude/templates/plan-template.md"
  description: "load plan template"
```

This step has **no `plugin_path_note`** (unlike step 0, which does). Reading it produced:

```
Read(.claude/templates/plan-template.md)
→ File does not exist. Note: your current working directory is
  /Users/dmitriym/Desktop/mds/b2b-store-notifications.
```

I recovered only because I had *already* learned the plugin root from earlier failures, then read
`/Users/dmitriym/Desktop/claude-kit/.claude/templates/plan-template.md` successfully.

### A2. `workflow-protocols` files (has `plugin_path_note`, but its precondition is never met)

`/workflow` STARTUP step 0.1 and the `load_phases` block reference:

```
.claude/skills/workflow-protocols/SKILL.md
.claude/skills/workflow-protocols/orchestration-core.md
```

Both `plugin_path_note`s say, in effect: *"if a `BUNDLED KIT ROOT` directive is present in context, resolve under that root."* But **no such directive is present**, so the conditional guidance is inert and I fell back to the project path:

```
Read(.claude/skills/workflow-protocols/SKILL.md)          → File does not exist.
Read(.claude/skills/workflow-protocols/orchestration-core.md) → File does not exist.
```

I then read `…/claude-kit/.claude/skills/workflow-protocols/orchestration-core.md` directly and it worked.

### Root cause (A)

Two distinct failure modes, same theme:

1. **Missing note:** some bundled-file references (planner step 2 `plan-template.md`) carry *no* `plugin_path_note`, so even a fully-correct plugin runtime gives the model no resolution hint.
2. **Note present but precondition unsatisfiable:** the `plugin_path_note` is gated on *"if a `BUNDLED KIT ROOT` directive is present in context"* — but **nothing injects that directive** in Plugin mode. So the gate never fires and the model silently falls back to a project path that doesn't contain the kit file.

### Suggested fix (A)

- Ensure the Plugin runtime **injects an explicit `BUNDLED KIT ROOT: <abs-path>` directive** into the main-session context AND every spawned subagent's context (SubagentStart). The skill bodies already *expect* this directive — it just isn't being delivered.
- Add the missing `plugin_path_note` to **every** bundled-file reference that lacks one (audit all skills for `Read .claude/...` steps; planner step 2 is one confirmed miss).
- Consider a deterministic fallback in the notes: *"if no `BUNDLED KIT ROOT` directive is present, resolve bundled files relative to the directory of the currently-executing skill file"* — so resolution never depends on a runtime injection that may be absent.

---

## Bug B — `code-reviewer` hard-REJECTS on an unresolvable rubric (pipeline-fatal) + reviewer inconsistency

### What happened

When delegating Phase 4 to the `code-reviewer` subagent (no `BUNDLED KIT ROOT` directive in its delegation context — see Bug A root cause), the agent **aborted at STARTUP**:

```
VERDICT: REJECTED
issue: CR-setup-rubric-unresolvable [BLOCKER]
  "Rubric unresolvable — code-review-rules/SKILL.md not found under a trusted anchor
   (project path or BUNDLED KIT ROOT). … a sibling claude-kit checkout is reachable but
   is not a trusted anchor … REJECTED triggers a workflow STOP … coder_retry: false."
```

The agent's STARTUP rule **forbids it from searching the filesystem** for the rubric (a deliberate anti-version-drift guard), so it refused to load from the reachable sibling checkout and STOPped.

**Why this is severe:** per the kit's own routing, `REJECTED` = *workflow STOP*. The M3.T7 code was actually clean (the re-run reviewed it as `APPROVED_WITH_COMMENTS`). So a **correct implementation was blocked by a review-environment misconfiguration**. In an unattended `--auto` run this halts the pipeline on a false negative.

### The inconsistency

The `plan-reviewer` subagent, earlier in the **same** session, hit the **identical** missing-anchor condition but behaved **differently** — it loaded the rubric from the sibling checkout and **proceeded**, emitting only a WARN:

```
⚠️ WARN: rubric loaded from a session-registered additional working directory
(claude-kit checkout), not from an injected BUNDLED KIT ROOT directive — no
BUNDLED KIT ROOT was present in the delegation context. … This is a provenance
signal only; it does not change the verdict.
```

So: **`plan-reviewer` = lenient (load-with-WARN), `code-reviewer` = strict (REJECT)**. Same situation, opposite outcomes. One of them is wrong; they should agree.

### The fix that worked (workaround)

Re-dispatching the **same** `code-reviewer` with an explicit directive prepended to the delegation prompt resolved it immediately:

```
BUNDLED KIT ROOT: /Users/dmitriym/Desktop/claude-kit/.claude
We are in PLUGIN MODE … resolve code-review-rules/SKILL.md under that root …
```

→ the agent loaded the rubric and returned `APPROVED_WITH_COMMENTS`. (This is still review iteration 1/3 — the code was never actually reviewed on the first dispatch.)

### Secondary issue — `REJECTED` is semantically overloaded

A *setup error* (missing rubric) and a *fundamentally-wrong implementation* both map to `REJECTED` → *STOP*. These are very different. A reader/orchestrator can't distinguish "your code is unacceptable" from "my review tooling isn't wired up". Consider a distinct outcome (e.g. `BLOCKED_SETUP` / `ABSTAIN`) for environment failures, so the orchestrator can fix the environment and **re-dispatch** rather than treating it as a code rejection.

### Suggested fix (B)

1. Deliver the `BUNDLED KIT ROOT` directive into reviewer subagents in Plugin mode (same root cause as Bug A — the `SubagentStart inject-review-context.sh` hook is the natural place).
2. **Unify** plan-reviewer and code-reviewer rubric-resolution behavior. Pick one policy: either both abort, or both load-from-the-registered-kit-checkout-with-WARN. The lenient-with-WARN behavior is the more pipeline-robust default, *provided* the registered checkout is the pinned kit revision.
3. Separate "setup/environment failure" from a code `REJECTED` so a misconfigured review doesn't read as a code rejection (and doesn't consume a code-review iteration).

---

## Minor observations (lower confidence — may be out of scope / harness-level, not kit)

- **`SendMessage` unavailable.** After the plan-reviewer returned `NEEDS_CHANGES`, I wanted to continue *that same* agent (cheap re-confirm of 4 mechanical fixes) per the Agent-tool docs, but `ToolSearch "select:SendMessage"` → *"No matching deferred tools found."* So agent-continuation wasn't available; I had to either spawn a fresh ~80k-token review or proceed. This is likely a **harness** limitation rather than a claude-kit bug, but it interacts with the kit's review-loop economics (re-review cost). Flagging for awareness only.
- **Markdownlint noise in generated `.md` artifacts.** The plan/spec files the kit produces trip `MD022`/`MD032`/`MD037`, including a **false positive** where Go pointer syntax `*ResolveError` inside a fenced code block is read as markdown emphasis (`MD037`). Cosmetic; the linter is wrong about the code block, but the kit's `.md` artifact style invites the noise. Low priority.

---

## What did NOT go wrong (scoping, to avoid over-attribution)

- designer / planner / coder skills executed correctly once their bundled files were located.
- VERIFY (`go vet` + `make fmt` + `make lint` + `make test -race`) and the integration suite all ran and passed (one **flake** in `internal/app/ingest/pgrepo` during the full `-p 1` run that **cleared on isolation and on a clean re-run** — that's the project's known testcontainers reuse-container flake, **not** a kit bug).
- handoff JSON validation, checkpoint references, and the commit/push flow worked.
- The `cd`-persistence confusion I hit mid-session (running `git ls-files` in the wrong directory after a `cd /tmp/...`) was **my own tool-usage error**, not a kit defect — explicitly **not** attributed to claude-kit.
