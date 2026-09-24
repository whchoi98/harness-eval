---
name: quick
description: Quick harness evaluation — checklist-based scoring in ~30 seconds. Runs deterministic checks against the target project and produces a score, grade, and improvement suggestions.
effort: low
---

You are performing a Quick harness evaluation. This is a fast, checklist-based assessment that produces a score and grade.

## Steps

1. **Identify target project**: Use the current working directory as the target project root. Verify it exists and contains at least some files.

2. **Run scoring script**: Execute the scoring engine:
   ```bash
   HARNESS_EVAL_ROOT="${CLAUDE_PLUGIN_ROOT}" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scoring.sh" --mode quick "$(pwd)"
   ```
   Capture the JSON output. Exit code 1 means some checks failed and is a normal result; only exit code 2 is a script error.

3. **Parse results**: Extract from the JSON:
   - `scores.overall` — numeric score (1.0-10.0)
   - `scores.grade` — letter grade
   - `checklist` — per-tier pass/total counts
   - `results` — individual check pass/fail details

4. **Generate bilingual report**: Present results in English and Korean, separated by a horizontal rule. Use this format:

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
   (For each FAIL: its description and tier, then the fix — the file path to create or change, with example content)

   ## Next Steps
   (The improvements that would move the project to the next tier, highest impact first — as many as the failed checks warrant)

   ---

   # 하네스 Quick 평가

   **점수: {overall}/10 ({grade})**
   **날짜: {timestamp}**

   ## 체크리스트 결과

   | 단계 | 통과 | 전체 | 상태 |
   |------|------|------|------|
   | 기본 (6.0+) | X | Y | ✓/✗ |
   | 기능적 (7.0+) | X | Y | ✓/✗ |
   | 견고 (8.0+) | X | Y | ✓/✗ |
   | 프로덕션 (9.0+) | X | Y | ✓/✗ |

   ## 실패 항목
   (각 FAIL 항목의 설명과 단계, 그리고 해결 방법 — 만들거나 수정할 파일 경로와 예시 내용)

   ## 다음 단계
   (다음 단계 도달에 필요한 개선 사항 — 실패 항목에 맞춰 필요한 만큼, 영향도 순)
   ```

5. **Save reports to files**: Save the English and Korean reports as separate files in the target project:
   ```bash
   mkdir -p .harness-eval/reports
   ```
   - English report: `.harness-eval/reports/eval-{YYYY-MM-DD}-{NNN}-quick-en.md`
   - Korean report: `.harness-eval/reports/eval-{YYYY-MM-DD}-{NNN}-quick-ko.md`

   `{YYYY-MM-DD}` is the UTC date of the scoring output's `timestamp`. Quick runs are not recorded in history (`/harness-eval:compare` works from saved Standard and Full runs), so `{NNN}` is a per-day Quick report counter, not a history ID: list today's Quick reports with `ls .harness-eval/reports/eval-$(date -u +%F)-*-quick-en.md 2>/dev/null || true` (it prints nothing when there are none) and use one more than the highest `{NNN}` found, zero-padded to three digits (`001` if there are none). This keeps a second Quick run on the same day from overwriting the first.

   Use the Write tool to create each file. After saving, inform the user of the file paths.

## Error Handling

- If scoring.sh exits with code 2 (script error), show the error message and suggest checking dependencies (jq installed? correct path?)
- If the target has no `.claude/` directory at all, the score will be very low. Suggest running `/init` in a Claude Code session to create a CLAUDE.md, then adding `.claude/settings.json` with permissions and hooks.
- If jq is not installed, tell the user: `sudo apt install jq` or `brew install jq`

## Tone

Be direct and constructive. Focus on what to do next, not what's wrong.

## Language

Always produce the report in both English and Korean. English section first, then a horizontal rule (---), then the Korean section. Tables, scores, file paths, and code blocks are identical in both sections — only the prose text differs.
