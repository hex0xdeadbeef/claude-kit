# phases_onboard

Bootstrap .claude/ for new project.

workflow: "VALIDATE → DETECT → GENERATE → CONFIGURE → REPORT"

## phase_1_validate

name: "VALIDATE"
steps:
  - "Check target path exists"
  - "Check if .claude/ already exists (warn if yes)"
  - "Verify git repo initialized"
output: |
  ## [1/5] VALIDATE ✓
  Target: /path/to/project
  Git repo: YES/NO
  Existing .claude/: YES/NO
  📋 Continue? [Y/n]

## phase_2_detect

name: "DETECT"
steps:
  - "Detect language (go.mod, package.json, Cargo.toml, etc.)"
  - "Detect framework (if any)"
  - "Suggest relevant starter skills"
output: |
  ## [2/5] DETECT ✓
  Language: {detected_language} {version}
  Framework: {detected_framework}
  Suggested skills: [list]

## phase_3_generate

name: "GENERATE"
steps:
  - "Create .claude/ directory structure"
  - "Copy onboarding templates (mcp.json, settings.json)"
  - "Create minimal CLAUDE.md"
templates:
  source: ".claude/agents/meta-agent/templates/onboarding/"
  files:
    - "mcp.json → ~/.claude/mcp.json (if not exists)"
    - "settings.json → .claude/settings.json"
    - "sync-to-github.sh → .claude/scripts/sync-to-github.sh"
output: |
  ## [3/5] GENERATE ✓
  Created: .claude/
  Files: [list]

## phase_4_configure

name: "CONFIGURE"
steps:
  - "Prompt user to edit mcp.json (MEMORY_FILE_PATH)"
  - "Prompt user to edit sync-to-github.sh (GITHUB_REPO)"
  - "Suggest running project-researcher"
output: |
  ## [4/5] CONFIGURE

  ⚠️ Manual steps required:
  1. Edit ~/.claude/mcp.json - set MEMORY_FILE_PATH
  2. Edit .claude/scripts/sync-to-github.sh - set GITHUB_REPO
  3. Run: /project-researcher (to generate PROJECT-KNOWLEDGE.md)

## phase_5_report

name: "REPORT"
output: |
  ## [5/5] REPORT ✓

  ✅ Onboarding complete!

  Next steps:
  1. bd init (initialize beads)
  2. /project-researcher (analyze codebase)
  3. /meta-agent create skill <name> (add project-specific skills)
  4. Verify MCP servers:
     - Run: mcp__memory__search_nodes — query: 'test'
     - If fails: "⚠️ Memory MCP not configured. See shared-core.md → Memory health check"
     - If works: "✅ Memory MCP available"
