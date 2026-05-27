---
status: research
type: analysis
complexity: XL
author: workflow orchestrator (XL research session)
date: 2026-05-27
scope: CHANGELOG.md versions 2.1.121 → 2.1.152 (inclusive)
prior_artifacts:
  - ".claude/prompts/changelog-2189-2118-workflow-analysis.md (2.1.89→2.1.118 analysis)"
  - "commit ac6deca — feat(workflow): Proposal B/D/E/F/G/H/I/J + 19 tests (v2.1.121-141 uplift)"
  - "commit 4e69f5f — feat(env): Proposal B/F/H opt-in env vars + version floor >= 2.1.141"
artifact_under_study: "claude-kit Workflow (post-uplift HEAD 7b0c03a — 8 skills, 8 cmds/agents, 24+ scripts)"
selected_improvements: 10
new_env_vars_introduced: 0
contract_changes: 0
---

# Анализ Claude Code CHANGELOG 2.1.121 → 2.1.152 на предмет улучшений Workflow

## 0. Executive Summary

Окно анализа `2.1.121 → 2.1.152` (24 версии) перекрывается с **уже выполненной**
работой. Session-recovery обнаружил, что прошлый XL-прогон
(`changelog-v2.1.121-141-uplift`, commits `ac6deca` + `4e69f5f`) уже собрал лучшее из
диапазона **2.1.121–141**: 6 кластеров (exec-form `args`, `worktree.baseRef`,
`continueOnBlock`, `PostToolUseFailure`, `$CLAUDE_EFFORT`-инъекция, OTEL-observability,
`terminalSequence`-нотификация, MCP `alwaysLoad`-preload), 19 тестов, plan-review APPROVED 3/3.

**Следствие:** реальная незанятая поверхность — это **(а)** диапазон `2.1.142 → 2.1.152`
(выше прошлого потолка 141) + **(б)** немного пунктов из 121–141, которые 6 кластеров
не затронули (`skillOverrides`, `subagent_type`-нормализация) + **(в)** семантический
churn `/simplify`, который начался в 2.1.147 и напрямую ломает наш Phase 2.5.

**Распределение по диапазону 2.1.121–152:** ~290 bullet-point'ов CHANGELOG → **34**
Workflow-релевантных. Из них:
- **DONE** (внедрено прошлым uplift'ом): 9.
- **PASSIVE** (платформенный bug-fix/perf, выигрыш автоматом): 13.
- **APPLY** (применимо, не внедрено → улучшения): 9.
- **WATCH** (недо-документировано / рискованно): 3.

**Ключевые выводы:**
1. **1 реальный correctness-gap (P0):** `/simplify` (Phase 2.5) был удалён в 2.1.147 и
   возвращён как алиас `/code-review --fix` в 2.1.152 — наш version floor `>= 2.1.141`
   оставляет «дыру» 2.1.147–2.1.151, где Phase 2.5 вызывает несуществующую команду,
   и расширенную семантику на 2.1.152+, под которую не откалиброван 30%-guard.
2. **4 P1-улучшения:** Stop-block-cap invariant vs платформенный `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`;
   `background_tasks`-aware completion-notify; defensive `subagent_type`-нормализация;
   `skillOverrides: name-only` (измеримая экономия токенов).
3. **5 P2-улучшений:** документация платформенных гарантий, SessionStart `sessionTitle`,
   config-safety guard для hook-типов, escalation-документация `/code-review`, defense-in-depth
   `disallowed-tools` для read-only `code-researcher`.
4. **0 новых env-var'ов** в нашей конфигурации (соблюдён принцип env-var restraint).
5. **0 изменений контрактов** plan/plan-review/coder/code-review (см. §10 — Contract-Safety Audit).

**Побочная находка (вне changelog-scope, но блокирующая):** HEAD `7b0c03a` содержал
синтаксическую ошибку в `protect-files.sh` (commented-out `fi` → `unexpected end of file`),
из-за чего PreToolUse(Write|Edit)-hook fail-closed блокировал ВСЕ записи в репозиторий.
Исправлено в рамках сессии (syntax restored, scripts-deny оставлен DISABLED по выбору
пользователя), добавлен `test-protect-files.sh`. Это НЕ входит в 10 улучшений (не
changelog-feature), но зафиксировано как hotfix.

Лист предложений — см. §6 (10 пунктов, приоритеты P0..P2). Отвергнутые кандидаты с
обоснованием — §7 (доказательство, что поверхность просканирована полностью, без padding'а).

---

## 1. Методология

### 1.1 Scope и связь с прошлой работой

- **Источник:** `CHANGELOG.md`, строки 3 → 674 (версии `2.1.152 … 2.1.121`, сверху вниз).
- **Нижняя граница:** `2.1.121` (по требованию задачи). **Верхняя граница:** `2.1.152` (текущий top).
- **Предшественник:** `changelog-2189-2118-workflow-analysis.md` покрыл `2.1.89→2.1.118`.
  Диапазон `2.1.119–120` не анализировался ни тем доком (потолок 118), ни здесь (пол 121) —
  это известный 2-версионный gap; по grep'у CHANGELOG в нём нет Workflow-релевантных пунктов
  (2.1.120 — мелкие фиксы; 2.1.119 отсутствует в файле).
- **Критический факт session-recovery:** существует **закоммиченный** uplift
  `changelog-v2.1.121-141-uplift` (artifacts в `.claude/workflow-state/`). Его scope —
  `2.1.121–141`. Поэтому фильтр этого анализа дополнительно исключает всё, что уже
  внедрено тем прогоном (см. §3 — DONE-инвентаризация).

### 1.2 Фильтр Workflow-релевантности

Пункт попадает в scope, если затрагивает: events/matcher'ы наших hooks; subagents pipeline
(delegation/isolation/Task tool); MCP жизненный цикл; permissions/security-периметр;
model effort/thinking/caching; worktree isolation (`code-reviewer`); skills/slash-commands,
влияющие на `/workflow`·`/planner`·`/coder`·reviewers.

### 1.3 Намеренно исключено

UI/TUI/fullscreen/Kitty/VS Code-фиксы; OAuth/login/keychain; plugin-marketplace; Remote
Control/claude.ai bridge; Bedrock/Vertex/Foundry-специфика; Windows/PowerShell-специфика;
SDK-only. Эти классы не меняют поведение нашего локального subscription-pipeline.

### 1.4 Принципы отбора 10 улучшений (ограничения задачи)

1. **No false positives** — каждое заявление о пользе falsifiable; тип пользы помечен
   (correctness | reliability | cost | regression-prevention | security-DiD | UX).
   Документационные пункты заявляют пользу «предотвращение регресса / снижение error-rate
   онбординга», а НЕ «улучшение runtime-производительности».
2. **No contract breakage** — ни один пункт не трогает дискриминаторы `handoff.schema.json`,
   конверт `VERDICT`/`VERDICT_JSON`, либо вход хеша canonical-ID `sha256(category|location|problem)`.
3. **Env-var restraint** — 0 новых env-var'ов в нашей конфигурации (per feedback 2026-05-22).
4. **Импакт > количество** — пункты ранжированы; распределение честно front-loaded (1×P0, 4×P1, 5×P2).

---

## 2. Полный каталог Workflow-релевантных фичей (2.1.121 → 2.1.152)

Статусы: **DONE** (внедрено uplift'ом), **PASSIVE** (автоматический выигрыш), **APPLY**
(→ §6), **WATCH** (мониторим), **IGNORE** (вне scope, опущено).

| # | Версия | Фича | Статус | → |
|---|--------|------|--------|---|
| 1 | 2.1.152 | `/simplify` теперь = `/code-review --fix` (применяет findings к рабочему дереву) | **APPLY** | I-01 |
| 2 | 2.1.152 | `/code-review --fix` применяет reuse/simplification/efficiency findings | APPLY | I-01, I-09 |
| 3 | 2.1.152 | Skills/slash-commands: `disallowed-tools` во frontmatter | APPLY | I-10 |
| 4 | 2.1.152 | `/reload-skills` + SessionStart `reloadSkills: true` | WATCH | — |
| 5 | 2.1.152 | SessionStart hooks могут задавать `hookSpecificOutput.sessionTitle` (startup+resume) | APPLY | I-07 |
| 6 | 2.1.152 | `MessageDisplay` hook event (transform/hide assistant text) | WATCH | §7 |
| 7 | 2.1.152 | Fallback на `--fallback-model` при «model not found» вместо отказа | PASSIVE | — |
| 8 | 2.1.150 | Sandbox write-allowlist в worktree сужен до `.git` (был весь main-repo root) | PASSIVE(sec) | I-06 |
| 9 | 2.1.150 | `find` в Bash больше не исчерпывает macOS vnode-таблицу (crash хоста) | PASSIVE | I-06 |
| 10 | 2.1.149 | `/usage` per-category breakdown (skills/subagents/plugins/per-MCP cost) | WATCH | §7 |
| 11 | 2.1.147 | `/simplify` переименован в `/code-review`; cleanup-and-fix поведение **удалено** | **APPLY** | I-01 |
| 12 | 2.1.145 | Stop и SubagentStop input включают `background_tasks` + `session_crons` | **APPLY** | I-03 |
| 13 | 2.1.145 | Read tool: «PARTIAL view» вместо hard-error при превышении token-лимита | PASSIVE | I-06 |
| 14 | 2.1.145 | Permission-bypass fix: bare env-var assignment больше не auto-approve | PASSIVE(sec) | I-06 |
| 15 | 2.1.145 | `agent_id`/`parent_agent_id` в OTEL tool-spans + nesting background-subagent | PASSIVE | — (Part 4 uplift) |
| 16 | 2.1.144 | `head`/`tail` удовлетворяют read-before-edit; no-match grep/git diff ≠ failure | PASSIVE | — |
| 17 | 2.1.143 | Stop-hook block-cap: turn завершается после **8** блоков (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`) | **APPLY** | I-02 |
| 18 | 2.1.143 | Worktree cleanup больше не делает `rm -rf` при сбое `git worktree remove` | PASSIVE(sec) | I-06 |
| 19 | 2.1.142 | Hook-config error: prompt/agent-type hook на SessionStart/Setup/SubagentStart | **APPLY** | I-08 |
| 20 | 2.1.142 | Reactive compaction seeds от overflow-size (меньше wasted retry) | PASSIVE | — |
| 21 | 2.1.141 | `terminalSequence` в hook JSON output | **DONE** | Proposal H |
| 22 | 2.1.140 | `subagent_type` matching case/separator-insensitive («Code Reviewer»→code-reviewer) | **APPLY** | I-04 |
| 23 | 2.1.140 | `/loop` больше не планирует лишние wakeup'ы для self-notifying задач | PASSIVE | — |
| 24 | 2.1.139 | hook `args: string[]` exec-form | **DONE** | Proposal (Part 1) |
| 25 | 2.1.139 | hook `continueOnBlock` на PostToolUse | **DONE** | Proposal (Part 2) |
| 26 | 2.1.139 | Compaction prompt сохраняет sensitive user instructions | PASSIVE | I-06 |
| 27 | 2.1.133 | `worktree.baseRef` (`fresh`\|`head`) | **DONE** | Proposal (Part 1) |
| 28 | 2.1.133 | Hooks получают `effort.level` / `$CLAUDE_EFFORT` | **DONE** | Proposal (Part 3) |
| 29 | 2.1.132 | Bedrock/Vertex 400 при `ENABLE_PROMPT_CACHING_1H` — fixed | PASSIVE | I-06 |
| 30 | 2.1.132 | `CLAUDE_CODE_SESSION_ID` в Bash subprocess (matching session_id hook'ов) | WATCH | §7 |
| 31 | 2.1.129 | `skillOverrides` работает: `off`\|`user-invocable-only`\|`name-only` | **APPLY** | I-05 |
| 32 | 2.1.129 | 1H prompt-cache TTL silent-downgrade в 5min — fixed | PASSIVE | I-06 |
| 33 | 2.1.122 | Malformed hooks-entry в settings.json не инвалидирует весь файл | PASSIVE(sec) | I-06 |
| 34 | 2.1.121 | MCP `alwaysLoad` (tools минуют tool-search deferral) | **DONE** | Proposal F |

> **Не вошедшие в таблицу 2.1.121 пункты** `PostToolUse updatedToolOutput` (для всех tools) и
> `CLAUDE_CODE_FORK_SUBAGENT=1` (non-interactive) → §7 (отвергнуты с обоснованием).

---

## 3. Уже внедрено (DONE) — исключаем из предложений

Эти 9 фичей закрыты прошлым uplift'ом (`ac6deca`/`4e69f5f`) и подтверждаются тестами.
**Их нельзя пере-предлагать** — это было бы дублирование.

| Фича | Версия | Доказательство (файл/тест/commit) |
|------|--------|------------------------------------|
| exec-form `args` | 2.1.139 | `settings.json` (все hooks `args:[]`); `test-hooks-exec-form.sh`, `test-hook-args-positional.sh` |
| `continueOnBlock` | 2.1.139 | `validate-handoff.sh`; `test-validate-handoff-continueOnBlock.sh` |
| `PostToolUseFailure` | 2.1.139 | `settings.json` `PostToolUseFailure`; `log-tool-failure.sh`; `test-log-tool-failure-*.sh` |
| `worktree.baseRef` | 2.1.133 | `settings.json` (`"fresh"`); `test-worktree-baseref-declared.sh` |
| `$CLAUDE_EFFORT` инъекция | 2.1.133 | `inject-review-context.sh`; `test-inject-review-effort-context.sh` |
| OTEL observability | 2.1.139/145 | `aggregate-pipeline-metrics.sh`, `audit-skill-loads.sh`; `test-aggregate-*`, `test-audit-skill-loads-*` |
| `terminalSequence` notify | 2.1.141 | `notify-workflow-complete.sh`; `test-notify-workflow-complete-*.sh` |
| MCP `alwaysLoad` preload | 2.1.121 | `mcp-preload-warn.sh`; `test-mcp-preload-warn-*.sh`; `CLAUDE_KIT_MCP_PRELOAD` |
| Version floor `>= 2.1.141` | — | `CLAUDE.md` Soft Prerequisites |

> **Также реверт:** `.claude/prompts/remove-taskcreated-hook.md` подтверждает, что старое
> предложение `TaskCreated`-hook (из 2189-2118 анализа, P1-07) было **отклонено и удалено** —
> не предлагаем повторно.

---

## 4. Граф взаимодействия артефактов (post-uplift) + куда заходят 10 улучшений

### 4.1 Легенда

`→` прямая зависимость · `⇢` lifecycle/event · `[NEW]`/`[MOD]`/`[DOC]` — действие улучшения · `★ I-NN` — точка входа.

### 4.2 Текущий pipeline + точки входа улучшений

```
┌───────────────────────── CONFIG LAYER ─────────────────────────┐
│ settings.json ──(hooks map)──► 24+ scripts                       │
│   ★ I-05 [MOD] + skillOverrides{name-only} для internal skills   │
│   ★ I-10 [MOD] code-researcher.md frontmatter + disallowed-tools │
│ CLAUDE.md ──(auto-load)──► every session                         │
│   ★ I-01 [DOC] Soft-Prereq: SIMPLIFY-path floor note (2.1.152)   │
│   ★ I-06 [DOC] "Platform Guarantees Relied Upon"                 │
│   ★ I-02 [DOC] Stop-block-cap vs CLAUDE_CODE_STOP_HOOK_BLOCK_CAP  │
└──────────────────────────────────┬──────────────────────────────┘
                                    ▼
┌──────────────── COMMAND LAYER (orchestrator ctx) ───────────────┐
│ /workflow ─► /designer(L/XL) ─► /planner ─► [plan-reviewer⟲] ──► │
│            ─► /coder ──┬─ EVALUATE                                │
│                        ├─ IMPLEMENT                              │
│                        ├─ SIMPLIFY (Phase 2.5) ──► /simplify     │
│                        │     ★ I-01 [MOD] coder.md:468 +         │
│                        │       workflow.md:248 + orch-core.md:32 │
│                        │       (/simplify == /code-review --fix) │
│                        ├─ VERIFY  └─ SPEC-CHECK                  │
│            ─► [code-reviewer⟲ isolation:worktree]               │
│                  ★ I-09 [DOC] code-review-rules: /code-review    │
│                     <effort>|ultra escalation path              │
│            ─► git commit                                         │
└──────────────────────────────────┬──────────────────────────────┘
                                    ▼
┌───────────────────────── HOOK EVENT PLANE ──────────────────────┐
│ [SessionStart] ⇢ caveman-activate.sh, mcp-preload-warn.sh        │
│     ★ I-07 [NEW] set-session-title.sh (sessionTitle на старте)   │
│ [UserPromptSubmit] ⇢ enrich-context.sh (sessionTitle IMP-2)      │
│ [SubagentStart] ⇢ inject-review-context.sh, track-task-lifecycle │
│     ★ I-04 [MOD] subagent_type defensive normalize (delegation)  │
│ [SubagentStop] ⇢ save-review-checkpoint.sh [BLOCKING]            │
│     ★ I-04 [MOD] REVIEW_AGENTS compare .lower()-tolerant         │
│ [Stop] ⇢ verify-phase-completion · check-uncommitted · notify    │
│     ★ I-02 [MOD] check-uncommitted: STOP_BLOCK_MAX<8 invariant    │
│     ★ I-03 [MOD] notify-workflow-complete: background_tasks-aware │
│ [InstructionsLoaded] ⇢ validate-instructions.sh                  │
│     ★ I-08 [MOD] guard: SessionStart/SubagentStart command-type  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.3 Карта файлов, затрагиваемых 10 улучшениями (для contract-impact оценки)

```
.claude/commands/coder.md              ← I-01 (Phase 2.5 prose; handoff field UNCHANGED)
.claude/commands/workflow.md           ← I-01 (simplify_note)
.claude/skills/workflow-protocols/
        orchestration-core.md          ← I-01 (mermaid SMP node label)
        delegation-templates.md        ← I-04 (DOC normalize note)
.claude/scripts/check-uncommitted.sh   ← I-02 (invariant comment/test; payload BYTE-STABLE)
.claude/scripts/notify-workflow-complete.sh ← I-03 (read stdin background_tasks)
.claude/scripts/save-review-checkpoint.sh   ← I-04 (agent_type compare; hash UNCHANGED)
.claude/scripts/validate-instructions.sh     ← I-08 (new grep guard)
.claude/scripts/set-session-title.sh   ← I-07 [NEW]
.claude/agents/code-researcher.md      ← I-10 (frontmatter disallowed-tools)
.claude/skills/code-review-rules/      ← I-09 (escalation doc)
.claude/settings.json                  ← I-05 (skillOverrides), I-07 (SessionStart hook), I-10
CLAUDE.md                              ← I-01, I-02, I-06 (doc sections)
.claude/scripts/tests/                 ← ВСЕ 10 (новый тест на каждое)
```

> Ни один из этих файлов не является `handoff.schema.json`, не определяет verdict-конверт,
> и не участвует во входе canonical-ID хеша. Полный аудит — §10.

---

## 5. Проблемы текущего Workflow относительно 2.1.142–152 (observed gaps)

Каждая проблема привязана к файлу/строке и факту CHANGELOG.

- **Gap-A1 (correctness):** `/simplify` вызывается в `coder.md:468`, `workflow.md:248`,
  `orchestration-core.md:32`. CHANGELOG 2.1.147 удалил `/simplify`; 2.1.152 вернул как
  `/code-review --fix`. Floor `>= 2.1.141` ⇒ на 2.1.147–2.1.151 Phase 2.5 вызывает
  unknown-command (на 2.1.147+ unknown-commands в headless показывают ошибку — bullet 2.1.147).
- **Gap-A2 (calibration):** purpose Phase 2.5 — «eliminate NIT/MINOR» (`coder.md:465`),
  guard 30% (`coder.md:472`). Новая семантика `/code-review --fix` применяет также
  **correctness-bug fixes** и reuse/efficiency — это шире, чем NIT/MINOR, и меняет риск-профиль guard'а.
- **Gap-R1 (reliability):** платформенный `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP=8` (2.1.143)
  нигде не упомянут (grep: «platform var NOT referenced»). Наш `STOP_BLOCK_MAX=5`
  (`check-uncommitted.sh:14`) сегодня **ниже** 8 — конфликта нет, но инвариант не зафиксирован
  тестом; будущая правка >8 даст force-end turn'а с потерей half-saved state.
- **Gap-R2 (edge-case correctness):** `notify-workflow-complete.sh` не читает stdin
  (подтверждено grep'ом), значит не видит `background_tasks` (2.1.145) — может выстрелить
  «workflow complete» пока фоновый subagent ещё работает.
- **Gap-O1 (robustness):** `save-review-checkpoint.sh` сравнивает `agent_type` с
  `REVIEW_AGENTS` точным совпадением (строка 151). Платформа 2.1.140 нормализует
  `subagent_type` на входе Agent-tool — наш compare стоит сделать tolerant как defense-in-depth.
- **Gap-C1 (cost):** `skillOverrides` (2.1.129) не используется (grep: «NOT referenced»);
  описания 8 internal-skill-пакетов инжектируются каждую сессию полностью.
- **Gap-D1 (regression-prevention):** 6 платформенных PASSIVE-фиксов, на которые kit
  опирается (worktree-isolation, 1H-cache, compaction, Read PARTIAL, settings resilience),
  нигде не задокументированы как «зависимости» — риск отката при будущих правках.
- **Gap-U1 (UX):** `sessionTitle` выставляется только на первом `UserPromptSubmit`
  (`enrich-context.sh:78`); при `--resume` до первого промпта заголовок не отражает workflow.
- **Gap-S1 (config-safety):** платформа 2.1.142 теперь ошибается на prompt/agent-type hook
  для SessionStart/SubagentStart. Мы compliant (все command-type), но нет guard-теста против регресса.
- **Gap-DiD1 (security):** `code-researcher` — read-only исследователь, но его невозможность
  писать держится только на природе haiku-промпта, не на платформенном ограничении.

---

## 6. Лист улучшений (10 пунктов)

Формат: **Problem → CHANGELOG ref → Proposed → Benefit [тип] → Contract-safety → Cost → AC**.
AC сформулированы falsifiable и явно сохраняют контракты.

### P0 — Correctness

#### I-01 — Согласовать Phase 2.5 SIMPLIFY с `/simplify` → `/code-review --fix`

- **Problem:** Gap-A1 + Gap-A2. Phase 2.5 вызывает `/simplify`, чья семантика дважды менялась
  (удалён 2.1.147, возвращён как `/code-review --fix` 2.1.152). Floor `>= 2.1.141` оставляет
  ломкое окно и расширенную семантику без рекалибровки.
- **CHANGELOG:** 2.1.147 («Renamed /simplify to /code-review… cleanup-and-fix behavior removed»),
  2.1.152 («`/simplify` now invokes `/code-review --fix`»).
- **Proposed:**
  1. `coder.md` Phase 2.5: `step_2` — сделать вызов robust: «Run `/simplify` (== `/code-review --fix`
     on v2.1.152+); if the command is unavailable (versions 2.1.147–2.1.151), SKIP gracefully and
     set `simplify_applied: skipped`». Обновить `purpose` на «apply low-risk reuse/simplification/
     efficiency fixes (and minor correctness fixes) before review».
  2. `workflow.md:248` `simplify_note` + `orchestration-core.md:32` mermaid-label — синхронизировать
     формулировку (`/simplify` → `/simplify (= /code-review --fix)`).
  3. `CLAUDE.md` Soft Prerequisites: добавить sentence, что **SIMPLIFY-path** требует `>= 2.1.152`
     для штатной работы; ниже — graceful-skip (не блокирует pipeline).
  4. Пересмотреть 30%-guard: оставить порог, но в `note` указать, что при новой семантике
     guard защищает и от correctness-fix'ов, расширяющих диффы.
- **Benefit [correctness]:** устраняет unknown-command на 2.1.147–2.1.151 (falsifiable: `/simplify`
  на 2.1.148 даёт ошибку → после правки Phase 2.5 делает skipped, pipeline продолжается);
  выравнивает purpose/guard под фактическую семантику.
- **Contract-safety:** `coder_to_code_review` handoff сохраняет поле `simplify_applied`
  (значения `true|false|skipped` — `skipped` уже легальное per `coder.md:470`). Mermaid и prose
  не входят ни в один data-контракт. **БЕЗОПАСНО.**
- **Cost:** ~1.0h (3 prose-правки + 1 CLAUDE.md note + 1 тест).
- **AC:**
  1. `coder.md` Phase 2.5 `step_2` содержит graceful-skip ветку и `simplify_applied: skipped`.
  2. `workflow.md` `simplify_note` и `orchestration-core.md` mermaid упоминают `/code-review --fix`-идентичность.
  3. `CLAUDE.md` Soft Prerequisites упоминает `>= 2.1.152` для штатного SIMPLIFY + graceful degradation ниже.
  4. Новый `test-simplify-semantics-doc.sh`: grep-asserts (1)–(3) присутствуют и взаимосогласованы; падает, если формулировка рассинхронизирована.
  5. **Regression:** `coder_to_code_review` schema-валидация неизменна (handoff с `simplify_applied: skipped` валиден).

### P1 — Reliability / Robustness / Cost

#### I-02 — Зафиксировать инвариант Stop-block-cap относительно платформенного `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`

- **Problem:** Gap-R1. Платформа force-завершает turn после 8 подряд Stop-блоков (2.1.143).
  Наш `STOP_BLOCK_MAX=5` сегодня ниже 8 (ОК), но инвариант не защищён.
- **CHANGELOG:** 2.1.143 («stop hooks that block repeatedly… ends after 8 consecutive blocks,
  override via `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`»).
- **Proposed:**
  1. `check-uncommitted.sh`: добавить комментарий-инвариант рядом с `STOP_BLOCK_MAX=5`:
     «MUST stay < platform `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` (default 8) so our circuit breaker
     fires first and saves state, before the platform force-ends the turn mid-block.»
  2. `CLAUDE.md` (Error Handling/Stop) + `workflow.md` Hook stderr-секция: задокументировать
     взаимодействие нашего breaker'а (5) и платформенного cap'а (8); явно сказать, что мы НЕ
     устанавливаем `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` (env-restraint), а проектируем под default.
  3. Не менять значение `STOP_BLOCK_MAX` и не добавлять env-var.
- **Benefit [regression-prevention]:** честно — runtime сегодня корректен; тест-инвариант не даёт
  будущей правке поднять breaker ≥ 8 и тем самым отдать управление платформенному force-end
  (который не сохранит наш half-written state). Falsifiable: тест читает `STOP_BLOCK_MAX` и
  падает, если ≥ 8.
- **Contract-safety:** Stop-hook не входит в 4 фазовых контракта. Block-payload остаётся
  **byte-stable** (AC-P3.10 прошлого P3-фикса) — только добавляются комментарий + doc. **БЕЗОПАСНО.**
- **Cost:** ~0.4h.
- **AC:**
  1. `check-uncommitted.sh` содержит инвариант-комментарий со ссылкой на `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`.
  2. `CLAUDE.md` + `workflow.md` описывают «5 < 8» взаимодействие.
  3. Новый `test-stop-block-cap-invariant.sh`: extract `STOP_BLOCK_MAX`, assert `< 8`; падает при ≥ 8.
  4. **Regression:** `test-stop-circuit-breaker.sh` (существующий) продолжает PASS — payload неизменён.

#### I-03 — `notify-workflow-complete.sh` учитывает `background_tasks`/`session_crons`

- **Problem:** Gap-R2. Stop-нотификация может выстрелить «complete», пока фоновая задача активна.
- **CHANGELOG:** 2.1.145 («Stop and SubagentStop hook input now includes `background_tasks` and
  `session_crons`»).
- **Proposed:** в `notify-workflow-complete.sh` (после gate `phase==5 && APPROVED`) прочитать
  stdin JSON; если `background_tasks` непуст — `exit 0` без эмиссии (отложить до финального Stop).
  `session_crons` использовать только информативно (комментарий: auto-checkpoint cron виден).
  Скрипт остаётся default-OFF (`CLAUDE_KIT_PHASE_COMPLETION_NOTIFY`).
- **Benefit [edge-case correctness]:** честно — сценарий редок (researcher работает в Phase 1/1.5,
  не в Phase 5), поэтому это defensive-hardening, а НЕ частый баг. Falsifiable: mock Stop-payload
  с `background_tasks:[{...}]` → нотификация подавлена; пустой → выстреливает.
- **Contract-safety:** Stop-hook, opt-in, не фазовый контракт. Allowlist OSC 9/BEL сохранён. **БЕЗОПАСНО.**
- **Cost:** ~0.6h.
- **AC:**
  1. notify по-прежнему default OFF.
  2. `on` + phase5 + APPROVED + `background_tasks==[]` → эмиссия `terminalSequence`.
  3. `on` + phase5 + APPROVED + `background_tasks` непуст → нет эмиссии.
  4. Новый `test-notify-background-tasks-suppress.sh` покрывает (2)+(3).
  5. **Regression:** `test-notify-workflow-complete-allowlist.sh` + `-default-off.sh` остаются PASS.

#### I-04 — Defensive нормализация `subagent_type` в резолвере agent-type

- **Problem:** Gap-O1. Точный compare `REVIEW_AGENTS` хрупок к casing/separator вариациям.
- **CHANGELOG:** 2.1.140 («`subagent_type` matching case- and separator-insensitive»).
- **Proposed:** в `save-review-checkpoint.sh` ввести `_normalize_agent_type(s)` =
  `s.strip().lower().replace(' ','-').replace('_','-')` и применять к `agent_type` перед
  сравнением с `REVIEW_AGENTS`/`WORKTREE_AGENTS`. Канонические имена (`plan-reviewer` и т.д.)
  не меняются. Note в `delegation-templates.md`: платформа нормализует input, мы — payload-compare.
- **Benefit [robustness]:** честно — это НЕ чинит P0-2 worktree-heuristic (SubagentStart всё ещё
  не fire'ит для worktree-агентов — 2.1.140 этого не меняет). Польза узкая: устойчивость
  REVIEW_AGENTS-матчинга к будущим/ручным вариациям casing. Falsifiable: payload `agent_type:"Code Reviewer"`
  резолвится в `code-reviewer`.
- **Contract-safety:** **КРИТИЧНО** — `agent_type` НЕ входит в canonical-ID хеш
  (`category|location|problem`), поэтому нормализация его не затрагивает байт-стабильность ID.
  Поля marker'а (`agent`, `effective_agent_type`, `verdict_source`) сохраняют значения для
  канонических входов. **БЕЗОПАСНО** при условии: нормализация добавочная, не меняет вывод для
  уже-канонических имён.
- **Cost:** ~0.8h.
- **AC:**
  1. `_normalize_agent_type` применяется только к compare, не к записываемым marker-значениям для канонических входов.
  2. Новый `test-subagent-type-normalize.sh`: входы `"Code Reviewer"`, `"code_reviewer"`, `"PLAN-REVIEWER"` → корректный resolve; канонический `"code-reviewer"` → без изменений.
  3. **Regression:** `test-subagent-stop-backfill-agent-type.sh` + `test-canonical-id-normalization.sh` остаются PASS (доказывает, что хеш ID не тронут).

#### I-05 — `skillOverrides: name-only` для internal pipeline-skills

- **Problem:** Gap-C1. Полные описания 8 internal-skill-пакетов инжектируются каждую сессию.
- **CHANGELOG:** 2.1.129 («`skillOverrides` setting now works: `off` hides from model and /,
  `user-invocable-only` hides from model only, `name-only` collapses description»).
- **Proposed:** в `settings.json` добавить `skillOverrides` со значением **`name-only`** для
  internal-only skills: `workflow-protocols`, `planner-rules`, `coder-rules`, `plan-review-rules`,
  `code-review-rules`, `design-rules`, `systematic-debugging`, `tdd-rules`. User-invocable skills
  (`workflow`, `planner`, `coder`, `designer`, `meta-agent`, `project-researcher`) — НЕ трогать.
  **Запрещено `off`** (заблокирует Skill-tool загрузку командами).
- **Benefit [cost]:** измеримое снижение токенов на инъекцию skill-descriptions (falsifiable:
  `/context` до/после показывает меньший per-skill estimate; число пишем в `pipeline-metrics.jsonl`).
- **Contract-safety:** `name-only` сохраняет invocation (команды всё ещё грузят skill через Skill
  tool — collapse касается только description в листинге). Контракты фаз не затронуты. **БЕЗОПАСНО**
  при строгом условии «name-only, не off».
- **Cost:** ~0.7h (config + verify-load тест).
- **AC:**
  1. `settings.json` `skillOverrides` = `name-only` для 8 internal skills; user-invocable skills отсутствуют в блоке.
  2. Дымовой тест: команда `/coder` всё ещё успешно грузит `coder-rules` (Skill-tool invocation не сломан).
  3. Новый `test-skilloverrides-internal-name-only.sh`: assert ни один skill не помечен `off`; assert user-invocable skills не в блоке.
  4. **Regression:** запуск `/workflow` без ошибок «skill not found».

### P2 — Regression-prevention / UX / Defense-in-Depth / Doc

#### I-06 — Секция «Platform Guarantees Relied Upon» в CLAUDE.md

- **Problem:** Gap-D1. 6 PASSIVE-фиксов, на которые kit опирается, не задокументированы как зависимости.
- **CHANGELOG:** 2.1.150 (worktree write-allowlist→`.git`), 2.1.143 (worktree cleanup без `rm -rf`),
  2.1.139 (compaction сохраняет sensitive instructions), 2.1.145 (Read PARTIAL-view), 2.1.129+2.1.132
  (1H-cache downgrade fix + Bedrock/Vertex 400 fix), 2.1.122 (malformed-hooks resilience).
- **Proposed:** новая подсекция в `CLAUDE.md` со списком «фича → версия → на что опирается kit».
  Привязать к обоснованию version floor.
- **Benefit [regression-prevention]:** честно — это документация; польза = не дать будущему
  maintainer'у откатить зависимость или понизить floor вслепую. Falsifiable: grep-тест на наличие секции.
- **Contract-safety:** doc-only. **БЕЗОПАСНО.**
- **Cost:** ~0.5h.
- **AC:**
  1. `CLAUDE.md` содержит секцию с ≥ 6 перечисленными гарантиями (версия + reliance).
  2. Новый `test-platform-guarantees-doc.sh`: grep-asserts наличие секции и ≥ 6 версий.

#### I-07 — SessionStart `sessionTitle` hook

- **Problem:** Gap-U1. Заголовок workflow не виден до первого промпта при `--resume`.
- **CHANGELOG:** 2.1.152 («SessionStart hooks can now set the session title via
  `hookSpecificOutput.sessionTitle` on startup and resume»).
- **Proposed:** новый `set-session-title.sh` (SessionStart, command-type), читает latest checkpoint
  (mtime-newest, как `notify-workflow-complete.sh:24`), эмитит `hookSpecificOutput.sessionTitle`
  тем же шаблоном `[WF] {feature} | PhN/5 | {complexity}`, что `enrich-context.sh:78`. Idempotent
  (тот же формат) — не конфликтует с UserPromptSubmit-вариантом.
- **Benefit [UX]:** заголовок виден при resume сразу. Falsifiable: при наличии checkpoint
  SessionStart-output содержит `sessionTitle` с корректным форматом.
- **Contract-safety:** SessionStart-hook, не фазовый контракт; формат заголовка идентичен
  существующему. **БЕЗОПАСНО.**
- **Cost:** ~0.7h.
- **AC:**
  1. `set-session-title.sh` зарегистрирован в `settings.json` SessionStart (command-type, `args:[]`).
  2. С checkpoint → эмитит `sessionTitle` формата `[WF] … | PhN/5 | …`; без checkpoint → `exit 0` без вывода.
  3. Новый `test-session-title-hook.sh` покрывает обе ветки.
  4. **Regression:** существующий `enrich-context.sh` sessionTitle-путь не изменён (`test-state-render-golden.sh` PASS).

#### I-08 — Guard в validate-instructions.sh: SessionStart/SubagentStart только command-type

- **Problem:** Gap-S1. Платформа 2.1.142 ошибается на prompt/agent-type hook для этих events;
  у нас нет защиты от такого регресса.
- **CHANGELOG:** 2.1.142 («configuring a prompt- or agent-type hook for SessionStart/Setup/SubagentStart
  now shows a clear "use a command-type hook instead" error»).
- **Proposed:** в `validate-instructions.sh` добавить проверку `settings.json`: для events
  `SessionStart`/`Setup`/`SubagentStart` все hooks должны иметь `type == "command"`. Нарушение →
  WARN (non-blocking, kit-stderr convention).
- **Benefit [config-safety]:** честно — мы сегодня compliant; guard предотвращает регресс, который
  иначе тихо сломает hook на старте. Falsifiable: подсунуть fixture-settings с prompt-type
  SubagentStart hook → guard выдаёт WARN.
- **Contract-safety:** проверка читает config, не меняет контракты. **БЕЗОПАСНО.**
- **Cost:** ~0.6h.
- **AC:**
  1. `validate-instructions.sh` проверяет тип hook'ов для трёх events.
  2. Новый `test-hooktype-guard.sh`: legit settings → PASS; fixture с prompt-type SubagentStart → WARN.
  3. **Regression:** реальный `settings.json` проходит guard без WARN (все наши SessionStart/SubagentStart — command-type).

#### I-09 — Документировать `/code-review <effort>` / `/code-review ultra` escalation в code-review-rules

- **Problem:** наследник `/ultrareview`; нет явного manual-escalation пути в reviewer-skill, и нет
  фиксации идентичности `/simplify == /code-review --fix` (связь с I-01).
- **CHANGELOG:** 2.1.147 (`/code-review` + `--comment`), 2.1.152 (`/code-review --fix`, ultra-вариант).
- **Proposed:** в `code-review-rules` добавить секцию «Escalation»: когда пользователю стоит
  запустить `/code-review high` или `/code-review ultra <PR#>` (security-sensitive, hot-path,
  multi-package > 500 LOC, повторный CHANGES_REQUESTED). Явно: orchestrator НЕ может вызвать
  ultra (billed, user-triggered).
- **Benefit [doc]:** честно — документация escalation-пути; не меняет автоматику. Falsifiable: grep-тест.
- **Contract-safety:** doc-only. **БЕЗОПАСНО.**
- **Cost:** ~0.3h.
- **AC:**
  1. `code-review-rules` содержит «Escalation» с критериями и пометкой «orchestrator cannot invoke».
  2. Новый `test-code-review-escalation-doc.sh`: grep-asserts наличие секции.

#### I-10 — Defense-in-depth `disallowed-tools` для read-only `code-researcher`

- **Problem:** Gap-DiD1. `code-researcher` — read-only, но запрет на запись держится лишь на промпте.
- **CHANGELOG:** 2.1.152 («Skills and slash commands can now set `disallowed-tools` in frontmatter
  to remove tools from the model while the skill is active»).
- **Proposed:** в `code-researcher.md` frontmatter добавить `disallowed-tools: [Write, Edit, NotebookEdit]`
  (исследователь возвращает summary ≤ 2000 токенов, не файлы — запись ему не нужна). Reviewers
  НЕ трогаем (им Write нужен для memory-sync). Если платформа применяет `disallowed-tools` только
  к skill-frontmatter, а не agent-frontmatter — fallback на skill-обёртку или пометка как known-limitation.
- **Benefit [security-DiD]:** провабельная невозможность мутации read-only агентом. Falsifiable:
  при попытке Write code-researcher получает tool-unavailable.
- **Contract-safety:** code-researcher — tool-assist, не pipeline-фаза; возвращает summary, не
  пишет artifacts. Удаление Write/Edit не затрагивает ни один handoff. **БЕЗОПАСНО.**
- **Cost:** ~0.6h (зависит от подтверждения scope `disallowed-tools` для agent-frontmatter).
- **AC:**
  1. `code-researcher.md` frontmatter содержит `disallowed-tools` с Write/Edit/NotebookEdit.
  2. Новый `test-code-researcher-readonly.sh`: assert frontmatter содержит запрет.
  3. **Regression:** code-researcher продолжает резолвиться как subagent; `track-task-lifecycle.sh` matcher `code-researcher` неизменен.

---

## 7. Рассмотренные и отклонённые кандидаты (доказательство полноты, без padding'а)

| Кандидат | Версия | Причина отклонения |
|----------|--------|--------------------|
| `MessageDisplay` hook | 2.1.152 | Может скрывать/менять текст ассистента — высокий риск маскировки verdict/handoff-строк; недо-понятен failure-mode. WATCH. |
| `PostToolUse updatedToolOutput` для всех tools | 2.1.121 | Подмена tool-output — риск тихого искажения данных, которые читают downstream hooks. Нет явного pipeline-выигрыша. WATCH. |
| `CLAUDE_CODE_FORK_SUBAGENT=1` non-interactive | 2.1.121 | «forked» ≠ parallel (подтверждено в 2189-2118 W-02); не расширяет flow. |
| `EnterWorktree` path-reuse | (≤2.1.121) | Теряем clean-slate per-iteration гарантию code-reviewer'а (решено в 2189-2118 P2-14). |
| `/usage` per-category cost | 2.1.149/150 | UI-фича, недоступна из hook'ов — не actionable для pipeline-metrics. |
| `disallowed-tools` для reviewers | 2.1.152 | Reviewers требуют Write для memory-sync — запрет сломал бы agent-memory protocol. |
| `CLAUDE_CODE_SESSION_ID` в Bash | 2.1.132 | Наши скрипты уже берут `session_id` из hook-payload; дублирующая ценность мала. |
| Новый env-var под любой из выше | — | Нарушает env-var restraint (feedback 2026-05-22). |
| Re-предложить `TaskCreated` hook | 2.1.89 | Уже отклонён и удалён (`remove-taskcreated-hook.md`). |

---

## 8. Сводная матрица приоритетов

| ID | Улучшение | Prio | Тип пользы | Effort | Risk | Новый env-var | Файлы |
|----|-----------|------|-----------|--------|------|---------------|-------|
| I-01 | SIMPLIFY ↔ /code-review --fix | **P0** | correctness | 1.0h | Low | нет | coder.md, workflow.md, orch-core.md, CLAUDE.md |
| I-02 | Stop-block-cap инвариант | P1 | regression-prev | 0.4h | Low | нет | check-uncommitted.sh, CLAUDE.md, workflow.md |
| I-03 | notify background_tasks-aware | P1 | edge correctness | 0.6h | Low | нет | notify-workflow-complete.sh |
| I-04 | subagent_type normalize | P1 | robustness | 0.8h | Low | нет | save-review-checkpoint.sh, delegation-templates.md |
| I-05 | skillOverrides name-only | P1 | cost | 0.7h | Med | нет | settings.json |
| I-06 | Platform-guarantees doc | P2 | regression-prev | 0.5h | Low | нет | CLAUDE.md |
| I-07 | SessionStart sessionTitle | P2 | UX | 0.7h | Low | нет | set-session-title.sh, settings.json |
| I-08 | Hook-type guard | P2 | config-safety | 0.6h | Low | нет | validate-instructions.sh |
| I-09 | /code-review escalation doc | P2 | doc | 0.3h | Low | нет | code-review-rules |
| I-10 | code-researcher disallowed-tools | P2 | security-DiD | 0.6h | Med | нет | code-researcher.md |
| | **Итого** | | | **~6.2h** | | **0** | 10 новых тестов |

> **Честное замечание о «ровно 10»:** P0-критичен только **I-01**; I-02..I-05 — крепкий P1;
> I-06..I-10 — P2 (доки/edge-case/DiD). Распределение front-loaded. Это НЕ padding: у каждого
> пункта конкретный falsifiable benefit с помеченным типом (не runtime-perf false-positive).
> Если приоритет «минимум риска / максимум импакта» — допустимо реализовать **core P0+P1 (I-01..I-05)**
> и отложить P2.

---

## 9. Риски внедрения и mitigations

| Риск | Вер. | Impact | Mitigation |
|------|------|--------|------------|
| I-04 нормализация меняет marker-вывод для канонического входа | Low | Med | Применять normalize ТОЛЬКО к compare; regression-тест на canonical-ID байт-стабильность |
| I-05 `skillOverrides` случайно `off` → модель не грузит skill | Med | High | Жёсткое AC: только `name-only`; дымовой тест Skill-load; user-invocable skills исключены |
| I-10 `disallowed-tools` не применяется к agent-frontmatter (только skill) | Med | Low | Подтвердить scope перед коммитом; fallback на skill-обёртку или known-limitation note |
| I-01 graceful-skip скрывает реальную поломку `/simplify` | Low | Low | Skip пишет `simplify_applied: skipped` + stderr WARN — видно в handoff/transcript |
| I-03 чтение stdin ломает текущий no-stdin путь | Low | Low | Best-effort drain (`cat 2>/dev/null`), как в `check-uncommitted.sh:20` |
| Любой пункт ломает контракт | Low | High | §10 Contract-Safety Audit + per-item regression AC + полный прогон `tests/` |

---

## 10. Contract-Safety Audit (обязательное требование задачи)

Проверка: **ни одно из 10 улучшений не меняет** контракты передачи данных между фазами.

**Защищаемые сущности:**
- 4 handoff-дискриминатора: `planner_to_plan_review`, `plan_review_to_coder`,
  `coder_to_code_review`, `code_review_to_completion` (+ `$handoff_contract`).
- 2 verdict-дискриминатора: `plan_review_verdict`, `code_review_verdict` (+ `$verdict_contract`).
- Конверт `VERDICT:` (enum) + `VERDICT_JSON:` fenced-block.
- Canonical-ID хеш: `sha256(norm(category)|norm(location)|norm(problem))[:8]`, префиксы `PR-`/`CR-`.
- `handoff.schema.json` (v1.2.0).

**Построчный вывод:**

| ID | Трогает контракт? | Доказательство безопасности |
|----|-------------------|------------------------------|
| I-01 | НЕТ | Меняет prose Phase 2.5 + mermaid-label; сохраняет handoff-поле `simplify_applied` (значение `skipped` уже легально). |
| I-02 | НЕТ | Stop-hook вне 4 контрактов; block-payload байт-стабилен; только комментарий+doc+тест. |
| I-03 | НЕТ | Stop-hook (opt-in); читает `background_tasks`, не пишет в контракт-артефакты; allowlist сохранён. |
| I-04 | НЕТ | `agent_type` НЕ входит во вход хеша canonical-ID; нормализация только на compare; marker-значения для канонических имён неизменны. |
| I-05 | НЕТ | `skillOverrides: name-only` влияет на листинг description, не на invocation и не на данные фаз. |
| I-06 | НЕТ | Документация. |
| I-07 | НЕТ | SessionStart `sessionTitle`; формат идентичен существующему; вне контрактов. |
| I-08 | НЕТ | Read-only проверка config; WARN-only. |
| I-09 | НЕТ | Документация. |
| I-10 | НЕТ | `code-researcher` — tool-assist, не фаза; возвращает summary, не пишет handoff. |

**Гейт тестов (обязательное требование):** базовая линия `tests/` (75/75 PASS на момент анализа)
должна остаться зелёной, и каждое улучшение добавляет ≥ 1 тест. Команда прогона (exit-code-safe, per feedback):
```bash
rc=0; for f in .claude/scripts/tests/test-*.sh; do bash "$f" || rc=1; done; exit $rc
```

---

## 11. Следующие шаги

1. **Gate (текущий шаг):** подтвердить с пользователем (а) набор 10 vs core P0+P1 (I-01..I-05);
   (б) реализовать сейчас vs остановиться на плане.
2. **При approve →** `/planner` берёт выбранный набор как Parts (рекомендуемая кластеризация:
   Cluster-1 = I-01 (correctness); Cluster-2 = I-02+I-03 (Stop-hooks); Cluster-3 = I-04 (subagent);
   Cluster-4 = I-05 (cost/config); Cluster-5 = I-06..I-09 (docs/UX); Cluster-6 = I-10 (DiD)).
3. **plan-reviewer (agent)** валидирует план — формальное review, без self-review.
4. **/coder** реализует Part-by-Part с TDD (RGR), сохраняя базовую линию тестов на каждом Part.
5. **code-reviewer (agent)** ревьюит diff в worktree.
6. **Phase 5:** commit + `pipeline-metrics.jsonl` (включая измерение токенов до/после I-05).

> **Hotfix вне 10:** ремонт `protect-files.sh` (write-lock) + `test-protect-files.sh` уже в дереве
> (не закоммичен). Войдёт в тот же branch-diff, который увидит code-reviewer.

---

## 12. Changelog этого документа

| Дата | Версия | Изменение |
|------|--------|-----------|
| 2026-05-27 | 1.0 | Анализ 2.1.121→2.1.152; исключён внедрённый uplift 121–141; 34 релевантных фичи; 10 улучшений (0 новых env-var, 0 изменений контрактов); зафиксирован protect-files.sh hotfix |
