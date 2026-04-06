# Hooks Module

## Role
Plugin-provided hooks that trigger on Claude Code events in evaluated projects.

## Key Files
- `post-eval-badge.sh` — Generates evaluation badge after assessment completes (Stop event)

## Rules
- Hooks are registered in `.claude-plugin/plugin.json` under the `hooks` array
- Must be executable (`chmod +x`)
- Must handle missing dependencies gracefully (exit 0 on missing jq, etc.)
- Plugin hooks differ from dev hooks in `.claude/hooks/` — these are shipped with the plugin
