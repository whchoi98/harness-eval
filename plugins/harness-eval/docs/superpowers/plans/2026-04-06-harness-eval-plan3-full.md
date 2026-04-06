# harness-eval Plan 3: Full Flow (Multi-Agent)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Full evaluation flow with 5 agents, the orchestrator skill, the `/harness-eval` command entry point, and the post-eval badge hook. This completes the plugin.

**Architecture:** The Full flow runs Standard analysis first, then dispatches a collector agent to build a project artifact, 3 evaluator agents in parallel (safety, completeness, design), and a synthesizer to produce the final 12-dimension report. Generation and evaluation are separated per Anthropic's harness design article.

**Tech Stack:** Markdown (agent prompts, skills), Bash (hook script)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `agents/collector.md` | Scan project structure, collect harness artifacts → project-artifact.md |
| `agents/safety-evaluator.md` | Evaluate Safety (qualitative) + Cost Efficiency dimensions |
| `agents/completeness-evaluator.md` | Evaluate Actionability + Testability + Contract-Based Testing |
| `agents/design-evaluator.md` | Evaluate Agent Communication + Context Management + Feedback Loop + Evolvability |
| `agents/synthesizer.md` | Aggregate all scores → 12-dimension report + roadmap |
| `skills/full.md` | Orchestrator skill for multi-agent Full evaluation |
| `commands/harness-eval.md` | `/harness-eval` entry point command (mode routing) |
| `hooks/post-eval-badge.sh` | Auto-update README badge after evaluation completes |

---

### Task 1: Collector Agent

**Files:**
- Modify: `agents/collector.md` (overwrite placeholder)

The collector scans the target project and produces a structured artifact that other agents consume.

- [ ] **Step 1: Create agents/collector.md**

Agent frontmatter: model sonnet, tools Read/Glob/Grep/Bash/LS.

The collector should:
1. Scan `.claude/` directory structure (settings.json, hooks, skills, agents, commands)
2. Read CLAUDE.md files (root + module-level)
3. Inventory all hook scripts, skills, agents, commands with their key properties
4. Collect test file listing
5. Check for plugin.json (plugin-based harness)
6. Limit scan to 500 files for large projects, prioritizing `.claude/`

Output format (structured markdown artifact):
```markdown
---
agent: collector
timestamp: <ISO 8601>
phase: collection
---

## Project Overview
- Name: <basename>
- Root: <path>
- File count: N (scanned N)

## Harness Components

### Settings
(content of settings.json)

### Hooks
| File | Event | Executable | Lines |
|------|-------|-----------|-------|

### Skills
| File | Description | Has Frontmatter |
|------|-------------|-----------------|

### Agents  
| File | Description | Model | Tools |
|------|-------------|-------|-------|

### Commands
| File | Has Error Recovery |
|------|-------------------|

### CLAUDE.md Files
| Path | Lines | Key Sections |
|------|-------|-------------|

## Tests
| File | Type |
|------|------|

## Raw Data
(JSON summary for downstream agents)
```

- [ ] **Step 2: Commit**

```bash
git add agents/collector.md
git commit -m "feat: add collector agent for project structure scanning"
```

---

### Task 2: Safety Evaluator Agent

**Files:**
- Modify: `agents/safety-evaluator.md` (overwrite placeholder)

- [ ] **Step 1: Create agents/safety-evaluator.md**

Agent frontmatter: model opus, tools Read/Glob/Grep.

Evaluates 2 dimensions:
1. **Safety** (qualitative supplement to static-analysis.sh):
   - Principle of Least Privilege: are tool scopes minimal?
   - Deny list effectiveness: are the right commands blocked?
   - Secret pattern coverage: are patterns comprehensive enough?
   - Attack surface analysis: could any hook or command be exploited?

2. **Cost Efficiency**:
   - Are expensive models (opus) used only where needed?
   - Could any agent/skill use a cheaper model?
   - Are tool lists minimal (fewer tools = faster, cheaper)?
   - Are there redundant agents or skills?

Input: project-artifact.md + score-result.json (provided in prompt)

Output format:
```markdown
---
agent: safety-evaluator
timestamp: <ISO 8601>
phase: evaluation
---

## Scores
| Dimension | Score (0-10) | Confidence | Evidence Summary |
|-----------|-------------|------------|-----------------|
| Safety | X | high/medium/low | ... |
| Cost Efficiency | X | high/medium/low | ... |

## Findings
### [PASS|WARN|FAIL] <finding title>
- File: <path:line>
- Detail: <description>
- Recommendation: <improvement>

## Recommendations
1. (priority ordered)
```

- [ ] **Step 2: Commit**

```bash
git add agents/safety-evaluator.md
git commit -m "feat: add safety-evaluator agent for security and cost analysis"
```

---

### Task 3: Completeness Evaluator Agent

**Files:**
- Modify: `agents/completeness-evaluator.md` (overwrite placeholder)

- [ ] **Step 1: Create agents/completeness-evaluator.md**

Agent frontmatter: model sonnet, tools Read/Glob/Grep.

Evaluates 3 dimensions:
1. **Actionability**: Are commands copy-pasteable? Do skills have clear steps? Are outputs structured?
2. **Testability**: Do tests exist? Are they meaningful (not just mocks)? Is coverage sufficient?
3. **Contract-Based Testing**: Do agents define input/output contracts? Are contracts verified by tests?

- [ ] **Step 2: Commit**

```bash
git add agents/completeness-evaluator.md
git commit -m "feat: add completeness-evaluator agent for actionability and testing analysis"
```

---

### Task 4: Design Evaluator Agent

**Files:**
- Modify: `agents/design-evaluator.md` (overwrite placeholder)

- [ ] **Step 1: Create agents/design-evaluator.md**

Agent frontmatter: model opus, tools Read/Glob/Grep.

Evaluates 4 dimensions derived from the Anthropic harness design article:
1. **Agent Communication**: Do agents have clear interfaces? Is data flow well-defined?
2. **Context Management**: Is context (CLAUDE.md) well-structured? Does it avoid overloading?
3. **Feedback Loop Maturity**: Are there mechanisms for learning from failures? Iteration tracking?
4. **Evolvability**: Can new components be added without breaking existing ones? Modularity?

- [ ] **Step 2: Commit**

```bash
git add agents/design-evaluator.md
git commit -m "feat: add design-evaluator agent for architecture quality analysis"
```

---

### Task 5: Synthesizer Agent

**Files:**
- Modify: `agents/synthesizer.md` (overwrite placeholder)

- [ ] **Step 1: Create agents/synthesizer.md**

Agent frontmatter: model sonnet, tools Read/Bash.

The synthesizer:
1. Receives: Standard analysis results (static + checklist) + 3 evaluator outputs
2. Aggregates: 12 dimensions with weights (Basic 0.50, Operational 0.25, Design 0.25)
3. Computes: Overall weighted score and grade
4. Generates: Full report using templates/report-full.md structure
5. Creates: Prioritized improvement roadmap
6. Saves: via history.sh and badge.sh

Output: Complete markdown report ready to show to user.

- [ ] **Step 2: Commit**

```bash
git add agents/synthesizer.md
git commit -m "feat: add synthesizer agent for score aggregation and report generation"
```

---

### Task 6: Full Evaluation Skill (Orchestrator)

**Files:**
- Modify: `skills/full.md` (overwrite placeholder)

- [ ] **Step 1: Create skills/full.md**

The orchestrator skill coordinates the full 3-phase evaluation:

**Phase 1: Collection**
- Run Standard flow (static-analysis.sh + scoring.sh)
- Dispatch collector agent → project-artifact.md

**Phase 2: Parallel Evaluation**
- Dispatch 3 evaluator agents in parallel (using Agent tool):
  - safety-evaluator
  - completeness-evaluator
  - design-evaluator
- Each receives: project-artifact + standard results
- Handle partial failures: if an agent fails, mark its dimensions as null

**Phase 3: Synthesis**
- Dispatch synthesizer agent with all results
- Save to history, update badge
- Present final report to user

Error handling:
- Collector fail → abort Full, return Standard results only
- Evaluator fail → null dimensions, partial report
- Synthesizer fail → show raw agent outputs

- [ ] **Step 2: Commit**

```bash
git add skills/full.md
git commit -m "feat: add full evaluation skill as multi-agent orchestrator"
```

---

### Task 7: Command Entry Point + Hook

**Files:**
- Modify: `commands/harness-eval.md` (overwrite placeholder)
- Modify: `hooks/post-eval-badge.sh` (overwrite placeholder)

- [ ] **Step 1: Create commands/harness-eval.md**

The `/harness-eval` command routes to the appropriate skill:

```markdown
---
description: Evaluate Claude Code harness engineering quality
allowed-tools: Read, Glob, Grep, Bash, Agent
---

Evaluate the harness engineering quality of the current project.

## Usage

/harness-eval [mode]

Modes:
- `quick` (default) — Checklist-based scoring in ~30 seconds
- `standard` — Static + dynamic analysis in 2-3 minutes
- `full` — Multi-agent comprehensive evaluation in 5-10 minutes
- `compare` — Compare with previous evaluation

## Routing

Based on the mode argument:
- **quick**: Use the `quick` skill from this plugin
- **standard**: Use the `standard` skill from this plugin
- **full**: Use the `full` skill from this plugin
- **compare**: Use the `compare` skill from this plugin

If no mode specified, default to `quick`.
```

- [ ] **Step 2: Create hooks/post-eval-badge.sh**

A Stop hook that detects if an evaluation was just completed and auto-updates the badge:

```bash
#!/usr/bin/env bash
# post-eval-badge.sh — Auto-update README badge after harness evaluation
# Triggered on Stop event. Checks if .harness-eval/latest.json was recently updated.

set -euo pipefail

PROJECT_ROOT="$(pwd)"
LATEST="$PROJECT_ROOT/.harness-eval/latest.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BADGE_SCRIPT="$PLUGIN_ROOT/scripts/badge.sh"

# Only run if latest.json exists and was modified in the last 5 minutes
if [[ -f "$LATEST" ]] && [[ -f "$BADGE_SCRIPT" ]]; then
  LATEST_MOD=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$(( NOW - LATEST_MOD ))
  
  if [[ $AGE -lt 300 ]]; then
    bash "$BADGE_SCRIPT" "$PROJECT_ROOT" > /dev/null 2>&1 || true
  fi
fi
```

- [ ] **Step 3: Make hook executable**

```bash
chmod +x hooks/post-eval-badge.sh
```

- [ ] **Step 4: Commit**

```bash
git add commands/harness-eval.md hooks/post-eval-badge.sh
git commit -m "feat: add /harness-eval command entry point and post-eval badge hook"
```

---

### Task 8: Final Verification

- [ ] **Step 1: Verify no placeholders remain**

```bash
for f in skills/*.md agents/*.md commands/*.md; do
  if grep -q "TODO" "$f" 2>/dev/null; then echo "PLACEHOLDER: $f"; else echo "OK: $f"; fi
done
```

- [ ] **Step 2: Run all tests**

```bash
bash tests/test-scoring.sh
bash tests/test-static-analysis.sh
bash tests/test-history.sh
```

- [ ] **Step 3: Validate plugin.json references**

```bash
for f in $(jq -r '.skills[].path, .agents[].path, .commands[].path, .hooks[].path' plugin.json); do
  [[ -f "$f" ]] && echo "OK: $f" || echo "MISSING: $f"
done
```

- [ ] **Step 4: Verify hook is executable**

```bash
test -x hooks/post-eval-badge.sh && echo "OK: hook executable" || echo "FAIL: hook not executable"
```

- [ ] **Step 5: Clean up test artifacts**

```bash
rm -rf tests/fixtures/*/.harness-eval
```

---

## Plan Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Collector agent | agents/collector.md |
| 2 | Safety evaluator agent | agents/safety-evaluator.md |
| 3 | Completeness evaluator agent | agents/completeness-evaluator.md |
| 4 | Design evaluator agent | agents/design-evaluator.md |
| 5 | Synthesizer agent | agents/synthesizer.md |
| 6 | Full evaluation orchestrator skill | skills/full.md |
| 7 | Command entry point + hook | commands/harness-eval.md, hooks/post-eval-badge.sh |
| 8 | Final verification | (validation only) |
