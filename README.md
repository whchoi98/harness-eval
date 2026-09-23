# harness-eval

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.3.0-green.svg)](plugins/harness-eval/.claude-plugin/plugin.json)
[![Bash](https://img.shields.io/badge/Bash-4%2B-brightgreen.svg)](#prerequisites)
[![English](https://img.shields.io/badge/lang-English-blue.svg)](#english)
[![한국어](https://img.shields.io/badge/lang-한국어-red.svg)](#한국어)

**A Claude Code plugin for systematic 3-tier evaluation of harness engineering quality**
**Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하는 플러그인**

---

# English

## Overview

harness-eval is a Claude Code plugin that systematically evaluates the engineering quality of Claude Code harness configurations. It combines deterministic script-based quantitative checks with AI agent-powered qualitative reviews through a 3-tier evaluation system (Quick / Standard / Full).

The plugin scores projects across 12 dimensions in 3 categories — Basic Quality (correctness, safety, completeness, consistency), Operational (actionability, testability, cost efficiency, contract-based testing), and Design Quality (agent communication, context management, feedback loop maturity, evolvability) — producing structured reports with letter grades (A+ through F) and improvement roadmaps.

## Features

- **3-Tier Evaluation System** — Choose evaluation depth: Quick (< 30s checklist), Standard (static + dynamic analysis), or Full (multi-agent parallel review)
- **Multi-Agent Analysis** — Full mode dispatches 5 specialized agents (collector, safety-evaluator, completeness-evaluator, design-evaluator, synthesizer) for comprehensive assessment, and computes the final score with a script (`aggregate.sh`)
- **Model and Effort Checks** — Static analysis reads the model and effort settings in `.claude/`, in each plugin root's agents, skills, and commands, and in settings. It flags retired, deprecated, and unrecognized model IDs, dated Anthropic API snapshot IDs, invalid effort values, and thinking caps (`model-config`), and agent files Claude Code never loads (`agent-format`)
- **Evaluation History Tracking** — Save, list, and compare evaluation results over time with trend analysis and delta reporting
- **Badge Generation** — Generate score-based badges (A+ through F) in SVG and Markdown formats; no evaluation mode edits your README unless you opt in
- **Test Fixtures** — Validate scoring accuracy across minimal, functional, robust, and production maturity levels, plus regression fixtures for the nested hook schema and for model settings

## Prerequisites

- Bash 4+
- jq 1.6+
- Python 3.6+
- Git
- Claude Code CLI

## Installation

### Install

From the terminal (shell):

```bash
claude plugin marketplace add https://github.com/whchoi98/harness-eval
claude plugin install harness-eval@harness-eval
```

Or from inside a Claude Code session:

```
/plugin marketplace add https://github.com/whchoi98/harness-eval
/plugin install harness-eval@harness-eval
```

### Verify

From the terminal:

```bash
claude plugin list
```

Or from inside a Claude Code session:

```
/plugin list
```

### Update

From the terminal:

```bash
claude plugin marketplace update harness-eval
claude plugin update harness-eval@harness-eval
```

Restart Claude Code afterwards to load the new version.

Or from inside a Claude Code session:

```
/plugin marketplace update harness-eval
/plugin install harness-eval@harness-eval
```

### Uninstall

From the terminal:

```bash
claude plugin remove harness-eval
claude plugin marketplace remove harness-eval
```

Or from inside a Claude Code session:

```
/plugin remove harness-eval
/plugin marketplace remove harness-eval
```

### From Source (For Development)

```bash
git clone https://github.com/whchoi98/harness-eval.git
cd harness-eval/plugins/harness-eval
bash scripts/setup.sh
```

## Usage

Run evaluations from inside a Claude Code session:

```
/harness-eval:quick              # Checklist-based scoring (~30s)
/harness-eval:standard           # Static + dynamic analysis (~2-3min)
/harness-eval:full               # Multi-agent comprehensive review (~5-10min)
/harness-eval:compare            # Compare with previous evaluation
/harness-eval:harness-eval full  # Argument style also works
```

> **Trust requirement (Standard and Full modes):** Standard mode's dynamic-analysis phase *executes code from the target project* — its `.claude/hooks/` scripts and its test suite — on your machine. Only run it against a repository you trust. The skill lists what would run and asks you in chat to confirm before executing any target code; this is the skill's own question, not a Claude Code permission prompt, because `/harness-eval:standard` pre-approves Bash. To evaluate an untrusted repository without running its code, pass `--static-only` (or `--no-dynamic`), which performs static analysis and scoring only. Quick mode never executes target code. Full mode does not run the target's hooks or tests, but its collector and synthesizer agents have Bash while they read the target's files, and `/harness-eval:full` pre-approves the Bash commands its orchestrator runs — see [SECURITY.md](SECURITY.md).

Reports are written to `.harness-eval/reports/` in the target project as separate English and Korean files. Standard and Full also write intermediate files to `.harness-eval/run/` (Full passes the script output and the collector's inventory there by path), and every run rewrites them. When `.harness-eval/` has no `.gitignore`, Standard and Full create one containing `*`, so git ignores everything in it; an existing `.gitignore` there is left unchanged. Quick does not create it, so if you have only run Quick, keep `.harness-eval/reports/` out of your commits yourself.

No evaluation mode changes your README. The plugin's Stop hook updates the README badge after a Standard or Full run only if you opt in (`HARNESS_EVAL_AUTO_BADGE=1`, or `{"autoBadge": true}` in an untracked `.harness-eval/config.json`; a copy tracked by git does not count). It acts once per saved evaluation, at the end of the response that saved it, and never writes through a symlinked `README.md`. Otherwise run `badge.sh` yourself.

Run evaluation scripts directly:

```bash
# Score a target project
HARNESS_EVAL_ROOT=$(pwd) bash scripts/scoring.sh /path/to/target-project
# Output: {"mode": "quick", "scores": {"overall": 7.2, "grade": "B"}, "checklist": {...}, "results": [...], "timestamp": "..."}

# Run static analysis
HARNESS_EVAL_ROOT=$(pwd) bash scripts/static-analysis.sh /path/to/target-project
# Output: {"summary": {"pass": 12, "warn": 1, "fail": 0, "total": 13}, "categories": {...}, ...}

# View evaluation history (target project first, then subcommand)
HARNESS_EVAL_ROOT=$(pwd) bash scripts/history.sh /path/to/target-project list
# Output: [{"id": "eval-2026-04-06-001", "timestamp": "...", "mode": "standard", "overall": 7.2, "grade": "B"}]

# Aggregate Full-mode dimension scores (JSON on stdin; each of the 12 keys 0-10 or null)
bash scripts/aggregate.sh <<'EOF'
{"dimensions": {"correctness": 9, "safety": 8, "completeness": 7, "consistency": 9}}
EOF
# Output: {"timestamp": "...", "mode": "full", "scores": {"overall": 8.2, "grade": "B+"}, "dimensions": {...}, "categories": {"basicQuality": 8.25, "operational": null, "designQuality": null}, "status": {...}, "missing": ["actionability", ...]}

# Generate badge (rewrites or creates the target's README.md)
bash scripts/badge.sh /path/to/target-project
# Output: Badge SVG/Markdown
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `HARNESS_EVAL_ROOT` | Path to the harness-eval plugin root directory | optional; `scoring.sh` and `static-analysis.sh` detect it from their own location |
| `HARNESS_EVAL_AUTO_BADGE` | Set to `1` to let the Stop hook update the README badge after a Standard or Full run (same as `{"autoBadge": true}` in an untracked `.harness-eval/config.json`) | unset (off) |

> **Note:** `CLAUDE_NOTIFY_WEBHOOK` is **not** consumed by the installed plugin. It is only read by this repository's development-time hook (`.claude/hooks/notify.sh`, registered on the `Notification` event in `.claude/settings.json`) and has no effect on evaluation runs for plugin users.

## Models and Effort

Full mode's five agents use the `opus` model alias, which Claude Code 2.1.280 and later resolve to Claude Opus 5.5 (`claude-opus-5-5`) on the Anthropic API, Claude Platform on AWS, Amazon Bedrock, and Google Vertex AI. Each agent sets its own effort, so a Full evaluation runs at the same depth whatever effort you choose with `/effort` or with `effortLevel` in settings:

| Agent | Effort |
|-------|--------|
| collector | `low` |
| completeness-evaluator | `medium` |
| design-evaluator | `medium` |
| safety-evaluator | `high` |
| synthesizer | `medium` |

`/harness-eval:quick` and `/harness-eval:compare` run at `effort: low`. Through the `/harness-eval` router (`/harness-eval:harness-eval`), every mode runs at your session effort, including its default Quick mode. Standard and the Full orchestrator use your session's model and effort.

- **Microsoft Foundry:** Claude Code resolves `opus` to Claude Opus 4.6 there (and to Claude Opus 4.7 through an LLM gateway). If your deployment offers Claude Opus 5.5, set `ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5-5`.
- **Overriding the agents' model:** `CLAUDE_CODE_SUBAGENT_MODEL` applies only to subagents that set no model, so on its own it does not change these five. With `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` as well, that model (or your session model, if `CLAUDE_CODE_SUBAGENT_MODEL` is unset) replaces every agent's model, including these. Scores from an overridden model are not comparable with runs on the default model.
- **Overriding the agents' effort:** `CLAUDE_CODE_EFFORT_LEVEL` takes precedence over every agent's `effort`; set to `auto` or `unset`, it puts every agent on the model's default effort. An effort cap (`maxEffortLevel` in settings, or a cap set by your organization) lowers any agent above it, for example safety-evaluator's `high`. Scores from such runs are not comparable with default runs.

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
│   │   ├── static-analysis.sh           # Syntax, validity, permissions, model/effort checks
│   │   ├── aggregate.sh                 # Full-mode 12-dimension score aggregation
│   │   ├── lib/grade.sh                 # Shared grade thresholds (sourced)
│   │   ├── history.sh                   # Evaluation history and trend analysis
│   │   ├── badge.sh                     # Score-to-badge conversion (A+ ~ F)
│   │   ├── setup.sh                     # Developer setup entry point
│   │   └── install-hooks.sh             # Git hook installation
│   │
│   ├── agents/                          # Subagents for Full mode evaluation
│   │   ├── collector.md                 # Target project inventory (writes artifact.md)
│   │   ├── safety-evaluator.md          # Safety and cost efficiency
│   │   ├── completeness-evaluator.md    # Actionability, testability, contracts
│   │   ├── design-evaluator.md          # Agent communication, context, feedback, evolvability
│   │   └── synthesizer.md               # Scoring, history save, en/ko report files
│   │
│   ├── skills/                          # User-facing evaluation entry points
│   │   ├── quick/SKILL.md               # Fast checklist evaluation
│   │   ├── standard/SKILL.md            # Standard analysis evaluation
│   │   ├── full/SKILL.md                # Multi-agent orchestrator
│   │   └── compare/SKILL.md             # Comparative analysis
│   │
│   ├── commands/                        # Slash command definitions
│   │   ├── harness-eval.md              # /harness-eval command router
│   │   ├── quick.md                     # /harness-eval:quick
│   │   ├── standard.md                  # /harness-eval:standard
│   │   ├── full.md                      # /harness-eval:full
│   │   └── compare.md                   # /harness-eval:compare
│   │
│   ├── hooks/                           # Plugin-provided hooks
│   │   ├── hooks.json                   # Hook event registration
│   │   └── post-eval-badge.sh           # Opt-in README badge update on Stop
│   │
│   ├── templates/                       # Evaluation templates
│   │   ├── checklist.json               # Check definitions (Quick/Standard)
│   │   ├── report-full.md               # Reference report template (not read at runtime)
│   │   └── report-component.md          # Reference report template (not read at runtime)
│   │
│   ├── tests/                           # Automated test suite
│   │   ├── test-scoring.sh              # Scoring script tests (24 tests)
│   │   ├── test-static-analysis.sh      # Static analysis tests (107 tests)
│   │   ├── test-history.sh              # History management tests (38 tests)
│   │   ├── test-aggregate.sh            # Aggregation tests (74 tests)
│   │   ├── harness-run-all.sh           # Harness validation runner
│   │   ├── hooks/                       # Dev hook and plugin Stop hook tests
│   │   ├── structure/                   # Plugin structure tests
│   │   └── fixtures/                    # Maturity mock projects + regression fixtures
│   │
│   └── docs/                            # Documentation
│       ├── architecture.md              # System architecture (bilingual)
│       ├── onboarding.md                # Developer onboarding guide
│       ├── decisions/                   # Architecture Decision Records
│       └── runbooks/                    # Operational runbooks (release, model change)
│
└── .claude/                             # Development-time Claude settings
    ├── settings.json                    # Hook registrations and deny list
    ├── hooks/                           # Dev hooks (doc-sync, secret-scan, etc.)
    ├── skills/                          # Dev skills (code-review, refactor, etc.)
    ├── commands/                        # Dev commands (review, test-all, deploy)
    └── agents/                          # Dev agents (code-reviewer.md, security-auditor.md)
```

## Testing

```bash
# Run all evaluation script tests (243 tests)
cd plugins/harness-eval
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-aggregate.sh

# Run harness validation tests
bash tests/harness-run-all.sh

# Run specific test category
bash tests/harness-run-all.sh hooks       # Hook tests only
bash tests/harness-run-all.sh structure   # Structure tests only
```

Total coverage: **447 checks** via `harness-run-all.sh` — 204 harness-validation checks (dev hooks 27, plugin Stop hook 33, secret patterns 25, structure, version consistency, and Full-mode contracts 118, shellcheck 1) plus the four evaluation-script suites it re-runs (test-scoring 24 + test-static-analysis 107 + test-history 38 + test-aggregate 74 = 243). One check (shellcheck lint) is skipped when `shellcheck` is not installed.

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
5. Open a Pull Request against the repository's default branch (`main`).

> **Branch note:** The remote currently has both `main` and `master`, which have diverged. `main` is the intended default and PR target; confirm the current default branch on GitHub before branching, and rebase onto it before opening a PR.

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

3개 카테고리의 12개 차원 — 기본 품질(정확성, 안전성, 완전성, 일관성), 운영(실행 가능성, 검증 가능성, 비용 효율성, 계약 기반 테스트), 설계 품질(에이전트 커뮤니케이션, 컨텍스트 관리, 피드백 루프 성숙도, 진화 가능성) — 에 걸쳐 프로젝트를 평가하고, 등급(A+~F)이 포함된 구조화된 보고서와 개선 로드맵을 제공합니다.

## 주요 기능

- **3단계 평가 체계** — 평가 깊이를 선택합니다: Quick (30초 미만 체크리스트), Standard (정적+동적 분석), Full (멀티 에이전트 병렬 리뷰)
- **멀티 에이전트 분석** — Full 모드에서 5개 전문 에이전트(collector, safety-evaluator, completeness-evaluator, design-evaluator, synthesizer)를 배치하여 종합 평가를 수행하고, 최종 점수는 스크립트(`aggregate.sh`)로 계산합니다
- **모델·effort 검사** — 정적 분석이 `.claude/`, 각 플러그인 루트의 에이전트·스킬·커맨드, settings의 모델·effort 설정을 읽습니다. 은퇴·deprecated·알 수 없는 모델 ID, Anthropic API 형식의 날짜 스냅샷 ID, 잘못된 effort 값, thinking 상한(`model-config`)과 Claude Code가 로드하지 않는 에이전트 파일(`agent-format`)을 찾아냅니다
- **평가 이력 추적** — 평가 결과를 저장, 조회, 비교하며 추세 분석과 델타 리포팅을 제공합니다
- **뱃지 생성** — 점수 기반 뱃지(A+~F)를 SVG 및 Markdown 형식으로 생성합니다. opt-in하지 않으면 어떤 평가 모드도 README를 수정하지 않습니다
- **테스트 픽스처** — minimal, functional, robust, production 성숙도 수준별로 점수 정확성을 검증하고, 중첩 훅 스키마와 모델 설정용 회귀 픽스처를 함께 둡니다

## 사전 요구 사항

- Bash 4+
- jq 1.6+
- Python 3.6+
- Git
- Claude Code CLI

## 설치 방법

### 설치

터미널 (Shell)에서:

```bash
claude plugin marketplace add https://github.com/whchoi98/harness-eval
claude plugin install harness-eval@harness-eval
```

또는 Claude Code 세션 안에서:

```
/plugin marketplace add https://github.com/whchoi98/harness-eval
/plugin install harness-eval@harness-eval
```

### 확인

터미널에서:

```bash
claude plugin list
```

또는 Claude Code 세션 안에서:

```
/plugin list
```

### 업데이트

터미널에서:

```bash
claude plugin marketplace update harness-eval
claude plugin update harness-eval@harness-eval
```

새 버전을 불러오려면 이후 Claude Code를 다시 시작하세요.

또는 Claude Code 세션 안에서:

```
/plugin marketplace update harness-eval
/plugin install harness-eval@harness-eval
```

### 삭제

터미널에서:

```bash
claude plugin remove harness-eval
claude plugin marketplace remove harness-eval
```

또는 Claude Code 세션 안에서:

```
/plugin remove harness-eval
/plugin marketplace remove harness-eval
```

### 소스에서 설치 (개발용)

```bash
git clone https://github.com/whchoi98/harness-eval.git
cd harness-eval/plugins/harness-eval
bash scripts/setup.sh
```

## 사용법

Claude Code 세션 안에서 평가를 실행합니다:

```
/harness-eval:quick              # 체크리스트 기반 평가 (~30초)
/harness-eval:standard           # 정적+동적 분석 (~2-3분)
/harness-eval:full               # 멀티 에이전트 종합 평가 (~5-10분)
/harness-eval:compare            # 이전 평가와 비교
/harness-eval:harness-eval full  # 인자 방식도 가능
```

> **신뢰 요구 사항 (Standard 및 Full 모드):** Standard 모드의 동적 분석 단계는 대상 프로젝트의 코드(`.claude/hooks/` 스크립트와 테스트 스위트)를 사용자의 머신에서 *실제로 실행*합니다. 신뢰할 수 있는 저장소에 대해서만 실행하세요. 스킬은 실행될 항목을 나열하고, 대상 코드를 실행하기 전에 채팅으로 확인을 요청합니다. 이 확인은 스킬이 직접 묻는 것이며 Claude Code의 권한 프롬프트가 아닙니다. `/harness-eval:standard`가 Bash를 미리 승인하기 때문입니다. 신뢰할 수 없는 저장소를 코드 실행 없이 평가하려면 `--static-only`(또는 `--no-dynamic`)를 전달하면 정적 분석과 채점만 수행합니다. Quick 모드는 대상 코드를 실행하지 않습니다. Full 모드는 대상 프로젝트의 훅이나 테스트를 실행하지 않지만, collector와 synthesizer 에이전트는 대상 파일을 읽는 동안 Bash를 사용할 수 있고, `/harness-eval:full`은 오케스트레이터가 실행하는 Bash 명령을 미리 승인합니다. 자세한 내용은 [SECURITY.md](SECURITY.md)를 참조하세요.

보고서는 대상 프로젝트의 `.harness-eval/reports/`에 영어와 한국어 파일로 따로 저장됩니다. Standard와 Full은 중간 파일도 `.harness-eval/run/`에 기록하며(Full은 스크립트 출력과 collector 인벤토리를 이곳에서 경로로 주고받음), 실행할 때마다 새로 씁니다. `.harness-eval/`에 `.gitignore`가 없으면 Standard와 Full이 `*` 한 줄짜리 `.gitignore`를 만들어 git이 그 안의 파일을 모두 무시하게 합니다. 이미 있는 `.gitignore`는 건드리지 않습니다. Quick은 이 파일을 만들지 않으므로, Quick만 실행했다면 `.harness-eval/reports/`가 커밋되지 않도록 직접 관리하세요.

어떤 평가 모드도 README를 수정하지 않습니다. 플러그인의 Stop 훅은 opt-in한 경우(`HARNESS_EVAL_AUTO_BADGE=1` 또는 git이 추적하지 않는 `.harness-eval/config.json`의 `{"autoBadge": true}`. git이 추적하는 파일은 opt-in으로 인정하지 않음)에만 Standard·Full 실행 후 README 뱃지를 갱신합니다. 저장된 평가마다 한 번, 그 평가를 저장한 응답이 끝날 때 동작하며, symlink인 `README.md`를 통해서는 쓰지 않습니다. 그 밖에는 `badge.sh`를 직접 실행하세요.

평가 스크립트를 직접 실행할 수도 있습니다:

```bash
# 대상 프로젝트 점수 산출
HARNESS_EVAL_ROOT=$(pwd) bash scripts/scoring.sh /path/to/target-project
# 출력: {"mode": "quick", "scores": {"overall": 7.2, "grade": "B"}, "checklist": {...}, "results": [...], "timestamp": "..."}

# 정적 분석 실행
HARNESS_EVAL_ROOT=$(pwd) bash scripts/static-analysis.sh /path/to/target-project
# 출력: {"summary": {"pass": 12, "warn": 1, "fail": 0, "total": 13}, "categories": {...}, ...}

# 평가 이력 조회 (대상 프로젝트를 먼저, 서브커맨드를 뒤에)
HARNESS_EVAL_ROOT=$(pwd) bash scripts/history.sh /path/to/target-project list
# 출력: [{"id": "eval-2026-04-06-001", "timestamp": "...", "mode": "standard", "overall": 7.2, "grade": "B"}]

# Full 모드 차원 점수 집계 (stdin JSON, 12개 키 각각 0-10 또는 null)
bash scripts/aggregate.sh <<'EOF'
{"dimensions": {"correctness": 9, "safety": 8, "completeness": 7, "consistency": 9}}
EOF
# 출력: {"timestamp": "...", "mode": "full", "scores": {"overall": 8.2, "grade": "B+"}, "dimensions": {...}, "categories": {"basicQuality": 8.25, "operational": null, "designQuality": null}, "status": {...}, "missing": ["actionability", ...]}

# 뱃지 생성 (대상 프로젝트의 README.md를 다시 쓰거나 새로 만듦)
bash scripts/badge.sh /path/to/target-project
# 출력: Badge SVG/Markdown
```

## 환경 설정

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `HARNESS_EVAL_ROOT` | harness-eval 플러그인 루트 디렉토리 경로 | 선택. `scoring.sh`와 `static-analysis.sh`는 스크립트 위치에서 자동으로 찾음 |
| `HARNESS_EVAL_AUTO_BADGE` | `1`로 설정하면 Standard·Full 실행 후 Stop 훅이 README 뱃지를 갱신 (git이 추적하지 않는 `.harness-eval/config.json`의 `{"autoBadge": true}`와 같음) | 미설정 (꺼짐) |

> **참고:** `CLAUDE_NOTIFY_WEBHOOK`은 설치된 플러그인이 **사용하지 않습니다**. 이 변수는 오직 본 저장소의 개발용 훅(`.claude/hooks/notify.sh`, `.claude/settings.json`의 `Notification` 이벤트에 등록됨)에서만 읽으며, 플러그인 사용자의 평가 실행에는 아무런 영향을 주지 않습니다.

## 모델과 effort

Full 모드의 에이전트 5개는 `opus` 모델 alias를 사용합니다. Claude Code 2.1.280 이상은 Anthropic API, Claude Platform on AWS, Amazon Bedrock, Google Vertex AI에서 이 alias를 Claude Opus 5.5(`claude-opus-5-5`)로 해석합니다. 에이전트마다 effort를 직접 지정하므로, `/effort`나 settings의 `effortLevel`로 정한 세션 effort와 관계없이 Full 평가는 같은 깊이로 실행됩니다:

| 에이전트 | Effort |
|----------|--------|
| collector | `low` |
| completeness-evaluator | `medium` |
| design-evaluator | `medium` |
| safety-evaluator | `high` |
| synthesizer | `medium` |

`/harness-eval:quick`과 `/harness-eval:compare`는 `effort: low`로 실행됩니다. `/harness-eval` 라우터(`/harness-eval:harness-eval`)를 거치면 기본 Quick 모드를 포함한 모든 모드가 세션 effort로 실행됩니다. Standard와 Full 오케스트레이터는 세션의 모델과 effort를 그대로 사용합니다.

- **Microsoft Foundry:** Claude Code는 Foundry에서 `opus`를 Claude Opus 4.6으로 해석합니다(LLM gateway를 거치면 Claude Opus 4.7). 배포 환경에서 Claude Opus 5.5를 쓸 수 있다면 `ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5-5`를 설정하세요.
- **에이전트 모델 재정의:** `CLAUDE_CODE_SUBAGENT_MODEL`은 모델을 지정하지 않은 서브에이전트에만 적용되므로, 이것만으로는 이 5개 에이전트가 바뀌지 않습니다. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`을 함께 설정하면 그 모델이(`CLAUDE_CODE_SUBAGENT_MODEL`이 없으면 세션 모델이) 이 에이전트들을 포함한 모든 에이전트의 모델을 대체합니다. 재정의한 모델로 얻은 점수는 기본 모델로 실행한 결과와 직접 비교할 수 없습니다.
- **에이전트 effort 재정의:** `CLAUDE_CODE_EFFORT_LEVEL`은 모든 에이전트의 `effort`보다 우선하며, 값이 `auto`나 `unset`이면 모든 에이전트가 모델의 기본 effort로 실행됩니다. effort 상한(settings의 `maxEffortLevel` 또는 조직이 정한 상한)은 그보다 높은 에이전트(예: safety-evaluator의 `high`)를 낮춥니다. 이렇게 얻은 점수는 기본 실행과 비교할 수 없습니다.

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
│   │   ├── static-analysis.sh           # 문법, 유효성, 권한, 모델·effort 검사
│   │   ├── aggregate.sh                 # Full 모드 12개 차원 점수 집계
│   │   ├── lib/grade.sh                 # 공용 등급 임계값 (source 전용)
│   │   ├── history.sh                   # 평가 이력 및 추세 분석
│   │   ├── badge.sh                     # 점수→뱃지 변환 (A+ ~ F)
│   │   ├── setup.sh                     # 개발자 설정 진입점
│   │   └── install-hooks.sh             # Git 훅 설치
│   │
│   ├── agents/                          # Full 모드 서브에이전트
│   │   ├── collector.md                 # 대상 프로젝트 인벤토리 (artifact.md 작성)
│   │   ├── safety-evaluator.md          # 안전성 및 비용 효율성
│   │   ├── completeness-evaluator.md    # 실행 가능성, 검증 가능성, 계약
│   │   ├── design-evaluator.md          # 에이전트 커뮤니케이션, 컨텍스트, 피드백, 진화 가능성
│   │   └── synthesizer.md               # 채점, 이력 저장, 영어/한국어 보고서 파일
│   │
│   ├── skills/                          # 사용자 대면 평가 진입점
│   │   ├── quick/SKILL.md               # 빠른 체크리스트 평가
│   │   ├── standard/SKILL.md            # 표준 분석 평가
│   │   ├── full/SKILL.md                # 멀티 에이전트 오케스트레이터
│   │   └── compare/SKILL.md             # 비교 분석
│   │
│   ├── commands/                        # 슬래시 커맨드 정의
│   │   ├── harness-eval.md              # /harness-eval 커맨드 라우터
│   │   ├── quick.md                     # /harness-eval:quick
│   │   ├── standard.md                  # /harness-eval:standard
│   │   ├── full.md                      # /harness-eval:full
│   │   └── compare.md                   # /harness-eval:compare
│   │
│   ├── hooks/                           # 플러그인 제공 훅
│   │   ├── hooks.json                   # 훅 이벤트 등록
│   │   └── post-eval-badge.sh           # Stop 시 README 뱃지 갱신 (opt-in)
│   │
│   ├── templates/                       # 평가 템플릿
│   │   ├── checklist.json               # 체크 항목 정의 (Quick/Standard)
│   │   ├── report-full.md               # 참고용 보고서 템플릿 (런타임 미사용)
│   │   └── report-component.md          # 참고용 보고서 템플릿 (런타임 미사용)
│   │
│   ├── tests/                           # 자동화 테스트 스위트
│   │   ├── test-scoring.sh              # 점수 산출 테스트 (24개)
│   │   ├── test-static-analysis.sh      # 정적 분석 테스트 (107개)
│   │   ├── test-history.sh              # 이력 관리 테스트 (38개)
│   │   ├── test-aggregate.sh            # 점수 집계 테스트 (74개)
│   │   ├── harness-run-all.sh           # 하네스 검증 러너
│   │   ├── hooks/                       # 개발용 훅·플러그인 Stop 훅 테스트
│   │   ├── structure/                   # 플러그인 구조 테스트
│   │   └── fixtures/                    # 성숙도 모의 프로젝트 + 회귀 픽스처
│   │
│   └── docs/                            # 문서
│       ├── architecture.md              # 시스템 아키텍처 (이중 언어)
│       ├── onboarding.md                # 개발자 온보딩 가이드
│       ├── decisions/                   # 아키텍처 결정 기록 (ADR)
│       └── runbooks/                    # 운영 런북 (릴리스, 모델 교체)
│
└── .claude/                             # 개발용 Claude 설정
    ├── settings.json                    # 훅 등록 및 deny 목록
    ├── hooks/                           # 개발용 훅 (doc-sync, secret-scan 등)
    ├── skills/                          # 개발용 스킬 (code-review, refactor 등)
    ├── commands/                        # 개발용 커맨드 (review, test-all, deploy)
    └── agents/                          # 개발용 에이전트 (code-reviewer.md, security-auditor.md)
```

## 테스트

```bash
# 평가 스크립트 테스트 전체 실행 (243개)
cd plugins/harness-eval
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-aggregate.sh

# 하네스 검증 테스트 실행
bash tests/harness-run-all.sh

# 특정 카테고리 테스트
bash tests/harness-run-all.sh hooks       # 훅 테스트만
bash tests/harness-run-all.sh structure   # 구조 테스트만
```

전체 테스트 커버리지: `harness-run-all.sh` 기준 **총 447개 체크** — 하네스 검증 체크 204개(개발용 훅 27, 플러그인 Stop 훅 33, 시크릿 패턴 25, 구조·버전 일관성·Full 모드 계약 118, shellcheck 1)에 더해 러너가 재실행하는 4개 평가 스크립트 스위트(test-scoring 24 + test-static-analysis 107 + test-history 38 + test-aggregate 74 = 243). `shellcheck` 미설치 시 1개 체크(shellcheck 린트)는 skip 처리됩니다.

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
5. 저장소의 기본 브랜치(`main`)를 대상으로 Pull Request를 생성합니다.

> **브랜치 참고:** 현재 원격에는 `main`과 `master`가 모두 존재하며 서로 분기되어 있습니다. `main`이 의도된 기본 브랜치이자 PR 대상입니다. 브랜치를 생성하기 전에 GitHub에서 현재 기본 브랜치를 확인하고, PR을 열기 전에 해당 브랜치 위로 rebase하세요.

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
