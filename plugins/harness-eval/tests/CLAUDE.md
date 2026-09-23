# Tests Module

## Role
Automated test suite validating evaluation scripts and plugin structure integrity.

## Key Files
- `test-scoring.sh` — Tests scoring.sh against all 4 fixture levels (24 tests)
- `test-static-analysis.sh` — Tests static-analysis.sh correctness, including the `model-config` and `agent-format` checks against `fixtures/model-era-project/` and temp fixtures (provider-form and unrecognized model IDs, the served-ID table, `env.CLAUDE_CODE_EFFORT_LEVEL` and the `CLAUDE_CODE_DISABLE_*THINKING` flags, the Bedrock and Vertex spellings of Opus 5 under the thinking-cap exemption, plugin roots, CRLF and unclosed frontmatter, thinking caps under a model that accepts disabled thinking) (107 tests)
- `test-history.sh` — Tests history.sh storage and retrieval, the refusal to write through a symlinked `.harness-eval/`, `history.json`, or `latest.json`, the self-ignoring `.harness-eval/.gitignore`, the file mode of `latest.json`, and that a save keeps the mode of existing files (`chmod 600`) (38 tests)
- `test-aggregate.sh` — Tests aggregate.sh: full and missing dimensions, weight renormalization, rejected input, grade-boundary parity with scoring.sh, status boundaries, and history.sh/badge.sh compatibility of its record (74 tests)
- `harness-run-all.sh` — Harness validation runner (447 total: 204 harness-validation checks for hooks, secret patterns, structure, version, Full-mode contracts, shellcheck + re-runs the 4 eval suites above, 243 tests). A suite that exits without a `Results:` line is recorded as a FAIL with its exit code and the last 15 lines of its output, and a missing `hooks/` or `structure/` directory is a FAIL; the runner continues to the next suite and prints the summary in both cases
- `hooks/test-hooks.sh` — Dev hook existence, permissions, registration, behavior tests (27 checks)
- `hooks/test-plugin-hooks.sh` — Plugin Stop hook (`post-eval-badge.sh`): opt-in, the once-per-evaluation marker, symlink and git-tracked refusals, and `badge.sh`'s README guards, including the malformed-block message for an unclosed badge block and a separate message when awk itself fails (33 checks; without git, its 3 git checks become 1 skip)
- `hooks/test-secret-patterns.sh` — Secret detection true positive / false positive tests (25 checks)
- `structure/test-plugin-structure.sh` — Manifest, directory convention, CLAUDE.md coverage, version consistency, agent frontmatter (`name`/`description`/`model`/`effort`, with each plugin and dev agent's `model` and `effort` checked against `MODEL_ALIASES`, `KNOWN_MODEL_ID_PATTERN`, and `FRONTMATTER_EFFORT_LEVELS` read from `static-analysis.sh`), dev skill `description`, no `.yml`/`.yaml` agent files, `static-analysis.sh` run on the repository root (`model-config` and `agent-format` must PASS; results for the gitignored `.claude/settings.local.json` are left out), and the Full-mode string contracts: `ARTIFACT_WRITTEN`, the `EVAL_ID`/`REPORT_EN`/`REPORT_KO`/`SCORE`/`MISSING` lines, the `SCRIPT_FAILED`/`AGENT_FAILED` markers, `subagent_type` names, evaluator `## Scores` dimension names against `synthesizer.md`, the synthesizer heredoc keys against `aggregate.sh`, and the static-analysis categories. The contract checks run `aggregate.sh` and `static-analysis.sh` (on `fixtures/minimal-project`, read-only), so they need `jq` (118 checks; the count grows with the number of agent and dev skill files)
- `fixtures/` — 4 frozen maturity mock projects, `nested-hooks-project/` (nested hook schema), `model-era-project/` (model pins and agent formats); see `fixtures/README.md`

## Rules
- All test files must be executable (`chmod +x`)
- Evaluation tests (test-scoring.sh etc.) run from plugin directory with `HARNESS_EVAL_ROOT=$(pwd)`
- Harness tests (harness-run-all.sh) resolve `REPO_ROOT` (monorepo root) and `PLUGIN_ROOT` (this directory) automatically
- Harness tests validate both repo-level files (.claude/) and plugin-level files (this directory)
- Exit code 0 = all pass, 1 = failures detected
- A new evaluation suite must print a `Results: N passed, M failed` line and be listed in `EVAL_SUITES` in `harness-run-all.sh`
- Test fixtures must not be modified by tests (read-only)
- The four maturity fixtures and `nested-hooks-project/` are frozen: when a new check changes their results, update the test expectations, and add a new fixture for a new shape
- `model-era-project/` changes together with the model tables in `scripts/static-analysis.sh` at each model release; `../docs/runbooks/model-change.md` lists the rest of what to re-check then
- The Full-mode contract checks assume every `agents/*.md` is a Full-mode agent dispatched by `skills/full/SKILL.md`, and they name the two Phase 1 scripts; update them when a non-Full agent or a Phase 1 script is added
- Fixture levels: minimal (basic), functional (hooks+skills), robust (tests+deny), production (CI/CD+docs)
- When tests are added or removed, update the counts here, in the plugin-root `CLAUDE.md`, `README.md` (both halves), and `docs/onboarding.md`, from an actual runner result
