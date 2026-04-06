# Scripts Module

## Role
Deterministic evaluation scripts that produce quantitative metrics. Each script accepts a target project root as `$1` and outputs structured JSON to stdout.

## Key Files
- `scoring.sh` — Checklist-based scoring engine (Quick/Standard modes)
- `static-analysis.sh` — Bash syntax, JSON validity, permissions, registration checks
- `history.sh` — Evaluation history storage, trend analysis, JSON history file management
- `badge.sh` — Score-to-badge conversion (A+ through F), SVG and markdown output
- `setup.sh` — New developer setup (prerequisites check, permissions, JSON validation)
- `install-hooks.sh` — Git commit-msg hook installer (AI co-author removal)

## Rules
- All evaluation scripts require `HARNESS_EVAL_ROOT` env var pointing to plugin root
- `$1` = target project root (required, validated at startup)
- JSON output to stdout only; human-readable logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error
- Check for `jq` dependency at startup before any processing
- `setup.sh` and `install-hooks.sh` are development utilities, not evaluation scripts
