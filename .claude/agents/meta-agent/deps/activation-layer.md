# Activation Layer

purpose: "Prevent wrong command activation through multi-layer filtering"
problem: "User says 'review skill' but agent runs 'create skill'"

## Activation Flow

flow: |
  User Input
       │
       ▼
  ┌─────────────────┐
  │ Keyword Match   │ ← "create", "new", "add"
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ Pattern Extract │ ← type="skill", name=?
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ False Positive? │ ← Not "what is", "list", "explain"
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ Context Valid?  │ ← type valid, name present?
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ Disambiguation  │ ← "Create NEW or enhance EXISTING?"
  └────────┬────────┘
           │
           ▼
      ACTIVATE

## Keywords

mode_keywords:
  create: ["create", "new", "add", "generate", "make"]
  enhance: ["enhance", "improve", "update", "upgrade", "extend"]
  audit: ["audit", "review all", "check all", "scan"]
  delete: ["delete", "remove", "drop"]
  rollback: ["rollback", "restore", "undo"]
  list: ["list runs", "show runs"]
  resume: ["resume", "continue"]

type_keywords:
  command: ["command", "cmd"]
  skill: ["skill"]
  rule: ["rule"]
  agent: ["agent"]

## Patterns

extraction_patterns:
  - pattern: "create {type} {name}"
    extracts: [type, name]

  - pattern: "new {type} called {name}"
    extracts: [type, name]

  - pattern: "add {type} for {purpose}"
    extracts: [type, purpose]

  - pattern: "enhance {type} {name}"
    extracts: [type, name]

  - pattern: "{type} {name} needs updating"
    extracts: [type, name]
    mode: "enhance"

## False Positive Filter

exclude_if:
  questions: ["what is", "how do", "how does", "explain", "describe"]
  view_requests: ["list", "show me", "display", "where is", "find"]
  past_tense: ["I created", "I made", "was created"]

examples:
  NOT_activate: ["what is a skill?", "list all skills", "show me the errors skill", "explain skill activation"]
  activate: ["create skill errors", "new skill for logging", "add a skill for testing", "I need a skill that..."]

## Disambiguation

require_confirmation_if:
  - "ambiguous type (could be skill or command)"
  - "name not specified"
  - "multiple matches exist"

prompts:
  ambiguous_mode: |
    Did you mean:
    1. Create NEW artifact
    2. Enhance EXISTING artifact
    Which? [1/2]

  ambiguous_type: |
    What type of artifact?
    1. command
    2. skill
    3. rule
    4. agent
    Which? [1/2/3/4]

  missing_name: |
    What should this {type} be called?

  multiple_matches: |
    Found multiple matches:
    1. {match_1}
    2. {match_2}
    Which did you mean? [1/2]

# ── Auto-Chain ──
auto_chain:
  purpose: "Automatically trigger related commands after success"
  chains:
    - trigger: "/meta-agent create success"
      next: "Run VERIFY phase automatically"
      condition: "artifact created"
    - trigger: "/meta-agent enhance success"
      next: "Suggest /meta-agent audit"
      condition: "major changes"
  user_notification:
    before_chain: "Auto-triggering {next} based on {trigger}..."
    allow_skip: true
    skip_phrase: "skip auto"

# ── Integration ──
integration:

INIT:
  steps:
    1_keywords: "Match mode keywords"
    2_patterns: "Extract type and name"
    3_filter: "Check false positives"
    4_validate: "Confirm context"
    5_disambiguate: "If needed, ask user"
    6_activate: "Set mode, type, name"

output: |
  Activation:
  - Mode: {mode}
  - Type: {type}
  - Name: {name}
  - Confidence: {high/medium/low}

  [if low confidence]
  Please confirm: {disambiguation_prompt}
  [/if]
