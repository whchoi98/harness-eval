---
description: Run the harness-eval plugin's full test runner and report results
allowed-tools: Read, Bash(cd plugins/harness-eval:*), Bash(bash tests/harness-run-all.sh:*), Bash(bash tests/test-scoring.sh:*), Bash(bash tests/test-static-analysis.sh:*), Bash(bash tests/test-history.sh:*), Bash(bash tests/test-aggregate.sh:*), Bash(bash -n:*), Bash(chmod +x:*), Bash(ls:*), Glob
effort: low
---

# Test All

Execute the full test suite for the harness-eval plugin.

The runners live under `plugins/harness-eval/tests/`. There is no
`tests/run-all.sh` at the repo root — the runner is
`plugins/harness-eval/tests/harness-run-all.sh`; it also runs the
evaluation-script suites (`tests/test-*.sh`, listed in its `EVAL_SUITES`).

## Step 1: Verify Test Runners

```bash
ls -la plugins/harness-eval/tests/*.sh
```

## Step 2: Run Tests

```bash
cd plugins/harness-eval && bash tests/harness-run-all.sh $ARGUMENTS
```

`harness-run-all.sh` runs the hook and structure checks, re-runs the evaluation-script
suites, and runs shellcheck (skipped if not installed). An argument filters by suite name
(e.g. `hooks`, `structure`, `test-scoring`). Run a single evaluation suite directly
(`HARNESS_EVAL_ROOT=$(pwd) bash tests/<suite>.sh`) only when isolating a failure.

## Step 3: Report

Present:
- Total tests run, passed, failed, skipped - as printed in the runner's Results block
- Failed test details with file paths and error messages
- Suggest fixes for failing tests if the cause is apparent

## Error Recovery

### If a test runner itself fails
```bash
bash -n plugins/harness-eval/tests/harness-run-all.sh    # Check syntax
ls -la plugins/harness-eval/tests/**/*.sh                # Check permissions
chmod +x plugins/harness-eval/tests/**/*.sh              # Fix permissions
```

### Common failure categories and fixes

| Failure Pattern | Likely Cause | Fix |
|---|---|---|
| "file not found" | Missing file after restructure | Create file or update test |
| "invalid JSON" | Malformed manifest | `python3 -m json.tool <file>` |
| "Version mismatch" | Manifest versions diverged | Update both to same version |
| "not executable" | Permission reset by git | `chmod +x` on affected files |
| "bash syntax error" | Bad edit in script | `bash -n <file>` to locate error |

### If many tests fail at once
Likely a structural change broke multiple assumptions:
1. `git log -1` -- what was the last change?
2. `git diff HEAD~1` -- what specifically changed?
3. Fix the root cause, not individual tests
