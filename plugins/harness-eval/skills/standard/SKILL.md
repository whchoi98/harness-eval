---
name: standard
description: Standard harness evaluation — static analysis, dynamic testing, and checklist scoring in 2-3 minutes. Produces a detailed report with findings and improvement roadmap. Dynamic testing runs the target's hooks and tests after the user confirms. Pass --static-only for repositories you do not trust.
---

You are performing a Standard harness evaluation. This combines static analysis, dynamic testing, and checklist scoring for a comprehensive assessment.

## Trust boundary and mode selection

**Read this before running anything.** Standard mode's dynamic analysis (Phase 2) *executes code from the target project* — its hook scripts and its test suite — on the evaluator's machine. A core use case for this tool is evaluating a repository you did not write (a teammate's project, a freshly cloned open-source repo). Running its hooks and tests can have side effects (network calls / webhooks, file writes, environment changes) even on repositories you trust, and running them against crafted input is itself risky. Static analysis (Phases 1 and 3) only reads files and is always safe.

Determine the run mode from the invocation:

- If the arguments include `--static-only` (or `--no-dynamic`), run **static-only mode**: skip Phase 2 entirely and run every other phase. In the report, mark every Dynamic Analysis subsection as `Skipped (static-only mode)`.
- Otherwise (the default), run target code in Phase 2 only after the user confirms at the gate below, because the target may be a repository you did not write.

## Phase 1: Static Analysis

Run the static analysis script:
```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/static-analysis.sh" "$(pwd)"
```

Capture the JSON output. Exit code 1 means issues were found and is a normal result; only exit code 2 is a script error. This checks:
- **Correctness**: bash syntax, JSON validity, hook file mapping, permissions, model and effort settings (`model-config`), agent file format (`agent-format`)
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
2. Run it with a sample payload for the event it is registered for (see the `hooks` section of `.claude/settings.json`): for a PreToolUse/PostToolUse hook on Bash, `echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | env -i PATH="$PATH" bash <hook>`. Record the exit code and what it prints. Silence is normal for many hooks; flag missing output only when the hook's purpose implies it should respond to this event.
3. Check exit codes are 0 or 1 (Claude Code treats exit 2 as a block signal, not a script error; anything higher indicates a crash)

### 2b. Secret Pattern Testing (if a secret-scanning hook exists)
Read the hook first to see how it gets its input: a JSON hook event on stdin (e.g. `tool_input.command` or `tool_input.content`), raw stdin, or files it scans itself (such as git-staged files). Build one true-positive and one false-positive probe in that form, using only these fake values: `AKIAIOSFODNN7EXAMPLE` (AWS access key ID), `aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` (AWS secret key in its usual context), and `normal-base64-string-that-is-not-a-key` (should not trigger). For hooks that scan staged files, stage the probe only inside the disposable copy. If a probe cannot reach the hook, record it as `not testable this way`, not as a missed detection.

### 2c. Existing Test Suite
Discover the target project's own test runner (do not assume a fixed name — it may be a top-level test script, a `Makefile` target, or a language-specific runner). Only run it after the confirmation gate:
```bash
# Discover candidate test entry points (examples — adapt to the project)
ls Makefile package.json tests/*.sh test/*.sh 2>/dev/null
# Run the discovered runner from a disposable copy where possible, e.g.:
#   bash <discovered-test-script>
```
If no test suite is found, record "No test suite found" and move on.

## Phase 3: Scoring and History

Run this phase from the target project root. If Phase 2 left the shell in the disposable copy, return to the project first, so the score and history describe the real project.

Prepare the run directory. When `.harness-eval/` has no `.gitignore`, this creates one containing `*`, so git ignores the evaluation files; an existing `.gitignore` (or a symlink by that name) is left untouched:
```bash
mkdir -p .harness-eval/run && { test -e .harness-eval/.gitignore || test -L .harness-eval/.gitignore || printf '*\n' > .harness-eval/.gitignore; }
```

Run the checklist scoring (`tee` shows you the JSON and keeps a copy for the history save):
```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scoring.sh" --mode standard "$(pwd)" | tee .harness-eval/run/standard-score.json
```

The pipeline's exit status is `tee`'s, so judge the result by its output: a JSON document with `scores` means scoring worked; an error on stderr with an empty `standard-score.json` means it failed (see Error Handling).

Then save the result to history:
```bash
HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/history.sh" "$(pwd)" save < .harness-eval/run/standard-score.json
```

It prints `{"id":"eval-YYYY-MM-DD-NNN","saved":true}`. That `id` names the report files in Phase 5.

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
(Improvements in priority order: cover every FAIL and the WARNs worth fixing, without padding)

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
(영향도 순 개선 사항 — 모든 FAIL과 고칠 가치가 있는 WARN을 담되, 억지로 항목을 채우지 않음)
```

## Phase 5: Save Reports to Files

Save the English and Korean reports as separate files in the target project:
```bash
mkdir -p .harness-eval/reports
```
- English report: `.harness-eval/reports/{id}-standard-en.md`
- Korean report: `.harness-eval/reports/{id}-standard-ko.md`

`{id}` is the ID printed by the history save in Phase 3. If the save failed, name the files `eval-{YYYY-MM-DD}-unsaved-standard-en.md` and `eval-{YYYY-MM-DD}-unsaved-standard-ko.md` (UTC date of the scoring output's `timestamp`) and tell the user this run was not recorded in history. An unsaved file of that name can already exist from an earlier run the same day, and the Write tool refuses to overwrite a file it has not read, so Read an existing one first and then overwrite it.

Use the Write tool to create each file. Then report the evaluation ID (or that there is none) and the saved report file paths to the user.

## Error Handling

- If static-analysis.sh fails with exit 2: report the error but continue with scoring
- If scoring.sh fails (an error on stderr and an empty `.harness-eval/run/standard-score.json`): show the error, suggest checking jq/dependencies, and skip the history save, since there is no score to record
- If history.sh save fails: warn, use the unsaved report file names from Phase 5, and still deliver the report
- If no `.claude/` directory exists: the score will be very low. Suggest running `/init` in a Claude Code session to create a CLAUDE.md, then adding `.claude/settings.json` with permissions and hooks.

## Tone

Be constructive: give a specific fix for each issue found, and order the improvement roadmap by impact.

## Language

Always produce the report in both English and Korean. English section first, then a horizontal rule (---), then the Korean section. Tables, scores, file paths, and code blocks are identical in both sections — only the prose text differs.
