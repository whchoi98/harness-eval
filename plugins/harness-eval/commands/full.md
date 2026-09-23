---
description: Full harness evaluation — multi-agent comprehensive review (~5-10min). Use when the user explicitly asks for a full, deep, or multi-agent harness evaluation. For a quick score use quick; for static plus dynamic checks use standard.
allowed-tools: Read, Glob, Grep, Bash, Task
---

Run a Full harness evaluation of the current project. It orchestrates the collector, safety-evaluator, completeness-evaluator, design-evaluator, and synthesizer agents.

Read `${CLAUDE_PLUGIN_ROOT}/skills/full/SKILL.md` and follow it for the current project. In that file, CLAUDE_PLUGIN_ROOT stands for this plugin's root, `${CLAUDE_PLUGIN_ROOT}`; your shell does not define that variable, so use the path itself in the commands you run and in any command you show the user.

Arguments: $ARGUMENTS

<!-- Note: this command and the `full` skill share the `harness-eval:full` name (intentional thin-wrapper pattern). Claude Code surfaces this command's description for the shared name, so the routing text lives here, and the body delegates to the skill file by path. See skills/CLAUDE.md for the coexistence rationale. -->
<!-- Subagents are dispatched with the Agent tool; `Task` in allowed-tools is its legacy alias and still pre-approves it. The skill specifies each subagent_type (harness-eval:collector, etc.). -->
