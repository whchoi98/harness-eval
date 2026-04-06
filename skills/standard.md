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

Combine all results into a comprehensive report using this structure:

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

(Priority-ordered list of 5-10 specific improvements, combining static analysis suggestions with checklist gaps)
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
