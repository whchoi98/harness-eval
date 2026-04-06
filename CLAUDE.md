# harness-eval Plugin

Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하는 플러그인.

## Architecture

- **3-tier evaluation**: Quick (checklist) → Standard (static+dynamic) → Full (multi-agent)
- **Hybrid**: Deterministic scripts for quantitative checks, agent prompts for qualitative review
- **Generation/Evaluation separation**: Full mode uses separate collector, evaluator, and synthesizer agents

## Key Paths

- `scripts/` — Bash scripts (scoring.sh, static-analysis.sh, history.sh, badge.sh)
- `templates/checklist.json` — Check definitions for Quick/Standard modes
- `skills/` — User-facing evaluation skills (quick, standard, full, compare)
- `agents/` — Subagents for Full mode evaluation
- `tests/fixtures/` — Mock projects at 4 maturity levels for testing

## Conventions

- All scripts: `$1` = target project root, `HARNESS_EVAL_ROOT` env var = plugin root
- Script output: JSON to stdout, human logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error
- All scripts check for `jq` dependency at startup
