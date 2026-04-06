# Tests Module

## Role
Automated test suite validating evaluation scripts and plugin structure integrity.

## Key Files
- `test-scoring.sh` — Tests scoring.sh against all 4 fixture levels
- `test-static-analysis.sh` — Tests static-analysis.sh correctness
- `test-history.sh` — Tests history.sh storage and retrieval
- `run-all.sh` — Test runner with TAP-style assertions (in `tests/` root after init)
- `fixtures/` — 4-level maturity mock projects

## Rules
- All test files must be executable (`chmod +x`)
- Tests use `HARNESS_EVAL_ROOT=$(pwd)` to point scripts at the plugin
- Exit code 0 = all pass, 1 = failures detected
- Test fixtures must not be modified by tests (read-only)
- Fixture levels: minimal (basic), functional (hooks+skills), robust (tests+deny), production (CI/CD+docs)
