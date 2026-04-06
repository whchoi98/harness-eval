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
사용자는 스킬을 통해 평가를 시작하고, 결과는 구조화된 보고서와 뱃지로 제공된다.

## Components

### Evaluation Layer (정량 분석)
- **scripts/scoring.sh** -- 체크리스트 기반 점수 산출. Quick/Standard 모드 지원.
- **scripts/static-analysis.sh** -- Bash 문법, JSON 유효성, 파일 권한, 등록 일관성 검증.
- **scripts/history.sh** -- 평가 이력 저장 및 추세 분석. JSON 기반 이력 파일 관리.
- **scripts/badge.sh** -- 점수 기반 뱃지(A+~F) SVG/마크다운 생성.

### Orchestration Layer (스킬)
- **skills/quick.md** -- 빠른 체크리스트 기반 평가 (< 30초).
- **skills/standard.md** -- 정적+동적 분석 포함 표준 평가.
- **skills/full.md** -- 멀티 에이전트 병렬 평가 오케스트레이터.
- **skills/compare.md** -- 두 평가 간 비교 분석.

### Analysis Layer (에이전트)
- **agents/collector.md** -- 대상 프로젝트 정보 수집 (파일 구조, 설정, 스크립트).
- **agents/safety-evaluator.md** -- 도구 범위, deny 목록, 시크릿 패턴 안전성 평가.
- **agents/completeness-evaluator.md** -- 이벤트 커버리지, 에러 복구, 문서 완전성 평가.
- **agents/design-evaluator.md** -- 아키텍처 품질, 모듈성, 출력 스키마 설계 평가.
- **agents/synthesizer.md** -- 개별 평가 결과를 종합 보고서로 합성.

### Presentation Layer (출력)
- **templates/checklist.json** -- Quick/Standard 모드 체크 항목 정의.
- **templates/report-full.md** -- Full 모드 보고서 템플릿.
- **templates/report-component.md** -- 구성 요소별 보고서 템플릿.

### Validation Layer (테스트)
- **tests/test-scoring.sh** -- 점수 산출 스크립트 검증.
- **tests/test-static-analysis.sh** -- 정적 분석 스크립트 검증.
- **tests/test-history.sh** -- 이력 관리 스크립트 검증.
- **tests/fixtures/** -- 4단계 성숙도 모의 프로젝트 (minimal, functional, robust, production).

### Entry Point
- **commands/harness-eval.md** -- `/harness-eval` 슬래시 커맨드.
- **hooks/post-eval-badge.sh** -- 평가 완료 후 뱃지 자동 생성 (Stop 이벤트).

## Full Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    Entry Points                              │
│                                                              │
│  ┌─────────────────┐    ┌────────────────────────┐           │
│  │ /harness-eval   │    │ Stop Hook              │           │
│  │ (command)       │───▶│ (post-eval-badge.sh)   │           │
│  └────────┬────────┘    └────────────────────────┘           │
└───────────┼──────────────────────────────────────────────────┘
            ▼
┌──────────────────────────────────────────────────────────────┐
│                 Orchestration (Skills)                        │
│                                                              │
│  ┌──────┐  ┌──────────┐  ┌──────┐  ┌─────────┐             │
│  │Quick │  │Standard  │  │Full  │  │Compare  │             │
│  │      │  │          │  │      │  │         │             │
│  └──┬───┘  └────┬─────┘  └──┬───┘  └─────────┘             │
└─────┼───────────┼────────────┼───────────────────────────────┘
      │           │            │
      ▼           ▼            ▼
┌─────────────────────────┐  ┌─────────────────────────────────┐
│   Evaluation Scripts    │  │        Analysis Agents           │
│                         │  │                                  │
│  ┌─────────┐ ┌────────┐│  │ ┌──────────┐  ┌──────────────┐ │
│  │scoring  │ │static- ││  │ │collector │─▶│safety-eval   │ │
│  │.sh      │ │analysis││  │ └──────────┘  ├──────────────┤ │
│  └─────────┘ │.sh     ││  │              │completeness  │ │
│  ┌─────────┐ └────────┘│  │              │-eval         │ │
│  │history  │ ┌────────┐│  │              ├──────────────┤ │
│  │.sh      │ │badge.sh││  │              │design-eval   │ │
│  └─────────┘ └────────┘│  │              └──────┬───────┘ │
└─────────────────────────┘  │                     ▼         │
                             │              ┌──────────────┐ │
                             │              │synthesizer   │ │
                             │              └──────────────┘ │
                             └─────────────────────────────────┘
                                            │
                             ┌──────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    Output (Templates)                         │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐ │
│  │checklist.json│  │report-full.md│  │report-component.md │ │
│  └──────────────┘  └──────────────┘  └────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

```
User -> /harness-eval -> Skill (Quick|Standard|Full)
                           |
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
       scoring.sh    static-analysis.sh  agents/*
           |               |               |
           └───────────────┼───────────────┘
                           ▼
                    Synthesizer -> Report + Badge
```

## Key Design Decisions

- **3단계 평가 체계** -- 빠른 피드백(Quick)부터 심층 분석(Full)까지 사용자가 시간/깊이를 선택할 수 있도록 설계
- **하이브리드 접근** -- 정량적 체크(스크립트)와 정성적 리뷰(에이전트)를 분리하여 각각의 강점을 활용
- **생성/평가 분리** -- collector가 데이터를 수집하고 evaluator가 독립적으로 평가하여 편향 방지
- **JSON stdout / stderr 로그** -- 스크립트 출력을 기계 판독 가능하게 유지하면서 사람용 로그는 stderr로 분리
- **4단계 테스트 픽스처** -- minimal → functional → robust → production 성숙도 스펙트럼으로 점수 차이를 검증

## Operations
- Evaluation: see `skills/quick.md`, `skills/standard.md`, `skills/full.md`
- Test: `bash tests/run-all.sh`

---

# English

## System Overview

harness-eval is a plugin that systematically evaluates Claude Code harness engineering quality.
It combines quantitative script analysis with qualitative agent review through a 3-tier evaluation system (Quick/Standard/Full).
Users initiate evaluations via skills, and results are delivered as structured reports with badges.

## Components

### Evaluation Layer (Quantitative Analysis)
- **scripts/scoring.sh** -- Checklist-based scoring. Supports Quick/Standard modes.
- **scripts/static-analysis.sh** -- Bash syntax, JSON validity, file permissions, registration consistency checks.
- **scripts/history.sh** -- Evaluation history storage and trend analysis. JSON-based history file management.
- **scripts/badge.sh** -- Score-based badge (A+ to F) SVG/markdown generation.

### Orchestration Layer (Skills)
- **skills/quick.md** -- Fast checklist-based evaluation (< 30 seconds).
- **skills/standard.md** -- Standard evaluation with static + dynamic analysis.
- **skills/full.md** -- Multi-agent parallel evaluation orchestrator.
- **skills/compare.md** -- Comparative analysis between two evaluations.

### Analysis Layer (Agents)
- **agents/collector.md** -- Target project information gathering (file structure, settings, scripts).
- **agents/safety-evaluator.md** -- Tool scope, deny list, secret pattern safety evaluation.
- **agents/completeness-evaluator.md** -- Event coverage, error recovery, documentation completeness evaluation.
- **agents/design-evaluator.md** -- Architecture quality, modularity, output schema design evaluation.
- **agents/synthesizer.md** -- Synthesizes individual evaluation results into a comprehensive report.

### Presentation Layer (Output)
- **templates/checklist.json** -- Check item definitions for Quick/Standard modes.
- **templates/report-full.md** -- Full mode report template.
- **templates/report-component.md** -- Component-level report template.

### Validation Layer (Tests)
- **tests/test-scoring.sh** -- Scoring script verification.
- **tests/test-static-analysis.sh** -- Static analysis script verification.
- **tests/test-history.sh** -- History management script verification.
- **tests/fixtures/** -- 4-level maturity mock projects (minimal, functional, robust, production).

### Entry Point
- **commands/harness-eval.md** -- `/harness-eval` slash command.
- **hooks/post-eval-badge.sh** -- Auto badge generation after evaluation (Stop event).

## Full Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    Entry Points                              │
│                                                              │
│  ┌─────────────────┐    ┌────────────────────────┐           │
│  │ /harness-eval   │    │ Stop Hook              │           │
│  │ (command)       │───▶│ (post-eval-badge.sh)   │           │
│  └────────┬────────┘    └────────────────────────┘           │
└───────────┼──────────────────────────────────────────────────┘
            ▼
┌──────────────────────────────────────────────────────────────┐
│                 Orchestration (Skills)                        │
│                                                              │
│  ┌──────┐  ┌──────────┐  ┌──────┐  ┌─────────┐             │
│  │Quick │  │Standard  │  │Full  │  │Compare  │             │
│  └──┬───┘  └────┬─────┘  └──┬───┘  └─────────┘             │
└─────┼───────────┼────────────┼───────────────────────────────┘
      │           │            │
      ▼           ▼            ▼
┌─────────────────────────┐  ┌─────────────────────────────────┐
│   Evaluation Scripts    │  │        Analysis Agents           │
│                         │  │                                  │
│  ┌─────────┐ ┌────────┐│  │ ┌──────────┐  ┌──────────────┐ │
│  │scoring  │ │static- ││  │ │collector │─▶│safety-eval   │ │
│  │.sh      │ │analysis││  │ └──────────┘  ├──────────────┤ │
│  └─────────┘ │.sh     ││  │              │completeness  │ │
│  ┌─────────┐ └────────┘│  │              │-eval         │ │
│  │history  │ ┌────────┐│  │              ├──────────────┤ │
│  │.sh      │ │badge.sh││  │              │design-eval   │ │
│  └─────────┘ └────────┘│  │              └──────┬───────┘ │
└─────────────────────────┘  │                     ▼         │
                             │              ┌──────────────┐ │
                             │              │synthesizer   │ │
                             │              └──────────────┘ │
                             └─────────────────────────────────┘
                                            │
                             ┌──────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    Output (Templates)                         │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐ │
│  │checklist.json│  │report-full.md│  │report-component.md │ │
│  └──────────────┘  └──────────────┘  └────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

```
User -> /harness-eval -> Skill (Quick|Standard|Full)
                           |
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
       scoring.sh    static-analysis.sh  agents/*
           |               |               |
           └───────────────┼───────────────┘
                           ▼
                    Synthesizer -> Report + Badge
```

## Key Design Decisions

- **3-tier evaluation system** -- Lets users choose speed vs depth, from quick feedback (Quick) to deep analysis (Full)
- **Hybrid approach** -- Separates quantitative checks (scripts) from qualitative review (agents) to leverage each strength
- **Generation/evaluation separation** -- Collector gathers data, evaluators assess independently to prevent bias
- **JSON stdout / stderr logging** -- Keeps script output machine-readable while human logs go to stderr
- **4-level test fixtures** -- minimal -> functional -> robust -> production maturity spectrum verifies score differentiation

## Operations
- Evaluation: see `skills/quick.md`, `skills/standard.md`, `skills/full.md`
- Test: `bash tests/run-all.sh`
