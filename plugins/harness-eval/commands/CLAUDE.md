# Commands Module

## Role
User-facing slash commands for evaluation. Each `.md` file in this directory is auto-discovered by Claude Code as a `/harness-eval:<name>` command.

## Key Files
- `harness-eval.md` — Main entry point with `argument-hint: [quick|standard|full|compare]`
- `quick.md` — Direct quick evaluation command
- `standard.md` — Direct standard evaluation command
- `full.md` — Direct full evaluation command
- `compare.md` — Direct compare evaluation command

## Rules
- Commands are auto-discovered from this directory (not registered in plugin.json)
- Must include frontmatter with `description` and `allowed-tools` fields
- `argument-hint` in frontmatter makes options visible in Claude Code UI
- Each mode command activates the corresponding skill from `skills/<mode>/SKILL.md`
