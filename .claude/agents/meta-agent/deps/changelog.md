# meta-agent Changelog

## v9.0.0 (2026-02-08)
Research-driven upgrade: 8 improvements from academic patterns (ADAS, Reflexion, Constitutional AI, Tree of Thought, MetaGPT, DSPy):

Architecture:
- RENAMED: CRITIQUE → CONSTITUTE phase (constitutional AI-based quality review)
- EMBEDDED: EVALUATE + REFLECT sub-phases inside DRAFT loop (Reflexion pattern)
- EMBEDDED: ARCHIVE extraction sub-step inside CLOSE (ADAS pattern)
- ADDED: --explore flag for forced Tree of Thought in PLAN phase
- ADDED: 2 new blocking gates (CONSTITUTE_GATE, EVALUATE_GATE)

New deps (6 files):
- deps/phase-contracts.md (P3.1) — 8 typed inter-phase contracts (MetaGPT pattern)
- deps/artifact-constitution.md (P3.3) — 5 quality principles with weighted scoring
- deps/artifact-archive.md (P3.2) — evolving pattern library (ADAS pattern)
- deps/plan-exploration.md (P3.4) — Tree of Thought design exploration
- deps/phases-enhance.md — offloaded detailed ENHANCE phases from main
- deps/troubleshooting.md — offloaded troubleshooting + common_mistakes from main

Enhanced deps (6 files):
- deps/eval-optimizer.md — separated evaluator + adaptive weights per artifact type (DSPy)
- deps/subagents.md — evaluator_agent + reflector_agent + draft_phase_dag
- deps/self-improvement.md — episodic memory structure + retrieval strategy
- deps/blocking-gates.md — recovery strategies per gate + escalation protocol
- deps/context-management.md — budget tracking + enforcement rules
- deps/load-order.md — before-load checks + updated Tier 3 mapping

Size:
- meta-agent.md: 768 → 517 lines (-32.7%), well under agent critical threshold (600)
- Total deps: 18 → 24 files
- Total deps LOC: ~3058 → ~4150 lines

## v8.2.0 (2026-01-18)
Phase enforcement and comprehensive execution:
- ADDED: PHASE_ENFORCEMENT section with mandatory_phases map
- ADDED: stop_conditions for gate failures, user rejection, quality threshold
- ADDED: enforcement_output template for phase transitions
- FIXED: phase_count 10→9 (CHECKPOINT/EVAL-OPTIMIZE are embedded, not separate)
- FIXED: output templates [N/10]→[N/9] across all phases
- OFFLOADED: phases_create to deps/phases-create.md (-60 lines)
- SIZE: 800→767 lines (-4.1%), under critical threshold
- KEY: workflow.key now says "NEVER skip" explicitly

## v8.1.0 (2026-01-18)
Full integration of 4 patterns into phases:
- INTEGRATED into phases: All 4 patterns now have explicit steps in workflow
- WORKFLOW: Added DRAFT phase (9 phases: INIT→EXPLORE→ANALYZE→PLAN→CRITIQUE→DRAFT→APPLY→VERIFY→CLOSE)
- INIT: Added activation layer validation, progress tracking init, load order init
- ALL PHASES: Added checkpoint/progress.json updates
- ALL PHASES: Added Tier 3 load/unload steps
- DRAFT: Added eval-optimizer loop (iterate until 0.85 quality)
- CLOSE: Added auto-chain suggestion
- Fixes: v8.0 had patterns as sections but not integrated into phases

## v8.0.0 (2026-01-18)
Session persistence and quality iteration:
- Added PROGRESS_TRACKING: workspace/, progress.json, --resume for context exhaustion recovery
- Added EVAL_OPTIMIZER: iterative quality loop until 0.85 threshold (not just pass/fail)
- Added 4-TIER_LOADING: explicit load/unload strategy per phase
- Added ACTIVATION_LAYER: false-positive filter, disambiguation, auto-chain
- New commands: list, --resume, abort, cleanup
- Research basis: META-AGENT-UPGRADE-GUIDE.md patterns

## v7.0.0
Major upgrade based on best practices research:
- Added EXTERNAL_VALIDATION: YAML lint, reference validation, structure checks
- Enhanced REFLEXION: trigger→context→mistake→consequence→fix→example format
- Added AUTO-INJECTION: few-shot hints from lessons in INIT phase
- Added DECAY MECHANISM: archive stale lessons, promote recurring to troubleshooting
- Upgraded SUBAGENTS to DAG: dynamic task graph with dependencies
- Added 5 predefined subagent types + dynamic generation
- Added PARALLEL EXECUTION: up to 7 concurrent subagents
- Added CASCADE PREVENTION: single task failure doesn't fail DAG
- Research basis: Reflexion, TDAG Framework, H-MEM, Claude Code patterns

## v6.0.0
Major upgrade based on meta-agent research:
- Added OBSERVABILITY: tracing, metrics, MCP memory logging
- Added STEP_QUALITY: per-phase quality checks (Process Reward Model)
- Added SELF_IMPROVEMENT: lessons_learned, auto-troubleshooting
- Added SUBAGENTS: parallel research for CREATE mode
- Added CONTEXT_MANAGEMENT: hierarchical context (immediate/session/persistent)
- Added DRY_RUN mode: preview changes without applying
- Updated blocking-gates.md with STEP_QUALITY_GATE

## v5.x
- v5.4.0: Added ONBOARD mode for bootstrapping .claude/ in new projects
- v5.3.1: Fixed skill size thresholds (400→600) to match artifact-quality.md
- v5.3: Added CRITIQUE and VERIFY phases for mandatory self-review
- v5.2: Restored blocking_gates, ai_first_principles
- v5.1: Added frontmatter, troubleshooting, common_mistakes, phases_delete/rollback
- v5.0: Beads optional (--track), checkpoints provide control

## v4.0
- Command with checkpoints
