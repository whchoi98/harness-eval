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
- The Stop hook runs at the end of every Claude response (the Stop event, not session end) in every project the plugin is installed in, so it must never modify user files without consent
- README auto-badge is **opt-in**: `post-eval-badge.sh` rewrites `README.md` (via `badge.sh`) only when `HARNESS_EVAL_AUTO_BADGE=1` or an untracked `.harness-eval/config.json` has `autoBadge: true`. Otherwise it writes a one-line note to stderr and exits 0; Claude Code does not show a Stop hook's output on exit 0, so the user does not see that note. It changes nothing but its `.harness-eval/.badge-seen` marker
- This hook is the only automatic badge path: no evaluation mode runs `badge.sh` (Full stopped doing so in 0.3.0). It handles each saved evaluation once: it acts when `.harness-eval/latest.json` is newer than the mtime recorded in `.harness-eval/.badge-seen` and less than a day old, then records that mtime. A history save (Standard or Full) produces such a file however long the rest of the response takes; Quick runs are not saved to history, so they never trigger it
- The repository must not be able to trigger the hook or grant the opt-in: it does nothing when `.harness-eval/`, `latest.json`, `config.json`, or `.badge-seen` is a symlink or when `latest.json` is tracked by git, and a git-tracked `config.json` is not an opt-in. `badge.sh` refuses a symlinked `README.md` (exit 2), and `history.sh save` refuses a symlinked `.harness-eval/`, `history.json`, or `latest.json`
- Do not swallow badge.sh stderr/failures with blanket `> /dev/null 2>&1 || true` — failures must stay visible. When an opted-in update fails, the hook exits 1, because Claude Code shows a Stop hook's stderr to the user only for exit codes other than 0 and 2 (2 would feed it back to the model instead)
