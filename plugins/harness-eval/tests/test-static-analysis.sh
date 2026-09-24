#!/usr/bin/env bash
set -euo pipefail

# test-static-analysis.sh — Tests for static-analysis.sh against fixture projects

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANALYSIS="$PROJECT_ROOT/scripts/static-analysis.sh"
FIXTURES="$PROJECT_ROOT/tests/fixtures"

export HARNESS_EVAL_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
ERRORS=""

###############################################################################
# Helpers
###############################################################################

assert_true() {
  local condition="$1"
  local label="$2"

  if [[ "$condition" == "true" || "$condition" == "1" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label"
  fi
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — got $actual"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — got $actual (expected $expected)"
  fi
}

assert_ge() {
  local actual="$1"
  local min="$2"
  local label="$3"

  if [[ "$actual" -ge "$min" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — $actual >= $min"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — $actual < $min"
  fi
}

assert_exit_code() {
  local args="$1"
  local expected="$2"
  local label="$3"

  set +e
  eval "$ANALYSIS" $args > /dev/null 2>&1
  local actual=$?
  set -e

  assert_eq "$actual" "$expected" "$label"
}

# check_status <json> <id> <file> — comma-joined statuses of the checks with
# that id and file field ("none" when there is no such check).
check_status() {
  echo "$1" | jq -r --arg id "$2" --arg file "$3" '
    [.checks[] | select(.id == $id and .file == $file) | .status]
    | if length == 0 then "none" else join(",") end' 2>/dev/null || echo "error"
}

# check_details_match <json> <id> <file> <regex> — "true" if that check's details match.
check_details_match() {
  echo "$1" | jq --arg id "$2" --arg file "$3" --arg re "$4" '
    [.checks[] | select(.id == $id and .file == $file) | .details | test($re)] | any' 2>/dev/null || echo "false"
}

###############################################################################
# Test 1: Valid JSON output for all fixtures
###############################################################################
echo "=== static-analysis.sh tests ==="
echo ""
echo "--- Valid JSON output ---"

for fixture in minimal-project functional-project robust-project production-project; do
  output=$("$ANALYSIS" "$FIXTURES/$fixture" 2>/dev/null) || true
  valid=$(echo "$output" | jq 'type == "object"' 2>/dev/null || echo "false")
  assert_true "$valid" "$fixture produces valid JSON"
done

###############################################################################
# Test 2: Summary fields exist (pass/warn/fail/total)
###############################################################################
echo ""
echo "--- Summary fields ---"

for fixture in minimal-project functional-project robust-project production-project; do
  output=$("$ANALYSIS" "$FIXTURES/$fixture" 2>/dev/null) || true
  has_fields=$(echo "$output" | jq '
    .summary | type == "object"
    and has("pass") and has("warn") and has("fail") and has("total")
  ' 2>/dev/null || echo "false")
  assert_true "$has_fields" "$fixture summary has pass/warn/fail/total fields"
done

###############################################################################
# Test 3: Checks array items have required fields (id, category, status, details)
###############################################################################
echo ""
echo "--- Checks array structure ---"

for fixture in minimal-project functional-project robust-project production-project; do
  output=$("$ANALYSIS" "$FIXTURES/$fixture" 2>/dev/null) || true
  count=$(echo "$output" | jq '.checks | length' 2>/dev/null || echo "0")
  if [[ "$count" -gt 0 ]]; then
    # Verify all items have required fields
    all_valid=$(echo "$output" | jq '
      .checks | map(has("id") and has("category") and has("status") and has("details")) | all
    ' 2>/dev/null || echo "false")
    assert_true "$all_valid" "$fixture checks items have id/category/status/details"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $fixture checks array is empty"
    echo "  FAIL: $fixture checks array is empty"
  fi
done

###############################################################################
# Test 4: Minimal fixture has at least 1 FAIL (no hooks)
###############################################################################
echo ""
echo "--- Minimal fixture failures ---"

output=$("$ANALYSIS" "$FIXTURES/minimal-project" 2>/dev/null) || true
fail_count=$(echo "$output" | jq '.summary.fail' 2>/dev/null || echo "0")
assert_ge "$fail_count" 1 "minimal-project has at least 1 FAIL"

###############################################################################
# Test 5: Production fixture has 0 FAIL and 0 WARN
###############################################################################
echo ""
echo "--- Production fixture clean ---"

output=$("$ANALYSIS" "$FIXTURES/production-project" 2>/dev/null) || true
prod_fail=$(echo "$output" | jq '.summary.fail' 2>/dev/null || echo "1")
prod_warn=$(echo "$output" | jq '.summary.warn' 2>/dev/null || echo "1")
assert_eq "$prod_fail" "0" "production-project has 0 FAIL"
assert_eq "$prod_warn" "0" "production-project has 0 WARN"

###############################################################################
# Test 6: Monotonic quality — production has fewer issues than minimal
###############################################################################
echo ""
echo "--- Monotonic quality ---"

min_output=$("$ANALYSIS" "$FIXTURES/minimal-project" 2>/dev/null) || true
prod_output=$("$ANALYSIS" "$FIXTURES/production-project" 2>/dev/null) || true

min_issues=$(echo "$min_output" | jq '.summary.warn + .summary.fail' 2>/dev/null || echo "999")
prod_issues=$(echo "$prod_output" | jq '.summary.warn + .summary.fail' 2>/dev/null || echo "999")

if [[ "$prod_issues" -lt "$min_issues" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: production has fewer issues than minimal ($prod_issues < $min_issues)"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: production issues ($prod_issues) should be < minimal issues ($min_issues)"
fi

###############################################################################
# Test 7: Exit codes
###############################################################################
echo ""
echo "--- Exit codes ---"

assert_exit_code "\"$FIXTURES/robust-project\""     0 "robust-project exits 0 (all pass)"
assert_exit_code "\"$FIXTURES/production-project\"" 0 "production-project exits 0 (all pass)"
assert_exit_code "\"$FIXTURES/minimal-project\""    1 "minimal-project exits 1 (has fails/warns)"
assert_exit_code "/nonexistent/path"                2 "nonexistent path exits 2"
assert_exit_code ""                                 2 "no arguments exits 2"

###############################################################################
# Test 8: Bad syntax detection via temp fixture
###############################################################################
echo ""
echo "--- Bad syntax detection ---"

TMPDIR_FIXTURE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE"' EXIT

# Set up minimal temp fixture structure
mkdir -p "$TMPDIR_FIXTURE/.claude/hooks"
mkdir -p "$TMPDIR_FIXTURE/.claude"

# Create a broken hook script with invalid bash syntax
cat > "$TMPDIR_FIXTURE/.claude/hooks/broken-hook.sh" << 'BROKEN'
#!/usr/bin/env bash
# This file has intentionally broken syntax
if [[ true ]]; then
  echo "unclosed if block"
# missing fi
BROKEN

chmod +x "$TMPDIR_FIXTURE/.claude/hooks/broken-hook.sh"

# Create a minimal settings.json so other checks don't swamp the result
cat > "$TMPDIR_FIXTURE/.claude/settings.json" << 'SETTINGS'
{
  "permissions": {
    "allow": [],
    "deny": ["Bash(rm -rf:*)"]
  },
  "hooks": {
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": ".claude/hooks/broken-hook.sh"}]}],
    "PostToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": ".claude/hooks/broken-hook.sh"}]}]
  }
}
SETTINGS

# Create CLAUDE.md so root-claude-md doesn't add noise
echo "# Test project" > "$TMPDIR_FIXTURE/CLAUDE.md"

tmp_output=$("$ANALYSIS" "$TMPDIR_FIXTURE" 2>/dev/null) || true

# Check that bash-syntax check produced at least one FAIL
bash_syntax_fails=$(echo "$tmp_output" | jq '[.checks[] | select(.id == "bash-syntax" and .status == "FAIL")] | length' 2>/dev/null || echo "0")
assert_ge "$bash_syntax_fails" 1 "temp fixture with broken .sh triggers bash-syntax FAIL"

# Confirm the failing check references the broken file
broken_file_mentioned=$(echo "$tmp_output" | jq '
  [.checks[] | select(.id == "bash-syntax" and .status == "FAIL")] | length > 0
' 2>/dev/null || echo "false")
assert_true "$broken_file_mentioned" "bash-syntax FAIL check references broken hook file"

###############################################################################
# Test 9: hook-file-mapping supports the nested (real Claude Code) hook schema
#          — regression guard for the flat-only command-extraction bug (decision #4).
###############################################################################
echo ""
echo "--- Nested hook schema (hook-file-mapping regression) ---"

nested_output=$("$ANALYSIS" "$FIXTURES/nested-hooks-project" 2>/dev/null) || true

# The nested fixture references present-hook.sh (exists) and missing-hook.sh (absent),
# both under the real Claude Code nested schema (.hooks.<Event>[].hooks[].command).
# Extraction must read the nested command and never yield the pre-fix "null" path.
nested_present=$(echo "$nested_output" | jq '
  [.checks[]
   | select(.id == "hook-file-mapping" and .status == "PASS"
            and (.details | test("present-hook\\.sh")))] | length' 2>/dev/null || echo "0")
assert_ge "$nested_present" 1 "nested schema: present-hook.sh mapped to PASS"

nested_missing=$(echo "$nested_output" | jq '
  [.checks[]
   | select(.id == "hook-file-mapping" and .status == "FAIL"
            and (.details | test("missing-hook\\.sh")))] | length' 2>/dev/null || echo "0")
assert_ge "$nested_missing" 1 "nested schema: missing-hook.sh mapped to FAIL"

# Regression: the flat-only extraction produced "Hook file missing: null" for nested hooks.
nested_null=$(echo "$nested_output" | jq '
  [.checks[]
   | select(.id == "hook-file-mapping")
   | .details | select(test("null"))] | length' 2>/dev/null || echo "0")
assert_eq "$nested_null" "0" "nested schema: no 'null' hook path leaked (decision #4 regression)"

###############################################################################
# Test 10: model-config / agent-format on the frozen fixtures — none of them
#          pins a model or ships a non-.md agent, so each check adds exactly
#          one correctness PASS and nothing else.
###############################################################################
echo ""
echo "--- model-config / agent-format on frozen fixtures ---"

for fixture in minimal-project functional-project robust-project production-project nested-hooks-project; do
  output=$("$ANALYSIS" "$FIXTURES/$fixture" 2>/dev/null) || true
  for id in model-config agent-format; do
    entries=$(echo "$output" | jq -r --arg id "$id" '
      [.checks[] | select(.id == $id) | "\(.status)/\(.category)"] | join(",")' 2>/dev/null || echo "error")
    assert_eq "$entries" "PASS/correctness" "$fixture: $id emits exactly one correctness PASS"
  done
done

###############################################################################
# Test 11: model-config paths on tests/fixtures/model-era-project
#          (see that fixture's CLAUDE.md for the per-file expectations)
###############################################################################
echo ""
echo "--- model-config (model-era-project) ---"

ERA="$FIXTURES/model-era-project"
era_output=$("$ANALYSIS" "$ERA" 2>/dev/null) || true

era_valid=$(echo "$era_output" | jq 'type == "object"' 2>/dev/null || echo "false")
assert_true "$era_valid" "model-era-project produces valid JSON"

assert_eq "$(check_status "$era_output" model-config .claude/agents/retired.md)" "FAIL" \
  "retired generation (claude-3-5-sonnet snapshot) is a FAIL"
assert_eq "$(check_status "$era_output" model-config .claude/agents/retired41.md)" "FAIL" \
  "retired-table model (claude-opus-4-1) is a FAIL"
assert_eq "$(check_status "$era_output" model-config .claude/agents/deprecated.md)" "WARN" \
  "deprecated model (claude-sonnet-4-0) is a WARN"
assert_eq "$(check_status "$era_output" model-config .claude/agents/snapshot.md)" "WARN" \
  "dated snapshot (claude-haiku-4-5-20251001) is a WARN"
assert_true "$(check_details_match "$era_output" model-config .claude/agents/snapshot.md "'claude-haiku-4-5-20251001' pins a dated snapshot$")" \
  "snapshot value is read with quotes and trailing comment stripped"
assert_eq "$(check_status "$era_output" model-config .claude/agents/inherit.md)" "WARN" \
  "invalid effort (turbo) is a WARN"
assert_true "$(check_details_match "$era_output" model-config .claude/agents/inherit.md "effort 'turbo'")" \
  "invalid-effort WARN names the effort value, not the inherit model"
assert_eq "$(check_status "$era_output" model-config .claude/agents/typo.md)" "WARN" \
  "claude-* ID outside the known families and version shape (claude-sonnet-4.5) is a WARN"
assert_true "$(check_details_match "$era_output" model-config .claude/agents/typo.md "'claude-sonnet-4.5' is an unrecognized Claude model ID")" \
  "typo WARN says the ID is unrecognized"
assert_true "$(check_details_match "$era_output" model-config .claude/agents/typo55.md "'claude-opus-55' is an unrecognized Claude model ID")" \
  "a well-shaped typo (claude-opus-55 for claude-opus-5-5) is an unrecognized-ID WARN"
assert_true "$(check_details_match "$era_output" model-config .claude/agents/unreleased.md "'claude-sonnet-4-7' is an unrecognized Claude model ID")" \
  "a well-formed ID that was never released (claude-sonnet-4-7) is an unrecognized-ID WARN"
assert_eq "$(check_status "$era_output" model-config .claude/commands/ship.md)" "WARN" \
  "unrecognized model name in a command (gpt-4o) is a WARN"
assert_eq "$(check_status "$era_output" model-config .claude/settings.json)" "WARN" \
  "settings.json thinking caps and deprecated env model give one WARN for the file"
assert_true "$(check_details_match "$era_output" model-config .claude/settings.json "alwaysThinkingEnabled is false")" \
  "settings.json WARN reports alwaysThinkingEnabled: false"
assert_true "$(check_details_match "$era_output" model-config .claude/settings.json "MAX_THINKING_TOKENS")" \
  "settings.json WARN reports env.MAX_THINKING_TOKENS"
assert_true "$(check_details_match "$era_output" model-config .claude/settings.json "env.CLAUDE_CODE_SUBAGENT_MODEL 'claude-sonnet-4-20250514' is deprecated")" \
  "settings.json WARN reports the deprecated env model"
assert_true "$(check_details_match "$era_output" model-config .claude/settings.json "env.CLAUDE_CODE_DISABLE_THINKING is set to 1 \\(not a cost control")" \
  "settings.json WARN reports env.CLAUDE_CODE_DISABLE_THINKING=1 under an always-thinking model"
assert_eq "$(check_details_match "$era_output" model-config .claude/settings.json "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING")" "false" \
  "env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=0 (flag off) is not reported"
assert_true "$(check_details_match "$era_output" model-config .claude/settings.json "env.CLAUDE_CODE_EFFORT_LEVEL 'maximum' is not a valid effort level")" \
  "settings.json WARN reports the invalid env.CLAUDE_CODE_EFFORT_LEVEL"

for ok_file in .claude/agents/pinned.md .claude/agents/fable.md .claude/skills/summarize/SKILL.md .claude/agents/reviewer.yml; do
  assert_eq "$(check_status "$era_output" model-config "$ok_file")" "none" \
    "model-config does not flag $ok_file"
done
assert_eq "$(check_status "$era_output" model-config .claude/skills/summarize/agent-template.md)" "none" \
  "a skill's supporting .md (not SKILL.md) is not read, so its retired ID is not flagged"

era_mc_pass=$(echo "$era_output" | jq -r '
  [.checks[] | select(.id == "model-config" and .status == "PASS") | .details] | join("|")' 2>/dev/null || echo "error")
assert_true "$([[ "$era_mc_pass" == "10 model/effort setting(s) "* ]] && echo true || echo false)" \
  "valid values (aliases, [1m], undated IDs, named/integer effort) aggregate into one PASS of 10"

###############################################################################
# Test 12: agent-format paths on model-era-project
###############################################################################
echo ""
echo "--- agent-format (model-era-project) ---"

assert_eq "$(check_status "$era_output" agent-format .claude/agents/reviewer.yml)" "WARN" \
  "reviewer.yml agent definition is a WARN"
assert_eq "$(check_status "$era_output" agent-format .claude/agents/triage.json)" "WARN" \
  "triage.json agent definition is a WARN"
era_af=$(echo "$era_output" | jq -r '[.checks[] | select(.id == "agent-format") | .status] | join(",")' 2>/dev/null || echo "error")
assert_eq "$era_af" "WARN,WARN" "agent-format flags only the non-.md files and emits no PASS"

###############################################################################
# Test 13: the new checks feed categories.correctness
#          (5 existing PASS + 1 aggregated model-config PASS; 8 + 2 WARN; 2 FAIL)
###############################################################################
echo ""
echo "--- correctness category effect (model-era-project) ---"

era_corr=$(echo "$era_output" | jq -c '.categories.correctness | [.pass, .warn, .fail, .score]' 2>/dev/null || echo "error")
assert_eq "$era_corr" "[6,10,2,6.1]" "model-era-project correctness [pass,warn,fail,score]"
assert_exit_code "\"$ERA\"" 1 "model-era-project exits 1 (has fails/warns)"

###############################################################################
# Test 14: settings-only rules via a temp fixture (settings.local.json is
#          gitignored, so it cannot live in a committed fixture)
###############################################################################
echo ""
echo "--- model-config settings rules (temp fixture) ---"

TMPDIR_MODEL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE" "$TMPDIR_MODEL"' EXIT
mkdir -p "$TMPDIR_MODEL/.claude"
echo "# Model settings test project" > "$TMPDIR_MODEL/CLAUDE.md"

# CLAUDE_CODE_TMPDIR is not a model env var, so its "claude-2" is not read as Claude 2.
cat > "$TMPDIR_MODEL/.claude/settings.json" << 'SETTINGS'
{
  "model": "sonnet",
  "effortLevel": "xhigh",
  "env": {
    "CLAUDE_CONFIG_DIR": "/home/dev/.claude",
    "CLAUDE_CODE_TMPDIR": "/tmp/claude-2"
  }
}
SETTINGS

cat > "$TMPDIR_MODEL/.claude/settings.local.json" << 'SETTINGS'
{
  "model": "claude-3-7-sonnet-20250219",
  "effortLevel": "max",
  "env": {
    "ANTHROPIC_MODEL": "us.anthropic.claude-opus-4-1-20250805-v1:0",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-5@20251101",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4",
    "ANTHROPIC_SMALL_FAST_MODEL": "anthropic.claude-v2:1",
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-1.3",
    "ANTHROPIC_CUSTOM_MODEL_OPTION": "us.anthropic.claude-sonnet-4.5-v1:0"
  }
}
SETTINGS

model_output=$("$ANALYSIS" "$TMPDIR_MODEL" 2>/dev/null) || true

assert_eq "$(check_status "$model_output" model-config .claude/settings.json)" "none" \
  "valid settings (alias model, effortLevel xhigh, non-model env values containing claude-) are not flagged"
assert_eq "$(check_status "$model_output" model-config .claude/settings.local.json)" "FAIL" \
  "settings.local.json is scanned and its worst issue (retired model) sets one FAIL"
assert_true "$(check_details_match "$model_output" model-config .claude/settings.local.json "effortLevel 'max' is not accepted in settings")" \
  "effortLevel max in settings is reported (settings accept low..xhigh only)"
assert_true "$(check_details_match "$model_output" model-config .claude/settings.local.json "env.ANTHROPIC_MODEL '[^']*claude-opus-4-1[^']*' is a retired model")" \
  "Bedrock spelling of a retired model is caught"
assert_true "$(check_details_match "$model_output" model-config .claude/settings.local.json "'anthropic.claude-v2:1' is a retired model")" \
  "Bedrock Claude 2 spelling (claude-v2) is caught"
assert_true "$(check_details_match "$model_output" model-config .claude/settings.local.json "env.CLAUDE_CODE_SUBAGENT_MODEL 'claude-1.3' is a retired model")" \
  "Claude 1.x ID is caught"
assert_true "$(check_details_match "$model_output" model-config .claude/settings.local.json "'claude-sonnet-4' is deprecated")" \
  "Foundry spelling of a deprecated model (claude-sonnet-4) is caught"
assert_true "$(check_details_match "$model_output" model-config .claude/settings.local.json "env.ANTHROPIC_CUSTOM_MODEL_OPTION '[^']*claude-sonnet-4.5-v1:0' is an unrecognized Claude model ID")" \
  "a typo inside a Bedrock-form ID is still reported"
assert_eq "$(check_details_match "$model_output" model-config .claude/settings.local.json "claude-opus-4-5@20251101")" "false" \
  "Vertex @date ID (the model has no undated Vertex ID) is a valid pin"
assert_eq "$(check_details_match "$model_output" model-config .claude/settings.local.json "claude-haiku-4-5-20251001-v1:0")" "false" \
  "Bedrock dated ID (the model has no undated Bedrock ID) is a valid pin"

model_pass=$(echo "$model_output" | jq -r '
  [.checks[] | select(.id == "model-config" and .status == "PASS") | .details] | join("|")' 2>/dev/null || echo "error")
assert_true "$([[ "$model_pass" == "4 model/effort setting(s) "* ]] && echo true || echo false)" \
  "only the four valid model/effort values are counted in the PASS"
assert_eq "$(echo "$model_output" | jq -r '[.checks[] | select(.id == "agent-format") | .status] | join(",")' 2>/dev/null || echo "error")" \
  "PASS" "no .claude/agents/ directory gives one agent-format PASS"

###############################################################################
# Test 15: plugin roots via a temp fixture — a directory holding
#          .claude-plugin/plugin.json (the target itself or plugins/*/) has its
#          agents/, skills/<name>/SKILL.md and commands/ read like .claude/
###############################################################################
echo ""
echo "--- model-config / agent-format on plugin roots (temp fixture) ---"

TMPDIR_PLUGIN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE" "$TMPDIR_MODEL" "$TMPDIR_PLUGIN"' EXIT
mkdir -p "$TMPDIR_PLUGIN/.claude-plugin" "$TMPDIR_PLUGIN/agents" "$TMPDIR_PLUGIN/skills/doc" \
  "$TMPDIR_PLUGIN/commands" "$TMPDIR_PLUGIN/plugins/p1/.claude-plugin" "$TMPDIR_PLUGIN/plugins/p1/agents" \
  "$TMPDIR_PLUGIN/plugins/other/agents"
echo "# Plugin test project" > "$TMPDIR_PLUGIN/CLAUDE.md"
echo '{"name": "root-plugin"}' > "$TMPDIR_PLUGIN/.claude-plugin/plugin.json"
echo '{"name": "p1"}' > "$TMPDIR_PLUGIN/plugins/p1/.claude-plugin/plugin.json"

printf -- '---\nname: legacy\ndescription: Legacy agent\nmodel: claude-3-opus-20240229\n---\n\nReview.\n' \
  > "$TMPDIR_PLUGIN/agents/legacy.md"
# Windows line endings: the frontmatter must still be read.
printf -- '---\r\nname: crlf\r\ndescription: Agent saved with CRLF\r\nmodel: claude-opus-4-1\r\neffort: high\r\n---\r\n\r\nPlan.\r\n' \
  > "$TMPDIR_PLUGIN/agents/crlf.md"
# No closing '---': Claude Code reads no frontmatter, so neither does model-config.
printf -- '---\nname: unclosed\nmodel: claude-3-opus-20240229\n\nDraft.\n' \
  > "$TMPDIR_PLUGIN/agents/unclosed.md"
printf -- '---\nname: doc\ndescription: Doc skill\nmodel: haiku\neffort: low\n---\n\nWrite docs.\n' \
  > "$TMPDIR_PLUGIN/skills/doc/SKILL.md"
printf -- '---\nname: template\ndescription: Supporting file\nmodel: claude-3-opus-20240229\n---\n' \
  > "$TMPDIR_PLUGIN/skills/doc/reference.md"
printf -- '---\ndescription: Run command\nmodel: gpt-4o\n---\n\nRun.\n' > "$TMPDIR_PLUGIN/commands/run.md"
printf -- '---\nname: y\ndescription: Deprecated pin\nmodel: claude-sonnet-4-0\n---\n\nCheck.\n' \
  > "$TMPDIR_PLUGIN/plugins/p1/agents/y.md"
printf 'name: x\nprompt: Review.\n' > "$TMPDIR_PLUGIN/plugins/p1/agents/x.yml"
printf -- '---\nname: z\ndescription: Not in a plugin root\nmodel: claude-3-opus-20240229\n---\n' \
  > "$TMPDIR_PLUGIN/plugins/other/agents/z.md"

plugin_output=$("$ANALYSIS" "$TMPDIR_PLUGIN" 2>/dev/null) || true

assert_eq "$(check_status "$plugin_output" model-config agents/legacy.md)" "FAIL" \
  "retired model in an agent of a plugin at the project root is a FAIL"
assert_eq "$(check_status "$plugin_output" model-config agents/crlf.md)" "FAIL" \
  "CRLF frontmatter is read (retired model in a CRLF agent is a FAIL)"
assert_eq "$(check_status "$plugin_output" model-config agents/unclosed.md)" "none" \
  "frontmatter without a closing --- is not read"
assert_eq "$(check_status "$plugin_output" model-config commands/run.md)" "WARN" \
  "plugin commands/ are read"
assert_eq "$(check_status "$plugin_output" model-config plugins/p1/agents/y.md)" "WARN" \
  "agents of a plugin under plugins/*/ are read"
assert_eq "$(check_status "$plugin_output" model-config skills/doc/reference.md)" "none" \
  "a plugin skill's supporting .md is not read"
assert_eq "$(check_status "$plugin_output" model-config plugins/other/agents/z.md)" "none" \
  "a plugins/*/ directory without .claude-plugin/plugin.json is not a plugin root"

plugin_pass=$(echo "$plugin_output" | jq -r '
  [.checks[] | select(.id == "model-config" and .status == "PASS") | .details] | join("|")' 2>/dev/null || echo "error")
assert_true "$([[ "$plugin_pass" == "3 model/effort setting(s) "* ]] && echo true || echo false)" \
  "valid plugin values (CRLF effort, SKILL.md model and effort) are counted in the PASS"
assert_eq "$(check_status "$plugin_output" agent-format plugins/p1/agents/x.yml)" "WARN" \
  "a .yml agent in a plugin's agents/ is a WARN"
assert_eq "$(echo "$plugin_output" | jq -r '[.checks[] | select(.id == "agent-format") | .status] | join(",")' 2>/dev/null || echo "error")" \
  "WARN" "agent-format reports only that file and emits no PASS"

###############################################################################
# Test 16: thinking caps under a model that accepts disabled thinking are a
#          working cost control, so they are not reported
###############################################################################
echo ""
echo "--- model-config thinking caps with a non-always-thinking model (temp fixture) ---"

TMPDIR_THINK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE" "$TMPDIR_MODEL" "$TMPDIR_PLUGIN" "$TMPDIR_THINK"' EXIT
mkdir -p "$TMPDIR_THINK/.claude"
echo "# Thinking settings test project" > "$TMPDIR_THINK/CLAUDE.md"
cat > "$TMPDIR_THINK/.claude/settings.json" << 'SETTINGS'
{
  "model": "haiku",
  "alwaysThinkingEnabled": false,
  "env": { "MAX_THINKING_TOKENS": "8000" }
}
SETTINGS

think_output=$("$ANALYSIS" "$TMPDIR_THINK" 2>/dev/null) || true
assert_eq "$(check_status "$think_output" model-config .claude/settings.json)" "none" \
  "alwaysThinkingEnabled false and MAX_THINKING_TOKENS with model haiku are not flagged"

###############################################################################
# Tests 17-19 use one temp project per case, each with its own settings.
###############################################################################
TMPDIR_CASES="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE" "$TMPDIR_MODEL" "$TMPDIR_PLUGIN" "$TMPDIR_THINK" "$TMPDIR_CASES"' EXIT

# settings_case <name> <settings.json> [settings.local.json] — create the case
# project and print its static-analysis output.
settings_case() {
  local dir="$TMPDIR_CASES/$1"
  mkdir -p "$dir/.claude"
  echo "# Settings case $1" > "$dir/CLAUDE.md"
  printf '%s\n' "$2" > "$dir/.claude/settings.json"
  if [[ -n "${3:-}" ]]; then
    printf '%s\n' "$3" > "$dir/.claude/settings.local.json"
  fi
  "$ANALYSIS" "$dir" 2>/dev/null || true
}

###############################################################################
# Test 17: the thinking-cap exemption compares the settings model as its
#          undated ID, and the env thinking flags follow the same exemption
###############################################################################
echo ""
echo "--- model-config thinking caps: provider spellings and env flags (temp fixtures) ---"

case_output=$(settings_case opus5-bedrock '{"model": "us.anthropic.claude-opus-5-v1:0", "alwaysThinkingEnabled": false,
  "env": {"MAX_THINKING_TOKENS": "8000", "CLAUDE_CODE_DISABLE_THINKING": "1", "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING": "true"}}')
assert_eq "$(check_status "$case_output" model-config .claude/settings.json)" "none" \
  "Bedrock spelling of Opus 5 is exempt like claude-opus-5 (thinking caps and env flags not flagged)"

case_output=$(settings_case opus5-vertex '{"model": "claude-opus-5@20260115", "alwaysThinkingEnabled": false,
  "env": {"CLAUDE_CODE_DISABLE_THINKING": "yes"}}')
assert_eq "$(check_status "$case_output" model-config .claude/settings.json)" "none" \
  "Vertex spelling of Opus 5 is exempt like claude-opus-5"

case_output=$(settings_case opus55 '{"model": "claude-opus-5-5", "alwaysThinkingEnabled": false,
  "env": {"CLAUDE_CODE_DISABLE_THINKING": "TRUE", "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING": "on"}}')
assert_eq "$(check_status "$case_output" model-config .claude/settings.json)" "WARN" \
  "claude-opus-5-5 is not exempt: its thinking caps are one WARN for the file"
assert_true "$(check_details_match "$case_output" model-config .claude/settings.json "alwaysThinkingEnabled is false")" \
  "claude-opus-5-5 WARN reports alwaysThinkingEnabled: false"
assert_true "$(check_details_match "$case_output" model-config .claude/settings.json "env.CLAUDE_CODE_DISABLE_THINKING is set to TRUE")" \
  "claude-opus-5-5 WARN reports env.CLAUDE_CODE_DISABLE_THINKING (flag values are case-insensitive)"
assert_true "$(check_details_match "$case_output" model-config .claude/settings.json "env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING is set to on")" \
  "claude-opus-5-5 WARN reports env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING"

case_output=$(settings_case opus55-bedrock '{"model": "us.anthropic.claude-opus-5-5-v1:0",
  "env": {"CLAUDE_CODE_DISABLE_THINKING": "1"}}')
assert_true "$(check_details_match "$case_output" model-config .claude/settings.json "env.CLAUDE_CODE_DISABLE_THINKING is set to 1")" \
  "Bedrock spelling of Opus 5.5 is not exempt"

###############################################################################
# Test 18: env.CLAUDE_CODE_EFFORT_LEVEL — an accepted value is a WARN because it
#          overrides every agent's effort; any other value is ignored by Claude Code
###############################################################################
echo ""
echo "--- model-config env.CLAUDE_CODE_EFFORT_LEVEL (temp fixtures) ---"

case_output=$(settings_case effort-named '{"model": "sonnet", "env": {"CLAUDE_CODE_EFFORT_LEVEL": "High"}}' \
  '{"env": {"CLAUDE_CODE_EFFORT_LEVEL": "unset"}}')
assert_true "$(check_details_match "$case_output" model-config .claude/settings.json "env.CLAUDE_CODE_EFFORT_LEVEL 'high' overrides the effort of every agent")" \
  "a named effort level (any case) is a WARN that it overrides every agent's effort"
assert_true "$(check_details_match "$case_output" model-config .claude/settings.local.json "env.CLAUDE_CODE_EFFORT_LEVEL 'unset' overrides the effort of every agent")" \
  "unset is accepted and reported as an override"
case_pass=$(echo "$case_output" | jq -r '
  [.checks[] | select(.id == "model-config" and .status == "PASS") | .details] | join("|")' 2>/dev/null || echo "error")
assert_true "$([[ "$case_pass" == "1 model/effort setting(s) "* ]] && echo true || echo false)" \
  "an accepted CLAUDE_CODE_EFFORT_LEVEL is not counted as a valid setting in the PASS"

case_output=$(settings_case effort-int '{"env": {"CLAUDE_CODE_EFFORT_LEVEL": "40"}}' \
  '{"env": {"CLAUDE_CODE_EFFORT_LEVEL": "auto"}}')
assert_true "$(check_details_match "$case_output" model-config .claude/settings.json "'40' overrides the effort")" \
  "an integer effort is accepted and reported as an override"
assert_true "$(check_details_match "$case_output" model-config .claude/settings.local.json "'auto' overrides the effort")" \
  "auto is accepted and reported as an override"

case_output=$(settings_case effort-bad '{"env": {"CLAUDE_CODE_EFFORT_LEVEL": ""}}' \
  '{"env": {"CLAUDE_CODE_EFFORT_LEVEL": "ultracode"}}')
assert_eq "$(check_status "$case_output" model-config .claude/settings.json)" "none" \
  "an empty CLAUDE_CODE_EFFORT_LEVEL sets nothing and is not flagged"
assert_true "$(check_details_match "$case_output" model-config .claude/settings.local.json "'ultracode' is not a valid effort level; Claude Code ignores it")" \
  "a value the env var does not accept (ultracode) is reported as ignored"

###############################################################################
# Test 19: every served model ID passes, and well-shaped IDs that name no
#          served model are unrecognized (claude-api shared/models.md)
###############################################################################
echo ""
echo "--- model-config served model IDs (temp fixture) ---"

SERVED_IDS=(claude-opus-5-5 claude-opus-5 claude-opus-4-8 claude-opus-4-7 claude-opus-4-6 claude-opus-4-5
  claude-sonnet-5 claude-sonnet-4-6 claude-sonnet-4-5 claude-haiku-4-5
  claude-fable-5-1 claude-fable-5 claude-mythos-5-1 claude-mythos-5)
UNSERVED_IDS=(claude-opus-55 claude-opus-5-6 claude-opus-4-9 claude-opus-6 claude-sonnet-4-7 claude-sonnet-6
  claude-haiku-5 claude-haiku-4-6 claude-fable-9 claude-fable-5-2 claude-mythos-5-2)
ids_dir="$TMPDIR_CASES/model-ids"
mkdir -p "$ids_dir/.claude/agents"
echo "# Model ID table" > "$ids_dir/CLAUDE.md"
for id in "${SERVED_IDS[@]}" "${UNSERVED_IDS[@]}"; do
  printf -- '---\nname: %s\ndescription: Agent pinned to %s\nmodel: %s\n---\n\nWork.\n' "$id" "$id" "$id" \
    > "$ids_dir/.claude/agents/$id.md"
done
ids_output=$("$ANALYSIS" "$ids_dir" 2>/dev/null) || true

flagged_served=""
for id in "${SERVED_IDS[@]}"; do
  [[ "$(check_status "$ids_output" model-config ".claude/agents/$id.md")" == "none" ]] || flagged_served="$flagged_served $id"
done
assert_eq "${flagged_served# }" "" "no served model ID is flagged"
ids_pass=$(echo "$ids_output" | jq -r '
  [.checks[] | select(.id == "model-config" and .status == "PASS") | .details] | join("|")' 2>/dev/null || echo "error")
assert_true "$([[ "$ids_pass" == "${#SERVED_IDS[@]} model/effort setting(s) "* ]] && echo true || echo false)" \
  "all ${#SERVED_IDS[@]} served model IDs are counted in the PASS"
missed_unserved=""
for id in "${UNSERVED_IDS[@]}"; do
  [[ "$(check_details_match "$ids_output" model-config ".claude/agents/$id.md" "'$id' is an unrecognized Claude model ID")" == "true" ]] \
    || missed_unserved="$missed_unserved $id"
done
assert_eq "${missed_unserved# }" "" "every unserved ID (typos, unreleased versions) is an unrecognized-ID WARN"

###############################################################################
# Summary
###############################################################################
echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailures:$ERRORS"
  exit 1
fi
echo "All tests passed!"
