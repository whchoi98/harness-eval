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
# Helper: extract_frontmatter — print a .md file's YAML frontmatter: the lines
#   between a '---' on line 1 and the next '---' line, with CRLF line endings
#   read as LF. Returns 1 when the file has no frontmatter, including an
#   unclosed block. Shared by frontmatter-consistency and model-config so both
#   read the same block and neither scans the markdown body. One awk process and
#   no pipe, so a large file cannot end in SIGPIPE under pipefail.
###############################################################################
extract_frontmatter() {
  local md_file="$1"
  awk '{ sub(/\r$/, "") }
       NR == 1 { if ($0 !~ /^---[[:space:]]*$/) exit 1; next }
       /^---[[:space:]]*$/ { printf "%s", fm; closed = 1; exit }
       { fm = fm $0 "\n" }
       END { if (!closed) exit 1 }' "$md_file"
}

###############################################################################
# Check 1: bash-syntax — bash -n on all .sh files in hooks/ and scripts/
###############################################################################
check_bash_syntax() {
  log "Running bash-syntax checks..."
  local found_any=false

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
        # Sanitize error output for JSON
        local err_msg
        err_msg="$(head -5 <<< "$syntax_output" | tr '\n' '; ')"
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
      err_msg="$(head -3 <<< "$jq_output" | tr '\n' '; ')"
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
      local frontmatter

      if frontmatter="$(extract_frontmatter "$md_file")"; then
        has_frontmatter=true
        if grep -qE '^description:' <<< "$frontmatter"; then
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
# Model tables for model-config.
# Update from the claude-api skill's shared/models.md (Current, Legacy,
# Deprecated and Retired tables) at each model release. Patterns are EREs
# matched against the lowercased value, so Bedrock
# ("[region.]anthropic.claude-...-v1:0"), Vertex ("claude-...@YYYYMMDD") and
# Foundry ("claude-opus-4") spellings match as well.
# tests/structure/test-plugin-structure.sh reads MODEL_ALIASES,
# FRONTMATTER_EFFORT_LEVELS and KNOWN_MODEL_ID_PATTERN from this file by name,
# so keep each on one line in its current form.
###############################################################################
# Claude Code model aliases (compared after a trailing "[1m]" is removed).
MODEL_ALIASES=(inherit default opus sonnet haiku fable best opusplan)
# Retired: no longer served, so requests fail or Claude Code silently remaps
# the ID; either way the pin no longer selects the model it names.
RETIRED_MODEL_PATTERNS=(
  '(^|[^a-z])claude-(instant|1|2|3)([.-]|$)'        # every Claude 1.x/2.x/3.x model
  '(^|[^a-z])claude-v[12]([:.-]|$)'                 # Bedrock Claude 1/2 (anthropic.claude-v2:1)
  '(^|[^a-z0-9])claude-opus-4-1([^0-9]|$)'          # Claude Opus 4.1, retired 2026-08-05
)
# Deprecated: still served, retirement announced.
DEPRECATED_MODEL_PATTERNS=(
  '(^|[^a-z0-9])claude-(opus|sonnet)-4-0([^0-9]|$)' # Claude Opus 4 / Sonnet 4 aliases
  '(^|[^a-z0-9])claude-(opus|sonnet)-4[-@]20250514' # and their dated IDs
  '(^|[^a-z0-9])claude-(opus|sonnet)-4$'            # and their Foundry IDs
)
# Undated IDs served today: the Current and Legacy tables, less the IDs matched
# as retired or deprecated above. An ID is compared after its provider prefix,
# Bedrock "-vN:M" suffix and date are removed. Each served ID is listed, not a
# version shape, so a typo such as "claude-opus-55" or "claude-sonnet-4.5" and
# an ID that was never released such as "claude-sonnet-4-7" are reported
# instead of passing as current IDs. Add each model here when it launches.
KNOWN_MODEL_ID_PATTERN='^claude-(opus-(5-5|5|4-[5-8])|sonnet-(5|4-[56])|haiku-4-5|fable-5(-1)?|mythos-5(-1)?)$'
# Frontmatter `effort:` takes a named level or an integer (Claude Code also
# accepts "med"). settings.json `effortLevel` takes only the four levels below
# and silently drops anything else, including "max". The env var
# CLAUDE_CODE_EFFORT_LEVEL takes the frontmatter values plus "auto" and "unset"
# (both select the model default) and ignores anything else.
FRONTMATTER_EFFORT_LEVELS=(low med medium high xhigh max)
SETTINGS_EFFORT_LEVELS=(low medium high xhigh)
ENV_EFFORT_LEVELS=(low med medium high xhigh max auto unset)

# model-config accumulators. Issues are collected per file and emitted as one
# check per file (worst status wins); valid values are only counted, so a
# project with many agents does not inflate the correctness ratio.
MC_OK=0
MC_ANY_ISSUE=false
MC_VALUE=""
MC_BASE=""
MC_PROVIDER_ID=false
MC_DATED=false
MC_WORST=""
MC_ISSUES=()
MC_SUGGESTIONS=()

# mc_normalize <raw> — sets MC_VALUE to the comparable form of a frontmatter or
# settings value: CR, trailing " # comment", surrounding whitespace and quotes
# removed, lowercased, trailing "[1m]" removed.
mc_normalize() {
  local v="${1//$'\r'/}"
  local dq_re='^"(.*)"$'
  local sq_re="^'(.*)'\$"
  v="${v%%[[:space:]]#*}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  if [[ "$v" =~ $dq_re || "$v" =~ $sq_re ]]; then
    v="${BASH_REMATCH[1]}"
  fi
  v="${v,,}"
  MC_VALUE="${v%\[1m\]}"
}

# mc_reduce_id <normalized value> — sets MC_BASE to the undated ID. Bedrock
# ("[region.]anthropic.claude-...[-YYYYMMDD][-vN[:M]]") and Vertex
# ("claude-...@YYYYMMDD") spellings lose their provider parts, and any
# "-YYYYMMDD" date is removed. MC_PROVIDER_ID is true for a Bedrock or Vertex
# spelling, MC_DATED for a value that carried a "-YYYYMMDD" date.
mc_reduce_id() {
  local base="$1"
  local bedrock_re='^([a-z-]+\.)?anthropic\.(claude-.*)$'
  local bedrock_ver_re='^(.*)-v[0-9]+(:[0-9]+)?$'
  local vertex_re='^(.*)@20[0-9]{6}$'
  local dated_re='^(.*)-20[0-9]{6}$'
  MC_PROVIDER_ID=false
  MC_DATED=false
  if [[ "$base" =~ $bedrock_re ]]; then
    base="${BASH_REMATCH[2]}"
    MC_PROVIDER_ID=true
    if [[ "$base" =~ $bedrock_ver_re ]]; then
      base="${BASH_REMATCH[1]}"
    fi
  elif [[ "$base" =~ $vertex_re ]]; then
    base="${BASH_REMATCH[1]}"
    MC_PROVIDER_ID=true
  fi
  if [[ "$base" =~ $dated_re ]]; then
    base="${BASH_REMATCH[1]}"
    MC_DATED=true
  fi
  MC_BASE="$base"
}

# mc_issue <WARN|FAIL> <issue> <suggestion> — record one problem for the current file.
mc_issue() {
  local status="$1" issue="$2" suggestion="$3"
  MC_ANY_ISSUE=true
  if [[ "$status" == "FAIL" || -z "$MC_WORST" ]]; then
    MC_WORST="$status"
  fi
  MC_ISSUES+=("$issue")
  local s
  for s in ${MC_SUGGESTIONS[@]+"${MC_SUGGESTIONS[@]}"}; do
    [[ "$s" == "$suggestion" ]] && return 0
  done
  MC_SUGGESTIONS+=("$suggestion")
}

# mc_flush <rel_path> — emit the current file's issues as one model-config check.
mc_flush() {
  local rel_path="$1"
  if [[ ${#MC_ISSUES[@]} -gt 0 ]]; then
    local details suggestion
    details="$(printf '%s; ' "${MC_ISSUES[@]}")"
    suggestion="$(printf '%s ' "${MC_SUGGESTIONS[@]}")"
    add_check "model-config" "correctness" "$MC_WORST" "$rel_path: ${details%; }" "$rel_path" "${suggestion% }"
  fi
  MC_WORST=""
  MC_ISSUES=()
  MC_SUGGESTIONS=()
}

# mc_check_model <label> <raw> — classify one model value (frontmatter `model:`,
# settings `.model`, or a model env var whose value contains "claude-").
mc_check_model() {
  local label="$1" pattern alias
  mc_normalize "$2"
  local value="$MC_VALUE"
  [[ -z "$value" ]] && return 0

  for alias in "${MODEL_ALIASES[@]}"; do
    if [[ "$value" == "$alias" ]]; then
      MC_OK=$((MC_OK + 1))
      return 0
    fi
  done
  for pattern in "${RETIRED_MODEL_PATTERNS[@]}"; do
    if [[ "$value" =~ $pattern ]]; then
      mc_issue "FAIL" "$label '$value' is a retired model" \
        "Replace retired IDs with an alias (opus, sonnet, haiku) or inherit; retired models fail or are silently remapped by Claude Code."
      return 0
    fi
  done
  for pattern in "${DEPRECATED_MODEL_PATTERNS[@]}"; do
    if [[ "$value" =~ $pattern ]]; then
      mc_issue "WARN" "$label '$value' is deprecated (retirement announced)" \
        "Move deprecated IDs to an alias or a current model ID before they retire."
      return 0
    fi
  done
  # Provider ARNs (Bedrock inference profiles) name no model ID to check.
  if [[ "$value" == arn:* ]]; then
    MC_OK=$((MC_OK + 1))
    return 0
  fi
  if [[ "$value" != *claude-* ]]; then
    mc_issue "WARN" "$label '$value' is not a Claude Code model alias or a claude-* model ID" \
      "Use an alias (inherit, opus, sonnet, haiku, fable) or a full claude-* model ID; ignore this if a gateway maps the name."
    return 0
  fi

  # Bedrock and Vertex IDs of Claude 4.5-generation models exist only in dated
  # form, and Claude Code's provider setup pins them, so a date is a finding
  # only on an Anthropic API-style ID.
  mc_reduce_id "$value"
  if [[ ! "$MC_BASE" =~ $KNOWN_MODEL_ID_PATTERN ]]; then
    mc_issue "WARN" "$label '$value' is an unrecognized Claude model ID" \
      "Check the ID against the Anthropic models overview (current IDs look like claude-opus-5-5 or claude-sonnet-5), or use an alias; ignore this if a gateway maps the name."
    return 0
  fi
  if [[ "$MC_DATED" == true && "$MC_PROVIDER_ID" == false ]]; then
    mc_issue "WARN" "$label '$value' pins a dated snapshot" \
      "Prefer an alias or the undated ID; keep a dated snapshot only where exact reproducibility is required, and review it at each model release."
    return 0
  fi
  MC_OK=$((MC_OK + 1))
}

# mc_check_effort <label> <raw> <frontmatter|settings|env> — classify one effort
# value. "env" is CLAUDE_CODE_EFFORT_LEVEL in settings `env`: every value that
# Claude Code accepts there is a WARN too, because it replaces the effort of the
# session and of every agent, skill and command, including effort pinned in
# frontmatter, so no component keeps the depth it was tuned at.
mc_check_effort() {
  local label="$1" kind="$3" level
  mc_normalize "$2"
  local value="$MC_VALUE"
  [[ -z "$value" ]] && return 0

  if [[ "$kind" == "env" ]]; then
    local accepted=false
    [[ "$value" =~ ^[0-9]+$ ]] && accepted=true
    for level in "${ENV_EFFORT_LEVELS[@]}"; do
      [[ "$value" == "$level" ]] && accepted=true
    done
    if [[ "$accepted" == true ]]; then
      mc_issue "WARN" "$label '$value' overrides the effort of every agent, skill and command, including effort pinned in frontmatter" \
        "Set CLAUDE_CODE_EFFORT_LEVEL only where the session and every subagent should run at one effort (auto and unset select the model default everywhere); for a project default that frontmatter effort still overrides, use effortLevel."
    else
      mc_issue "WARN" "$label '$value' is not a valid effort level; Claude Code ignores it" \
        "Set CLAUDE_CODE_EFFORT_LEVEL to low, medium, high, xhigh, max, an integer, auto or unset, or remove it."
    fi
  elif [[ "$kind" == "frontmatter" ]]; then
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      MC_OK=$((MC_OK + 1))
      return 0
    fi
    for level in "${FRONTMATTER_EFFORT_LEVELS[@]}"; do
      if [[ "$value" == "$level" ]]; then
        MC_OK=$((MC_OK + 1))
        return 0
      fi
    done
    mc_issue "WARN" "$label '$value' is not a valid effort level" \
      "Use low, medium, high, xhigh, max or an integer for effort."
  else
    for level in "${SETTINGS_EFFORT_LEVELS[@]}"; do
      if [[ "$value" == "$level" ]]; then
        MC_OK=$((MC_OK + 1))
        return 0
      fi
    done
    mc_issue "WARN" "$label '$value' is not accepted in settings, which take low, medium, high or xhigh; Claude Code ignores it" \
      "Use low, medium, high or xhigh for effortLevel; set max per session (/effort max) or in agent/skill frontmatter."
  fi
}

###############################################################################
# Helper: plugin_component_dirs <sub>... — print "<plugin root>/<sub>" (NUL-
#   terminated, relative to the target) for each plugin root: a directory that
#   holds .claude-plugin/plugin.json, either the target itself or plugins/*/ in
#   a marketplace repo. Claude Code loads a plugin's agents/, skills/ and
#   commands/ the same way as their .claude/ counterparts.
###############################################################################
plugin_component_dirs() {
  local manifest root sub
  for manifest in "$TARGET/.claude-plugin/plugin.json" "$TARGET"/plugins/*/.claude-plugin/plugin.json; do
    [[ -f "$manifest" ]] || continue
    root="${manifest%/.claude-plugin/plugin.json}"
    root="${root#"$TARGET"}"
    root="${root#/}"
    for sub in "$@"; do
      printf '%s\0' "${root:+$root/}$sub"
    done
  done
}

###############################################################################
# Check 10: model-config — model pins and effort settings
#   Reads only YAML frontmatter `model:`/`effort:` (never the body) of
#   .claude/{agents,commands}/**/*.md and .claude/skills/<name>/SKILL.md, the
#   same files under each plugin root (agents/, commands/, skills/<name>/SKILL.md),
#   and these settings keys: .model, .effortLevel, model env vars (*_MODEL,
#   *_MODEL_FORCE, *_MODEL_OPTION) whose value contains "claude-",
#   .alwaysThinkingEnabled == false, .env.MAX_THINKING_TOKENS,
#   .env.CLAUDE_CODE_EFFORT_LEVEL, .env.CLAUDE_CODE_DISABLE_THINKING and
#   .env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING.
###############################################################################
check_model_config() {
  log "Running model-config checks..."
  MC_OK=0
  MC_ANY_ISSUE=false

  local dirs=(".claude/agents" ".claude/skills" ".claude/commands")
  local dir
  while IFS= read -r -d '' dir; do
    dirs+=("$dir")
  done < <(plugin_component_dirs agents skills commands)

  for dir in "${dirs[@]}"; do
    local abs_dir="$TARGET/$dir"
    if [[ ! -d "$abs_dir" ]]; then
      continue
    fi
    # Claude Code loads a skill only from <skills dir>/<name>/SKILL.md; other
    # .md files under a skill are supporting files, not configuration.
    local find_args=(-name '*.md')
    if [[ "$dir" == skills || "$dir" == */skills ]]; then
      find_args=(-mindepth 2 -maxdepth 2 -name 'SKILL.md')
    fi

    while IFS= read -r -d '' md_file; do
      local rel_path="${md_file#"$TARGET"/}"
      local frontmatter line
      frontmatter="$(extract_frontmatter "$md_file")" || continue
      while IFS= read -r line; do
        case "$line" in
          model:*)  mc_check_model "model" "${line#model:}" ;;
          effort:*) mc_check_effort "effort" "${line#effort:}" "frontmatter" ;;
        esac
      done <<< "$frontmatter"
      mc_flush "$rel_path"
    done < <(find "$abs_dir" "${find_args[@]}" -type f -print0 2>/dev/null | sort -z)
  done

  # Thinking caps are ignored only by always-thinking models (Opus 5.5, Fable,
  # Mythos). When settings pin a model that accepts disabled thinking, the cap
  # is a working control and is not reported. settings.local.json overrides
  # settings.json, so it is read first. The model is compared as its undated
  # ID, so the Bedrock and Vertex spellings of Opus 5 are exempt like
  # claude-opus-5, while claude-opus-5-5 is not.
  local project_model="" pm_file
  for pm_file in ".claude/settings.local.json" ".claude/settings.json"; do
    [[ -f "$TARGET/$pm_file" ]] || continue
    project_model="$(jq -r 'if type == "object" then
        ((.model | strings) // (.env | objects | .ANTHROPIC_MODEL | strings) // empty)
      else empty end' "$TARGET/$pm_file" 2>/dev/null)" || project_model=""
    if [[ -n "$project_model" ]]; then
      break
    fi
  done
  mc_normalize "$project_model"
  mc_reduce_id "$MC_VALUE"
  local thinking_caps_apply=true
  case "$MC_BASE" in
    haiku|sonnet|claude-3*|claude-haiku-*|claude-sonnet-*|claude-opus-4*|claude-opus-5)
      thinking_caps_apply=false ;;
  esac

  local thinking_note="not a cost control on always-thinking models"
  local thinking_fix="On always-thinking models (Claude Opus 5.5, Fable) effort is the only thinking control: use effortLevel (settings) or effort (frontmatter) instead. If this project runs a model that accepts disabled thinking (Haiku 4.5, Sonnet), pin it in settings \`model\` and this is not reported."
  local settings_files=(".claude/settings.json" ".claude/settings.local.json")
  local file
  for file in "${settings_files[@]}"; do
    local abs_path="$TARGET/$file"
    [[ -f "$abs_path" ]] || continue

    # One "key<TAB>value" line per setting of interest. Invalid JSON yields
    # nothing here; json-valid already reports it.
    local entries key value
    entries="$(jq -r '
      if type != "object" then empty else
        (if (.model | type) == "string" then ["model", .model] else empty end),
        (if (.effortLevel != null) then ["effortLevel", (.effortLevel | tostring)] else empty end),
        (if .alwaysThinkingEnabled == false then ["alwaysThinkingEnabled", "false"] else empty end),
        (.env | if type == "object" then to_entries[] else empty end
          | if .key == "MAX_THINKING_TOKENS" then ["MAX_THINKING_TOKENS", (.value | tostring)]
            elif (.key == "CLAUDE_CODE_EFFORT_LEVEL" or .key == "CLAUDE_CODE_DISABLE_THINKING"
                  or .key == "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING") and .value != null
              then ["env." + .key, (.value | tostring)]
            elif (.key | test("_MODEL(_FORCE|_OPTION)?$")) and (.value | type) == "string"
                 and (.value | ascii_downcase | contains("claude-"))
              then ["env." + .key, .value]
            else empty end)
      end | @tsv' "$abs_path" 2>/dev/null)" || entries=""

    while IFS=$'\t' read -r key value; do
      case "$key" in
        "") ;;
        model)       mc_check_model "model" "$value" ;;
        effortLevel) mc_check_effort "effortLevel" "$value" "settings" ;;
        alwaysThinkingEnabled)
          if [[ "$thinking_caps_apply" == true ]]; then
            mc_issue "WARN" "alwaysThinkingEnabled is false ($thinking_note)" "$thinking_fix"
          fi ;;
        MAX_THINKING_TOKENS)
          if [[ "$thinking_caps_apply" == true ]]; then
            mc_issue "WARN" "env.MAX_THINKING_TOKENS is set to $value ($thinking_note)" "$thinking_fix"
          fi ;;
        env.CLAUDE_CODE_EFFORT_LEVEL) mc_check_effort "$key" "$value" "env" ;;
        env.CLAUDE_CODE_DISABLE_THINKING|env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING)
          # Claude Code reads these flags as on only for 1, true, yes or on.
          mc_normalize "$value"
          case "$MC_VALUE" in
            1|true|yes|on)
              if [[ "$thinking_caps_apply" == true ]]; then
                mc_issue "WARN" "$key is set to $value ($thinking_note)" "$thinking_fix"
              fi ;;
          esac ;;
        env.*)       mc_check_model "$key" "$value" ;;
      esac
    done <<< "$entries"
    mc_flush "$file"
  done

  if [[ "$MC_OK" -gt 0 ]]; then
    add_check "model-config" "correctness" "PASS" "$MC_OK model/effort setting(s) use aliases, current model IDs or valid effort levels"
  elif [[ "$MC_ANY_ISSUE" == false ]]; then
    add_check "model-config" "correctness" "PASS" "No model pins or effort settings found in .claude/ or plugin-root frontmatter, or in settings"
  fi
}

###############################################################################
# Check 11: agent-format — non-.md agent definitions are never loaded
#   Scans .claude/agents/ and each plugin root's agents/.
###############################################################################
check_agent_format() {
  log "Running agent-format checks..."
  local dirs=(".claude/agents") dir
  while IFS= read -r -d '' dir; do
    dirs+=("$dir")
  done < <(plugin_component_dirs agents)

  local found_dir=false found_any=false
  for dir in "${dirs[@]}"; do
    [[ -d "$TARGET/$dir" ]] || continue
    found_dir=true
    while IFS= read -r -d '' agent_file; do
      found_any=true
      local rel_path="${agent_file#"$TARGET"/}"
      add_check "agent-format" "correctness" "WARN" \
        "Not loaded by Claude Code: $rel_path (agents must be .md files with YAML frontmatter)" "$rel_path" \
        "Convert it to $dir/<name>.md with name and description (plus tools, model, effort as needed) in YAML frontmatter and the prompt as the body, then remove the old file"
    done < <(find "$TARGET/$dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.json' \) -print0 2>/dev/null | sort -z)
  done

  if [[ "$found_dir" == false ]]; then
    add_check "agent-format" "correctness" "PASS" "No agent directories (.claude/agents/ or plugin agents/)"
  elif [[ "$found_any" == false ]]; then
    add_check "agent-format" "correctness" "PASS" "No .yml/.yaml/.json agent files in .claude/agents/ or plugin agents/"
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
  check_model_config
  check_agent_format

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
