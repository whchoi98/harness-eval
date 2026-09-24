---
name: release
description: Cut a harness-eval release - bump the version in the three manifest fields and the README version badge, update CHANGELOG (EN+KO), tag. Use only when the user asks to release.
disable-model-invocation: true
---

# Release Skill

This repository is a monorepo: the marketplace manifest is at the root
(`.claude-plugin/marketplace.json`) and the plugin lives under
`plugins/harness-eval/`.

## Procedure

Follow `plugins/harness-eval/docs/runbooks/release.md` §1-6 - it is the single source for the command sequence: run `bash tests/harness-run-all.sh` from `plugins/harness-eval/` (it covers every suite), bump the three manifest fields and the README version badge (`version-X.Y.Z-green.svg`), move `[Unreleased]` into a dated `[X.Y.Z] - YYYY-MM-DD` section in both the English and 한국어 halves of CHANGELOG.md (leave an empty `[Unreleased]`), commit, then create the annotated tag on that commit.

Propose the version from the changes since the last tag (there may be no tag yet), using the runbook's SemVer rules (MAJOR = breaking plugin contract: script args, output schema, events), and show the CHANGELOG diff before committing. Do not push the branch or tag without the user's go-ahead.

## Summary

- Version bump (old → new)
- Key changes
- Next steps (push the branch and tag; verify the install per runbook §7)
