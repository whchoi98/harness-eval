<p align="center">
  <kbd><a href="#english">English</a></kbd> |
  <kbd><a href="#한국어">한국어</a></kbd>
</p>

---

# English

## System Overview

harness-eval is a Claude Code marketplace plugin monorepo that evaluates harness engineering quality through a 3-tier evaluation system (Quick/Standard/Full). The monorepo wraps a plugin (`plugins/harness-eval/`) with marketplace packaging (`.claude-plugin/`) and development tooling (`.claude/`).

## Components by Layer

### Presentation Layer

| Component | Location | Purpose |
|-----------|----------|---------|
| Slash Commands | `plugins/harness-eval/commands/` | User-facing entry points (`/harness-eval`, `/harness-eval:quick`, `/harness-eval:standard`, `/harness-eval:full`, `/harness-eval:compare`) |
| Templates | `plugins/harness-eval/templates/` | `checklist.json` scoring input; the report formats themselves are defined in the skills and the synthesizer agent |
| Badge Generator | `plugins/harness-eval/scripts/badge.sh` | Visual grade badge for README embedding (run by the opt-in Stop hook or by the user) |

### Processing Layer

| Component | Location | Purpose |
|-----------|----------|---------|
| Skills | `plugins/harness-eval/skills/` | Evaluation logic per tier (quick, standard, full, compare) |
| Agents | `plugins/harness-eval/agents/` | Full-mode subagents: collector (writes the inventory file), three read-only evaluators, synthesizer (scores, saves history, writes the reports) |
| Scoring Engine | `plugins/harness-eval/scripts/scoring.sh` | Deterministic checklist scoring |
| Aggregator | `plugins/harness-eval/scripts/aggregate.sh` | Deterministic Full-mode 12-dimension scoring (grade thresholds shared with scoring.sh via `scripts/lib/grade.sh`) |
| Static Analyzer | `plugins/harness-eval/scripts/static-analysis.sh` | File/code pattern analysis, including model and effort settings |

### Storage Layer

| Component | Location | Purpose |
|-----------|----------|---------|
| History Manager | `plugins/harness-eval/scripts/history.sh` | Evaluation result tracking over time (`.harness-eval/history.json`, `latest.json`) |
| Run Directory | `.harness-eval/run/` (target project) | Intermediate files passed between Full phases by path; rewritten each run |
| Report Output | `.harness-eval/reports/` (target project) | Saved evaluation reports (one file per language) |

### Observability Layer

| Component | Location | Purpose |
|-----------|----------|---------|
| Session Hook | `.claude/hooks/session-context.sh` | Project context loading at session start |
| Doc-Sync Hook | `.claude/hooks/check-doc-sync.sh` | Missing documentation detection |
| Secret Scan Hook | `.claude/hooks/secret-scan.sh` | Pre-commit secret detection |
| Notification Hook | `.claude/hooks/notify.sh` | Webhook notifications for events |

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Monorepo Root                           │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │.claude-plugin│  │   .claude/   │  │     docs/        │  │
│  │              │  │              │  │                   │  │
│  │ marketplace  │  │ hooks        │  │ architecture     │  │
│  │  .json       │  │ skills       │  │ decisions/       │  │
│  │              │  │ commands     │  │ runbooks/        │  │
│  │              │  │ agents       │  │ onboarding       │  │
│  │              │  │ settings     │  │                   │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              plugins/harness-eval/                   │    │
│  │                                                     │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │    │
│  │  │commands/ │  │ skills/  │  │    agents/       │  │    │
│  │  │          │  │          │  │                   │  │    │
│  │  │ quick    │  │ quick/   │  │ collector        │  │    │
│  │  │ standard │  │ standard/│  │ completeness-eval│  │    │
│  │  │ full     │  │ full/    │  │ design-eval      │  │    │
│  │  │ compare  │  │ compare/ │  │ safety-eval      │  │    │
│  │  │          │  │          │  │ synthesizer      │  │    │
│  │  └────┬─────┘  └────┬─────┘  └────────┬─────────┘  │    │
│  │       │              │                  │            │    │
│  │       ▼              ▼                  ▼            │    │
│  │  ┌──────────────────────────────────────────────┐   │    │
│  │  │              scripts/                         │   │    │
│  │  │  scoring.sh  static-analysis.sh  history.sh  │   │    │
│  │  │  aggregate.sh  badge.sh  lib/grade.sh        │   │    │
│  │  └──────────────────────┬───────────────────────┘   │    │
│  │                         │                            │    │
│  │                         ▼                            │    │
│  │  ┌──────────────────────────────────────────────┐   │    │
│  │  │           templates/ + hooks/                 │   │    │
│  │  │  checklist.json  report-*.md  hooks.json      │   │    │
│  │  └──────────────────────────────────────────────┘   │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

```
User Command ▶ Skill (Quick/Standard/Full) ▶ Scripts (scoring/analysis) ▶ Report (en/ko)
Full: scripts ▶ .harness-eval/run/ ▶ collector ▶ 3 evaluators (parallel) ▶ synthesizer ▶ aggregate.sh ▶ history + en/ko report files
```

## Key Design Decisions

1. **Monorepo with marketplace packaging** — Keeps plugin code alongside marketplace manifest and dev tooling in one repo. See [ADR-001](../plugins/harness-eval/docs/decisions/ADR-001-marketplace-monorepo.md).
2. **Auto-discovery convention** — Plugin uses directory-based auto-discovery (`skills/<name>/SKILL.md`) instead of explicit registration in plugin.json. See [ADR-002](../plugins/harness-eval/docs/decisions/ADR-002-auto-discovery-convention.md).
3. **3-tier evaluation** — Quick (~30s checklist), Standard (~2-3min static+dynamic), Full (~5-10min multi-agent) gives users flexibility to choose depth vs speed.
4. **Bilingual output** — All reports generate English and Korean simultaneously to serve the target user base.
5. **Bash-first scripting** — Scripts use bash + jq for portability across Claude Code environments without requiring Node.js or Python runtimes.
6. **Per-agent model and effort, file handoff** — Full-mode agents use the `opus` alias and each sets its own effort, so depth does not follow the session effort chosen with `/effort` or `effortLevel` (`CLAUDE_CODE_EFFORT_LEVEL` and effort caps still take precedence). Full phases pass script output and the collector's inventory as files by path, the three evaluator results travel inline to the synthesizer, and a script computes the score. No mode edits README.md without opt-in. See [ADR-003](../plugins/harness-eval/docs/decisions/ADR-003-opus-5-5-model-effort-and-file-handoff.md).

## Operations

- See [Onboarding Guide](onboarding.md) for new developer setup
- See [Plugin Runbooks](../plugins/harness-eval/docs/runbooks/) for operational procedures: [release](../plugins/harness-eval/docs/runbooks/release.md) and [model change](../plugins/harness-eval/docs/runbooks/model-change.md) (what to re-check when Claude's model line changes)
- See [Plugin Architecture](../plugins/harness-eval/docs/architecture.md) for plugin-level details

---

# 한국어

## 시스템 개요

harness-eval은 3단계 평가 시스템(Quick/Standard/Full)을 통해 하네스 엔지니어링 품질을 평가하는 Claude Code 마켓플레이스 플러그인 모노레포입니다. 모노레포는 플러그인(`plugins/harness-eval/`)을 마켓플레이스 패키징(`.claude-plugin/`)과 개발 도구(`.claude/`)로 감싸고 있습니다.

## 계층별 컴포넌트

### 프레젠테이션 계층

| 컴포넌트 | 위치 | 목적 |
|----------|------|------|
| 슬래시 커맨드 | `plugins/harness-eval/commands/` | 사용자 진입점 (`/harness-eval`, `/harness-eval:quick`, `/harness-eval:standard`, `/harness-eval:full`, `/harness-eval:compare`) |
| 템플릿 | `plugins/harness-eval/templates/` | 채점 입력 `checklist.json`. 리포트 형식 자체는 스킬과 synthesizer 에이전트에 정의됨 |
| 뱃지 생성기 | `plugins/harness-eval/scripts/badge.sh` | README 삽입용 등급 뱃지 (opt-in Stop 훅 또는 사용자가 실행) |

### 처리 계층

| 컴포넌트 | 위치 | 목적 |
|----------|------|------|
| 스킬 | `plugins/harness-eval/skills/` | 티어별 평가 로직 (quick, standard, full, compare) |
| 에이전트 | `plugins/harness-eval/agents/` | Full 모드 서브에이전트: collector(인벤토리 파일 작성), 읽기 전용 evaluator 3개, synthesizer(채점, 이력 저장, 리포트 작성) |
| 채점 엔진 | `plugins/harness-eval/scripts/scoring.sh` | 결정론적 체크리스트 채점 |
| 집계기 | `plugins/harness-eval/scripts/aggregate.sh` | Full 모드 12개 차원 결정론적 채점 (`scripts/lib/grade.sh`로 scoring.sh와 등급 임계값 공유) |
| 정적 분석기 | `plugins/harness-eval/scripts/static-analysis.sh` | 파일/코드 패턴 분석 (모델·effort 설정 포함) |

### 저장 계층

| 컴포넌트 | 위치 | 목적 |
|----------|------|------|
| 이력 관리자 | `plugins/harness-eval/scripts/history.sh` | 평가 결과 시계열 추적 (`.harness-eval/history.json`, `latest.json`) |
| 실행 디렉토리 | `.harness-eval/run/` (대상 프로젝트) | Full 단계 사이에 경로로 넘기는 중간 파일, 실행마다 새로 씀 |
| 리포트 출력 | `.harness-eval/reports/` (대상 프로젝트) | 저장된 평가 리포트 (언어별 파일) |

### 관측성 계층

| 컴포넌트 | 위치 | 목적 |
|----------|------|------|
| 세션 훅 | `.claude/hooks/session-context.sh` | 세션 시작 시 프로젝트 컨텍스트 로딩 |
| 문서 동기화 훅 | `.claude/hooks/check-doc-sync.sh` | 누락된 문서 감지 |
| 시크릿 스캔 훅 | `.claude/hooks/secret-scan.sh` | 커밋 전 시크릿 감지 |
| 알림 훅 | `.claude/hooks/notify.sh` | 이벤트 웹훅 알림 |

## 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                     모노레포 루트                             │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │.claude-plugin│  │   .claude/   │  │     docs/        │  │
│  │              │  │              │  │                   │  │
│  │ marketplace  │  │ hooks        │  │ architecture     │  │
│  │  .json       │  │ skills       │  │ decisions/       │  │
│  │              │  │ commands     │  │ runbooks/        │  │
│  │              │  │ agents       │  │ onboarding       │  │
│  │              │  │ settings     │  │                   │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              plugins/harness-eval/                   │    │
│  │                                                     │    │
│  │  commands/ ▶ skills/ ▶ agents/ ▶ scripts/           │    │
│  │                         │                            │    │
│  │                         ▼                            │    │
│  │              templates/ + hooks/                     │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 데이터 흐름 요약

```
사용자 커맨드 ▶ 스킬 (Quick/Standard/Full) ▶ 스크립트 (채점/분석) ▶ 리포트 (en/ko)
Full: 스크립트 ▶ .harness-eval/run/ ▶ collector ▶ evaluator 3개 (병렬) ▶ synthesizer ▶ aggregate.sh ▶ 이력 + en/ko 리포트 파일
```

## 주요 설계 결정

1. **마켓플레이스 패키징이 포함된 모노레포** — 플러그인 코드를 마켓플레이스 매니페스트, 개발 도구와 함께 하나의 저장소에 유지. [ADR-001](../plugins/harness-eval/docs/decisions/ADR-001-marketplace-monorepo.md) 참조.
2. **자동 검색 컨벤션** — plugin.json에 명시적 등록 대신 디렉토리 기반 자동 검색(`skills/<name>/SKILL.md`) 사용. [ADR-002](../plugins/harness-eval/docs/decisions/ADR-002-auto-discovery-convention.md) 참조.
3. **3단계 평가** — Quick (~30초 체크리스트), Standard (~2-3분 정적+동적), Full (~5-10분 멀티에이전트)으로 깊이 대 속도의 유연한 선택 제공.
4. **이중언어 출력** — 모든 리포트가 영어와 한국어를 동시에 생성하여 대상 사용자층 지원.
5. **Bash 우선 스크립팅** — Node.js나 Python 런타임 없이 Claude Code 환경 간 이식성을 위해 bash + jq 사용.
6. **에이전트별 모델·effort, 파일 handoff** — Full 모드 에이전트는 `opus` alias를 쓰고 각자 effort를 지정하므로 평가 깊이가 `/effort`나 `effortLevel`로 정한 세션 effort를 따라가지 않음(`CLAUDE_CODE_EFFORT_LEVEL`과 effort 상한은 여전히 우선함). Full 단계는 스크립트 출력과 collector 인벤토리를 파일 경로로 주고받고, evaluator 세 개의 결과는 synthesizer prompt에 그대로 전달하며, 점수는 스크립트가 계산. opt-in 없이는 어떤 모드도 README.md를 수정하지 않음. [ADR-003](../plugins/harness-eval/docs/decisions/ADR-003-opus-5-5-model-effort-and-file-handoff.md) 참조.

## 운영

- 신규 개발자 설정은 [온보딩 가이드](onboarding.md) 참조
- 운영 절차는 [플러그인 런북](../plugins/harness-eval/docs/runbooks/) 참조: [릴리스](../plugins/harness-eval/docs/runbooks/release.md), [모델 교체](../plugins/harness-eval/docs/runbooks/model-change.md)(Claude 모델 라인이 바뀔 때 다시 점검할 항목)
- 플러그인 수준 상세 내용은 [플러그인 아키텍처](../plugins/harness-eval/docs/architecture.md) 참조
