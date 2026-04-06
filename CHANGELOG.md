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

- Add project scaffolding with enhanced CLAUDE.md, module documentation, and Auto-Sync Rules
- Add development hooks for documentation sync, secret scanning, session context loading, and notifications
- Add development skills for code review, refactoring, release management, and documentation sync
- Add development commands: `/review`, `/test-all`, `/deploy`
- Add development agents: code-reviewer and security-auditor with structured output schemas
- Add harness validation test suite with 97 tests covering hooks, secret patterns, and plugin structure
- Add architecture documentation with bilingual support and ASCII diagrams
- Add developer onboarding guide with prerequisites, setup steps, and troubleshooting
- Add README.md with bilingual structure and shields.io badges
- Add secret scanning hook with 17 detection patterns and dangerous command deny list
- Add MIT License

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

- CLAUDE.md 확장, 모듈 문서, Auto-Sync Rules를 포함한 프로젝트 스캐폴딩 추가
- 문서 동기화, 시크릿 스캐닝, 세션 컨텍스트 로딩, 알림을 위한 개발용 훅 추가
- 코드 리뷰, 리팩토링, 릴리스 관리, 문서 동기화를 위한 개발용 스킬 추가
- 개발용 커맨드 추가: `/review`, `/test-all`, `/deploy`
- 구조화된 출력 스키마를 갖춘 개발용 에이전트 추가: code-reviewer, security-auditor
- 훅, 시크릿 패턴, 플러그인 구조를 검증하는 97개 하네스 검증 테스트 스위트 추가
- 이중 언어 지원 및 ASCII 다이어그램을 포함한 아키텍처 문서 추가
- 사전 요구 사항, 설정 단계, 트러블슈팅을 포함한 개발자 온보딩 가이드 추가
- 이중 언어 구조 및 shields.io 뱃지를 포함한 README.md 추가
- 17개 탐지 패턴을 갖춘 시크릿 스캐닝 훅 및 위험 명령 deny 목록 추가
- MIT 라이선스 추가

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
