#!/bin/bash
# Validates plugin structure integrity: manifests, file existence, CLAUDE.md sections.

# --- Manifest validation ---
PLUGIN_MANIFEST=".claude-plugin/plugin.json"
assert_file_exists ".claude-plugin/plugin.json exists" "$PLUGIN_MANIFEST"
assert_json_valid "plugin.json is valid JSON" "$PLUGIN_MANIFEST"
assert_json_valid "settings.json is valid JSON" ".claude/settings.json"
assert_json_valid "checklist.json is valid JSON" "templates/checklist.json"

# --- plugin.json required fields ---
PLUGIN_JSON=$(cat "$PLUGIN_MANIFEST")
assert_contains "plugin.json has author field" "$PLUGIN_JSON" '"author"'
assert_contains "plugin.json has repository field" "$PLUGIN_JSON" '"repository"'
assert_contains "plugin.json has license field" "$PLUGIN_JSON" '"license"'

# --- Plugin directory convention validation ---
# Skills: skills/<name>/SKILL.md
SKILLS=(quick standard full compare)
for skill in "${SKILLS[@]}"; do
    assert_file_exists "Skill: skills/$skill/SKILL.md" "skills/$skill/SKILL.md"
done

# Agents: agents/<name>.md
AGENTS=(collector safety-evaluator completeness-evaluator design-evaluator synthesizer)
for agent in "${AGENTS[@]}"; do
    assert_file_exists "Agent: agents/$agent.md" "agents/$agent.md"
done

# Commands: commands/<name>.md
assert_file_exists "Command: commands/harness-eval.md" "commands/harness-eval.md"

# Hooks: hooks/hooks.json + hook scripts
assert_file_exists "hooks/hooks.json exists" "hooks/hooks.json"
assert_json_valid "hooks/hooks.json is valid JSON" "hooks/hooks.json"
assert_file_exists "hooks/post-eval-badge.sh exists" "hooks/post-eval-badge.sh"

# --- File existence ---
assert_file_exists "Root CLAUDE.md" "CLAUDE.md"
assert_file_exists "docs/architecture.md" "docs/architecture.md"
assert_file_exists "docs/onboarding.md" "docs/onboarding.md"
assert_file_exists "docs/decisions/.template.md" "docs/decisions/.template.md"
assert_file_exists "docs/runbooks/.template.md" "docs/runbooks/.template.md"

# --- Script validation ---
SCRIPTS=(scoring static-analysis history badge setup install-hooks)
for script in "${SCRIPTS[@]}"; do
    assert_file_exists "scripts/$script.sh exists" "scripts/$script.sh"
    assert_file_executable "scripts/$script.sh is executable" "scripts/$script.sh"
    assert_bash_syntax "scripts/$script.sh valid bash" "scripts/$script.sh"
done

# --- Plugin hook validation ---
assert_file_exists "hooks/post-eval-badge.sh" "hooks/post-eval-badge.sh"
assert_file_executable "hooks/post-eval-badge.sh is executable" "hooks/post-eval-badge.sh"
assert_bash_syntax "hooks/post-eval-badge.sh valid bash" "hooks/post-eval-badge.sh"

# --- Command frontmatter ---
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
    grep -qF "## $section" CLAUDE.md && pass "CLAUDE.md: has $section" || fail "CLAUDE.md: has $section" "not found"
done

# --- Module CLAUDE.md coverage ---
MODULE_DIRS=(scripts agents skills commands hooks templates tests)
for dir in "${MODULE_DIRS[@]}"; do
    assert_file_exists "$dir/CLAUDE.md exists" "$dir/CLAUDE.md"
done
