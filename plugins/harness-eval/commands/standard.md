---
description: Standard harness evaluation — static + dynamic analysis (~2-3min). Dynamic testing runs the target's hooks and tests after the user confirms. Pass --static-only for repositories you do not trust.
argument-hint: "[--static-only]"
allowed-tools: Read, Glob, Grep, Bash
---

Run a standard harness evaluation on the current project.

Read `${CLAUDE_PLUGIN_ROOT}/skills/standard/SKILL.md` and follow it for the current project. In that file, CLAUDE_PLUGIN_ROOT stands for this plugin's root, `${CLAUDE_PLUGIN_ROOT}`; your shell does not define that variable, so use the path itself in the commands you run and in any command you show the user.

Arguments (they select the run mode, so apply them unchanged, including `--static-only` / `--no-dynamic`): $ARGUMENTS

<!-- This command and the `standard` skill share the `harness-eval:standard` name. Claude Code surfaces this command's description for that name and hides the skill's, so the command delegates by reading the skill file instead of invoking the skill by name. Keep the two descriptions in sync; see skills/CLAUDE.md. -->
