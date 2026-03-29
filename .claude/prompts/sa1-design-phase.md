---
title: "SA-1: Add Design Phase (Phase 0.7) to Workflow Pipeline"
feature: sa1-design-phase
task_type: integration
complexity: XL
status: pending_review
plan_version: "1.2"
created: "2026-03-29"
sequential_thinking_used: true
---

# Plan: SA-1 Design Phase (Brainstorming)

## Context

Claude Kit's workflow pipeline currently starts planning immediately after task analysis (Phase 0.5 → Phase 1). For L/XL tasks, this leads to premature planning without clarifying requirements, exploring alternatives, or getting user approval on the approach. Superpowers v5.0.6 demonstrates that a dedicated design/brainstorming phase before planning significantly reduces plan-review iteration loops.

**Current pipeline:**
```
task-analysis (0.5) → /planner (1) → plan-reviewer (2) → /coder (3) → code-reviewer (4) → completion (5)
```

**Target pipeline:**
```
task-analysis (0.5) → /designer (0.7) → /planner (1) → plan-reviewer (2) → /coder (3) → code-reviewer (4) → completion (5)
```

## Scope

### IN
- New `/designer` command (Phase 0.7) with 5 internal phases
- New `design-rules` skill package (SKILL.md + supporting files)
- New `spec-template.md` template for spec output
- New handoff contract: designer → planner
- Updated routing: S/M skip designer, L/XL go through designer
- Updated orchestration-core.md, workflow.md, checkpoint-protocol.md, handoff-protocol.md
- Updated plan-reviewer.md (spec coverage validation for L/XL)
- Updated planner.md (accept spec as optional input)
- Updated workflow-architecture.md (documentation)

### OUT
- Visual brainstorming server (NR-3 from cross-review — not applicable to backend framework)
- Changes to /coder or code-reviewer (no impact)
- Changes to existing S/M routing (unchanged)

## Dependencies

blocks: []
blocked_by: []

## Architecture Decision

**Analyzed via Sequential Thinking (6 steps)**

**Alternatives considered:**

| # | Approach | Pros | Cons | Why Rejected |
|---|----------|------|------|-------------|
| A | Separate `/designer` command | Clean SRP, first-class checkpoint, standalone spec artifact | More files, new handoff contract | **SELECTED** |
| B | Extend `/planner` with sub-phase | Fewer files, no new handoff | Overloads planner (7+ phases), messy checkpoint, spec not standalone | SRP violation, planner already complex |
| C | Skill-driven (no command) | Lightweight | Breaks Commands vs Agents convention, no clean isolation | Convention violation |
| D | Hybrid (planner Phase 0 with gate) | Better gate than B | Same cons as B with minor improvement | Same fundamental issues as B |

**Selected approach:** Approach A — Separate `/designer` command

**Rationale:**
1. Follows Commands vs Agents design (commands = shared context orchestration)
2. Each command has one responsibility: designer = explore & decide, planner = research & plan
3. First-class Phase 0.7 checkpoint for session recovery
4. Spec as standalone artifact (`.claude/prompts/{feature}-spec.md`) — plan-reviewer can validate spec coverage
5. Matches Superpowers' separation (brainstorming ≠ writing-plans)

**Trade-offs accepted:**
- More files (~5 new + ~6 updated) — acceptable for strategic feature
- New handoff contract — follows existing 4-contract pattern
- Context switch designer→planner — mitigated by structured handoff payload

## Parts

### Part 1: spec-template.md — Spec Output Template
**File:** `.claude/templates/spec-template.md`
**Action:** CREATE
**Description:** Template for designer output spec file. Defines structure that plan-reviewer will validate and planner will consume.

```markdown
meta:
  type: "spec-template"
  purpose: "Design spec template — output of /designer, input to /planner and validated by plan-reviewer"
  usage: "Fill placeholders → save as {feature}-spec.md → pass to /planner"

spec:
  title: "{Feature Name}"
  status: "pending_approval"  # Set by /designer — do not manually edit. Values: pending_approval | approved

  context:
    current_state: "{What exists now}"
    motivation: "{Why this change is needed}"
    business_value: "{Expected outcome}"

  requirements:
    in_scope:
      - "{Requirement 1}"
      - "{Requirement 2}"
    out_of_scope:
      - item: "{What is excluded}"
        reason: "{Why excluded}"
    constraints:
      - "{Non-negotiable constraint 1}"
      - "{Non-negotiable constraint 2}"

  approach:
    selected:
      name: "{Approach name}"
      description: "{How it works}"
      rationale: "{Why this approach}"
    alternatives:
      - option: "{Alternative 1}"
        pros: ["{pro1}", "{pro2}"]
        cons: ["{con1}", "{con2}"]
        rejected_because: "{Why not chosen}"
      - option: "{Alternative 2}"
        pros: ["{pro1}"]
        cons: ["{con1}"]
        rejected_because: "{Why not chosen}"

  key_decisions:
    - decision: "{Decision 1}"
      rationale: "{Why}"
      impact: "{What this affects}"
    - decision: "{Decision 2}"
      rationale: "{Why}"
      impact: "{What this affects}"

  risks:
    - risk: "{Risk description}"
      severity: "HIGH|MEDIUM|LOW"
      mitigation: "{How to mitigate}"
    - risk: "{Risk description}"
      severity: "HIGH|MEDIUM|LOW"
      mitigation: "{How to mitigate}"

  acceptance_criteria:
    - "{Criterion 1 — verifiable}"
    - "{Criterion 2 — verifiable}"

  notes: "{Additional context, edge cases, open questions resolved}"
```

---

### Part 2: designer.md — Designer Command
**File:** `.claude/commands/designer.md`
**Action:** CREATE
**Description:** Core command for Phase 0.7. Explores context, clarifies requirements with user, proposes 2-3 approaches, writes spec, gets user approval.

```markdown
---
name: designer
description: Explores requirements and designs approach before planning. Produces approved spec for /planner.
model: opus
effort: high
---

# DESIGNER

role:
  identity: "Solution Architect"
  owns: "Requirements clarification, approach exploration, design spec creation"
  does_not_own: "Implementation planning (→ /planner), code writing (→ /coder), plan review (→ plan-reviewer)"
  output_contract: "File .claude/prompts/{feature}-spec.md + handoff_output payload for /planner"
  success_criteria: "Spec approved by user, all required sections present, handoff formed"

## TRIGGERS
triggers:
  - if: "Task complexity is L or XL"
    then: "ALWAYS run /designer before /planner"
  - if: "Task complexity is S or M"
    then: "SKIP /designer, go directly to /planner"
  - if: "Task type is new_feature or integration AND complexity is M"
    then: "RECOMMEND /designer (orchestrator asks user)"

## INPUT
input:
  arguments:
    - name: task
      required: true
      format: "Task description text"
      example: "Add design phase to workflow pipeline"

    - name: --from-spec
      required: false
      format: "path"
      description: "Resume from existing spec file (skip Phase 1-2)"

  examples:
    - cmd: "/designer Add caching layer for API responses"
      description: "Design caching approach before planning"
    - cmd: "/designer --from-spec .claude/prompts/caching-spec.md"
      description: "Resume from existing spec"

## OUTPUT
output:
  file: ".claude/prompts/{feature-name}-spec.md"
  format: |
    Design spec created: .claude/prompts/{feature-name}-spec.md

    Summary:
    - Approach: {selected approach name}
    - Alternatives considered: {N}
    - Key decisions: {N}
    - Risks identified: {N}

    Checklist:
    - [x] Context explored
    - [x] Requirements clarified with user
    - [x] Approaches analyzed
    - [x] Spec written
    - [x] User approved

  handoff_output:
    to: "/planner"
    spec_artifact: ".claude/prompts/{feature-name}-spec.md"
    metadata:
      task_type: "{type}"
      complexity: "{S|M|L|XL}"
      approaches_considered: N
      sequential_thinking_used: true|false
    key_decisions:
      - "{decision + rationale}"
    known_risks:
      - "{risk + severity}"
    acceptance_criteria_count: N

## STARTUP
startup:
  steps:
    - step: 0
      action: "Load design-rules skill"
      file: ".claude/skills/design-rules/SKILL.md"

    - step: 1
      action: "Check for existing spec (--from-spec or .claude/prompts/{feature}-spec.md)"
      recovery: "If spec exists with status: approved → skip to handoff formation"

## PIPELINE
pipeline:
  flow: "EXPLORE → CLARIFY → PROPOSE → SPEC → GATE"

  phases:
    - phase: 1
      name: "EXPLORE CONTEXT"
      purpose: "Understand current state and constraints"
      actions:
        - "Read task description from orchestrator"
        - "Quick codebase scan (Grep/Glob) for affected areas"
        - "Identify existing patterns, interfaces, constraints"
        - "Check PROJECT-KNOWLEDGE.md for project-specific context"
      budget:
        reads: 10
        tool_calls: 15
      output: "Context summary (current state, affected areas, constraints)"

    - phase: 2
      name: "CLARIFY REQUIREMENTS"
      purpose: "Ensure shared understanding with user before designing"
      actions:
        - "Formulate clarifying questions based on context"
        - "Ask questions ONE AT A TIME (not batch)"
        - "Define scope IN/OUT with user confirmation"
        - "Identify priority if multiple sub-features"
      gate: "Do NOT proceed without user answers to critical questions"
      skip_when: "Task description is unambiguous AND scope is clear"
      output: "Clarified requirements (scope IN/OUT, constraints, priorities)"

    - phase: 3
      name: "PROPOSE APPROACHES"
      purpose: "Generate and compare alternative solutions"
      actions:
        - "Generate 2-3 alternative approaches"
        - "For each: description, pros, cons, estimated complexity"
        - "Use Sequential Thinking if complexity L/XL or alternatives >= 3"
        - "Recommend one approach with clear rationale"
      output: "Approaches table with recommendation"

    - phase: 4
      name: "WRITE SPEC"
      purpose: "Document the design decision as a spec artifact"
      actions:
        - "Write spec to .claude/prompts/{feature}-spec.md using spec-template"
        - "Include: context, requirements, selected approach, alternatives, key decisions, risks, acceptance criteria"
        - "Set status: pending_approval"
      output: "Spec file created"

    - phase: 5
      name: "USER APPROVAL GATE"
      purpose: "Get explicit user confirmation before proceeding to planning"
      actions:
        - "Present spec summary to user"
        - "Ask: 'Approve this design to proceed to planning?'"
        - "If approved → set status: approved, form handoff"
        - "If rejected → iterate (back to Phase 2 or 3 based on feedback)"
      gate: "HARD GATE — do NOT form handoff without user approval"
      output: "Approved spec + handoff payload for /planner"

## RULES
rules:
  - id: RULE_1
    name: "No Planning"
    rule: "NEVER write implementation plans or break down into Parts — that is /planner's job"
  - id: RULE_2
    name: "Questions First"
    rule: "ALWAYS clarify ambiguous requirements before proposing approaches"
  - id: RULE_3
    name: "Minimum Alternatives"
    rule: "ALWAYS propose at least 2 approaches (even if one is clearly better)"
  - id: RULE_4
    name: "User Gate"
    rule: "NEVER skip user approval — the spec MUST be approved before handoff"
  - id: RULE_5
    name: "No Code"
    rule: "NEVER write implementation code — only high-level approach descriptions"

## MCP TOOLS
mcp_tools:
  sequential_thinking:
    when: "Phase 3 (PROPOSE APPROACHES) for L/XL complexity or >= 3 alternatives"
    purpose: "Structured trade-off analysis"
  context7:
    when: "Phase 1 (EXPLORE) if external library/API involved"
    purpose: "Current documentation lookup"

## ERROR HANDLING
error_handling:
  - error: "User doesn't respond to questions"
    action: "Wait — do NOT assume answers"
  - error: "User rejects all approaches"
    action: "Ask for constraints that weren't captured, re-explore"
  - error: "Spec file already exists with status: approved"
    action: "Show existing spec, ask user: reuse or redesign?"
```

---

### Part 3: design-rules Skill Package
**Files:**
- `.claude/skills/design-rules/SKILL.md` (CREATE)
- `.claude/skills/design-rules/spec-quality.md` (CREATE)
- `.claude/skills/design-rules/design-checklist.md` (CREATE)

**Action:** CREATE (3 files)
**Description:** Skill package loaded by /designer at startup. Contains spec quality guidelines and self-verification checklist.

**SKILL.md:**
```markdown
---
name: design-rules
description: Design phase rules for /designer command. Load at /designer startup (step 0). Covers spec quality, design checklist, approach evaluation criteria.
disable-model-invocation: true
---

# Design Rules

## Purpose
Guidelines for the /designer command to produce high-quality design specs that reduce plan-review iterations.

## Instructions

### Step 1: Load at /designer startup
Read this SKILL.md for overview. Supporting files loaded on-demand per phase.

### Step 2: Use phase-driven loading
- Phase 3 (PROPOSE) → read [Spec Quality](spec-quality.md) for approach evaluation criteria
- Phase 4 (WRITE SPEC) → read [Design Checklist](design-checklist.md) for self-verification
- Phase 5 (USER GATE) → verify checklist before presenting to user

## Spec Quality Criteria

| Criterion | Required | Check |
|-----------|----------|-------|
| Context describes current state | Yes | Not just "add X" but "currently Y exists, need X because Z" |
| Scope has IN and OUT | Yes | OUT items have explicit reasons |
| At least 2 approaches compared | Yes | With pros/cons for each |
| Selected approach has rationale | Yes | References constraints from requirements |
| Key decisions are numbered | Yes | Each has rationale and impact |
| Risks have severity and mitigation | Yes | HIGH risks must have concrete mitigation |
| Acceptance criteria are verifiable | Yes | Each can be checked as pass/fail |

## Anti-Patterns

| Anti-Pattern | Why Bad | Fix |
|---|---|---|
| "The obvious approach is..." | Skips exploration, may miss better options | Always compare at least 2 |
| Spec without OUT scope | Scope creep during planning | Explicitly list what's excluded |
| Vague acceptance criteria ("works well") | Can't verify | Make criteria concrete and testable |
| No risks identified | Every design has risks | Identify at least 1 per approach |
| Copying task description as context | No analysis | Describe current state, not just goal |

## Common Issues

### Designer skips CLARIFY phase
**Cause:** Task seems clear.
**Fix:** Even "clear" tasks benefit from scope IN/OUT confirmation. At minimum, confirm scope.

### User rejects all approaches
**Cause:** Missing constraint not captured.
**Fix:** Ask: "What constraint am I missing?" — don't generate more approaches without new information.

## References
- [Spec Quality](spec-quality.md) — detailed quality criteria, approach evaluation matrix
- [Design Checklist](design-checklist.md) — phase-by-phase self-verification
```

**spec-quality.md:**
```markdown
# Spec Quality

## Approach Evaluation Matrix

When comparing approaches, evaluate each against:

| Criterion | Weight | How to Assess |
|-----------|--------|---------------|
| Feasibility | HIGH | Can it be implemented with current codebase/deps? |
| Complexity | HIGH | How many Parts/layers will /planner need? |
| Maintainability | MEDIUM | Will future changes be easy? |
| Risk | MEDIUM | What can go wrong? How bad? |
| Performance | LOW (unless explicit) | Only if task mentions performance |

## Spec Completeness Checklist

Before writing spec to file:
- [ ] Context section describes CURRENT state (not just desired state)
- [ ] Requirements have concrete IN/OUT scope
- [ ] At least 2 approaches with honest pros/cons
- [ ] Selected approach references specific constraints
- [ ] Key decisions explain WHY, not just WHAT
- [ ] Risks have severity (HIGH/MEDIUM/LOW) and mitigation strategy
- [ ] Acceptance criteria are pass/fail verifiable
- [ ] No implementation details (that's /planner's job)

## Quality Gates

| Gate | Trigger | Action |
|------|---------|--------|
| Spec < 30 lines | Too brief | Add missing sections |
| 0 risks identified | Unrealistic | Find at least 1 risk per approach |
| Acceptance criteria use vague words ("good", "proper", "clean") | Unverifiable | Rewrite as concrete checks |
| Selected approach has no rejected alternatives | No exploration | Add at least 1 alternative |
```

**design-checklist.md:**
```markdown
# Design Checklist

Self-verification at each /designer phase.

## Phase 1: EXPLORE CONTEXT
- [ ] Codebase areas identified (files, packages, patterns)
- [ ] Existing constraints documented
- [ ] PROJECT-KNOWLEDGE.md checked (if exists)

## Phase 2: CLARIFY REQUIREMENTS
- [ ] Critical questions asked (scope, priorities, constraints)
- [ ] User responded to all critical questions
- [ ] Scope IN/OUT defined
- [ ] Scope confirmed by user

## Phase 3: PROPOSE APPROACHES
- [ ] At least 2 approaches generated
- [ ] Each approach has pros AND cons
- [ ] Sequential Thinking used (if L/XL or >= 3 alternatives)
- [ ] Recommendation includes clear rationale
- [ ] Recommendation references specific constraints

## Phase 4: WRITE SPEC
- [ ] All spec-template sections filled
- [ ] Context describes current state, not just goal
- [ ] Key decisions have rationale and impact
- [ ] Risks have severity and mitigation
- [ ] Acceptance criteria are verifiable
- [ ] No implementation details (Parts, code examples)

## Phase 5: USER APPROVAL GATE
- [ ] Spec summary presented to user
- [ ] User explicitly approved (not assumed)
- [ ] Status set to "approved"
- [ ] Handoff payload formed with all required fields
```

---

### Part 4: workflow.md Updates — New Phase 0.7
**File:** `.claude/commands/workflow.md`
**Action:** UPDATE
**Description:** Add Phase 0.7 to startup sequence, pipeline flow, and delegation protocol.

**Changes:**

1. **startup.steps** — Add step 0.2 after task analysis:
```yaml
    - step: 0.2
      action: "Route through /designer (L/XL only)"
      condition: "complexity L or XL"
      skip_when: "S/M complexity — designer adds overhead for simple tasks"
      optional_when: "M complexity AND task_type is new_feature or integration — ask user"
      note: "For M tasks of type new_feature/integration, ask user: 'This task may benefit from a design phase. Run /designer first?'"
```

2. **startup.steps[1]** — Update TodoWrite items to include Phase 0.7:
```yaml
    items:
      - "Phase 0: Get Task (completed)"
      - "Phase 0.5: Task Analysis (completed)"
      - "Phase 0.7: Design → /designer (pending — or skip if S/M)"
      - "Phase 1: Planning (pending)"
      - "Phase 2: Plan Review → plan-reviewer agent (pending — or skip if S)"
      - "Phase 3: Implementation (pending)"
      - "Phase 4: Code Review → code-reviewer agent (pending)"
      - "Phase 5: Completion — commit + metrics (pending)"
```

3. **pipeline.flow** — Update flow string:
```yaml
  flow: "task-analysis → /designer* → /planner [→ code-researcher*] → plan-reviewer (agent) → /coder [→ code-researcher*] → code-reviewer (agent)"
  flow_note: "* /designer is Phase 0.7, activated for L/XL tasks only. S/M skip to /planner. code-researcher is optional tool-assist."
```

4. **delegation_protocol** — Add designer_delegation section (before plan_review_delegation):
```yaml
  designer_delegation:
    command: "/designer"
    when: "Phase 0.7 — after task analysis, before /planner"
    skip_when: "S/M complexity (direct to /planner)"
    optional_when: "M complexity AND task_type in [new_feature, integration] — ask user"
    context_to_pass:
      - "Task description"
      - "Complexity: L/XL"
      - "Task type: {type}"
    returns: "Approved spec file + handoff payload for /planner"
    post_delegation: |
      After /designer completion:
      1. Verify spec file exists at .claude/prompts/{feature}-spec.md
      2. Verify status: approved in spec frontmatter
      3. Write checkpoint: phase_completed=0.7, phase_name="design"
      4. Pass designer handoff to /planner as additional input
```

5. **input.arguments --from-phase** — Update format to accept 0.7:
```yaml
    - name: --from-phase
      required: false
      format: "0.7|1-4"
      description: "Resume from specified phase (0.7=Design, 1=Planning, 2=Plan Review, 3=Implementation, 4=Code Review)"
```

6. **frontmatter description** — Update to reflect new phase:
```yaml
description: "Full development cycle: task-analysis → [/designer (L/XL)] → planner → plan-review (agent) → coder → code-review (agent)"
```

7. **pipeline.evaluate_note** — Update RETURN routing to note designer phase:
```yaml
    On RETURN: orchestrator increments plan_review counter, writes checkpoint.
    If spec exists (L/XL path): re-run /planner with coder feedback + original spec.
    If no spec (S/M path): re-run /planner with coder feedback only.
```

8. **output.phases** — Add Design phase (before Planning):
```yaml
  phases:
    - phase: Design
      produces: Approved design spec
      location: ".claude/prompts/{feature}-spec.md"
      note: "L/XL only. S/M skip to Planning."

    - phase: Planning
      produces: Implementation plan
      location: ".claude/prompts/{feature}.md"
```
Keep remaining phases (Plan Review, Implementation, Code Review, Completion) unchanged.

---

### Part 5: orchestration-core.md Updates — Pipeline Phases
**File:** `.claude/skills/workflow-protocols/orchestration-core.md`
**Action:** UPDATE
**Description:** Add Phase 0.7 to pipeline diagram, phase descriptions, and routing table.

**Changes:**

1. **Pipeline diagram** — Add designer between task-analysis and planner:
```
task-analysis → /designer* → /planner → plan-reviewer (agent) → /coder → code-reviewer (agent) → completion
     ↓              ↓             ↓              ↓                  ↓              ↓                    ↓
  Classify    Design(L/XL)     Plan       Validation             Code         Review              Commit+Metrics
  S/M → skip ↗     ↓ REJECT         ↓ FAIL         ↓ FAIL
  M(new/integ) → optional ↗
                  ← user ←        ← back ←       ← back ←
                                  (max 3x)       (max 3x)
```

2. **Add Phase 0.7 description** (between Phase 0.5 and Phase 1):
```
**Phase 0.7 — Design (L/XL only):** Execute /designer. Output: `.claude/prompts/{feature}-spec.md`. User approval gate required. SKIP for S/M complexity.
- If user rejects design → iterate within /designer (not a pipeline loop — internal to designer)
- Checkpoint: `phase_completed: 0.7, phase_name: "design"`
```

3. **Phase 1 description** — Update to reference optional spec input:
```
**Phase 1 — Planning:** Execute /planner. If spec exists → planner references spec. Output: `.claude/prompts/{feature}.md`
```

4. **Session Recovery heuristic table** — Add pre-planning recovery rows ABOVE existing table (do NOT replace existing rows):

**Pre-planning recovery (new rows — add above existing table):**

| Spec exists? | Plan exists? | Resume from |
|---|---|---|
| No | No | Phase 0.7: Design (if L/XL) or Phase 1: Planning (S/M) |
| Yes (approved) | No | Phase 1: Planning (spec done, skip design) |

**Post-planning recovery (existing rows — PRESERVE AS-IS):**

The existing table with columns `Plan exists? | Evaluate exists? | Code changes? | Tests pass? | Resume from` remains unchanged. The `Evaluate exists?` column is load-bearing for Phase 3 crash recovery and MUST NOT be removed.

5. **Session Recovery quick check commands** — Add spec check:
```
ls .claude/prompts/*-spec.md                  # Spec?
```
Add this line above the existing `ls .claude/prompts/` check.

---

### Part 6: handoff-protocol.md Updates — New Contract
**File:** `.claude/skills/workflow-protocols/handoff-protocol.md`
**Action:** UPDATE
**Description:** Add designer_to_planner handoff contract.

**Add before `planner_to_plan_review` contract:**
```yaml
    designer_to_planner:
      producer: "/designer"
      consumer: "/planner"
      payload:
        spec_artifact: ".claude/prompts/{feature}-spec.md"
        metadata:
          task_type: "{new_feature|integration|...}"
          complexity: "{L|XL}"
          approaches_considered: N
          sequential_thinking_used: true|false
        key_decisions:
          - "Key decision description + rationale"
        known_risks:
          - "Risk description + severity"
        acceptance_criteria_count: N
```

**Also update `planner_to_plan_review` contract** — add spec fields to metadata:
```yaml
    planner_to_plan_review:
      # ... existing fields unchanged ...
      payload:
        # ... existing fields unchanged ...
        metadata:
          # ... existing fields ...
          spec_referenced: true|false
          spec_artifact: ".claude/prompts/{feature}-spec.md"  # if applicable, null otherwise
```

**Also update narrative_casting template_fields** to include designer as possible context_source:

```yaml
  narrative_casting:
    template_fields:
      - field: "context_source"
        value: "{agent_name}"
        description: "Which agent produced the artifact (planner | designer | coder)"
```

---

### Part 7: checkpoint-protocol.md Updates — Phase 0.7
**File:** `.claude/skills/workflow-protocols/checkpoint-protocol.md`
**Action:** UPDATE
**Description:** Add phase 0.7 to allowed values and update example.

**Changes:**

1. **format.phase_completed** — Add 0.7:
```yaml
    phase_completed: "0.5|0.7|1|2|3|4|5"
```

2. **format.phase_name** — Add design:
```yaml
    phase_name: "task-analysis|design|planning|plan-review|implementation|code-review|completion"
```

3. **session_recovery quick check** — Add spec check:
```
ls .claude/prompts/*-spec.md                  # Spec?
```

---

### Part 8: plan-reviewer.md Updates — Spec Coverage Validation
**File:** `.claude/agents/plan-reviewer.md`
**Action:** UPDATE
**Description:** Add spec coverage check for L/XL plans that should reference a design spec.

**Changes:**

1. **Process step 2 (READ PLAN)** — Add spec reference check:
```markdown
   - If complexity L/XL: check for referenced spec file (`.claude/prompts/{feature}-spec.md`)
   - If spec exists: verify plan covers all acceptance criteria from spec
   - If complexity is L or XL AND spec file not found: add MINOR issue (not BLOCKER — spec is recommended, planner may have good reasons)
   - Skip spec check entirely for S and M complexity (M tasks may legitimately have no spec if user declined optional designer)
```

2. **Process step 4 (VALIDATE COMPLETENESS)** — Add spec alignment check:
```markdown
   - Spec alignment (if spec exists):
     - Plan approach matches spec selected approach
     - Plan scope covers spec requirements (IN scope)
     - Plan acceptance criteria include spec acceptance criteria
```

3. **Output format** — Add spec alignment to architecture compliance table:
```markdown
| Spec alignment | PASS/FAIL/N/A |
```

---

### Part 9: planner.md Updates — Accept Spec Input
**File:** `.claude/commands/planner.md`
**Action:** UPDATE
**Description:** Accept designer spec as optional input, reference it during planning.

**Changes:**

1. **input.arguments** — Add spec argument:
```yaml
    - name: --spec
      required: false
      format: "path to spec file"
      description: "Design spec from /designer (auto-passed by workflow for L/XL)"
```

2. **startup** — Add spec loading step:
```yaml
    - step: 0.5
      action: "Load spec if provided"
      check: "If --spec provided OR .claude/prompts/{feature}-spec.md exists"
      action_if_found: "Read spec → use as input for Phase 1 (Understand) and Phase 4 (Design)"
      action_if_not_found: "Proceed without spec (standard flow)"
```

3. **Phase 1 (Understand)** — Reference spec:
```yaml
      note: "If spec provided → skip clarifying questions already answered in spec. Focus on implementation-specific questions only."
```

4. **Phase 4 (Design)** — Reference spec:
```yaml
      note: "If spec provided → use spec's selected approach and key decisions as starting point. Designer already explored alternatives — planner refines into Parts."
```

5. **handoff_output** — Add spec reference:
```yaml
    spec_referenced: true|false
    spec_artifact: ".claude/prompts/{feature}-spec.md"  # if applicable
```

---

### Part 10: workflow-architecture.md Updates — Documentation
**File:** `.claude/docs/workflow-architecture.md`
**Action:** UPDATE
**Description:** Add /designer to artifact inventory, pipeline phases, and interaction diagrams.

**Changes:**

1. **Commands table** — Add designer row:
```markdown
| designer | `.claude/commands/designer.md` | Design exploration + spec creation | opus |
```

2. **Skills table** — Add design-rules row:
```markdown
| design-rules | `.claude/skills/design-rules/` | 3 | /designer (startup) |
```

3. **Templates table** — Add spec-template row:
```markdown
| spec-template.md | `.claude/templates/spec-template.md` | Template for design specs |
```

4. **Pipeline phases table** — Add Phase 0.7 row:
```markdown
| 0.7 | Design | /designer | Task + context | `.claude/prompts/{feature}-spec.md` |
```

5. **Routing table** — Update L/XL rows to include designer:
```markdown
| L | 4-6 | 3+ | /designer → standard | RECOMMENDED | Standard |
| XL | 7+ | 4+ | /designer → full | REQUIRED | Standard |
```

6. **Mermaid diagrams** — Update Core Pipeline Flow to include designer node.

---

### Part 11: Integration Verification
**Action:** VERIFY
**Description:** Verify all cross-references are consistent.

**Checks:**
- [ ] workflow.md references Phase 0.7 consistently
- [ ] orchestration-core.md pipeline matches workflow.md
- [ ] handoff-protocol.md has 5 contracts (was 4 + 1 tool)
- [ ] checkpoint-protocol.md allows phase_completed: 0.7
- [ ] plan-reviewer.md spec check references correct file pattern
- [ ] planner.md --spec flag matches designer output path
- [ ] workflow-architecture.md tables include all new artifacts
- [ ] check-uncommitted.sh handles phase 0.7 as "in progress" (not >= 5)
- [ ] README.md pipeline string, phases table, and --from-phase match workflow.md
- [ ] No broken cross-references between files

### Part 12: check-uncommitted.sh Fix — Float-Safe Phase Comparison
**File:** `.claude/scripts/check-uncommitted.sh`
**Action:** UPDATE
**Description:** Fix Stop hook to handle decimal phase numbers (0.7). Current `sed 's/[^0-9]//g'` strips decimal from `0.7` → `07` = integer 7, making `7 < 5` false — the hook thinks the workflow is complete at Phase 0.7 and fails to block uncommitted changes.

**Changes:**

Replace line 29 (phase extraction + comparison):
```bash
# BEFORE (broken for Phase 0.7):
PHASE=$(grep 'phase_completed:' "$CHECKPOINT" 2>/dev/null | sed 's/[^0-9]//g' || echo "0")
PHASE="${PHASE:-0}"
if [[ "$PHASE" -lt 5 ]]; then
```

```bash
# AFTER (float-safe via awk):
PHASE_RAW=$(grep 'phase_completed:' "$CHECKPOINT" 2>/dev/null | sed 's/.*phase_completed:[[:space:]]*//' | tr -d '"'"'" || echo "0")
PHASE_RAW="${PHASE_RAW:-0}"
IS_COMPLETE=$(awk -v p="$PHASE_RAW" 'BEGIN { print (p+0 >= 5) ? "1" : "0" }')
if [[ "$IS_COMPLETE" == "0" ]]; then
```

**Why:** `phase_completed: "0.7"` must be recognized as "workflow in progress" (< 5), not as "complete" (>= 5). The awk approach handles both integer (0, 1, 2, 3, 4, 5) and decimal (0.5, 0.7) phase values correctly.

---

### Part 13: README.md Updates — User-Facing Documentation
**File:** `README.md`
**Action:** UPDATE
**Description:** Update user-facing pipeline description, `--from-phase` examples, and phases table to include Phase 0.7 Designer.

**Changes:**

1. **Line 68 — Pipeline flow string:**

```markdown
**Pipeline:** `task-analysis` → `designer*` → `planner` → `plan-review` → `coder` → `code-review`
```

Add footnote: `* designer runs for L/XL tasks only. S/M skip to planner.`

2. **Line 73 — `--from-phase` example:**

```bash
/workflow --from-phase 0.7                         # resume from design phase
```

3. **Lines 89-96 — Phases table** — Insert Designer row after Task Analysis:

```markdown
| # | Phase | Description |
|---|-------|-------------|
| 1 | Task Analysis | Complexity classification (S/M/L/XL) and route selection |
| 1.5 | Design | Requirements exploration + approach selection *(L/XL only, optional for M new_feature/integration)* |
| 2 | Planning | Codebase research, implementation plan creation |
| 3 | Plan Review | Plan validation against architecture *(skipped for S-complexity)* |
| 4 | Implementation | Code writing strictly per approved plan, running tests |
| 5 | Code Review | Change review: architecture, security, quality |
| 6 | Completion | Git commit + lessons learned *(if non-trivial)* |
```

---

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| `.claude/templates/spec-template.md` | CREATE | Spec output template |
| `.claude/commands/designer.md` | CREATE | Designer command (Phase 0.7) |
| `.claude/skills/design-rules/SKILL.md` | CREATE | Design rules skill |
| `.claude/skills/design-rules/spec-quality.md` | CREATE | Spec quality criteria |
| `.claude/skills/design-rules/design-checklist.md` | CREATE | Phase-by-phase checklist |
| `.claude/commands/workflow.md` | UPDATE | Add Phase 0.7 routing + delegation |
| `.claude/skills/workflow-protocols/orchestration-core.md` | UPDATE | Add Phase 0.7 to pipeline |
| `.claude/skills/workflow-protocols/handoff-protocol.md` | UPDATE | Add designer→planner contract |
| `.claude/skills/workflow-protocols/checkpoint-protocol.md` | UPDATE | Add phase 0.7 value |
| `.claude/agents/plan-reviewer.md` | UPDATE | Add spec coverage validation |
| `.claude/commands/planner.md` | UPDATE | Accept spec as input |
| `.claude/docs/workflow-architecture.md` | UPDATE | Document new phase |
| `.claude/scripts/check-uncommitted.sh` | UPDATE | Float-safe phase comparison for 0.7 |
| `README.md` | UPDATE | User-facing pipeline docs + phases table |

**Total: 5 CREATE + 9 UPDATE = 14 files**

## Acceptance Criteria

### Functional
- [ ] `/designer` command produces spec file at `.claude/prompts/{feature}-spec.md`
- [ ] Spec includes all template sections (context, requirements, approaches, decisions, risks, acceptance criteria)
- [ ] User approval gate works (spec not marked approved without user confirmation)
- [ ] `/planner` accepts `--spec` flag and references spec during planning
- [ ] plan-reviewer checks spec coverage for L/XL plans
- [ ] S/M tasks skip designer (no regression)

### Technical
- [ ] All 14 files created/updated without YAML syntax errors
- [ ] Handoff protocol has 5 phase contracts + 1 tool contract
- [ ] Checkpoint protocol allows phase_completed: 0.7
- [ ] Cross-references between files are consistent
- [ ] Stop hook (`check-uncommitted.sh`) correctly identifies Phase 0.7 as "in progress"
- [ ] README.md phases table and pipeline string match workflow.md
- [ ] No broken Mermaid diagram syntax
- [ ] workflow-architecture.md reflects all changes

### Architecture
- [ ] Designer follows Commands vs Agents convention (command, not agent)
- [ ] Designer uses opus model (consistent with planning model routing)
- [ ] Handoff contract follows existing pattern structure
- [ ] Skip logic is at orchestrator level (not inside designer)

## Testing Plan

Configuration framework — no Go code tests required.

**Manual verification:**
1. Read each created file and verify YAML structure
2. Verify cross-references between updated files
3. Walk through pipeline flow mentally: S task (skips designer) → M task (optional) → L/XL task (mandatory)
4. Verify checkpoint recovery: crash at Phase 0.7 → resume should work

## Handoff Notes

- Sequential Thinking analysis (6 steps) available in conversation context
- Cross-review document at `.claude/docs/cross-review-superpowers.md` section SP-1 has Superpowers brainstorming details
- Key adaptation from Superpowers: questions one-at-a-time pattern, HARD-GATE before planning, anti-pattern detection
- Simplified vs Superpowers: no visual brainstorming server, no WebSocket, no 9-step process (condensed to 5 phases)
