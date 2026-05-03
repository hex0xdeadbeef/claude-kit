---
meta:
  type: "spec"
  status: "approved"
  produced_by: "/designer"
  feature: "coder-codereview-audit"
  task_type: "refactoring"
  complexity: "XL"
  approaches_considered: 2
  sequential_thinking_used: true
  pk_referenced: true
  acceptance_criteria_count: 36
  release_baseline: "v1.22.0 (latest tag) + b8d9fd1 (5 fixes) + cdc0e85 (FUNC_LOC_LIMIT revert)"
  prior_waves:
    - "coder-codereview-improvements (P1..P5: handoff caps, ID normalize, defensive backfill, verdict ordering, summarised additionalContext)"
    - "code-review-pipeline-improvements (P1..P4: minor-threshold reconcile, pre-delegation handoff serialize, warn-mode caveat, iter-≥2 spot-check) + Part 5 reverted"
---

# Spec: Coder + Code-Reviewer Pipeline Audit (v3 wave)

> Задача audit-уровня: на основании read-only анализа выявить 5 РЕМАНЕНТНЫХ дефектов фаз `/coder` + `code-reviewer`, прошедших мимо двух предыдущих волн исправлений (`coder-codereview-improvements`, `code-review-pipeline-improvements`). Каждое предложение строго additive — контракты `planner_to_plan_review`, `plan_review_to_coder`, `coder_to_code_review`, `plan_review_verdict`, `code_review_verdict` НЕ ломаются.

---

## Context

### Current state (verified 2026-05-03 against HEAD)

| Stage | Artifact | Lines |
|---|---|---|
| Coder command | `.claude/commands/coder.md` | 583 |
| Coder skill (SKILL) | `.claude/skills/coder-rules/SKILL.md` | 126 |
| Coder skill (review-response) | `.claude/skills/coder-rules/review-response.md` | 244 |
| Coder skill (spec-check) | `.claude/skills/coder-rules/spec-check.md` | 76 |
| Code-reviewer agent | `.claude/agents/code-reviewer.md` | 409 |
| Code-review skill (SKILL) | `.claude/skills/code-review-rules/SKILL.md` | 92 |
| Code-review skill (security) | `.claude/skills/code-review-rules/security-checklist.md` | 73 |
| Workflow protocols | `.claude/skills/workflow-protocols/*.md` | 18 files |
| Schema | `.claude/schemas/handoff.schema.json` | 1.1.0 (5 contracts) |
| Hook scripts (Coder/CR-related) | `.claude/scripts/{save-review-checkpoint,inject-review-context,validate-handoff,save-progress-before-compact,prepare-worktree}.sh` | 5 files, ~1900 lines |
| Tests baseline | `.claude/scripts/tests/test-*.sh` | **41/41 PASS** at audit start |

### Motivation

После двух волн фиксов (b8d9fd1 + cdc0e85) пайплайн стабилен по тестам, но детальный аудит обнаружил 5 РЕАЛЬНЫХ корректностных и наблюдаемостных дефектов, выживших обе волны. Все 5 — additive-fixable: ни один не требует изменения пяти зафиксированных контрактов JSON-Schema 1.1.0.

### Interaction Graph (Coder + Code-Reviewer subset)

```mermaid
flowchart TB
    %% Producers
    PLAN[/planner output:<br/>.claude/prompts/{feature}.md/]
    SPEC[/designer output:<br/>.claude/prompts/{feature}-spec.md/]

    %% Coder phases
    subgraph CODER["/coder"]
        direction TB
        ST[STARTUP — load:<br/>coder-rules SKILL,<br/>tdd-rules + tdd-shapes/&lt;LANG&gt;.md,<br/>spec-check]
        EVAL[Phase 1.5 EVALUATE<br/>budget per complexity<br/>output: {feature}-evaluate.md]
        RR[Phase 0.5 REVIEW RESPONSE<br/>only on re-entry<br/>load review-response.md]
        IMPL[Phase 2 IMPLEMENT<br/>Red-Green-Refactor cycles]
        SIMP[Phase 2.5 SIMPLIFY<br/>L/XL + parts≥5]
        VRF[Phase 3 VERIFY<br/>VERIFY_CMD cascade]
        SC[Phase 3.5 SPEC CHECK<br/>PASS / PARTIAL / FAIL<br/>max 1 retry]
        OUT[handoff narrative<br/>final_format text]
    end

    %% Orchestrator (workflow.md)
    subgraph WF["/workflow orchestrator"]
        direction TB
        DEL_PRE_CR[code_review_delegation.<br/>pre_delegation:<br/>STEP SHA / -2 sidecar /<br/>-1 .iteration-in-flight /<br/>0 IMP-01.2 handoff write<br/>narrative cap 600]
        SCHEMA[validate-handoff.sh<br/>oneOf 5 contracts]
        DEL_POST_CR[post_delegation:<br/>extract verdict /<br/>set-diff resolved/regression /<br/>append issues_history /<br/>write checkpoint]
    end

    %% Code-reviewer
    subgraph CR["code-reviewer (worktree)"]
        direction TB
        STC[STARTUP — additionalContext<br/>or INJECTED-CONTEXT.md sidecar]
        QC[QUICK CHECK<br/>trust verify_status /<br/>iter≥2 spot-check]
        REV[REVIEW<br/>arch / err-handling /<br/>security / tests]
        VOUT[VERDICT line +<br/>VERDICT_JSON envelope +<br/>narrative]
    end

    %% Hooks
    subgraph HOOKS["Event hooks"]
        SS_START[SubagentStart →<br/>inject-review-context.sh]
        SS_STOP[SubagentStop →<br/>save-review-checkpoint.sh<br/>IMP-02 / IMP-03 / IMP-H]
        WT[WorktreeCreate →<br/>prepare-worktree.sh<br/>copies sidecar]
        PRE_C[PreCompact →<br/>save-progress-before-compact.sh]
    end

    %% Persistent state
    subgraph STATE[".claude/workflow-state/"]
        CKPT[{feature}-checkpoint.yaml<br/>iteration_commit_sha,<br/>issues_history,<br/>delta_review_mode]
        RC[review-completions.jsonl<br/>verdict_source,<br/>canonical_issue_ids]
        HV[handoff-validation.jsonl<br/>schema_invalid,<br/>imp04_*,<br/>id_collision]
        REG[agent-id-registry.jsonl]
        SIDE[code-reviewer-INJECTED-CONTEXT.md]
    end

    %% Edges
    PLAN --> ST
    SPEC -.optional L/XL.-> ST
    ST --> EVAL
    EVAL --> IMPL
    IMPL --> SIMP
    SIMP --> VRF
    VRF --> SC
    SC --> OUT
    OUT --> DEL_PRE_CR
    DEL_PRE_CR --> SCHEMA
    SCHEMA --> WT
    WT --> SIDE
    DEL_PRE_CR --> SS_START
    SS_START --> STC
    STC --> QC
    QC --> REV
    REV --> VOUT
    VOUT --> SS_STOP
    SS_STOP --> RC
    SS_STOP --> CKPT
    SS_STOP --> HV
    SS_STOP --> DEL_POST_CR
    DEL_POST_CR -->|CHANGES_REQUESTED| RR
    RR --> IMPL
    PRE_C -.snapshot.-> CKPT
```

**Loaded artefacts (Coder + Code-Reviewer scope, post-1.22 baseline):**

- Commands: `coder.md` (Phase 0.5/1/1.5/2/2.5/3/3.5)
- Agent: `code-reviewer.md` (worktree-isolated; QUICK CHECK / GET CHANGES / REVIEW / VERDICT)
- Skills: `coder-rules/{SKILL,review-response,spec-check,examples,checklist,troubleshooting,mcp-tools}.md`; `code-review-rules/{SKILL,examples,security-checklist,checklist,troubleshooting}.md`; `workflow-protocols/{handoff-protocol,delegation-templates,incomplete-output-recovery,diff-manifest,orchestration-core,agent-memory-protocol,checkpoint-protocol,re-routing,counter-recovery,parallel-dispatch,pipeline-metrics,state-layer,unknown-verdict-recovery,examples-troubleshooting,handoff-contracts,SKILL,autonomy}.md`
- Schema: `handoff.schema.json` v1.1.0 (oneOf: planner_to_plan_review, plan_review_to_coder, coder_to_code_review, plan_review_verdict, code_review_verdict)
- Hooks: `save-review-checkpoint.sh`, `inject-review-context.sh`, `validate-handoff.sh`, `save-progress-before-compact.sh`, `prepare-worktree.sh`, `track-task-lifecycle.sh`, `sync-agent-memory.sh`, `resolve-worktree-path.py`
- Templates: `plan-template.md`, `spec-template.md`

**Out of audit scope (not loaded):** `/planner`, `plan-reviewer`, `/designer`, `/simplify`, `code-researcher`, `verdict-recovery`, `meta-agent`, `project-researcher`, `db-explorer`, install pipeline, `caveman` skill, `claude-md-audit`. Их влияние на Coder/CR упомянуто только через граф выше.

---

## Scope

### In

P-1. Согласовать обработку legacy-alias verdict `NEEDS_CHANGES` от `code-reviewer` на уровне orchestrator (routing + counter increment).
P-2. Добавить контракт `code_review_to_completion` в `handoff.schema.json` и записывать его на disk перед re-route в `/coder` (закрытие IMP-01.2).
P-3. Поднять fail-after-retry signal в `spec_check`: новое optional bool-поле, чтобы `code-reviewer` не демотировал FAIL→PARTIAL→MINOR без следа.
P-4. Удалить hardcoded `Functions ≤ 30 lines` правило из `code-reviewer.md` полностью — функционал покрывается линтерами проекта (golangci-lint funlen, pylint, eslint, clippy). Reviewer не должен дублировать линтерные проверки.
P-5. Жёстко определить роль `narrative_for_reviewer` как summary-only + добавить telemetry-record при тихой truncation на уровне orchestrator.

### Out

- item: "Реинтродукция `FUNC_LOC_LIMIT` numeric slot или LANGUAGE-conditional threshold"
  reason: "Reverted in cdc0e85 due to numeric-parse fragility. P-4 удаляет правило целиком — function-length проверки делегируются project linter (golangci-lint funlen / pylint / eslint / clippy / checkstyle), который УЖЕ вызывается в Phase 3 VERIFY до code-review."
- item: "Изменение enum `verdict` для `code_review_verdict`"
  reason: "Schema 1.1.0 фиксирует 5 значений (APPROVED/APPROVED_WITH_COMMENTS/CHANGES_REQUESTED/NEEDS_CHANGES/REJECTED) для cross-version compatibility — удаление NEEDS_CHANGES сломает legacy-corpus."
- item: "Перенос `code-researcher` в pipeline phase / увеличение memory-budget reviewer"
  reason: "Tool-agent статус и turn-budget — отдельные обсуждения за пределами audit-замечаний."
- item: "Изменение `coder_to_code_review` mandatory полей"
  reason: "Сохраняем существующий required set; все правки additive (новые optional поля)."
- item: "Введение нового `verdict_source` enum-значения"
  reason: "save-review-checkpoint.sh уже различает `structured_json`/`structured_json_schema_invalid`/`regex_fallback`/`none` — этого достаточно для P-1..P-5."
- item: "Изменение worktree.sparsePaths defaults"
  reason: "Обращается отдельным C-stage genericity audit; QUICK CHECK pre-flight уже эмитит BLOCKER при mis-config."
- item: "Расширение `narrative_for_reviewer` cap > 600 chars"
  reason: "P-5 закрывает root cause через summary-only contract, не растягивая лимит."

### Constraints (non-negotiable)

C-1. **Schema additive only.** Новые поля ВСЕ optional; existing required-set неизменен. JSON-Schema 1.1.0 → minor bump (1.2.0) — обратная совместимость гарантирована.
C-2. **41/41 baseline tests must pass.** Все существующие fixtures и тесты в `.claude/scripts/tests/test-*.sh` остаются зелёными.
C-3. **Сохранить контракты verbatim:** `$handoff_contract` и `$verdict_contract` discriminator strings, canonical-ID pattern `^[PC]R-[0-9a-f]{8}$`, parts of `## Scope` / `## Architecture Decision` / `## Tests` / `## Acceptance Criteria` / `## Parts` H2 headers, file-path references — все по boundaries из `.claude/skills/caveman/SKILL.md` § Boundaries (claude-kit).
C-4. **Ни одно предложение НЕ должно ломать v1.16..v1.22 правки в пайпе.** В частности:
  - canonical issue-ID normalization (502734f) — не трогаем `_compute_canonical_id` алгоритм.
  - handoff schema caps + size gauge (0b9150b) — не повышаем `narrative_for_reviewer` лимит.
  - summarised additionalContext rendering CAP 6000 (8afeb2f) — не повышаем cap.
  - defensive backfill / verdict-block TTL / worktree sidecar (87551b0) — оставляем семантику IMP-H + sidecar нетронутой.
  - verdict ordering (723d196) — оставляем порядок VERDICT → VERDICT_JSON → narrative.
  - FUNC_LOC_LIMIT revert (cdc0e85) — НЕ реинтродуцируем slot; используем LANGUAGE-only conditional.
C-5. **Каждая правка обоснована конкретной строкой/файлом.** Никаких "может в будущем" — только observable problems с указанием артефакта/строки.

---

## Architecture Decision

### Approach selected: Additive-only schema + orchestrator-level normalization

**Description:** Все 5 правок реализуются как
(a) дополнительные optional поля в `handoff.schema.json`,
(b) уточняющие правила в orchestrator (`delegation-templates.md`, `orchestration-core.md`, `re-routing.md`),
(c) минимальные правила в `coder.md` / `code-reviewer.md` для эмиссии/чтения новых полей,
(d) telemetry records (новые `record_kind` в `handoff-validation.jsonl`),
(e) добавочные тесты на регрессию.

**Rationale:** Дублирует уже-доказавший-себя стиль waves 1-2 (additive schema additions + delta-only behaviour change). Все 5 правок проходят через тот же набор валидаций (`validate-handoff.sh`, schema oneOf, hook stderr formatting). Вероятность регрессии MIN.

### Alternatives considered

#### Alt A: Refactor handoff format (replace JSON with YAML or richer envelope)

- pros: ["Можно в одном месте описать FAIL→PARTIAL semantics", "Понятная многострочная narrative"]
- cons: ["Ломает 5 контрактов разом", "validate-handoff.sh + check-jsonschema infra переписать", "save-review-checkpoint.sh `_extract_verdict_json` + IMP-02/03 — все ломается", "Все existing fixtures переписать → 41 тестов в зоне риска"]
- rejected_because: "Прямое нарушение C-1 + C-2 + C-4. Невозможно без масштабного переписывания и мажорной schema-bump'а."

#### Alt B: Сделать P-1..P-5 хук-only (без правок schema/agent prose)

- pros: ["Никаких правок agent files — минимальная поверхность", "Semantic-equivalent через post-hoc rewrites в save-review-checkpoint.sh"]
- cons: ["P-2 невозможен — handoff JSON должен быть на disk ДО запуска coder, не post-факто", "P-3 fail_after_retry должен прийти ОТ coder, hook не знает интент", "P-5 telemetry на trim требует знать pre-trim длину — это в orchestrator, не в hook", "Скрытая логика в hooks => agents-как-документация фиксируют ложь"]
- rejected_because: "Не закрывает root causes для P-2/P-3/P-5. Hook-only решает только наблюдаемую часть, оставляя contract-side непрозрачной."

### Top-5 Problems and Solutions

#### Problem 1: `NEEDS_CHANGES` verdict from code-reviewer is unrouted at orchestrator level

**Evidence:**
- `.claude/agents/code-reviewer.md:180`: `NEEDS_CHANGES: legacy alias for CHANGES_REQUESTED. Emit ONLY when orchestrator explicitly signals planner re-route via iteration counter`.
- `.claude/schemas/handoff.schema.json:209`: enum `code_review_verdict.verdict` includes `NEEDS_CHANGES` (cross-version compatibility).
- `.claude/skills/workflow-protocols/orchestration-core.md:64`: только `CHANGES_REQUESTED → Phase 3` упомянут для code-review. NEEDS_CHANGES от code-reviewer ОТСУТСТВУЕТ в routing.
- `.claude/skills/workflow-protocols/orchestration-core.md:108-115`: increment_rules перечисляет `plan-review verdict = NEEDS_CHANGES` И `code-review verdict = CHANGES_REQUESTED`, но НЕ имеет правила для `code-review verdict = NEEDS_CHANGES`.
- `.claude/skills/coder-rules/review-response.md:8`: trigger описан как `code-review iteration N/3`, но не упоминает NEEDS_CHANGES vs CHANGES_REQUESTED дискриминацию.

**Impact:** Если reviewer (или verdict-recovery, или regex-fallback в save-review-checkpoint.sh) нормализует verdict в `NEEDS_CHANGES`, orchestrator silently не увеличивает code_review counter и потенциально не route'ит обратно в Phase 3. Loop limit guard разрушается. Корректностный баг, не покрытый существующими тестами.

**Justification (no false positive):** `_extract_verdict_json` И regex `r'(?i)verdict:\s*(APPROVED_WITH_COMMENTS|APPROVED|CHANGES_REQUESTED|NEEDS_CHANGES|REJECTED)'` (см. `save-review-checkpoint.sh:497`) — оба механизма ВСТРЕЧАЮТ NEEDS_CHANGES от code-reviewer и эмитят его в `verdict` поле marker'а. Это не теоретическая возможность.

**Solution:** Документировать canonical alias normalization NEEDS_CHANGES → CHANGES_REQUESTED НА УРОВНЕ ORCHESTRATOR + добавить правило в `re-routing.md` + увеличить counter согласно увязке.

#### Problem 2: `code_review_to_completion` handoff is not schema-validated (IMP-01.2 deferred)

**Evidence:**
- `.claude/skills/workflow-protocols/handoff-protocol.md:156-157`: `contracts_not_yet_covered: [designer_to_planner, code_review_to_completion → IMP-01.2]`.
- `.claude/skills/workflow-protocols/delegation-templates.md` `code_review_delegation.post_delegation`: после получения verdict обновляется только checkpoint и issues_history. JSON-handoff на disk не пишется.
- Coder Phase 0.5 (`review-response.md:99-115`): "Read issues from code-reviewer handoff payload" — payload-источник не определён схемой; на практике issues приходят через `additionalContext` SubagentStart hook + `issues_history` в checkpoint, без validate-handoff.sh.
- Asymmetry с plan-review: тот же файл строки 159-168 показывают, что plan_review_to_coder ПИШЕТСЯ на disk и валидируется (`pre_delegation step 6.5`).

**Impact:** На re-entry `/coder` после CHANGES_REQUESTED получает issues только через free-form text (delegation prompt template + checkpoint YAML scrape). Нет машинно-валидной структуры issues с category/severity/location/problem/suggestion. Реальные последствия:
1. Coder может пропустить severity-ordering (BLOCKER first), потому что severity извлекается из текста.
2. Push-back/accept decision (review-response.md step 3) делается на необработанных строках — ID нестабильны (canonical IDs живут в `review-completions.jsonl`, отдельный путь).
3. Orchestrator не может re-validate issues при re-route (нет схемы для них).

**Justification:** Plan-side контракт уже эмитится (delegation-templates.md L159-168 step 6.5). Symmetry argument — тот же подход, который IMP-01.2 явно запланирован но never realized.

**Solution:** Добавить `code_review_to_completion` $def в `handoff.schema.json`; добавить `post_delegation step 6.5` в code_review_delegation; coder Phase 0.5 STARTUP читает `.claude/workflow-state/{feature}-handoff.json` если existing.

#### Problem 3: Spec-check FAIL→PARTIAL silent demotion bypasses BLOCKER classification

**Evidence:**
- `.claude/skills/coder-rules/spec-check.md:57`: `**Max 1 inline fix retry.** If still FAIL after retry → set status: PARTIAL, proceed`.
- `.claude/skills/coder-rules/spec-check.md:58`: `PARTIAL: document gaps, proceed to handoff. code-reviewer treats gaps as MINOR`.
- `.claude/agents/code-reviewer.md:86-88`: `If spec_check.status == PARTIAL: Note gaps from spec_check.issues, factor into REVIEW as MINOR`.
- Decision matrix (`code-reviewer.md:178`): `APPROVED_WITH_COMMENTS: 0 BLOCKER, 0 MAJOR, has MINOR/NIT (merge with notes)`.

**Impact:** Coder реализовавший 4 из 5 plan Parts → SPEC CHECK FAIL → 1 retry → still FAIL → демотируется в PARTIAL → reviewer классифицирует как MINOR → APPROVED_WITH_COMMENTS → MERGE. Реальный gap в plan-coverage сливается без CHANGES_REQUESTED. Это soft contract violation: spec-check был обещан как safety net "did we build the right thing?", но retry exhaustion обнуляет его.

**Justification:** Не теоретическая — coder.md Phase 3.5 explicitly enforces `Max 1 inline fix retry` ровно для случая, когда часть не реализуется тривиально. Если этот retry exhausts, текущая семантика теряет signal.

**Solution:** Добавить optional bool `spec_check.failure_after_retry` в `coder_to_code_review` schema + правило в `code-reviewer.md`: при `status=PARTIAL && failure_after_retry==true` → BLOCKER (не MINOR), category=`completeness`.

#### Problem 4: Hardcoded `Functions ≤ 30 lines` duplicates linter responsibility

**Evidence:**
- `.claude/agents/code-reviewer.md:139`: `Functions ≤ 30 lines (flag if exceeded)` — hardcoded под "4b. Error Handling".
- 30 lines = kit-default Go threshold per `.claude/PROJECT-KNOWLEDGE.md.example` и Go convention.
- `Part 5: FUNC_LOC_LIMIT slot` из `code-review-pipeline-improvements-spec.md` БЫЛ реверчен в cdc0e85 из-за numeric-parse fragility (попытка сделать порог настраиваемым провалилась).
- `.claude/skills/code-review-rules/SKILL.md` НЕ упоминает 30 lines — порог живёт ИСКЛЮЧИТЕЛЬНО в agent file.
- Линтеры проекта (по LANGUAGE) уже покрывают function-length проверки идиоматичным образом:
  - Go: `golangci-lint` → `funlen` linter (configurable per-project в `.golangci.yml`).
  - Python: `pylint` → `too-many-statements` / `pylint-pytest` рекомендации.
  - TypeScript: `eslint` → `max-lines-per-function` rule.
  - Rust: `clippy` → `too_many_lines` lint.
  - Java: `checkstyle` → `MethodLength` check.
- VERIFY phase в `/coder` обязательно вызывает project lint (`{LINT_CMD}`) — функционал function-length УЖЕ запускается перед code-review.

**Impact:**
1. **Дублирование:** reviewer flagging того, что lint уже проверил → шум в issues, не corrective signal.
2. **Кросс-language false-positive:** применение Go-default 30 lines к Python (idiomatic data pipeline 50-100 строк), TypeScript (React component с hooks 60-80), Java (verbose Builder 40+), Rust (impl block 50+) → false-positive findings на каждом non-Go ревью. Reviewer накапливает MINOR → 5+ MINOR same file auto-escalation → MAJOR → CHANGES_REQUESTED.
3. **Несистемный порог:** project может иметь свой `funlen` config (например 80 для long-test-file pattern) — reviewer игнорирует.
4. **Conflict with linter ground truth:** если `golangci-lint` PASS (project allows 50-line functions), reviewer всё равно flag'ит → coder вынужден push-back или сокращать без причины.

**Justification (без false-positive):** Это НЕ теоретическая проблема — порог hardcoded в code-reviewer.md L139 без conditional skip. Любой ревью на non-Go проекте триггерит правило. Линтер УЖЕ запущен в `/coder` Phase 3 VERIFY (см. `coder.md` verify_startup cascade), поэтому reviewer-side check избыточен.

**Solution:** Полное удаление правила "Functions ≤ 30 lines (flag if exceeded)" из `code-reviewer.md` + удаление мёртвой ссылки в `code-review-rules/SKILL.md`. Function-length теперь — ответственность project linter. Reviewer концентрируется на семантических проблемах error-handling (не numerical metric).

**Why removal, not slot/conditional:**
- LANGUAGE-conditional path → постоянное обслуживание per-language thresholds + дублирование linter config.
- Slot path → cdc0e85 уже показал numeric-parse fragility.
- Удаление → ноль обслуживания, signal not duplicated, source-of-truth = single (linter).

#### Problem 5: `narrative_for_reviewer` truncation is silent — no telemetry

**Evidence:**
- `.claude/schemas/handoff.schema.json:294-295`: `"narrative_for_reviewer": maxLength 600`.
- `.claude/skills/workflow-protocols/delegation-templates.md:289-291`: `Cap rule (P1 schema constraint): truncate narrative_for_reviewer at 600 chars BEFORE write — schema validation rejects payloads exceeding the cap.`
- `.claude/commands/coder.md:58-64`: `narrative_for_reviewer` шаблон содержит 5 многострочных bulletted списков (`Coder implemented...`, `Evaluate phase...`, `Deviations from plan...`, `Spec check...`, `High-risk areas...`) — для XL легко >600 chars.
- `.claude/scripts/save-review-checkpoint.sh` пишет `narrative_truncated` НЕ существует как `record_kind`.

**Impact:** На XL задаче coder narrative с 5 разделов >600 chars. Orchestrator silently обрезает. Reviewer получает усечённый narrative (последний раздел `High-risk areas` обычно ниже всего → откидывается первым). Risk-area-driven focus теряется. Усечение не записывается в `handoff-validation.jsonl` → не наблюдаем.

**Justification:** Не false-positive — это документированное поведение. Cap (600) фиксирован по C-4 (P1 schema constraint, 0b9150b). Решение НЕ меняет cap, а:
(1) уточняет роль narrative как summary-only,
(2) направляет deviations/risks в structured arrays (`high_risk_areas`, `risks_mitigated`, `deviations_from_plan` УЖЕ существуют в schema!),
(3) добавляет telemetry record `narrative_truncated` в `handoff-validation.jsonl` когда orchestrator реально обрезает.

**Solution:**
(a) `coder.md:58-64` явно объявляет narrative summary-only (1-2 предложения, без bullets); details идут в structured arrays.
(b) `delegation-templates.md` STEP 0 пишет `record_kind: "narrative_truncated"` в `handoff-validation.jsonl` если pre-trim length > 600.
(c) Тест `test-narrative-truncation-telemetry.sh` ловит запись.

### Key Decisions

- decision: "Schema bump 1.1.0 → 1.2.0 (additive)"
  rationale: "Добавляются новые $defs (`code_review_to_completion`) + optional поля (`spec_check.failure_after_retry`). Existing `coder_to_code_review` 1.1.0 fixtures остаются valid."
  impact: "Все имеющиеся handoff и verdict envelopes продолжают валидироваться. validate-handoff.sh oneOf-list расширяется на 1 entry. test fixtures из waves 1-2 не меняются."

- decision: "P-1 — orchestrator-level normalization (не agent-level)"
  rationale: "Code-reviewer schema уже фиксирует NEEDS_CHANGES (legacy alias) — удаление сломает legacy corpus. Нормализация на orchestrator не трогает agent поведения."
  impact: "В re-routing.md появляется правило `code-review NEEDS_CHANGES → treat as CHANGES_REQUESTED → increment code_review counter, route to Phase 3`. orchestration-core.md диаграмма обновляется: `CR -->|NEEDS_CHANGES (alias) / CHANGES_REQUESTED max 3x| COD`."

- decision: "P-2 — `code_review_to_completion` is OPTIONAL on disk (graceful degradation)"
  rationale: "Coder Phase 0.5 на re-entry СНАЧАЛА пытается прочитать handoff JSON; на отсутствии — fallback на текущий path (issues через delegation prompt + checkpoint). Backwards compatible: первый запуск после rollout продолжит работать без файла."
  impact: "code-reviewer.md не меняется (он не пишет JSON; пишет orchestrator). Все ранее-merged feature branches продолжают корректно re-route."

- decision: "P-3 — `failure_after_retry` is OPTIONAL bool (default false)"
  rationale: "Existing coder_to_code_review fixtures без поля остаются valid (additive). Code-reviewer reads field defensively с default false."
  impact: "spec-check.md обновляется: при retry exhaustion → set `failure_after_retry: true` (не меняем итоговый PARTIAL/FAIL status)."

- decision: "P-4 — Удаление правила, делегирование линтеру"
  rationale: "Function-length checks УЖЕ покрыты project linter (golangci-lint funlen / pylint / eslint max-lines-per-function / clippy too_many_lines / checkstyle MethodLength), который запускается в `/coder` Phase 3 VERIFY до code-review. Reviewer-side дублирование не добавляет signal, генерирует false-positive на non-Go проектах. Удаление безопаснее, чем LANGUAGE-conditional или slot — нулевое обслуживание, single source of truth."
  impact: "code-reviewer.md L139 удаляется bullet целиком. code-review-rules/SKILL.md синхронизуется (если ссылка есть). Test guard: regression test проверяет, что после удаления reviewer не эмитит MINOR/MAJOR findings типа 'function exceeds N lines' для function-length метрик. Function-length corrections поступают из linter output, не из reviewer."

- decision: "P-5 — narrative summary-only contract enforced in coder.md, telemetry в orchestrator"
  rationale: "Cap фиксирован (C-4). Root cause — coders cram structured info в prose. Лечится docs-fix coder.md + telemetry-only fix orchestrator."
  impact: "coder.md handoff_output narrative section получает explicit '1-2 sentences summary' rule. delegation-templates.md STEP 0 эмитит JSONL record при truncation."

### Known Risks

- risk: "P-4 удаление правила потенциально пропускает корректные long-function flags на проектах БЕЗ funlen-equivalent linter"
  severity: "LOW"
  mitigation: "Все 5 supported LANGUAGE'ов имеют идиоматичный funlen-аналог из коробки (golangci-lint funlen, pylint, eslint max-lines-per-function, clippy too_many_lines, checkstyle MethodLength). Project без linter уже не проходит coder Phase 3 VERIFY на других основаниях. Если custom кастомный язык вне 5-enum — emerges как consolidated NIT через other slot-driven paths, не через function-length specifically."

- risk: "P-2 add'l schema variant создаёт новую surface area для validation regressions"
  severity: "LOW"
  mitigation: "Покрыть новый $def двумя fixtures (valid + invalid) + integration test через validate-handoff.sh direct mode (existing pattern, см. test-coder-to-codereview-handoff-write.sh)."

- risk: "P-1 alias normalization может быть зловредно скрыт в metrics — оператору сложнее увидеть, что reviewer эмитнул NEEDS_CHANGES"
  severity: "LOW"
  mitigation: "При нормализации записывать `record_kind: 'verdict_alias_normalized'` в `handoff-validation.jsonl` с original_verdict + normalized_verdict. Pipeline-metrics остаётся неизменной."

- risk: "P-5 enforcement coder.md prose change может игнорироваться LLM, если coder получит narrative >600 от планировщика"
  severity: "LOW"
  mitigation: "Telemetry record делает violation наблюдаемым; orchestrator продолжает работать (graceful truncation). Жёсткой regression нет."

- risk: "Прохождение 41/41 тестов после правок зависит от того, что fixtures не нуждаются в новых required полях"
  severity: "LOW"
  mitigation: "C-1 — все additive optional. `test-coder-to-codereview-handoff-write.sh` fixture без `failure_after_retry` остаётся valid (default applied)."

---

## Tests

### Per-Part Test Plan

| Part | New test | Purpose | Outcome assertion |
|---|---|---|---|
| Part 1 | `test-needs-changes-alias-routing.sh` | Stub orchestrator pipe simulating reviewer emit `verdict: NEEDS_CHANGES` для code_review_verdict; assert orchestrator increments `iteration.code_review` counter и routes to Phase 3. | Counter increments by 1; phase next = 3. |
| Part 2 | `test-code-review-to-completion-handoff.sh` | Generate fixture `code_review_to_completion` (valid + invalid); pipe через `validate-handoff.sh`; verify schema oneOf accepts valid и rejects invalid. Plus: stub coder Phase 0.5 reading the JSON. | check-jsonschema rc=0 for valid, rc=2 for invalid (extra field). Coder reads issues with canonical IDs. |
| Part 3 | `test-spec-check-failure-after-retry-blocker.sh` | Fixture `coder_to_code_review` with `spec_check.status=PARTIAL` + `failure_after_retry=true`; stub code-reviewer logic (mocked review block); assert classification = BLOCKER, category = `completeness`. | Verdict CHANGES_REQUESTED emitted, BLOCKER count ≥1. |
| Part 4 | `test-func-loc-rule-removed.sh` | Grep code-reviewer.md + code-review-rules/SKILL.md; assert: (a) текстовый шаблон "Functions ≤ 30 lines" отсутствует во всём `.claude/agents/code-reviewer.md` и `.claude/skills/code-review-rules/`; (b) bullet под "4b. Error Handling" перечисляет только семантические правила (no numerical metrics); (c) `coder.md` Phase 3 VERIFY cascade still references `{LINT_CMD}` (linter responsibility preserved). | Grep returns zero matches for "Functions ≤ 30 lines" / "≤ 30 lines" / "<= 30 lines" в reviewer-side файлах. LINT_CMD ссылка в coder.md не тронута. |
| Part 5 | `test-narrative-truncation-telemetry.sh` | Fixture coder handoff narrative_for_reviewer length 750 chars; stub orchestrator pre_delegation STEP 0; assert: (a) narrative truncated to 600 chars; (b) `narrative_truncated` record appended to `handoff-validation.jsonl` with original_length + truncated_length. | Both assertions pass; existing schema validation continues to PASS. |

### Regression suite (existing — must remain green)

Все 41 теста в `.claude/scripts/tests/test-*.sh` остаются зелёными. Особо чувствительные:

- `test-coder-to-codereview-handoff-write.sh` — НЕ должен падать после schema 1.2.0 bump (additive).
- `test-codereview-spec-check-iter2-spotcheck.sh` — поведение iter≥2 spot-check не меняется.
- `test-canonical-id-normalization.sh` — sha256 алгоритм не трогаем (C-4).
- `test-handoff-size-cap.sh` — narrative cap не меняется.
- `test-state-render-golden.sh` — golden file fixtures обновляются ТОЛЬКО если pipeline metrics shape меняется (не меняется в этом wave).
- `test-save-review-checkpoint.sh` — структура marker'а не меняется (canonical_issue_ids preserved).
- `test-incomplete-output-step0-warn.sh` — IMP-02 warn-mode caveat не меняется.
- `test-imp04-diff-based-replan.sh` — diff-manifest unchanged.
- `test-subagent-stop-backfill-agent-type.sh` — IMP-01 backfill unchanged.
- `test-decision-matrix-consistency.sh` — decision matrix между code-reviewer.md / code-review-rules/SKILL.md остаётся byte-identical (5+ MINOR same file → MAJOR).

### Test commands

```bash
# Full regression
for f in .claude/scripts/tests/test-*.sh; do bash "$f" >/dev/null 2>&1 || echo "FAIL: $f"; done

# Targeted new tests
bash .claude/scripts/tests/test-needs-changes-alias-routing.sh
bash .claude/scripts/tests/test-code-review-to-completion-handoff.sh
bash .claude/scripts/tests/test-spec-check-failure-after-retry-blocker.sh
bash .claude/scripts/tests/test-func-loc-limit-language-skip.sh
bash .claude/scripts/tests/test-narrative-truncation-telemetry.sh

# Schema sanity
check-jsonschema --schemafile .claude/schemas/handoff.schema.json .claude/scripts/tests/fixtures/*.json
```

---

## Acceptance Criteria

### AC-Global

- AC-G1: `git diff` show'ит ТОЛЬКО additive changes в `.claude/schemas/handoff.schema.json` (no removed/renamed properties; version bumped 1.1.0 → 1.2.0).
- AC-G2: 41 existing tests + 5 new tests = 46/46 PASS (P-4 test — pure grep assertion, no fixture).
- AC-G3: `validate-handoff.sh` принимает все existing fixtures из `.claude/scripts/tests/fixtures/` без изменений.
- AC-G4: Каждое изменение в agent files (`coder.md`, `code-reviewer.md`) ссылается на соответствующий PROJECT-KNOWLEDGE slot или canonical SKIP pattern (no naked Go-defaults).
- AC-G5: Никаких новых `record_kind` значений в `handoff-validation.jsonl` кроме определённых в этом spec'e (`narrative_truncated`, `verdict_alias_normalized`).

### AC-Per-Part

#### AC-P1 (NEEDS_CHANGES routing)

- AC-P1.1: `re-routing.md` содержит явное правило: `code-review verdict in {CHANGES_REQUESTED, NEEDS_CHANGES} → treat alias-equivalent → increment code_review counter → route Phase 3`.
- AC-P1.2: `orchestration-core.md` Mermaid-диаграмма edge `CR -->|CHANGES_REQUESTED max 3x| COD` обновлена на `CR -->|CHANGES_REQUESTED \\| NEEDS_CHANGES (alias)\\nmax 3x| COD`.
- AC-P1.3: `tracking_protocol.increment_rules` в `orchestration-core.md` добавляет matching trigger для NEEDS_CHANGES (с пометкой alias).
- AC-P1.4: Тест `test-needs-changes-alias-routing.sh` симулирует verdict marker = NEEDS_CHANGES + проверяет, что orchestrator state transitions identical к CHANGES_REQUESTED.
- AC-P1.5: На нормализации orchestrator аппендит `record_kind: "verdict_alias_normalized"` в `handoff-validation.jsonl` с полями `{original_verdict, normalized_verdict, agent: "code-reviewer", iteration}`.

#### AC-P2 (code_review_to_completion contract)

- AC-P2.1: `handoff.schema.json` содержит новый `$def` `code_review_to_completion` с `$handoff_contract: const "code_review_to_completion"` discriminator.
- AC-P2.2: `oneOf` top-level расширён на 6 entries (5 existing + 1 new). Existing fixtures (`test-coder-to-codereview-handoff-write.sh`, etc.) остаются valid.
- AC-P2.3: `delegation-templates.md` `code_review_delegation.post_delegation` шаг 6.5 пишет JSON в `.claude/workflow-state/{feature}-handoff.json` после извлечения verdict + canonical_issue_ids.
- AC-P2.4: `coder.md` Phase 0.5 STARTUP читает `.claude/workflow-state/{feature}-handoff.json` если present и имеет `$handoff_contract == "code_review_to_completion"`.
- AC-P2.5: Graceful fallback — если файл отсутствует (первый rollout, hook fail), coder продолжает работать через existing path (delegation prompt text).
- AC-P2.6: Тест `test-code-review-to-completion-handoff.sh` валидирует valid (rc=0) + invalid (rc=2) fixtures + проверяет coder STARTUP read path.
- AC-P2.7: `handoff-protocol.md:156` обновлён — `code_review_to_completion` удалён из `contracts_not_yet_covered`.

#### AC-P3 (Spec Check failure_after_retry)

- AC-P3.1: `handoff.schema.json` `coder_to_code_review.spec_check` получает дополнительный optional bool `failure_after_retry: { type: "boolean" }`.
- AC-P3.2: `coder-rules/spec-check.md:57` обновлён — при retry exhaustion устанавливать `failure_after_retry: true` AND keeping status: PARTIAL (не меняем downgrade-семантику; только сигнал).
- AC-P3.3: `code-reviewer.md:86-88` обновлён — на `spec_check.status == PARTIAL && spec_check.failure_after_retry == true` raise BLOCKER (category=`completeness`, location=`Part {first missing}`); НЕ MINOR.
- AC-P3.4: Decision matrix в обоих местах (`code-reviewer.md`, `code-review-rules/SKILL.md`) остаётся byte-identical (test-decision-matrix-consistency.sh не падает).
- AC-P3.5: Существующая семантика PARTIAL (coverage>=ratio_threshold но minor gap) НЕ меняется — только дополнительный сигнал поверх.
- AC-P3.6: Тест `test-spec-check-failure-after-retry-blocker.sh` — fixture с `failure_after_retry=true` → emitted verdict CHANGES_REQUESTED.

#### AC-P4 (Functions ≤ 30 lines rule removed)

- AC-P4.1: `code-reviewer.md:139` bullet `Functions ≤ 30 lines (flag if exceeded)` УДАЛЁН полностью. Окружающий контекст ("4b. Error Handling") сохраняет остальные семантические правила (error wrapping, no log+return, грэп `log.*err`).
- AC-P4.2: `code-review-rules/SKILL.md` НЕ содержит ссылку на 30-line threshold (если такая есть, удалить).
- AC-P4.3: НЕ вводится новый PROJECT-KNOWLEDGE.md slot. `FUNC_LOC_LIMIT` НЕ появляется ни в `.claude/PROJECT-KNOWLEDGE.md.example`, ни в `code-reviewer.md`, ни в любом другом артефакте (cdc0e85 регрессия исключена).
- AC-P4.4: НЕ вводится LANGUAGE-conditional path для function-length — правило просто удалено.
- AC-P4.5: Тест `test-func-loc-rule-removed.sh`: `grep -E 'Functions\s*[≤<=]+\s*30\s*lines|≤\s*30\s*lines\s*\(flag\s*if\s*exceeded\)' .claude/agents/code-reviewer.md .claude/skills/code-review-rules/` возвращает zero matches.
- AC-P4.6: `coder.md` Phase 3 VERIFY cascade и его `{LINT_CMD}` ссылка НЕ меняются — function-length проверки остаются ответственностью project linter.
- AC-P4.7: Existing test `test-decision-matrix-consistency.sh` продолжает PASS (decision matrix shape не зависит от 30-line правила).

#### AC-P5 (narrative summary-only + truncation telemetry)

- AC-P5.1: `coder.md:58-64` narrative_for_reviewer template переформулирован: `narrative_for_reviewer (1-2 sentences summary ONLY): "{One-line description of work + most critical risk}". Detailed deviations/risks/areas → use structured arrays (deviations_from_plan, risks_mitigated, high_risk_areas).`
- AC-P5.2: `delegation-templates.md` STEP 0 при `len(narrative) > 600`:
  (a) Логирует record `{record_kind: "narrative_truncated", agent: "/coder", original_length: N, truncated_length: 600, feature, iteration}` в `handoff-validation.jsonl`.
  (b) Truncate to 600 chars (existing behaviour preserved).
- AC-P5.3: Cap `maxLength: 600` в schema НЕ меняется (C-4).
- AC-P5.4: Тест `test-narrative-truncation-telemetry.sh` — narrative >600 → record_kind=`narrative_truncated` присутствует в jsonl.
- AC-P5.5: Существующий `test-handoff-size-cap.sh` не fail'ит (cap 600 unchanged).
- AC-P5.6: Coder.md final_format example (lines 65-87) перерабатывается так, что narrative_for_reviewer показывается одной строкой; structured arrays занимают всё остальное.

---

## Approval Gate

**Pending user approval.** Spec статус: `pending_approval`. После approval (via /workflow):

1. status → `approved`.
2. Handoff payload сформируется для /planner со следующим content:
   - spec_artifact: `.claude/prompts/coder-codereview-audit-spec.md`
   - metadata: `{task_type: "refactoring", complexity: "XL", approaches_considered: 2, sequential_thinking_used: true}`
   - key_decisions: 5 записей выше.
   - known_risks: 5 записей выше.
   - acceptance_criteria_count: 24 (5 global + 19 per-part).
3. /planner получит spec и сформирует план Parts 1-5 (1 на проблему).

**Reviewer focus areas (для plan-reviewer):**
- Areas needing attention: `Part 2: schema oneOf bump 1.1.0 → 1.2.0 — verify all existing fixtures continue to validate`, `Part 3: spec_check.failure_after_retry semantics — verify не ломает existing FAIL→PARTIAL retry path`, `Part 4: LANGUAGE detection cascade — verify CLAUDE.md fallback to "go" preserves R2 kit-dogfood`.
