---
description: Quick harness evaluation — checklist-based scoring (~30s)
allowed-tools: Read, Glob, Grep, Bash
effort: low
---

Run a quick harness evaluation on the current project.

Read `${CLAUDE_PLUGIN_ROOT}/skills/quick/SKILL.md` and follow it for the current project. In that file, CLAUDE_PLUGIN_ROOT stands for this plugin's root, `${CLAUDE_PLUGIN_ROOT}`; your shell does not define that variable, so use the path itself in the commands you run and in any command you show the user.

Arguments: $ARGUMENTS

<!-- This command and the `quick` skill share the `harness-eval:quick` name. Claude Code surfaces this command's description for that name and hides the skill's, so the command delegates by reading the skill file instead of invoking the skill by name. Keep the two in sync (including `effort`); see skills/CLAUDE.md. -->
