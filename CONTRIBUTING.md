# Contributing to harness-eval

Thanks for contributing! harness-eval is a Claude Code plugin (shipped via a marketplace
monorepo) that evaluates the harness-engineering quality of other projects. It is written
almost entirely in Bash, with `jq` for JSON and `python3` for JSON validation.

## Prerequisites

- Git
- Bash 4+ (macOS ships 3.2 — install a newer bash via `brew install bash`)
- `jq` (`brew install jq` / `sudo apt install jq`)
- `bc` (used by the scoring tests)
- Python 3 (JSON validation)
- `shellcheck` (optional locally; runs in CI) — `brew install shellcheck` / `sudo apt install shellcheck`
- GNU `grep` with PCRE (`grep -P`) — required by the secret-scan hook (Linux has it; on
  macOS `brew install grep` and use `ggrep`/the gnubin PATH)

## Getting started

```bash
git clone https://github.com/whchoi98/harness-eval.git
cd harness-eval
bash scripts/install-hooks.sh        # optional: local git hooks
```

## Running the tests

From the plugin directory, `harness-run-all.sh` is the single entry point. It runs the
hooks/structure/secret-pattern harness checks, the three evaluation-script suites
(scoring/static-analysis/history), and a `shellcheck` stage (skipped if shellcheck is not
installed):

```bash
cd plugins/harness-eval
bash tests/harness-run-all.sh                 # everything
bash tests/harness-run-all.sh hooks           # only hook tests
bash tests/harness-run-all.sh structure       # only structure tests
```

You can also run the evaluation suites individually (they require `HARNESS_EVAL_ROOT`):

```bash
cd plugins/harness-eval
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-scoring.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-static-analysis.sh
HARNESS_EVAL_ROOT="$(pwd)" bash tests/test-history.sh
```

All of the above run automatically in CI (`.github/workflows/ci.yml`) on every push and
pull request. CI is the required gate — a PR must be green before merge.

## Coding conventions

Scripts and hooks:
- Target `$1` = target project root; `HARNESS_EVAL_ROOT` env var = plugin root (optional for
  `scoring.sh`/`static-analysis.sh`, which can auto-detect; not read by `history.sh`/`badge.sh`).
- JSON goes to **stdout**; human-readable logs go to **stderr**.
- Exit codes: `0` = success, `1` = issues found, `2` = script/usage error.
- Every script checks for `jq` at startup before processing.
- After editing any shell script, run `bash -n <file>` and fix all errors.
- Keep new `awk`/`jq` **injection-safe**: pass data with `awk -v` and `jq --arg` / `--argjson`,
  never by string-interpolating untrusted values into the program text.
- Claude Code hooks receive their event payload as **JSON on stdin** (parse with `jq`); there
  are no `$TOOL_INPUT`-style environment variables. A `PreToolUse` hook blocks a tool call by
  exiting with code **2** (only exit 2 is treated as a block).

Documentation:
- English source files stay in English; the CHANGELOG and README are intentionally bilingual
  (English + 한국어) and both halves must be kept in sync.
- New directory under the plugin root → add a `CLAUDE.md` there, EXCEPT `commands/` and
  `agents/`: Claude Code auto-discovers every `*.md` under those as a component, so do not
  place a `CLAUDE.md` (or any non-component `*.md`) in them.

## Tests and fixtures

- New behavior needs a test. Evaluation-script changes go in `tests/test-*.sh`; harness/dev
  changes go under `tests/hooks/` or `tests/structure/`.
- The four maturity fixtures (`tests/fixtures/{minimal,functional,robust,production}-project/`)
  are frozen. In particular, **do not change an existing fixture's `settings.json` schema** —
  the flat hook schema there is a deliberate legacy-compatibility case. Add a NEW fixture
  directory if you need to exercise a different shape (see `nested-hooks-project/`).
- `tests/fixtures/secret-samples.txt` and `false-positives.txt` are data sources for the
  secret-scan end-to-end tests — keep them prose-only / non-triggering as documented.

## Pull requests

1. Branch off the default branch; never commit directly to it.
2. Keep changes additive where possible — the test suite guards existing output schemas.
3. Run `bash tests/harness-run-all.sh` locally and make sure it is green.
4. Describe what changed and how you verified it.
5. For anything that changes the plugin version, follow
   `plugins/harness-eval/docs/runbooks/release.md`.

## Security

Please report vulnerabilities privately — see [SECURITY.md](SECURITY.md).
