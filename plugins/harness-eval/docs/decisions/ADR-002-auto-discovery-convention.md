# ADR-002: Claude Code Auto-Discovery Convention Over Explicit Registration

## Status
Accepted

## Context
Claude Code plugins can register components (skills, agents, commands, hooks) either explicitly in `plugin.json` arrays or via directory convention (auto-discovery). The initial implementation used explicit `[{"name":"...","path":"..."}]` arrays, which caused validation errors during `claude plugin install`.

## Options Considered

### Option 1: Explicit registration in plugin.json
- **Pros**: All components visible in one manifest file
- **Cons**: Claude Code rejected the object-array format; required maintaining sync between manifest and files

### Option 2: Directory convention with auto-discovery
- **Pros**: Claude Code native pattern, no manifest sync issues, validated by working plugins (claude-hud, project-init)
- **Cons**: Component list not visible in plugin.json

## Decision
Adopted Option 2 — plugin.json contains metadata only. Components are discovered via directory convention:
- Skills: `skills/<name>/SKILL.md`
- Agents: `agents/<name>.md`
- Commands: `commands/<name>.md`
- Hooks: `hooks/hooks.json`

## Consequences

### Positive
- Plugin installs successfully without validation errors
- No manifest/file sync drift
- Follows proven patterns from official plugins

### Negative
- Cannot see component list from plugin.json alone — must browse directories
