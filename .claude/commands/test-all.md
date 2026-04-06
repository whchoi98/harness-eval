---
description: Execute the full test suite and report results
allowed-tools: Read, Bash(bash tests/run-all.sh:*), Bash(bash -n:*), Bash(chmod +x:*), Glob
---

# Test All

Execute the full test suite for the harness-eval plugin.

## Step 1: Verify Test Runner

Check that the test runner exists and is executable:
```bash
ls -la tests/run-all.sh
```

## Step 2: Run Tests

Execute the test suite:

```bash
bash tests/run-all.sh
```

If $ARGUMENTS specifies a filter, pass it:
```bash
bash tests/run-all.sh $ARGUMENTS
```

## Step 3: Report

Present:
- Total tests run, passed, failed, skipped
- Failed test details with file paths and error messages
- Suggest fixes for failing tests if the cause is apparent

## Error Recovery

### If test runner itself fails
```bash
bash -n tests/run-all.sh          # Check syntax
ls -la tests/**/*.sh              # Check permissions
chmod +x tests/**/*.sh            # Fix permissions
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
