# Harness Engineering Evaluation Framework

Claude Code 하네스 엔지니어링 품질을 체계적으로 평가하기 위한 프레임워크.

---

## 1. 평가 대상: 5개 핵심 구성 요소

Claude Code 하네스는 5개 구성 요소로 이루어지며, 각각이 Claude의 행동을 다른 방식으로 제어한다.

| 구성 요소 | 제어 방식 | 평가 관점 |
|---|---|---|
| **Hooks** (settings.json + .claude/hooks/) | 이벤트 기반 자동 트리거 | 정확성, 안전성, 커버리지 |
| **Skills** (.claude/skills/) | Claude에게 역할 수행 방법 지시 | 실행 가능성, 작업 취약도에 맞는 구체성 |
| **Commands** (.claude/commands/) | 사용자 반복 작업 자동화 | 완전성, 에러 복구 |
| **Agents** (.claude/agents/) | 독립 병렬 분석 | 출력 스키마, 도구 범위, 모델·effort |
| **CLAUDE.md** (루트 + 모듈별) | 프로젝트 컨텍스트 (시스템 프롬프트) | 정확성, 최신성, 실행 가능성 |

---

## 2. 평가 기준: 12개 차원 (3개 카테고리)

각 구성 요소(1절)를 아래 12개 차원으로 평가하며, 차원은 3개 카테고리로 묶인다. 이 분류와 가중치는 Full 모드 집계 스크립트 `scripts/aggregate.sh`(종합기 `agents/synthesizer.md`가 호출)의 구현과 일치한다. Quick/Standard 모드는 `templates/checklist.json`의 tier 체크리스트를 이 차원들의 빠른 프록시로 사용한다.

### 카테고리 A. 기본 품질 (Basic Quality) — 가중치 0.50

#### 2.1 정확성 (Correctness)
- 문법 오류 없는가? (`bash -n` 검증, JSON 유효성)
- 등록이 올바른가? (settings.json 훅 등록과 실제 파일 일치)
- 참조가 유효한가? (템플릿 경로, 파일 존재 확인)
- 버전이 일치하는가? (매니페스트 간 동기화)
- 모델·effort 지정이 유효한가? (`static-analysis.sh` `model-config`: `.claude/`와 플러그인 루트(`.claude-plugin/plugin.json`이 있는 대상 루트 또는 `plugins/*/`)의 에이전트·커맨드·`skills/<name>/SKILL.md` 프론트매터, settings의 `model`·`effortLevel`·`alwaysThinkingEnabled`, `env`의 모델 키·`MAX_THINKING_TOKENS`·`CLAUDE_CODE_EFFORT_LEVEL`·`CLAUDE_CODE_DISABLE_THINKING`·`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`)
  - 은퇴 모델 ID(`claude-instant*`, `claude-1*`·`claude-2*`, `claude-3*`, Bedrock `claude-v1`/`claude-v2`, `claude-opus-4-1*` 등 Anthropic 모델 문서의 은퇴 목록. FAIL)가 없고, 날짜 스냅샷 대신 별칭(`opus`, `sonnet`, `inherit` 등)이나 날짜 없는 현행 ID를 쓰는가 (날짜 스냅샷은 Anthropic API 형식만 WARN이다. 날짜가 붙은 Bedrock·Vertex ID는 유효한 지정으로 본다)
  - 은퇴가 예고된 deprecated 모델(WARN)이나, 별칭도 아니고 제공 중인 모델 ID 목록에도 없는 모델명(WARN. `claude-opus-55` 같은 오타와 `claude-sonnet-4-7`처럼 출시된 적 없는 ID 포함)을 쓰지 않는가. 목록은 버전 모양이 아니라 제공 중인 ID를 하나씩 나열하며, Bedrock·Vertex 표기는 접두사·버전 접미사·날짜를 뗀 ID로 비교한다
  - 프론트매터 `effort`는 low/medium/high/xhigh/max 또는 정수, settings `effortLevel`은 low/medium/high/xhigh인가 (그 밖의 값은 Claude Code가 무시한다). `env.CLAUDE_CODE_EFFORT_LEVEL`은 설정되어 있으면 항상 WARN이다. Claude Code가 받아들이는 값(`auto`·`unset`과 정수 포함)이면 프론트매터에 고정한 effort까지 모든 구성 요소의 effort를 덮어쓰고, 그 밖의 값은 무시되기 때문이다
  - `alwaysThinkingEnabled: false`, `MAX_THINKING_TOKENS`, 켜진(`1`/`true`/`yes`/`on`) `CLAUDE_CODE_DISABLE_THINKING`·`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`이 thinking이 항상 켜진 모델(Opus 5.5, Fable)을 쓰는 설정에 없는가 (settings가 thinking을 끌 수 있는 모델을 지정하면 제외한다. 이 판단도 날짜·접두사를 뗀 ID로 하므로 `us.anthropic.claude-opus-5-v1:0`은 `claude-opus-5`와 같이 제외된다)
- 에이전트 파일이 로드되는 형식인가? (`.claude/agents/`와 플러그인 루트 `agents/`의 `.yml`/`.yaml`/`.json`은 Claude Code가 로드하지 않으므로 YAML 프론트매터가 있는 `.md`여야 한다 — `agent-format`)

#### 2.2 안전성 (Safety)
- 도구 범위가 최소 권한(Least Privilege)인가?
  - Bad: `Bash(python3:*)` → Good: `Bash(python3 -c:*)`
  - Bad: `Bash(cat:*)` → Good: Read 도구 사용
- Deny 목록이 위험 명령을 차단하는가?
  - `rm -rf`, `git push --force`, `git reset --hard`, `eval` (pipe-to-shell은 prefix 기반 permission 규칙으로 막을 수 없어 PreToolUse 훅에서 처리)
- 시크릿 패턴의 거짓 양성(FP)/거짓 음성(FN) 비율
  - TP ≥ 90%, FP ≤ 5%

#### 2.3 완전성 (Completeness)
- 모든 이벤트가 커버되는가?
  - PreToolUse, PostToolUse, Stop, Notification
- 에러 복구 가이드가 있는가?
  - 각 커맨드에 "실패 시" 섹션 존재
  - 롤백 절차 문서화
- 모든 디렉토리에 CLAUDE.md가 있는가?
- 테스트 프레임워크가 존재하는가?

#### 2.4 일관성 (Consistency)
- 프로젝트 파일과 플러그인 템플릿이 동기화되어 있는가?
- 버전이 일치하는가? (marketplace.json = plugin.json)
- 명명 규칙이 통일되어 있는가?
- 프론트매터 형식이 일관적인가? (command/skill은 `allowed-tools`, agent는 `tools`)

### 카테고리 B. 운영 (Operational) — 가중치 0.25

#### 2.5 실행 가능성 (Actionability)
- 명령어가 복사-붙여넣기 가능한가? (그대로 실행해야 하는 명령과 인자)
- 커맨드·스킬의 처방 수준이 작업 취약도에 맞는가?
  - 배포·파괴적 작업·고정 인자 스크립트 호출처럼 순서가 중요한 곳은 정확한 단계
  - 리뷰·분석 같은 판단 작업은 목표·제약·완료 기준 (판단 작업의 STEP 1..N 스크립트는 현재 모델을 과하게 제약해 출력 품질을 떨어뜨린다)
- 출력 형식이 구조화되어 있는가?
  - 에이전트: Verdict (PASS/WARN/FAIL), Summary 테이블
  - 커맨드·스킬: 산출물(형식, 필수 필드, 저장 위치) 명시
- 다음 단계가 명확한가?

#### 2.6 검증 가능성 (Testability)
- 자동화된 테스트가 존재하는가?
- 테스트가 실제 버그를 잡는가? (fixture가 실제 스키마와 일치해 결함을 은폐하지 않는가)
- 테스트 커버리지가 충분한가?
  - 훅: 문법, 권한, 등록, 동작
  - 시크릿: TP/FP 패턴
  - 구조: 매니페스트, 파일 존재, 프론트매터
- 스킬·에이전트 동작을 반복 검증할 수단이 있는가? (고정 입력 몇 개와 출력의 기대 속성, 또는 fixture 대상 에이전트 스모크 실행. 모델·effort를 바꿀 때 다시 돌려 프롬프트·effort 변경을 측정한다. 있으면 가점하되, 없다는 이유만으로 크게 감점하지 않는다)

#### 2.7 비용 효율성 (Cost Efficiency)
- 구성 요소마다 모델과 effort가 작업에 맞는가? 토큰 단가나 모델 등급 이름이 아니라 완료 작업당 비용으로 판단한다.
  - effort를 지원하는 모델에서는 effort가 1차 레버다: 기계적 단계(수집·포맷팅·전달)는 낮은 effort나 스크립트로, 판단 단계는 역량 있는 모델에 중간 effort로, `xhigh`/`max`는 작업이 요구할 때만 쓴다
  - 강한 모델 하나(또는 `inherit`)를 모든 곳에 쓰는 구성은 그 자체로 비효율이 아니다. 더 작은 모델을 권하기 전에 effort 하향을 먼저 권한다
  - 재현 가능한 깊이가 중요한 구성 요소(평가자, 리뷰어)는 호출자 세션의 effort를 상속하지 않고 고정한다. 단, settings의 `env.CLAUDE_CODE_EFFORT_LEVEL`(`auto`/`unset` 포함)은 모든 구성 요소의 `effort`보다 우선하므로, 설정되어 있으면 어떤 고정값을 덮어쓰는지 본다
  - thinking 상한·비활성화 설정(`alwaysThinkingEnabled: false`, `env.MAX_THINKING_TOKENS`, `env.CLAUDE_CODE_DISABLE_THINKING`, `env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`)은 thinking이 항상 켜진 모델에서 thinking을 끄지 못하므로 비용 통제 수단이 아니다 — effort를 권한다. 낮은 `env.CLAUDE_CODE_MAX_OUTPUT_TOKENS`도 작업당 비용을 줄이지 않고 응답을 자른다(thinking도 출력 한도에 포함된다)
  - effort를 지원하지 않는 모델(Claude Haiku 4.5, Claude Sonnet 4.5 — Bedrock·Vertex·Foundry에서 `sonnet` 별칭이 가리키는 모델 — 및 그 이전 모델)은 `effort`를 무시하므로 모델 선택만으로 판단한다
- 도구 목록이 최소한이고, 중복 구성 요소가 없는가?
- 위임·팬아웃에 상한이 있는가? ("서브에이전트를 띄워 작업을 검증하라" 같은 지시가 없는가)
- 입력이 출력을 완전히 결정하는 단계(집계, 포맷팅, 라우팅)를 모델 호출 대신 코드로 처리하는가?
- 대용량 입력에 대한 가드가 있는가? (파일 수 상한, glob prune 등)
- 불필요한 반복 실행·중복 저장, 매 턴 다시 주입되는 리마인더가 없는가?
- 컨텍스트는 분량이 아니라 내용으로 본다: 프로젝트 고유 정보는 낭비가 아니고, 기본 동작의 재진술·낡은 사실·서로 어긋나는 중복이 낭비다.

#### 2.8 계약 기반 테스트 (Contract-Based Testing)
- 구성 요소 간 인터페이스(입력/출력 스키마)가 명시되어 있는가?
- 그 계약을 검증하는 테스트가 있는가? (예: 스크립트 출력 JSON 스키마, 소비자 기대치)
- 스키마 변경이 회귀 테스트로 잡히는가?
- (가중 계산 시 운영 카테고리에 포함)

### 카테고리 C. 설계 품질 (Design Quality) — 가중치 0.25

#### 2.9 에이전트 커뮤니케이션 (Agent Communication)
- 에이전트 간 입력/출력 핸드오프가 명확한가?
- 오케스트레이터가 하위 에이전트를 올바른 이름/타입으로 디스패치하는가?
- 위임이 작업에 맞는가? (서브에이전트가 적거나 없는 것은 결함이 아니다 — 스킬→스크립트, 훅→Claude, 커맨드→스킬처럼 실제로 있는 인터페이스로 평가한다. 주 에이전트의 작업을 검증만 하는 서브에이전트, 작은 작업에 여러 병렬 에이전트, 도구 호출 몇 번이면 끝날 일의 위임은 약점이다)

#### 2.10 컨텍스트 관리 (Context Management)
- 컨텍스트가 필요한 곳에 전달되고 과도하게 부풀지 않는가? (분량이 아니라 내용으로 판단한다: 작성자만 아는 프로젝트 고유 정보는 부풀림이 아니고, 기본 동작의 재진술·낡은 사실·표현만 다른 중복 규칙이 부풀림이다. Claude Code는 로드된 메모리 파일 하나가 모델 컨텍스트 윈도의 약 5%(문자 수 기준, 하한 약 40,000자)를 넘으면 경고한다)
- 대상 규모에 따른 컨텍스트 제한 전략이 있는가?
- 지시문이 현재 모델에 맞는가? 다음 패턴이 없는지 본다. 점수 근거(rationale)처럼 산출물로 필요한 설명과 스킬 `description`의 라우팅 문구는 해당하지 않는다
  - 강조어 과밀 (`CRITICAL/MUST/NEVER`)
  - 사고 제어 문구: 'think step by step'·`<scratchpad>`, 'answer without deliberating', "don't think" 규칙. thinking 깊이는 문구가 아니라 effort가 정하고, thinking이 항상 켜진 모델(Claude Opus 5.5)에서 "don't think" 규칙은 따를 수 없으며 내부 태그가 출력에 새어 나올 가능성만 높인다
  - thinking을 끈 Claude Opus 5용 완화 문구: 'say a sentence before each tool call', 'say so if no tool fits', "don't use internal XML tags". thinking을 끈 상태에서만 나타나는 현상에 대한 대응이라 thinking이 항상 켜진 모델에서는 대개 불필요하므로, 문구 없이 다시 시험해 재현되지 않는 것은 뺀다. thinking을 끄고 운영한다고 밝힌 하네스는 예외다
  - 서식 금지 규칙: 'never use bullets'·'no headers'·'no bold'. 과하게 서식을 쓰던 모델에 맞춘 규칙이라 지금은 독자가 원하는 구조까지 없앤다. 언제 서식이 맞는지 말하는 규칙(여러 부분으로 된 내용은 목록, 설명은 문장)으로 바꾼다. 출력 소비자가 요구하는 형식(파서, 일반 텍스트 채널, 고정 템플릿)은 해당하지 않는다
  - 내부 추론을 응답에 재현하라는 요청
  - 'hold all findings'·'don't narrate' 같은 업데이트 억제
  - 'be thorough' 같은 부스터와 숫자 출력 상한
  - 자기검증 스캐폴딩, 리뷰 프롬프트의 severity 필터

#### 2.11 피드백 루프 성숙도 (Feedback Loop Maturity)
- 검증→수정→재검증 루프가 자동화되어 있는가? (테스트, CI, 훅. 모델에게 스스로 다시 확인하라는 프롬프트나 검증용 서브에이전트는 피드백 루프로 치지 않는다)
- 실패가 조용히 삼켜지지 않고 표면화되는가?
- 실패에서 얻은 교훈을 사건 서술이 아닌 일반 규칙으로 남기고, 쌓인 규칙을 추가만 하지 않고 재검증해 폐기하는가? (예: 모델이 바뀔 때 CLAUDE.md·스킬 지시 재점검)

#### 2.12 진화 가능성 (Evolvability)
- 새 구성 요소/차원을 추가하기 쉬운가? (auto-discovery, 모듈 문서)
- 단일 정본(single source of truth)이 정의되어 중복 표류를 막는가? (등급표, 버전, 스키마)
- 모델 교체에 견디는가? (별칭·`inherit` 사용 또는 한 곳에서 모델 지정, 모델별 우회 지시에 대상 모델 명시, 모델 변경 시 프롬프트·에이전트·effort 재점검 절차. 은퇴·deprecated·날짜 스냅샷·무효 모델 ID 자체는 정확성의 `model-config`가 잡는다)

---

## 3. 점수 체계

### 3.1 구성 요소별 점수 (0-10)

| 점수 | 등급 | 의미 | 특징 |
|---|---|---|---|
| 9.5-10 | A+ | 프로덕션 최적화 | 벤치마크, CI/CD, SLA, 메트릭 |
| 9.0-9.4 | A | 프로덕션 준비 | 통합 테스트, 성능 기준, 마이그레이션 가이드 |
| 8.5-8.9 | A- | 프로덕션 가능 | 에러 복구, 단위 테스트, 출력 스키마 |
| 8.0-8.4 | B+ | 견고 | 테스트 존재, 도구 범위 강화 |
| 7.0-7.9 | B | 기능적 | 구조 존재하나 테스트/복구 미흡 |
| 6.0-6.9 | C | 기본 | 작동하지만 안전장치 부족 |
| <6.0 | F | 불완전 | 핵심 구성 요소 누락 |

### 3.2 종합 점수 산출 (카테고리 가중 평균)

종합 점수는 12개 차원(2절)을 3개 카테고리로 묶어 가중 평균한다. Full 모드에서는 `scripts/aggregate.sh`가 이 공식을 계산하고, 종합기(`agents/synthesizer.md`)는 그 결과를 그대로 보고한다.

```
카테고리 평균 = 해당 카테고리에서 점수가 있는 차원들의 산술 평균 (차원은 카테고리 내 동일 가중)

종합 점수 = (기본 품질 평균 × 0.50)
          + (운영 평균       × 0.25)
          + (설계 품질 평균   × 0.25)
          → 소수 첫째 자리 반올림, 범위 0.0–10.0 (차원 점수가 0–10이므로)
          (점수가 없는 카테고리는 빼고 나머지 가중치를 재정규화)
```

- **기본 품질 (0.50)**: 정확성·안전성·완전성·일관성
- **운영 (0.25)**: 실행 가능성·검증 가능성·비용 효율성·계약 기반 테스트
- **설계 품질 (0.25)**: 에이전트 커뮤니케이션·컨텍스트 관리·피드백 루프 성숙도·진화 가능성

> Quick/Standard 모드는 위 차원별 0–10 점수를 직접 산출하지 않고, `templates/checklist.json`의 tier(basic/functional/robust/production) 통과 비율을 `scripts/scoring.sh`가 가중·감쇠하여 1.0–10.0 척도와 같은 등급표(3.1절)로 환산한다. Full 모드는 정적 분석의 카테고리별 점수(`categories.*.score`, 기본 품질 4개 차원)와 세 평가 에이전트의 차원 점수(나머지 8개 차원)를 `scripts/aggregate.sh`로 위 공식에 따라 합산한다. safety-evaluator가 내는 Safety 점수는 가중 계산에 들어가지 않는 정성 보완 점수다.

### 3.3 카테고리 가중치 근거

- **기본 품질 0.50**: 하네스가 틀리거나 안전하지 않으면 나머지가 무의미하므로 절반의 비중을 둔다
- **운영 0.25**: 올바르게 동작하더라도 실행 불가능하거나 테스트되지 않으면 신뢰할 수 없다
- **설계 품질 0.25**: 단기 정확성보다 장기 유지보수·확장에 영향을 주는 구조적 특성

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
bash tests/harness-run-all.sh
```

### 4.3 설계 리뷰 (수동 평가)

| 검토 항목 | 질문 | 기대 답변 |
|---|---|---|
| 도구 범위 | 각 커맨드가 실제 사용하는 것만 허용하는가? | `Bash(python3 -c:*)` not `Bash(python3:*)` |
| 에러 복구 | 각 커맨드에 "실패 시" 섹션이 있는가? | 롤백 절차, 원인 진단 포함 |
| 출력 스키마 | 에이전트가 구조화된 형식으로 응답하는가? | Markdown with Verdict, Summary table |
| 템플릿 동기화 | 참조 템플릿이 실제 파일과 일치하는가? | diff 결과 없음 |
| Deny 목록 | 위험한 명령이 차단되는가? | rm -rf, force push, eval (pipe-to-shell은 deny 규칙으로 매칭되지 않으므로 PreToolUse 훅) |
| 자동 동작 범위 | 훅이 실제로 수정하는 것 vs 경고만 하는 것 | 명확히 구분되어 있는가 |

---

## 5. 평가 보고서 형식

이 절은 독자를 위한 예시다. 실행 시 보고서 형식의 정본은 Full 모드가 `agents/synthesizer.md`, Quick·Standard·Compare 모드가 각 `skills/<mode>/SKILL.md`이며, 이 문서는 런타임에 읽히지 않는다.

### 5.1 구성 요소별 보고 (수동 리뷰)

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

### 5.2 종합 보고 (Full 모드)

Full 모드 보고서는 영어 파일(`<EVAL_ID>-full-en.md`)과 한국어 파일(`<EVAL_ID>-full-ko.md`) 두 개이며, 점수·등급·가중치·상태 값·파일 경로·코드 블록은 두 파일에서 같다. 한국어 파일의 구성은 다음과 같다.

```markdown
# 하네스 종합 평가 리포트

**점수: X.X/10 (등급)**
**날짜: YYYY-MM-DD**
**모드: Full**

## 차원별 점수

| 카테고리 | 차원 | 점수 | 가중치 | 상태 |
|----------|------|------|--------|------|
| 기본 품질 | 정확성 | X/10 | 0.50 | pass |
| 기본 품질 | 안전성 | X/10 | 0.50 | warn |
| 기본 품질 | 완전성 | X/10 | 0.50 | ... |
| 기본 품질 | 일관성 | X/10 | 0.50 | ... |
| 운영 | 실행 가능성 | X/10 | 0.25 | ... |
| 운영 | 검증 가능성 | X/10 | 0.25 | ... |
| 운영 | 비용 효율성 | X/10 | 0.25 | ... |
| 운영 | 계약 기반 테스트 | X/10 | 0.25 | ... |
| 설계 품질 | 에이전트 커뮤니케이션 | X/10 | 0.25 | ... |
| 설계 품질 | 컨텍스트 관리 | X/10 | 0.25 | ... |
| 설계 품질 | 피드백 루프 성숙도 | N/A | 0.25 | N/A |
| 설계 품질 | 진화 가능성 | X/10 | 0.25 | ... |

## 요약 (Executive Summary)
(종합 결과, 가장 강한·약한 영역, 누락된 차원과 그 이유)

## 상세 발견사항
### 기본 품질 (Basic Quality)
(정적 분석 발견사항과 safety-evaluator의 Safety 발견사항, "안전성 (safety-evaluator): X/10")
### 운영 (Operational)
### 설계 품질 (Design Quality)

## 치명적 이슈 (즉시 수정)
(FAIL 수준 발견사항만. 없으면 "치명적 이슈 없음.")

## 개선 로드맵
### 다음 등급: <목표 등급>
1. **<개선 항목>** - 예상 효과: <차원> +<N>
2. **<개선 항목>** - 예상 효과: 추정 안 됨 (<차원>)
### 장기 목표

## 점수 히스토리
(이전 Full 실행과 이번 결과, Full 기준 추세, 다른 모드의 최근 실행)
```

- 상태는 `aggregate.sh`가 차원 점수로 정한다: 7.0 이상 `pass`, 4.0 이상 7.0 미만 `warn`, 4.0 미만 `fail`. 점수가 없는 차원은 점수와 상태 모두 `N/A`다.
- 가중치 열은 차원별 가중치가 아니라 카테고리 가중치다. 카테고리 안의 차원은 카테고리 평균에 같은 비중으로 들어간다.
- 로드맵 항목의 예상 효과는 평가 에이전트의 권고 줄에서 그대로 옮기며, 종합 점수에 미칠 영향은 계산하지 않는다. safety-evaluator의 Safety 항목은 가중 Safety 점수가 아니라 보조 Safety 점수 기준이므로 "안전성 +<N> (safety-evaluator 보조 점수 기준)"으로 적는다. 목표 등급은 F → C → B → B+ → A- → A → A+ 순서의 다음 등급이다.

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

프로젝트의 하네스 수준을 빠르게 진단하기 위한 체크리스트. **자동 채점(Quick/Standard 모드)의 정본은 `templates/checklist.json`이며, 아래 tier 항목은 그 구성을 반영한다.** `(수동 리뷰)`로 표시된 항목은 `checklist.json`에서 자동 채점되지 않는 심화 기준으로, 설계 리뷰(4.3절)에서 수동 평가한다.

### 기본 (6.0+ 달성) — checklist.json `basic` tier
- [ ] CLAUDE.md 존재
- [ ] .claude/settings.json 또는 .claude/settings.local.json 존재
- [ ] 훅 1개 이상 등록
- [ ] 커맨드 1개 이상 존재

### 기능적 (7.0+ 달성) — checklist.json `functional` tier
- [ ] 핵심 훅 이벤트 등록 (PreToolUse, PostToolUse)
- [ ] 시크릿 스캐닝 훅 존재
- [ ] 스킬 2개 이상 정의 (flat `*.md` 또는 `<name>/SKILL.md`)
- [ ] 에이전트 1개 이상 정의 (Quick/Standard 점수 연속성을 위해 남긴 프록시다. Full 모드는 2.9절에 따라 서브에이전트가 없는 것을 결함으로 보지 않으므로, 서브에이전트 없이 스킬·스크립트로 잘 설계된 하네스는 두 모드에서 다른 평가를 받을 수 있다. 이 항목의 조정은 후속 과제다)
- [ ] Auto-Sync Rules 문서화 (수동 리뷰)

### 견고 (8.0+ 달성) — checklist.json `robust` tier
- [ ] 자동화된 테스트 존재
- [ ] 커맨드에 에러 복구 섹션
- [ ] 에이전트에 출력 스키마 정의
- [ ] Deny 목록 설정
- [ ] 모든 주요 디렉토리에 CLAUDE.md (2개 이상)
- [ ] 도구 범위 최소 권한 적용 (수동 리뷰)

### 프로덕션 (9.0+ 달성) — checklist.json `production` tier
- [ ] 통합 테스트 (E2E)
- [ ] CI/CD 파이프라인
- [ ] 마이그레이션 가이드
- [ ] 성능 벤치마크 (수동 리뷰)
- [ ] SLA 문서 (수동 리뷰)
