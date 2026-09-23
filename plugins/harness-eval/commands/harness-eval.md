---
description: Evaluate Claude Code harness engineering quality
argument-hint: "[quick|standard|full|compare] [--static-only]"
allowed-tools: Read, Glob, Grep, Bash, Task
---

Evaluate the harness engineering quality of the current project.

## Usage

/harness-eval [mode] [options]

Modes:
- `quick` (default) — Checklist-based scoring in ~30 seconds
- `standard` — Static + dynamic analysis in 2-3 minutes; dynamic testing runs the target's hooks and tests after you confirm, and `--static-only` skips it
- `full` — Multi-agent comprehensive evaluation in 5-10 minutes
- `compare` — Compare with previous evaluation

## Routing

Arguments: $ARGUMENTS

The first word of the arguments is the mode (`quick` if there are none). For that mode, read `${CLAUDE_PLUGIN_ROOT}/skills/<mode>/SKILL.md` and follow it for the current project, applying the remaining arguments (for example `--static-only` for standard) as that mode's arguments. In that file, CLAUDE_PLUGIN_ROOT stands for this plugin's root, `${CLAUDE_PLUGIN_ROOT}`; your shell does not define that variable, so use the path itself in the commands you run and in any command you show the user.

If the mode is not one of quick, standard, full, compare, show the usage information above and list the valid modes.

This router sets no `effort`, because it also runs standard and full, so every mode runs here at the session's effort; the `effort: low` in the quick and compare skill files does not apply to a file you read. Those two modes are mechanical (run a script, then format its JSON), which is why their own commands, `/harness-eval:quick` and `/harness-eval:compare`, run at low effort. When routing to quick or compare, follow the skill's steps without extra investigation of the project.

<!-- The mode commands (`quick`, `standard`, `full`, `compare`) share their `harness-eval:<mode>` names with the same-named skills, and Claude Code surfaces the command's description for each name, so this router reads the skill file directly instead of invoking a skill by name. See skills/CLAUDE.md. Full mode dispatches subagents with the Agent tool; `Task` in allowed-tools is its legacy alias and still pre-approves it. The router has no `effort` key because it also routes to standard and full; quick and compare get `effort: low` only through their own commands, since a SKILL.md read with the Read tool contributes no frontmatter. -->

