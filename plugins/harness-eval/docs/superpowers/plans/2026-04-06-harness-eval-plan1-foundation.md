# harness-eval Plan 1: Foundation + Quick Flow

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the plugin skeleton, checklist engine, scoring script, Quick evaluation skill, and fixture-based tests so that `/harness-eval quick` produces a working score.

**Architecture:** Bottom-up build — checklist.json defines what to check, scoring.sh runs checks and computes weighted scores, skills/quick.md orchestrates the user-facing flow. All deterministic (no agents). Fixture projects at 4 maturity levels validate scoring accuracy.

**Tech Stack:** Bash 4.0+, jq, Markdown (skills/templates)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `plugin.json` | Plugin manifest — registers skills, agents, commands, hooks |
| `CLAUDE.md` | Plugin-level context for Claude sessions |
| `templates/checklist.json` | Check definitions: 4 tiers, 10 check types, ~20 items |
| `scripts/scoring.sh` | Checklist engine: loads checklist.json, runs checks, computes weighted score |
| `skills/quick.md` | User-facing Quick evaluation skill |
| `tests/test-scoring.sh` | Tests for scoring.sh against fixtures |
| `tests/fixtures/minimal-project/` | Mock project scoring ~6.0 |
| `tests/fixtures/functional-project/` | Mock project scoring ~7.0 |
| `tests/fixtures/robust-project/` | Mock project scoring ~8.0 |
| `tests/fixtures/production-project/` | Mock project scoring ~9.0 |

---

### Task 1: Plugin Skeleton

**Files:**
- Create: `plugin.json`
- Create: `CLAUDE.md`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "harness-eval",
  "version": "0.1.0",
  "description": "Evaluate Claude Code harness engineering quality. Quick/Standard/Full 3-tier evaluation with multi-agent design review, history tracking, and badge generation.",
  "skills": [
    { "name": "quick", "path": "skills/quick.md" },
    { "name": "standard", "path": "skills/standard.md" },
    { "name": "full", "path": "skills/full.md" },
    { "name": "compare", "path": "skills/compare.md" }
  ],
  "agents": [
    { "name": "collector", "path": "agents/collector.md" },
    { "name": "safety-evaluator", "path": "agents/safety-evaluator.md" },
    { "name": "completeness-evaluator", "path": "agents/completeness-evaluator.md" },
    { "name": "design-evaluator", "path": "agents/design-evaluator.md" },
    { "name": "synthesizer", "path": "agents/synthesizer.md" }
  ],
  "commands": [
    { "name": "harness-eval", "path": "commands/harness-eval.md" }
  ],
  "hooks": [
    { "event": "Stop", "path": "hooks/post-eval-badge.sh" }
  ]
}
```

- [ ] **Step 2: Create CLAUDE.md**

```markdown
# harness-eval Plugin

Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하는 플러그인.

## Architecture

- **3-tier evaluation**: Quick (checklist) → Standard (static+dynamic) → Full (multi-agent)
- **Hybrid**: Deterministic scripts for quantitative checks, agent prompts for qualitative review
- **Generation/Evaluation separation**: Full mode uses separate collector, evaluator, and synthesizer agents

## Key Paths

- `scripts/` — Bash scripts (scoring.sh, static-analysis.sh, history.sh, badge.sh)
- `templates/checklist.json` — Check definitions for Quick/Standard modes
- `skills/` — User-facing evaluation skills (quick, standard, full, compare)
- `agents/` — Subagents for Full mode evaluation
- `tests/fixtures/` — Mock projects at 4 maturity levels for testing

## Conventions

- All scripts: `$1` = target project root, `HARNESS_EVAL_ROOT` env var = plugin root
- Script output: JSON to stdout, human logs to stderr
- Exit codes: 0 = success, 1 = issues found, 2 = script error
- All scripts check for `jq` dependency at startup
```

- [ ] **Step 3: Create placeholder files for unimplemented components**

Create empty placeholder files so plugin.json references don't break:

```bash
mkdir -p skills agents commands hooks
touch skills/standard.md skills/full.md skills/compare.md
touch agents/collector.md agents/safety-evaluator.md agents/completeness-evaluator.md agents/design-evaluator.md agents/synthesizer.md
touch commands/harness-eval.md
touch hooks/post-eval-badge.sh
```

Each placeholder should contain a single line:
```markdown
<!-- TODO: Implemented in Plan 2/3 -->
```

- [ ] **Step 4: Validate plugin.json**

Run: `cat plugin.json | python3 -m json.tool > /dev/null && echo "VALID" || echo "INVALID"`
Expected: `VALID`

- [ ] **Step 5: Commit**

```bash
git add plugin.json CLAUDE.md skills/ agents/ commands/ hooks/
git commit -m "feat: add plugin skeleton with manifest and placeholders"
```

---

### Task 2: Checklist Definition

**Files:**
- Create: `templates/checklist.json`

- [ ] **Step 1: Create templates directory**

```bash
mkdir -p templates
```

- [ ] **Step 2: Create checklist.json**

```json
{
  "version": "1.0",
  "tiers": {
    "basic": {
      "label": "Basic (6.0+)",
      "weight": 1.0,
      "items": [
        {
          "id": "basic-claude-md",
          "description": "CLAUDE.md exists",
          "type": "file_exists",
          "target": "CLAUDE.md"
        },
        {
          "id": "basic-settings",
          "description": ".claude/settings.json or .claude/settings.local.json exists",
          "type": "file_exists_any",
          "targets": [".claude/settings.json", ".claude/settings.local.json"]
        },
        {
          "id": "basic-hook-registered",
          "description": "At least 1 hook registered in settings",
          "type": "json_array_min",
          "target": ".claude/settings.json",
          "path": ".hooks",
          "min": 1
        },
        {
          "id": "basic-command-exists",
          "description": "At least 1 command file exists",
          "type": "glob_min",
          "target": ".claude/commands/*.md",
          "min": 1
        }
      ]
    },
    "functional": {
      "label": "Functional (7.0+)",
      "weight": 1.5,
      "items": [
        {
          "id": "func-hook-events",
          "description": "All 4 hook events registered (PreToolUse, PostToolUse, PreCommit, Notification or Stop)",
          "type": "json_keys_present",
          "target": ".claude/settings.json",
          "path": ".hooks",
          "keys": ["PreToolUse", "PostToolUse"]
        },
        {
          "id": "func-secret-scanning",
          "description": "Secret scanning hook exists",
          "type": "grep_match",
          "target": ".claude/settings.json",
          "pattern": "secret|AKIA|password|token"
        },
        {
          "id": "func-skills",
          "description": "At least 2 skill files exist",
          "type": "glob_min",
          "target": ".claude/skills/*.md",
          "min": 2
        },
        {
          "id": "func-agent",
          "description": "At least 1 agent file exists",
          "type": "glob_min",
          "target": ".claude/agents/*.md",
          "min": 1
        }
      ]
    },
    "robust": {
      "label": "Robust (8.0+)",
      "weight": 2.0,
      "items": [
        {
          "id": "robust-tests",
          "description": "Automated test directory exists with test files",
          "type": "glob_min",
          "target": "tests/**/*test*",
          "min": 1
        },
        {
          "id": "robust-error-recovery",
          "description": "Commands contain error recovery sections",
          "type": "grep_all_files",
          "target": ".claude/commands/*.md",
          "pattern": "[Ff]ail|[Ee]rror|[Rr]ollback|[Rr]ecovery"
        },
        {
          "id": "robust-agent-schema",
          "description": "Agents define output schema or format",
          "type": "grep_all_files",
          "target": ".claude/agents/*.md",
          "pattern": "[Oo]utput|[Ff]ormat|[Ss]chema|[Vv]erdict"
        },
        {
          "id": "robust-deny-list",
          "description": "Deny list configured in settings",
          "type": "json_field_exists",
          "target": ".claude/settings.json",
          "path": ".permissions.deny"
        },
        {
          "id": "robust-module-claude-md",
          "description": "Module-level CLAUDE.md files exist (at least 2 total)",
          "type": "glob_min",
          "target": "**/CLAUDE.md",
          "min": 2
        }
      ]
    },
    "production": {
      "label": "Production (9.0+)",
      "weight": 2.5,
      "items": [
        {
          "id": "prod-e2e-tests",
          "description": "E2E or integration test files exist",
          "type": "glob_min",
          "target": "tests/**/*{e2e,integration,integ}*",
          "min": 1
        },
        {
          "id": "prod-ci-cd",
          "description": "CI/CD pipeline config exists",
          "type": "file_exists_any",
          "targets": [".github/workflows/*.yml", ".github/workflows/*.yaml", ".gitlab-ci.yml", "Jenkinsfile"]
        },
        {
          "id": "prod-migration-guide",
          "description": "Migration or upgrade guide exists",
          "type": "grep_match",
          "target": "*.md",
          "pattern": "[Mm]igrat|[Uu]pgrad|[Cc]hangelog|CHANGELOG"
        }
      ]
    }
  }
}
```

- [ ] **Step 3: Validate checklist.json**

Run: `cat templates/checklist.json | python3 -m json.tool > /dev/null && echo "VALID" || echo "INVALID"`
Expected: `VALID`

- [ ] **Step 4: Commit**

```bash
git add templates/checklist.json
git commit -m "feat: add checklist definition with 4 tiers and 16 check items"
```

---

### Task 3: Test Fixtures — Minimal Project

**Files:**
- Create: `tests/fixtures/minimal-project/.claude/settings.local.json`
- Create: `tests/fixtures/minimal-project/CLAUDE.md`

A minimal project has only the "basic" tier partially covered: CLAUDE.md exists, settings exists, but no hooks registered and no commands. Expected score: ~5.0-6.5.

- [ ] **Step 1: Create minimal fixture**

```bash
mkdir -p tests/fixtures/minimal-project/.claude
```

Create `tests/fixtures/minimal-project/CLAUDE.md`:
```markdown
# Minimal Project
A basic project with minimal harness setup.
```

Create `tests/fixtures/minimal-project/.claude/settings.local.json`:
```json
{
  "permissions": {
    "allow": []
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add tests/fixtures/minimal-project/
git commit -m "test: add minimal-project fixture (~6.0 tier)"
```

---

### Task 4: Test Fixtures — Functional Project

**Files:**
- Create: `tests/fixtures/functional-project/` (full structure)

A functional project passes all basic + most functional checks. Expected score: ~6.5-7.5.

- [ ] **Step 1: Create functional fixture**

```bash
mkdir -p tests/fixtures/functional-project/.claude/{commands,skills,agents,hooks}
```

Create `tests/fixtures/functional-project/CLAUDE.md`:
```markdown
# Functional Project
A project with functional harness setup including hooks, skills, and commands.
```

Create `tests/fixtures/functional-project/.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "command": ".claude/hooks/check-safety.sh" }
    ],
    "PostToolUse": [
      { "matcher": "Write", "command": ".claude/hooks/check-secrets.sh" }
    ]
  },
  "permissions": {
    "allow": ["Read", "Glob", "Grep"]
  }
}
```

Create `tests/fixtures/functional-project/.claude/hooks/check-safety.sh`:
```bash
#!/usr/bin/env bash
# Safety check hook
echo "checking safety..."
```

Create `tests/fixtures/functional-project/.claude/hooks/check-secrets.sh`:
```bash
#!/usr/bin/env bash
# Secret scanning hook - checks for AKIA patterns and tokens
input=$(cat)
if echo "$input" | grep -qP 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: AWS key detected"
  exit 1
fi
```

Create `tests/fixtures/functional-project/.claude/commands/review.md`:
```markdown
Review the current changes for quality issues.
```

Create `tests/fixtures/functional-project/.claude/skills/code-style.md`:
```markdown
---
description: Enforce code style conventions
---
Follow the project's code style guidelines.
```

Create `tests/fixtures/functional-project/.claude/skills/testing.md`:
```markdown
---
description: Guide test writing
---
Write tests following project conventions.
```

Create `tests/fixtures/functional-project/.claude/agents/reviewer.md`:
```markdown
---
description: Code review agent
allowed-tools: Read, Glob, Grep
---
Review code for quality issues.
```

- [ ] **Step 2: Make hooks executable**

```bash
chmod +x tests/fixtures/functional-project/.claude/hooks/*.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/fixtures/functional-project/
git commit -m "test: add functional-project fixture (~7.0 tier)"
```

---

### Task 5: Test Fixtures — Robust and Production Projects

**Files:**
- Create: `tests/fixtures/robust-project/` (full structure)
- Create: `tests/fixtures/production-project/` (full structure)

- [ ] **Step 1: Create robust fixture**

```bash
mkdir -p tests/fixtures/robust-project/.claude/{commands,skills,agents,hooks}
mkdir -p tests/fixtures/robust-project/tests
mkdir -p tests/fixtures/robust-project/src
```

Create `tests/fixtures/robust-project/CLAUDE.md`:
```markdown
# Robust Project
A project with robust harness including tests, deny lists, and error recovery.
```

Create `tests/fixtures/robust-project/src/CLAUDE.md`:
```markdown
# Source Module
Source code conventions and patterns.
```

Create `tests/fixtures/robust-project/.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "command": ".claude/hooks/check-safety.sh" }
    ],
    "PostToolUse": [
      { "matcher": "Write", "command": ".claude/hooks/check-secrets.sh" }
    ]
  },
  "permissions": {
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Bash(rm -rf:*)", "Bash(git push --force:*)", "Bash(eval:*)"]
  }
}
```

Create `tests/fixtures/robust-project/.claude/hooks/check-safety.sh`:
```bash
#!/usr/bin/env bash
echo "checking safety..."
```

Create `tests/fixtures/robust-project/.claude/hooks/check-secrets.sh`:
```bash
#!/usr/bin/env bash
input=$(cat)
if echo "$input" | grep -qP 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: AWS key detected"
  exit 1
fi
```

Create `tests/fixtures/robust-project/.claude/commands/deploy.md`:
```markdown
Deploy the application.

## Error Recovery

If deployment fails:
1. Check the deployment logs
2. Rollback to the previous version
3. Investigate the root cause
```

Create `tests/fixtures/robust-project/.claude/skills/code-style.md`:
```markdown
---
description: Code style enforcement
---
Follow code style conventions.
```

Create `tests/fixtures/robust-project/.claude/skills/testing.md`:
```markdown
---
description: Test writing guide
---
Write tests following conventions.
```

Create `tests/fixtures/robust-project/.claude/agents/reviewer.md`:
```markdown
---
description: Code review agent
allowed-tools: Read, Glob, Grep
---

## Output Format

| Check | Verdict | Detail |
|-------|---------|--------|
| Style | PASS/WARN/FAIL | ... |
```

Create `tests/fixtures/robust-project/tests/test-example.sh`:
```bash
#!/usr/bin/env bash
echo "PASS: example test"
```

- [ ] **Step 2: Create production fixture**

```bash
mkdir -p tests/fixtures/production-project/.claude/{commands,skills,agents,hooks}
mkdir -p tests/fixtures/production-project/{tests,src,docs}
mkdir -p tests/fixtures/production-project/.github/workflows
```

Create `tests/fixtures/production-project/CLAUDE.md`:
```markdown
# Production Project
A production-grade project with full harness, CI/CD, and migration guides.
```

Create `tests/fixtures/production-project/src/CLAUDE.md`:
```markdown
# Source Module
Source code conventions.
```

Create `tests/fixtures/production-project/docs/CLAUDE.md`:
```markdown
# Docs Module
Documentation conventions.
```

Create `tests/fixtures/production-project/.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "command": ".claude/hooks/check-safety.sh" }
    ],
    "PostToolUse": [
      { "matcher": "Write", "command": ".claude/hooks/check-secrets.sh" }
    ]
  },
  "permissions": {
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Bash(rm -rf:*)", "Bash(git push --force:*)", "Bash(eval:*)"]
  }
}
```

Create `tests/fixtures/production-project/.claude/hooks/check-safety.sh`:
```bash
#!/usr/bin/env bash
echo "checking safety..."
```

Create `tests/fixtures/production-project/.claude/hooks/check-secrets.sh`:
```bash
#!/usr/bin/env bash
input=$(cat)
if echo "$input" | grep -qP 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: AWS key detected"
  exit 1
fi
```

Create `tests/fixtures/production-project/.claude/commands/deploy.md`:
```markdown
Deploy the application.

## Error Recovery

If deployment fails:
1. Rollback with `git revert`
2. Check CI logs
```

Create `tests/fixtures/production-project/.claude/skills/code-style.md`:
```markdown
---
description: Code style enforcement
---
Follow code style conventions.
```

Create `tests/fixtures/production-project/.claude/skills/testing.md`:
```markdown
---
description: Test guide
---
Write tests.
```

Create `tests/fixtures/production-project/.claude/agents/reviewer.md`:
```markdown
---
description: Code review agent
allowed-tools: Read, Glob, Grep
---

## Output Format

| Check | Verdict | Detail |
|-------|---------|--------|
```

Create `tests/fixtures/production-project/tests/test-e2e-deploy.sh`:
```bash
#!/usr/bin/env bash
echo "PASS: e2e deploy test"
```

Create `tests/fixtures/production-project/tests/test-integration-hooks.sh`:
```bash
#!/usr/bin/env bash
echo "PASS: integration test"
```

Create `tests/fixtures/production-project/.github/workflows/ci.yml`:
```yaml
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash tests/run-all.sh
```

Create `tests/fixtures/production-project/CHANGELOG.md`:
```markdown
# Changelog

## v1.0.0
- Initial release with full harness
```

- [ ] **Step 3: Make all hooks executable**

```bash
chmod +x tests/fixtures/robust-project/.claude/hooks/*.sh
chmod +x tests/fixtures/production-project/.claude/hooks/*.sh
chmod +x tests/fixtures/robust-project/tests/*.sh
chmod +x tests/fixtures/production-project/tests/*.sh
```

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/robust-project/ tests/fixtures/production-project/
git commit -m "test: add robust-project and production-project fixtures (~8.0 and ~9.0 tiers)"
```

---

### Task 6: scoring.sh — Check Engine

**Files:**
- Create: `scripts/scoring.sh`

This is the core engine. It loads `checklist.json`, runs each check against the target project, computes per-tier pass rates, then calculates a weighted overall score.

- [ ] **Step 1: Create scripts directory**

```bash
mkdir -p scripts
```

- [ ] **Step 2: Create scoring.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# scoring.sh — Checklist-based harness evaluation engine
# Usage: scoring.sh [--mode quick|standard] <target-project-root>
# Output: JSON to stdout
# Exit: 0 = success, 1 = issues found, 2 = script error

# ── dependency check ──
if ! command -v jq &>/dev/null; then
  echo '{"error":"jq is required but not installed. Install with: sudo apt install jq (or brew install jq)"}' >&2
  exit 2
fi

# ── argument parsing ──
MODE="quick"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [[ -z "${TARGET:-}" ]]; then
  echo '{"error":"Usage: scoring.sh [--mode quick|standard] <target-project-root>"}' >&2
  exit 2
fi

if [[ ! -d "$TARGET" ]]; then
  echo "{\"error\":\"Target directory not found: $TARGET\"}" >&2
  exit 2
fi

# Resolve absolute paths
TARGET="$(cd "$TARGET" && pwd)"
HARNESS_EVAL_ROOT="${HARNESS_EVAL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CHECKLIST="$HARNESS_EVAL_ROOT/templates/checklist.json"

if [[ ! -f "$CHECKLIST" ]]; then
  echo '{"error":"checklist.json not found. Plugin may not be installed correctly."}' >&2
  exit 2
fi

# ── check functions ──

check_file_exists() {
  local target="$1"
  [[ -f "$TARGET/$target" ]]
}

check_file_exists_any() {
  local targets_json="$1"
  local count
  count=$(echo "$targets_json" | jq -r '.[]' | while read -r t; do
    # Handle glob patterns
    if compgen -G "$TARGET/$t" > /dev/null 2>&1; then
      echo "found"
      break
    fi
  done)
  [[ "$count" == "found" ]]
}

check_glob_min() {
  local pattern="$1"
  local min="$2"
  local count=0
  # Use find for recursive glob, or compgen for simple
  if [[ "$pattern" == *"**"* ]]; then
    # Convert glob to find pattern
    local base_dir="${pattern%%/**}"
    local file_pattern="${pattern##**/}"
    if [[ -d "$TARGET/$base_dir" ]]; then
      count=$(find "$TARGET/$base_dir" -name "$file_pattern" 2>/dev/null | wc -l)
    elif [[ "$base_dir" == "$pattern" ]]; then
      # Pattern like "**/CLAUDE.md"
      count=$(find "$TARGET" -name "$file_pattern" 2>/dev/null | wc -l)
    fi
  else
    count=$(compgen -G "$TARGET/$pattern" 2>/dev/null | wc -l || echo 0)
  fi
  [[ "$count" -ge "$min" ]]
}

check_json_field_exists() {
  local target="$1"
  local path="$2"
  local file="$TARGET/$target"
  [[ -f "$file" ]] && jq -e "$path" "$file" > /dev/null 2>&1
}

check_json_array_min() {
  local target="$1"
  local path="$2"
  local min="$3"
  local file="$TARGET/$target"
  if [[ ! -f "$file" ]]; then return 1; fi
  local count
  # hooks is an object with event keys, each containing arrays
  if [[ "$path" == ".hooks" ]]; then
    count=$(jq '[.hooks // {} | to_entries[] | .value | length] | add // 0' "$file" 2>/dev/null || echo 0)
  else
    count=$(jq "$path | length" "$file" 2>/dev/null || echo 0)
  fi
  [[ "$count" -ge "$min" ]]
}

check_json_keys_present() {
  local target="$1"
  local path="$2"
  local keys_json="$3"
  local file="$TARGET/$target"
  if [[ ! -f "$file" ]]; then return 1; fi
  local all_present=true
  for key in $(echo "$keys_json" | jq -r '.[]'); do
    if ! jq -e "${path}.${key}" "$file" > /dev/null 2>&1; then
      all_present=false
      break
    fi
  done
  $all_present
}

check_grep_match() {
  local target="$1"
  local pattern="$2"
  # target may be a glob pattern
  local found=false
  for file in $TARGET/$target; do
    if [[ -f "$file" ]] && grep -qE "$pattern" "$file" 2>/dev/null; then
      found=true
      break
    fi
  done
  $found
}

check_grep_all_files() {
  local target="$1"
  local pattern="$2"
  local all_match=true
  local any_file=false
  for file in $TARGET/$target; do
    if [[ -f "$file" ]]; then
      any_file=true
      if ! grep -qE "$pattern" "$file" 2>/dev/null; then
        all_match=false
        break
      fi
    fi
  done
  $any_file && $all_match
}

# ── run checks ──

run_check() {
  local check_json="$1"
  local check_type check_target result

  check_type=$(echo "$check_json" | jq -r '.type')

  case "$check_type" in
    file_exists)
      check_target=$(echo "$check_json" | jq -r '.target')
      check_file_exists "$check_target"
      ;;
    file_exists_any)
      local targets
      targets=$(echo "$check_json" | jq -c '.targets')
      check_file_exists_any "$targets"
      ;;
    glob_min)
      check_target=$(echo "$check_json" | jq -r '.target')
      local min
      min=$(echo "$check_json" | jq -r '.min')
      check_glob_min "$check_target" "$min"
      ;;
    json_field_exists)
      check_target=$(echo "$check_json" | jq -r '.target')
      local jpath
      jpath=$(echo "$check_json" | jq -r '.path')
      check_json_field_exists "$check_target" "$jpath"
      ;;
    json_array_min)
      check_target=$(echo "$check_json" | jq -r '.target')
      local jpath min
      jpath=$(echo "$check_json" | jq -r '.path')
      min=$(echo "$check_json" | jq -r '.min')
      check_json_array_min "$check_target" "$jpath" "$min"
      ;;
    json_keys_present)
      check_target=$(echo "$check_json" | jq -r '.target')
      local jpath keys
      jpath=$(echo "$check_json" | jq -r '.path')
      keys=$(echo "$check_json" | jq -c '.keys')
      check_json_keys_present "$check_target" "$jpath" "$keys"
      ;;
    grep_match)
      check_target=$(echo "$check_json" | jq -r '.target')
      local pattern
      pattern=$(echo "$check_json" | jq -r '.pattern')
      check_grep_match "$check_target" "$pattern"
      ;;
    grep_all_files)
      check_target=$(echo "$check_json" | jq -r '.target')
      local pattern
      pattern=$(echo "$check_json" | jq -r '.pattern')
      check_grep_all_files "$check_target" "$pattern"
      ;;
    *)
      echo "Unknown check type: $check_type" >&2
      return 1
      ;;
  esac
}

# ── main scoring logic ──

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESULTS='[]'
TIER_SCORES='{}'

for tier in $(jq -r '.tiers | keys[]' "$CHECKLIST"); do
  tier_weight=$(jq -r ".tiers.${tier}.weight" "$CHECKLIST")
  item_count=$(jq ".tiers.${tier}.items | length" "$CHECKLIST")
  passed=0

  for i in $(seq 0 $((item_count - 1))); do
    item=$(jq -c ".tiers.${tier}.items[$i]" "$CHECKLIST")
    item_id=$(echo "$item" | jq -r '.id')
    item_desc=$(echo "$item" | jq -r '.description')
    item_weight=$(echo "$item" | jq -r '.weight // 1.0')

    if run_check "$item"; then
      status="PASS"
      passed=$((passed + 1))
    else
      status="FAIL"
    fi

    RESULTS=$(echo "$RESULTS" | jq --arg id "$item_id" --arg desc "$item_desc" \
      --arg status "$status" --arg tier "$tier" --argjson weight "$item_weight" \
      '. + [{"id": $id, "description": $desc, "status": $status, "tier": $tier, "weight": $weight}]')
  done

  # tier score: ratio of passed items (0.0 - 1.0)
  if [[ $item_count -gt 0 ]]; then
    tier_ratio=$(echo "scale=4; $passed / $item_count" | bc)
  else
    tier_ratio="1.0"
  fi

  TIER_SCORES=$(echo "$TIER_SCORES" | jq --arg tier "$tier" --argjson ratio "$tier_ratio" \
    --argjson weight "$tier_weight" --argjson passed "$passed" --argjson total "$item_count" \
    '. + {($tier): {"ratio": $ratio, "weight": $weight, "passed": $passed, "total": $total}}')
done

# ── compute overall score ──
# Score formula: weighted sum of tier ratios, mapped to 1.0-10.0 scale
# Each tier's contribution is capped by previous tiers (can't score high on "production"
# if "basic" is failing)

OVERALL=$(echo "$TIER_SCORES" | jq '
  # Extract tiers in order
  ["basic", "functional", "robust", "production"] as $order |
  # Calculate cumulative weighted score
  reduce $order[] as $tier (
    {"score": 0, "total_weight": 0, "prev_ratio": 1.0};
    if .[$tier] then
      .[$tier] as $t |
      # Tier contribution is dampened by previous tier ratio
      ($t.ratio * .prev_ratio) as $effective_ratio |
      .score += ($effective_ratio * $t.weight) |
      .total_weight += $t.weight |
      .prev_ratio = ([.prev_ratio, $t.ratio] | min)
    else . end
  ) |
  # Normalize to 1.0-10.0 scale
  if .total_weight > 0 then
    ((.score / .total_weight) * 9.0 + 1.0)
  else 1.0 end |
  # Round to 1 decimal
  (. * 10 | floor) / 10
')

# ── grade mapping ──
GRADE=$(echo "$OVERALL" | jq -r '
  if . >= 9.5 then "A+"
  elif . >= 9.0 then "A"
  elif . >= 8.5 then "A-"
  elif . >= 8.0 then "B+"
  elif . >= 7.0 then "B"
  elif . >= 6.0 then "C"
  else "F"
  end
')

# ── build output ──
jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg mode "$MODE" \
  --argjson overall "$OVERALL" \
  --arg grade "$GRADE" \
  --argjson tiers "$TIER_SCORES" \
  --argjson results "$RESULTS" \
  '{
    timestamp: $timestamp,
    mode: $mode,
    scores: {
      overall: $overall,
      grade: $grade
    },
    checklist: $tiers,
    results: $results
  }'

# Exit 1 if any FAIL found, else 0
if echo "$RESULTS" | jq -e '[.[] | select(.status == "FAIL")] | length > 0' > /dev/null; then
  exit 1
else
  exit 0
fi
```

- [ ] **Step 3: Make executable**

```bash
chmod +x scripts/scoring.sh
```

- [ ] **Step 4: Smoke test against minimal fixture**

Run: `HARNESS_EVAL_ROOT="$(pwd)" bash scripts/scoring.sh tests/fixtures/minimal-project 2>&1 | jq .scores`
Expected: JSON output with overall score between 3.0-6.0 and grade "C" or "F"

- [ ] **Step 5: Smoke test against production fixture**

Run: `HARNESS_EVAL_ROOT="$(pwd)" bash scripts/scoring.sh tests/fixtures/production-project 2>&1 | jq .scores`
Expected: JSON output with overall score between 7.0-10.0 and grade "A-" or higher

- [ ] **Step 6: Commit**

```bash
git add scripts/scoring.sh
git commit -m "feat: add scoring.sh checklist evaluation engine"
```

---

### Task 7: Test Suite for scoring.sh

**Files:**
- Create: `tests/test-scoring.sh`

- [ ] **Step 1: Create test-scoring.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# test-scoring.sh — Tests for scoring.sh against fixture projects
# Validates that each fixture scores within expected range

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCORING="$PROJECT_ROOT/scripts/scoring.sh"
FIXTURES="$PROJECT_ROOT/tests/fixtures"

export HARNESS_EVAL_ROOT="$PROJECT_ROOT"

PASS=0
FAIL=0
ERRORS=""

assert_score_range() {
  local fixture="$1"
  local min="$2"
  local max="$3"
  local label="$4"

  local output score
  output=$("$SCORING" "$FIXTURES/$fixture" 2>/dev/null) || true
  score=$(echo "$output" | jq -r '.scores.overall' 2>/dev/null || echo "null")

  if [[ "$score" == "null" ]]; then
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — no score in output"
    return
  fi

  local in_range
  in_range=$(echo "$score >= $min && $score <= $max" | bc -l)
  if [[ "$in_range" == "1" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — score $score (expected $min-$max)"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — score $score (expected $min-$max)"
  fi
}

assert_grade() {
  local fixture="$1"
  local expected_grade="$2"
  local label="$3"

  local output grade
  output=$("$SCORING" "$FIXTURES/$fixture" 2>/dev/null) || true
  grade=$(echo "$output" | jq -r '.scores.grade' 2>/dev/null || echo "null")

  if [[ "$grade" == "$expected_grade" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — grade $grade"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — grade $grade (expected $expected_grade)"
  fi
}

assert_has_results() {
  local fixture="$1"
  local label="$2"

  local output count
  output=$("$SCORING" "$FIXTURES/$fixture" 2>/dev/null) || true
  count=$(echo "$output" | jq '.results | length' 2>/dev/null || echo "0")

  if [[ "$count" -gt 0 ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — $count check results"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — no check results"
  fi
}

assert_exit_code() {
  local fixture="$1"
  local expected="$2"
  local label="$3"

  "$SCORING" "$FIXTURES/$fixture" > /dev/null 2>&1
  local actual=$?

  if [[ "$actual" -eq "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label — exit code $actual"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $label — exit code $actual (expected $expected)"
  fi
}

echo "=== scoring.sh tests ==="
echo ""

echo "--- Score ranges ---"
assert_score_range "minimal-project"    3.0 6.5  "minimal scores 3.0-6.5"
assert_score_range "functional-project" 5.5 8.0  "functional scores 5.5-8.0"
assert_score_range "robust-project"     6.5 9.0  "robust scores 6.5-9.0"
assert_score_range "production-project" 7.5 10.0 "production scores 7.5-10.0"

echo ""
echo "--- Monotonic ordering ---"
# Production >= Robust >= Functional >= Minimal
min_score=$("$SCORING" "$FIXTURES/minimal-project" 2>/dev/null | jq '.scores.overall')
func_score=$("$SCORING" "$FIXTURES/functional-project" 2>/dev/null | jq '.scores.overall')
rob_score=$("$SCORING" "$FIXTURES/robust-project" 2>/dev/null | jq '.scores.overall')
prod_score=$("$SCORING" "$FIXTURES/production-project" 2>/dev/null | jq '.scores.overall')

monotonic=$(echo "$prod_score >= $rob_score && $rob_score >= $func_score && $func_score >= $min_score" | bc -l)
if [[ "$monotonic" == "1" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: scores are monotonically increasing ($min_score → $func_score → $rob_score → $prod_score)"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: scores NOT monotonic ($min_score → $func_score → $rob_score → $prod_score)"
fi

echo ""
echo "--- Result structure ---"
assert_has_results "minimal-project" "minimal has check results"
assert_has_results "production-project" "production has check results"

echo ""
echo "--- Exit codes ---"
assert_exit_code "minimal-project" 1 "minimal exits 1 (has failures)"
assert_exit_code "production-project" 0 "production exits 0 (all pass)"

echo ""
echo "--- Error handling ---"
# Non-existent target
"$SCORING" "/nonexistent/path" > /dev/null 2>&1 && ec=$? || ec=$?
if [[ "$ec" -eq 2 ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: nonexistent path exits 2"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: nonexistent path exits $ec (expected 2)"
fi

# No arguments
"$SCORING" > /dev/null 2>&1 && ec=$? || ec=$?
if [[ "$ec" -eq 2 ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: no arguments exits 2"
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}\n  FAIL: no arguments exits $ec (expected 2)"
fi

echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailures:$ERRORS"
  exit 1
fi
echo "All tests passed!"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/test-scoring.sh
```

- [ ] **Step 3: Run tests**

Run: `bash tests/test-scoring.sh`
Expected: All tests pass. If failures, fix scoring.sh and re-run.

- [ ] **Step 4: Commit**

```bash
git add tests/test-scoring.sh
git commit -m "test: add scoring.sh test suite with fixture validation"
```

---

### Task 8: Quick Evaluation Skill

**Files:**
- Create: `skills/quick.md`
- Create: `templates/report-component.md`

- [ ] **Step 1: Create report-component template**

Create `templates/report-component.md`:
```markdown
## {component_name}
**Score: {score}/10**

**Strengths:**
{strengths}

**Weaknesses:**
{weaknesses}

**To reach next tier:**
{improvements}
```

- [ ] **Step 2: Create skills/quick.md**

```markdown
---
name: quick
description: Quick harness evaluation — checklist-based scoring in ~30 seconds. Runs deterministic checks against the target project and produces a score, grade, and improvement suggestions.
---

You are performing a Quick harness evaluation. This is a fast, checklist-based assessment that produces a score and grade.

## Steps

1. **Identify target project**: Use the current working directory as the target project root. Verify it exists and contains at least some files.

2. **Run scoring script**: Execute the scoring engine:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scoring.sh" --mode quick "$(pwd)"
   ```
   Capture the JSON output.

3. **Parse results**: Extract from the JSON:
   - `scores.overall` — numeric score (1.0-10.0)
   - `scores.grade` — letter grade
   - `checklist` — per-tier pass/total counts
   - `results` — individual check pass/fail details

4. **Generate report**: Present results in this format:

   ```
   # Harness Quick Evaluation

   **Score: {overall}/10 ({grade})**
   **Date: {timestamp}**

   ## Checklist Results

   | Tier | Passed | Total | Status |
   |------|--------|-------|--------|
   | Basic (6.0+) | X | Y | ✓/✗ |
   | Functional (7.0+) | X | Y | ✓/✗ |
   | Robust (8.0+) | X | Y | ✓/✗ |
   | Production (9.0+) | X | Y | ✓/✗ |

   ## Failed Checks
   (List each FAIL item with its description and tier)

   ## Next Steps
   (List 3-5 specific improvements to reach the next tier, prioritized by impact)
   ```

5. **Provide actionable guidance**: For each failed check, explain what the user needs to do to fix it. Be specific — include file paths and example content.

## Error Handling

- If scoring.sh exits with code 2 (script error), show the error message and suggest checking dependencies (jq installed? correct path?)
- If the target has no `.claude/` directory at all, score will be very low — guide the user to run `claude` init or create the directory manually
- If jq is not installed, tell the user: `sudo apt install jq` or `brew install jq`

## Tone

Be direct and constructive. Focus on what to do next, not what's wrong.
```

- [ ] **Step 3: Commit**

```bash
git add skills/quick.md templates/report-component.md
git commit -m "feat: add quick evaluation skill and report template"
```

---

### Task 9: End-to-End Verification

- [ ] **Step 1: Validate all JSON files**

Run: `find . -name "*.json" -not -path "./.git/*" -exec python3 -m json.tool {} \; > /dev/null && echo "ALL VALID"`
Expected: `ALL VALID`

- [ ] **Step 2: Run full test suite**

Run: `bash tests/test-scoring.sh`
Expected: All tests pass

- [ ] **Step 3: Verify plugin.json references exist**

Run:
```bash
for f in $(jq -r '.skills[].path, .agents[].path, .commands[].path, .hooks[].path' plugin.json); do
  [[ -f "$f" ]] && echo "OK: $f" || echo "MISSING: $f"
done
```
Expected: All files show `OK`

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address issues found in end-to-end verification"
```

(Skip if no changes needed)

---

## Plan Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Plugin skeleton | plugin.json, CLAUDE.md |
| 2 | Checklist definition | templates/checklist.json |
| 3 | Minimal fixture | tests/fixtures/minimal-project/ |
| 4 | Functional fixture | tests/fixtures/functional-project/ |
| 5 | Robust + Production fixtures | tests/fixtures/robust-project/, production-project/ |
| 6 | Scoring engine | scripts/scoring.sh |
| 7 | Test suite | tests/test-scoring.sh |
| 8 | Quick skill + report template | skills/quick.md, templates/report-component.md |
| 9 | E2E verification | (validation only) |
