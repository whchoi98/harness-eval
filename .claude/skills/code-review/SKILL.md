# Code Review Skill

Review changed code with confidence-based scoring to filter false positives.

## Review Scope

By default, review unstaged changes from `git diff`. The user may specify different files or scope.

## Review Criteria

### Project Guidelines Compliance
- Import patterns and module boundaries
- Framework conventions and language style
- Function declarations and error handling
- Naming conventions from CLAUDE.md

### Bug Detection
- Logic errors and null/undefined handling
- Race conditions and memory leaks
- Security vulnerabilities (OWASP Top 10)
- Performance problems

### Code Quality
- Code duplication and unnecessary complexity
- Missing critical error handling
- Test coverage gaps
- Accessibility issues (for frontend code)

## Confidence Scoring

Rate each issue 0-100:
- **0-24**: Likely false positive or pre-existing issue. Do not report.
- **25-49**: Might be real but possibly a nitpick. Do not report.
- **50-74**: Real issue but minor. Report only if critical.
- **75-89**: Verified real issue, important. Report with fix suggestion.
- **90-100**: Confirmed critical issue. Must report.

**Only report issues with confidence >= 75.**

## Output Format

For each issue:
### [CRITICAL|IMPORTANT] <issue title> (confidence: XX)
**File:** `path/to/file.ext:line`
**Issue:** Clear description of the problem
**Guideline:** Reference to CLAUDE.md rule or security standard
**Fix:** Concrete code suggestion

If no high-confidence issues found, confirm code meets standards with brief summary.
