#!/bin/bash
# Validates plugin structure integrity: manifests, file existence, CLAUDE.md sections.
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
SCRIPTS=(scoring static-analysis history badge setup install-hooks)
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

# --- CLAUDE.md content ---
SECTIONS=("Overview" "Tech Stack" "Project Structure" "Conventions" "Key Commands" "Auto-Sync Rules")
for section in "${SECTIONS[@]}"; do
    grep -qF "## $section" "$P/CLAUDE.md" && pass "CLAUDE.md: has $section" || fail "CLAUDE.md: has $section" "not found"
done

# --- Module CLAUDE.md coverage ---
MODULE_DIRS=(scripts agents skills commands hooks templates tests)
for dir in "${MODULE_DIRS[@]}"; do
    assert_file_exists "$dir/CLAUDE.md exists" "$P/$dir/CLAUDE.md"
done
