---
description: Evaluate Claude Code harness engineering quality
argument-hint: [quick|standard|full|compare]
allowed-tools: Read, Glob, Grep, Bash, Agent
---

Evaluate the harness engineering quality of the current project.

## Usage

/harness-eval [mode]

Modes:
- `quick` (default) — Checklist-based scoring in ~30 seconds
- `standard` — Static + dynamic analysis in 2-3 minutes  
- `full` — Multi-agent comprehensive evaluation in 5-10 minutes
- `compare` — Compare with previous evaluation

## Routing

Parse the mode argument (first argument, or "quick" if none provided).

Based on the mode, activate the corresponding skill from this plugin:
- **quick** → Use the `quick` skill
- **standard** → Use the `standard` skill
- **full** → Use the `full` skill
- **compare** → Use the `compare` skill

If an unrecognized mode is provided, show the usage information above and list the valid modes.
