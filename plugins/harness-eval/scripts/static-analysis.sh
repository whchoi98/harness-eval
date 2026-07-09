#!/usr/bin/env bash
# static-analysis.sh — Static analysis for Claude Code harness projects
# Usage: static-analysis.sh <target-project-root>
# Output: JSON to stdout, logs to stderr
# Exit codes: 0 = all pass, 1 = issues found, 2 = script error

set -euo pipefail

###############################################################################
# Dependency checks
###############################################################################
check_dependencies() {
  if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo '{"error":"Bash 4.0+ is required"}' >&2
    exit 2
  fi
  if ! command -v jq &>/dev/null; then
    echo '{"error":"jq is required but not installed"}' >&2
    exit 2
  fi
}

###############################################################################
# Globals
###############################################################################
TARGET=""
HARNESS_EVAL_ROOT="${HARNESS_EVAL_ROOT:-}"
CHECKS_JSON="[]"
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

###############################################################################
# Resolve plugin root from script location if not set
###############################################################################
resolve_root() {
  if [[ -z "$HARNESS_EVAL_ROOT" ]]; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    HARNESS_EVAL_ROOT="$(cd "$script_dir/.." && pwd)"
  fi
}

###############################################################################
# Argument parsing
###############################################################################
parse_args() {
  if [[ $# -eq 0 ]]; then
    emit_error "Usage: static-analysis.sh <target-project-root>"
    exit 2
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*)
        emit_error "Unknown flag: $1"
        exit 2
        ;;
      *)
        TARGET="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$TARGET" ]]; then
    emit_error "Usage: static-analysis.sh <target-project-root>"
    exit 2
  fi

  # Resolve to absolute path
  local original_target="$TARGET"
  TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || {
    emit_error "Target directory does not exist: $original_target"
    exit 2
  }

  if [[ ! -d "$TARGET" ]]; then
    emit_error "Target is not a directory: $TARGET"
    exit 2
  fi
}

###############################################################################
# Logging helpers (all go to stderr)
###############################################################################
log() { echo "[static-analysis] $*" >&2; }
# Build the error JSON with jq so messages containing quotes/backslashes
# (e.g. target paths) stay valid JSON for machine consumers on stderr.
emit_error() { jq -n --arg msg "$*" '{error:$msg}' >&2; }

###############################################################################
# Helper: add_check — append a check result to CHECKS_JSON
#   Params: id, category, status, details, [file], [suggestion]
###############################################################################
add_check() {
  local id="$1"
  local category="$2"
  local status="$3"
  local details="$4"
  local file="${5:-}"
  local suggestion="${6:-}"

  # Update counters
  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac

  # Build JSON object using jq for proper escaping
  local check_json
  check_json="$(jq -n \
    --arg id "$id" \
    --arg category "$category" \
    --arg status "$status" \
    --arg details "$details" \
    --arg file "$file" \
    --arg suggestion "$suggestion" \
    '{id: $id, category: $category, status: $status, details: $details}
     + (if $file != "" then {file: $file} else {} end)
     + (if $suggestion != "" then {suggestion: $suggestion} else {} end)'
  )"

  CHECKS_JSON="$(echo "$CHECKS_JSON" | jq -c --argjson check "$check_json" '. + [$check]')"

  log "  [$status] $id: $details"
}

###############################################################################
# Check 1: bash-syntax — bash -n on all .sh files in hooks/ and scripts/
###############################################################################
check_bash_syntax() {
  log "Running bash-syntax checks..."
  local found_any=false
  local all_pass=true

  local dirs=(".claude/hooks" "scripts")
  for dir in "${dirs[@]}"; do
    local abs_dir="$TARGET/$dir"
    if [[ ! -d "$abs_dir" ]]; then
      continue
    fi

    while IFS= read -r -d '' sh_file; do
      found_any=true
      local rel_path="${sh_file#"$TARGET"/}"
      local syntax_output
      if syntax_output="$(bash -n "$sh_file" 2>&1)"; then
        add_check "bash-syntax" "correctness" "PASS" "Syntax OK: $rel_path" "$rel_path"
      else
        all_pass=false
        # Sanitize error output for JSON
        local err_msg
        err_msg="$(echo "$syntax_output" | head -5 | tr '\n' '; ')"
        add_check "bash-syntax" "correctness" "FAIL" "Syntax error in $rel_path: $err_msg" "$rel_path"
      fi
    done < <(find "$abs_dir" -name '*.sh' -type f -print0 2>/dev/null)
  done

  if [[ "$found_any" == false ]]; then
    add_check "bash-syntax" "correctness" "PASS" "No .sh files found in .claude/hooks/ or scripts/"
  fi
}

###############################################################################
# Check 2: json-valid — validate settings JSON files with jq
###############################################################################
check_json_valid() {
  log "Running json-valid checks..."
  local files=(".claude/settings.json" ".claude/settings.local.json")

  for file in "${files[@]}"; do
    local abs_path="$TARGET/$file"
    if [[ ! -f "$abs_path" ]]; then
      add_check "json-valid" "correctness" "PASS" "File does not exist (OK): $file" "$file"
      continue
    fi

    local jq_output
    if jq_output="$(jq empty "$abs_path" 2>&1)"; then
      add_check "json-valid" "correctness" "PASS" "Valid JSON: $file" "$file"
    else
      local err_msg
      err_msg="$(echo "$jq_output" | head -3 | tr '\n' '; ')"
      add_check "json-valid" "correctness" "FAIL" "Invalid JSON in $file: $err_msg" "$file"
    fi
  done
}

###############################################################################
# Check 3: hook-file-mapping — verify referenced hook files exist
###############################################################################
check_hook_file_mapping() {
  log "Running hook-file-mapping checks..."
  local settings_file="$TARGET/.claude/settings.json"

  if [[ ! -f "$settings_file" ]]; then
    add_check "hook-file-mapping" "correctness" "PASS" "No settings.json found; no hooks to verify"
    return
  fi

  local hooks_exist
  hooks_exist="$(jq -r 'if .hooks then "yes" else "no" end' "$settings_file" 2>/dev/null)" || hooks_exist="no"

  if [[ "$hooks_exist" == "no" ]]; then
    add_check "hook-file-mapping" "correctness" "PASS" "No hooks configured in settings.json"
    return
  fi

  # Extract all command values from hooks. Support BOTH schemas:
  #   - real Claude Code (nested): .hooks.<Event>[] = {matcher, hooks:[{type,command}]}
  #   - legacy/flat fixture:       .hooks.<Event>[] = {matcher, command}
  # The `.command // (.hooks[]?.command)` fallback reads whichever is present,
  # so real projects are no longer flagged with "Hook file missing: null".
  local commands
  commands="$(jq -r '.hooks | to_entries[] | .value[] | (.command // (.hooks[]?.command)) // empty' "$settings_file" 2>/dev/null)" || commands=""

  if [[ -z "$commands" ]]; then
    add_check "hook-file-mapping" "correctness" "PASS" "No hook commands found"
    return
  fi

  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue

    # A command may be a bare script path ("...x.sh --arg") or an interpreter
    # invocation ("bash .claude/hooks/x.sh"). Tokenize (read -ra does not
    # glob-expand, so this is injection-safe) and, if the first token is a
    # known interpreter, skip it plus any leading flags / env VAR=value
    # assignments and take the first remaining token as the script path.
    local -a tokens
    read -ra tokens <<< "$cmd"
    [[ ${#tokens[@]} -eq 0 ]] && continue

    local script_path=""
    case "${tokens[0]}" in
      bash|sh|zsh|env|python|python3)
        local i
        for (( i=1; i<${#tokens[@]}; i++ )); do
          case "${tokens[$i]}" in
            -*)  continue ;;   # skip interpreter flags (e.g. -e, -u)
            *=*) continue ;;   # skip env-style VAR=value assignments
            *)   script_path="${tokens[$i]}"; break ;;
          esac
        done
        ;;
      *)
        script_path="${tokens[0]}"
        ;;
    esac

    [[ -z "$script_path" ]] && continue

    if [[ -f "$TARGET/$script_path" ]]; then
      add_check "hook-file-mapping" "correctness" "PASS" "Hook file exists: $script_path" "$script_path"
    else
      add_check "hook-file-mapping" "correctness" "FAIL" "Hook file missing: $script_path" "$script_path"
    fi
  done <<< "$commands"
}

###############################################################################
# Check 4: hook-permissions — .sh files in hooks/ should be executable
###############################################################################
check_hook_permissions() {
  log "Running hook-permissions checks..."
  local hooks_dir="$TARGET/.claude/hooks"

  if [[ ! -d "$hooks_dir" ]]; then
    add_check "hook-permissions" "correctness" "PASS" "No .claude/hooks/ directory"
    return
  fi

  local found_any=false

  while IFS= read -r -d '' sh_file; do
    found_any=true
    local rel_path="${sh_file#"$TARGET"/}"
    if [[ -x "$sh_file" ]]; then
      add_check "hook-permissions" "correctness" "PASS" "Executable: $rel_path" "$rel_path"
    else
      add_check "hook-permissions" "correctness" "WARN" "Not executable: $rel_path" "$rel_path" "Run: chmod +x $rel_path"
    fi
  done < <(find "$hooks_dir" -name '*.sh' -type f -print0 2>/dev/null)

  if [[ "$found_any" == false ]]; then
    add_check "hook-permissions" "correctness" "PASS" "No .sh files in .claude/hooks/"
  fi
}

###############################################################################
# Check 5: tool-scope — detect overly permissive tool patterns
###############################################################################
check_tool_scope() {
  log "Running tool-scope checks..."
  local settings_file="$TARGET/.claude/settings.json"

  if [[ ! -f "$settings_file" ]]; then
    # Also check settings.local.json
    settings_file="$TARGET/.claude/settings.local.json"
    if [[ ! -f "$settings_file" ]]; then
      add_check "tool-scope" "safety" "PASS" "No settings files found; no permissions to check"
      return
    fi
  fi

  local allow_list
  allow_list="$(jq -r '.permissions.allow // [] | .[]' "$settings_file" 2>/dev/null)" || allow_list=""

  if [[ -z "$allow_list" ]]; then
    add_check "tool-scope" "safety" "PASS" "No allow-list entries to check"
    return
  fi

  local found_issues=false

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue

    # Check for Bash(*:*) or bare "Bash" — very permissive
    if [[ "$entry" == "Bash" || "$entry" == 'Bash(*:*)' || "$entry" == 'Bash(*)' ]]; then
      found_issues=true
      add_check "tool-scope" "safety" "WARN" "Very permissive tool pattern: $entry" ".claude/settings.json" "Scope Bash permissions to specific commands"
      continue
    fi

    # Check for Bash(python3:*) without -c
    if [[ "$entry" =~ ^Bash\(python3:\*\)$ ]]; then
      found_issues=true
      add_check "tool-scope" "safety" "WARN" "Broad python3 scope: $entry" ".claude/settings.json" "Use Bash(python3 -c:*) instead"
      continue
    fi

    # Check for Bash(cat:*)
    if [[ "$entry" =~ ^Bash\(cat:\*\)$ ]]; then
      found_issues=true
      add_check "tool-scope" "safety" "WARN" "cat via Bash: $entry" ".claude/settings.json" "Consider using the Read tool instead"
      continue
    fi

    # Check for Bash(rm:*)
    if [[ "$entry" =~ ^Bash\(rm:\*\)$ || "$entry" =~ ^Bash\(rm\ -rf:\*\)$ ]]; then
      found_issues=true
      add_check "tool-scope" "safety" "WARN" "Dangerous rm pattern: $entry" ".claude/settings.json" "Restrict rm usage or add to deny list"
      continue
    fi
  done <<< "$allow_list"

  if [[ "$found_issues" == false ]]; then
    add_check "tool-scope" "safety" "PASS" "No overly permissive tool patterns found"
  fi
}

###############################################################################
# Check 6: deny-list — check for permissions.deny array
###############################################################################
check_deny_list() {
  log "Running deny-list checks..."
  local settings_file="$TARGET/.claude/settings.json"

  if [[ ! -f "$settings_file" ]]; then
    settings_file="$TARGET/.claude/settings.local.json"
    if [[ ! -f "$settings_file" ]]; then
      add_check "deny-list" "safety" "WARN" "No settings file found; no deny list configured" "" "Add a permissions.deny array with dangerous commands"
      return
    fi
  fi

  local has_deny
  has_deny="$(jq -r 'if .permissions.deny and (.permissions.deny | length) > 0 then "yes" else "no" end' "$settings_file" 2>/dev/null)" || has_deny="no"

  if [[ "$has_deny" == "yes" ]]; then
    local deny_count
    deny_count="$(jq -r '.permissions.deny | length' "$settings_file" 2>/dev/null)"
    add_check "deny-list" "safety" "PASS" "Deny list present with $deny_count entries"
  else
    add_check "deny-list" "safety" "WARN" "No deny list configured" "" "Add permissions.deny with dangerous commands (e.g., rm -rf, git push --force)"
  fi
}

###############################################################################
# Check 7: hook-event-coverage — check registered hook events
###############################################################################
check_hook_event_coverage() {
  log "Running hook-event-coverage checks..."
  local settings_file="$TARGET/.claude/settings.json"

  if [[ ! -f "$settings_file" ]]; then
    add_check "hook-event-coverage" "completeness" "FAIL" "No settings.json; no hooks registered"
    return
  fi

  local hooks_exist
  hooks_exist="$(jq -r 'if .hooks then "yes" else "no" end' "$settings_file" 2>/dev/null)" || hooks_exist="no"

  if [[ "$hooks_exist" == "no" ]]; then
    add_check "hook-event-coverage" "completeness" "FAIL" "No hooks object in settings.json"
    return
  fi

  # Get hook event keys
  local events
  events="$(jq -r '.hooks | keys[]' "$settings_file" 2>/dev/null)" || events=""

  local event_count=0
  local event_list=""
  local known_events=("PreToolUse" "PostToolUse" "Stop" "Notification")

  while IFS= read -r event; do
    [[ -z "$event" ]] && continue
    event_count=$((event_count + 1))
    if [[ -n "$event_list" ]]; then
      event_list="$event_list, $event"
    else
      event_list="$event"
    fi
  done <<< "$events"

  # Determine missing events
  local missing=""
  for known in "${known_events[@]}"; do
    local found=false
    while IFS= read -r event; do
      if [[ "$event" == "$known" ]]; then
        found=true
        break
      fi
    done <<< "$events"
    if [[ "$found" == false ]]; then
      if [[ -n "$missing" ]]; then
        missing="$missing, $known"
      else
        missing="$known"
      fi
    fi
  done

  if [[ "$event_count" -ge 2 ]]; then
    add_check "hook-event-coverage" "completeness" "PASS" "Hook events registered: $event_list ($event_count events)" "" ""
  elif [[ "$event_count" -eq 1 ]]; then
    add_check "hook-event-coverage" "completeness" "WARN" "Only 1 hook event registered: $event_list" "" "Consider adding hooks for: $missing"
  else
    add_check "hook-event-coverage" "completeness" "FAIL" "No hook events registered" "" "Add hooks for events like PreToolUse, PostToolUse"
  fi
}

###############################################################################
# Check 8: root-claude-md — check for CLAUDE.md at project root
###############################################################################
check_root_claude_md() {
  log "Running root-claude-md check..."
  if [[ -f "$TARGET/CLAUDE.md" ]]; then
    add_check "root-claude-md" "completeness" "PASS" "CLAUDE.md exists at project root" "CLAUDE.md"
  else
    add_check "root-claude-md" "completeness" "FAIL" "CLAUDE.md missing at project root" "" "Create a CLAUDE.md with project context and conventions"
  fi
}

###############################################################################
# Check 9: frontmatter-consistency — check .md files for description field
###############################################################################
check_frontmatter_consistency() {
  log "Running frontmatter-consistency checks..."
  local dirs=(".claude/skills" ".claude/agents")
  local found_any=false

  for dir in "${dirs[@]}"; do
    local abs_dir="$TARGET/$dir"
    if [[ ! -d "$abs_dir" ]]; then
      continue
    fi

    while IFS= read -r -d '' md_file; do
      found_any=true
      local rel_path="${md_file#"$TARGET"/}"

      # Check for YAML frontmatter with description field
      # Frontmatter starts with --- on line 1 and ends with --- on a subsequent line
      local has_frontmatter=false
      local has_description=false

      if head -1 "$md_file" | grep -q '^---$'; then
        has_frontmatter=true
        # Extract frontmatter (between first --- and second ---)
        local frontmatter
        frontmatter="$(sed -n '2,/^---$/p' "$md_file" | sed '$d')"
        if echo "$frontmatter" | grep -qE '^description:'; then
          has_description=true
        fi
      fi

      if [[ "$has_description" == true ]]; then
        add_check "frontmatter-consistency" "consistency" "PASS" "Has description in frontmatter: $rel_path" "$rel_path"
      elif [[ "$has_frontmatter" == true ]]; then
        add_check "frontmatter-consistency" "consistency" "WARN" "Frontmatter missing description field: $rel_path" "$rel_path" "Add 'description: ...' to YAML frontmatter"
      else
        add_check "frontmatter-consistency" "consistency" "WARN" "No YAML frontmatter found: $rel_path" "$rel_path" "Add YAML frontmatter with a description field"
      fi
    done < <(find "$abs_dir" -name '*.md' -type f -print0 2>/dev/null)
  done

  if [[ "$found_any" == false ]]; then
    add_check "frontmatter-consistency" "consistency" "PASS" "No .md files found in .claude/skills/ or .claude/agents/"
  fi
}

###############################################################################
# Main analysis
###############################################################################
analyze() {
  # Correctness checks
  check_bash_syntax
  check_json_valid
  check_hook_file_mapping
  check_hook_permissions

  # Safety checks
  check_tool_scope
  check_deny_list

  # Completeness checks
  check_hook_event_coverage
  check_root_claude_md

  # Consistency checks
  check_frontmatter_consistency

  # Build final output
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local total=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))

  # Derive the 4 Basic-Quality category scores from the per-check category tags.
  # Formula: score = 10 * (pass + 0.5*warn) / (pass + warn + fail), rounded to
  # 1 decimal; a category with 0 checks scores null (never invented). This is
  # an ADDITIVE top-level `categories` key — existing keys are unchanged.
  local categories_json
  categories_json="$(echo "$CHECKS_JSON" | jq -c '
    def cat_stats(name):
      ([ .[] | select(.category == name) ]) as $items
      | ($items | map(select(.status == "PASS")) | length) as $p
      | ($items | map(select(.status == "WARN")) | length) as $w
      | ($items | map(select(.status == "FAIL")) | length) as $f
      | ($p + $w + $f) as $tot
      | {
          pass: $p,
          warn: $w,
          fail: $f,
          score: (if $tot == 0 then null
                  else ( ( ( ($p + (0.5 * $w)) / $tot ) * 100 ) | round ) / 10
                  end)
        };
    {
      correctness:  cat_stats("correctness"),
      safety:       cat_stats("safety"),
      completeness: cat_stats("completeness"),
      consistency:  cat_stats("consistency")
    }
  ')"

  jq -n \
    --arg timestamp "$timestamp" \
    --arg project "$TARGET" \
    --argjson checks "$CHECKS_JSON" \
    --argjson pass "$PASS_COUNT" \
    --argjson warn "$WARN_COUNT" \
    --argjson fail "$FAIL_COUNT" \
    --argjson total "$total" \
    --argjson categories "$categories_json" \
    '{
      timestamp: $timestamp,
      project: $project,
      checks: $checks,
      summary: {
        pass: $pass,
        warn: $warn,
        fail: $fail,
        total: $total
      },
      categories: $categories
    }'

  # Exit code: 1 if any issues, 0 if all pass
  if [[ "$FAIL_COUNT" -gt 0 || "$WARN_COUNT" -gt 0 ]]; then
    return 1
  fi
  return 0
}

###############################################################################
# Entry point
###############################################################################
main() {
  check_dependencies
  resolve_root
  parse_args "$@"

  log "Analyzing: $TARGET"
  log "Plugin root: $HARNESS_EVAL_ROOT"

  analyze
}

main "$@"
