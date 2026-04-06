# Commands Module

## Role
User-facing slash command (`/harness-eval`) that serves as the primary entry point for evaluations.

## Key Files
- `harness-eval.md` — Routes user to appropriate evaluation skill based on arguments

## Rules
- Commands are registered in `plugin.json` under the `commands` array
- Must include frontmatter with `description` field
- Arguments determine which skill is invoked (quick, standard, full)
