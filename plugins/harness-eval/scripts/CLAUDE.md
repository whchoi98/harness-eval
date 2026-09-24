# Scripts Module

## Role
Deterministic evaluation scripts that produce quantitative metrics. Each evaluation script accepts a target project root as `$1` (except `aggregate.sh`, which reads JSON on stdin) and outputs structured JSON to stdout.

## Key Files
- `scoring.sh` — Checklist-based scoring engine (Quick/Standard modes)
- `static-analysis.sh` — Per-category checks with a 0-10 score per category. Correctness: bash syntax, JSON validity, hook-file mapping, hook permissions, `model-config`, `agent-format`. Safety: tool scope, deny list. Completeness: hook event coverage, root CLAUDE.md. Consistency: frontmatter consistency
- `aggregate.sh` — Full-mode aggregation: reads `{"dimensions": {<12 keys>: 0-10 | null}}` (optional `timestamp`, `mode`) on stdin and prints the canonical history record (`timestamp`, `mode`, `scores.overall`, `scores.grade`, `dimensions`, `categories`, per-dimension `status`, `missing`). Category weights 0.50/0.25/0.25 are renormalized over the categories that have scores. It rejects unknown keys, out-of-range values, and all-null input with exit 2
- `lib/grade.sh` — Sourced helper (not executable) defining `score_to_grade`, the only copy of the grade thresholds (A+ ≥9.5, A ≥9.0, A- ≥8.5, B+ ≥8.0, B ≥7.0, C ≥6.0, else F). `scoring.sh` and `aggregate.sh` source it relative to their own location
- `history.sh` — Evaluation history storage, trend analysis, JSON history file management (`save` appends the stdin record verbatim and rewrites `latest.json`). It refuses (exit 2) to write when `.harness-eval/`, `history.json`, or `latest.json` is a symlink or not a regular file/directory, writes every file through a temp file plus `mv -f` (an existing file keeps its mode, read with GNU then BSD `stat`; a new file gets the umask default), and creates `.harness-eval/.gitignore` (`*`) only when no file or link has that name
- `badge.sh` — Score-to-badge conversion (A+ through F), SVG and markdown output; rewrites or creates the target's README.md. It refuses (exit 2) a README.md that is a symlink (dangling included) or not a regular file, and rewrites through a `mktemp` file that keeps README.md's mode. The badge block reaches `awk` through `ENVIRON` because BSD awk rejects a newline in a `-v` value; awk exit 3 means a malformed marker block, any other failure is reported as a failed rewrite, and both exit 2
- `setup.sh` — New developer setup (prerequisites check, permissions, JSON validation)
- `install-hooks.sh` — Git commit-msg hook installer (AI co-author removal)

## Rules
- `scoring.sh` and `static-analysis.sh` use `HARNESS_EVAL_ROOT` (plugin root) if set, otherwise auto-detect the plugin root from the script's own location — it is optional, not required
- `history.sh`, `badge.sh`, and `aggregate.sh` do not read `HARNESS_EVAL_ROOT`
- `$1` = target project root (required, validated at startup); `aggregate.sh` takes no arguments and treats any argument as a usage error
- JSON output to stdout only; human-readable logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error (`aggregate.sh`: 0 or 2 only)
- Check for `jq` dependency at startup before any processing
- Pass untrusted values to `awk`/`jq` as data (`awk -v`, `jq --arg`/`--argjson`), never by interpolating them into the program text (a multi-line value goes through `ENVIRON`, since BSD awk rejects newlines in `-v`)
- `scoring.sh` output is a contract that the tests, `history.sh compare`, and the Quick/Standard skills read, so change it only deliberately and update those consumers in the same change
- `model-config` reads only YAML frontmatter `model:`/`effort:` (never file bodies) in the files Claude Code loads: `.claude/{agents,commands}/**/*.md`, `.claude/skills/<name>/SKILL.md`, and the same `agents/`, `commands/` and `skills/<name>/SKILL.md` under each plugin root (a directory with `.claude-plugin/plugin.json`: the target itself or `plugins/*/`). From settings it reads `model`, `effortLevel`, `alwaysThinkingEnabled`, and from `env`: `MAX_THINKING_TOKENS`, `CLAUDE_CODE_EFFORT_LEVEL`, `CLAUDE_CODE_DISABLE_THINKING`, `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`, and model env vars (`*_MODEL`, `*_MODEL_FORCE`, `*_MODEL_OPTION`) whose value contains `claude-`
- Thinking caps (`alwaysThinkingEnabled: false`, `env.MAX_THINKING_TOKENS`, and either `DISABLE_*THINKING` flag when it is `1`, `true`, `yes` or `on`, the values Claude Code reads as on) are a WARN only when the settings model is not one that accepts disabled thinking (Haiku, Sonnet, Opus 4.x, Opus 5, Claude 3). The model is compared as its undated ID (`mc_reduce_id`), so `us.anthropic.claude-opus-5-v1:0` and `claude-opus-5@20260115` are exempt like `claude-opus-5`, and `claude-opus-5-5` is not
- `env.CLAUDE_CODE_EFFORT_LEVEL` is always a WARN. A value Claude Code accepts there (`ENV_EFFORT_LEVELS` or an integer; `auto` and `unset` select the model default) replaces the effort of the session and of every agent, skill and command, including effort pinned in frontmatter; any other value is ignored by Claude Code. Neither is counted in the aggregated PASS
- Dated IDs are a WARN only in Anthropic API form; Bedrock and Vertex dated IDs are valid pins. A `claude-*` ID whose undated form does not match `KNOWN_MODEL_ID_PATTERN` is a WARN. The pattern lists each served ID rather than a version shape, so a typo such as `claude-opus-55` or a never-released `claude-sonnet-4-7` does not pass as current
- `agent-format` scans `.claude/agents/` and each plugin root's `agents/`
- The model tables (`MODEL_ALIASES`, `RETIRED_MODEL_PATTERNS`, `DEPRECATED_MODEL_PATTERNS`, `KNOWN_MODEL_ID_PATTERN`, the effort-level lists) follow the claude-api skill's `shared/models.md` (Current and Legacy tables for the served IDs); at each model release or retirement, update them together with `tests/fixtures/model-era-project/` and the expectations in `tests/test-static-analysis.sh`, including its served-ID list
- `tests/structure/test-plugin-structure.sh` reads `MODEL_ALIASES`, `FRONTMATTER_EFFORT_LEVELS` and `KNOWN_MODEL_ID_PATTERN` out of `static-analysis.sh` by name to validate the plugin and dev agents' `model`/`effort`, so keep each on one line in its current form (`NAME=(a b c)`, `KNOWN_MODEL_ID_PATTERN='...'`)
- `extract_frontmatter` is shared by `frontmatter-consistency` and `model-config`: it reads CRLF files, and a block without a closing `---` counts as no frontmatter
- `setup.sh` and `install-hooks.sh` are development utilities, not evaluation scripts
