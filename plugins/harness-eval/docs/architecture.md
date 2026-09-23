# Architecture

<p align="center">
  <a href="#-한국어"><kbd>한국어</kbd></a>&nbsp;&nbsp;&nbsp;
  <a href="#-english"><kbd>English</kbd></a>
</p>

---

# 한국어

## System Overview

harness-eval은 Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하는 플러그인이다.
3단계 평가 체계(Quick/Standard/Full)를 통해 정량적 스크립트 분석과 정성적 에이전트 리뷰를 결합한다.
사용자는 커맨드로 평가를 시작하고, 결과는 영어·한국어 보고서 파일로 제공된다. README 뱃지는 사용자가 opt-in한 경우에만 갱신된다.

## Components

### Evaluation Layer (정량 분석)
- **scripts/scoring.sh** -- 체크리스트 기반 점수 산출. Quick/Standard 모드 지원.
- **scripts/static-analysis.sh** -- Bash 문법, JSON 유효성, 파일 권한, 등록 일관성, 모델·effort 설정(`model-config`), 로드되지 않는 에이전트 파일(`agent-format`) 검증. 카테고리(Correctness/Safety/Completeness/Consistency)별 0–10 점수를 낸다.
- **scripts/aggregate.sh** -- Full 모드의 12개 차원 점수를 stdin JSON으로 받아 카테고리 가중치(0.50/0.25/0.25, 점수가 있는 카테고리끼리 재정규화)로 합산하고, 정본 history 레코드(overall, grade, 차원별 status, missing)를 출력.
- **scripts/lib/grade.sh** -- 등급 임계값의 유일한 정의(`score_to_grade`). scoring.sh와 aggregate.sh가 source한다.
- **scripts/history.sh** -- 평가 이력 저장 및 추세 분석. `history.json`과 `latest.json` 관리.
- **scripts/badge.sh** -- 점수 기반 뱃지(A+~F) SVG/마크다운 생성. README.md를 수정하므로 opt-in Stop 훅이나 사용자 요청으로만 실행된다.

### Orchestration Layer (스킬)
- **skills/quick/SKILL.md** -- 빠른 체크리스트 기반 평가 (< 30초). history에 저장하지 않는다.
- **skills/standard/SKILL.md** -- 정적+동적 분석 포함 표준 평가. 동적 분석은 사용자 확인 후 대상 코드를 실행하며 `--static-only`로 건너뛸 수 있다. 채점 직후 history에 저장한다.
- **skills/full/SKILL.md** -- 멀티 에이전트 병렬 평가 오케스트레이터. 서브에이전트는 Agent 도구로 호출하고, 모델·effort는 각 에이전트 frontmatter를 따른다.
- **skills/compare/SKILL.md** -- 저장된 두 평가 간 비교 분석.

### Analysis Layer (에이전트)
- **agents/collector.md** -- 대상 프로젝트의 하네스 인벤토리 수집(설정, 훅, 스킬, 에이전트, 커맨드, CLAUDE.md, 테스트, 플러그인 매니페스트). `.harness-eval/run/artifact.md`를 쓰고 `ARTIFACT_WRITTEN: <path>`를 반환한다. 도구: Read, Glob, Grep, Bash, Write.
- **agents/safety-evaluator.md** -- Safety(정적 점수에 대한 정성 보완) + Cost Efficiency(모델·effort 적합성, 도구 목록, 중복, 토큰·위임 비용). 읽기 전용.
- **agents/completeness-evaluator.md** -- Actionability, Testability, Contract-Based Testing. 읽기 전용.
- **agents/design-evaluator.md** -- Agent Communication, Context Management, Feedback Loop Maturity, Evolvability. 읽기 전용.
- **agents/synthesizer.md** -- 12개 차원 점수를 aggregate.sh로 채점하고, history에 저장하며, 영어·한국어 보고서 파일을 작성한다. 정상 경로에서 Full history 저장과 보고서 작성의 유일한 주체다(collector가 실패하면 오케스트레이터가 Standard 체크리스트 점수를 저장하고 fallback 보고서를 쓴다). 도구: Read, Bash, Write.
- 모든 에이전트는 `model: opus`를 쓰고 effort를 직접 지정한다(collector low, completeness·design·synthesizer medium, safety high). `CLAUDE_CODE_EFFORT_LEVEL`과 effort 상한(settings의 `maxEffortLevel`, 조직 상한)은 이 값보다 우선한다. 근거는 ADR-003과 플러그인 `CLAUDE.md`의 Agents module notes에 있다.

### Presentation Layer (출력)
- **templates/checklist.json** -- Quick/Standard 모드 체크 항목 정의(채점 입력).
- **templates/report-full.md, report-component.md** -- 초기 보고서 템플릿. 참고용이며 런타임에 읽지 않는다. 실제 보고서 형식은 각 `skills/*/SKILL.md`와 `agents/synthesizer.md`에 정의되어 있다.
- **보고서 파일** -- 대상 프로젝트의 `.harness-eval/reports/<id>-<mode>-{en,ko}.md` (Quick은 `eval-<date>-<NNN>-quick-{en,ko}.md`).

### Validation Layer (테스트)
- **tests/test-scoring.sh** -- 점수 산출 스크립트 검증.
- **tests/test-static-analysis.sh** -- 정적 분석 스크립트 검증(`model-config`, `agent-format` 포함).
- **tests/test-history.sh** -- 이력 관리 스크립트 검증.
- **tests/test-aggregate.sh** -- 집계 스크립트 검증(재정규화, 입력 거부, scoring.sh와의 등급 일치).
- **tests/hooks/, tests/structure/** -- 개발 훅, 플러그인 Stop 훅과 `badge.sh`의 README 보호 장치, 시크릿 패턴, 구조·버전 일관성, 에이전트 frontmatter(`model`·`effort` 값은 `static-analysis.sh`의 테이블과 대조), 이 저장소에 대한 `static-analysis.sh` 실행(`model-config`·`agent-format` PASS), Full 모드 문자열 계약(마커, 최종 메시지 줄, `## Scores` 차원, aggregate.sh 키) 검증.
- **tests/fixtures/** -- 4단계 성숙도 모의 프로젝트(minimal, functional, robust, production)와 회귀 픽스처(nested-hooks-project, model-era-project).

### Entry Point
- **commands/harness-eval.md** -- `/harness-eval [quick|standard|full|compare] [options]` 메인 커맨드. effort를 지정하지 않으므로 기본 quick을 포함한 모든 모드를 세션 effort로 실행한다.
- **commands/quick.md, standard.md, full.md, compare.md** -- 개별 모드 커맨드. 해당 모드의 `SKILL.md`를 경로로 읽어 따른다. `quick`과 `compare`는 `effort: low`로 실행된다.
- **hooks/hooks.json** -- 훅 이벤트 등록 (Stop -> post-eval-badge.sh).
- **hooks/post-eval-badge.sh** -- 사용자가 opt-in(`HARNESS_EVAL_AUTO_BADGE=1` 또는 git이 추적하지 않는 `.harness-eval/config.json`의 `autoBadge: true`)한 경우에만 README 뱃지를 갱신한다. 매 응답이 끝날 때 실행되지만, 저장된 평가마다 한 번(`latest.json`이 `.harness-eval/.badge-seen` 표식보다 새롭고 하루가 지나지 않은 경우)만 동작하며, symlink이거나 git이 추적하는 생성 파일은 무시한다. 자동으로 뱃지를 바꾸는 경로는 이것뿐이다.

## Full Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    Entry Points                              │
│                                                              │
│  ┌─────────────────┐    ┌──────────────────────────────┐     │
│  │ /harness-eval   │    │ Stop Hook (opt-in only)      │     │
│  │ (commands)      │    │ post-eval-badge.sh           │     │
│  └────────┬────────┘    └──────────────────────────────┘     │
└───────────┼──────────────────────────────────────────────────┘
            ▼
┌──────────────────────────────────────────────────────────────┐
│                 Orchestration (Skills)                       │
│                                                              │
│  ┌──────┐  ┌──────────┐  ┌──────┐  ┌─────────┐               │
│  │Quick │  │Standard  │  │Full  │  │Compare  │               │
│  └──┬───┘  └────┬─────┘  └──┬───┘  └─────────┘               │
└─────┼───────────┼───────────┼────────────────────────────────┘
      │           │           │
      ▼           ▼           ▼
┌─────────────────────────┐  ┌─────────────────────────────────┐
│   Evaluation Scripts    │  │   Analysis Agents (Full)        │
│                         │  │                                 │
│  scoring.sh             │  │  collector ──▶ run/artifact.md  │
│  static-analysis.sh     │  │      │                          │
│  aggregate.sh           │  │      ▼                          │
│  lib/grade.sh           │  │  safety-eval    ┐ parallel,     │
│  history.sh             │  │  completeness   ├ read-only     │
│  badge.sh               │  │  design-eval    ┘               │
│                         │  │      │                          │
│                         │  │      ▼                          │
│                         │  │  synthesizer ──▶ aggregate.sh,  │
│                         │  │                  history.sh     │
└─────────────────────────┘  └─────────────────────────────────┘
                                            │
                             ┌──────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────┐
│           Output (target project .harness-eval/)             │
│                                                              │
│  run/       static.json  score.json  artifact.md             │
│             record.json  standard-score.json                 │
│  reports/   <id>-<mode>-en.md  <id>-<mode>-ko.md             │
│  history.json  latest.json  .gitignore (*)  .badge-seen      │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

```
Quick:     scoring.sh ──▶ report files (en, ko)                       (not saved to history)
Standard:  static-analysis.sh, scoring.sh ──▶ [user confirms] hooks/tests
           ──▶ history.sh save ──▶ report files named by the saved ID
Full:
  Phase 1  static-analysis.sh ┐ in parallel ──▶ run/static.json, run/score.json
           scoring.sh         ┘               (SCRIPT_FAILED marker if one fails)
           collector ──▶ run/artifact.md      (returns ARTIFACT_WRITTEN: <path>)
           collector fails ──▶ history.sh save < score.json (mode standard)
                           ──▶ reports/<EVAL_ID>-full-fallback-{en,ko}.md, stop
  Phase 2  safety / completeness / design evaluators in parallel,
           each reading the three files by absolute path
  Phase 3  synthesizer (paths + the 3 evaluator outputs inline, verbatim):
           12 scores ──▶ aggregate.sh > run/record.json
           ──▶ history.sh save (only owner) ──▶ reports/<EVAL_ID>-full-{en,ko}.md
  Phase 4  orchestrator reads both reports and presents them in full
Badge:     no mode runs badge.sh; the Stop hook runs it once per saved evaluation
           (latest.json newer than .badge-seen, under a day old), only when the
           user opted in
```

## Key Design Decisions

- **3단계 평가 체계** -- 빠른 피드백(Quick)부터 심층 분석(Full)까지 사용자가 시간/깊이를 선택할 수 있도록 설계
- **하이브리드 접근** -- 정량적 체크(스크립트)와 정성적 리뷰(에이전트)를 분리하여 각각의 강점을 활용
- **생성/평가 분리** -- collector가 데이터를 수집하고 evaluator가 독립적으로 평가하여 편향 방지
- **파일 handoff** -- 서브에이전트는 최종 메시지만 반환하므로, 스크립트 출력과 collector 인벤토리는 `.harness-eval/run/`의 파일로 넘기고 prompt에는 그 절대 경로를 담는다. 읽기 전용인 evaluator 세 개의 결과만은 오케스트레이터가 synthesizer prompt에 그대로 옮겨 넣고, Phase 4에서는 두 보고서 전문을 다시 보여 준다
- **self-ignoring `.harness-eval/`** -- Standard·Full의 실행 디렉터리 준비 단계와 `history.sh save`가 `.harness-eval/.gitignore`(`*`)가 없으면 만들어, collector 인벤토리와 보고서가 커밋되지 않게 한다(Quick은 만들지 않는다)
- **결정론적 집계** -- 가중 평균과 등급은 `aggregate.sh`와 `lib/grade.sh`가 계산하고, synthesizer는 그 결과를 그대로 보고한다
- **에이전트별 모델·effort 고정** -- effort를 지정하지 않은 서브에이전트는 세션 effort를 상속하므로, 평가 깊이가 사용자마다 달라지지 않도록 각 에이전트가 effort를 직접 지정한다. `/effort`나 settings의 `effortLevel`은 이 값을 바꾸지 않지만, `CLAUDE_CODE_EFFORT_LEVEL`(`auto`·`unset` 포함)과 effort 상한은 이 값보다 우선한다 ([ADR-003](decisions/ADR-003-opus-5-5-model-effort-and-file-handoff.md))
- **최소 쓰기 권한** -- 신뢰할 수 없는 대상 파일을 읽는 evaluator는 읽기 전용이고, 쓰기는 collector와 synthesizer가 `.harness-eval/` 아래에만 한다
- **README 뱃지 opt-in** -- 어떤 평가 모드도 README.md를 수정하지 않으며, 자동 갱신은 opt-in한 Stop 훅만 한다
- **JSON stdout / stderr 로그** -- 스크립트 출력을 기계 판독 가능하게 유지하면서 사람용 로그는 stderr로 분리
- **4단계 테스트 픽스처** -- minimal → functional → robust → production 성숙도 스펙트럼으로 점수 차이를 검증

## Operations
- Evaluation: see `skills/quick/SKILL.md`, `skills/standard/SKILL.md`, `skills/full/SKILL.md`
- Test: `bash tests/harness-run-all.sh`
- Release: `docs/runbooks/release.md`
- 모델 교체: `docs/runbooks/model-change.md` (Claude 모델 라인이 바뀔 때 프롬프트, 에이전트별 모델·effort, 모델 테이블을 다시 점검하고 라이브 실행으로 시간·비용을 측정)

---

# English

## System Overview

harness-eval is a plugin that systematically evaluates Claude Code harness engineering quality.
It combines quantitative script analysis with qualitative agent review through a 3-tier evaluation system (Quick/Standard/Full).
Users start an evaluation with a command, and results are delivered as English and Korean report files. The README badge is updated only when the user has opted in.

## Components

### Evaluation Layer (Quantitative Analysis)
- **scripts/scoring.sh** -- Checklist-based scoring. Supports Quick/Standard modes.
- **scripts/static-analysis.sh** -- Bash syntax, JSON validity, file permissions, registration consistency, model and effort settings (`model-config`), and agent files that are never loaded (`agent-format`). Produces a 0-10 score per category (Correctness/Safety/Completeness/Consistency).
- **scripts/aggregate.sh** -- Reads Full mode's 12 dimension scores as JSON on stdin, combines them with the category weights (0.50/0.25/0.25, renormalized over the categories that have scores), and prints the canonical history record (overall, grade, per-dimension status, missing).
- **scripts/lib/grade.sh** -- The single definition of the grade thresholds (`score_to_grade`), sourced by scoring.sh and aggregate.sh.
- **scripts/history.sh** -- Evaluation history storage and trend analysis. Manages `history.json` and `latest.json`.
- **scripts/badge.sh** -- Score-based badge (A+ to F) SVG/markdown generation. Because it edits README.md, it runs only from the opt-in Stop hook or at the user's request.

### Orchestration Layer (Skills)
- **skills/quick/SKILL.md** -- Fast checklist-based evaluation (< 30 seconds). Not saved to history.
- **skills/standard/SKILL.md** -- Standard evaluation with static + dynamic analysis. Dynamic analysis runs target code after the user confirms and is skipped with `--static-only`. Saves history right after scoring.
- **skills/full/SKILL.md** -- Multi-agent parallel evaluation orchestrator. Dispatches subagents with the Agent tool; model and effort come from each agent's frontmatter.
- **skills/compare/SKILL.md** -- Comparative analysis between two saved evaluations.

### Analysis Layer (Agents)
- **agents/collector.md** -- Inventories the target's harness (settings, hooks, skills, agents, commands, CLAUDE.md files, tests, plugin manifests), writes `.harness-eval/run/artifact.md`, and returns `ARTIFACT_WRITTEN: <path>`. Tools: Read, Glob, Grep, Bash, Write.
- **agents/safety-evaluator.md** -- Safety (a qualitative supplement to the static score) + Cost Efficiency (model/effort fit, tool lists, redundancy, token and delegation spend). Read-only.
- **agents/completeness-evaluator.md** -- Actionability, Testability, Contract-Based Testing. Read-only.
- **agents/design-evaluator.md** -- Agent Communication, Context Management, Feedback Loop Maturity, Evolvability. Read-only.
- **agents/synthesizer.md** -- Scores the 12 dimensions with aggregate.sh, saves the evaluation to history, and writes the English and Korean report files. On the normal path, the only component that saves Full history or writes Full reports (when the collector fails, the orchestrator saves the Standard checklist score and writes fallback reports). Tools: Read, Bash, Write.
- Every agent uses `model: opus` and sets its own effort (collector low; completeness, design, synthesizer medium; safety high). `CLAUDE_CODE_EFFORT_LEVEL` and an effort cap (`maxEffortLevel` in settings, or an organization cap) take precedence over these values. The reasons are in ADR-003 and in the Agents module notes of the plugin `CLAUDE.md`.

### Presentation Layer (Output)
- **templates/checklist.json** -- Check item definitions for Quick/Standard modes (scoring input).
- **templates/report-full.md, report-component.md** -- Early report templates, kept for reference and not read at runtime. The report formats in use are defined in each `skills/*/SKILL.md` and in `agents/synthesizer.md`.
- **Report files** -- `.harness-eval/reports/<id>-<mode>-{en,ko}.md` in the target project (Quick: `eval-<date>-<NNN>-quick-{en,ko}.md`).

### Validation Layer (Tests)
- **tests/test-scoring.sh** -- Scoring script verification.
- **tests/test-static-analysis.sh** -- Static analysis script verification (including `model-config` and `agent-format`).
- **tests/test-history.sh** -- History management script verification.
- **tests/test-aggregate.sh** -- Aggregation script verification (renormalization, rejected input, grade parity with scoring.sh).
- **tests/hooks/, tests/structure/** -- Dev hooks, the plugin Stop hook and `badge.sh`'s README guards, secret patterns, structure and version consistency, agent frontmatter (`model` and `effort` values checked against `static-analysis.sh`'s tables), `static-analysis.sh` run on this repository (`model-config` and `agent-format` must PASS), and the Full-mode string contracts (markers, final-message lines, `## Scores` dimensions, aggregate.sh keys).
- **tests/fixtures/** -- 4-level maturity mock projects (minimal, functional, robust, production) and regression fixtures (nested-hooks-project, model-era-project).

### Entry Point
- **commands/harness-eval.md** -- `/harness-eval [quick|standard|full|compare] [options]` main command. It sets no effort, so it runs every mode, including its default quick, at the session effort.
- **commands/quick.md, standard.md, full.md, compare.md** -- Individual mode commands. Each reads its mode's `SKILL.md` by path and follows it. `quick` and `compare` run at `effort: low`.
- **hooks/hooks.json** -- Hook event registration (Stop -> post-eval-badge.sh).
- **hooks/post-eval-badge.sh** -- Updates the README badge only when the user opted in (`HARNESS_EVAL_AUTO_BADGE=1` or `autoBadge: true` in an untracked `.harness-eval/config.json`). It runs at the end of every response but acts once per saved evaluation (`latest.json` newer than the `.harness-eval/.badge-seen` marker and under a day old), and it ignores generated files that are symlinks or tracked by git. This is the only automatic badge path.

## Full Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    Entry Points                              │
│                                                              │
│  ┌─────────────────┐    ┌──────────────────────────────┐     │
│  │ /harness-eval   │    │ Stop Hook (opt-in only)      │     │
│  │ (commands)      │    │ post-eval-badge.sh           │     │
│  └────────┬────────┘    └──────────────────────────────┘     │
└───────────┼──────────────────────────────────────────────────┘
            ▼
┌──────────────────────────────────────────────────────────────┐
│                 Orchestration (Skills)                       │
│                                                              │
│  ┌──────┐  ┌──────────┐  ┌──────┐  ┌─────────┐               │
│  │Quick │  │Standard  │  │Full  │  │Compare  │               │
│  └──┬───┘  └────┬─────┘  └──┬───┘  └─────────┘               │
└─────┼───────────┼───────────┼────────────────────────────────┘
      │           │           │
      ▼           ▼           ▼
┌─────────────────────────┐  ┌─────────────────────────────────┐
│   Evaluation Scripts    │  │   Analysis Agents (Full)        │
│                         │  │                                 │
│  scoring.sh             │  │  collector ──▶ run/artifact.md  │
│  static-analysis.sh     │  │      │                          │
│  aggregate.sh           │  │      ▼                          │
│  lib/grade.sh           │  │  safety-eval    ┐ parallel,     │
│  history.sh             │  │  completeness   ├ read-only     │
│  badge.sh               │  │  design-eval    ┘               │
│                         │  │      │                          │
│                         │  │      ▼                          │
│                         │  │  synthesizer ──▶ aggregate.sh,  │
│                         │  │                  history.sh     │
└─────────────────────────┘  └─────────────────────────────────┘
                                            │
                             ┌──────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────┐
│           Output (target project .harness-eval/)             │
│                                                              │
│  run/       static.json  score.json  artifact.md             │
│             record.json  standard-score.json                 │
│  reports/   <id>-<mode>-en.md  <id>-<mode>-ko.md             │
│  history.json  latest.json  .gitignore (*)  .badge-seen      │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

```
Quick:     scoring.sh ──▶ report files (en, ko)                       (not saved to history)
Standard:  static-analysis.sh, scoring.sh ──▶ [user confirms] hooks/tests
           ──▶ history.sh save ──▶ report files named by the saved ID
Full:
  Phase 1  static-analysis.sh ┐ in parallel ──▶ run/static.json, run/score.json
           scoring.sh         ┘               (SCRIPT_FAILED marker if one fails)
           collector ──▶ run/artifact.md      (returns ARTIFACT_WRITTEN: <path>)
           collector fails ──▶ history.sh save < score.json (mode standard)
                           ──▶ reports/<EVAL_ID>-full-fallback-{en,ko}.md, stop
  Phase 2  safety / completeness / design evaluators in parallel,
           each reading the three files by absolute path
  Phase 3  synthesizer (paths + the 3 evaluator outputs inline, verbatim):
           12 scores ──▶ aggregate.sh > run/record.json
           ──▶ history.sh save (only owner) ──▶ reports/<EVAL_ID>-full-{en,ko}.md
  Phase 4  orchestrator reads both reports and presents them in full
Badge:     no mode runs badge.sh; the Stop hook runs it once per saved evaluation
           (latest.json newer than .badge-seen, under a day old), only when the
           user opted in
```

## Key Design Decisions

- **3-tier evaluation system** -- Lets users choose speed vs depth, from quick feedback (Quick) to deep analysis (Full)
- **Hybrid approach** -- Separates quantitative checks (scripts) from qualitative review (agents) to leverage each strength
- **Generation/evaluation separation** -- Collector gathers data, evaluators assess independently to prevent bias
- **File handoff** -- A subagent returns only its final message, so script output and the collector's inventory move between Full phases as files in `.harness-eval/run/`, and prompts carry their absolute paths. Only the three read-only evaluators' results are relayed inline, verbatim, into the synthesizer's prompt, and Phase 4 re-displays both reports in full
- **Self-ignoring `.harness-eval/`** -- Standard's and Full's run-directory step and `history.sh save` create `.harness-eval/.gitignore` (`*`) when there is none, so the collector inventory and the reports are not committed (Quick does not create it)
- **Deterministic aggregation** -- `aggregate.sh` and `lib/grade.sh` compute the weighted average and grade; the synthesizer reports their result as is
- **Per-agent model and effort** -- A subagent without an `effort` inherits the session effort, so each agent sets its own to keep evaluation depth the same for every user. `/effort` and the settings `effortLevel` do not change it, but `CLAUDE_CODE_EFFORT_LEVEL` (including `auto` and `unset`) and effort caps take precedence ([ADR-003](decisions/ADR-003-opus-5-5-model-effort-and-file-handoff.md))
- **Least write access** -- The evaluators, which read untrusted target files, are read-only; only the collector and synthesizer write, and only under `.harness-eval/`
- **README badge is opt-in** -- No evaluation mode edits README.md; only the opt-in Stop hook updates it automatically
- **JSON stdout / stderr logging** -- Keeps script output machine-readable while human logs go to stderr
- **4-level test fixtures** -- minimal -> functional -> robust -> production maturity spectrum verifies score differentiation

## Operations
- Evaluation: see `skills/quick/SKILL.md`, `skills/standard/SKILL.md`, `skills/full/SKILL.md`
- Test: `bash tests/harness-run-all.sh`
- Release: `docs/runbooks/release.md`
- Model change: `docs/runbooks/model-change.md` (re-check the prompts, each agent's model and effort, and the model tables when Claude's model line changes, and measure time and cost with a live run)
