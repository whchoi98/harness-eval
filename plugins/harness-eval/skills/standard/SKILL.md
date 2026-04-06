---
name: standard
description: Standard harness evaluation — static analysis, dynamic testing, and checklist scoring in 2-3 minutes. Produces a detailed report with findings and improvement roadmap.
---

You are performing a Standard harness evaluation. This combines static analysis, dynamic testing, and checklist scoring for a comprehensive assessment.

## Phase 1: Static Analysis

Run the static analysis script:
```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/static-analysis.sh" "$(pwd)"
```

Capture the JSON output. This checks:
- **Correctness**: bash syntax, JSON validity, hook file mapping, permissions
- **Safety**: tool scope analysis, deny list presence
- **Completeness**: hook event coverage, CLAUDE.md existence
- **Consistency**: frontmatter field consistency

## Phase 2: Dynamic Analysis

Perform these live tests using Bash tool calls:

### 2a. Hook Execution Testing
For each hook script found in `.claude/hooks/`:
1. Run with empty input: `echo "" | bash <hook>` — should not crash
2. Run with sample input: `echo '{"tool":"Bash","input":"ls"}' | bash <hook>` — should produce output
3. Check exit codes are 0 or 1 (not 2+, which indicates script error)

### 2b. Secret Pattern Testing (if secret scanning hook exists)
Test true positives and false positives:
```bash
# True positive — should be detected
echo "AKIAIOSFODNN7EXAMPLE" | bash <secret-hook>
# True positive — AWS secret key pattern
echo "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" | bash <secret-hook>
# False positive — should NOT trigger
echo "normal-base64-string-that-is-not-a-key" | bash <secret-hook>
```

### 2c. Existing Test Suite
Look for test files in `tests/` directory. If found, run them:
```bash
# Look for test runner
ls tests/run-all.sh tests/*.sh 2>/dev/null
# Run discovered tests
bash tests/run-all.sh  # or individual test files
```

## Phase 3: Scoring

Run the checklist scoring:
```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scoring.sh" --mode standard "$(pwd)"
```

## Phase 4: Report Generation

Combine all results into a **bilingual** (English + Korean) report. English section first, then `---`, then Korean section. Tables, scores, and code are identical — only prose differs.

```
# Harness Standard Evaluation

**Score: {overall}/10 ({grade})**
**Date: {timestamp}**

## Static Analysis Summary

| Category | Pass | Warn | Fail |
|----------|------|------|------|
| Correctness | X | Y | Z |
| Safety | X | Y | Z |
| Completeness | X | Y | Z |
| Consistency | X | Y | Z |

## Static Analysis Findings
(List each WARN and FAIL with details, file path, and suggestion)

## Dynamic Analysis Results

### Hook Execution
(Results of hook testing — which hooks passed/failed)

### Secret Pattern Accuracy
(TP/FP results if applicable)

### Test Suite Results
(Results of running existing tests, or "No test suite found")

## Checklist Results

| Tier | Passed | Total | Status |
|------|--------|-------|--------|
| Basic (6.0+) | X | Y | ✓/✗ |
| Functional (7.0+) | X | Y | ✓/✗ |
| Robust (8.0+) | X | Y | ✓/✗ |
| Production (9.0+) | X | Y | ✓/✗ |

## Improvement Roadmap
(Priority-ordered list of 5-10 specific improvements)

---

# 하네스 Standard 평가

**점수: {overall}/10 ({grade})**
**날짜: {timestamp}**

## 정적 분석 요약

| 카테고리 | 통과 | 경고 | 실패 |
|----------|------|------|------|
| 정확성 | X | Y | Z |
| 안전성 | X | Y | Z |
| 완전성 | X | Y | Z |
| 일관성 | X | Y | Z |

## 정적 분석 발견 사항
(각 WARN 및 FAIL 항목의 상세 내용, 파일 경로, 개선 제안)

## 동적 분석 결과

### 훅 실행
(훅 테스트 결과 — 통과/실패 항목)

### 시크릿 패턴 정확도
(해당되는 경우 TP/FP 결과)

### 테스트 스위트 결과
(기존 테스트 실행 결과, 또는 "테스트 스위트 없음")

## 체크리스트 결과

| 단계 | 통과 | 전체 | 상태 |
|------|------|------|------|
| 기본 (6.0+) | X | Y | ✓/✗ |
| 기능적 (7.0+) | X | Y | ✓/✗ |
| 견고 (8.0+) | X | Y | ✓/✗ |
| 프로덕션 (9.0+) | X | Y | ✓/✗ |

## 개선 로드맵
(영향도 순으로 정렬된 5-10개 구체적 개선 사항)
```

## Phase 5: Save History

Save the scoring result to history:
```bash
echo '<scoring-json>' | HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" save
```

Report the evaluation ID to the user.

## Error Handling

- If static-analysis.sh fails with exit 2: report the error but continue with scoring
- If scoring.sh fails with exit 2: show error and suggest checking jq/dependencies
- If history.sh save fails: warn but don't block the report
- If no `.claude/` directory exists: note very low score expected, guide user to set up basics

## Tone

Be thorough but constructive. For each issue found, provide a specific fix. Prioritize the improvement roadmap by impact.

## Language

Always produce the report in both English and Korean. English section first, then a horizontal rule (---), then the Korean section. Tables, scores, file paths, and code blocks are identical in both sections — only the prose text differs.
