---
name: summary-agent
description: Template the summarize skill copies when it scaffolds a new agent
model: claude-3-opus-20240229
---

Supporting file of the summarize skill, not a skill definition. Claude Code loads a
skill only from `.claude/skills/<name>/SKILL.md`, so `model-config` does not read this
frontmatter and its retired model ID is not flagged.
