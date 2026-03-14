# Changelog

purpose: "Version history and breaking changes for meta-agent"

## v9.0.0 (2026-02-08)
- CRITIQUE phase renamed to CONSTITUTE (Constitutional AI evaluation)
- Added P1-P5 universal principles + P6-P7 domain-specific
- Added CONSTITUTE_GATE and EVALUATE_GATE (blocking-gates.md)
- Added MAR (Multi-Agent Reflexion) replacing single evaluator
- Added Tree of Thought exploration for PLAN phase
- Added ADAS pattern archive
- Added 4-tier lazy loading strategy
- Added agent teams for CREATE mode

breaking_changes:
  - "CRITIQUE → CONSTITUTE (all phase references)"
  - "Single evaluator → 3 MAR critics (eval-optimizer.md)"
  - "New gates: CONSTITUTE_GATE, EVALUATE_GATE"

## v9.1.0 (planned)
- Added check-plan-drift.sh hook (PLAN_DRIFT gate)
- Note: Hook script exists but not yet registered in settings.json (see ISSUE-03)
