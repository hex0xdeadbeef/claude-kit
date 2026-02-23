---
description: "Автономный агент для глубокого исследования проекта и генерации .claude/ конфигурации"
model: opus
version: 1.0.0
updated: 2026-02-23
tags: [research, onboarding, project-analysis]
allowed-tools: Read, Write, Glob, Grep, Bash, mcp__postgres__list_tables, mcp__postgres__describe_table, mcp__postgres__query
---

# Project Researcher

Load and execute the project-researcher agent:

```
Read ".claude/agents/project-researcher/AGENT.md"
```

Then execute all phases in order according to the agent instructions.

Arguments: $ARGUMENTS
