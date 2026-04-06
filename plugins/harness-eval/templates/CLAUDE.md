# Templates Module

## Role
Structured templates that define evaluation criteria and report formats. All report templates support bilingual output (English + Korean).

## Key Files
- `checklist.json` — Check definitions for Quick/Standard modes (JSON array of checks with categories, weights, descriptions)
- `report-full.md` — Full mode comprehensive report template (bilingual: English section + Korean section)
- `report-component.md` — Component-level evaluation report template (bilingual)

## Rules
- `checklist.json` must be valid JSON (validate with `python3 -m json.tool`)
- Report templates use Markdown with placeholder variables
- Both report templates contain English and Korean sections separated by `---`
- Changes to checklist.json affect scoring across all evaluation modes
