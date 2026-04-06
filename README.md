# harness-eval

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](.claude-plugin/plugin.json)
[![Bash](https://img.shields.io/badge/Bash-4%2B-brightgreen.svg)](#prerequisites)
[![English](https://img.shields.io/badge/lang-English-blue.svg)](#english)
[![한국어](https://img.shields.io/badge/lang-한국어-red.svg)](#한국어)

**A Claude Code plugin for systematic 3-tier evaluation of harness engineering quality**
**Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하는 플러그인**

---

# English

## Overview

harness-eval is a Claude Code plugin that systematically evaluates the engineering quality of Claude Code harness configurations. It combines deterministic script-based quantitative checks with AI agent-powered qualitative reviews through a 3-tier evaluation system (Quick / Standard / Full).

The plugin scores projects across 6 dimensions — correctness, safety, completeness, actionability, consistency, and testability — producing structured reports with letter grades (A+ through F) and improvement roadmaps.

## Features

- **3-Tier Evaluation System** — Choose evaluation depth: Quick (< 30s checklist), Standard (static + dynamic analysis), or Full (multi-agent parallel review)
- **Multi-Agent Analysis** — Full mode dispatches 5 specialized agents (collector, safety-evaluator, completeness-evaluator, design-evaluator, synthesizer) for comprehensive assessment
- **Evaluation History Tracking** — Save, list, and compare evaluation results over time with trend analysis and delta reporting
- **Badge Generation** — Automatically generate score-based badges (A+ through F) in SVG and Markdown formats
- **4-Level Test Fixtures** — Validate scoring accuracy across minimal, functional, robust, and production maturity levels

## Prerequisites

- Bash 4+
- jq 1.6+
- Python 3.6+
- Git
- Claude Code CLI

## Installation

### Via Marketplace (Recommended)

```bash
# Register the marketplace
claude plugin marketplace add https://github.com/whchoi98/harness-eval

# Install the plugin
claude plugin install harness-eval@harness-eval
```

After installation, the `/harness-eval` command becomes available in all Claude Code sessions.

To verify the installation:

```bash
# List installed plugins
claude plugin list
```

To uninstall:

```bash
claude plugin remove harness-eval
```

### From Source (For Development)

```bash
# Clone the repository
git clone https://github.com/whchoi98/harness-eval.git

# Navigate to the project directory
cd harness-eval

# Run the setup script
bash scripts/setup.sh
```

## Usage

Invoke the evaluation through the `/harness-eval` slash command or directly via skills:

```bash
# Quick evaluation — checklist-based, < 30 seconds
/harness-eval quick

# Standard evaluation — static + dynamic analysis
/harness-eval standard

# Full evaluation — multi-agent comprehensive review
/harness-eval full

# Compare two evaluations
/harness-eval compare
```

Run evaluation scripts directly:

```bash
# Score a target project
HARNESS_EVAL_ROOT=$(pwd) bash scripts/scoring.sh /path/to/target-project
# Output: {"score": 7.2, "grade": "B", "checks": [...]}

# Run static analysis
HARNESS_EVAL_ROOT=$(pwd) bash scripts/static-analysis.sh /path/to/target-project
# Output: {"summary": {"pass": 12, "warn": 1, "fail": 0, "total": 13}, ...}

# View evaluation history
HARNESS_EVAL_ROOT=$(pwd) bash scripts/history.sh list /path/to/target-project
# Output: [{"id": "eval-2026-04-06-001", "score": 7.2, ...}]

# Generate badge
bash scripts/badge.sh /path/to/target-project
# Output: Badge SVG/Markdown
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `HARNESS_EVAL_ROOT` | Path to the harness-eval plugin root directory | (required) |
| `CLAUDE_NOTIFY_WEBHOOK` | Webhook URL for evaluation completion notifications | (empty, disabled) |

## Project Structure

```
harness-eval/                            # Marketplace + Plugin monorepo
├── .claude-plugin/
│   └── marketplace.json                 # Marketplace catalog
├── README.md
├── CHANGELOG.md
├── LICENSE
│
├── plugins/harness-eval/                # Plugin root
│   ├── .claude-plugin/
│   │   └── plugin.json                  # Plugin manifest (metadata only)
│   ├── CLAUDE.md                        # Project context and conventions
│   │
│   ├── scripts/                         # Deterministic evaluation scripts
│   │   ├── scoring.sh                   # Checklist-based scoring engine
│   │   ├── static-analysis.sh           # Syntax, validity, permissions checks
│   │   ├── history.sh                   # Evaluation history and trend analysis
│   │   └── badge.sh                     # Score-to-badge conversion (A+ ~ F)
│   │
│   ├── agents/                          # Subagents for Full mode evaluation
│   │   ├── collector.md                 # Target project data gathering
│   │   ├── safety-evaluator.md          # Tool scope and secret safety
│   │   ├── completeness-evaluator.md    # Coverage and error recovery
│   │   ├── design-evaluator.md          # Architecture quality review
│   │   └── synthesizer.md               # Result aggregation and reporting
│   │
│   ├── skills/                          # User-facing evaluation entry points
│   │   ├── quick/SKILL.md               # Fast checklist evaluation
│   │   ├── standard/SKILL.md            # Standard analysis evaluation
│   │   ├── full/SKILL.md                # Multi-agent orchestrator
│   │   └── compare/SKILL.md             # Comparative analysis
│   │
│   ├── commands/                        # Slash command definition
│   │   └── harness-eval.md              # /harness-eval command router
│   │
│   ├── hooks/                           # Plugin-provided hooks
│   │   ├── hooks.json                   # Hook event registration
│   │   └── post-eval-badge.sh           # Auto badge on evaluation completion
│   │
│   ├── templates/                       # Evaluation templates
│   │   ├── checklist.json               # Check definitions (Quick/Standard)
│   │   ├── report-full.md               # Full report template
│   │   └── report-component.md          # Component report template
│   │
│   ├── tests/                           # Automated test suite
│   │   ├── test-scoring.sh              # Scoring script tests (15 tests)
│   │   ├── test-static-analysis.sh      # Static analysis tests (23 tests)
│   │   ├── test-history.sh              # History management tests (19 tests)
│   │   ├── harness-run-all.sh           # Harness validation runner
│   │   ├── hooks/                       # Hook validation tests
│   │   ├── structure/                   # Plugin structure tests
│   │   └── fixtures/                    # 4-level maturity mock projects
│   │
│   └── docs/                            # Documentation
│       ├── architecture.md              # System architecture (bilingual)
│       ├── onboarding.md                # Developer onboarding guide
│       ├── decisions/                   # Architecture Decision Records
│       └── runbooks/                    # Operational runbooks
│
└── .claude/                             # Development-time Claude settings
    ├── settings.json                    # Hook registrations and deny list
    ├── hooks/                           # Dev hooks (doc-sync, secret-scan, etc.)
    ├── skills/                          # Dev skills (code-review, refactor, etc.)
    ├── commands/                        # Dev commands (review, test-all, deploy)
    └── agents/                          # Dev agents (code-reviewer, security-auditor)
```

## Testing

```bash
# Run all evaluation script tests (57 tests)
cd plugins/harness-eval
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh

# Run harness validation tests
bash tests/harness-run-all.sh

# Run specific test category
bash tests/harness-run-all.sh hooks       # Hook tests only
bash tests/harness-run-all.sh structure   # Structure tests only
```

## Contributing

1. Fork the repository.
2. Create a feature branch.
   ```bash
   git checkout -b feat/add-new-check
   ```
3. Commit your changes using Conventional Commits.
   ```bash
   git commit -m "feat: add new security check for CORS configuration"
   ```
4. Push to your branch.
   ```bash
   git push origin feat/add-new-check
   ```
5. Open a Pull Request against `main`.

When adding new evaluation checks:
- Add the check definition to `templates/checklist.json`
- Add corresponding logic to the appropriate script in `scripts/`
- Add test cases covering the new check
- Update `CLAUDE.md` if conventions change

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

- **Maintainer**: WooHyung Choi
- **Email**: whchoi98@gmail.com
- **Issues**: [GitHub Issues](https://github.com/whchoi98/harness-eval/issues)

---

# 한국어

## 개요

harness-eval은 Claude Code 하네스 구성의 엔지니어링 품질을 체계적으로 평가하는 Claude Code 플러그인입니다. 결정론적 스크립트 기반 정량 검사와 AI 에이전트 기반 정성 리뷰를 3단계 평가 체계(Quick / Standard / Full)로 결합합니다.

6개 차원(정확성, 안전성, 완전성, 실행 가능성, 일관성, 검증 가능성)에 걸쳐 프로젝트를 평가하고, 등급(A+~F)이 포함된 구조화된 보고서와 개선 로드맵을 제공합니다.

## 주요 기능

- **3단계 평가 체계** — 평가 깊이를 선택합니다: Quick (30초 미만 체크리스트), Standard (정적+동적 분석), Full (멀티 에이전트 병렬 리뷰)
- **멀티 에이전트 분석** — Full 모드에서 5개 전문 에이전트(collector, safety-evaluator, completeness-evaluator, design-evaluator, synthesizer)를 배치하여 종합 평가를 수행합니다
- **평가 이력 추적** — 평가 결과를 저장, 조회, 비교하며 추세 분석과 델타 리포팅을 제공합니다
- **뱃지 생성** — 점수 기반 뱃지(A+~F)를 SVG 및 Markdown 형식으로 자동 생성합니다
- **4단계 테스트 픽스처** — minimal, functional, robust, production 성숙도 수준별로 점수 정확성을 검증합니다

## 사전 요구 사항

- Bash 4+
- jq 1.6+
- Python 3.6+
- Git
- Claude Code CLI

## 설치 방법

### 마켓플레이스를 통한 설치 (권장)

```bash
# 마켓플레이스 등록
claude plugin marketplace add https://github.com/whchoi98/harness-eval

# 플러그인 설치
claude plugin install harness-eval@harness-eval
```

설치 후 모든 Claude Code 세션에서 `/harness-eval` 커맨드를 사용할 수 있습니다.

설치 확인:

```bash
# 설치된 플러그인 목록 조회
claude plugin list
```

제거:

```bash
claude plugin remove harness-eval
```

### 소스에서 설치 (개발용)

```bash
# 저장소 클론
git clone https://github.com/whchoi98/harness-eval.git

# 프로젝트 디렉토리로 이동
cd harness-eval

# 설정 스크립트 실행
bash scripts/setup.sh
```

## 사용법

`/harness-eval` 슬래시 커맨드 또는 스킬을 통해 평가를 실행합니다:

```bash
# Quick 평가 — 체크리스트 기반, 30초 미만
/harness-eval quick

# Standard 평가 — 정적 + 동적 분석
/harness-eval standard

# Full 평가 — 멀티 에이전트 종합 리뷰
/harness-eval full

# 두 평가 비교
/harness-eval compare
```

평가 스크립트를 직접 실행할 수도 있습니다:

```bash
# 대상 프로젝트 점수 산출
HARNESS_EVAL_ROOT=$(pwd) bash scripts/scoring.sh /path/to/target-project
# 출력: {"score": 7.2, "grade": "B", "checks": [...]}

# 정적 분석 실행
HARNESS_EVAL_ROOT=$(pwd) bash scripts/static-analysis.sh /path/to/target-project
# 출력: {"summary": {"pass": 12, "warn": 1, "fail": 0, "total": 13}, ...}

# 평가 이력 조회
HARNESS_EVAL_ROOT=$(pwd) bash scripts/history.sh list /path/to/target-project
# 출력: [{"id": "eval-2026-04-06-001", "score": 7.2, ...}]

# 뱃지 생성
bash scripts/badge.sh /path/to/target-project
# 출력: Badge SVG/Markdown
```

## 환경 설정

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `HARNESS_EVAL_ROOT` | harness-eval 플러그인 루트 디렉토리 경로 | (필수) |
| `CLAUDE_NOTIFY_WEBHOOK` | 평가 완료 알림을 위한 웹훅 URL | (비어 있음, 비활성) |

## 프로젝트 구조

```
harness-eval/                            # 마켓플레이스 + 플러그인 모노레포
├── .claude-plugin/
│   └── marketplace.json                 # 마켓플레이스 카탈로그
├── README.md
├── CHANGELOG.md
├── LICENSE
│
├── plugins/harness-eval/                # 플러그인 루트
│   ├── .claude-plugin/
│   │   └── plugin.json                  # 플러그인 매니페스트 (메타데이터)
│   ├── CLAUDE.md                        # 프로젝트 컨텍스트 및 규칙
│   │
│   ├── scripts/                         # 결정론적 평가 스크립트
│   │   ├── scoring.sh                   # 체크리스트 기반 점수 산출 엔진
│   │   ├── static-analysis.sh           # 문법, 유효성, 권한 검사
│   │   ├── history.sh                   # 평가 이력 및 추세 분석
│   │   └── badge.sh                     # 점수→뱃지 변환 (A+ ~ F)
│   │
│   ├── agents/                          # Full 모드 서브에이전트
│   │   ├── collector.md                 # 대상 프로젝트 데이터 수집
│   │   ├── safety-evaluator.md          # 도구 범위 및 시크릿 안전성
│   │   ├── completeness-evaluator.md    # 커버리지 및 에러 복구
│   │   ├── design-evaluator.md          # 아키텍처 품질 리뷰
│   │   └── synthesizer.md               # 결과 종합 및 보고서 생성
│   │
│   ├── skills/                          # 사용자 대면 평가 진입점
│   │   ├── quick/SKILL.md               # 빠른 체크리스트 평가
│   │   ├── standard/SKILL.md            # 표준 분석 평가
│   │   ├── full/SKILL.md                # 멀티 에이전트 오케스트레이터
│   │   └── compare/SKILL.md             # 비교 분석
│   │
│   ├── commands/                        # 슬래시 커맨드 정의
│   │   └── harness-eval.md              # /harness-eval 커맨드 라우터
│   │
│   ├── hooks/                           # 플러그인 제공 훅
│   │   ├── hooks.json                   # 훅 이벤트 등록
│   │   └── post-eval-badge.sh           # 평가 완료 시 자동 뱃지 생성
│   │
│   ├── templates/                       # 평가 템플릿
│   │   ├── checklist.json               # 체크 항목 정의 (Quick/Standard)
│   │   ├── report-full.md               # Full 보고서 템플릿
│   │   └── report-component.md          # 구성 요소 보고서 템플릿
│   │
│   ├── tests/                           # 자동화 테스트 스위트
│   │   ├── test-scoring.sh              # 점수 산출 테스트 (15개)
│   │   ├── test-static-analysis.sh      # 정적 분석 테스트 (23개)
│   │   ├── test-history.sh              # 이력 관리 테스트 (19개)
│   │   ├── harness-run-all.sh           # 하네스 검증 러너
│   │   ├── hooks/                       # 훅 검증 테스트
│   │   ├── structure/                   # 플러그인 구조 테스트
│   │   └── fixtures/                    # 4단계 성숙도 모의 프로젝트
│   │
│   └── docs/                            # 문서
│       ├── architecture.md              # 시스템 아키텍처 (이중 언어)
│       ├── onboarding.md                # 개발자 온보딩 가이드
│       ├── decisions/                   # 아키텍처 결정 기록 (ADR)
│       └── runbooks/                    # 운영 런북
│
└── .claude/                             # 개발용 Claude 설정
    ├── settings.json                    # 훅 등록 및 deny 목록
    ├── hooks/                           # 개발용 훅 (doc-sync, secret-scan 등)
    ├── skills/                          # 개발용 스킬 (code-review, refactor 등)
    ├── commands/                        # 개발용 커맨드 (review, test-all, deploy)
    └── agents/                          # 개발용 에이전트 (code-reviewer, security-auditor)
```

## 테스트

```bash
# 평가 스크립트 테스트 전체 실행 (57개)
cd plugins/harness-eval
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh

# 하네스 검증 테스트 실행
bash tests/harness-run-all.sh

# 특정 카테고리 테스트
bash tests/harness-run-all.sh hooks       # 훅 테스트만
bash tests/harness-run-all.sh structure   # 구조 테스트만
```

전체 테스트 커버리지: 4개 테스트 스위트, **총 154개 테스트**.

## 기여 방법

1. 저장소를 Fork합니다.
2. 기능 브랜치를 생성합니다.
   ```bash
   git checkout -b feat/add-new-check
   ```
3. Conventional Commits 형식으로 커밋합니다.
   ```bash
   git commit -m "feat: CORS 설정 보안 체크 추가"
   ```
4. 브랜치에 Push합니다.
   ```bash
   git push origin feat/add-new-check
   ```
5. `main` 브랜치를 대상으로 Pull Request를 생성합니다.

새 평가 체크를 추가할 때:
- `templates/checklist.json`에 체크 정의를 추가합니다
- `scripts/`의 해당 스크립트에 로직을 추가합니다
- 새 체크를 커버하는 테스트 케이스를 추가합니다
- 규칙이 변경되면 `CLAUDE.md`를 업데이트합니다

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 연락처

- **메인테이너**: WooHyung Choi
- **이메일**: whchoi98@gmail.com
- **이슈**: [GitHub Issues](https://github.com/whchoi98/harness-eval/issues)
