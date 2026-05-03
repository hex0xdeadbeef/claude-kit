# code-reviewer Memory

Persistent project-shared memory for the `code-reviewer` agent.
Native loader injects the first 200 lines / 25 KB of this file into the
agent system prompt at SubagentStart. Update via Edit; create new topic
files in this dir for detail beyond the 200-line/25KB head.

## Project Conventions

- All agent artifacts under `.claude/agents/` use YAML-first frontmatter; H2 prose follows.
- Hook stderr format: `[<script-basename>] <LABEL>: <message>` (see `.claude/rules/workflow.md`).
- Tests live at `.claude/scripts/tests/test-*.sh`; one assertion per AC-ID.
- Permission denials in `settings.json` are deny-overrides-allow; do not assume auto-grants override denylists.

## Anti-patterns Catalog

- Modifying `handoff.schema.json` for additive fields without bumping schema version (breaks fixture replay).
- Touching Caveman boundary clauses (verbatim contract — IMP-03 ID hash stability depends on it).
- Hardcoding `/Users/<name>/...` paths in committed config files (kit is shared with other users).
- Editing files outside `.claude/agent-memory/code-reviewer/` from this agent — role is read-only on codebase.

## Patterns Catalog

- Small mechanical fixes (test fixture exports, log cap tweaks) bundle well into a single Part with grep predicates.
- New observability signals (WARN at startup, telemetry records) go to stderr / JSONL — never to stdout (would break hook contracts).
- When a fix has a corresponding pre-authored test, the test is the source of truth — derive the implementation from the test predicates, not vice versa.
