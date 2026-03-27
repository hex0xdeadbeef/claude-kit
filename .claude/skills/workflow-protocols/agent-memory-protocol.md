# Agent Memory Protocol

purpose: "Standardized memory behavior for all agents with `memory: project` frontmatter"

---

agent_memory_protocol:
  applies_to: "All agents with `memory: project` — code-researcher, code-reviewer, plan-reviewer"
  storage: ".claude/agent-memory/{agent_name}/"
  index: "MEMORY.md in agent memory dir (≤200 lines)"

  startup:
    action: "Read .claude/agent-memory/{agent_name}/MEMORY.md for prior context"
    on_missing: "First run — no memory to load, proceed without"
    purpose: "Recall codebase patterns, past review findings, project topology"

  completion:
    ordering: "AFTER primary output is fully formed (verdict, handoff, summary)"
    action: "Save newly discovered patterns to agent memory"
    severity: "NON_CRITICAL — if turns exhausted after output, skip memory entirely"
    what_to_save:
      code-researcher: "Package locations, key interfaces, codebase topology, patterns found"
      code-reviewer: "Code anti-patterns, recurring issues, good patterns from APPROVED reviews"
      plan-reviewer: "Plan anti-patterns, common section gaps, successful architecture patterns"

  first_run:
    trigger: "MEMORY.md does not exist in agent memory dir"
    action: "Initialize MEMORY.md with brief project structure summary"
    what_to_save:
      code-researcher: "Package structure, key entry points"
      code-reviewer: "Project code conventions, common anti-patterns observed"
      plan-reviewer: "Project layer structure, review checklist priorities"

  limits:
    memory_index: "MEMORY.md ≤200 lines — move detailed findings to topic files"
    topic_files: "One file per topic (e.g., patterns.md, anti-patterns.md)"
    cleanup: "Remove outdated entries when updating"

  tools_required:
    write_new: "Write tool — create new memory files"
    update_existing: "Edit tool — incremental updates to existing files (code-reviewer only currently)"
    read: "Read tool — load memory at startup"

  worktree_agents:
    note: "Agents with `isolation: worktree` (code-reviewer) write memory to worktree copy"
    sync: "SubagentStop hook runs sync-agent-memory.sh to copy files back to main repo"
    reference: "See save-review-checkpoint.sh (IMP-01/IMP-05)"
