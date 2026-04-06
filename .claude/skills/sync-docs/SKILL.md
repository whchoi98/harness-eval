# Sync Docs Skill

Synchronize project documentation with current code state.

## Actions

### 1. Quality Assessment
Score each CLAUDE.md file (0-100) across:
- Commands/workflows (20 pts)
- Architecture clarity (20 pts)
- Non-obvious patterns (15 pts)
- Conciseness (15 pts)
- Currency (15 pts)
- Actionability (15 pts)

Apply anti-pattern deductions:
- Over 500 lines (-15)
- Vague instructions (-10)
- Duplicated docs (-10)
- No test guidance (-10)
- Contains secrets (-20)

Output quality report with grades (A-F) before making changes.

### 2. Root CLAUDE.md Sync
- Update Overview, Tech Stack, Conventions, Key Commands
- Verify commands are copy-paste ready against actual scripts

### 3. Architecture Doc Sync
- Update docs/architecture.md to reflect current system structure
- Add new components, update data flows, reflect infrastructure changes

### 4. Module CLAUDE.md Audit
- Scan all directories under plugin root
- Create CLAUDE.md for modules missing one
- Update existing module CLAUDE.md files if out of date
- Score each module CLAUDE.md

### 5. ADR and Runbook Audit
- Check recent commits for undocumented architectural decisions
- Verify runbook coverage against project characteristics
- Flag stale ADRs and outdated runbooks

### 6. .claude-plugin/plugin.json Sync
- Verify all paths in .claude-plugin/plugin.json point to existing files
- Verify version consistency

### 7. Report
Output before/after quality scores, anti-patterns detected, and list of all changes.
