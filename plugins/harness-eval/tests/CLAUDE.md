# Tests Module

## Role
Automated test suite validating evaluation scripts and plugin structure integrity.

## Key Files
- `test-scoring.sh` — Tests scoring.sh against all 4 fixture levels (15 tests)
- `test-static-analysis.sh` — Tests static-analysis.sh correctness (23 tests)
- `test-history.sh` — Tests history.sh storage and retrieval (19 tests)
- `harness-run-all.sh` — Harness validation runner (104 tests: hooks, secret patterns, structure)
- `hooks/test-hooks.sh` — Dev hook existence, permissions, registration, behavior tests
- `hooks/test-secret-patterns.sh` — Secret detection true positive / false positive tests
- `structure/test-plugin-structure.sh` — Manifest, directory convention, CLAUDE.md coverage tests
- `fixtures/` — 4-level maturity mock projects

## Rules
- All test files must be executable (`chmod +x`)
- Evaluation tests (test-scoring.sh etc.) run from plugin directory with `HARNESS_EVAL_ROOT=$(pwd)`
- Harness tests (harness-run-all.sh) resolve `REPO_ROOT` (monorepo root) and `PLUGIN_ROOT` (this directory) automatically
- Harness tests validate both repo-level files (.claude/) and plugin-level files (this directory)
- Exit code 0 = all pass, 1 = failures detected
- Test fixtures must not be modified by tests (read-only)
- Fixture levels: minimal (basic), functional (hooks+skills), robust (tests+deny), production (CI/CD+docs)
