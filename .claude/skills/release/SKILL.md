# Release Skill

Automate the release process with validation checks.

This repository is a monorepo: the marketplace manifest is at the root
(`.claude-plugin/marketplace.json`) and the plugin lives under
`plugins/harness-eval/`.

## Procedure

### 1. Pre-release Checks
- Verify working tree is clean: `git status`
- Verify all tests pass (161 tests total), run from the plugin directory:
  ```bash
  cd plugins/harness-eval
  HARNESS_EVAL_ROOT=$(pwd) bash tests/test-scoring.sh          # 15 tests
  HARNESS_EVAL_ROOT=$(pwd) bash tests/test-static-analysis.sh  # 23 tests
  HARNESS_EVAL_ROOT=$(pwd) bash tests/test-history.sh          # 19 tests
  bash tests/harness-run-all.sh                                # 104 tests
  ```
- Check for uncommitted changes

### 2. Determine Version
- Review changes since the last tag (handle the tag-absent initial state):
  ```bash
  LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
  if [ -n "$LAST_TAG" ]; then
    git log "$LAST_TAG"..HEAD --oneline
  else
    echo "No tags yet — treating all history as the first release:"
    git log --oneline
  fi
  ```
- Apply semver rules:
  - MAJOR: Breaking API changes
  - MINOR: New features, backward compatible
  - PATCH: Bug fixes only

### 3. Update Changelog
- Group changes by type (Added, Changed, Fixed, Removed)
- Include commit references
- Add date and version header

### 4. Create Release
- Update the version in **both** manifests so they stay in sync:
  - `plugins/harness-eval/.claude-plugin/plugin.json` (`version`)
  - `.claude-plugin/marketplace.json` (`metadata.version` **and** `plugins[].version`)
- Create git tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- Generate release notes

### 5. Summary
- Display version bump
- List key changes
- Show next steps (push tag, deploy, etc.)
