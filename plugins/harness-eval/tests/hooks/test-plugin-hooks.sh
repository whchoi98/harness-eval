#!/bin/bash
# Tests for the plugin's own Stop hook (hooks/post-eval-badge.sh) and the
# badge.sh symlink guards it relies on: opt-in, once-per-evaluation handling,
# and refusal of repository-planted links and git-tracked files.
#
# Sourced by tests/harness-run-all.sh, which provides PLUGIN_ROOT and the
# assert helpers. Every name here is PH_/ph_-prefixed so nothing collides
# with the runner's variables, and nothing here calls exit.

PH_HOOK="$PLUGIN_ROOT/hooks/post-eval-badge.sh"
PH_BADGE="$PLUGIN_ROOT/scripts/badge.sh"
PH_TMP="$(mktemp -d)"
PH_LATEST_JSON='{"timestamp":"2026-09-23T00:00:00Z","mode":"standard","scores":{"overall":8.1,"grade":"B+"}}'
PH_START='<!-- harness-eval-badge:start -->'
PH_NOW="$(date +%s)"

# ph_project <name>: a project with README.md and an untracked latest.json.
ph_project() {
  local d="$PH_TMP/$1"
  mkdir -p "$d/.harness-eval"
  printf '# Project\n' > "$d/README.md"
  printf '%s\n' "$PH_LATEST_JSON" > "$d/.harness-eval/latest.json"
  echo "$d"
}

# ph_run_hook <dir> [VAR=value ...]: run the hook from <dir> (Claude Code runs
# hooks in the project directory) with HARNESS_EVAL_AUTO_BADGE unset unless
# given, and print its exit code.
ph_run_hook() {
  local dir="$1" rc
  shift
  (cd "$dir" && env -u HARNESS_EVAL_AUTO_BADGE CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$@" \
    bash "$PH_HOOK" >/dev/null 2>&1)
  rc=$?
  echo "$rc"
}

# ph_run_badge <dir>: run badge.sh on <dir> and print its exit code.
ph_run_badge() {
  local rc
  bash "$PH_BADGE" "$1" >/dev/null 2>&1
  rc=$?
  echo "$rc"
}

ph_has_badge() {
  if grep -qF "$PH_START" "$1" 2>/dev/null; then echo yes; else echo no; fi
}

ph_exists() {
  if [[ -e "$1" || -L "$1" ]]; then echo yes; else echo no; fi
}

ph_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

ph_set_mtime() {
  touch -d "@$2" "$1" 2>/dev/null || touch -t "$(date -r "$2" +%Y%m%d%H%M.%S)" "$1"
}

ph_mode() {
  stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1" 2>/dev/null || echo unknown
}

# --- Registration -------------------------------------------------------------
if jq -e '[.hooks.Stop[].hooks[].command | select(contains("post-eval-badge.sh"))] | length == 1' \
    "$PLUGIN_ROOT/hooks/hooks.json" >/dev/null 2>&1; then
  pass "post-eval-badge.sh is registered on Stop"
else
  fail "post-eval-badge.sh is registered on Stop" "hooks.json has no Stop command for it"
fi

# --- Without opt-in: no README change, evaluation marked as handled -----------
PH_D="$(ph_project no-consent)"
assert_eq "no opt-in: hook exits 0" "0" "$(ph_run_hook "$PH_D")"
assert_eq "no opt-in: README.md unchanged" "# Project" "$(cat "$PH_D/README.md")"
assert_eq "no opt-in: .badge-seen records latest.json mtime" \
  "$(ph_mtime "$PH_D/.harness-eval/latest.json")" "$(cat "$PH_D/.harness-eval/.badge-seen" 2>/dev/null)"

# --- Opt-in: each saved evaluation is handled once, with no 5-minute window ---
PH_D="$(ph_project once)"
ph_set_mtime "$PH_D/.harness-eval/latest.json" "$((PH_NOW - 600))"
assert_eq "opt-in: 10-minute-old evaluation handled (exit 0)" "0" \
  "$(ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1)"
assert_eq "opt-in: 10-minute-old evaluation updates README.md" "yes" "$(ph_has_badge "$PH_D/README.md")"
printf '# Project\n' > "$PH_D/README.md"
ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1 >/dev/null
assert_eq "opt-in: same evaluation is not handled twice" "# Project" "$(cat "$PH_D/README.md")"
ph_set_mtime "$PH_D/.harness-eval/latest.json" "$PH_NOW"
ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1 >/dev/null
assert_eq "opt-in: a newer save is handled" "yes" "$(ph_has_badge "$PH_D/README.md")"

PH_D="$(ph_project stale)"
ph_set_mtime "$PH_D/.harness-eval/latest.json" "$((PH_NOW - 2 * 86400))"
ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1 >/dev/null
assert_eq "opt-in: evaluation older than a day ignored" "# Project" "$(cat "$PH_D/README.md")"

# --- Config opt-in counts only when config.json is untracked ------------------
PH_D="$(ph_project config-untracked)"
printf '{"autoBadge": true}\n' > "$PH_D/.harness-eval/config.json"
ph_run_hook "$PH_D" >/dev/null
assert_eq "config opt-in (untracked config.json) updates README.md" "yes" "$(ph_has_badge "$PH_D/README.md")"

PH_D="$(ph_project config-symlink)"
printf '{"autoBadge": true}\n' > "$PH_TMP/outside-config.json"
ln -s "$PH_TMP/outside-config.json" "$PH_D/.harness-eval/config.json"
ph_run_hook "$PH_D" >/dev/null
assert_eq "symlinked config.json is not an opt-in" "# Project" "$(cat "$PH_D/README.md")"

if command -v git >/dev/null 2>&1; then
  PH_D="$(ph_project config-tracked)"
  printf '{"autoBadge": true}\n' > "$PH_D/.harness-eval/config.json"
  git -C "$PH_D" init -q && git -C "$PH_D" add .harness-eval/config.json
  ph_run_hook "$PH_D" >/dev/null
  assert_eq "git-tracked config.json is not an opt-in" "# Project" "$(cat "$PH_D/README.md")"

  PH_D="$(ph_project latest-tracked)"
  git -C "$PH_D" init -q && git -C "$PH_D" add .harness-eval/latest.json
  ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1 >/dev/null
  assert_eq "git-tracked latest.json: README.md unchanged" "# Project" "$(cat "$PH_D/README.md")"
  assert_eq "git-tracked latest.json: no .badge-seen written" "no" "$(ph_exists "$PH_D/.harness-eval/.badge-seen")"
else
  skip "git-tracked config.json / latest.json checks" "git not installed"
fi

# --- Repository-planted links are never followed ------------------------------
PH_D="$(ph_project latest-symlink)"
rm -f "$PH_D/.harness-eval/latest.json"
printf '%s\n' "$PH_LATEST_JSON" > "$PH_TMP/outside-latest.json"
ln -s "$PH_TMP/outside-latest.json" "$PH_D/.harness-eval/latest.json"
ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1 >/dev/null
assert_eq "symlinked latest.json: README.md unchanged" "# Project" "$(cat "$PH_D/README.md")"
assert_eq "symlinked latest.json: no .badge-seen written" "no" "$(ph_exists "$PH_D/.harness-eval/.badge-seen")"

PH_D="$(ph_project seen-symlink)"
printf 'KEEP\n' > "$PH_TMP/outside-seen"
ln -s "$PH_TMP/outside-seen" "$PH_D/.harness-eval/.badge-seen"
ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1 >/dev/null
assert_eq "symlinked .badge-seen: link target unchanged" "KEEP" "$(cat "$PH_TMP/outside-seen")"
assert_eq "symlinked .badge-seen: README.md unchanged" "# Project" "$(cat "$PH_D/README.md")"

PH_D="$(ph_project readme-symlink)"
rm -f "$PH_D/README.md"
printf '# Outside\n' > "$PH_TMP/outside-readme"
ln -s "$PH_TMP/outside-readme" "$PH_D/README.md"
assert_eq "opt-in with symlinked README.md: hook reports failure (exit 1)" "1" \
  "$(ph_run_hook "$PH_D" HARNESS_EVAL_AUTO_BADGE=1)"
assert_eq "opt-in with symlinked README.md: link target unchanged" "# Outside" "$(cat "$PH_TMP/outside-readme")"

# --- badge.sh guards ----------------------------------------------------------
PH_D="$(ph_project badge-symlink)"
rm -f "$PH_D/README.md"
printf '# Outside\n' > "$PH_TMP/outside-readme-2"
ln -s "$PH_TMP/outside-readme-2" "$PH_D/README.md"
assert_eq "badge.sh: symlinked README.md refused (exit 2)" "2" "$(ph_run_badge "$PH_D")"
assert_eq "badge.sh: symlinked README.md target unchanged" "# Outside" "$(cat "$PH_TMP/outside-readme-2")"

PH_D="$(ph_project badge-dangling)"
rm -f "$PH_D/README.md"
ln -s "$PH_TMP/created-by-badge" "$PH_D/README.md"
assert_eq "badge.sh: dangling README.md link refused (exit 2)" "2" "$(ph_run_badge "$PH_D")"
assert_eq "badge.sh: dangling README.md target not created" "no" "$(ph_exists "$PH_TMP/created-by-badge")"

# A committed README.md.tmp link must not receive the rewritten README.
PH_D="$(ph_project badge-tmp-link)"
printf '# Project\n%s\nold\n<!-- harness-eval-badge:end -->\n' "$PH_START" > "$PH_D/README.md"
chmod 644 "$PH_D/README.md"
printf 'KEEP\n' > "$PH_TMP/outside-tmp"
ln -s "$PH_TMP/outside-tmp" "$PH_D/README.md.tmp"
assert_eq "badge.sh: marker rewrite succeeds (exit 0)" "0" "$(ph_run_badge "$PH_D")"
assert_eq "badge.sh: README.md.tmp link target unchanged" "KEEP" "$(cat "$PH_TMP/outside-tmp")"
if grep -qF 'grade-B+-' "$PH_D/README.md"; then
  pass "badge.sh: marker rewrite replaced the block"
else
  fail "badge.sh: marker rewrite replaced the block" "new grade badge not found in README.md"
fi
assert_eq "badge.sh: marker rewrite keeps README.md mode" "644" "$(ph_mode "$PH_D/README.md")"

# Both markers present, but the end marker comes first, so the block never
# closes: the rewrite must stop with the malformed-block message.
PH_D="$(ph_project badge-unclosed)"
printf '# Project\n<!-- harness-eval-badge:end -->\n%s\nkeep\n' "$PH_START" > "$PH_D/README.md"
PH_BEFORE="$(cat "$PH_D/README.md")"
PH_ERR="$(bash "$PH_BADGE" "$PH_D" 2>&1 >/dev/null)"
PH_RC=$?
assert_eq "badge.sh: unclosed badge block refused (exit 2)" "2" "$PH_RC"
assert_eq "badge.sh: unclosed badge block leaves README.md unchanged" "$PH_BEFORE" "$(cat "$PH_D/README.md")"
assert_contains "badge.sh: unclosed badge block reported as malformed" "$PH_ERR" "badge block is malformed"

# An awk that fails while reading README.md (the rewrite; score_to_color reads
# no file) must be reported as an awk failure, not as a malformed README.
PH_AWK="$(command -v awk)"
mkdir -p "$PH_TMP/failing-awk"
{
  printf '#!/bin/bash\n'
  printf 'for a in "$@"; do case "$a" in *README.md) exit 2 ;; esac; done\n'
  printf 'exec %q "$@"\n' "$PH_AWK"
} > "$PH_TMP/failing-awk/awk"
chmod +x "$PH_TMP/failing-awk/awk"
PH_D="$(ph_project badge-awk-fails)"
printf '# Project\n%s\nold\n<!-- harness-eval-badge:end -->\n' "$PH_START" > "$PH_D/README.md"
PH_BEFORE="$(cat "$PH_D/README.md")"
PH_ERR="$(PATH="$PH_TMP/failing-awk:$PATH" bash "$PH_BADGE" "$PH_D" 2>&1 >/dev/null)"
PH_RC=$?
assert_eq "badge.sh: awk failure exits 2 and leaves README.md unchanged" "2|$PH_BEFORE" "$PH_RC|$(cat "$PH_D/README.md")"
if grep -qF 'awk exit 2' <<< "$PH_ERR" && ! grep -qF 'malformed' <<< "$PH_ERR"; then
  pass "badge.sh: awk failure reported as awk failure, not a malformed README"
else
  fail "badge.sh: awk failure reported as awk failure, not a malformed README" "stderr: $PH_ERR"
fi

rm -rf "$PH_TMP"
unset PH_HOOK PH_BADGE PH_TMP PH_LATEST_JSON PH_START PH_NOW PH_D PH_BEFORE PH_ERR PH_RC PH_AWK
