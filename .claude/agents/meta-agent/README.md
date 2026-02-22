# Meta-Agent v9.0

Meta-agent for managing Claude Code artifacts (commands, skills, rules, agents).

## What's New in v9.0

Based on meta-agent research (best practices 2025-2026):

- **CONSTITUTE**: Constitutional AI evaluation (P1-P5 principles, replaces CRITIQUE)
- **SEPARATED EVALUATION**: Evaluator + Reflector subagents (Reflexion pattern)
- **TREE OF THOUGHT**: Design space exploration in PLAN phase
- **ADAS ARCHIVE**: Self-improving pattern library from successful operations
- **PHASE CONTRACTS**: Typed inter-phase communication (MetaGPT pattern)
- **AGENT TEAMS**: Peer-to-peer teammates for CREATE mode (v10.0)
- **MODEL ROUTING**: haiku/sonnet/opus per task complexity
- **HOOKS**: Deterministic validation gates (size, YAML, references, phases)
- **OBSERVABILITY**: Tracing, metrics, MCP memory logging per run
- **STEP QUALITY**: Per-phase quality checks (Process Reward Model)
- **SELF-IMPROVEMENT**: Lessons + reflections via episodic memory
- **CONTEXT MANAGEMENT**: 4-tier lazy loading with budget tracking
- **DRY-RUN MODE**: Preview changes without applying

## Structure

```
.claude/
├── commands/
│   └── meta-agent.md              # Main command (invoke with /meta-agent)
│
├── agents/meta-agent/
│   ├── README.md                  # This file
│   ├── deps/                      # Supporting files (24 files, loaded on demand)
│   │   ├── artifact-quality.md    # Quality criteria & external validation
│   │   ├── artifact-analyst.md    # Analysis patterns (CREATE/ENHANCE)
│   │   ├── artifact-review.md     # Review workflow
│   │   ├── artifact-fix.md        # Fix patterns
│   │   ├── artifact-constitution.md # Constitutional AI evaluation (P1-P5)
│   │   ├── artifact-archive.md    # ADAS pattern library
│   │   ├── artifact-handles.md    # Handle pattern for section-level loading
│   │   ├── blocking-gates.md      # Gate definitions & recovery strategies
│   │   ├── phase-contracts.md     # Typed inter-phase contracts
│   │   ├── phases-enhance.md      # ENHANCE mode phases (9 phases)
│   │   ├── phases-create.md       # CREATE mode phases
│   │   ├── phases-onboard.md      # Onboarding workflow
│   │   ├── plan-exploration.md    # Tree of Thought exploration
│   │   ├── subagents.md           # DAG execution & predefined agents
│   │   ├── agent-teams.md         # Peer-to-peer Agent Teams (v10.0)
│   │   ├── eval-optimizer.md      # MAR evaluation loop
│   │   ├── self-improvement.md    # Reflexion pattern & episodic memory
│   │   ├── step-quality.md        # Per-phase quality checks
│   │   ├── context-management.md  # Context budget & hierarchy
│   │   ├── load-order.md          # 4-tier lazy loading strategy
│   │   ├── activation-layer.md    # Command activation & disambiguation
│   │   ├── progress-tracking.md   # Session persistence & resume
│   │   ├── observability.md       # Tracing & metrics
│   │   ├── troubleshooting.md     # Common problems & mistakes
│   │   └── changelog.md           # Version history (v5-v9)
│   │
│   ├── scripts/                   # Deterministic hook scripts
│   │   ├── check-artifact-size.sh # PreToolUse: enforce SIZE_GATE
│   │   ├── yaml-lint.sh           # PostToolUse: validate YAML syntax
│   │   ├── check-references.sh    # PostToolUse: validate file references
│   │   └── verify-phase-completion.sh # Stop: verify all phases ran
│   │
│   └── templates/onboarding/      # Onboarding templates
│       ├── mcp.json               # MCP configuration template
│       ├── settings.json          # Claude Code settings template
│       └── sync-to-github.sh      # GitHub sync helper
│
├── templates/                     # Templates for new artifacts
│   ├── command.md
│   ├── skill.md
│   ├── rule.md
│   ├── agent.md
│   └── plan-template.md
│
└── archive/                       # Backup storage (for rollback)
```

## Usage

```bash
# Enhance existing artifact
/meta-agent enhance command my-command

# Create new artifact (with agent teams research)
/meta-agent create skill api-patterns

# Preview changes without applying
/meta-agent enhance command my-command --dry-run

# Force design exploration
/meta-agent create skill new-skill --explore

# Audit all artifacts
/meta-agent audit

# Delete artifact (with backup)
/meta-agent delete skill old-skill

# Rollback from backup
/meta-agent rollback

# Bootstrap new project
/meta-agent onboard /path/to/project

# Session management
/meta-agent list                  # List all runs
/meta-agent --resume {run_id}     # Resume from checkpoint
/meta-agent abort {run_id}        # Abort run
/meta-agent cleanup               # Delete runs older than 7 days
```

## Workflow

```
INIT → EXPLORE → ANALYZE → PLAN(ToT) → CONSTITUTE → DRAFT(+eval+reflect) → APPLY → VERIFY → CLOSE(+archive)
```

Key features:

- **CONSTITUTE**: Constitutional evaluation via 5 principles (replaces CRITIQUE)
- **DRAFT**: Separated evaluator + reflector subagents (Reflexion pattern)
- **PLAN**: Tree of Thought exploration for complex changes
- **VERIFY**: External validation (YAML, references, size, structure)
- **CLOSE**: ADAS archive extraction for self-improvement
- **CHECKPOINT**: User approval required before any changes
- **STEP QUALITY**: Quality checks after each phase
- **HOOKS**: Deterministic gates that agent cannot skip

## Dependencies

- **MCP memory** (optional but recommended): For context persistence, lessons learned
- **beads** (optional): Use `--track` flag for task tracking

## Customization

1. Adjust thresholds in `deps/blocking-gates.md`
2. Add project-specific templates in `templates/`
3. Update `deps/artifact-quality.md` with project patterns
4. Tune `deps/step-quality.md` criteria per phase
5. Configure hooks in `scripts/` for deterministic validation
