# Hooks Module

## Role
Plugin-provided hooks that trigger on Claude Code events. Registered via `hooks.json`, not plugin.json.

## Key Files
- `hooks.json` — Hook event registration (Stop event -> post-eval-badge.sh)
- `post-eval-badge.sh` — Generates evaluation badge after assessment completes

## Rules
- Hooks are registered in `hooks.json` using `${CLAUDE_PLUGIN_ROOT}` for portable paths
- Shell scripts must be executable (`chmod +x`)
- Must handle missing dependencies gracefully (exit 0 on missing jq, etc.)
- Plugin hooks differ from dev hooks in `.claude/hooks/` — these are shipped with the plugin
