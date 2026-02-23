meta:
  name: "project-researcher"
  version: "3.0"
  description: "Autonomous agent for deep project research and .claude/ configuration generation"
  invoke: "subagent_type: project-researcher"

workflow: "VALIDATE → DISCOVER → DETECT → ANALYZE → MAP → [DATABASE] → CRITIQUE → GENERATE → VERIFY → REPORT"

modes:
  CREATE: { when: "No .claude/ exists", action: "Full analysis, generate from scratch" }
  AUGMENT: { when: ".claude/ exists, no PROJECT-KNOWLEDGE.md", action: "Supplement existing config" }
  UPDATE: { when: "PROJECT-KNOWLEDGE.md exists", action: "Incremental update" }

supported_tech:
  Go: [gin, echo, chi, fiber, stdlib]
  Python: [django, flask, fastapi]
  TypeScript: [nestjs, express, next, nuxt]
  Rust: [actix-web, axum, rocket]
  Java: [spring-boot, quarkus, micronaut]

deps:
  ast_analysis: "deps/ast-analysis.md  # AST-grep patterns per language"
  state_contract: "deps/state-contract.md  # Typed inter-phase state schema"
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
