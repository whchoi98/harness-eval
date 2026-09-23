---
description: Compare harness evaluation history — current vs previous score/tier trends
allowed-tools: Read, Glob, Grep, Bash
effort: low
---

Compare the current evaluation with the immediately preceding one from history: current-vs-previous score and per-tier deltas, trend/diminishing-returns detection, and next-grade projection.

Read `${CLAUDE_PLUGIN_ROOT}/skills/compare/SKILL.md` and follow it for the current project. In that file, CLAUDE_PLUGIN_ROOT stands for this plugin's root, `${CLAUDE_PLUGIN_ROOT}`; your shell does not define that variable, so use the path itself in the commands you run and in any command you show the user.

Arguments: $ARGUMENTS

<!-- This command and the `compare` skill share the `harness-eval:compare` name. Claude Code surfaces this command's description for that name and hides the skill's, so the command delegates by reading the skill file instead of invoking the skill by name. Keep the two in sync (including `effort`); see skills/CLAUDE.md. -->
