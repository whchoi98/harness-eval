# Runbook: Cut a harness-eval Release

## Overview
Step-by-step procedure for publishing a new version of the `harness-eval` plugin to the
marketplace. A release bumps the version in three manifests that MUST stay in lockstep,
moves the CHANGELOG `Unreleased` entries under the new version, tags the commit, and
verifies a clean marketplace install.

## When to Use
- Shipping a new set of features/fixes that have landed on the default branch.
- Publishing a hotfix for a security or correctness defect.
- Any time `.claude-plugin/marketplace.json` or `plugins/harness-eval/.claude-plugin/plugin.json`
  version needs to change.

## Prerequisites
- Write access to the `whchoi98/harness-eval` repository (push tags).
- A clean working tree on an up-to-date default branch.
- Local toolchain: Bash 4+, `jq`, `python3`, `bc`, and (optionally) `shellcheck`.
- Green CI on the commit you intend to release.

## Procedure

### 1. Confirm a clean, green starting point
```bash
git switch main && git pull --ff-only
git status --porcelain            # must be empty

# Full suite: hook, secret-pattern and structure checks, the four evaluation-script
# suites, and the shellcheck stage, in one command.
cd plugins/harness-eval
bash tests/harness-run-all.sh

# The four evaluation suites, as documented (granular output):
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-scoring.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-history.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-aggregate.sh
cd -
```
Do not proceed unless every suite passes.

### 2. Choose the new version (SemVer)
Decide `MAJOR.MINOR.PATCH` per [Semantic Versioning](https://semver.org):
- MAJOR — breaking changes to the plugin contract (script args, output schema, events).
- MINOR — backwards-compatible features (new checks, modes, skills).
- PATCH — backwards-compatible bug fixes.

```bash
NEW_VERSION="0.2.0"   # example
```

### 3. Bump the version in all three manifests
These three values MUST be identical; the `test-plugin-structure.sh` version-consistency
test fails the build otherwise.

```bash
# 1) marketplace metadata.version
# 2) marketplace plugins[0].version
jq --arg v "$NEW_VERSION" \
   '.metadata.version = $v | .plugins[0].version = $v' \
   .claude-plugin/marketplace.json > .claude-plugin/marketplace.json.tmp \
   && mv .claude-plugin/marketplace.json.tmp .claude-plugin/marketplace.json

# 3) plugin.json version
jq --arg v "$NEW_VERSION" '.version = $v' \
   plugins/harness-eval/.claude-plugin/plugin.json > plugins/harness-eval/.claude-plugin/plugin.json.tmp \
   && mv plugins/harness-eval/.claude-plugin/plugin.json.tmp plugins/harness-eval/.claude-plugin/plugin.json
```

Also update the version badge near the top of `README.md` (`version-X.Y.Z-green.svg`). No
test checks it, so it drifts unless it is bumped here.

### 4. Update the CHANGELOG
Move the `[Unreleased]` entries into a new `[$NEW_VERSION] - YYYY-MM-DD` section in
`CHANGELOG.md`. Keep the English and Korean (한국어) sections in sync — both are bilingual
and must describe the same changes. Leave a fresh, empty `[Unreleased]` scaffold.

### 5. Validate and re-test
```bash
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null
python3 -m json.tool plugins/harness-eval/.claude-plugin/plugin.json > /dev/null

cd plugins/harness-eval && bash tests/harness-run-all.sh && cd -
```
The version-consistency assertions in the structure suite confirm the three manifests agree.

### 6. Commit, tag, and push
```bash
git add .claude-plugin/marketplace.json \
        plugins/harness-eval/.claude-plugin/plugin.json \
        CHANGELOG.md README.md
git commit -m "release: v$NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "harness-eval v$NEW_VERSION"
git push origin main
git push origin "v$NEW_VERSION"
```

### 7. Verify the published install
In a scratch directory, install from the marketplace and confirm the version:
```bash
claude plugin marketplace add https://github.com/whchoi98/harness-eval
claude plugin install harness-eval@harness-eval
```

## Verification
- [ ] `harness-run-all.sh` passes (harness checks, the four evaluation suites, and the shellcheck stage) on the release commit.
- [ ] `metadata.version`, `plugins[0].version`, and `plugin.json` `version` are all `$NEW_VERSION`, and the README version badge matches.
- [ ] Both manifests are valid JSON (`python3 -m json.tool`).
- [ ] `CHANGELOG.md` has a dated `[$NEW_VERSION]` section (EN + KO) and a fresh empty `[Unreleased]`.
- [ ] Tag `v$NEW_VERSION` exists on the remote and points at the release commit.
- [ ] A fresh `claude plugin install` reports the new version.

## Rollback
If a problem is found after tagging but before/after publishing:
```bash
# Remove the tag locally and remotely
git tag -d "v$NEW_VERSION"
git push origin ":refs/tags/v$NEW_VERSION"

# Revert the release commit (keeps history) or reset if not yet pushed
git revert --no-edit HEAD          # if already pushed
# git reset --hard HEAD~1          # only if the commit was never pushed
```
Then re-run this runbook from step 1 after fixing the underlying issue.

## Notes
- The three-way version lock is enforced by `tests/structure/test-plugin-structure.sh`;
  never bump one manifest without the others.
- Runtime evaluation artifacts (`.harness-eval/`) are gitignored and must never be part of
  a release commit.
- A release that follows a change in Claude's model line (a new, deprecated, or retired
  model, or a new target model for the agents) goes through `model-change.md` first, so the
  model tables, the agents' model and effort, and the measured run times are current.
- Last verified: 2026-09-24 (v0.3.0)
