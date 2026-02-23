meta:
  name: "project-researcher"
  version: "4.0"
  description: "Autonomous orchestrator agent for deep project research and .claude/ configuration generation"
  invoke: "subagent_type: project-researcher"

architecture: "orchestrator + 6 specialized subagents via Task tool"

workflow: "DISCOVERY → DETECTION → ANALYSIS → CRITIQUE(gate) → GENERATION → VERIFICATION(gate) → REPORT"

modes:
  CREATE: { when: "No .claude/ exists", action: "Full analysis, generate from scratch" }
  AUGMENT: { when: ".claude/ exists, no PROJECT-KNOWLEDGE.md", action: "Supplement existing config" }
  UPDATE: { when: "PROJECT-KNOWLEDGE.md exists", action: "Incremental update" }

subagents:
  discovery: { file: "subagents/discovery.md", model: haiku, phases: "VALIDATE + DISCOVER" }
  detection: { file: "subagents/detection.md", model: sonnet, phases: "DETECT", parallelizable: true }
  analysis: { file: "subagents/analysis.md", model: opus, phases: "ANALYZE + MAP + DATABASE", parallelizable: true }
  generation: { file: "subagents/generation.md", model: sonnet, phases: "GENERATE" }
  verification: { file: "subagents/verification.md", model: sonnet, phases: "VERIFY", gate: blocking }
  report: { file: "subagents/report.md", model: haiku, phases: "REPORT" }

inline_phases:
  critique: { file: "phases/critique.md", model: opus, gate: blocking }

supported_tech:
  Go: [gin, echo, chi, fiber, stdlib]
  Python: [django, flask, fastapi]
  TypeScript: [nestjs, express, next, nuxt]
  Rust: [actix-web, axum, rocket]
  Java: [spring-boot, quarkus, micronaut]

deps:
  orchestration: "deps/orchestration.md  # Subagent interaction protocol"
  state_contract: "deps/state-contract.md  # Typed inter-phase state schema + subagent interface"
  ast_analysis: "deps/ast-analysis.md  # AST-grep patterns per language"
  edge_cases: "deps/edge-cases.md  # Known limitations"
  step_quality: "deps/step-quality.md  # Per-phase quality checks"
  reflexion: "deps/reflexion.md  # Self-improvement pattern"

outputs:
  CLAUDE_md: ".claude/CLAUDE.md  # Main file (≤200 lines)"
  PROJECT_KNOWLEDGE: ".claude/PROJECT-KNOWLEDGE.md  # Full research + dependency topology"
  memory: ".claude/memory.json  # MCP persistent context"
  skills: ".claude/skills/"
  rules: ".claude/rules/"

related:
  meta_agent: "meta-agent  # audit/enhance generated artifacts"
