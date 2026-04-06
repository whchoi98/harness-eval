# Skills Module

## Role
User-facing evaluation entry points. Each skill defines an evaluation mode that Claude follows when invoked.

## Key Files
- `quick.md` — Fast checklist evaluation (< 30 seconds)
- `standard.md` — Static + dynamic analysis evaluation
- `full.md` — Multi-agent orchestrator for comprehensive evaluation
- `compare.md` — Comparative analysis between two evaluation results

## Rules
- Skills are registered in `plugin.json` under the `skills` array
- Each skill must define clear steps Claude follows sequentially
- Quick/Standard invoke scripts directly; Full spawns agents
- All skills reference `templates/checklist.json` for check definitions
