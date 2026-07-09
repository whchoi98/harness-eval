# Nested Hooks Fixture

Regression fixture for the `hook-file-mapping` static-analysis check.

Unlike the four maturity fixtures (minimal/functional/robust/production) which use
the legacy **flat** hook schema (`{ "matcher": ..., "command": ... }`), this fixture
uses the **real Claude Code nested** hook schema:

```json
{ "hooks": { "<Event>": [ { "matcher": ..., "hooks": [ { "type": "command", "command": "..." } ] } ] } }
```

It intentionally references one hook script that exists (`present-hook.sh`) and one
that does not (`missing-hook.sh`) so tests can assert that command extraction works
for the nested schema (PASS for the present file, FAIL for the missing one) and never
emits the pre-fix "Hook file missing: null" false negative.

This fixture is NOT part of the scoring/monotonic maturity ladder; it exists only to
exercise nested-schema parsing.
