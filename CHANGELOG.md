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

### Changed

- **BREAKING:** Restructure as marketplace + plugin monorepo — plugin files moved to `plugins/harness-eval/`
- **BREAKING:** Adopt Claude Code auto-discovery convention — `plugin.json` contains metadata only, skills use `skills/<name>/SKILL.md` format, hooks registered via `hooks/hooks.json`

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

[Unreleased]: https://github.com/whchoi98/harness-eval/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.1.0

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

### Changed

- **BREAKING:** 마켓플레이스 + 플러그인 모노레포 구조로 전환 — 플러그인 파일이 `plugins/harness-eval/`로 이동
- **BREAKING:** Claude Code 자동 탐색 컨벤션 적용 — `plugin.json`은 메타데이터만 포함, 스킬은 `skills/<name>/SKILL.md` 형식, 훅은 `hooks/hooks.json`으로 등록

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

[Unreleased]: https://github.com/whchoi98/harness-eval/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/whchoi98/harness-eval/releases/tag/v0.1.0
