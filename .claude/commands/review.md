---
description: Review current changes in the harness-eval repo (scripts, hooks, SKILL/agent/command prompts) and report every issue with severity and confidence
allowed-tools: Read, Glob, Grep, Bash(git status:*), Bash(git diff:*), Bash(git log:*)
---

# Code Review

Review the current changes and report every issue with a severity and a confidence score.

## Step 1: Get Changes

Determine the scope of review:

- If $ARGUMENTS specifies files, review those files
- Otherwise, review all uncommitted work. List it with `git status --short --untracked-files=all` (the flag lists the files inside new directories), review tracked changes with `git diff HEAD` (staged and unstaged together), and Read each untracked (`??`) file in full, since a new file has no diff

## Step 2: Review

For each changed file, apply the code-review skill (`.claude/skills/code-review/SKILL.md`):
the repo contracts it lists, project guidelines from CLAUDE.md, and general correctness and security.

## Step 3: Score

Score each issue for severity and confidence per the code-review skill. Present confidence ≥ 75 first with fix suggestions; list lower-confidence items briefly after them. If nothing reaches 75, say so and still list the lower-confidence items.

## Step 4: Output

Use the code-review skill's output format: file path and line, issue, guideline, and fix for each item.

## Error Recovery

### If no changes found (Step 1)
If `git status --short --untracked-files=all` lists nothing, there is nothing uncommitted to review. Inform the user:
- Check if changes are committed: `git log -1 --oneline`
- Check if on the right branch: `git status --short --branch` (the first line names it)
- Suggest specifying files directly: `/review path/to/file`

### If CLAUDE.md is missing or empty (Step 2)
Cannot evaluate project guidelines without CLAUDE.md. Suggest:
- Run `/init` in a Claude Code session to generate CLAUDE.md
- Or create a minimal CLAUDE.md with conventions section

### If the diff is too large to review in one pass
Review it all; if you had to skip or skim files, list them in the report. Treat SKILL.md, agent, and command files as code, not documentation.
