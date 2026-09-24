# Changelog

[![English](https://img.shields.io/badge/lang-English-blue.svg)](#english)
[![한국어](https://img.shields.io/badge/lang-한국어-red.svg)](#한국어)

---

# English

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-24

Tuning release for Claude Opus 5.5: every Full-mode agent sets its model alias and effort,
Full mode hands data between phases as files and computes its score in a script, and
static analysis checks model and effort settings. The test suite runs 447 checks via
`harness-run-all.sh`.

### Added

- Add `scripts/aggregate.sh`, deterministic Full-mode scoring: it reads the 12 dimension scores as JSON on stdin, averages each category's scored dimensions, applies the 0.50 / 0.25 / 0.25 weights renormalized over the categories that have scores, and prints the canonical history record (`scores`, `dimensions`, `categories`, per-dimension `status`, `missing`)
- Add `scripts/lib/grade.sh` (`score_to_grade`), the single definition of the grade thresholds, sourced by both `scoring.sh` and `aggregate.sh` (`scoring.sh` output is unchanged)
- Add the `model-config` static check (Correctness). It reads `model:`/`effort:` frontmatter in `.claude/` agents and commands and in `.claude/skills/<name>/SKILL.md`, the same components under each plugin root (the target or `plugins/*/` with a `.claude-plugin/plugin.json`), and the settings keys `model`, `effortLevel`, `alwaysThinkingEnabled`, `env.MAX_THINKING_TOKENS`, `env.CLAUDE_CODE_EFFORT_LEVEL`, `env.CLAUDE_CODE_DISABLE_THINKING`, `env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`, and the `env` model keys (`*_MODEL`, `*_MODEL_FORCE`, `*_MODEL_OPTION`). FAIL for retired models, including Bedrock `claude-v1`/`claude-v2` and Claude 1.x. WARN for deprecated models (including the Foundry IDs `claude-opus-4` and `claude-sonnet-4`), dated snapshot IDs in Anthropic API form (dated Bedrock and Vertex IDs are valid pins), `claude-*` IDs missing from the list of served model IDs (the list names each served ID, so a typo such as `claude-opus-55` or a never-released `claude-sonnet-4-7` is reported instead of passing as current), non-Claude model names, invalid effort values (settings `effortLevel` accepts only `low`/`medium`/`high`/`xhigh`), any `env.CLAUDE_CODE_EFFORT_LEVEL` (a value Claude Code accepts overrides the effort of every agent, skill, and command, including effort pinned in frontmatter, and any other value is ignored), and thinking caps (`alwaysThinkingEnabled: false`, `MAX_THINKING_TOKENS`, or a `CLAUDE_CODE_DISABLE_*THINKING` flag that is on) unless the settings pin a model that accepts disabled thinking. That model is compared by its undated ID, so the Bedrock and Vertex spellings of Claude Opus 5 are exempt like `claude-opus-5`
- Add the `agent-format` static check (Correctness): WARN for `*.yml|yaml|json` files in `.claude/agents/` and in each plugin root's `agents/`, which Claude Code does not load
- Add `tests/test-aggregate.sh` (74 tests), `tests/hooks/test-plugin-hooks.sh` (33 checks of the plugin's Stop hook and of `badge.sh`'s README guards), and the `tests/fixtures/model-era-project/` fixture; `test-static-analysis.sh` grows from 26 to 107 tests and `test-history.sh` from 19 to 38
- Add structure checks: every plugin and dev agent sets `name`, `description`, `model`, and `effort` in frontmatter, with a `model` that is an alias or a served model ID and an `effort` that is an accepted level or an integer (both read from `static-analysis.sh`'s tables); every dev skill has a `description`; no `.yml`/`.yaml` agent file exists; and `static-analysis.sh` run on this repository reports PASS for `model-config` and `agent-format`
- Add Full-mode contract checks to the structure suite: the `ARTIFACT_WRITTEN`, `EVAL_ID` / `REPORT_EN` / `REPORT_KO` / `SCORE` / `MISSING`, `SCRIPT_FAILED`, and `AGENT_FAILED` strings on both the producing and the consuming side, the `subagent_type` names, each evaluator's `## Scores` dimensions against the synthesizer, and the synthesizer's heredoc keys, run through `aggregate.sh`
- Add rubric areas: completeness-evaluator "Prescription Matched to Fragility" (replaces "Skill Structure") and "Prompt and Agent Checks"; design-evaluator "Delegation Fit", "Instruction Fit for Current Models" (dated patterns such as thinking-steering prose and "don't think" rules, mitigations written for Claude Opus 5 with thinking off, and blanket anti-formatting rules), and "Model-Change Resilience"; safety-evaluator "Delegation and Model-Call Cost"
- Add `argument-hint: "[--static-only]"` to `/harness-eval:standard`; the `/harness-eval` router passes the options after the mode to that mode
- Add ADR-003 (per-agent model and effort, file handoff in Full mode, and the measured run time and cost of each mode on Claude Opus 5.5) and a "Models and effort" section in the README
- Add the model-change runbook (`plugins/harness-eval/docs/runbooks/model-change.md`): what to re-check when Claude's model line changes (a prompt audit of the agents, skills, and commands, each agent's model and effort, and the static-analysis model tables with the model-era fixture), followed by the test suite and a live run on a fixture copy whose time and cost are recorded

### Changed

- **Model and effort:** all five Full-mode agents use `model: opus` with an explicit `effort` — collector `low`, completeness-evaluator `medium`, design-evaluator `medium`, safety-evaluator `high`, synthesizer `medium`. Collector, completeness-evaluator, and synthesizer were on `sonnet`, and no agent set effort, so evaluation depth followed each user's session effort. The Full skill leaves model and effort to each agent's frontmatter. `CLAUDE_CODE_EFFORT_LEVEL` (including `auto` and `unset`) and an effort cap in settings or from the organization still override the agents' effort, as the README explains. The `quick` and `compare` commands run at `effort: low`; the `/harness-eval` router runs every mode, including its default quick, at the session effort
- **Full-mode data flow:** Phase 1 runs static analysis and scoring in parallel and writes their output to `<project>/.harness-eval/run/`; the collector writes `artifact.md` there and returns its path; the evaluators read those files by path, and the orchestrator passes their final messages to the synthesizer verbatim; the synthesizer scores with `aggregate.sh`, redirecting its output to `record.json` so that a rejected input is not hidden behind a pipe, is the only component that saves history on the normal path, and writes `<EVAL_ID>-full-en.md` and `<EVAL_ID>-full-ko.md` itself
- If the collector fails, Full now saves the Standard checklist score to history (mode `standard`) and writes `<EVAL_ID>-full-fallback-en.md` / `-ko.md`; Standard tees its score to `.harness-eval/run/standard-score.json` before saving
- When nothing could be scored, the synthesizer ends with `SCORE: none` and a `NOTE:` line, and the orchestrator reports that rather than a failed history save. When the synthesizer stops before reporting, the orchestrator checks `record.json` against the last history entry to tell the user whether the run was saved. The badge note is left out for a run that was not saved
- Full mode tells the user in one line what each of Phases 1-3 runs when it starts and in one line what it produced when it ends, failure markers and fallbacks included, because the scripts' and subagents' work is otherwise invisible for several minutes
- The synthesizer takes the Score History trend from the last five Full runs and shows the last five runs of any mode, labelled by mode, for context, so newer Standard runs no longer push the earlier Full runs out of the trend
- Full history records add `categories`, `status`, and `missing`; `history.sh` and `badge.sh` read the records as before. The Full overall score ranges from 0.0 to 10.0
- Every static-analysis run now has at least two more Correctness entries (`model-config`, `agent-format`), so Basic Quality scores and history trends can step at this release. In a plugin or marketplace repository, the plugin's own agents, skills, and commands are now checked as well
- Cost Efficiency rubric (safety-evaluator, framework §2.7): judge each component's model and effort by cost per completed task, with effort as the first lever; recommend lowering effort before a smaller model; thinking caps are not cost controls on always-thinking models; models without effort support (Claude Haiku 4.5, and Claude Sonnet 4.5, which `sonnet` selects on Bedrock, Vertex, and Foundry) are judged by model choice alone
- The Cost Efficiency rubric reports which effort pins a project-level `env.CLAUDE_CODE_EFFORT_LEVEL` in settings overrides, and safety-evaluator judges a skill's or command's `allowed-tools` as a pre-approval list (an unscoped `Bash` there runs every shell command without a prompt) rather than as a restriction
- Evaluator recommendations name their dimension and expected gain, and the synthesizer copies them into the roadmap verbatim, with no overall-score arithmetic in prose. A Safety item estimates the safety-evaluator's supplementary Safety score and is labelled that way
- safety-evaluator no longer re-scores emphasis density, thinking-steering prose, or step-by-step fit, which Context Management and Actionability score. Its deny-list guidance no longer treats writes under `/etc/` as a command prefix to deny; it credits `Edit(...)` deny rules, Claude Code's path checks, or a `PreToolUse` hook instead. completeness-evaluator treats `allowed-tools` as a pre-approval list, not a restriction
- The three evaluators leave `.harness-eval/`, `.git/`, and `node_modules/` out of their own Glob and Grep scans, so earlier reports that quote scored patterns are not scored again
- design-evaluator judges CLAUDE.md size by content, using Claude Code's memory-file warning threshold (about 5% of the context window, at least about 40,000 characters) instead of fixed line counts
- Standard mode saves history right after scoring, before writing its reports, and names the reports by the saved ID (`{id}-standard-{en|ko}.md`; `eval-{date}-unsaved-standard-…` if the save fails). It prepares `.harness-eval/run/` before scoring, and its Correctness summary lists `model-config` and `agent-format`
- Compare mode notes when the two evaluations use different modes, omits the per-tier table when a Full record is involved, shows per-tier pass rates in %, and names its report `{current.id}-compare-{en|ko}.md`
- Mode commands read `skills/<mode>/SKILL.md` by path instead of invoking the same-named skill, and carry the routing text in their `description`, which is the one Claude Code shows for the shared name. Because `${CLAUDE_PLUGIN_ROOT}` is not substituted in a file read with the Read tool, they tell the model the plugin's path to use in the commands it runs and in any command it shows the user
- Agent and skill prompts are rewritten as plain statements with reasons (stacked emphasis and "be thorough" boosters removed)
- The collector writes its inventory to a file, records each skill's, command's, and agent's `model`, `effort`, and tool fields, scans plugin roots' `hooks/`, `skills/`, `agents/`, and `commands/`, and counts files with `git ls-files` or a pruned `find`
- Dev harness: `/review` and the code-review skill report every issue with severity and confidence (75+ first), and by default `/review`, the code-review skill, and the code-reviewer agent review all uncommitted work (`git status --short --untracked-files=all`, `git diff HEAD`, and each untracked file read in full); `/test-all` and `/deploy` run the test runner once and report its numbers; the release skill follows `plugins/harness-eval/docs/runbooks/release.md` and is user-invoked only (`disable-model-invocation: true`); `/deploy`, the sync-docs skill, and the release skill treat the README version badge as a fourth version location next to the three manifests
- `harness-run-all.sh` runs four evaluation-script suites (adds `test-aggregate`) and the plugin Stop hook tests

### Fixed

- Fix Full mode running `badge.sh` unconditionally, which rewrote the target's README.md even though the Stop-hook badge is opt-in; no mode runs it now
- Fix Full-mode history ownership: both the synthesizer and the orchestrator had a save step ("if not already done"), and the scoring JSON was re-typed through `echo`; the synthesizer now saves `record.json` once, by file redirect
- Fix report names that were meant to match a history ID that did not exist yet: Standard wrote its reports before saving history, and Quick never saves history. Standard now saves first; Quick uses a per-day counter (highest `NNN` + 1), so a second Quick run on the same day no longer overwrites the first
- Fix the Standard `--static-only` instruction to run "Phase 1 and Phase 3 only", which also skipped the report and history steps; it now skips only the dynamic-analysis phase
- Fix the dev agents `.claude/agents/code-reviewer.yml` and `security-auditor.yml`, which Claude Code never loaded (only `.md` agents load); they are now `.md` agents at `opus` / `medium`
- Fix the router's `argument-hint`, which YAML parsed as a list because it was unquoted
- Fix the advice to run `claude init`, which does not exist, and `/review`'s advice to run `/init-project`, a third-party plugin command; Quick, Standard, and `/review` now point to `/init` in a Claude Code session
- Fix the collector counting files with Glob, which returns at most 100 paths and includes ignored directories
- Fix the subagent dispatch wording: the tool is `Agent` (`Task` is its legacy alias and still works in `allowed-tools`)
- Fix the framework's expected deny-list answer, which listed pipe-to-shell even though a `Bash(...)` deny rule cannot match it; that defense belongs in a `PreToolUse` hook
- Fix the Stop hook's 5-minute window, which could miss an evaluation whose response ended more than five minutes after the history save: the hook now handles each saved evaluation once (a `latest.json` newer than its `.harness-eval/.badge-seen` marker and less than a day old). A failed opted-in badge update now exits 1, so Claude Code shows the error
- Fix the README update instructions: `claude plugin marketplace refresh` and `/plugin marketplace refresh` do not exist. The README now gives `claude plugin marketplace update harness-eval` and `claude plugin update harness-eval@harness-eval`, or `/plugin marketplace update harness-eval` inside a session
- Fix static analysis reading CRLF frontmatter, which `frontmatter-consistency` misreported; a block without a closing `---` now counts as no frontmatter
- Fix re-runs that write a report name that already exists (Compare, Standard's and the Full fallback's `unsaved` names, and the synthesizer's `unsaved-full` names): the component that writes the file reads the existing one before overwriting it, because the Write tool refuses to overwrite a file it has not read
- Fix documentation that described the Stop hook as running at session end and as printing a visible notice without opt-in, and SECURITY.md's claim that the target's `.harness-eval/` was already gitignored
- Fix the framework's report example (§5.2), which used Strong/Good/Weak status labels; it now shows the synthesizer's `pass` / `warn` / `fail` values and section layout
- Fix the developer onboarding rules that every script takes `$1` (`aggregate.sh` takes no arguments) and that empty script output means `HARNESS_EVAL_ROOT` is unset
- Fix intermittent false results from `echo … | grep -q` and `echo … | head` under `set -o pipefail`: when `grep -q` or `head` stopped reading early, the writer got SIGPIPE and the pipeline failed. The test runner's helpers and the secret-pattern tests failed checks that had matched, and `static-analysis.sh` could report a present frontmatter `description` as missing; they now read here-strings
- Fix badge updates on macOS: `badge.sh` passed the multi-line badge block to awk with `-v`, which BSD awk rejects ("newline in string"), so every update after the first badge failed and the error blamed a malformed README. The block now goes through `ENVIRON`, and an awk failure is reported as such rather than as a malformed badge block; both exit 2 and leave README.md unchanged
- Fix `harness-run-all.sh` stopping at a suite that exits without a `Results:` line: under `set -o pipefail` the summary `grep` ended the runner before it printed the diagnostics or the summary. It now records a FAIL with the suite's exit code and the last 15 lines of its output and moves on, and a missing `tests/hooks/` or `tests/structure/` directory is a FAIL instead of being skipped silently
- Fix the collector inventorying every `.md` file under a skills directory as a skill: it now counts only `<skills dir>/<name>/SKILL.md`, the file Claude Code loads, and lists the other files as supporting or not-loaded files without model or effort, so a supporting file's frontmatter is not judged as skill configuration

### Removed

- Remove Full mode's single-file bilingual report split on `<!-- LANG:KO -->`; the synthesizer writes one file per language
- Remove the static-analysis and scoring JSON from the collector's prompt (the collector never used them)
- Remove the fixed item counts on Quick "Next Steps" (3-5) and the Standard roadmap (5-10)
- Remove hard-coded test totals from the dev commands and the release skill
- Remove the plugin `CLAUDE.md` rule that created ADRs, runbooks, and CLAUDE.md files automatically after every Plan-mode exit; ADRs and runbooks are written for real decisions and procedures, or on request

### Security

- `history.sh save` refuses to write (exit 2) when `.harness-eval/`, `history.json`, or `latest.json` is a symlink (a dangling one included) or the wrong kind of file, and writes each file through a temporary file, which takes the permissions of the file it replaces, and a rename. A repository cannot redirect these writes outside the project, a failed `jq` step cannot truncate a file, and a `history.json` or `latest.json` restricted with `chmod 600` stays restricted
- `badge.sh` refuses a symlinked or non-regular `README.md` (exit 2) and rewrites the README through a `mktemp` file instead of the fixed name `README.md.tmp`, which a committed link could redirect
- The Stop hook ignores a `.harness-eval/`, `latest.json`, `config.json`, or `.badge-seen` that is a symlink, and a `latest.json` tracked by git; a git-tracked `config.json` no longer counts as opt-in. Files committed to a repository can no longer trigger a README write on the user's behalf
- `.harness-eval/` now ignores itself in git after a Standard or Full run: their run-directory step and `history.sh save` create `.harness-eval/.gitignore` (`*`) when there is none, and leave an existing file or link alone (Quick does not create it)
- The collector's artifact lists settings `env` keys but quotes the values only for model, provider, effort, thinking, and output-limit settings, and it replaces credential-shaped strings elsewhere with `<redacted>`, because the artifact is saved in the project
- The synthesizer's prompt names the only Bash commands it runs and limits its writes to `.harness-eval/`. SECURITY.md now lists those commands, describes the `.gitignore`, and states that the harness-eval commands, `/harness-eval:full` and `/harness-eval:standard` included, pre-approve the Bash commands their orchestrator runs
- The three evaluators and the synthesizer cite a credential or other secret value by `file:line` and write `<redacted>` in its place, so a finding about a hard-coded secret does not copy the secret into the reports

## [0.2.0] - 2026-07-10

Remediation release: a multi-dimension review with adversarial verification found
61 confirmed defects + 5 design gaps; this release addresses all of them. The test
suite runs 190 checks via `harness-run-all.sh` and `claude plugin validate` exits 0.

### Added

- Add CI workflow (`.github/workflows/ci.yml`) running all test suites, `bash -n`, JSON validation, and shellcheck on every push/PR
- Add `CONTRIBUTING.md`, `SECURITY.md`, and a release runbook (`docs/runbooks/release.md`)
- Add version-consistency test (manifests must agree) and a nested-schema hook-file-mapping regression fixture
- Add Standard-mode trust-boundary confirmation gate and `--static-only` path (dynamic analysis runs target code)
- Add bilingual report output — all evaluations generate separate English and Korean reports
- Save reports to `.harness-eval/reports/eval-{date}-{NNN}-{mode}-{en|ko}.md` in target project
- Add individual mode slash commands: `/harness-eval:quick`, `/harness-eval:standard`, `/harness-eval:full`, `/harness-eval:compare`
- Add `argument-hint: [quick|standard|full|compare]` to main command for UI visibility
- Add marketplace support — install via `claude plugin marketplace add https://github.com/whchoi98/harness-eval`
- Add harness validation test suite (`tests/harness-run-all.sh` with hook and structure test categories)
- Add root-level monorepo documentation (`docs/architecture.md`, `docs/onboarding.md`) and scripts (`scripts/setup.sh`, `scripts/install-hooks.sh`)

### Changed

- **BREAKING:** Restructure as marketplace + plugin monorepo — plugin files moved to `plugins/harness-eval/`
- **BREAKING:** Adopt Claude Code auto-discovery convention — `plugin.json` contains metadata only, skills use `skills/<name>/SKILL.md` format, hooks registered via `hooks/hooks.json`
- Unify the evaluation model on the 12-dimension / 3-category taxonomy (Basic Quality 0.50, Operational 0.25, Design Quality 0.25) across `harness-evaluation-framework.md` and `agents/synthesizer.md` (framework doc previously described a 6-dimension / component-weight model)
- Make the Stop-hook README badge write opt-in (`HARNESS_EVAL_AUTO_BADGE`) instead of silently editing README on every session end
- Full-mode bilingual reports split on the `<!-- LANG:KO -->` token instead of an ambiguous `---`

### Fixed

- Fix arbitrary-command execution (RCE) in `badge.sh`: the untrusted `.scores.overall` from a target project's `latest.json` was interpolated into an `awk` program; it is now validated numeric and passed via `awk -v`
- Fix all 5 agents' frontmatter tool-restriction field (`allowed-tools` -> `tools`; `allowed-tools` is ignored on subagents) and drop the non-existent `LS` tool — read-only evaluators are now actually read-only
- Fix `static-analysis.sh` hook-file-mapping producing false FAILs on the real (nested) Claude Code settings schema — now supports both nested and flat schemas and skips interpreter tokens when extracting the script path
- Fix Full-mode scoring contract: unify grade thresholds to `scripts/scoring.sh` (the single source of truth), align the history/`latest.json` storage schema to what `badge.sh`/`history.sh` consume, and derive Basic Quality from `static-analysis` per-category scores
- Fix the release toolchain (`/deploy`, `/test-all`, release skill) referencing the non-existent `tests/run-all.sh` and a wrong `plugin.json` path
- Remove auto-discovery pollution: `commands/CLAUDE.md` and `agents/CLAUDE.md` registered as bogus frontmatter-less components; content moved into the plugin-root `CLAUDE.md`
- Fix `scripts/scoring.sh` recursive glob to prune `.git`/`node_modules`/`vendor`/`.venv`/`.harness-eval`, and guard checklist tiers with no `items`
- Fix `history.sh` unbound-variable crash on a non-numeric `list --last` argument
- Fix `.claude/settings.json` deny list: remove the `curl * | bash` and `wget * | bash` rules — Claude Code matches `Bash(...)` deny rules by command prefix and decomposes pipelines into segments, so a mid-pattern `*` before a pipe never matches and these rules could never fire. Pipe-to-shell defense belongs in a `PreToolUse` hook, not a permission rule. Kept and expanded the rules that do work as prefixes (`rm -rf`/`rm -fr`/`rm -r`, `git push --force`/`-f`, `git reset --hard`, `git clean -f`, `chmod 777`, `eval`, `python3 -c`)
- Fix `secret-scan.sh` so it can actually block: exit code `2` on detection (Claude Code treats only exit 2 as a PreToolUse block), removed the `2>/dev/null || true` wrapper in `settings.json` that forced exit 0, NUL-delimited staged-file iteration, a rewritten AWS-secret-key pattern (the old variable-length look-behind failed to compile under `grep -P`), and a skip-list that now matches basenames and excludes the scanner's own pattern/test corpus
- Fix dev hooks that read non-existent env vars (`$TOOL_INPUT`, `$TOOL_INPUT_PATH`, `$EVENT`, `$MESSAGE`) — Claude Code delivers hook data as JSON on stdin, so the hooks now parse stdin (with positional-arg fallback)
- Fix portability: GNU-only `sed -i` in `install-hooks.sh` (broke commits on macOS/BSD) and the hardcoded relative `.git/hooks` path (broke in the monorepo)
- Fix hook event matcher in `.claude/settings.json` (`PreCommit` is not a valid event; corrected to `PreToolUse`)

## [0.1.0] - 2026-04-06

### Added

- Add 3-tier evaluation system: Quick (checklist), Standard (static + dynamic analysis), Full (multi-agent review)
- Add checklist-based scoring engine with 16 check items across 4 maturity tiers
- Add static analysis script for bash syntax, JSON validity, file permissions, and registration consistency checks
- Add evaluation history tracking with save, list, and compare operations
- Add badge generation (A+ through F) in SVG and Markdown formats
- Add multi-agent Full evaluation with 5 specialized agents: collector, safety-evaluator, completeness-evaluator, design-evaluator, synthesizer
- Add `/harness-eval` slash command as unified evaluation entry point
- Add post-evaluation badge hook triggered on Stop event
- Add compare skill for side-by-side evaluation history analysis
- Add 4-level test fixtures for score validation: minimal, functional, robust, production

### Fixed

- Fix `--mode` flag parsing to handle missing value argument gracefully
- Fix missing `quick.md` placeholder referenced by plugin.json manifest

[Unreleased]: https://github.com/whchoi98/harness-eval/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.3.0
[0.2.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.2.0

<!-- 0.1.0 predates tagging and is intentionally left without a link. -->

---

# 한국어

이 프로젝트의 모든 주요 변경 사항은 이 파일에 기록됩니다.
이 문서는 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [Unreleased]

## [0.3.0] - 2026-09-24

Claude Opus 5.5에 맞춘 튜닝 릴리스다. Full 모드의 모든 에이전트가 모델 alias와 effort를 직접 지정하고, Full 모드는 단계 사이의 데이터를 파일로 넘기며 점수를 스크립트로 계산한다. 정적 분석은 모델·effort 설정도 검사한다. `harness-run-all.sh` 기준 447개 체크를 실행한다.

### Added

- `scripts/aggregate.sh` 추가 — Full 모드의 결정론적 채점. 12개 차원 점수를 stdin JSON으로 받아 카테고리별로 점수가 있는 차원만 평균하고, 0.50 / 0.25 / 0.25 가중치를 점수가 있는 카테고리끼리 재정규화해 적용한 뒤, 정본 history 레코드(`scores`, `dimensions`, `categories`, 차원별 `status`, `missing`)를 출력
- `scripts/lib/grade.sh`(`score_to_grade`) 추가 — 등급 임계값의 유일한 정의로, `scoring.sh`와 `aggregate.sh`가 함께 source함 (`scoring.sh` 출력은 그대로)
- 정적 체크 `model-config`(Correctness) 추가 — `.claude/`의 에이전트·커맨드와 `.claude/skills/<name>/SKILL.md`, 각 플러그인 루트(`.claude-plugin/plugin.json`이 있는 대상 루트 또는 `plugins/*/`) 아래의 같은 구성 요소에서 `model:`/`effort:` frontmatter를 읽고, settings에서는 `model`, `effortLevel`, `alwaysThinkingEnabled`, `env.MAX_THINKING_TOKENS`, `env.CLAUDE_CODE_EFFORT_LEVEL`, `env.CLAUDE_CODE_DISABLE_THINKING`, `env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`, `env`의 모델 키(`*_MODEL`, `*_MODEL_FORCE`, `*_MODEL_OPTION`)를 읽음. 은퇴 모델은 FAIL(Bedrock `claude-v1`/`claude-v2`와 Claude 1.x 포함). deprecated 모델(Foundry ID `claude-opus-4`·`claude-sonnet-4` 포함), Anthropic API 형식의 날짜 스냅샷 ID(날짜가 붙은 Bedrock·Vertex ID는 유효한 지정), 제공 중인 모델 ID 목록에 없는 `claude-*` ID(목록이 제공 중인 ID를 하나씩 나열하므로 `claude-opus-55` 같은 오타나 출시된 적 없는 `claude-sonnet-4-7`도 현행 ID로 통과하지 않음), Claude가 아닌 모델명, 잘못된 effort 값(settings `effortLevel`은 `low`/`medium`/`high`/`xhigh`만 허용), 설정된 `env.CLAUDE_CODE_EFFORT_LEVEL`(Claude Code가 받아들이는 값이면 frontmatter에 고정한 effort까지 모든 에이전트·스킬·커맨드의 effort를 덮어쓰고, 그 밖의 값은 무시됨), thinking 상한(`alwaysThinkingEnabled: false`, `MAX_THINKING_TOKENS`, 켜진 `CLAUDE_CODE_DISABLE_*THINKING` 플래그)은 WARN. 단 thinking 상한은 settings가 thinking을 끌 수 있는 모델을 지정하면 제외하며, 이 모델은 날짜를 뗀 ID로 비교하므로 Claude Opus 5의 Bedrock·Vertex 표기도 `claude-opus-5`처럼 제외됨
- 정적 체크 `agent-format`(Correctness) 추가 — Claude Code가 로드하지 않는 `.claude/agents/`와 각 플러그인 루트 `agents/`의 `*.yml|yaml|json` 파일을 WARN
- `tests/test-aggregate.sh`(74개 테스트), `tests/hooks/test-plugin-hooks.sh`(플러그인 Stop 훅과 `badge.sh`의 README 보호 장치 검사 33개), `tests/fixtures/model-era-project/` 픽스처 추가. `test-static-analysis.sh`는 26개에서 107개로, `test-history.sh`는 19개에서 38개로 증가
- 구조 테스트 추가 — 플러그인·개발용 에이전트는 모두 frontmatter에 `name`, `description`, `model`, `effort`를 두고, `model`은 alias나 제공 중인 모델 ID, `effort`는 허용된 level이나 정수여야 함(둘 다 `static-analysis.sh`의 테이블에서 읽음). 개발용 스킬은 모두 `description`을 두고, `.yml`/`.yaml` 에이전트 파일은 없어야 하며, 이 저장소에 `static-analysis.sh`를 실행하면 `model-config`와 `agent-format`이 PASS여야 함
- 구조 스위트에 Full 모드 계약 검사 추가 — `ARTIFACT_WRITTEN`, `EVAL_ID` / `REPORT_EN` / `REPORT_KO` / `SCORE` / `MISSING`, `SCRIPT_FAILED`, `AGENT_FAILED` 문자열이 만드는 쪽과 읽는 쪽에 모두 있는지, `subagent_type` 이름, 각 evaluator `## Scores`의 차원 이름과 synthesizer의 일치, synthesizer heredoc 키(`aggregate.sh`로 실제 실행)를 검사
- 루브릭 항목 추가 — completeness-evaluator "Prescription Matched to Fragility"("Skill Structure" 대체)와 "Prompt and Agent Checks", design-evaluator "Delegation Fit", "Instruction Fit for Current Models"(사고 제어 문구와 "don't think" 규칙, thinking을 끈 Claude Opus 5용 완화 문구, 일괄 서식 금지 규칙 같은 낡은 패턴), "Model-Change Resilience", safety-evaluator "Delegation and Model-Call Cost"
- `/harness-eval:standard`에 `argument-hint: "[--static-only]"` 추가, `/harness-eval` 라우터는 모드 뒤의 옵션을 해당 모드에 그대로 전달
- ADR-003(에이전트별 모델·effort, Full 모드 파일 handoff, Claude Opus 5.5에서 측정한 모드별 실행 시간과 비용)과 README "모델과 effort" 절 추가
- 모델 교체 런북(`plugins/harness-eval/docs/runbooks/model-change.md`) 추가 — Claude 모델 라인이 바뀔 때 다시 점검할 항목(에이전트·스킬·커맨드의 프롬프트 감사, 에이전트별 모델·effort, static-analysis 모델 테이블과 model-era 픽스처)에 이어 테스트 스위트를 실행하고, 픽스처 사본에서 라이브 실행한 시간과 비용을 기록하는 절차

### Changed

- **모델과 effort:** Full 모드 에이전트 5개 모두 `model: opus`에 effort를 명시 — collector `low`, completeness-evaluator `medium`, design-evaluator `medium`, safety-evaluator `high`, synthesizer `medium`. 기존에는 collector·completeness-evaluator·synthesizer가 `sonnet`이었고 effort를 지정한 에이전트가 없어 평가 깊이가 사용자 세션 effort를 따라갔음. Full 스킬은 모델과 effort를 각 에이전트 frontmatter에 맡김. `CLAUDE_CODE_EFFORT_LEVEL`(`auto`·`unset` 포함)과 settings 또는 조직이 정한 effort 상한은 여전히 에이전트 effort보다 우선함(README 참조). `quick`과 `compare` 커맨드는 `effort: low`로 실행되고, `/harness-eval` 라우터는 기본 quick을 포함한 모든 모드를 세션 effort로 실행
- **Full 모드 데이터 흐름:** Phase 1에서 정적 분석과 채점을 병렬로 실행해 결과를 `<project>/.harness-eval/run/`에 기록하고, collector는 같은 곳에 `artifact.md`를 쓴 뒤 경로를 반환하며, evaluator는 그 파일들을 경로로 읽고, 오케스트레이터는 evaluator의 최종 메시지를 synthesizer에 그대로 전달함. synthesizer는 `aggregate.sh`로 채점하되 거부된 입력이 파이프에 가려지지 않도록 출력을 `record.json`으로 리다이렉트하고, 정상 경로에서 history를 저장하는 유일한 컴포넌트이며, `<EVAL_ID>-full-en.md`와 `<EVAL_ID>-full-ko.md`를 직접 작성
- collector가 실패하면 Full은 이제 Standard 체크리스트 점수를 history에 저장하고(mode `standard`) `<EVAL_ID>-full-fallback-en.md` / `-ko.md`를 작성함. Standard는 저장 전에 점수를 `.harness-eval/run/standard-score.json`에 tee함
- 채점할 것이 전혀 없으면 synthesizer는 `SCORE: none`과 `NOTE:` 줄로 끝내고, 오케스트레이터는 history 저장 실패가 아니라 그 사실을 알림. synthesizer가 보고 전에 멈추면 오케스트레이터가 `record.json`과 마지막 history 항목을 대조해 저장 여부를 알려 줌. 저장되지 않은 실행에는 뱃지 안내를 붙이지 않음
- Full 모드는 Phase 1-3 각각이 시작할 때 무엇을 실행하는지, 끝날 때 무엇을 만들었는지(실패 마커와 fallback 포함)를 사용자에게 한 줄씩 알림. 그러지 않으면 스크립트와 서브에이전트가 일하는 몇 분 동안 사용자에게 아무것도 보이지 않기 때문임
- synthesizer는 Score History의 추세를 최근 Full 실행 5개로 판단하고, 모드와 관계없는 최근 실행 5개를 모드 표시와 함께 맥락으로 보여 줌. 그래서 뒤따른 Standard 실행이 이전 Full 실행을 추세에서 밀어내지 않음
- Full history 레코드에 `categories`, `status`, `missing` 추가 — `history.sh`와 `badge.sh`는 기존과 같이 읽음. Full overall 점수의 범위는 0.0–10.0
- 모든 정적 분석 실행에 Correctness 항목이 최소 2개(`model-config`, `agent-format`) 늘어나므로, 이 릴리스를 기점으로 기본 품질 점수와 history 추세가 계단식으로 달라질 수 있음. 플러그인·마켓플레이스 저장소에서는 플러그인 자체의 에이전트·스킬·커맨드도 이제 검사 대상임
- 비용 효율성 루브릭(safety-evaluator, framework §2.7) — 구성 요소마다 모델과 effort를 완료 작업당 비용으로 판단하고 effort를 1차 레버로 봄. 작은 모델보다 effort 하향을 먼저 권고하며, thinking 상한은 thinking이 항상 켜진 모델에서 비용 통제 수단이 아님. effort를 지원하지 않는 모델(Claude Haiku 4.5, 그리고 Bedrock·Vertex·Foundry에서 `sonnet`이 가리키는 Claude Sonnet 4.5)은 모델 선택만으로 판단
- 비용 효율성 루브릭은 settings의 프로젝트 수준 `env.CLAUDE_CODE_EFFORT_LEVEL`이 어떤 effort 고정값을 덮어쓰는지 보고하고, safety-evaluator는 스킬·커맨드의 `allowed-tools`를 제한이 아니라 사전 승인 목록으로 판단함(그곳의 범위 없는 `Bash`는 모든 셸 명령을 확인 없이 실행함)
- evaluator 권고에 차원과 예상 이득을 명시하고, synthesizer는 이를 로드맵에 그대로 옮기며 overall 점수 산술은 산문에 쓰지 않음. Safety 항목은 safety-evaluator의 보조 Safety 점수 기준이며 그렇게 표시함
- safety-evaluator는 강조어 밀도, 사고 제어 문구, 단계별 지시의 적합성을 다시 채점하지 않음(각각 컨텍스트 관리와 실행 가능성이 채점). deny 목록 안내는 `/etc/` 아래 쓰기를 deny할 명령 prefix로 보지 않고, `Edit(...)` deny 규칙, Claude Code의 경로 검사, `PreToolUse` 훅을 대신 인정함. completeness-evaluator는 `allowed-tools`를 제한이 아니라 사전 승인 목록으로 봄
- 세 evaluator는 자체 Glob·Grep 스캔에서 `.harness-eval/`, `.git/`, `node_modules/`를 제외함. 채점 대상 패턴을 인용한 이전 보고서가 다시 채점되지 않도록 하기 위함
- design-evaluator는 CLAUDE.md 크기를 고정 줄 수 대신 내용으로 판단하고, Claude Code의 메모리 파일 경고 기준(context window의 약 5%, 최소 약 40,000자)을 사용
- Standard 모드는 채점 직후, 보고서를 쓰기 전에 history를 저장하고 저장된 ID로 보고서 이름을 정함(`{id}-standard-{en|ko}.md`, 저장 실패 시 `eval-{date}-unsaved-standard-…`). 채점 전에 `.harness-eval/run/`을 준비하며, Correctness 요약에 `model-config`와 `agent-format`을 포함함
- Compare 모드는 두 평가의 모드가 다르면 알리고, Full 레코드가 포함되면 tier별 표를 생략하며, tier별 통과율을 %로 표시하고, 보고서 이름을 `{current.id}-compare-{en|ko}.md`로 정함
- 모드 커맨드는 같은 이름의 스킬을 호출하지 않고 `skills/<mode>/SKILL.md`를 경로로 읽으며, 라우팅 문구는 커맨드 `description`에 둠(이름이 겹치면 Claude Code는 커맨드의 description을 보여 줌). Read 도구로 읽은 파일에서는 `${CLAUDE_PLUGIN_ROOT}`가 치환되지 않으므로, 실행하는 명령과 사용자에게 보여 주는 명령에 쓸 플러그인 경로를 모델에 알려 줌
- 에이전트·스킬 프롬프트를 이유가 붙은 평이한 문장으로 재작성(겹친 강조와 "be thorough"류 부스터 제거)
- collector는 인벤토리를 파일로 쓰고, 스킬·커맨드·에이전트의 `model`, `effort`, 도구 필드를 기록하며, 플러그인 루트의 `hooks/`, `skills/`, `agents/`, `commands/`를 스캔하고, 파일 수는 `git ls-files` 또는 prune한 `find`로 셈
- 개발 하네스 — `/review`와 code-review 스킬은 모든 이슈를 severity·confidence와 함께 보고(75 이상 먼저)하며, `/review`, code-review 스킬, code-reviewer 에이전트는 기본적으로 커밋되지 않은 작업 전체를 리뷰함(`git status --short --untracked-files=all`, `git diff HEAD`, untracked 파일은 전체를 읽음). `/test-all`과 `/deploy`는 테스트 러너를 한 번 실행하고 그 수치를 보고, release 스킬은 `plugins/harness-eval/docs/runbooks/release.md`를 따르며 사용자만 호출 가능(`disable-model-invocation: true`). `/deploy`, sync-docs 스킬, release 스킬은 README 버전 뱃지를 매니페스트 세 곳에 이은 네 번째 버전 위치로 다룸
- `harness-run-all.sh`가 평가 스크립트 스위트 4개(`test-aggregate` 추가)와 플러그인 Stop 훅 테스트를 실행

### Fixed

- Full 모드가 `badge.sh`를 무조건 실행해, Stop 훅 뱃지가 opt-in인데도 대상 프로젝트의 README.md를 다시 쓰던 문제 수정 — 이제 어떤 모드도 실행하지 않음
- Full 모드 history 저장 주체 수정 — synthesizer와 오케스트레이터 모두에 저장 단계가 있었고("if not already done") 채점 JSON을 `echo`로 다시 타이핑했음. 이제 synthesizer가 `record.json`을 파일 리다이렉트로 한 번만 저장
- 아직 존재하지 않는 history ID에 맞춰야 했던 보고서 이름 수정 — Standard는 history 저장 전에 보고서를 썼고 Quick은 history를 저장하지 않음. 이제 Standard는 먼저 저장하고, Quick은 하루 단위 카운터(가장 큰 `NNN` + 1)를 써서 같은 날 두 번째 Quick 실행이 첫 보고서를 덮어쓰지 않음
- Standard `--static-only` 지시문이 "Phase 1과 Phase 3만" 실행하라고 해서 보고서와 history 단계까지 건너뛰던 문제 수정 — 이제 동적 분석 단계만 건너뜀
- Claude Code가 로드한 적 없는 개발용 에이전트 `.claude/agents/code-reviewer.yml`·`security-auditor.yml` 수정(`.md` 에이전트만 로드됨) — `opus` / `medium`의 `.md` 에이전트로 전환
- 따옴표가 없어 YAML이 리스트로 파싱하던 라우터 `argument-hint` 수정
- 존재하지 않는 `claude init`과 서드파티 플러그인 커맨드인 `/init-project`(`/review`)를 안내하던 문구 수정 — Quick, Standard, `/review`는 Claude Code 세션의 `/init`을 안내
- collector가 Glob으로 파일 수를 세던 문제 수정 — Glob은 최대 100개 경로만 반환하고 무시된 디렉터리까지 포함함
- 서브에이전트 호출 도구 이름 수정 — 도구 이름은 `Agent`이며 `Task`는 legacy alias로 `allowed-tools`에서 계속 동작
- framework의 deny 목록 기대 답변이 `Bash(...)` deny 규칙으로 매칭할 수 없는 pipe-to-shell을 포함하던 것 수정 — 이 방어는 `PreToolUse` 훅의 몫
- Stop 훅의 5분 창 때문에 history 저장 후 5분이 넘어 끝난 응답의 평가를 놓칠 수 있던 문제 수정 — 이제 저장된 평가마다 한 번 처리함(`latest.json`이 `.harness-eval/.badge-seen` 표식보다 새롭고 하루가 지나지 않은 경우). opt-in한 뱃지 갱신이 실패하면 이제 exit 1로 끝나므로 Claude Code가 오류를 보여 줌
- README 업데이트 안내 수정 — `claude plugin marketplace refresh`와 `/plugin marketplace refresh`는 존재하지 않음. 이제 `claude plugin marketplace update harness-eval`과 `claude plugin update harness-eval@harness-eval`, 세션 안에서는 `/plugin marketplace update harness-eval`을 안내
- 정적 분석이 CRLF frontmatter를 잘못 읽어 `frontmatter-consistency`가 오보고하던 문제 수정. 닫는 `---`가 없는 블록은 이제 frontmatter가 없는 것으로 봄
- 이미 있는 보고서 이름으로 다시 쓰는 실행(Compare, Standard와 Full fallback의 `unsaved` 이름, synthesizer의 `unsaved-full` 이름) 수정 — Write 도구는 읽지 않은 파일을 덮어쓰지 않으므로, 파일을 쓰는 컴포넌트가 기존 파일을 먼저 읽은 뒤 덮어씀
- Stop 훅이 세션 종료 시 실행되고 opt-in이 없으면 보이는 안내를 출력한다고 설명하던 문서와, 대상 프로젝트의 `.harness-eval/`이 이미 gitignore되어 있다던 SECURITY.md 설명 수정
- framework 보고서 예시(§5.2)가 Strong/Good/Weak 상태 표기를 쓰던 것 수정 — 이제 synthesizer 보고서의 `pass` / `warn` / `fail` 값과 섹션 구성을 보여 줌
- 모든 스크립트가 `$1`을 받는다는 개발자 온보딩 규칙(`aggregate.sh`는 인자를 받지 않음)과 스크립트 출력이 비면 `HARNESS_EVAL_ROOT` 미설정이 원인이라는 안내 수정
- `set -o pipefail`에서 `echo … | grep -q`와 `echo … | head`가 간헐적으로 틀린 결과를 내던 문제 수정 — `grep -q`나 `head`가 일찍 읽기를 멈추면 쓰는 쪽이 SIGPIPE를 받아 파이프라인이 실패했음. 테스트 러너 헬퍼와 secret 패턴 테스트가 매치된 체크를 실패로 처리했고, `static-analysis.sh`는 있는 frontmatter `description`을 없다고 보고할 수 있었음. 이제 here-string으로 읽음
- macOS에서 뱃지 갱신이 실패하던 문제 수정 — `badge.sh`가 여러 줄 뱃지 블록을 `awk -v`로 넘겼는데 BSD awk는 이를 거부하므로("newline in string"), 첫 뱃지 추가 이후의 갱신이 모두 실패하고 오류 메시지는 README가 malformed라고 잘못 안내했음. 이제 블록을 `ENVIRON`으로 넘기고, awk 자체의 실패는 뱃지 블록 오류와 구분해 보고함. 두 경우 모두 exit 2로 끝나며 README.md는 그대로 둠
- `Results:` 줄 없이 끝난 스위트에서 `harness-run-all.sh`가 멈추던 문제 수정 — `set -o pipefail`에서 요약 줄을 찾는 `grep`이 실패해, 진단과 최종 요약을 출력하기 전에 러너가 종료했음. 이제 스위트의 종료 코드와 출력 마지막 15줄을 담은 FAIL을 기록하고 다음 스위트로 넘어가며, `tests/hooks/`나 `tests/structure/` 디렉터리가 없으면 조용히 건너뛰지 않고 FAIL로 기록함
- collector가 스킬 디렉터리 안의 모든 `.md` 파일을 스킬로 인벤토리하던 문제 수정 — 이제 Claude Code가 로드하는 `<skills dir>/<name>/SKILL.md`만 스킬로 세고, 나머지 파일은 모델·effort 없이 보조 파일이나 로드되지 않는 파일로 적음. 보조 파일의 frontmatter가 스킬 설정으로 평가되지 않음

### Removed

- Full 모드의 `<!-- LANG:KO -->` 기준 단일 파일 이중 언어 보고서 분할 제거 — synthesizer가 언어별 파일을 하나씩 작성
- collector 프롬프트에서 정적 분석·채점 JSON 제거(collector는 이를 사용하지 않았음)
- Quick "Next Steps"(3-5개)와 Standard 로드맵(5-10개)의 고정 항목 수 제거
- 개발용 커맨드와 release 스킬에 하드코딩된 테스트 총수 제거
- Plan 모드 종료 때마다 ADR·runbook·CLAUDE.md를 자동 생성하게 하던 플러그인 `CLAUDE.md` 규칙 제거 — ADR과 runbook은 실제 결정·절차가 있거나 요청이 있을 때만 작성

### Security

- `history.sh save`는 `.harness-eval/`, `history.json`, `latest.json`이 symlink(끊어진 링크 포함)이거나 종류가 다른 파일이면 쓰지 않고 exit 2로 끝나며, 모든 파일을 임시 파일에 쓴 뒤 rename함. 임시 파일은 바꿀 파일의 권한을 이어받음. 저장소가 이 쓰기를 프로젝트 밖으로 돌릴 수 없고, `jq` 단계가 실패해도 파일이 잘리지 않으며, `chmod 600`으로 좁혀 둔 `history.json`·`latest.json`도 저장 뒤에 그대로 유지됨
- `badge.sh`는 symlink이거나 일반 파일이 아닌 `README.md`를 거부하고(exit 2), 커밋된 링크가 가로챌 수 있는 고정 이름 `README.md.tmp` 대신 `mktemp` 파일을 거쳐 README를 다시 씀
- Stop 훅은 symlink인 `.harness-eval/`·`latest.json`·`config.json`·`.badge-seen`과 git이 추적하는 `latest.json`을 무시하고, git이 추적하는 `config.json`은 더 이상 opt-in으로 인정하지 않음. 저장소에 커밋된 파일로는 사용자 대신 README 쓰기를 일으킬 수 없음
- Standard·Full 실행 후 `.harness-eval/`이 git에서 스스로를 무시함 — 두 모드의 실행 디렉터리 준비 단계와 `history.sh save`가 `.harness-eval/.gitignore`(`*`)가 없으면 만들고, 이미 있는 파일이나 링크는 건드리지 않음(Quick은 만들지 않음)
- collector 산출물은 settings `env`의 키를 모두 적되 값은 모델·프로바이더·effort·thinking·출력 상한 설정일 때만 인용하고, 그 밖의 credential 형태 문자열은 `<redacted>`로 바꿈. 산출물이 프로젝트 안에 저장되기 때문임
- synthesizer 프롬프트가 실행하는 Bash 명령을 명시하고 쓰기를 `.harness-eval/` 아래로 한정함. SECURITY.md는 이제 그 명령 목록과 `.gitignore`를 설명하고, `/harness-eval:full`과 `/harness-eval:standard`를 포함한 harness-eval 커맨드가 오케스트레이터의 Bash 명령을 미리 승인한다는 점을 밝힘
- 세 evaluator와 synthesizer는 credential 등 secret 값을 `file:line`으로 가리키고 값 자리에는 `<redacted>`를 씀. 하드코딩된 secret에 대한 finding이 그 값을 보고서로 옮기지 않음

## [0.2.0] - 2026-07-10

보강 릴리스: 적대적 검증을 곁들인 다차원 리뷰에서 확정 결함 61건 + 설계 갭 5건을 발견했고, 이 릴리스에서 전부 해소했다. `harness-run-all.sh` 기준 190개 체크를 실행하며 `claude plugin validate`는 exit 0이다.

### Added

- CI 워크플로(`.github/workflows/ci.yml`) 추가 — 모든 테스트 스위트 + `bash -n` + JSON 검증 + shellcheck를 push/PR마다 실행
- `CONTRIBUTING.md`, `SECURITY.md`, 릴리스 런북(`docs/runbooks/release.md`) 추가
- 버전 일관성 테스트(매니페스트 간 일치)와 중첩 스키마 hook-file-mapping 회귀 픽스처 추가
- Standard 모드 신뢰 경계 확인 게이트 및 `--static-only` 경로 추가 (동적 분석은 대상 프로젝트 코드를 실행함)
- 이중 언어 리포트 출력 추가 — 모든 평가가 영어/한국어 별도 리포트 생성
- 대상 프로젝트의 `.harness-eval/reports/eval-{날짜}-{순번}-{모드}-{en|ko}.md`에 리포트 파일 저장
- 개별 모드 슬래시 커맨드 추가: `/harness-eval:quick`, `/harness-eval:standard`, `/harness-eval:full`, `/harness-eval:compare`
- 메인 커맨드에 `argument-hint: [quick|standard|full|compare]` 추가하여 UI에서 옵션 표시
- 마켓플레이스 지원 추가 — `claude plugin marketplace add https://github.com/whchoi98/harness-eval`로 설치
- 하네스 검증 테스트 스위트 추가 (`tests/harness-run-all.sh`, 훅 및 구조 테스트 카테고리 포함)
- 루트 수준 모노레포 문서(`docs/architecture.md`, `docs/onboarding.md`)와 스크립트(`scripts/setup.sh`, `scripts/install-hooks.sh`) 추가

### Changed

- **BREAKING:** 마켓플레이스 + 플러그인 모노레포 구조로 전환 — 플러그인 파일이 `plugins/harness-eval/`로 이동
- **BREAKING:** Claude Code 자동 탐색 컨벤션 적용 — `plugin.json`은 메타데이터만 포함, 스킬은 `skills/<name>/SKILL.md` 형식, 훅은 `hooks/hooks.json`으로 등록
- 평가 모델을 12차원 / 3카테고리 분류(기본 품질 0.50, 운영 0.25, 설계 품질 0.25)로 통일 — `harness-evaluation-framework.md`와 `agents/synthesizer.md` 일치 (기존 framework 문서는 6차원 / 구성요소 가중치 모델을 기술)
- Stop 훅의 README 뱃지 기록을 opt-in(`HARNESS_EVAL_AUTO_BADGE`)으로 변경 — 세션 종료마다 조용히 README를 수정하지 않음
- Full 모드 이중 언어 리포트를 모호한 `---` 대신 `<!-- LANG:KO -->` 토큰으로 분할

### Fixed

- `badge.sh`의 임의 명령 실행(RCE) 수정: 대상 프로젝트 `latest.json`의 신뢰할 수 없는 `.scores.overall`이 `awk` 프로그램에 보간되던 것을 숫자 검증 후 `awk -v`로 전달
- 5개 에이전트 전부 프론트매터 도구 제한 필드 수정(`allowed-tools` -> `tools`; 서브에이전트에서 `allowed-tools`는 무시됨) 및 존재하지 않는 `LS` 도구 제거 — read-only 평가자가 실제로 read-only가 됨
- `static-analysis.sh` hook-file-mapping이 실제(중첩) Claude Code settings 스키마에서 오탐(false FAIL)하던 것 수정 — 중첩·평면 스키마 모두 지원하고 스크립트 경로 추출 시 인터프리터 토큰을 건너뜀
- Full 모드 채점 계약 수정: 등급 임계값을 `scripts/scoring.sh`(단일 정본)로 통일, history/`latest.json` 저장 스키마를 `badge.sh`/`history.sh` 소비자와 일치, Basic Quality를 `static-analysis` 카테고리별 점수에서 도출
- 릴리스 툴체인(`/deploy`, `/test-all`, release 스킬)이 존재하지 않는 `tests/run-all.sh`와 잘못된 `plugin.json` 경로를 참조하던 것 수정
- auto-discovery 오염 제거: `commands/CLAUDE.md`·`agents/CLAUDE.md`가 프론트매터 없는 가짜 컴포넌트로 등록되던 것 — 내용을 플러그인 루트 `CLAUDE.md`로 이동
- `scripts/scoring.sh` 재귀 glob이 `.git`/`node_modules`/`vendor`/`.venv`/`.harness-eval`를 prune하도록 수정, `items` 없는 체크리스트 tier 가드 추가
- `history.sh`의 비숫자 `list --last` 인자에서 발생하던 unbound-variable 크래시 수정
- `.claude/settings.json` deny 목록 수정: `curl * | bash`·`wget * | bash` 규칙 제거 — Claude Code는 `Bash(...)` deny 규칙을 명령 prefix로 매칭하고 파이프라인을 세그먼트로 분해하므로, 파이프 앞의 중간 `*`는 결코 매칭되지 않아 두 규칙은 발동 자체가 불가능했음. pipe-to-shell 방어는 permission 규칙이 아니라 `PreToolUse` 훅에서 처리해야 함. prefix로 실제 동작하는 규칙은 유지·확장(`rm -rf`/`rm -fr`/`rm -r`, `git push --force`/`-f`, `git reset --hard`, `git clean -f`, `chmod 777`, `eval`, `python3 -c`)
- `secret-scan.sh`가 실제로 차단하도록 수정: 탐지 시 exit code `2`(Claude Code는 PreToolUse 차단을 exit 2로만 인식), exit 0을 강제하던 `settings.json`의 `2>/dev/null || true` 래퍼 제거, 스테이징 파일 순회를 NUL 구분으로 변경, `grep -P`에서 컴파일 실패하던 가변 길이 look-behind AWS 시크릿 패턴 재작성, skip 목록이 basename까지 매칭하고 스캐너 자체 패턴/테스트 코퍼스를 제외하도록 개선
- 존재하지 않는 환경변수(`$TOOL_INPUT`, `$TOOL_INPUT_PATH`, `$EVENT`, `$MESSAGE`)를 읽던 개발용 훅 수정 — Claude Code는 훅 데이터를 stdin JSON으로 전달하므로 stdin을 파싱하도록 변경(위치 인자 fallback 포함)
- 이식성 수정: `install-hooks.sh`의 GNU 전용 `sed -i`(macOS/BSD에서 커밋 실패)와 하드코딩된 상대 경로 `.git/hooks`(모노레포에서 실패)
- `.claude/settings.json`의 훅 이벤트 matcher 수정 (`PreCommit`은 유효한 이벤트가 아니므로 `PreToolUse`로 정정)

## [0.1.0] - 2026-04-06

### Added

- 3단계 평가 체계 추가: Quick (체크리스트), Standard (정적+동적 분석), Full (멀티 에이전트 리뷰)
- 4단계 성숙도 기준 16개 체크 항목을 갖춘 체크리스트 기반 점수 산출 엔진 추가
- Bash 문법, JSON 유효성, 파일 권한, 등록 일관성을 검사하는 정적 분석 스크립트 추가
- 저장, 조회, 비교 기능을 갖춘 평가 이력 추적 기능 추가
- SVG 및 Markdown 형식의 뱃지 생성 기능 추가 (A+~F)
- 5개 전문 에이전트를 활용한 멀티 에이전트 Full 평가 추가: collector, safety-evaluator, completeness-evaluator, design-evaluator, synthesizer
- 통합 평가 진입점인 `/harness-eval` 슬래시 커맨드 추가
- Stop 이벤트에서 작동하는 평가 후 뱃지 자동 생성 훅 추가
- 평가 이력 비교 분석을 위한 compare 스킬 추가
- 점수 검증을 위한 4단계 테스트 픽스처 추가: minimal, functional, robust, production

### Fixed

- `--mode` 플래그에 값이 누락된 경우의 파싱 오류 수정
- plugin.json 매니페스트에서 참조하는 `quick.md` 플레이스홀더 누락 수정

[Unreleased]: https://github.com/whchoi98/harness-eval/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.3.0
[0.2.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.2.0

<!-- 0.1.0은 태그 도입 이전 버전이라 의도적으로 링크를 두지 않습니다. -->
