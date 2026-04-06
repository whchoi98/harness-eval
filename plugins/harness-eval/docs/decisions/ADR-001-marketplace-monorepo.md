# ADR-001: Marketplace + Plugin Monorepo Structure

## Status
Accepted

## Context
The harness-eval plugin initially had a flat structure with `plugin.json` at the project root. To enable marketplace registration (`claude plugin marketplace add`), a separate marketplace repository was created. Managing two repositories for a single plugin added unnecessary complexity.

## Options Considered

### Option 1: Separate marketplace and plugin repositories
- **Pros**: Clear separation of concerns, independent versioning
- **Cons**: Two repos to maintain, SHA pinning required, sync overhead

### Option 2: Monorepo with marketplace.json at root and plugin in subdirectory
- **Pros**: Single repo, single URL for both marketplace and plugin, simpler maintenance
- **Cons**: Slightly more complex directory structure

## Decision
Adopted Option 2 — monorepo structure with `marketplace.json` at repo root pointing to `./plugins/harness-eval` via relative path. This follows the same pattern as `project-init` plugin.

## Consequences

### Positive
- Single `claude plugin marketplace add https://github.com/whchoi98/harness-eval` installs everything
- No cross-repo SHA synchronization needed
- Simpler CI/CD and versioning

### Negative
- Plugin files are nested one level deeper (`plugins/harness-eval/`)
- Test runner needs to resolve both REPO_ROOT and PLUGIN_ROOT
