# Harness Engineering Evaluation Framework

Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하기 위한 프레임워크.

---

## 1. 평가 대상: 5개 핵심 구성 요소

Claude Code 하네스는 5개 구성 요소로 이루어지며, 각각이 Claude의 행동을 다른 방식으로 제어한다.

| 구성 요소 | 제어 방식 | 평가 관점 |
|---|---|---|
| **Hooks** (settings.json + .claude/hooks/) | 이벤트 기반 자동 트리거 | 정확성, 안전성, 커버리지 |
| **Skills** (.claude/skills/) | Claude에게 역할 수행 방법 지시 | 실행 가능성, 구체성 |
| **Commands** (.claude/commands/) | 사용자 반복 작업 자동화 | 완전성, 에러 복구 |
| **Agents** (.claude/agents/) | 독립 병렬 분석 | 출력 스키마, 도구 범위 |
| **CLAUDE.md** (루트 + 모듈별) | 프로젝트 컨텍스트 (시스템 프롬프트) | 정확성, 최신성, 실행 가능성 |

---

## 2. 평가 기준: 6개 차원

각 구성 요소를 6개 차원으로 평가한다.

### 2.1 정확성 (Correctness)
- 문법 오류 없는가? (`bash -n` 검증, JSON 유효성)
- 등록이 올바른가? (settings.json 훅 등록과 실제 파일 일치)
- 참조가 유효한가? (템플릿 경로, 파일 존재 확인)
- 버전이 일치하는가? (매니페스트 간 동기화)

### 2.2 안전성 (Safety)
- 도구 범위가 최소 권한(Least Privilege)인가?
  - Bad: `Bash(python3:*)` → Good: `Bash(python3 -c:*)`
  - Bad: `Bash(cat:*)` → Good: Read 도구 사용
- Deny 목록이 위험 명령을 차단하는가?
  - `rm -rf`, `git push --force`, `git reset --hard`, `eval`, `curl | bash`
- 시크릿 패턴의 거짓 양성(FP)/거짓 음성(FN) 비율
  - TP ≥ 90%, FP ≤ 5%

### 2.3 완전성 (Completeness)
- 모든 이벤트가 커버되는가?
  - SessionStart, PreCommit, PostToolUse, Notification
- 에러 복구 가이드가 있는가?
  - 각 커맨드에 "실패 시" 섹션 존재
  - 롤백 절차 문서화
- 모든 디렉토리에 CLAUDE.md가 있는가?
- 테스트 프레임워크가 존재하는가?

### 2.4 실행 가능성 (Actionability)
- 명령어가 복사-붙여넣기 가능한가?
- 출력 형식이 구조화되어 있는가?
  - 에이전트: Verdict (PASS/WARN/FAIL), Summary 테이블
  - 커맨드: Step-by-step 구조
- 다음 단계가 명확한가?

### 2.5 일관성 (Consistency)
- 프로젝트 파일과 플러그인 템플릿이 동기화되어 있는가?
- 버전이 일치하는가? (marketplace.json = plugin.json)
- 명명 규칙이 통일되어 있는가?
- 프론트매터 형식이 일관적인가? (description, allowed-tools)

### 2.6 검증 가능성 (Testability)
- 자동화된 테스트가 존재하는가?
- 테스트가 실제 버그를 잡는가?
- 테스트 커버리지가 충분한가?
  - 훅: 문법, 권한, 등록, 동작
  - 시크릿: TP/FP 패턴
  - 구조: 매니페스트, 파일 존재, 프론트매터

---

## 3. 점수 체계

### 3.1 구성 요소별 점수 (0-10)

| 점수 | 등급 | 의미 | 특징 |
|---|---|---|---|
| 9.5-10 | A+ | 프로덕션 최적화 | 벤치마크, CI/CD, SLA, 메트릭 |
| 9.0-9.4 | A | 프로덕션 준비 | 통합 테스트, 성능 기준, 마이그레이션 가이드 |
| 8.5-8.9 | A- | 프로덕션 가능 | 에러 복구, 단위 테스트, 출력 스키마 |
| 8.0-8.4 | B+ | 견고 | 테스트 존재, 도구 범위 강화 |
| 7.0-7.9 | B/B- | 기능적 | 구조 존재하나 테스트/복구 미흡 |
| 6.0-6.9 | C | 기본 | 작동하지만 안전장치 부족 |
| <6.0 | D/F | 불완전 | 핵심 구성 요소 누락 |

### 3.2 종합 점수 산출 (가중 평균)

```
종합 점수 = Σ (구성 요소 점수 × 가중치)

  Hooks             × 0.20  (자동 동작의 핵심)
  Commands          × 0.15  (사용자 워크플로우)
  CLAUDE.md         × 0.15  (Claude 컨텍스트의 근간)
  테스트             × 0.15  (검증의 핵심)
  Skills            × 0.10  (역할 정의)
  Agents            × 0.10  (병렬 분석)
  템플릿 동기화       × 0.10  (배포 일관성)
  지원 파일           × 0.05  (인프라)
```

### 3.3 가중치 근거

- **Hooks (0.20)**: 사용자 개입 없이 자동 발동하므로 가장 영향력이 크다
- **Commands (0.15)**: 사용자가 매일 사용하는 인터페이스
- **CLAUDE.md (0.15)**: 세션마다 로드되어 Claude의 모든 행동에 영향
- **테스트 (0.15)**: 다른 모든 구성 요소의 품질을 보증
- **Skills/Agents (0.10 each)**: 특정 상황에서만 활성화
- **템플릿 동기화 (0.10)**: 배포 시에만 중요
- **지원 파일 (0.05)**: 초기 설정 시에만 중요

---

## 4. 평가 방법: 3단계 프로세스

### 4.1 정적 분석 (자동화 가능)

```bash
# Bash 문법 검증
find .claude/hooks -name "*.sh" -exec bash -n {} \;

# JSON 유효성 검증
find . -name "*.json" -not -path "./.git/*" -exec python3 -m json.tool {} \;

# 파일 존재 및 권한 확인
ls -la .claude/hooks/*.sh    # 실행 권한 확인
ls -la scripts/*.sh          # 실행 권한 확인

# settings.json 훅 등록 확인
cat .claude/settings.json | grep -o '"command".*\.sh' | sort

# 버전 일관성
# marketplace.json vs plugin.json 비교

# CLAUDE.md 커버리지
find . -type d -not -path "./.git/*" -maxdepth 2 | while read dir; do
    [ -f "$dir/CLAUDE.md" ] && echo "✓ $dir" || echo "✗ $dir (missing)"
done
```

### 4.2 동적 분석 (테스트 실행)

```bash
# 훅 동작 테스트
bash .claude/hooks/check-doc-sync.sh ""              # 빈 입력 → 무출력
bash .claude/hooks/check-doc-sync.sh "src/new/file"  # 누락 감지
bash .claude/hooks/session-context.sh                 # 프로젝트 정보 출력

# 시크릿 패턴 TP/FP 테스트
echo "AKIAIOSFODNN7EXAMPLE" | grep -qP 'AKIA[0-9A-Z]{16}'  # TP
echo "normal-base64-string" | grep -qP 'AKIA[0-9A-Z]{16}'  # FP (no match)

# 자동화된 테스트 실행
bash tests/run-all.sh
```

### 4.3 설계 리뷰 (수동 평가)

| 검토 항목 | 질문 | 기대 답변 |
|---|---|---|
| 도구 범위 | 각 커맨드가 실제 사용하는 것만 허용하는가? | `Bash(python3 -c:*)` not `Bash(python3:*)` |
| 에러 복구 | 각 커맨드에 "실패 시" 섹션이 있는가? | 롤백 절차, 원인 진단 포함 |
| 출력 스키마 | 에이전트가 구조화된 형식으로 응답하는가? | Markdown with Verdict, Summary table |
| 템플릿 동기화 | 참조 템플릿이 실제 파일과 일치하는가? | diff 결과 없음 |
| Deny 목록 | 위험한 명령이 차단되는가? | rm -rf, force push, eval, curl\|bash |
| 자동 동작 범위 | 훅이 실제로 수정하는 것 vs 경고만 하는 것 | 명확히 구분되어 있는가 |

---

## 5. 평가 보고서 형식

### 5.1 구성 요소별 보고

```markdown
### <구성 요소명>
**점수: X/10**

**강점:**
- (구체적 사실 기반)

**약점:**
- (구체적 파일/라인 참조)

**10/10 도달 조건:**
- (실행 가능한 개선 항목)
```

### 5.2 종합 보고

```markdown
## 종합 평가

| 구성 요소 | 점수 | 상태 |
|---|---|---|
| Hooks | X/10 | Strong/Good/Weak |
| Skills | X/10 | ... |
| ... | ... | ... |

**종합 점수: X.X/10 (등급)**

### 치명적 문제 (즉시 수정)
1. ...

### 주요 개선 항목
1. ...

### 9/10 도달 로드맵
1. ...
```

---

## 6. 반복 평가 사이클

```
초기 평가 → 치명적 문제 수정 → 재평가 → 주요 개선 → 재평가 → ...
```

**권장 주기:**
- 치명적 문제 수정 후: 즉시 재평가
- 주요 기능 추가 후: 재평가
- 정기: 버전 릴리스마다

**수렴 패턴 (이 프로젝트 실측):**

| 회차 | 점수 | 개선폭 | 주요 조치 |
|---|---|---|---|
| 1차 | 7.2 | — | 초기 평가, 치명적 문제 3개 발견 |
| 2차 | 7.9 | +0.7 | 테스트 113개, 에러 복구, 출력 스키마 |
| 3차 | 8.5 | +0.6 | 도구 강화, 템플릿 동기화, 모듈 문서 |
| (예상 4차) | ~9.0 | +0.5 | 통합 테스트, CI/CD, 성능 벤치마크 |

**수확 체감 법칙**: 초기 개선(7→8)은 빠르지만, 후기 개선(8.5→9.5)은 통합 테스트, CI/CD, SLA 등 인프라 투자가 필요하여 더 많은 노력이 든다.

---

## 7. 체크리스트 (Quick Assessment)

프로젝트의 하네스 수준을 빠르게 진단하기 위한 체크리스트:

### 기본 (6.0+ 달성)
- [ ] CLAUDE.md 존재
- [ ] .claude/settings.json 존재
- [ ] 훅 1개 이상 등록
- [ ] 커맨드 1개 이상 존재

### 기능적 (7.0+ 달성)
- [ ] 4개 훅 모두 등록 (SessionStart, PreCommit, PostToolUse, Notification)
- [ ] 시크릿 스캐닝 훅 존재
- [ ] 스킬 2개 이상 정의
- [ ] 에이전트 1개 이상 정의
- [ ] Auto-Sync Rules 문서화

### 견고 (8.0+ 달성)
- [ ] 자동화된 테스트 존재
- [ ] 커맨드에 에러 복구 섹션
- [ ] 에이전트에 출력 스키마 정의
- [ ] 도구 범위 최소 권한 적용
- [ ] Deny 목록 설정
- [ ] 모든 주요 디렉토리에 CLAUDE.md

### 프로덕션 (9.0+ 달성)
- [ ] 통합 테스트 (E2E)
- [ ] 성능 벤치마크
- [ ] CI/CD 파이프라인
- [ ] 마이그레이션 가이드
- [ ] SLA 문서
