# Agent Teams

purpose: "Peer-to-peer collaboration for CREATE mode — replaces orchestrator-worker DAG"
source: "https://code.claude.com/docs/en/agent-teams"
principle: "Each teammate has own context (no context pollution), peer-to-peer messaging, fresh context for review"

## Why Agent Teams > Orchestrator-Worker for CREATE

comparison:
  orchestrator_worker:
    pattern: "DAG in subagents.md — sequential spawn/await"
    context: "Shared via aggregation (context pollution risk)"
    review: "Same context sees draft + generation history (sunk-cost bias)"
    flexibility: "Fixed DAG topology — dynamic but predefined"
  agent_teams:
    pattern: "Persistent teammates with peer-to-peer messaging"
    context: "Each teammate has isolated context (no pollution)"
    review: "Fresh context for evaluation (native no-bias)"
    flexibility: "Teammates communicate directly (researcher → designer)"

## Constraints

constraints:
  no_nested_teams: "Teammates CANNOT spawn their own teams"
  one_team_per_session: "Only one team active at a time"
  lead_is_fixed: "Lead agent (meta-agent) fixed for session lifetime"
  max_teammates: 7  # Same as max_concurrent subagents
  max_turns: "All teammates MUST have max_turns set — SEE: subagents.md#max_turns_policy"

## CREATE Mode Team Definition

create_mode_team:
  lead: "meta-agent"
  role: "Coordination, synthesis, quality decisions, phase management"
  activation:
    when: "CREATE mode detected in INIT phase"
    condition: "Subagent system available (not fallback mode)"

  teammates:
    researcher:
      task: "Analyze codebase for patterns related to {topic}"
      model: haiku
      max_turns: 5  # haiku tier — scanning/exploration
      tools: [Read, Glob, Grep, WebSearch]
      output: "code_examples[], patterns_found[], api_conventions"
      maps_to: "codebase_analyzer + context_loader (merged role)"
      phase: "RESEARCH (phase 2)"

    scanner:
      task: "Find existing similar artifacts, check for duplicates"
      model: haiku
      max_turns: 5  # haiku tier — scanning/validation
      tools: [Read, Glob, Grep]
      output: "similar_artifacts[], overlap_score, duplicate_risk"
      maps_to: "artifact_scanner + dependency_analyzer (merged role)"
      phase: "RESEARCH (phase 2)"

    designer:
      task: "Draft artifact structure based on research"
      model: sonnet
      max_turns: 10  # sonnet tier — generation needs room for iteration
      tools: [Read, Write]
      input_from: [researcher, scanner]  # peer-to-peer
      output: "artifact_draft, structure_rationale"
      maps_to: "content generation in DRAFT phase"
      phase: "DRAFT (phase 6)"

  messaging_flow: |
    RESEARCH phase:
      lead ──spawn──→ researcher (parallel)
      lead ──spawn──→ scanner (parallel)
      researcher ──findings──→ lead (aggregation)
      scanner ──findings──→ lead (aggregation)

    DRAFT phase:
      lead ──research_summary──→ designer
      designer ──draft──→ lead
      lead ──eval_results──→ designer (if revision needed)

    Note: researcher → designer direct messaging possible
    if designer needs clarification on patterns

## Phase Integration

phase_integration:
  phase_2_research:
    old: "Spawn 3 subagents (codebase_analyzer, artifact_scanner, context_loader) → await → aggregate"
    new: "Spawn researcher + scanner teammates → peer-to-peer exchange → aggregate at lead"
    benefit: "Teammates persist, can be re-queried in later phases"

  phase_6_draft:
    old: "Lead generates → spawn evaluator_agent → spawn reflector_agent"
    new: "designer teammate generates → evaluator_agent (still separate subagent, opus) → reflector_agent (still separate subagent, opus)"
    note: "Evaluator/reflector remain as subagents (not teammates) — they need fresh context per evaluation"

  unchanged_phases: [INIT, TEMPLATE, PLAN, CONSTITUTE, APPLY, VERIFY, CLOSE]
  reason: "These phases don't benefit from persistent peer context"

## MAR Critics & Reflector: Why NOT Teammates

evaluator_reflector_note:
  pattern: "3 MAR critics + reflector kept as subagents (Task tool), NOT teammates"
  v10: "Single evaluator_agent → 3 persona-driven critics (MAR pattern)"
  critics: [correctness_critic (opus, max_turns:3), clarity_critic (sonnet, max_turns:3), efficiency_critic (haiku, max_turns:3)]
  reflector: "reflector_agent (opus, max_turns:5)"
  reason: |
    1. Fresh context is CRITICAL — critics must not see generation history
    2. One-shot execution per eval iteration — no need for persistent context
    3. Mixed model tiers — opus/sonnet/haiku (different from team default)
    4. Reflexion pattern requires isolation between generator and evaluator
    5. MAR requires independent perspectives — teammates sharing context would defeat purpose
  max_turns_ref: "SEE: subagents.md#max_turns_policy for limits and on_limit_reached behavior"
  ref: "SEE: subagents.md#correctness_critic, eval-optimizer.md#mar_evaluation"

## Fallback

fallback:
  when: "Agent Teams API unavailable or team spawn fails"
  action: "Fall back to DAG orchestrator-worker pattern"
  ref: "SEE: subagents.md#Mode: CREATE for original DAG"
  note: "Produces identical results, just without peer-to-peer messaging"

## Migration Path

migration:
  v9_to_v10:
    - "codebase_analyzer + context_loader → researcher teammate"
    - "artifact_scanner + dependency_analyzer → scanner teammate"
    - "Content generation (lead) → designer teammate"
    - "evaluator_agent → unchanged (subagent)"
    - "reflector_agent → unchanged (subagent)"
  backward_compatible: true
  rollback: "Remove agent-teams.md, revert subagents.md Mode: CREATE section"
