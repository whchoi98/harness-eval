---
description: Execute the full test suite and report results
allowed-tools: Read, Bash(cd plugins/harness-eval:*), Bash(bash tests/harness-run-all.sh:*), Bash(bash tests/test-scoring.sh:*), Bash(bash tests/test-static-analysis.sh:*), Bash(bash tests/test-history.sh:*), Bash(bash -n:*), Bash(chmod +x:*), Bash(ls:*), Glob
---

# Test All

Execute the full test suite for the harness-eval plugin (161 tests total).

The runners live under `plugins/harness-eval/tests/`. There is no
`tests/run-all.sh` at the repo root — the harness runner is
`plugins/harness-eval/tests/harness-run-all.sh`, and the three evaluation-script
suites are run separately with `HARNESS_EVAL_ROOT` set.

## Step 1: Verify Test Runners

```bash
ls -la plugins/harness-eval/tests/harness-run-all.sh
ls -la plugins/harness-eval/tests/test-scoring.sh
ls -la plugins/harness-eval/tests/test-static-analysis.sh
ls -la plugins/harness-eval/tests/test-history.sh
```

## Step 2: Run Tests

Run all four suites from the plugin directory:

```bash
cd plugins/harness-eval
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh          # 15 tests
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh  # 23 tests
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh          # 19 tests
bash tests/harness-run-all.sh                                # 104 tests
```

If `$ARGUMENTS` specifies a filter, pass it to the harness runner:
```bash
cd plugins/harness-eval && bash tests/harness-run-all.sh $ARGUMENTS
```

## Step 3: Report

Present:
- Total tests run, passed, failed, skipped (expected total: 161)
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
