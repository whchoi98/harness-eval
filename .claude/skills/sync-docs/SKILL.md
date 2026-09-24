---
name: sync-docs
description: Bring harness-eval's CLAUDE.md files, architecture docs, and manifests back in line with the current code. Use when the user asks to sync or audit docs, or after structural changes.
---

# Sync Docs Skill

Synchronize project documentation with current code state.

## Actions

### 1. Assess
For each CLAUDE.md, list what is wrong or stale: commands that don't run as written against the actual scripts, structure/architecture statements that no longer match, hard-coded facts (test counts, versions, file lists) that disagree with the code, and conventions the code follows that the file doesn't mention. Share this list before editing.

### 2. Root CLAUDE.md
The root CLAUDE.md is a short pointer (Overview, Structure, Installation, Development) that defers to `plugins/harness-eval/CLAUDE.md`; keep it that way. Check that its commands run as written and its structure list matches the tree. Tech Stack, Conventions and Key Commands live in the plugin CLAUDE.md (its headings are asserted by test-plugin-structure.sh).

### 3. Architecture docs
There are two: `docs/architecture.md` (monorepo view) and `plugins/harness-eval/docs/architecture.md` (plugin internals, English and Korean sections). Update whichever the change affects and keep both language sections in sync.

### 4. Module CLAUDE.md Audit
- The module directories are `scripts/`, `skills/`, `hooks/`, `templates/`, `tests/` under `plugins/harness-eval/` (the set `tests/structure/test-plugin-structure.sh` checks). Make sure each has a CLAUDE.md that matches the code; do not create CLAUDE.md in their subdirectories.
- `commands/` and `agents/` are auto-discovered, so a CLAUDE.md there registers a bogus component - their notes live in the plugin-root CLAUDE.md "Module Notes".
- Never create CLAUDE.md under `tests/fixtures/`, and never edit the existing fixture projects (they are frozen test inputs; new coverage goes in a new fixture directory).

### 5. ADR and Runbook Audit
- Check recent commits for undocumented architectural decisions
- Verify runbook coverage against project characteristics
- Flag stale ADRs and outdated runbooks

### 6. Manifest Sync (monorepo)
- `plugins/harness-eval/.claude-plugin/plugin.json` is metadata-only (no
  `skills`/`agents`/`commands`/`hooks` path arrays — those are auto-discovered),
  so validate the auto-discovered component directories exist instead of checking
  path arrays.
- Verify version consistency across all four locations:
  `plugins/harness-eval/.claude-plugin/plugin.json` (`version`),
  `.claude-plugin/marketplace.json` (`metadata.version` and `plugins[].version`), and
  the README version badge (`version-X.Y.Z-green.svg` near the top of `README.md`).

### 7. Report
List each file changed and what was corrected.
