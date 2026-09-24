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
- `model-era-project/` — model pins and effort settings in agent/skill/command frontmatter
  and `settings.json` (retired, deprecated, dated-snapshot, unrecognized and valid values,
  including well-shaped IDs that name no served model; thinking caps and the env thinking
  flags; an invalid `CLAUDE_CODE_EFFORT_LEVEL`), plus `.yml`/`.json` agent files. Its skill
  uses the layout Claude Code loads (`.claude/skills/<name>/SKILL.md`) next to a supporting
  `.md` that must not be read. Regression fixture for the `model-config` and `agent-format`
  checks; its `CLAUDE.md` lists the expected result per file. Update the model values here
  and the model tables in `scripts/static-analysis.sh` together at each model release. The
  `settings.local.json`, plugin-root, CRLF, served-ID table, valid `CLAUDE_CODE_EFFORT_LEVEL`
  and thinking-cap exemption cases (including the Bedrock and Vertex spellings of Opus 5)
  live in temp fixtures inside `tests/test-static-analysis.sh`: `*.local.json` is
  gitignored, a plugin manifest in this fixture would change what it measures, and one
  settings file can pin only one model.
- `secret-samples.txt` — prose describing secret patterns; contains **no real tokens** and
  must not trigger the scanner. Used as a false-negative guard in the secret-scan tests.
- `false-positives.txt` — credential-shaped-but-benign strings that must **not** be flagged.

See `tests/hooks/test-secret-patterns.sh` and `tests/test-static-analysis.sh` for how these
files are consumed.
