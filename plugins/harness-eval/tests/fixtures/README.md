# Test Fixtures (mock projects — not real configuration)

Everything under this directory is **test data**, not deployable configuration. The
`.claude/` trees, `settings.json`, hook scripts, and sample credential files here exist
solely to drive the test suite. Do not copy them into a real project, and do not treat a
flagged pattern inside a fixture as a real secret.

## Maturity ladder (used by scoring / static-analysis tests)

| Fixture | Represents | Notes |
| ------- | ---------- | ----- |
| `minimal-project/`    | Bare project        | Basic checks fail |
| `functional-project/` | Hooks + skills      | Functional tier passes |
| `robust-project/`     | Tests + deny list   | Robust tier passes |
| `production-project/` | CI/CD + docs        | All checks pass (scores 10.0) |

These four are **frozen**. Their `settings.json` deliberately uses the legacy **flat** hook
schema (`{ "matcher": ..., "command": ... }`) to lock in backwards-compatibility coverage.
Do not modify their schema — add a new fixture directory instead.

## Other fixtures

- `nested-hooks-project/` — uses the real Claude Code **nested** hook schema
  (`.hooks.<Event>[].hooks[].command`). Regression fixture for the `hook-file-mapping` check.
- `secret-samples.txt` — prose describing secret patterns; contains **no real tokens** and
  must not trigger the scanner. Used as a false-negative guard in the secret-scan tests.
- `false-positives.txt` — credential-shaped-but-benign strings that must **not** be flagged.

See `tests/hooks/test-secret-patterns.sh` and `tests/test-static-analysis.sh` for how these
files are consumed.
