# Project: <your-project-name>

> **Quick start:** This file documents project-level conventions used by the
> Claude Kit pipeline. For the language/framework-specific override values,
> populate `.claude/PROJECT-KNOWLEDGE.md` (see `.claude/PROJECT-KNOWLEDGE.md.example`
> for the canonical schema). The Plan stage reads PROJECT-KNOWLEDGE.md
> directly via `/planner` and via reviewer hook injection.
>
> Need a concrete starter? See `.claude/templates/project-claude-md-go-example.md`
> for a fully-populated Go backend example to copy and adapt.

## Language Profile

See `.claude/PROJECT-KNOWLEDGE.md` for the authoritative slot values
(LANGUAGE, VERIFY_CMD, LAYERS, ERROR_WRAP, etc.). The CLAUDE.md Language
Profile section below is a LEGACY fallback — kept for kits installed before
PROJECT-KNOWLEDGE.md became the input contract.

<!-- LEGACY FALLBACK — kept for backward compatibility.
     Authoritative values live in .claude/PROJECT-KNOWLEDGE.md. -->
- Language: <your-language>
- Commands: VERIFY=`<your-verify-cmd>`, FMT=`<your-fmt-cmd>`, LINT=`<your-lint-cmd>`, TEST=`<your-test-cmd>`
- Source: `<your-source-glob>`, Generated: `<your-gen-glob>`, Mocks: `<your-mock-glob>`
- Config: update `<your-config-example>` + `<your-config-docs>` when config changes

## Architecture (Import Matrix)

See `.claude/PROJECT-KNOWLEDGE.md → LAYERS / LAYER_RULE` for the
authoritative layer vocabulary. The Plan stage will use those values for
import-matrix validation.

## Workflow Commands

- Full dev cycle: `/workflow`
- Planning only: `/planner`
- Implementation: `/coder`

## Hooks

- See `.claude/settings.json` for the authoritative hook configuration.
