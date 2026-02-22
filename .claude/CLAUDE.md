# claude-go-kit

A reusable Claude Code configuration kit for Go projects.
Provides a set of agents, commands, and templates for AI-assisted development.

## What's included

agents:
  - meta-agent: Manage Claude Code artifacts (create/enhance/audit commands, skills, rules, agents)
  - project-researcher: Deep project analysis → generates PROJECT-KNOWLEDGE.md
  - db-explorer: Explore PostgreSQL schema via MCP

commands:
  - /meta-agent: Artifact lifecycle management (onboard, create, enhance, audit, delete, rollback)
  - /workflow: Full dev cycle (task-analysis → planner → plan-review → coder → code-review)
  - /planner: Research codebase → detailed implementation plan
  - /plan-review: Validate plan before coding starts
  - /coder: Implement code strictly per approved plan
  - /code-review: Code review before merge
  - /db-explorer: Explore database schema and data
  - /review-checklist: Code review checklist reference

templates:
  - .claude/templates/agent.md
  - .claude/templates/command.md
  - .claude/templates/skill.md
  - .claude/templates/rule.md
  - .claude/templates/plan-template.md

## Using this kit in a project

To install into a new project:
  cp -r .claude/ /path/to/your/project/
  cp CLAUDE.md /path/to/your/project/

Then run:
  /meta-agent onboard          # Bootstrap .claude/ for the project
  /project-researcher          # Analyze codebase → PROJECT-KNOWLEDGE.md

## Creating new artifacts

  /meta-agent create command <name>    # New slash command
  /meta-agent create skill <name>      # New reusable skill
  /meta-agent create agent <name>      # New agent
  /meta-agent enhance command <name>   # Improve existing artifact
  /meta-agent audit                    # Quality report for all artifacts

## MCP servers

Required (configure in ~/.claude/mcp.json):
  - memory (@modelcontextprotocol/server-memory) — persistent agent memory
  - context7 (@upstash/context7-mcp) — library documentation lookup
  - sequential-thinking — structured reasoning

Optional:
  - postgres (@anthropic/mcp-postgres) — for db-explorer agent

## Conventions

- All artifacts: YAML-first format (>80% YAML, minimal prose)
- Language: English for code, YAML keys, artifact specs
- Examples: use grep/glob patterns to find current code, not hardcoded snippets
- Size limits enforced by hooks (check-artifact-size.sh)
