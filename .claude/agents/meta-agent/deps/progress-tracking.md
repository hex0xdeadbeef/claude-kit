# Progress Tracking with Resume

purpose: "Session state persistence for context exhaustion recovery"
research: "Models corrupt Markdown more than JSON — use JSON for state"

## Workspace Structure

base: ".meta-agent/runs/"

run_id_format: "{YYYYMMDD}-{HHMMSS}-{mode}-{target}"
example: "20260118-143052-create-skill-errors"

directory_layout: |
  .meta-agent/runs/
  └── {run_id}/
      ├── progress.json       # State tracking (JSON!)
      ├── checkpoints/
      │   ├── research.json   # After RESEARCH
      │   └── plan.json       # After PLAN
      ├── findings/
      │   └── research.md     # RESEARCH artifacts
      ├── drafts/
      │   ├── v1.md           # First draft
      │   └── v2.md           # After optimization
      └── reviews/
          └── eval-1.json     # Evaluator feedback

## Progress JSON Schema

schema:
  run_id: "string"
  mode: "create | enhance | audit | delete"
  target:
    type: "command | skill | rule | agent"
    name: "string"
  current_phase: "INIT | RESEARCH | PLAN | DRAFT | APPLY | VERIFY | CLOSE"
  phases:
    PHASE_NAME:
      status: "pending | in_progress | done | failed"
      started_at: "ISO timestamp"
      completed_at: "ISO timestamp"
      score: "0.0-1.0 (from eval)"
      artifacts: ["relative paths"]
  checkpoints:
    - phase: "RESEARCH"
      timestamp: "ISO"
      can_resume: true
      state_file: "checkpoints/research.json"
  metrics:
    total_duration_ms: null
    iterations: 2
    quality_score: 0.87

## Resume Flow

trigger: "--resume {run_id}"

steps:
  1_load: "Read progress.json from workspace/{run_id}/"
  2_validate:
    - "File exists"
    - "Not completed (status != closed)"
    - "Has resumable checkpoint"
  3_find_checkpoint: "Latest checkpoint with can_resume=true"
  4_load_artifacts: "Read from checkpoint state_file"
  5_continue: "Resume from next phase"

flow_diagram: |
  Session 1:
    INIT → RESEARCH → PLAN → DRAFT ──► [CONTEXT EXHAUSTED]
                               │
                               ▼
                      progress.json saved

  Session 2:
    /meta-agent --resume {run_id}
                               │
                               ▼
                      Load progress.json
                      Find: PLAN completed
                      Load: checkpoints/plan.json
                               │
                               ▼
                      Continue DRAFT → APPLY → VERIFY → CLOSE

## Commands

list:
  usage: "/meta-agent list"
  action: "List all runs in workspace/"
  output: |
    Active runs:
    - 20260118-143052-create-skill-errors (DRAFT, can resume)

    Completed:
    - 20260117-091200-enhance-command-commit (CLOSED)

resume:
  usage: "/meta-agent --resume {run_id}"
  action: "Resume from last checkpoint"

abort:
  usage: "/meta-agent abort {run_id}"
  action: "Mark run as aborted, archive workspace"

cleanup:
  usage: "/meta-agent cleanup"
  action: "Delete runs older than 7 days"

## Checkpoint Trigger

when: "After each phase completion"

checkpoint_data:
  - phase: "completed phase name"
  - timestamp: "ISO"
  - loaded_context: "summarized findings"
  - partial_results: "draft content if any"
  - next_phase: "what to do next"

## Integration Points

INIT:
  - "Create workspace directory"
  - "Generate run_id"
  - "Write initial progress.json"

after_each_phase:
  - "Update progress.json (phase status = done)"
  - "Write checkpoint/{phase}.json"

CLOSE:
  - "Mark status = completed"
  - "Archive or keep based on config"

on_error:
  - "Update progress.json (phase status = failed)"
  - "Save error context to checkpoint"
  - "Output: run_id for resume"
