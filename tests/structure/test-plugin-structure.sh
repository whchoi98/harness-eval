#!/bin/bash
# Validates plugin structure integrity: manifests, file existence, CLAUDE.md sections.

# --- Manifest validation ---
assert_json_valid "plugin.json is valid JSON" "plugin.json"
assert_json_valid "settings.json is valid JSON" ".claude/settings.json"
assert_json_valid "checklist.json is valid JSON" "templates/checklist.json"

# --- plugin.json path validation ---
PLUGIN_JSON=$(cat plugin.json)

# Check all skill paths exist
for skill_path in $(python3 -c "import json; [print(s['path']) for s in json.load(open('plugin.json')).get('skills',[])]" 2>/dev/null); do
    assert_file_exists "Skill path: $skill_path" "$skill_path"
done

# Check all agent paths exist
for agent_path in $(python3 -c "import json; [print(a['path']) for a in json.load(open('plugin.json')).get('agents',[])]" 2>/dev/null); do
    assert_file_exists "Agent path: $agent_path" "$agent_path"
done

# Check all command paths exist
for cmd_path in $(python3 -c "import json; [print(c['path']) for c in json.load(open('plugin.json')).get('commands',[])]" 2>/dev/null); do
    assert_file_exists "Command path: $cmd_path" "$cmd_path"
done

# Check all hook paths exist
for hook_path in $(python3 -c "import json; [print(h['path']) for h in json.load(open('plugin.json')).get('hooks',[])]" 2>/dev/null); do
    assert_file_exists "Hook path: $hook_path" "$hook_path"
done

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
