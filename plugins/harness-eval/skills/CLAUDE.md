# Skills Module

## Role
User-facing evaluation entry points. Each skill defines an evaluation mode that Claude follows when invoked.

## Key Files
- `quick/SKILL.md` — Fast checklist evaluation (< 30 seconds)
- `standard/SKILL.md` — Static + dynamic analysis evaluation
- `full/SKILL.md` — Multi-agent orchestrator for comprehensive evaluation
- `compare/SKILL.md` — Comparative analysis between two evaluation results

## Rules
- Skills use `skills/<name>/SKILL.md` directory convention (auto-discovered by Claude Code)
- Not registered in plugin.json — discovered automatically from directory structure
- Each skill must define clear steps Claude follows sequentially
- Quick/Standard invoke scripts directly; Full spawns agents via the `Task` tool
- All evaluation skills generate bilingual reports (English + Korean) as separate files
- Reports saved to `.harness-eval/reports/eval-{date}-{NNN}-{mode}-{en|ko}.md` in target project

## Command/Skill coexistence
The `quick`, `standard`, `full`, and `compare` skills intentionally share their names with
same-named slash commands under `commands/` (e.g. both surface as `harness-eval:quick`). The
command is the explicit slash-command entry point (thin wrapper) and the skill holds the actual
evaluation steps and carries the model-facing `description` used for auto-triggering. Keep the
two in sync: if you rename or repurpose a mode, update both the `commands/<mode>.md` wrapper and
this skill so their descriptions do not diverge. Do NOT place a `CLAUDE.md` (or any non-component
`.md`) under `commands/` or `agents/` — those directories are auto-discovered and a stray `.md`
registers as a broken command/agent. Module notes for those directories live in the plugin-root
`CLAUDE.md` instead.
