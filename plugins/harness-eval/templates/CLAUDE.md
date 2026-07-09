# Templates Module

## Role
Structured templates that define evaluation criteria and report formats. All report templates support bilingual output (English + Korean).

## Key Files
- `checklist.json` — Tiered check definitions for Quick/Standard modes. A JSON object with a `version` string and a `tiers` map (`basic`, `functional`, `robust`, `production`); each tier has a `label`, a `weight`, and an `items` array. Each item has an `id`, `description`, `type` (e.g. `file_exists`, `glob_min`, `json_keys_present`, `grep_match`), and type-specific params (`target`/`targets`, `path`, `keys`, `pattern`, `min`). This is the canonical scored checklist consumed by `scripts/scoring.sh`.
- `report-full.md` — Full mode comprehensive report template (bilingual: English section + Korean section)
- `report-component.md` — Component-level evaluation report template (bilingual)

## Rules
- `checklist.json` must be valid JSON (validate with `python3 -m json.tool`)
- Report templates use Markdown with placeholder variables
- Both report templates contain English and Korean sections separated by `---`
- Changes to checklist.json affect scoring across all evaluation modes
