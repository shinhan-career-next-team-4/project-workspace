# 제공자(A팀 Spring) 검토 — 대화·비교 조건 확장 초안 v1 (CF12)

- 검토: contract-provider(A팀 Spring: calc·plan·auth), 2026-11-20
- 읽은 코드: `../moeun` `feature/126-input-suggestion` (읽기만 함, switch·fetch·수정 없음)
- 결론 한 줄: **방향은 수용. 단 초안의 "구현 지점 6개"는 실제로 9개이고, 그중 2개는 초안이 놓쳤는데 둘 다 "요청은 통과하는데 안 바뀜"을 직접 만든다.** 그리고 쟁점 3-1은 3주 범위에서 가장 비싼 항목이다.

---

## 0. 판정 요약

| 항목 | 판정 |
|---|---|
| CF12-1~3 배경·범위·D-040 대체 | 수용 |
| CF12-4 코드 현황표 | **수정** — 빠진 지점 3개(아래 1절). a~n의 사실 자체는 모두 코드와 일치 |
| CF12-5 `rules.yml` diff | 수용(단 yml만으로는 `/internal/calc`에 **아무 효과 없음** — 1절 ①) |
| 쟁점 1 `max-fields` | **수용(1-1 = 6)** |
| 쟁점 2 `HELD_ASSETS` | **수정** — 2-1 동의하되 display 키 전달 방식에 제약이 있다(4절) |
| 쟁점 3-1 초과 탈출 | **수정** — 3-1의 구현 비용이 초안 추정보다 크다. 3주 범위에서는 **3-2 권고**(3절) |
| 쟁점 3-4 `changed` 초과 | 수용 |
| 쟁점 3-6 양쪽 목표 금액 표시 | **수정 필수** — 단순 "키 추가"가 아니라 display 키 **스키마 변경**이다(2절 ④) |
| 쟁점 4 ai-server 두 겹 | 수용(4-1 + 4-2 테스트) |
| CF12-12 후속 작업 Issue 배정 | **수정** — 7절의 대조 결과대로 |

---

## 1. 구현 지점: 초안의 6개 → 실제 9개

초안 CF12-4의 a~n은 **행 번호까지 전부 코드와 일치**했다. 아래는 그 목록에 **없는데 반드시 고쳐야 하는** 지점이다.

### ① (빠짐·치명) `InternalCalcController.CHANGEABLE_KEYS` — `/internal/calc`의 실제 관문
`moeun/backend/src/main/java/com/moeun/backend/calc/web/InternalCalcController.java:39-42`

```java
/** 대화로 바꿀 수 있는 조건(D-040, CP-07). 이 밖의 키가 하나라도 있으면 요청 전체를 거절한다. */
private static final Set<String> CHANGEABLE_KEYS = Set.of(MONTHLY_SAVING_AMOUNT, SAVINGS_RATIO_PCT,
        SAVINGS_RATE_INPUT_PCT, TARGET_PERIOD_MONTHS);
```

이 Set은 `rules.yml`을 **보지 않는다.** 검사 순서 3(같은 파일 `:66-72`)에서 `goalAmount`가 들어오면 `rules.yml`이 6필드든 말든 그대로 `422 FIELD_NOT_CHANGEABLE`로 끝난다. 즉 **CF12-5의 yml diff는 CHAT 경로에 효과가 0이다.** 함께 고쳐야 할 같은 파일의 지점:

- `:86-110` `validate(...)`: `toInteger(...)`로 키를 **하드코딩해 하나씩** 꺼낸다. `goalAmount`(long), `heldAssets`(long) 두 줄 추가 + `hasValidatableValue`(`:99-100`) 조건에 2개 추가. 빼먹으면 `conditionChanges: {goalAmount: ...}` 하나만 온 요청이 **검증을 건너뛴다**(= 범위 밖 값이 엔진까지 간다).

### ② (빠짐) `PlanContextProviderImpl.CHANGEABLE_KEYS` — `recompute`의 관문
`calc/application/PlanContextProviderImpl.java:47-53`. 초안 g는 `toOverride()`(`:168-181`)만 지적했지만, 키를 막는 건 **그 위의 Set**(`:52`)이고 허용 밖 키는 `IllegalArgumentException`(`:170-172`)이다. 저장된 대화를 재계산할 때 `goalAmount`가 있으면 **500**이 난다(계약 C12b-6이 말하는 "F-4가 500"이 바로 이 경로). 즉 ai-server가 6키를 저장하기 시작하는 순간, 이 두 줄을 안 고치면 **F-4 비교 조회가 전부 500**이 된다. 배포 순서상 ai-server(T-8)보다 **먼저** 가야 한다.

> 참고: ①과 ②의 중복은 이미 Issue **#132 `[calc] 대화 조건 변환 코드를 한 곳으로 모으기`(OPEN, in-progress)** 가 `calc.application.ConditionChanges` 한 곳으로 모으는 중이다. **#132를 먼저 머지하면 이번 변경의 ①②가 한 파일 한 곳으로 줄어든다.** 제공자 쪽 강력 권고: #132 선행.

### ③ (빠짐) `CalcComparison.ConditionValues` — 응답의 `conditions`가 4필드 레코드
`calc/CalcComparison.java:29-45`

```java
/** 대화로 바꿀 수 있는 4개 조건의 계산에 실제 쓴 값. */
public record ConditionValues(Long monthlySavingAmount, int savingsRatioPct, BigDecimal savingsRateInputPct,
        Integer targetPeriodMonths)
```

internal-calc C2-3이 "4개 키가 항상 모두 있다"고 쓴 그 레코드다. 초안 CF12-10-1은 문서 한 줄을 6개로 바꾸라고만 적었는데, **공개 레코드에 필드 2개를 더하는 작업**이고 `/internal/calc` 응답 JSON 모양이 바뀐다 → REST Docs 스냅샷(`backend/src/test/java/com/moeun/backend/docs/InternalCalcDocsTest.java`)과 ai-server `ComparisonResponse` 스키마가 함께 바뀐다. 이걸 빼면 "목표 금액을 바꿔 계산은 됐는데 응답에 바뀐 목표 금액이 안 보임"이 된다.

### ④ (빠짐·설계 영향 큼) `ResultDisplayBuilder`의 `goalAmount` 키가 **접두어 없는 단일 키**
`calc/application/ResultDisplayBuilder.java` 클래스 주석:

> `{@code goalAmount}`: 접두어 없음(**비교에서도 두 계산의 목표가 같다**)

구현(`build()` 첫 줄)이 `display.put("goalAmount", ...)`다. `CompareConditionsUseCase.buildDisplay`(`:135-137`)는 `build()`를 current·changed 두 번 불러 `putAll`하므로, **목표 금액이 바뀐 비교에서는 두 번째(changed) 값이 첫 번째를 덮어쓴다.** 조용히. 즉 쟁점 3-6은 "display 키 2개 추가"가 아니라 **display 키 스키마 변경**이다:

- `goalAmount`(무접두어) → `current.goalAmount` / `changed.goalAmount`로 가거나, 또는 비교 경로에서만 접두어를 붙이는 분기를 넣어야 한다.
- 어느 쪽이든 **ai-server `DISPLAY_KEY` 정규식**(`ai-server/app/schemas.py:54-59`)이 `goalAmount`를 무접두어로만 허용하므로 함께 고쳐야 한다. (P-5 답: `current.`/`changed.` 접두어 쪽이 깔끔하다. `conditions.*`에 goalAmount를 넣는 방식은 이미 `conditions.current.*`/`conditions.changed.*` 접두어 체계가 있어 중복 표기가 생긴다.)
- `heldAssets`는 `putConditions(...)`에서 **`isSingleResult`일 때만** 넣는다(= 비교 display에는 아예 없다). 쟁점 2-1·3-6을 받으면 이 `if`도 풀어야 한다. 이건 C2-6이 "비교에서는 heldAssets·calcStartMonth·assumptions를 만들지 않는다"고 **의도적으로 정한 것**이라, 계약 개정이 필요한 변경이다.

### 그 밖에 훑은 결과(문제 없음 / 작음)

| 경로 | 결과 |
|---|---|
| 대안(`ALTERNATIVE`) | `rules.yml` 3필드·max 1 그대로. 영향 없음 |
| 되돌리기 `PlanService.undo`(`:159-179`) + `copyVersion` | `plan_version` 전 컬럼을 복사한다. `goal_amount`·`held_assets`도 포함 → **추가 작업 없음** |
| `calc_run` 재계산 | `calc_run`은 `plan_version_id`와 데이터 버전만 남긴다(ADR-002 최소 저장). 조건 값은 `chat_message.condition_changes`에 있다 → 스키마 변경 **없음** |
| `ModularityTests` | 새 타입을 안 만들고 `plan.ConditionOverride`·`calc.*`의 기존 의존 방향만 쓴다(calc → plan 단방향 유지). **순환 없음, 통과 예상** |
| 테스트 fixture | `ConditionOverride`를 `new`로 부르는 테스트 **4파일 20여 곳**이 생성자 인자 개수 때문에 전부 컴파일 깨짐(`ConditionValidatorTest`, `ConditionResolverTest`, `ChatComparisonQueryTest`, `PlanContextProviderTest`). 기계적이지만 반 일 |
| 계약 fixture | `backend/src/test/resources/contract/internal-calc/a4-response.json`이 `field: "goalAmount"`다 → **반드시 교체**(초안 지적대로). `a5-already-exceeded.json`도 쟁점 3-1을 받으면 신설 필요 |

---

## 2. 쟁점 1 `max-fields` — **1-1(6) 수용**

초안 분석이 **정확하다**. 확인:
- `ConditionValidator.java:83-86` — `maxFields() > 0 && changed.size() > maxFields` → `tooManyChanges` 1건만 담고 즉시 return.
- 현재 CHAT·COMPARE는 허용 4 = max 4이므로 `changed.size() > 4`가 불가능 → **분기 도달 불가**.
- `TOO_MANY_CHANGES`는 `FieldError.java:22-24`에 생성자만 있고, 쓰이는 곳은 `ConditionValidator:84`와 `ConditionValidatorTest:25`(ALTERNATIVE 케이스) **뿐**이다.

P-3 답: **문구도 프론트 처리도 없다.** `CopyBook.java:50`의 코드 목록에 `TOO_MANY_CHANGES`가 없고(`ALREADY_EXCEEDED`, `MALFORMED_REQUEST`, `INVALID_INTERNAL_KEY`, `CALC_FAILED`), 프론트 `src/api`에 `NOT_CHANGEABLE`/`reason` 분기 처리 코드가 **하나도 검색되지 않는다**. 즉 1-2(4 유지)는 문구표 키 신설 + ai-server 매핑 + 프론트 분기 + 테스트가 새로 생긴다(≈0.5~1일, 가치 0).
1-3(0)은 가드 소실. **6을 받는다. 비용 0.**

---

## 3. 쟁점 3-1 — 구현 비용 산정과 반대 의견

### 깨지는 것(구체)

1. **`CompareConditionsUseCase.computeComparison:88-92`** 재설계. 지금은 `current.input().hasExceededGoal()` → 즉시 `throw CalcRejectedException.alreadyExceeded()`. 3-1이면 "변경 키에 `goalAmount`/`heldAssets`가 있고 `changed`가 초과 아님"일 때만 통과시켜야 하므로, **`changed`를 먼저 해석해야** 분기할 수 있다(순서 역전). 자체는 10줄.
2. **internal-calc C2-4 불변식 "성공 응답은 항상 `CALCULATED`" 소멸.** 이게 진짜 비용이다. `current.status = ALREADY_EXCEEDED`면 `CalcEngine:93-95`가 `scenarios`를 **빈 목록**으로 준다. 그러면:
   - `CalcComparison.Diff.between`(`CalcComparison.java:57-69`): `byScenario`가 빈 목록이 되고, baseline 포인터는 `changed.findBaselineResult()`로 잡혀 `Diff(AVG, [])`가 나온다 → **NPE·예외는 안 난다**(검증 완료). `diff`는 자연히 비는 구조라 초안의 "`byScenario: []`"는 코드 수정 없이 성립한다. 좋은 쪽.
   - `ResultDisplayBuilder.build`(P-1 답): `for (ScenarioResult s : result.scenarios())`가 0회 돌고, `targetMonth`는 null 가드가 있다 → **터지지 않는다.** 다만 display에 `current.GOOD.*`류 키가 **통째로 없는** 맵이 나간다. ai-server 프롬프트와 프론트 카드가 "키가 없을 수 있다"를 전제로 쓰여 있지 않다면 그쪽에서 깨진다(소비자 확인 필요).
3. **`ALREADY_EXCEEDED`의 의미가 둘로 쪼개진다.** 지금은 **409 오류 코드**(`CalcRejectedException.ALREADY_EXCEEDED`, `InternalCalcExceptionHandler:44`)이면서 동시에 **`CalcStatus` 값**이다. 3-1 후에는 같은 상황이 "409 오류"일 때와 "200 성공 + status 필드"일 때로 갈린다. ai-server `agent.py:143`의 `"ALREADY_EXCEEDED": "chat.alreadyExceeded"` 매핑과 `agent.py:424·441`의 분기가 **오류 경로 기준**으로 쓰여 있어 둘을 구분하도록 고쳐야 한다. 프론트 `settledStatus`(`planStore`)도 성공 응답 안의 `ALREADY_EXCEEDED`를 지금은 비교 응답에서 기대하지 않는다.
4. **D-071 재작성 + 계약 5곳 + fixture 2건**(초안 CF12-10-1의 65·88·115·132·139~158·248·253·254·597~618행, A-5 신설).

### 비용 (백엔드 1명 기준)

| | 3-1 | 3-2 |
|---|---|---|
| Spring 코드 | 0.5일 | 0.2일 |
| 계약·REST Docs·fixture | 1.0일 | 0.2일 |
| ai-server 분기(오류 vs 성공 내 status) | 0.5일(B팀) | 0 |
| 프론트 비대칭 카드 | 0.5~1일(B팀) | 0.3일 |
| 회귀 위험 | **높음**(모든 비교 응답의 불변식이 바뀌어 기존 통합 테스트·목 전부 재검토) | 낮음 |

**제공자 의견: 3주 범위에서는 3-2를 권고한다.** 이유는 비용이 아니라 **회귀 범위**다. 3-1은 *모든* 비교 응답의 불변식(C2-4)을 바꾸므로, 초과와 무관한 정상 경로의 프론트·ai-server·목 fixture까지 전수 재검증해야 한다. 3-2는 초과 계획이라는 **드문 상태 하나만** 새 흐름으로 분기하고, 성공 응답 모양은 한 글자도 안 바뀐다. 데모에서 "초과 계획에서 목표를 올려 되살린다"는 **이야기는 그대로 보여줄 수 있다**(확인 → 적용 → 결과 화면이 다시 계산됨).
3-1을 꼭 하려면 **데모 이후 과제**로 분리하길 요청한다.

쟁점 3-4(`changed` 초과)는 **수용**. `CalcEngine:93-95`가 이미 그 응답을 만들고, 적용 후 결과 화면 초과 전환은 D-072·#52로 구현되어 있다. 다만 3-4는 3-1과 **독립이 아니다**: `changed`가 초과면 `changed.scenarios = []`라 2절 ④의 display 공백 문제와 C2-4 불변식 문제가 **3-2를 골라도 똑같이 생긴다.** 쟁점 2에서 `HELD_ASSETS`를 빼면(2-2) 3-4 상황은 "목표 금액을 내려서 초과"로 좁아지지만 여전히 가능하다. → **C2-4 개정은 어느 조합을 골라도 피할 수 없다.** 이것만은 범위에 넣어야 한다.

---

## 4. 쟁점 2 `HELD_ASSETS`와 D-035 — 계산은 맞다, 가드는 필요하다

계산 엔진 확인:
- `CalcInput.java:18` 주석 "보유 자산. 0 이상이며 운용 수익 없이 원금에 더한다", `:46` `heldAssets >= 0` 검증.
- `CalcEngine:159` `principal = heldAssets + monthlySavingAmount * k` — **시작월 기준 출발 잔액 한 가지 뜻**뿐이다.
- `ConditionResolver.createInput`(`:92-99`)은 `calcStartMonth`를 **항상 계획 저장값**으로 쓴다(D-013·D-032).

→ **override로 `heldAssets`를 바꿔도 계산 자체는 올바르다.** 엔진에 이중 계산 로직은 없다. 위험은 전적으로 **사용자가 말한 숫자의 의미**(지금 잔액 vs 시작월 잔액)이고, 초안의 진단이 맞다. **2-1 수용.**

단 전달 방식에 제약: 초안은 "Spring이 `display`에 `chat.heldAssetsBasis`를 내려보낸다"고 했는데, 지금 `display`는 **"키 → 표시 문자열"** 맵이고 `ai-server/app/schemas.py:54-59` `DISPLAY_KEY` 정규식에 맞지 않는 키는 **버려진다**. 그리고 비교 경로 display에는 `calcStartMonth`가 **없다**(`ResultDisplayBuilder`의 `isSingleResult` 분기) → `{calcStartMonth}` 자리를 채울 값이 비교 응답에 없다.
**수정안(P-4 답):** `tax.note`(D-073)와 같은 구조로 재사용 **가능하다.** 단 (a) 비교 display에 `calcStartMonth`를 추가하도록 C2-6을 개정하고, (b) `DISPLAY_KEY` 정규식에 `calcStartMonth`는 이미 있으니 그대로 쓰고, (c) 문구는 `display`가 아니라 **`notes` 같은 별도 문자열 목록**으로 내려보내길 권한다. display는 "숫자 표시 문자열"이라는 뜻이 명확해서 문장을 섞으면 PR-04 숫자 대조(#37)가 오탐할 수 있다.

**범위 축소안으로는 2-2(`GOAL_AMOUNT`만)를 지지한다.** 막다른 길 문제는 목표 금액만으로 풀리고, `HELD_ASSETS`를 빼면 ①`chat.heldAssetsBasis` 신설 ②비교 display `calcStartMonth` 추가 ③`conditions.heldAssets` 비교 노출 ④D-035 범위 확장이 전부 사라진다(≈1일 절감).

---

## 5. DB·저장 — 문제 없음

- `plan_version`(`backend/src/main/resources/db/schema.sql:68-92`)에 `goal_amount BIGINT NOT NULL`(`:73`), `held_assets BIGINT NOT NULL DEFAULT 0`(`:76`)이 **이미 컬럼으로 있다.** 제약도 `ck_pv_goal_amount CHECK (goal_amount > 0)`, `ck_pv_amounts`로 준비되어 있다. **스키마 변경 0.**
- 적용(F-5/P-6): `PlanService.merge`(`:202-216`)가 지금 두 값을 **현재 버전 값으로 하드코딩**해 `fields`에 넣는다. 여기에 `firstNonNull(changes.goalAmount(), current.getGoalAmount())` 두 줄로 끝난다. 그 뒤 `inputValidator.validate(merged)`(`:138`)가 다시 범위를 검사하므로 **방어선도 이미 있다**(D-033 유지).
- 새 버전·`revision`·되돌리기: `apply`는 `plan_version` INSERT + `replaceCurrent(... expectedRevision)` 낙관적 락 → 두 값이 바뀌어도 동일. `undo`의 `copyVersion`은 전 컬럼 복사라 **그대로 동작**한다.
- 초과 판정 "캐시" 같은 것은 없다. 초과는 `CalcInput.hasExceededGoal()`로 매번 계산한다(`CalcInput.java:63`). `calc_run`에 상태를 저장하지 않으므로(ADR-002) **적용 후 결과 화면이 자동으로 초과/정상으로 바뀐다.** 이 부분은 깨끗하다.
- `source` 컬럼 CHECK(`:91`)에 `'CHAT'`이 이미 있다 → 대화 적용으로 목표 금액이 바뀐 버전도 정상 기록된다.

**ADR-002(최소 저장) 충돌 없음. JWT·인증 영향 없음(`/internal/**`는 공유 비밀 헤더 그대로).**

---

## 6. 작업량 추정과 범위 권고

제공자(A팀 Spring) 몫만, 3주차 백엔드 1명 기준.

| 구성 | 일수 |
|---|---|
| #132 선행(이미 in-progress) | 기존 작업 |
| `rules.yml` + `ConditionOverride` 2필드 + `ConditionValidator.changedFields` | 0.3 |
| `InternalCalcController`(①) 또는 #132 후 `ConditionChanges` 한 곳 | 0.3 (#132 없으면 0.6) |
| `PlanContextProviderImpl`(②) | 0.2 (#132에 흡수 가능) |
| `ConditionResolver` override 배선 + 단위 테스트 | 0.3 |
| `PlanService.merge` 2줄 + 적용 테스트 | 0.3 |
| `CalcComparison.ConditionValues` 2필드 + REST Docs 스냅샷 | 0.5 |
| display 키 스키마(`current./changed. goalAmount`, 비교 `heldAssets`) + `ResultDisplayBuilderTest` | 0.7 |
| **C2-4 개정에 따른 `ALREADY_EXCEEDED` 성공응답 처리**(3-4만) | 0.5 |
| 기존 테스트 fixture 컴파일 수선(4파일) | 0.5 |
| 계약 문서·`moeun/docs/api` 사본 | 0.5 |
| **소계(쟁점 3은 3-2 선택)** | **≈4.1일** |
| 쟁점 3-1을 택할 때 추가(Spring+계약+fixture만) | **+1.5일** |
| 쟁점 2에서 `HELD_ASSETS`까지 (2-1 문구·display) | +1.0일 |

### 범위 권고 (제공자 쪽 1순위)

**1단계(이번에 한다, ≈3일):** CHAT만 + `GOAL_AMOUNT`만(2-2) + 쟁점 3은 3-2 + `max-fields: 6` + 쟁점 3-4(`changed` 초과 응답) + C2-4 개정.
**2단계(여유 있으면):** `HELD_ASSETS`(2-1), COMPARE 경로.
**3단계(데모 후):** 쟁점 3-1(초과 계획의 대칭 비교), 입력 수정 버튼 제거(T-13).

C-6에 대한 제공자 답: **COMPARE를 함께 열어도 Spring 추가 비용은 거의 0이다.** `ChangePath.COMPARE`는 코드에서 `PlanService.APPLY_PATHS`(`:51`)와 테스트에서만 쓰이고, 비교 API(#64)는 아직 OPEN(Should)이라 **조회 경로가 없다.** 즉 COMPARE에 6필드를 열어 두는 것은 "#64가 살아날 때를 대비한 yml 1줄"이고, 지금 당장 깨질 것이 없다. 다만 **적용 경로(`merge`)는 CHAT·COMPARE 공용**이므로 어느 쪽을 열어도 `merge` 수정은 필요하다. → **COMPARE도 함께 열자**(비용 0, 나중에 두 번 안 고침).

---

## 7. T-1~T-13 Issue 대조 (실제 `gh` 결과)

`gh issue list -R shinhan-career-next-team-4/moeun --limit 200 --state all` 기준.

| T | 초안 후보 | 실제 상태 | 제공자 판정 |
|---|---|---|---|
| T-1 rules.yml 6필드 | #17 | **#17 CLOSED**(status:review) `[plan] ConditionValidator와 rules.yml` | 제목·범위가 정확히 맞다. CLOSED라 **reopen 또는 신규**. D-058(본문 반영) 취지상 **#17 reopen + 수용 기준 추가**를 권고 |
| T-2 `ConditionOverride` 2필드 + `changedFields` | #17 또는 #10 | 같은 문제 | **#17에 합친다**(ConditionOverride·ConditionValidator가 #17 소관) |
| T-3 `ConditionResolver` override 배선 | #10 | **#10 CLOSED** `[contract] /internal/calc 응답·검증 오류 형식 확정` — **계약 Issue**다. 코드는 **#25 `[calc] 시작월 고정 ConditionResolver`(CLOSED)** / **#32 `[calc] POST /internal/calc`(CLOSED)** | **#10 아님.** 배선은 #32 범위. **신규 Issue 1건**(`[calc] 대화 조건 6필드 배선`)으로 T-2·T-3·T-6을 묶는 편이 낫다 |
| T-4 `PlanService.merge` | #33 또는 #68 | **#33 CLOSED** `[plan] 적용·되돌리기 서비스` — 정확히 맞다. #68은 OPEN이지만 "확인창·취소"(FR-PLAN-01·02)라 다른 범위 | **#33 reopen 또는 위 신규에 포함** |
| T-5 `toOverride` 6키 | #78 | **#78 CLOSED** `[calc] PlanContextProvider`. **그러나 #132 `[calc] 대화 조건 변환 코드를 한 곳으로 모으기`가 OPEN·in-progress**이고 바로 이 중복(①②)을 없애는 중이다 | **#132에 합친다. 그리고 #132를 이번 변경의 선행으로 못 박는다** |
| T-6 `CompareConditionsUseCase` 초과 분기 | #10(+#27·#30) | #27·#30 둘 다 CLOSED. 초과 분기 코드는 #32 | 3-2를 택하면 T-6은 **거의 사라진다**(기존 409 유지). 3-1이면 **신규 Issue 필수**(계약 불변식 변경이라 단독 추적 필요) |
| T-7 internal-calc 계약·fixture | #10 | #10 CLOSED(계약 Issue로 정확) | **#10 reopen**. 단 `backend/src/test/resources/contract/internal-calc/a4-response.json`(`field: "goalAmount"`)도 변경 범위에 **명시**해야 한다 — 초안엔 moeun/docs와 프론트 목만 적혀 있다 |
| T-8 ai-server 6키 | #21 | **#21 CLOSED** `[ai] 대화 조건 4개로 축소 — M-2` | 되살림이므로 **#21 reopen이 가장 정직**하다(이력이 한 곳에 남는다) |
| T-9 프롬프트 + fake 테스트 | #21, #23 | 둘 다 CLOSED. #23은 `[ai] 계산 응답 소비와 되묻기` | **#21에 합치고**, 단위 변환 테스트만 #23 |
| T-10 문구표 | #18 | **#18 CLOSED** `[docs] 문구표 copy.ko.yml` | **#18 reopen.** 더해서 `CopyBook.java:50`의 **코드 목록에 `TOO_MANY_CHANGES`가 없다**는 사실을 본문에 적어 둘 것(1-2를 고를 경우의 숨은 비용) |
| T-11 chat 리스너 4→6키 | #41 | **#41 CLOSED** `[chat] Spring chat 모듈 기반` | 맞다. 단 이 변환도 **#132의 공통 변환기로 흡수 가능** → #132 권고 |
| T-12 프론트 비대칭 카드 | #54 | **#54 OPEN**(in-progress)은 `[front] AI 설명 비동기 표시`다. 비교 **카드**는 **#53 `[front] 대화창 비교 결과 카드와 '내 계획으로 적용' 버튼`(OPEN, in-progress)** | **#54 → #53으로 정정** |
| T-13 입력 수정 버튼 제거 | #51·#49 | 둘 다 CLOSED. #51 `[front] 입력 수정 복귀…`가 정확한 대상 | 이번 범위 밖. 별도 결정 후 **#51 reopen** |

요약: **초안의 Issue 추정 중 T-3(#10→#32/신규)·T-12(#54→#53)는 틀렸고, T-5·T-11은 #132로 합치는 게 맞다.** 그리고 #10·#17·#18·#21·#33·#41·#78이 모두 **CLOSED**라, D-058의 "기존 Issue 본문을 고친다"를 지키려면 **reopen 정책**을 사람이 한 번 정해야 한다(→ Q 후보).

---

## 8. 모듈 경계·ADR 점검

- **의존 방향**: 새 타입 없음. `calc → plan`(`ConditionOverride`, `PlanView`, `ConditionValidator`) 단방향 그대로. `plan`은 `calc`를 참조하지 않는다. **`ModularityTests` 통과 예상, 순환 없음.**
- 단, 2절 ③·④처럼 `calc` 공개 타입(`CalcComparison`, display 키)이 바뀌므로 `calc`의 `package-info.java` 공개 API 설명 갱신이 필요하다(문서 한 줄).
- **ADR-002(최소 저장)**: 계산 결과를 새로 저장하지 않는다. 바뀌는 값은 모두 **이미 있는 `plan_version` 컬럼**이다. 충돌 없음.
- **JWT·인증**: 영향 없음.
- **오류 처리(ProblemDetail)**: 새 오류 코드를 **만들지 않는다**(쟁점 1에서 6을 고르면 `TOO_MANY_CHANGES`도 계속 비활성). 기존 `FIELD_NOT_CHANGEABLE`/`VALIDATION_FAILED`/`ALREADY_EXCEEDED`를 그대로 쓰므로 Spring에서 일관되게 낼 수 있다. **단 쟁점 3-1을 택하면 `ALREADY_EXCEEDED`가 "409 오류"와 "200 성공 안의 status"로 양쪽에 존재하게 되어, 오류 코드 체계의 일관성이 처음으로 흐려진다**(3-2를 권고하는 또 하나의 이유).

---

## 9. 수용 조건 (제공자 쪽 양보 불가 / 가능)

### 양보할 수 없는 것

1. **`InternalCalcController.CHANGEABLE_KEYS`(:39-42)와 `PlanContextProviderImpl.CHANGEABLE_KEYS`(:47-53)를 변경 범위에 명시한다.** 이 두 Set은 `rules.yml`을 읽지 않으므로, 빠지면 yml 변경이 아무 효과가 없거나(①) F-4 비교 조회가 전부 500(②)이 된다. — 근거: 위 두 파일·행
2. **Issue #132(`[calc] 대화 조건 변환 코드를 한 곳으로 모으기`, OPEN·in-progress)를 이번 변경의 선행으로 못 박는다.** 지금 머지 전에 6키로 넓히면 중복 3곳을 각각 고치고 #132가 그걸 또 합치게 되어 충돌이 난다.
3. **배포 순서: Spring(①②+배선) → ai-server 6키(T-8).** 역순이면 저장된 6키 대화가 Spring `recompute`에서 500이 된다(C12b-6).
4. **`CalcComparison.ConditionValues`에 2필드를 더하고 `display`의 무접두어 `goalAmount` 키를 `current./changed.`로 분리한다.** 분리하지 않으면 `CompareConditionsUseCase.buildDisplay`가 current 값을 **조용히 덮어쓴다**. — 근거: `ResultDisplayBuilder.build()` 첫 줄 + 클래스 주석의 "비교에서도 두 계산의 목표가 같다" 전제, `CompareConditionsUseCase:135-137`
5. **internal-calc C2-4 불변식("성공 응답은 항상 `CALCULATED`")은 쟁점 3을 어떻게 정하든 개정해야 한다.** 쟁점 3-4를 받는 순간 `changed.status = ALREADY_EXCEEDED` + `scenarios: []`가 성공 응답에 나온다. 이 한 건만은 반드시 범위에 넣는다.
6. **범위 검증은 Spring 한 곳(D-033) 유지, 단위 자동 보정 금지.** 초안 4-1의 "`2500`을 `25000000`으로 고쳐 주지 않는다"에 전적으로 동의한다. 금액 추측은 PR-04(숫자 일치)를 정면으로 깬다.

### 양보 가능한 것

- **쟁점 1**: 6 권고지만 0도 받는다. **4는 반대**(문구·프론트·ai-server 매핑이 전부 없어서 새로 만들어야 한다).
- **쟁점 2**: 2-1 동의. 범위가 빠듯하면 **2-2(목표 금액만)로 줄여도 제공자 쪽은 이견 없다**(≈1일 절감). 2-4는 D-013·D-032를 뒤집으므로 **반대**.
- **쟁점 3-1**: 사람이 3-1을 택하면 구현한다. 다만 **3-2를 1순위로 권고**하고, 3-1은 데모 이후로 분리할 것을 요청한다(비용 +1.5일, 회귀 범위가 전체 비교 응답).
- **COMPARE 동시 개방**: 제공자 쪽 추가 비용 0이므로 **같이 열자**는 입장이지만, 소비자가 CHAT만 원하면 수용한다.
- **쟁점 2-1의 문구 전달 경로**: `display` 맵이 아니라 별도 `notes`를 선호하지만, `DISPLAY_KEY` 정규식과 비교 display의 `calcStartMonth` 부재만 해결되면 `display` 방식도 받는다.
- **Issue 운용**: reopen이든 신규든 따른다. 다만 #10·#17·#18·#21·#33·#41·#78이 모두 CLOSED라는 사실만은 결정 전에 사람이 알아야 한다.
