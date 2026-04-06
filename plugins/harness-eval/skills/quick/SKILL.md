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

4. **Generate bilingual report**: Present results in BOTH English and Korean, separated by a horizontal rule. Use this format:

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
   (각 FAIL 항목의 설명과 단계를 나열)

   ## 다음 단계
   (다음 단계에 도달하기 위한 3-5개 구체적 개선 사항, 영향도 순)
   ```

5. **Provide actionable guidance**: For each failed check, explain what the user needs to do to fix it in both languages. Be specific — include file paths and example content.

## Error Handling

- If scoring.sh exits with code 2 (script error), show the error message and suggest checking dependencies (jq installed? correct path?)
- If the target has no `.claude/` directory at all, score will be very low — guide the user to run `claude` init or create the directory manually
- If jq is not installed, tell the user: `sudo apt install jq` or `brew install jq`

## Tone

Be direct and constructive. Focus on what to do next, not what's wrong.

## Language

Always produce the report in both English and Korean. English section first, then a horizontal rule (---), then the Korean section. Tables, scores, file paths, and code blocks are identical in both sections — only the prose text differs.
