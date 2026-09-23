---
name: code-review
description: Review criteria and confidence scoring for changes in the harness-eval monorepo (Bash scripts, hooks, SKILL/agent prompts, manifests). Use when reviewing a diff, PR, or file set in this repo.
---

# Code Review Skill

Review changed code in this repo and report every issue with a severity and a confidence score.

## Review Scope

By default, review all uncommitted work: `git status --short --untracked-files=all` for the file list, `git diff HEAD` for tracked changes (staged and unstaged), and each untracked (`??`) file read in full, since a new file has no diff. The user may specify different files or scope.

## What to check in this repo

Beyond general correctness and security, the contracts most likely to break here (plugin paths are under `plugins/harness-eval/`):
- Scripts: target project root as `$1` (`aggregate.sh` reads stdin instead), JSON on stdout / logs on stderr, exit codes 0/1/2, `jq` checked at startup (`scripts/CLAUDE.md`). The SKILL.md files duplicate this contract for plugin users, so a script change must update them.
- Prompt files are code. SKILL, agent, and command `.md` files carry contracts other code parses - handoff lines and markers, report headings, JSON field names, headings asserted by `tests/structure/test-plugin-structure.sh`. A changed string must match every consumer; grep for it.
- Auto-discovery: no non-component `.md` (including CLAUDE.md) under `commands/` or `agents/`. Agents use `tools`; commands and skills use `allowed-tools`.
- The version must match in `plugin.json` `version` and `marketplace.json` `metadata.version` + `plugins[].version`.
- Plugin hooks must not modify user files without opt-in, and their failures stay visible (`hooks/CLAUDE.md`).
- The fixtures under `tests/fixtures/` are frozen test inputs; new coverage goes in a new fixture directory.
- Bilingual output: English and Korean reports and doc sections stay in sync.

## Confidence and severity

For each issue give a severity (critical / important / minor) and a confidence 0-100 that it is a real, newly introduced defect (90+: confirmed; 75-89: verified; 50-74: likely; below 50: speculative or pre-existing). Report every issue with its scores. The report shows items at 75+ first and groups the rest under "Lower confidence" - the reader filters, you don't drop.

## Output Format

For each issue:
### [CRITICAL|IMPORTANT|MINOR] <issue title> (confidence: XX)
**File:** `path/to/file.ext:line`
**Issue:** Clear description of the problem
**Guideline:** Reference to CLAUDE.md rule or security standard
**Fix:** Concrete code suggestion

List items with confidence ≥ 75 first, then a "Lower confidence" section; if nothing reaches 75, say so and still list the rest.
