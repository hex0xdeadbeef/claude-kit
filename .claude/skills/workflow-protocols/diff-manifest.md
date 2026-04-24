---
name: diff-manifest
description: "Diff-manifest building algorithm for /workflow orchestrator (diff-based re-plan protocol). Load ONLY on plan_review iteration >= 2 via explicit directive in workflow.md pre_delegation STEP 0.5."
disable-model-invocation: true
---

# IMP-04: Diff-Manifest Building Algorithm

## Step 0.5: Build diff-manifest (MANDATORY for plan_review iteration >= 2)

      STEP 0.5 (IMP-04 — iteration 2+ only): Build diff manifest for planner.
      This step runs ONLY on iteration >= 2. Skip on iter 1.

      1. Read .claude/workflow-state/review-completions.jsonl — find the most recent
         entry where effective_agent_type == "plan-reviewer" in this session_id.
         Extract canonical_issue_ids[] → prior_issues.
         Read regression_ids from the prior phase-2 entry in
         checkpoint.issues_history[] (populated by IMP-03 post_delegation step 5 —
         this is the canonical source for regression signal, NOT review-completions.jsonl
         directly).

      2. Read prior plan at .claude/prompts/{feature}.md. Extract Part IDs and names
         from "## Part N:" headings or "parts:" YAML block. Build:
            prior_parts = [{id: 1, name: "..."}, {id: 2, name: "..."}, ...]

      3. Location → Part mapping (AC-5):
         For each issue in prior_issues:
           location = issue.location  (string, may be "", "Part N:", "Part N: Sym", or "file:line")
           match = re.match(r'^Part\s+(\d+)\s*:', location)
           if match:
             part_id = int(match.group(1))
             mapped[issue.id] = part_id
           else:
             # KD-6 fallback (AC-10): unmappable location → all Parts NEEDS_UPDATE
             mapped[issue.id] = "ALL"

             # Telemetry signal split (CR-002): distinguish two failure modes
             #   - empty string: legitimate cross-cutting concern (informational, reviewer-correct)
             #   - non-empty but no match: KD-8 non-compliance (actionable, reviewer-bug)
             if location == "":
               record_kind = "imp04_cross_cutting_issue"
               reason_txt = "empty location — plan-wide/cross-cutting concern (informational)"
             else:
               record_kind = "imp04_unmapped_location"
               reason_txt = "location does not match 'Part N:' prefix (IMP-03 KD-8 format)"

             log_record = {
               "ts": now_iso(),
               "record_kind": record_kind,
               "feature": "{feature}",
               "iteration": N,
               "issue_id": issue.id,
               "location": location,
               "reason": reason_txt
             }
             append_jsonl(".claude/workflow-state/handoff-validation.jsonl", log_record)

      4. IMP-03 integration (AC-9):
         prior_canonical_ids = {issue.id for issue in prior_issues}
         regression_ids from prior phase-2 issues_history entry (already computed by
         IMP-03 post_delegation step 5 — do NOT recompute here).

         For each prior_part in prior_parts:
           # issues_on_part is drawn from `mapped`, which is built exclusively from
           # prior_issues — every id here is by construction in prior_canonical_ids,
           # so no secondary filter is needed (CR-003).
           active_issues_on_part = [id for id, p in mapped.items() if p == prior_part.id or p == "ALL"]
           regressed_on_part = [id for id in active_issues_on_part if id in regression_ids]

           if regressed_on_part:
             status = "NEEDS_UPDATE"
             reason = f"regression: {','.join(regressed_on_part)}"
           elif active_issues_on_part:
             status = "NEEDS_UPDATE"
             reason = f"active issues: {','.join(active_issues_on_part)}"
           else:
             status = "UNCHANGED"
             reason = "no active issues"

           diff_manifest.append({"part_id": prior_part.id, "name": prior_part.name,
                                 "status": status, "reason": reason})

         If ANY issue has mapped[id] == "ALL" (KD-6 fallback triggered):
           For each entry in diff_manifest where status == "UNCHANGED":
             entry.status = "NEEDS_UPDATE"
             entry.reason = "KD-6 fallback: unmappable location forces all Parts to NEEDS_UPDATE"

      5. Write manifest to .claude/workflow-state/{feature}-diff-manifest.json —
         runtime artifact, regenerated every iter 2+, not checked in.

      6. Inject manifest reference into the /planner re-invocation prompt
         (see Planner Re-invocation Template section below).

## Planner Re-invocation Template (iteration 2+)

      IMP-04 — when orchestrator re-routes to Phase 1 (Planning) after a NEEDS_CHANGES
      verdict, the re-invocation of /planner includes the manifest reference. Concrete
      prompt fragment appended after the standard coder/reviewer feedback block:

        ---
        [IMP-04 — iter {N} diff manifest]
        Prior plan: .claude/prompts/{feature}.md (read for Part bodies)
        Manifest:   .claude/workflow-state/{feature}-diff-manifest.json
        Action:     Execute phase_0.8_prior_review_digest before phase_1_understand.
                    Preserve UNCHANGED Part bodies verbatim.
                    Address NEEDS_UPDATE Parts using issues in manifest.reason.
                    Add NEW Parts via Part-name set-diff (phase_0.8 Step 3).
        ---

      If manifest file missing (first iter 2+ run before STEP 0.5 executed, or KD-6
      triggered with empty mapping) → planner skips phase_0.8, writes plan without
      diff section → plan-reviewer runs full validation (AC-8 path).
