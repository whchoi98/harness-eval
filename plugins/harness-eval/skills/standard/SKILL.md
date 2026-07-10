---
name: standard
description: Standard harness evaluation — static analysis, dynamic testing, and checklist scoring in 2-3 minutes. Produces a detailed report with findings and improvement roadmap.
---

You are performing a Standard harness evaluation. This combines static analysis, dynamic testing, and checklist scoring for a comprehensive assessment.

## Trust boundary and mode selection

**Read this before running anything.** Standard mode's dynamic analysis (Phase 2) *executes code from the target project* — its hook scripts and its test suite — on the evaluator's machine. A core use case for this tool is evaluating a repository you did NOT write (a teammate's project, a freshly cloned open-source repo). Running its hooks and tests can have side effects (network calls / webhooks, file writes, environment changes) even on repositories you trust, and running them against crafted input is itself risky. Static analysis (Phases 1 and 3) only reads files and is always safe.

Determine the run mode from the invocation:

- If the arguments include `--static-only` (or `--no-dynamic`), run **static-only mode**: perform Phase 1 and Phase 3 only, and **skip Phase 2 entirely**. In the report, mark every Dynamic Analysis subsection as `Skipped (static-only mode)`.
- Otherwise (default), before doing any Phase 2 step you MUST pass the confirmation gate described in Phase 2. Never execute a target hook or test suite without either an explicit `--static-only`/`--no-dynamic` opt-out having been ruled out AND the user confirming.

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

**Skip this entire phase in static-only mode** (see "Trust boundary and mode selection" above); mark each subsection below as `Skipped (static-only mode)` in the report and go straight to Phase 3.

### Confirmation gate (required before any dynamic step)

Dynamic analysis runs code from the target project. Before executing anything, first enumerate what *would* run (list the hook script paths under `.claude/hooks/` and the discovered test runner), then ask the user to confirm with a message like:

> "Standard dynamic analysis will EXECUTE code from the target project on this machine: the hook scripts listed above and its test suite. This can have side effects (network calls, file writes) even for trusted repos. Do you trust this repository and want to proceed? Reply to proceed, or re-run with `--static-only` to skip dynamic analysis."

If the user does not affirmatively confirm, fall back to static-only behavior: skip Phase 2 and note it as `Skipped (not confirmed)` in the report. Only proceed below once the user has confirmed.

### Sandboxing guidance

When you do run target code, minimize blast radius:
- Run from a disposable copy of the project in a temporary directory (e.g. `cp -r` into a scratch dir) rather than the user's working tree, so writes cannot damage the original.
- Strip inherited secrets/credentials from the child environment (e.g. invoke via `env -i PATH="$PATH" bash <hook>`), so an exfiltrating hook has nothing to send.
- Do not grant network access if your environment can withhold it; treat any hook that attempts outbound network calls as a finding, not as expected behavior.
- Never pipe real secrets into hooks. Use only clearly-fake example values (as in 2b).

### 2a. Hook Execution Testing
For each hook script found in `.claude/hooks/` (after the gate above):
1. Run with empty input: `echo "" | env -i PATH="$PATH" bash <hook>` — should not crash
2. Run with sample input: `echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | env -i PATH="$PATH" bash <hook>` — should produce output
3. Check exit codes are 0 or 1 (Claude Code treats exit 2 as a block signal, not a script error; anything higher indicates a crash)

### 2b. Secret Pattern Testing (if secret scanning hook exists)
Test true positives and false positives with example (non-real) values:
```bash
# True positive — should be detected
echo "AKIAIOSFODNN7EXAMPLE" | env -i PATH="$PATH" bash <secret-hook>
# True positive — AWS secret key pattern
echo "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" | env -i PATH="$PATH" bash <secret-hook>
# False positive — should NOT trigger
echo "normal-base64-string-that-is-not-a-key" | env -i PATH="$PATH" bash <secret-hook>
```

### 2c. Existing Test Suite
Discover the target project's own test runner (do not assume a fixed name — it may be a top-level test script, a `Makefile` target, or a language-specific runner). Only run it after the confirmation gate:
```bash
# Discover candidate test entry points (examples — adapt to the project)
ls Makefile package.json tests/*.sh test/*.sh 2>/dev/null
# Run the discovered runner from a disposable copy where possible, e.g.:
#   bash <discovered-test-script>
```
If no test suite is found, record "No test suite found" and move on.

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

## Phase 5: Save Reports to Files

Save the English and Korean reports as separate files in the target project:
```bash
mkdir -p .harness-eval/reports
```
- English report: `.harness-eval/reports/eval-{YYYY-MM-DD}-{NNN}-standard-en.md`
- Korean report: `.harness-eval/reports/eval-{YYYY-MM-DD}-{NNN}-standard-ko.md`

Use the Write tool to create each file. The `{NNN}` sequence number should match the evaluation ID from history.

## Phase 6: Save History

Save the scoring result to history:
```bash
echo '<scoring-json>' | HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" save
```

Report the evaluation ID and saved report file paths to the user.

## Error Handling

- If static-analysis.sh fails with exit 2: report the error but continue with scoring
- If scoring.sh fails with exit 2: show error and suggest checking jq/dependencies
- If history.sh save fails: warn but don't block the report
- If no `.claude/` directory exists: note very low score expected, guide user to set up basics

## Tone

Be thorough but constructive. For each issue found, provide a specific fix. Prioritize the improvement roadmap by impact.

## Language

Always produce the report in both English and Korean. English section first, then a horizontal rule (---), then the Korean section. Tables, scores, file paths, and code blocks are identical in both sections — only the prose text differs.
