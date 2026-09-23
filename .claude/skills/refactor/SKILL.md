---
name: refactor
description: Behavior-preserving refactors of harness-eval scripts, hooks, and prompts, verified by the repo's test runner. Use when the user asks to restructure or clean up code without changing behavior.
---

# Refactor Skill

Refactor without changing behavior.

- Before editing, show the user what will change, what will not, and the risk; wait for their go-ahead.
- Behavior is defined by the tests and by the scripts' JSON output contracts that skills and agents consume (field names, exit codes). A refactor is done when `cd plugins/harness-eval && bash tests/harness-run-all.sh` passes with no edits to tests or fixtures; run it after each meaningful step.
- If a needed test is missing, propose adding it first.
