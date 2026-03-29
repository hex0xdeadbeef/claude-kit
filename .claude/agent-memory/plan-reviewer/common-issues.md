---
name: common-issues
description: Recurring mistakes found in plans during review — patterns to watch for
type: feedback
---

# Common Issues Catalog

## [sa1-design-phase] Issues Found (2026-03-29, iteration 1/3)

### Session Recovery Table Regression [MAJOR]

**Pattern:** When a plan adds a new pipeline phase and updates the session recovery heuristic table, it replaces existing columns instead of extending the table.
**Why bad:** The existing Evaluate exists? column covers mid-Phase 3 recovery — the most common real crash scenario. Removing it from the table orphans the quick check command.
**Fix:** Add new phase rows at the TOP (pre-planning section) while keeping existing rows intact. Use separate table groups if needed.

### Handoff Contract Schema Gaps [MINOR]

**Pattern:** A plan adds new fields to a command's handoff_output (e.g., spec_referenced) but forgets to update the corresponding contract in handoff-protocol.md.
**Why bad:** The contract is the authoritative schema. Consumers read the contract to understand what fields to expect. Undocumented fields cause confusion.
**Fix:** For every new field added to handoff_output, add a corresponding update to the contract definition in handoff-protocol.md.

### Template Missing Fields Referenced in Logic [MINOR]

**Pattern:** A command's phase logic references a field (e.g., status: approved) that doesn't appear in the template file it fills out.
**Why bad:** Users filling the template won't know about the required field.
**Fix:** Templates must include all fields that are read by the command that processes them.

### --from-phase Not Updated When New Phase Added [MINOR]

**Pattern:** A plan adds a new phase to the pipeline but doesn't update the --from-phase input argument format string in workflow.md.
**Why bad:** Users can't resume from the new phase via --from-phase.
**Fix:** When adding Phase N, update --from-phase format to include N as a valid value.

### Optional Phase Edge Case in Downstream Validators [MINOR]

**Pattern:** A plan adds an optional phase for M complexity, but the downstream validator (plan-reviewer) doesn't distinguish between "L/XL plan with no spec (problematic)" and "M plan with no spec because user declined (expected)".
**Why bad:** False positive MINOR issues on valid M plans.
**Fix:** Condition must explicitly check complexity — spec check only for L/XL, not M.

## [sa1-design-phase] Issues Found (2026-03-29, iteration 2/3)

### Orchestrator Recovery Step Not Updated for New Phase Artifact [MINOR]

**Pattern:** A plan adds a new phase that produces a new artifact type (e.g., spec file), updates the orchestration-core.md quick-check commands and planner auto-detection, but forgets to update the orchestrator command's own startup recovery step.
**Why bad:** The orchestrator's step 2 check becomes stale — doesn't tell the user "spec exists, designer phase is done." Planner auto-detects the spec regardless, so this is non-blocking.
**Fix:** When adding a new phase artifact, update both the skill-level quick check AND the orchestrator startup recovery step.

### Vague Documentation-Update Bullets [NIT]

**Pattern:** A plan includes a bullet like "update X to include Y as a possible value" where Y is already implicitly valid (e.g., adding a named example to a free-text template field).
**Why bad:** Creates ambiguous implementation work — coder may waste time on a no-op change, or add something that creates inconsistency.
**Fix:** Either specify the concrete YAML/Markdown line to add, or remove the bullet if no structural change is needed.

### Mermaid Diagram Updates Without Concrete Content [MINOR]

**Pattern:** A plan says "update Mermaid diagram to include X node" but doesn't provide the Mermaid syntax. All other content in the same Part has explicit table rows or YAML snippets.
**Why bad:** Inconsistent guidance — coder can implement all other changes precisely but must invent the Mermaid structure without reference.
**Fix:** Provide the concrete Mermaid node and edge additions when specifying diagram updates.
