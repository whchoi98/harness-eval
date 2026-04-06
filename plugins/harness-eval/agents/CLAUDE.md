# Agents Module

## Role
Subagents for Full mode evaluation. Spawned in parallel by `skills/full.md` to perform qualitative analysis of target projects.

## Key Files
- `collector.md` — Gathers target project information (file structure, settings, scripts)
- `safety-evaluator.md` — Evaluates tool scope, deny lists, secret pattern safety
- `completeness-evaluator.md` — Evaluates event coverage, error recovery, doc completeness
- `design-evaluator.md` — Evaluates architecture quality, modularity, output schemas
- `synthesizer.md` — Aggregates evaluator results into final weighted report

## Rules
- All agents receive collector output as input context
- Evaluators produce component-level scores (0-10) with structured justification
- Synthesizer applies weighted averaging per `harness-evaluation-framework.md`
- Output must follow the report template in `templates/report-component.md`
