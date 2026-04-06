# harness-eval Plugin Design Spec

**Date:** 2026-04-06
**Status:** Draft
**Author:** Collaborative (User + Claude)

---

## 1. Overview

Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하는 플러그인. 3개 레이어(Quick/Standard/Full)로 평가 깊이를 선택할 수 있으며, 다중 에이전트 기반 설계 리뷰, 점수 이력 추적, README 배지 생성을 지원한다.

### 1.1 목표

- 개인 개발자가 자신의 하네스 품질을 빠르게 진단하고 개선할 수 있도록 한다 (1순위)
- 팀/조직이 일관된 하네스 표준을 관리할 수 있도록 한다 (2순위)
- 플러그인 개발자가 배포 전 하네스 품질을 검증할 수 있도록 한다 (3순위)

### 1.2 설계 원칙

- **하이브리드 아키텍처**: 정량적 평가는 결정적 스크립트, 정성적 평가는 에이전트 프롬프트
- **계층형 접근**: Quick(30초) → Standard(2-3분) → Full(5-10분), 각 레이어 독립 실행 가능
- **생성/평가 분리** (Anthropic 기사): Full 모드에서 수집/평가/종합을 별도 에이전트로 분리하여 self-evaluation bias 방지
- **부분 실패 허용**: 에이전트 1개 실패가 전체 평가를 중단시키지 않음

### 1.3 참조

- Anthropic Engineering: [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- 원본 프레임워크: `docs/evaluation-framework.md`

---

## 2. Plugin Directory Structure

```
harness-eval/
├── plugin.json
├── CLAUDE.md
│
├── skills/
│   ├── quick.md                    # 체크리스트 → 즉석 등급
│   ├── standard.md                 # 정적+동적 분석 → 구성 요소별 점수
│   ├── full.md                     # 다중 에이전트 종합 평가 오케스트레이터
│   └── compare.md                  # 이력 비교 + 추세 + 배지
│
├── agents/
│   ├── collector.md                # 프로젝트 구조 수집 → 아티팩트 생성
│   ├── safety-evaluator.md         # 안전성 + 비용 효율성
│   ├── completeness-evaluator.md   # 실행 가능성 + 검증 가능성 + 계약 기반 테스트
│   ├── design-evaluator.md         # 통신 + 컨텍스트 + 피드백 루프 + 진화성
│   └── synthesizer.md              # 취합 → 보고서 + 로드맵
│
├── commands/
│   └── harness-eval.md             # /harness-eval 엔트리포인트
│
├── hooks/
│   └── post-eval-badge.sh          # 평가 후 README 배지 업데이트
│
├── scripts/
│   ├── static-analysis.sh          # 구문 검증, 파일 존재, 권한, 등록 확인
│   ├── scoring.sh                  # 체크리스트 집계 + 가중 평균 산출
│   ├── history.sh                  # 점수 이력 저장/조회/비교
│   └── badge.sh                    # README 배지 생성/업데이트
│
├── templates/
│   ├── report-component.md         # 구성 요소별 보고 템플릿
│   ├── report-full.md              # 종합 보고서 템플릿
│   └── checklist.json              # Quick 평가용 체크리스트 정의
│
├── tests/
│   ├── test-static-analysis.sh
│   ├── test-scoring.sh
│   ├── test-history.sh
│   ├── fixtures/
│   │   ├── minimal-project/        # ~6.0 수준
│   │   ├── functional-project/     # ~7.0 수준
│   │   ├── robust-project/         # ~8.0 수준
│   │   └── production-project/     # ~9.0+ 수준
│   └── expected/
│
└── docs/
    ├── evaluation-framework.md
    ├── scoring-guide.md
    └── anthropic-patterns.md
```

---

## 3. Evaluation Dimensions (12)

### 3.1 Three Categories

| Category | Dimension | Method | Layer |
|---|---|---|---|
| **Basic Quality** | Correctness | Script | Quick+ |
| | Safety | Script + Agent | Standard+ |
| | Completeness | Script | Standard+ |
| | Consistency | Script | Standard+ |
| **Operational Quality** | Actionability | Agent | Full |
| | Testability | Script + Agent | Standard+ |
| | Cost Efficiency | Agent | Full |
| **Design Quality** | Agent Communication | Agent | Full |
| | Context Management | Agent | Full |
| | Feedback Loop Maturity | Agent | Full |
| | Contract-Based Testing | Agent | Full |
| | Evolvability | Agent | Full |

Design Quality dimensions are derived from the Anthropic engineering article on harness design.

### 3.2 Scoring Per Layer

**Quick** — Checklist-based (deterministic):
- Load items from `checklist.json`
- Binary pass/fail checks
- Score = passed / total * 10 → grade mapping

**Standard** — 5 dimensions (deterministic + partial qualitative):
```
Weights (normalized):
  correctness      0.25
  safety           0.25
  completeness     0.20
  consistency      0.15
  testability      0.15
```

**Full** — All 12 dimensions (deterministic + agent qualitative):
```
Weights:
  Basic Quality   (6 dims)   0.50  ← reuses Standard script results
  Operational     (3 dims)   0.25
  Design Quality  (5 dims)   0.25
```

### 3.3 Grade Scale

| Score | Grade | Label |
|---|---|---|
| 9.5-10 | A+ | Production Optimized |
| 9.0-9.4 | A | Production Ready |
| 8.5-8.9 | A- | Production Capable |
| 8.0-8.4 | B+ | Robust |
| 7.0-7.9 | B | Functional |
| 6.0-6.9 | C | Basic |
| <6.0 | D/F | Incomplete |

### 3.4 Agent-to-Dimension Mapping (Full mode)

| Agent | Dimensions |
|---|---|
| collector | None (data collection only) |
| safety-evaluator | Safety (qualitative supplement) + Cost Efficiency |
| completeness-evaluator | Actionability + Testability (supplement) + Contract-Based Testing |
| design-evaluator | Agent Communication + Context Management + Feedback Loop + Evolvability |
| synthesizer | None (aggregation + report only) |

---

## 4. Execution Flows

### 4.1 Quick Flow (single skill, no agents)

```
User: /harness-eval quick
  → skills/quick.md activates
  → scripts/scoring.sh --mode quick
    ├─ templates/checklist.json 직접 로드 (static-analysis.sh 미사용)
    ├─ check type별 검증 함수로 .claude/ 스캔
    ├─ per-item pass/fail
    └─ tier별 달성률 → 가중 점수 → 등급
  → Terminal output: score, checklist, next steps
```

### 4.2 Standard Flow (single skill, script chain)

```
User: /harness-eval standard
  → skills/standard.md activates
  → scripts/static-analysis.sh → analysis-result.json
    ├─ bash -n (hook syntax)
    ├─ JSON validation
    ├─ file existence/permissions
    ├─ settings.json ↔ file mapping
    ├─ tool scope check
    └─ deny list check
  → Dynamic analysis (Claude가 skills/standard.md 프롬프트에 따라 수행)
    ├─ 훅 실행 테스트: 빈 입력/정상 입력/엣지 케이스를 Bash 도구로 직접 실행
    ├─ 시크릿 패턴 TP/FP: 알려진 패턴(AKIA 등)을 echo|grep으로 검증
    └─ 기존 테스트 스위트: tests/ 디렉토리 탐색 후 발견된 테스트 러너 실행
  → scripts/scoring.sh --mode standard → score-result.json
  → Report generation (templates/report-component.md)
  → scripts/history.sh save
```

### 4.3 Full Flow (multi-agent orchestration)

```
User: /harness-eval full
  → skills/full.md activates (orchestrator)

  Phase 1: Collection
    ├─ Standard flow (score-result.json)
    └─ Agent: collector → project-artifact.md

  Phase 2: Parallel Evaluation
    ├─ Agent: safety-evaluator     ─┐
    ├─ Agent: completeness-evaluator ├─ parallel
    └─ Agent: design-evaluator     ─┘
    Input: project-artifact.md + score-result.json
    Output: per-dimension scores + evidence + recommendations

  Phase 3: Synthesis
    └─ Agent: synthesizer
       → 12-dimension aggregate score
       → Full report (templates/report-full.md)
       → Improvement roadmap
       → scripts/history.sh save
       → scripts/badge.sh update
```

### 4.4 Agent Communication Protocol

Agents communicate via structured markdown artifacts:

```markdown
---
agent: <agent-name>
timestamp: <ISO 8601>
phase: collection | evaluation | synthesis
---

## Scores
| Dimension | Score | Evidence Summary |
|---|---|---|

## Findings
### [PASS|WARN|FAIL] <item>
- File: <path:line>
- Detail: <description>
- Recommendation: <improvement>

## Recommendations
1. (priority-ordered)
```

---

## 5. checklist.json Structure

### 5.1 Tier-based Organization

Four tiers matching the grade scale: basic (6.0+), functional (7.0+), robust (8.0+), production (9.0+).

### 5.2 Check Types

| Type | Description | Parameters |
|---|---|---|
| `file_exists` | File existence | `target` |
| `file_exists_any` | Any of multiple paths | `targets[]` |
| `glob_min` | Glob match minimum count | `target`, `min` |
| `json_field_exists` | JSON field existence | `target`, `path` |
| `json_array_min` | JSON array minimum size | `target`, `path`, `min` |
| `json_keys_present` | JSON keys present | `target`, `path`, `keys[]` |
| `grep_match` | Pattern match in files | `target`, `pattern` |
| `grep_all_files` | Pattern in all files | `target`, `pattern` |
| `frontmatter_field` | Markdown frontmatter field | `target`, `field` |
| `custom` | Custom script execution | `script` |

### 5.3 Items Per Tier

**Basic (6.0+):** CLAUDE.md exists, settings.json exists, 1+ hook registered, 1+ command exists.

**Functional (7.0+):** All 4 hook events registered, secret scanning hook, 2+ skills, 1+ agent.

**Robust (8.0+):** Automated tests, error recovery sections, agent output schema, least privilege tool scope, deny list, module-level CLAUDE.md coverage.

**Production (9.0+):** E2E integration tests, performance benchmarks, CI/CD pipeline, migration guide.

Each item has a `weight` (default 1.0) influencing its contribution to the tier score.

---

## 6. Script Interfaces

### 6.1 Common Contract

```
Input:  $1 = target project root path
        HARNESS_EVAL_ROOT = plugin root path (env var)
Output: stdout = JSON (machine-parseable)
        stderr = human-readable logs/errors
Exit:   0 = success, 1 = evaluation complete (issues found), 2 = script error
```

### 6.2 static-analysis.sh

```json
// Output schema
{
  "timestamp": "ISO 8601",
  "project": "/path",
  "checks": [
    {
      "id": "string",
      "category": "correctness|safety|completeness|consistency",
      "status": "PASS|WARN|FAIL",
      "details": "string",
      "file": "optional path",
      "line": "optional number",
      "suggestion": "optional string"
    }
  ],
  "summary": { "pass": N, "warn": N, "fail": N, "total": N }
}
```

### 6.3 scoring.sh

```json
// Output schema
{
  "timestamp": "ISO 8601",
  "mode": "quick|standard",
  "scores": {
    "overall": 0.0-10.0,
    "grade": "A+|A|A-|B+|B|C|D|F",
    "dimensions": {
      "<name>": { "score": 0.0-10.0, "weight": 0.0-1.0 }
    }
  },
  "components": {
    "hooks": 0.0-10.0,
    "skills": 0.0-10.0,
    "commands": 0.0-10.0,
    "agents": 0.0-10.0,
    "claude_md": 0.0-10.0
  },
  "checklist": {
    "<tier>": { "passed": N, "total": N }
  }
}
```

### 6.4 history.sh

```bash
history.sh <project> save    < score-result.json   # Save evaluation
history.sh <project> list    [--last N]              # List evaluations
history.sh <project> compare [--eval-id ID]          # Compare with previous
```

### 6.5 badge.sh

```bash
badge.sh <project>    # Read latest.json, update README.md badges
```

Badge color mapping: 9.0+ brightgreen, 8.0-8.9 green, 7.0-7.9 yellow, 6.0-6.9 orange, <6.0 red.

Badge markers in README.md:
```html
<!-- harness-eval-badge:start -->
![Harness Score](https://img.shields.io/badge/harness-8.5%2F10-green)
![Harness Grade](https://img.shields.io/badge/grade-A--green)
![Last Eval](https://img.shields.io/badge/eval-2026--04--06-blue)
<!-- harness-eval-badge:end -->
```

---

## 7. History and Tracking

### 7.1 Storage Location

Stored in the target project at `.harness-eval/`:

```
.harness-eval/
├── history.json     # All evaluation history (cumulative)
├── latest.json      # Most recent result (badge source)
└── reports/         # Per-evaluation markdown reports
```

### 7.2 history.json Schema

```json
{
  "version": "1.0",
  "project": "<name>",
  "evaluations": [
    {
      "id": "eval-YYYY-MM-DD-NNN",
      "timestamp": "ISO 8601",
      "mode": "quick|standard|full",
      "scores": {
        "overall": 0.0-10.0,
        "grade": "string",
        "dimensions": { "<name>": "number|null" }
      },
      "components": { "<name>": "number" },
      "checklist": { "total": N, "passed": N, "items": {} },
      "critical_issues": N,
      "report_path": "string"
    }
  ]
}
```

`null` dimension values indicate the dimension was not evaluated in that mode.

### 7.3 Compare Output

The compare skill shows:
- Current vs. previous score delta
- Per-dimension improvement/decline
- Diminishing returns detection (convergence pattern)
- Projection for next achievable grade
- ASCII bar chart history

### 7.4 Cross-mode Comparison

When comparing evaluations of different modes (e.g., quick vs full), only shared dimensions are compared. Non-comparable dimensions are clearly marked.

---

## 8. plugin.json Manifest

```json
{
  "name": "harness-eval",
  "version": "0.1.0",
  "description": "Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하는 플러그인. Quick/Standard/Full 3단계 평가, 다중 에이전트 기반 설계 리뷰, 이력 추적 및 배지 생성.",
  "skills": [
    { "name": "quick",    "path": "skills/quick.md" },
    { "name": "standard", "path": "skills/standard.md" },
    { "name": "full",     "path": "skills/full.md" },
    { "name": "compare",  "path": "skills/compare.md" }
  ],
  "agents": [
    { "name": "collector",               "path": "agents/collector.md" },
    { "name": "safety-evaluator",        "path": "agents/safety-evaluator.md" },
    { "name": "completeness-evaluator",  "path": "agents/completeness-evaluator.md" },
    { "name": "design-evaluator",        "path": "agents/design-evaluator.md" },
    { "name": "synthesizer",             "path": "agents/synthesizer.md" }
  ],
  "commands": [
    { "name": "harness-eval", "path": "commands/harness-eval.md" }
  ],
  "hooks": [
    { "event": "Stop", "path": "hooks/post-eval-badge.sh" }
  ]
}
```

### 8.1 Model Selection

| Agent | Model | Rationale |
|---|---|---|
| collector | sonnet | Tool-use focused, minimal reasoning |
| safety-evaluator | opus | Deep reasoning for security judgment |
| completeness-evaluator | sonnet | Pattern matching + moderate judgment |
| design-evaluator | opus | High reasoning for Anthropic-pattern evaluation |
| synthesizer | sonnet | Structuring/formatting focused |

---

## 9. Error Handling

### 9.1 Script Level

| Scenario | Handling | Exit |
|---|---|---|
| No `.claude/` in target | Score 1.0/10 F + setup guide | 0 |
| `settings.json` parse fail | FAIL that check, continue rest | 1 |
| `checklist.json` missing | Plugin install error | 2 |
| Hook script no execute permission | WARN + chmod suggestion | 1 |
| Target path not found | stderr error, exit immediately | 2 |

### 9.2 Agent Level (Full mode)

| Scenario | Handling |
|---|---|
| Evaluator agent timeout/fail | Dimension = `null`, partial report |
| Collector fail | Abort Full, return Standard results only |
| Synthesizer fail | Show raw agent outputs |
| Very large project (1000+ files) | Collector limits scan to 500 files, `.claude/` first |

**Principle:** Partial failure never stops the entire evaluation. Return results for whatever succeeded.

---

## 10. Testing Strategy

### 10.1 Fixture-based Testing

Four mock projects at different maturity levels validate scoring accuracy:

| Fixture | Expected Score | Purpose |
|---|---|---|
| `minimal-project` | ~6.0 | Basic tier validation |
| `functional-project` | ~7.0 | Functional tier validation |
| `robust-project` | ~8.0 | Robust tier validation |
| `production-project` | ~9.0 | Production tier validation |

Tests verify scores fall within expected ranges (e.g., 5.5-6.5 for minimal).

### 10.2 Test Coverage

- **static-analysis.sh**: Invalid JSON detection, permissive tool scope detection, missing files
- **scoring.sh**: Per-fixture score ranges, weight calculation correctness, mode-specific behavior
- **history.sh**: Save/load roundtrip, delta calculation, empty history handling
- **badge.sh**: Badge URL generation, README marker insertion/replacement

### 10.3 Edge Cases

| Edge Case | Handling |
|---|---|
| No harness at all | 1.0/10 F + starter guide |
| Plugin-based harness (outside `.claude/`) | Detect `plugin.json`, scan plugin root too |
| Monorepo (multiple CLAUDE.md) | Root-based eval, module coverage in completeness |
| No prior evaluations for compare | Guide to run quick/standard first |
| Cross-mode comparison | Common dimensions only, mark incomparable |
| Very large project | 500-file scan cap, `.claude/` priority |
| `jq` not installed | Dependency check at script start, install guidance |

---

## 11. Dependencies

**Required:**
- bash 4.0+
- jq

**Optional:**
- python3 (reserved for future complex scoring)

All scripts check dependencies at startup.

---

## 12. Out of Scope (v0.1)

- CI/CD integration (GitHub Actions, etc.) — future version
- Web dashboard for team-wide metrics — future version
- Auto-fix capabilities (only diagnose + recommend) — future version
- Real-time watch mode — future version
- Custom checklist extensions by users — future version (v0.2 candidate)
