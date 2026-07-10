---
description: Validate and prepare the plugin for release
allowed-tools: Read, Bash(cd plugins/harness-eval:*), Bash(bash tests/harness-run-all.sh:*), Bash(bash tests/test-scoring.sh:*), Bash(bash tests/test-static-analysis.sh:*), Bash(bash tests/test-history.sh:*), Bash(python3 -m json.tool:*), Bash(git tag:*), Bash(git describe:*), Bash(git status:*), Bash(git log:*), Glob
---

# Deploy

Validate and prepare the harness-eval plugin for release.

This repository is a monorepo: the marketplace manifest lives at the root
(`.claude-plugin/marketplace.json`) and the plugin itself lives under
`plugins/harness-eval/` (with its own metadata-only `.claude-plugin/plugin.json`).

## Step 1: Pre-Deploy Checks

1. Verify working tree is clean: `git status`
2. Verify current branch (warn if not `main`)
3. Run the full test suite (161 tests total):
   ```bash
   cd plugins/harness-eval
   HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh          # 15 tests
   HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh  # 23 tests
   HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh          # 19 tests
   bash tests/harness-run-all.sh                                # 104 tests
   ```
4. Validate the JSON manifests:
   ```bash
   python3 -m json.tool .claude-plugin/marketplace.json
   python3 -m json.tool plugins/harness-eval/.claude-plugin/plugin.json
   ```

## Step 2: Validate Plugin Structure

`plugin.json` is metadata-only (no `skills`/`agents`/`commands`/`hooks` arrays —
those are auto-discovered by directory convention), so validate the real layout:

1. Confirm the auto-discovered component directories exist:
   ```bash
   for d in skills agents commands hooks scripts templates; do
     [ -d "plugins/harness-eval/$d" ] && echo "OK: $d" || echo "MISSING: $d"
   done
   ```
2. Verify all scripts are executable
3. Validate bash syntax on all `.sh` files:
   ```bash
   find plugins/harness-eval -name "*.sh" -exec bash -n {} \;
   ```
4. Confirm `plugins/harness-eval/CLAUDE.md` is up to date

## Step 3: Version Check

1. Read the current version from `plugins/harness-eval/.claude-plugin/plugin.json`
2. Compare with the latest git tag (handle the tag-absent initial state):
   ```bash
   git describe --tags --abbrev=0 2>/dev/null || echo "(no tags yet)"
   ```
3. Suggest a version bump if needed (semver)
4. Remember: a version bump must be applied to **both** manifests
   (`plugins/harness-eval/.claude-plugin/plugin.json` and, in two places,
   `.claude-plugin/marketplace.json`: `metadata.version` and `plugins[].version`).

## Step 4: Summary

Display:
- Plugin name and version
- Files included
- Test results
- Any warnings or issues found
- Next steps (tag, push, publish)

## Error Recovery

### If tests fail (Step 1)
Fix failing tests before release. Run individual suites to isolate:
```bash
cd plugins/harness-eval
bash tests/harness-run-all.sh hooks
bash tests/harness-run-all.sh structure
HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh
```

### If a manifest is invalid or versions diverge (Step 2/3)
```bash
python3 -m json.tool .claude-plugin/marketplace.json
python3 -m json.tool plugins/harness-eval/.claude-plugin/plugin.json
```
Ensure the version string matches across `plugin.json`,
`marketplace.json` `metadata.version`, and `marketplace.json` `plugins[].version`.
