---
description: Full harness evaluation — multi-agent comprehensive review (~5-10min)
allowed-tools: Read, Glob, Grep, Bash, Task
---

Run a full harness evaluation on the current project.

Activate the `full` skill from this plugin to perform multi-agent parallel evaluation with collector, safety-evaluator, completeness-evaluator, design-evaluator, and synthesizer.

<!-- Note: this command and the `full` skill share the `harness-eval:full` name (intentional thin-wrapper pattern). The command is the explicit slash-command entry point; the skill holds the actual evaluation steps. See skills/CLAUDE.md for the coexistence rationale. -->
<!-- Subagent dispatch uses the `Task` tool (not `Agent`); the skill specifies each subagent_type (harness-eval:collector, etc.). -->

