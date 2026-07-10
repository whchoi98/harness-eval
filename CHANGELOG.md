# Changelog

[![English](https://img.shields.io/badge/lang-English-blue.svg)](#english)
[![한국어](https://img.shields.io/badge/lang-한국어-red.svg)](#한국어)

---

# English

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/whchoi98/harness-eval/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.2.0

<!-- 0.1.0 predates tagging and is intentionally left without a link. -->

---

# 한국어

이 프로젝트의 모든 주요 변경 사항은 이 파일에 기록됩니다.
이 문서는 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [Unreleased]

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

[Unreleased]: https://github.com/whchoi98/harness-eval/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.2.0

<!-- 0.1.0은 태그 도입 이전 버전이라 의도적으로 링크를 두지 않습니다. -->
