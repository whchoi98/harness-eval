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
| Slash Commands | `plugins/harness-eval/commands/` | User-facing entry points (`/harness-eval`, `/quick`, `/standard`, `/full`, `/compare`) |
| Report Templates | `plugins/harness-eval/templates/` | Bilingual Markdown report generation (en/ko) |
| Badge Generator | `plugins/harness-eval/scripts/badge.sh` | Visual grade badge for README embedding |

### Processing Layer

| Component | Location | Purpose |
|-----------|----------|---------|
| Skills | `plugins/harness-eval/skills/` | Evaluation logic per tier (quick, standard, full, compare) |
| Agents | `plugins/harness-eval/agents/` | Multi-agent orchestration for Full evaluation |
| Scoring Engine | `plugins/harness-eval/scripts/scoring.sh` | Deterministic checklist scoring |
| Static Analyzer | `plugins/harness-eval/scripts/static-analysis.sh` | File/code pattern analysis |

### Storage Layer

| Component | Location | Purpose |
|-----------|----------|---------|
| History Manager | `plugins/harness-eval/scripts/history.sh` | Evaluation result tracking over time |
| Report Output | `.harness-eval/reports/` (target project) | Saved evaluation reports |

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
User Command ▶ Skill (Quick/Standard/Full) ▶ Scripts (scoring/analysis) ▶ Templates ▶ Report (en/ko)
```

## Key Design Decisions

1. **Monorepo with marketplace packaging** — Keeps plugin code alongside marketplace manifest and dev tooling in one repo. See [ADR-001](../plugins/harness-eval/docs/decisions/ADR-001-marketplace-monorepo.md).
2. **Auto-discovery convention** — Plugin uses directory-based auto-discovery (`skills/<name>/SKILL.md`) instead of explicit registration in plugin.json. See [ADR-002](../plugins/harness-eval/docs/decisions/ADR-002-auto-discovery-convention.md).
3. **3-tier evaluation** — Quick (~30s checklist), Standard (~2-3min static+dynamic), Full (~5-10min multi-agent) gives users flexibility to choose depth vs speed.
4. **Bilingual output** — All reports generate English and Korean simultaneously to serve the target user base.
5. **Bash-first scripting** — Scripts use bash + jq for portability across Claude Code environments without requiring Node.js or Python runtimes.

## Operations

- See [Onboarding Guide](onboarding.md) for new developer setup
- See [Plugin Runbooks](../plugins/harness-eval/docs/runbooks/) for operational procedures
- See [Plugin Architecture](../plugins/harness-eval/docs/architecture.md) for plugin-level details

---

# 한국어

## 시스템 개요

harness-eval은 3단계 평가 시스템(Quick/Standard/Full)을 통해 하네스 엔지니어링 품질을 평가하는 Claude Code 마켓플레이스 플러그인 모노레포입니다. 모노레포는 플러그인(`plugins/harness-eval/`)을 마켓플레이스 패키징(`.claude-plugin/`)과 개발 도구(`.claude/`)로 감싸고 있습니다.

## 계층별 컴포넌트

### 프레젠테이션 계층

| 컴포넌트 | 위치 | 목적 |
|----------|------|------|
| 슬래시 커맨드 | `plugins/harness-eval/commands/` | 사용자 진입점 (`/harness-eval`, `/quick`, `/standard`, `/full`, `/compare`) |
| 리포트 템플릿 | `plugins/harness-eval/templates/` | 이중언어 Markdown 리포트 생성 (en/ko) |
| 배지 생성기 | `plugins/harness-eval/scripts/badge.sh` | README 삽입용 등급 배지 |

### 처리 계층

| 컴포넌트 | 위치 | 목적 |
|----------|------|------|
| 스킬 | `plugins/harness-eval/skills/` | 티어별 평가 로직 (quick, standard, full, compare) |
| 에이전트 | `plugins/harness-eval/agents/` | Full 평가 멀티에이전트 오케스트레이션 |
| 채점 엔진 | `plugins/harness-eval/scripts/scoring.sh` | 결정론적 체크리스트 채점 |
| 정적 분석기 | `plugins/harness-eval/scripts/static-analysis.sh` | 파일/코드 패턴 분석 |

### 저장 계층

| 컴포넌트 | 위치 | 목적 |
|----------|------|------|
| 이력 관리자 | `plugins/harness-eval/scripts/history.sh` | 평가 결과 시계열 추적 |
| 리포트 출력 | `.harness-eval/reports/` (대상 프로젝트) | 저장된 평가 리포트 |

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
사용자 커맨드 ▶ 스킬 (Quick/Standard/Full) ▶ 스크립트 (채점/분석) ▶ 템플릿 ▶ 리포트 (en/ko)
```

## 주요 설계 결정

1. **마켓플레이스 패키징이 포함된 모노레포** — 플러그인 코드를 마켓플레이스 매니페스트, 개발 도구와 함께 하나의 저장소에 유지. [ADR-001](../plugins/harness-eval/docs/decisions/ADR-001-marketplace-monorepo.md) 참조.
2. **자동 검색 컨벤션** — plugin.json에 명시적 등록 대신 디렉토리 기반 자동 검색(`skills/<name>/SKILL.md`) 사용. [ADR-002](../plugins/harness-eval/docs/decisions/ADR-002-auto-discovery-convention.md) 참조.
3. **3단계 평가** — Quick (~30초 체크리스트), Standard (~2-3분 정적+동적), Full (~5-10분 멀티에이전트)으로 깊이 대 속도의 유연한 선택 제공.
4. **이중언어 출력** — 모든 리포트가 영어와 한국어를 동시에 생성하여 대상 사용자층 지원.
5. **Bash 우선 스크립팅** — Node.js나 Python 런타임 없이 Claude Code 환경 간 이식성을 위해 bash + jq 사용.

## 운영

- 신규 개발자 설정은 [온보딩 가이드](onboarding.md) 참조
- 운영 절차는 [플러그인 런북](../plugins/harness-eval/docs/runbooks/) 참조
- 플러그인 수준 상세 내용은 [플러그인 아키텍처](../plugins/harness-eval/docs/architecture.md) 참조
