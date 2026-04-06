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
- Quick/Standard invoke scripts directly; Full spawns agents
- All evaluation skills generate bilingual reports (English + Korean) as separate files
- Reports saved to `.harness-eval/reports/eval-{date}-{NNN}-{mode}-{en|ko}.md` in target project
