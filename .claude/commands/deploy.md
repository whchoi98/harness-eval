---
description: Validate and prepare the plugin for release
allowed-tools: Read, Bash(bash tests/run-all.sh:*), Bash(python3 -m json.tool:*), Bash(git tag:*), Bash(git status:*), Bash(git log:*), Glob
---

# Deploy

Validate and prepare the harness-eval plugin for release.

## Step 1: Pre-Deploy Checks

1. Verify working tree is clean: `git status`
2. Verify current branch (warn if not main)
3. Run full test suite: `bash tests/run-all.sh`
4. Validate all JSON files: `python3 -m json.tool .claude-plugin/plugin.json`

## Step 2: Validate Plugin Structure

1. Check all paths in .claude-plugin/plugin.json exist
2. Verify all scripts are executable
3. Validate bash syntax on all .sh files
4. Confirm CLAUDE.md is up to date

## Step 3: Version Check

1. Read current version from .claude-plugin/plugin.json
2. Compare with latest git tag
3. Suggest version bump if needed (semver)

## Step 4: Summary

Display:
- Plugin name and version
- Files included
- Test results
- Any warnings or issues found
- Next steps (tag, push, publish)

## Error Recovery

### If tests fail (Step 1)
Fix failing tests before release. Run individual test files to isolate:
```bash
bash tests/run-all.sh hooks
bash tests/run-all.sh structure
```

### If .claude-plugin/plugin.json paths are broken (Step 2)
Check each path reference:
```bash
python3 -c "
import json
p = json.load(open('.claude-plugin/plugin.json'))
import os
for kind in ['skills','agents','commands','hooks']:
    for item in p.get(kind, []):
        path = item.get('path','')
        exists = os.path.exists(path)
        print(f\"{'OK' if exists else 'MISSING'}: {path}\")
"
```
