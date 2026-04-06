# harness-eval Plan 2: Standard Flow + History/Badge

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Standard evaluation flow (static analysis + dynamic analysis skill), history tracking, badge generation, and compare skill so that `/harness-eval standard` and `/harness-eval compare` produce working results.

**Architecture:** static-analysis.sh performs deterministic checks (syntax, permissions, tool scope, deny lists). skills/standard.md orchestrates: run static-analysis.sh, run scoring.sh, then guide Claude through dynamic analysis. history.sh persists results to `.harness-eval/` in the target project. badge.sh reads latest.json and updates README badges.

**Tech Stack:** Bash 4.0+, jq, Markdown (skills/templates)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `scripts/static-analysis.sh` | Correctness/safety checks: bash -n, JSON validation, file permissions, hook registration mapping, tool scope, deny list |
| `scripts/history.sh` | Save/list/compare evaluation history in target project's `.harness-eval/` |
| `scripts/badge.sh` | Read latest.json, generate shields.io badge URLs, update README.md |
| `skills/standard.md` | User-facing Standard evaluation orchestrator |
| `skills/compare.md` | History comparison and trend analysis skill |
| `templates/report-full.md` | Full report template for Standard/Full modes |
| `tests/test-static-analysis.sh` | Tests for static-analysis.sh |
| `tests/test-history.sh` | Tests for history.sh save/list/compare |

---

### Task 1: static-analysis.sh

**Files:**
- Create: `scripts/static-analysis.sh`

- [ ] **Step 1: Create static-analysis.sh**

The script performs these checks against a target project:

**Correctness checks:**
- `bash -n` on all `.sh` files in `.claude/hooks/` and `scripts/`
- JSON validation on `.claude/settings.json` and `.claude/settings.local.json`
- File existence: every hook command path in settings.json maps to an actual file
- File permissions: all `.sh` hook files are executable

**Safety checks:**
- Tool scope: detect overly permissive patterns (e.g., `Bash(python3:*)` instead of `Bash(python3 -c:*)`, `Bash(cat:*)` when Read tool should be used)
- Deny list: check if dangerous commands are blocked (`rm -rf`, `git push --force`, `git reset --hard`, `eval`, `curl | bash`)

**Completeness checks:**
- Hook event coverage: which events (PreToolUse, PostToolUse, Stop, Notification) are registered
- CLAUDE.md exists at project root

**Consistency checks:**
- Frontmatter field consistency across skills/agents (all have `description` field)

Output JSON schema:
```json
{
  "timestamp": "ISO 8601",
  "project": "/path",
  "checks": [
    {
      "id": "string",
      "category": "correctness|safety|completeness|consistency",
      "status": "PASS|WARN|FAIL",
      "details": "string",
      "file": "optional path",
      "suggestion": "optional string"
    }
  ],
  "summary": { "pass": 0, "warn": 0, "fail": 0, "total": 0 }
}
```

Exit codes: 0 = all pass, 1 = issues found, 2 = script error.

Implementation notes:
- Use same dependency check pattern as scoring.sh (jq, bash 4.0+)
- Use same `HARNESS_EVAL_ROOT` / `$1` target convention
- Build up a `checks` JSON array incrementally using jq
- At end, compute summary counts from the array

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/static-analysis.sh
```

- [ ] **Step 3: Smoke test against production fixture**

```bash
HARNESS_EVAL_ROOT="$(pwd)" bash scripts/static-analysis.sh tests/fixtures/production-project 2>/dev/null | jq '.summary'
```

Expected: mostly PASS, summary shows counts.

- [ ] **Step 4: Smoke test against minimal fixture**

```bash
HARNESS_EVAL_ROOT="$(pwd)" bash scripts/static-analysis.sh tests/fixtures/minimal-project 2>/dev/null | jq '.summary'
```

Expected: several WARN/FAIL (no hooks, no deny list, etc.)

- [ ] **Step 5: Commit**

```bash
git add scripts/static-analysis.sh
git commit -m "feat: add static-analysis.sh for correctness, safety, and completeness checks"
```

---

### Task 2: test-static-analysis.sh

**Files:**
- Create: `tests/test-static-analysis.sh`

- [ ] **Step 1: Create tests**

Tests should verify:
1. **Valid JSON output**: output is parseable JSON for all fixtures
2. **Summary counts**: `summary.total > 0` for all fixtures
3. **Production fixture**: mostly PASS, few/no FAIL
4. **Minimal fixture**: has WARN or FAIL items (no hooks, no deny list)
5. **Syntax check detection**: if a fixture had a bad .sh file, it would be caught (can test with a temp file)
6. **Exit codes**: 0 for all-pass project, 1 for issues, 2 for bad args
7. **Output schema**: all required fields present in each check item

Use same test pattern as test-scoring.sh (PASS/FAIL counters, assert helpers).

- [ ] **Step 2: Make executable and run**

```bash
chmod +x tests/test-static-analysis.sh
bash tests/test-static-analysis.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/test-static-analysis.sh
git commit -m "test: add static-analysis.sh test suite"
```

---

### Task 3: history.sh

**Files:**
- Create: `scripts/history.sh`

- [ ] **Step 1: Create history.sh**

Subcommands:
- `history.sh <project> save` — reads score-result JSON from stdin, appends to `.harness-eval/history.json`, copies to `.harness-eval/latest.json`
  - Auto-generates `id: "eval-YYYY-MM-DD-NNN"` (NNN = sequential within that day)
  - Creates `.harness-eval/` directory if missing
  - Initializes `history.json` with `{"version":"1.0","project":"<basename>","evaluations":[]}` if missing

- `history.sh <project> list [--last N]` — outputs summary table of evaluations
  - Default: all evaluations
  - `--last N`: only last N evaluations
  - Output JSON array of `{id, timestamp, mode, overall, grade}`

- `history.sh <project> compare [--eval-id ID]` — compare latest with previous (or specific ID)
  - Output JSON with `{current, previous, delta, per_tier_delta}`
  - If no previous evaluation exists, output `{"error":"No previous evaluation found"}`

Exit codes: same convention (0/1/2).

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/history.sh
```

- [ ] **Step 3: Smoke test save**

```bash
HARNESS_EVAL_ROOT="$(pwd)" bash scripts/scoring.sh tests/fixtures/production-project 2>/dev/null | \
  HARNESS_EVAL_ROOT="$(pwd)" bash scripts/history.sh tests/fixtures/production-project save
```

Verify: `tests/fixtures/production-project/.harness-eval/history.json` and `latest.json` created.

- [ ] **Step 4: Smoke test list**

```bash
HARNESS_EVAL_ROOT="$(pwd)" bash scripts/history.sh tests/fixtures/production-project list | jq .
```

Expected: array with 1 evaluation entry.

- [ ] **Step 5: Commit**

```bash
git add scripts/history.sh
git commit -m "feat: add history.sh for evaluation history tracking"
```

---

### Task 4: test-history.sh

**Files:**
- Create: `tests/test-history.sh`

- [ ] **Step 1: Create tests**

Tests using a temp directory to avoid polluting fixtures:
1. **Save roundtrip**: save a score, then list → should see it
2. **Multiple saves**: save twice, list → 2 entries with different IDs
3. **Latest.json**: after save, latest.json matches last saved score
4. **Compare**: save two results, compare → shows delta
5. **Empty history**: compare with no history → error message
6. **List --last N**: save 3, list --last 2 → only 2 returned
7. **Directory creation**: save to a project with no `.harness-eval/` → creates it
8. **Exit codes**: proper codes for each scenario

Each test should create a temporary project directory, run operations, then clean up.

- [ ] **Step 2: Make executable and run**

```bash
chmod +x tests/test-history.sh
bash tests/test-history.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/test-history.sh
git commit -m "test: add history.sh test suite"
```

---

### Task 5: badge.sh

**Files:**
- Create: `scripts/badge.sh`

- [ ] **Step 1: Create badge.sh**

Reads `.harness-eval/latest.json` from the target project and generates/updates shields.io badge markdown in README.md.

Badge color mapping:
- 9.0+ → brightgreen
- 8.0-8.9 → green  
- 7.0-7.9 → yellow
- 6.0-6.9 → orange
- <6.0 → red

Badge format (between markers):
```html
<!-- harness-eval-badge:start -->
![Harness Score](https://img.shields.io/badge/harness-{score}%2F10-{color})
![Harness Grade](https://img.shields.io/badge/grade-{grade}-{color})
![Last Eval](https://img.shields.io/badge/eval-{date}-blue)
<!-- harness-eval-badge:end -->
```

Behavior:
- If README.md has existing markers → replace content between them
- If README.md exists but no markers → append badges at the end
- If no README.md → create one with just badges
- URL-encode the score (e.g., `8.5` → `8.5%2F10`)

- [ ] **Step 2: Make executable and smoke test**

```bash
chmod +x scripts/badge.sh
# Create a test setup
mkdir -p /tmp/badge-test/.harness-eval
echo '{"scores":{"overall":8.5,"grade":"A-"},"timestamp":"2026-04-06T00:00:00Z"}' > /tmp/badge-test/.harness-eval/latest.json
echo "# Test Project" > /tmp/badge-test/README.md
HARNESS_EVAL_ROOT="$(pwd)" bash scripts/badge.sh /tmp/badge-test
cat /tmp/badge-test/README.md
rm -rf /tmp/badge-test
```

- [ ] **Step 3: Commit**

```bash
git add scripts/badge.sh
git commit -m "feat: add badge.sh for README harness score badges"
```

---

### Task 6: Standard Evaluation Skill

**Files:**
- Modify: `skills/standard.md` (overwrite placeholder)
- Create: `templates/report-full.md`

- [ ] **Step 1: Create report-full.md**

```markdown
# Harness Evaluation Report — {mode}

**Score: {overall}/10 ({grade})**
**Date: {timestamp}**
**Mode: {mode}**

---

## Summary

| Category | Score | Weight | Status |
|----------|-------|--------|--------|
{dimension_rows}

## Static Analysis

### Correctness
{correctness_findings}

### Safety
{safety_findings}

### Completeness
{completeness_findings}

### Consistency
{consistency_findings}

## Dynamic Analysis

{dynamic_findings}

## Checklist Results

| Tier | Passed | Total | Status |
|------|--------|-------|--------|
{checklist_rows}

## Failed Checks
{failed_checks}

## Improvement Roadmap
{roadmap}

---
*Generated by harness-eval v{version}*
```

- [ ] **Step 2: Create skills/standard.md**

The Standard skill orchestrates a 3-phase evaluation:

Phase 1: Static Analysis — run `scripts/static-analysis.sh`
Phase 2: Dynamic Analysis — Claude performs live tests (hook execution, secret pattern TP/FP, existing test suite)
Phase 3: Scoring + Report — run `scripts/scoring.sh --mode standard`, generate report, save to history

The skill prompt should instruct Claude to:
1. Run static-analysis.sh and capture results
2. Perform dynamic tests (execute hooks with test input, run existing tests)
3. Run scoring.sh for the checklist score
4. Combine static analysis findings + dynamic analysis + checklist score into a comprehensive report
5. Save results via history.sh
6. Present the report to the user

- [ ] **Step 3: Commit**

```bash
git add skills/standard.md templates/report-full.md
git commit -m "feat: add standard evaluation skill and full report template"
```

---

### Task 7: Compare Skill

**Files:**
- Modify: `skills/compare.md` (overwrite placeholder)

- [ ] **Step 1: Create skills/compare.md**

The Compare skill:
1. Runs `history.sh <project> list` to get evaluation history
2. Runs `history.sh <project> compare` to get delta with previous
3. Presents:
   - Current vs previous score with delta (↑/↓)
   - Per-tier improvement/decline
   - ASCII bar chart of score history
   - Prediction for next achievable grade
   - Diminishing returns warning if score improvements are shrinking

- [ ] **Step 2: Commit**

```bash
git add skills/compare.md
git commit -m "feat: add compare skill for evaluation history analysis"
```

---

### Task 8: End-to-End Verification

- [ ] **Step 1: Run all tests**

```bash
bash tests/test-scoring.sh
bash tests/test-static-analysis.sh
bash tests/test-history.sh
```

All should pass.

- [ ] **Step 2: Validate JSON files**

```bash
find . -name "*.json" -not -path "./.git/*" -not -path "*/fixtures/*/.harness-eval/*" -exec python3 -m json.tool {} \; > /dev/null
```

- [ ] **Step 3: Verify skill files are not placeholders**

```bash
for f in skills/standard.md skills/compare.md; do
  if grep -q "TODO" "$f"; then echo "STILL PLACEHOLDER: $f"; else echo "OK: $f"; fi
done
```

- [ ] **Step 4: Clean up any test artifacts in fixtures**

```bash
rm -rf tests/fixtures/*/.harness-eval
```

- [ ] **Step 5: Final commit if needed**

---

## Plan Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Static analysis script | scripts/static-analysis.sh |
| 2 | Static analysis tests | tests/test-static-analysis.sh |
| 3 | History tracking | scripts/history.sh |
| 4 | History tests | tests/test-history.sh |
| 5 | Badge generation | scripts/badge.sh |
| 6 | Standard evaluation skill | skills/standard.md, templates/report-full.md |
| 7 | Compare skill | skills/compare.md |
| 8 | E2E verification | (validation only) |
