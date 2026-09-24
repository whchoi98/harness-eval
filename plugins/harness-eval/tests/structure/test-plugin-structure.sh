#!/bin/bash
# Validates plugin structure integrity: manifests, file existence, CLAUDE.md sections,
# and the Full-mode string contracts between skills/full/SKILL.md, the agents, and aggregate.sh.
# Runs from REPO_ROOT. PLUGIN_ROOT points to plugins/harness-eval/.

P="${PLUGIN_ROOT:-.}"

# --- Marketplace manifest ---
assert_file_exists "marketplace.json exists" ".claude-plugin/marketplace.json"
assert_json_valid "marketplace.json is valid JSON" ".claude-plugin/marketplace.json"

# --- Plugin manifest ---
PLUGIN_MANIFEST="$P/.claude-plugin/plugin.json"
assert_file_exists "plugin.json exists" "$PLUGIN_MANIFEST"
assert_json_valid "plugin.json is valid JSON" "$PLUGIN_MANIFEST"
assert_json_valid "settings.json is valid JSON" ".claude/settings.json"
assert_json_valid "checklist.json is valid JSON" "$P/templates/checklist.json"

# --- plugin.json required fields ---
PLUGIN_JSON=$(cat "$PLUGIN_MANIFEST")
assert_contains "plugin.json has author field" "$PLUGIN_JSON" '"author"'
assert_contains "plugin.json has repository field" "$PLUGIN_JSON" '"repository"'
assert_contains "plugin.json has license field" "$PLUGIN_JSON" '"license"'

# --- Plugin directory convention validation ---
# Skills: skills/<name>/SKILL.md
SKILLS=(quick standard full compare)
for skill in "${SKILLS[@]}"; do
    assert_file_exists "Skill: $skill/SKILL.md" "$P/skills/$skill/SKILL.md"
done

# Agents: agents/<name>.md
AGENTS=(collector safety-evaluator completeness-evaluator design-evaluator synthesizer)
for agent in "${AGENTS[@]}"; do
    assert_file_exists "Agent: $agent.md" "$P/agents/$agent.md"
done

# Commands: commands/<name>.md
assert_file_exists "Command: harness-eval.md" "$P/commands/harness-eval.md"

# Hooks: hooks/hooks.json + hook scripts
assert_file_exists "hooks/hooks.json exists" "$P/hooks/hooks.json"
assert_json_valid "hooks/hooks.json is valid JSON" "$P/hooks/hooks.json"
assert_file_exists "hooks/post-eval-badge.sh exists" "$P/hooks/post-eval-badge.sh"

# --- File existence ---
assert_file_exists "Plugin CLAUDE.md" "$P/CLAUDE.md"
assert_file_exists "docs/architecture.md" "$P/docs/architecture.md"
assert_file_exists "docs/onboarding.md" "$P/docs/onboarding.md"
assert_file_exists "docs/decisions/.template.md" "$P/docs/decisions/.template.md"
assert_file_exists "docs/runbooks/.template.md" "$P/docs/runbooks/.template.md"

# --- Script validation ---
SCRIPTS=(scoring static-analysis history badge setup install-hooks aggregate)
for script in "${SCRIPTS[@]}"; do
    assert_file_exists "scripts/$script.sh exists" "$P/scripts/$script.sh"
    assert_file_executable "scripts/$script.sh is executable" "$P/scripts/$script.sh"
    assert_bash_syntax "scripts/$script.sh valid bash" "$P/scripts/$script.sh"
done

# --- Plugin hook validation ---
assert_file_executable "hooks/post-eval-badge.sh is executable" "$P/hooks/post-eval-badge.sh"
assert_bash_syntax "hooks/post-eval-badge.sh valid bash" "$P/hooks/post-eval-badge.sh"

# --- Dev command frontmatter ---
for cmd in review test-all deploy; do
    if [ -f ".claude/commands/$cmd.md" ]; then
        CMD_CONTENT=$(cat ".claude/commands/$cmd.md")
        assert_contains "Command $cmd: has frontmatter" "$CMD_CONTENT" "description:"
        assert_contains "Command $cmd: has allowed-tools" "$CMD_CONTENT" "allowed-tools:"
    fi
done

# --- Agent and skill frontmatter ---
# Prints the YAML frontmatter block (lines between a leading '---' and the next '---').
# Prints nothing when line 1 is not '---'.
_structure_frontmatter() {
    awk 'NR == 1 { if ($0 != "---") exit; next } /^---[[:space:]]*$/ { exit } { print }' "$1"
}

# Claude Code loads subagents only from *.md files with YAML frontmatter; a .yml/.yaml
# agent definition is silently ignored, so it must not exist at all.
for agents_dir in ".claude/agents" "$P/agents"; do
    agents_label="${agents_dir#"$P"/}"
    AGENT_YAML=""
    if [ -d "$agents_dir" ]; then
        AGENT_YAML=$(find "$agents_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
    fi
    if [ -z "$AGENT_YAML" ]; then
        pass "$agents_label: no .yml/.yaml agent definitions (only .md agents are loaded)"
    else
        fail "$agents_label: no .yml/.yaml agent definitions (only .md agents are loaded)" "convert to .md with YAML frontmatter: $(echo "$AGENT_YAML" | tr '\n' ' ')"
    fi
done

# Prints a frontmatter value as model-config compares it: CR, a trailing " # comment",
# surrounding whitespace and quotes removed, lowercased, a trailing "[1m]" removed.
_structure_fm_value() {
    local v
    v=$(sed -nE "s/^$2:[[:space:]]*//p" <<< "$1" | head -1 | tr -d '\r')
    v="${v%%[[:space:]]#*}"
    v="${v%"${v##*[![:space:]]}"}"
    case "$v" in
        \"*\"|\'*\') v="${v:1:${#v}-2}" ;;
    esac
    v=$(tr '[:upper:]' '[:lower:]' <<< "$v")
    printf '%s' "${v%\[1m\]}"
}

# The accepted model and effort values come from static-analysis.sh's model tables, the one
# place they are kept current with each model release, so this test and model-config agree.
STRUCT_SA="$P/scripts/static-analysis.sh"
STRUCT_ALIASES=$(sed -nE 's/^MODEL_ALIASES=\((.*)\)$/\1/p' "$STRUCT_SA" | head -1)
STRUCT_EFFORTS=$(sed -nE 's/^FRONTMATTER_EFFORT_LEVELS=\((.*)\)$/\1/p' "$STRUCT_SA" | head -1)
STRUCT_ID_RE=$(sed -nE "s/^KNOWN_MODEL_ID_PATTERN='(.*)'\$/\1/p" "$STRUCT_SA" | head -1)

# Every agent (plugin and dev) pins its model and effort in frontmatter: without `effort`
# a subagent inherits the caller's session effort, so evaluation depth would vary by user.
# The values must be ones Claude Code accepts: it ignores an unknown effort such as "hgih",
# and a model ID that names no served model fails or is remapped, and either way the pin
# no longer sets what the agents table in CLAUDE.md says.
for agent_file in "$P"/agents/*.md .claude/agents/*.md; do
    [ -f "$agent_file" ] || continue
    agent_label="${agent_file#"$P"/}"
    AGENT_FM=$(_structure_frontmatter "$agent_file")
    MISSING_KEYS=""
    for key in name description model effort; do
        grep -qE "^${key}:[[:space:]]*[^[:space:]]" <<< "$AGENT_FM" || MISSING_KEYS="$MISSING_KEYS $key:"
    done
    if [ -z "$MISSING_KEYS" ]; then
        pass "Agent frontmatter: $agent_label has name/description/model/effort"
    else
        fail "Agent frontmatter: $agent_label has name/description/model/effort" "missing in YAML frontmatter:$MISSING_KEYS ($agent_file)"
    fi

    AGENT_MODEL=$(_structure_fm_value "$AGENT_FM" model)
    AGENT_EFFORT=$(_structure_fm_value "$AGENT_FM" effort)
    VALUE_PROBLEMS=""
    if [ -z "$STRUCT_ALIASES" ] || [ -z "$STRUCT_EFFORTS" ] || [ -z "$STRUCT_ID_RE" ]; then
        VALUE_PROBLEMS="; cannot read MODEL_ALIASES, FRONTMATTER_EFFORT_LEVELS or KNOWN_MODEL_ID_PATTERN from $STRUCT_SA"
    else
        if [ -n "$AGENT_MODEL" ] && ! grep -qxF -- "$AGENT_MODEL" <<< "$(tr ' ' '\n' <<< "$STRUCT_ALIASES")" \
            && ! [[ "$AGENT_MODEL" =~ $STRUCT_ID_RE ]]; then
            VALUE_PROBLEMS="$VALUE_PROBLEMS; model '$AGENT_MODEL' is neither an alias ($STRUCT_ALIASES) nor a served model ID"
        fi
        if [ -n "$AGENT_EFFORT" ] && ! [[ "$AGENT_EFFORT" =~ ^[0-9]+$ ]] \
            && ! grep -qxF -- "$AGENT_EFFORT" <<< "$(tr ' ' '\n' <<< "$STRUCT_EFFORTS")"; then
            VALUE_PROBLEMS="$VALUE_PROBLEMS; effort '$AGENT_EFFORT' is not one of $STRUCT_EFFORTS or an integer"
        fi
    fi
    if [ -z "$VALUE_PROBLEMS" ]; then
        pass "Agent frontmatter: $agent_label model and effort are values Claude Code accepts"
    else
        fail "Agent frontmatter: $agent_label model and effort are values Claude Code accepts" "${VALUE_PROBLEMS#; } ($agent_file)"
    fi
done

# The repo's own harness passes the model checks it applies to targets. static-analysis.sh on
# the repo root reads every plugin and dev agent, skill and command and the settings files.
# Results for .claude/settings.local.json are left out: it is gitignored and per developer.
STRUCT_SELF=$(HARNESS_EVAL_ROOT="$P" bash "$STRUCT_SA" "${REPO_ROOT:-.}" 2>/dev/null) || true
for _sa_id in model-config agent-format; do
    _sa_label="Self-check: static-analysis.sh $_sa_id is PASS on the repo root"
    _sa_bad=""
    if [ -n "$STRUCT_SELF" ]; then
        _sa_bad=$(jq -r --arg id "$_sa_id" '
            [.checks[] | select(.id == $id and .file != ".claude/settings.local.json")] as $c
            | if ($c | length) == 0 then "no \($id) result"
              else [$c[] | select(.status != "PASS") | "\(.status): \(.details)"] | join("; ") end' \
            <<< "$STRUCT_SELF" 2>/dev/null) || _sa_bad="static-analysis.sh output is not JSON"
    else
        _sa_bad="static-analysis.sh printed nothing for the repo root"
    fi
    if [ -z "$_sa_bad" ]; then pass "$_sa_label"; else fail "$_sa_label" "$_sa_bad"; fi
done

# Dev skills need a frontmatter description, otherwise the H1 becomes the routing text.
for skill_file in .claude/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    SKILL_FM=$(_structure_frontmatter "$skill_file")
    if grep -qE '^description:[[:space:]]*[^[:space:]]' <<< "$SKILL_FM"; then
        pass "Dev skill frontmatter: $skill_file has description"
    else
        fail "Dev skill frontmatter: $skill_file has description" "missing 'description:' in YAML frontmatter"
    fi
done

# --- CLAUDE.md content ---
SECTIONS=("Overview" "Tech Stack" "Project Structure" "Conventions" "Key Commands" "Auto-Sync Rules")
for section in "${SECTIONS[@]}"; do
    grep -qF "## $section" "$P/CLAUDE.md" && pass "CLAUDE.md: has $section" || fail "CLAUDE.md: has $section" "not found"
done

# --- Module CLAUDE.md coverage ---
# commands/ and agents/ must NOT contain a CLAUDE.md: Claude Code auto-discovers every
# *.md under commands/ and agents/ as a component, so a CLAUDE.md there registers a bogus
# command/agent (decision #8). Their module notes now live in the plugin-root CLAUDE.md.
# The remaining module dirs are not scanned for components, so they keep their CLAUDE.md.
MODULE_DIRS=(scripts skills hooks templates tests)
for dir in "${MODULE_DIRS[@]}"; do
    assert_file_exists "$dir/CLAUDE.md exists" "$P/$dir/CLAUDE.md"
done

for dir in commands agents; do
    if [ ! -f "$P/$dir/CLAUDE.md" ]; then
        pass "$dir/CLAUDE.md absent (avoids auto-discovery pollution)"
    else
        fail "$dir/CLAUDE.md absent (avoids auto-discovery pollution)" "$P/$dir/CLAUDE.md must be removed; move its notes into the plugin-root CLAUDE.md"
    fi
done

# --- Version consistency across manifests ---
# marketplace.json metadata.version, marketplace.json plugins[0].version, and
# plugin.json version must all agree so an install pins a single coherent version.
MARKETPLACE_MANIFEST=".claude-plugin/marketplace.json"
if [ -f "$MARKETPLACE_MANIFEST" ] && [ -f "$PLUGIN_MANIFEST" ]; then
    MP_META_VER=$(jq -r '.metadata.version // "MISSING"' "$MARKETPLACE_MANIFEST" 2>/dev/null || echo "MISSING")
    MP_PLUGIN_VER=$(jq -r '.plugins[0].version // "MISSING"' "$MARKETPLACE_MANIFEST" 2>/dev/null || echo "MISSING")
    PLUGIN_VER=$(jq -r '.version // "MISSING"' "$PLUGIN_MANIFEST" 2>/dev/null || echo "MISSING")
    assert_eq "version: marketplace.metadata.version == plugins[0].version" "$MP_META_VER" "$MP_PLUGIN_VER"
    assert_eq "version: marketplace plugins[0].version == plugin.json version" "$MP_PLUGIN_VER" "$PLUGIN_VER"
else
    fail "version consistency" "marketplace.json or plugin.json manifest not found"
fi

# --- Full-mode string contracts ---
# skills/full/SKILL.md and the agents it dispatches hand results to each other as marker
# lines and tables that the receiving side matches by exact string. A rename on one side
# still reads fine as prose, but at run time the other side misses the result: a dimension
# goes silently null or a fallback fires. So each check greps only the exact token, on both
# the producing and the consuming side, and the prose around the tokens can change freely.
FULL_SKILL="$P/skills/full/SKILL.md"
FULL_COLLECTOR="$P/agents/collector.md"
FULL_SYNTH="$P/agents/synthesizer.md"

# Records one check: pass when the accumulated problem list ("; a; b") is empty.
_structure_report() {
    if [ -z "$2" ]; then pass "$1"; else fail "$1" "${2#; }"; fi
}

# _structure_has_tokens <file> <token>...: one check that <file> contains every fixed-string token.
_structure_has_tokens() {
    local file="$1" token problems="" label
    shift
    label="Full contract: ${file#"$P"/} has"
    for token in "$@"; do
        label="$label '$token'"
        grep -qF -- "$token" "$file" 2>/dev/null || problems="$problems; '$token' not found in $file"
    done
    _structure_report "$label" "$problems"
}

# Prints the table rows (lines starting with '|') under the first '## Scores' heading.
_structure_scores_rows() {
    awk '/^## Scores[ \t]*$/ { in_t = 1; next } in_t && /^## / { exit } in_t && /^\|/ { print }' "$1"
}

# stdin: table rows. Prints the first-column cells, without the header and separator rows.
_structure_scores_names() {
    awk -F'|' '{ c = $2; gsub(/^[ \t]+|[ \t]+$/, "", c)
                 if (c != "" && c != "Dimension" && c !~ /^:?-+:?$/) print c }'
}

# Dimension display name -> aggregate.sh key: "Contract-Based Testing" -> contractBasedTesting.
_structure_camel() {
    awk '{ out = ""; n = split($0, w, /[^A-Za-z0-9]+/)
           for (i = 1; i <= n; i++) {
               if (w[i] == "") continue
               if (out == "") out = tolower(w[i])
               else out = out toupper(substr(w[i], 1, 1)) tolower(substr(w[i], 2))
           }
           print out }' <<< "$1"
}

# Collector -> orchestrator: the line the orchestrator waits for before starting Phase 2.
_structure_has_tokens "$FULL_COLLECTOR" "ARTIFACT_WRITTEN:"
_structure_has_tokens "$FULL_SKILL" "ARTIFACT_WRITTEN:"

# Synthesizer -> orchestrator: the final-message lines Phase 4 parses. Each must start a line
# in the synthesizer's template and in the orchestrator's copy of it; NOTE: is optional.
for _full_f in "$FULL_SYNTH" "$FULL_SKILL"; do
    _full_problems=""
    for _full_key in EVAL_ID REPORT_EN REPORT_KO SCORE MISSING; do
        grep -qE "^[[:space:]]*${_full_key}: " "$_full_f" 2>/dev/null \
            || _full_problems="$_full_problems; no line starts with '$_full_key: ' in $_full_f"
    done
    _structure_report "Full contract: ${_full_f#"$P"/} has the EVAL_ID/REPORT_EN/REPORT_KO/SCORE/MISSING lines" "$_full_problems"
    _structure_has_tokens "$_full_f" "NOTE:"
done

# Orchestrator -> agents: failure markers that stand in for a missing input. The orchestrator
# emits SCRIPT_FAILED for each Phase 1 script and AGENT_FAILED for each evaluator; the
# evaluators handle SCRIPT_FAILED, and the synthesizer handles both.
_structure_has_tokens "$FULL_SKILL" \
    "SCRIPT_FAILED: static-analysis.sh produced no output" "SCRIPT_FAILED: scoring.sh produced no output"
_full_problems=""
_full_evaluators=0
for _full_f in "$P"/agents/*-evaluator.md; do
    [ -f "$_full_f" ] || continue
    _full_evaluators=$((_full_evaluators + 1))
    _full_token="AGENT_FAILED: $(basename "$_full_f" .md)"
    grep -qF -- "$_full_token" "$FULL_SKILL" 2>/dev/null || _full_problems="$_full_problems; '$_full_token' not found"
done
[ "$_full_evaluators" -gt 0 ] || _full_problems="no agents/*-evaluator.md found"
_structure_report "Full contract: skills/full/SKILL.md has an AGENT_FAILED marker per evaluator" "$_full_problems"
_structure_has_tokens "$FULL_SYNTH" "AGENT_FAILED:" "SCRIPT_FAILED:"
for _full_f in "$P"/agents/*-evaluator.md; do
    [ -f "$_full_f" ] || continue
    _structure_has_tokens "$_full_f" "SCRIPT_FAILED:"
done

# Orchestrator -> agents: every subagent_type the Full skill dispatches names a plugin agent,
# and every plugin agent (agents/ holds only the Full-mode agents) is dispatched under its
# frontmatter name.
FULL_DISPATCHED=$(grep -F 'subagent_type' "$FULL_SKILL" 2>/dev/null \
    | grep -oE 'harness-eval:[a-z][a-z0-9-]*' | sed 's/^harness-eval://' | sort -u)
_full_problems=""
[ -n "$FULL_DISPATCHED" ] || _full_problems="no 'harness-eval:<agent>' subagent_type found"
while IFS= read -r _full_name; do
    [ -n "$_full_name" ] || continue
    [ -f "$P/agents/$_full_name.md" ] || _full_problems="$_full_problems; harness-eval:$_full_name has no agents/$_full_name.md"
done <<< "$FULL_DISPATCHED"
_structure_report "Full contract: each subagent_type in skills/full/SKILL.md names a plugin agent" "$_full_problems"
for _full_f in "$P"/agents/*.md; do
    [ -f "$_full_f" ] || continue
    _full_base=$(basename "$_full_f" .md)
    _full_name=$(_structure_frontmatter "$_full_f" | sed -nE 's/^name:[[:space:]]*//p' | head -1 | tr -d "\"' \t\r")
    _full_problems=""
    [ "$_full_name" = "$_full_base" ] || _full_problems="frontmatter name '$_full_name' differs from the file name"
    grep -qxF -- "$_full_base" <<< "$FULL_DISPATCHED" \
        || _full_problems="$_full_problems; skills/full/SKILL.md has no subagent_type harness-eval:$_full_base"
    _structure_report "Full contract: ${_full_f#"$P"/} is dispatched as harness-eval:$_full_base" "$_full_problems"
done

# Synthesizer -> aggregate.sh: the camelCase keys in the synthesizer's heredoc are exactly the
# keys aggregate.sh scores. Checked by running aggregate.sh on them rather than reading its
# source: an unknown key is rejected (exit 2), a missing key shows up in .dimensions.
_structure_has_tokens "$FULL_SYNTH" "## Scores" "Score (0-10)"
FULL_SYN_KEYS=$(grep -oE '"[a-zA-Z]+": <' "$FULL_SYNTH" 2>/dev/null | sed -E 's/^"([a-zA-Z]+)".*/\1/' | sort)
if [ -z "$FULL_SYN_KEYS" ]; then
    fail "Full contract: synthesizer heredoc keys == aggregate.sh dimension keys" "no '\"<key>\": <score>' entries found in $FULL_SYNTH"
else
    FULL_AGG_INPUT=$(printf '%s\n' "$FULL_SYN_KEYS" | jq -Rn '{dimensions: ([inputs | {(.): 5}] | add)}')
    if FULL_AGG_OUT=$(printf '%s' "$FULL_AGG_INPUT" | bash "$P/scripts/aggregate.sh" 2>/dev/null); then
        FULL_AGG_KEYS=$(jq -r '.dimensions | keys[]' <<< "$FULL_AGG_OUT" 2>/dev/null | sort)
        assert_eq "Full contract: synthesizer heredoc keys == aggregate.sh dimension keys" \
            "$(echo "$FULL_AGG_KEYS" | tr '\n' ' ')" "$(echo "$FULL_SYN_KEYS" | tr '\n' ' ')"
    else
        FULL_AGG_ERR=$(printf '%s' "$FULL_AGG_INPUT" | bash "$P/scripts/aggregate.sh" 2>&1 >/dev/null | tr '\n' ' ')
        fail "Full contract: synthesizer heredoc keys == aggregate.sh dimension keys" "aggregate.sh rejected them: $FULL_AGG_ERR"
    fi
fi

# Evaluators -> synthesizer: the synthesizer takes each score from the "Score (0-10)" column of
# the evaluator's "## Scores" table, by dimension name, and passes it on under the matching
# heredoc key. Every name must appear in synthesizer.md and name a heredoc key.
FULL_EVAL_KEYS=""
for _full_f in "$P"/agents/*-evaluator.md; do
    [ -f "$_full_f" ] || continue
    _full_rows=$(_structure_scores_rows "$_full_f")
    _full_names=$(_structure_scores_names <<< "$_full_rows")
    _full_problems=""
    grep -qF 'Score (0-10)' <<< "${_full_rows%%$'\n'*}" || _full_problems="the '## Scores' header row has no 'Score (0-10)' column"
    [ -n "$_full_names" ] || _full_problems="$_full_problems; no dimension rows under '## Scores'"
    while IFS= read -r _full_name; do
        [ -n "$_full_name" ] || continue
        _full_key=$(_structure_camel "$_full_name")
        FULL_EVAL_KEYS="$FULL_EVAL_KEYS$_full_key"$'\n'
        grep -qF -- "$_full_name" "$FULL_SYNTH" || _full_problems="$_full_problems; '$_full_name' not found in synthesizer.md"
        grep -qxF -- "$_full_key" <<< "$FULL_SYN_KEYS" || _full_problems="$_full_problems; '$_full_name' ($_full_key) is not a synthesizer heredoc key"
    done <<< "$_full_names"
    _structure_report "Full contract: ${_full_f#"$P"/} '## Scores' dimensions match synthesizer.md" "$_full_problems"
done

# Every dimension has a source: the four Basic Quality keys come from static-analysis.sh
# (.categories.<key>.score, read under the same key), and the rest from an evaluator table.
# Otherwise that dimension would be null in every Full run.
FULL_STATIC_KEYS=$(HARNESS_EVAL_ROOT="$P" bash "$P/scripts/static-analysis.sh" "$P/tests/fixtures/minimal-project" 2>/dev/null \
    | jq -r '(.categories // {}) | keys[]' 2>/dev/null | sort)
_full_problems=""
[ -n "$FULL_STATIC_KEYS" ] || _full_problems="static-analysis.sh printed no .categories keys for fixtures/minimal-project"
while IFS= read -r _full_key; do
    [ -n "$_full_key" ] || continue
    grep -qxF -- "$_full_key" <<< "$FULL_SYN_KEYS" || _full_problems="$_full_problems; category '$_full_key' is not a synthesizer heredoc key"
done <<< "$FULL_STATIC_KEYS"
_structure_report "Full contract: static-analysis.sh categories are synthesizer heredoc keys" "$_full_problems"
_full_problems=""
while IFS= read -r _full_key; do
    [ -n "$_full_key" ] || continue
    grep -qxF -- "$_full_key" <<< "$FULL_STATIC_KEYS"$'\n'"$FULL_EVAL_KEYS" \
        || _full_problems="$_full_problems; '$_full_key' has no static-analysis category or evaluator '## Scores' row"
done <<< "$FULL_SYN_KEYS"
[ -n "$FULL_SYN_KEYS" ] || _full_problems="no synthesizer heredoc keys to check"
_structure_report "Full contract: every synthesizer heredoc key has a producer" "$_full_problems"
