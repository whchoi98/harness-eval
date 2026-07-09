# Changelog

[![English](https://img.shields.io/badge/lang-English-blue.svg)](#english)
[![한국어](https://img.shields.io/badge/lang-한국어-red.svg)](#한국어)

---

# English

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Fixed

- Fix `.claude/settings.json` deny list: remove the `curl * | bash` and `wget * | bash` rules — Claude Code matches `Bash(...)` deny rules by command prefix and decomposes pipelines into segments, so a mid-pattern `*` before a pipe never matches and these rules could never fire. Pipe-to-shell defense belongs in a `PreToolUse` hook, not a permission rule. Kept and expanded the rules that do work as prefixes (`rm -rf`/`rm -fr`/`rm -r`, `git push --force`/`-f`, `git reset --hard`, `git clean -f`, `chmod 777`, `eval`, `python3 -c`)
- Fix `secret-scan.sh` so it can actually block: exit code `2` on detection (Claude Code treats only exit 2 as a PreToolUse block), removed the `2>/dev/null || true` wrapper in `settings.json` that forced exit 0, NUL-delimited staged-file iteration, and a rewritten AWS-secret-key pattern (the old variable-length look-behind failed to compile under `grep -P`)
- Fix dev hooks that read non-existent env vars (`$TOOL_INPUT`, `$TOOL_INPUT_PATH`, `$EVENT`, `$MESSAGE`) — Claude Code delivers hook data as JSON on stdin, so the hooks now parse stdin (with positional-arg fallback)
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

<!-- Version comparison links are omitted until git tags exist. No release has been
     tagged yet, so `compare/v0.1.0...HEAD` and `releases/tag/v0.1.0` would 404.
     Add them back when v0.1.0 (and later) are tagged and published. -->

---

# 한국어

이 프로젝트의 모든 주요 변경 사항은 이 파일에 기록됩니다.
이 문서는 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [Unreleased]

### Added

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

### Fixed

- `.claude/settings.json` deny 목록 수정: `curl * | bash`·`wget * | bash` 규칙 제거 — Claude Code는 `Bash(...)` deny 규칙을 명령 prefix로 매칭하고 파이프라인을 세그먼트로 분해하므로, 파이프 앞의 중간 `*`는 결코 매칭되지 않아 두 규칙은 발동 자체가 불가능했음. pipe-to-shell 방어는 permission 규칙이 아니라 `PreToolUse` 훅에서 처리해야 함. prefix로 실제 동작하는 규칙은 유지·확장(`rm -rf`/`rm -fr`/`rm -r`, `git push --force`/`-f`, `git reset --hard`, `git clean -f`, `chmod 777`, `eval`, `python3 -c`)
- `secret-scan.sh`가 실제로 차단하도록 수정: 탐지 시 exit code `2`(Claude Code는 PreToolUse 차단을 exit 2로만 인식), exit 0을 강제하던 `settings.json`의 `2>/dev/null || true` 래퍼 제거, 스테이징 파일 순회를 NUL 구분으로 변경, `grep -P`에서 컴파일 실패하던 가변 길이 look-behind AWS 시크릿 패턴 재작성
- 존재하지 않는 환경변수(`$TOOL_INPUT`, `$TOOL_INPUT_PATH`, `$EVENT`, `$MESSAGE`)를 읽던 개발용 훅 수정 — Claude Code는 훅 데이터를 stdin JSON으로 전달하므로 stdin을 파싱하도록 변경(위치 인자 fallback 포함)
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

<!-- git 태그가 생성되기 전까지 버전 비교 링크는 생략합니다. 아직 릴리스 태그가 없어
     `compare/v0.1.0...HEAD`와 `releases/tag/v0.1.0` 링크는 404가 됩니다.
     v0.1.0(및 이후 버전)이 태그·발행되면 링크를 다시 추가하세요. -->
