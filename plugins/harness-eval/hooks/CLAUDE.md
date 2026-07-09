# Hooks Module

## Role
Plugin-provided hooks that trigger on Claude Code events. Registered via `hooks.json`, not plugin.json.

## Key Files
- `hooks.json` — Hook event registration (Stop event -> post-eval-badge.sh)
- `post-eval-badge.sh` — Updates the README badge after an evaluation completes (opt-in only)

## Rules
- Hooks are registered in `hooks.json` using `${CLAUDE_PLUGIN_ROOT}` for portable paths
- Shell scripts must be executable (`chmod +x`)
- Must handle missing dependencies gracefully (exit 0 on missing jq, etc.)
- Plugin hooks differ from dev hooks in `.claude/hooks/` — these are shipped with the plugin
- The Stop hook runs on every session end in every project the plugin is installed in, so it must never modify user files without consent
- README auto-badge is **opt-in**: `post-eval-badge.sh` rewrites `README.md` (via `badge.sh`) only when `HARNESS_EVAL_AUTO_BADGE=1` or `.harness-eval/config.json` has `autoBadge: true`. Otherwise it prints a one-line stderr notice (only when a fresh evaluation exists) and exits without touching files
- Do not swallow badge.sh stderr/failures with blanket `> /dev/null 2>&1 || true` — failures must stay visible
