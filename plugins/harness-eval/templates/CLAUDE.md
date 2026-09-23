# Templates Module

## Role
Structured templates for evaluation. `checklist.json` is a runtime input to scoring; the two report templates are reference material only.

## Key Files
- `checklist.json` — Tiered check definitions for Quick/Standard modes. A JSON object with a `version` string and a `tiers` map (`basic`, `functional`, `robust`, `production`); each tier has a `label`, a `weight`, and an `items` array. Each item has an `id`, `description`, `type` (e.g. `file_exists`, `glob_min`, `json_keys_present`, `grep_match`), and type-specific params (`target`/`targets`, `path`, `keys`, `pattern`, `min`). This is the canonical scored checklist consumed by `scripts/scoring.sh`.
- `report-full.md` — Early Full-mode report template (bilingual: English section + Korean section). Reference only.
- `report-component.md` — Early component-level report template (bilingual). Reference only.

## Rules
- `checklist.json` must be valid JSON (validate with `python3 -m json.tool`)
- Changes to checklist.json affect scoring across all evaluation modes
- `func-agent` (at least one `.claude/agents/*.md`, functional tier) is a proxy kept for Quick/Standard score continuity. Full mode's Agent Communication rubric does not count a harness without subagents as a defect, so the two can disagree for such a project; changing the item shifts every Quick/Standard score and history trend, which is why it is a separate follow-up (see framework §7)
- No skill, agent, command, or script reads `report-full.md` or `report-component.md`. The report formats that runs actually produce are defined in `skills/quick/SKILL.md`, `skills/standard/SKILL.md`, `skills/compare/SKILL.md`, and (Full) `agents/synthesizer.md`; change those, not these templates, to change a report
- The two report templates keep both languages in one file separated by `---` and use an older section layout (a category-only Summary table, Static/Dynamic Analysis, Checklist Results). The Full report is now two separate files with a per-dimension score table, written by the synthesizer, so do not copy the templates' layout into a runtime prompt
