# 대화·비교로 바꿀 수 있는 조건 확장 — 계약 개정 초안 v2 (CF12)

- 작성: tech-architect, 2026-11-20 (v1 → 제공자·소비자 독립 검토 → v2)
- 입력 문서: `changeable-fields-v1.md`, `review-changeable-fields-v1-provider.md`, `review-changeable-fields-v1-consumer.md`
- 항목 ID: `CF12-x`(v1과 같은 체계). 쟁점은 v2에서 **`X-A`~`X-E`** 로 다시 번호를 매긴다(v1의 쟁점 1~4와 매핑은 §Z).
- 상태: **초안 v2**. **합의 항목은 확정분으로 본문에 녹였고, `X-A`~`X-E` 5건은 사람이 정한다.** 이 문서만으로 코드·계약을 고치지 않는다.
- 코드 근거: `../moeun` `feature/126-input-suggestion` **읽기 전용**(switch·fetch·수정 없음). 행 번호는 그 브랜치 기준.
- 이 문서는 **자기완결**이다. v1을 읽지 않아도 된다. v1 → v2 변경은 §Z에 전부 적는다.

---

## CF12-1. 배경과 제품 방향 (확정, 양쪽 수용)

- 입력 화면을 한 번 거친 뒤에는 계획 조건을 **AI 대화로만** 바꾸게 하고, 결과 화면의 '입력 수정' 버튼은 **나중에 없앤다**(버튼 제거 자체는 이번 결정 범위 밖 → T-13).
- 그런데 지금 CHAT·COMPARE 허용 필드가 4개(월 저축액, 비중, 적금 금리, 기한)뿐이어서 **목표 금액·보유 자산은 대화로 바꿀 수 없다**(`422 FIELD_NOT_CHANGEABLE`).
- 특히 FR-RES-01의 초과 안내와 `chat.unchangeableCondition`·`chat.alreadyExceeded` 문구가 **"목표 금액은 입력 수정에서 바꿀 수 있어요"** 로 입력 수정 버튼을 가리킨다. 버튼이 사라지면 이 안내는 **막다른 길**이 된다.
- 그래서 버튼을 없애기 **전에** 대화·비교로 바꿀 수 있는 필드를 먼저 넓힌다.
- 왜 이렇게 했는가: 안내가 가리키는 출구를 먼저 만들고 나서 기존 출구를 닫는 순서여야, 어느 시점에도 사용자가 갇히지 않는다.

### CF12-2. 범위

| 항목 | 내용 |
|---|---|
| 추가 필드 | 사용자가 못 박은 것은 **`GOAL_AMOUNT`, `HELD_ASSETS` 둘**. 다만 **양쪽 검토가 모두 1단계는 `GOAL_AMOUNT`만** 권고 → **쟁점 X-B** |
| 넣지 않는 것 | 목표 종류(`GOAL_TYPE`/`GOAL_CUSTOM_NAME`), 기존 납입액(`existingMonthlyContribution`). 목표 종류는 나중에 '새 목표 세우기'로 따로 다룬다 |
| 적용 경로 | 사용자가 못 박은 것은 **CHAT, COMPARE 둘 다**. 소비자는 COMPARE 보류를 권고 → **쟁점 X-C** |
| 그대로 두는 경로 | `ALTERNATIVE`(3필드, `max-fields: 1`), `INPUT_EDIT`(`all-fields: true`) |

### CF12-3. D-040 대체 선언 (확정)

> **이 변경은 D-040("대화로 바꿀 수 있는 조건은 기존 4개를 유지하고 목표 금액은 입력 수정으로 바꾼다")을 뒤집는다.**
> 결정되면 새 D-번호를 받아 **D-040을 대체**하고, D-040 상태는 "대체됨 → D-xxx"로 바꾼다.
> 같이 바뀌는 확정 항목: **CP-07**(SRS 26행), **D-056**(문구 안의 "4개 조건"), **D-071**(초과 계획의 대화 재계산 — **부분 대체**, 쟁점 X-A), **D-035**(보유 자산 기준월 안내 — 범위 확장, 쟁점 X-B에 종속), **D-059**("네 조건" → "여섯 조건").
> **그대로 유지**: D-041(기준은 항상 내 계획, 누적 금지), D-033(범위 검증은 Spring 한 곳), D-013·D-032(시작월은 재계산해도 바뀌지 않는다), D-022(적용은 버튼), ADR-002(최소 저장).

---

## CF12-4. 코드 현황 — 구현 지점 전체 목록 (제공자·소비자 검토 반영)

v1은 6곳이라고 적었다. 두 검토로 **13곳**이 되었다. 굵은 항목은 v1에 **없던 것**이고, 전부 "요청은 통과하는데 값이 안 바뀜/조용히 사라짐"을 직접 만든다.

### CF12-4-1. Spring (A팀)

| # | 파일·위치 | 사실 | 이번 변경에서 할 일 |
|---|---|---|---|
| a | `plan/application/PlanRules.java:38-42` `PathRule.allows()` | `allFields \|\| fields.contains(field)` | 허용 목록은 yml만 고치면 된다 |
| b | `plan/ConditionValidator.java:83-86` | `maxFields() > 0 && changed.size() > maxFields` → `TOO_MANY_CHANGES` 1건 내고 즉시 반환. `0`은 제한 없음 | 지금 CHAT·COMPARE는 허용 4 = max 4라 **이 분기는 도달 불가**였다 → `max-fields: 6`(확정, CF12-6) |
| c | `plan/ConditionValidator.java:97-107` `changedFields(ConditionOverride)` | 4필드만 맵에 넣는다 | 2필드 추가. 안 하면 COMPARE 경로의 새 2필드가 **검증조차 되지 않고 조용히 사라진다** |
| d | `plan/ConditionOverride.java:6` | `record ConditionOverride(Long monthlySavingAmount, Integer targetPeriodMonths, Integer savingsRatioPct, BigDecimal savingsRateInputPct)` | **필드 2개 추가**(공개 타입 변경 → calc·plan·chat 호출부 전부 영향, 테스트 fixture 컴파일 깨짐 CF12-4-4) |
| **e** | **`calc/web/InternalCalcController.java:39-42` `CHANGEABLE_KEYS`** | `Set.of(MONTHLY_SAVING_AMOUNT, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT, TARGET_PERIOD_MONTHS)`. **이 Set은 `rules.yml`을 보지 않는다.** 검사 순서 3(`:66-72`)에서 `goalAmount`가 오면 yml이 6필드든 말든 `422 FIELD_NOT_CHANGEABLE` | **양보 불가(제공자 조건 1).** 이걸 안 고치면 **CF12-5의 yml diff는 `/internal/calc`에 효과가 0이다** |
| **f** | **`calc/web/InternalCalcController.java:86-110` `validate()` / `:99-100` `hasValidatableValue`** | `toInteger(...)`로 키를 하드코딩해 하나씩 꺼낸다 | `goalAmount`(long)·`heldAssets`(long) 두 줄 + `hasValidatableValue` 조건 2개 추가. 빼먹으면 `conditionChanges: {goalAmount: …}` 하나만 온 요청이 **검증을 건너뛰어 범위 밖 값이 엔진까지 간다** |
| g | `calc/application/ConditionResolver.java:54,57` | `long goalAmount = require(plan.goalAmount(), …)` / `heldAssets` 동일 — **`changes`를 아예 보지 않는다** | 엔진 입력에 override 배선. 빼먹으면 "요청은 통과하는데 결과가 안 바뀜" |
| h | `plan/application/PlanService.java:202-216` `merge()` | `goalAmount`·`heldAssets`를 **현재 버전 값으로 하드코딩**해 `fields`에 넣는다 | `firstNonNull(changes.goalAmount(), current.getGoalAmount())` **2줄**. 빼먹으면 "카드는 바뀌는데 적용하면 안 바뀜" |
| **i** | **`calc/application/PlanContextProviderImpl.java:47-53` `CHANGEABLE_KEYS`** | 키를 막는 건 `toOverride()`(`:168-181`)가 아니라 **그 위의 Set**(`:52`)이고, 허용 밖 키는 `IllegalArgumentException`(`:170-172`) | **양보 불가(제공자 조건 1).** 저장된 대화 재계산(F-4)에 `goalAmount`가 있으면 **500**. ai-server가 6키를 저장하기 시작하는 순간 이 두 줄 없으면 **F-4 비교 조회가 전부 500** → 배포 순서(CF12-11) 근거 |
| j | `calc/application/PlanContextProviderImpl.java:168-181` `toOverride()` | 4키 고정 | 6키 |
| **k** | **`calc/CalcComparison.java:29-45` `ConditionValues`** | `record ConditionValues(Long monthlySavingAmount, int savingsRatioPct, BigDecimal savingsRateInputPct, Integer targetPeriodMonths)` — internal-calc C2-3이 "4개 키가 항상 모두 있다"고 쓴 그 레코드 | **2필드 추가**(공개 레코드 = 응답 JSON 모양 변경 → REST Docs 스냅샷 `docs/InternalCalcDocsTest.java`, ai-server `ComparisonResponse` 동반 변경). 빼면 "계산은 됐는데 응답에 바뀐 목표 금액이 안 보임" |
| **l** | **`calc/application/ResultDisplayBuilder.java`** | 클래스 주석: `goalAmount`는 *"접두어 없음(비교에서도 두 계산의 목표가 같다)"*, `build()` 첫 줄 `display.put("goalAmount", …)`. `CompareConditionsUseCase.buildDisplay:135-137`이 `build()`를 current·changed 두 번 불러 `putAll` | **양보 불가(제공자 조건 4).** 목표 금액이 바뀐 비교에서 **changed 값이 current를 조용히 덮어쓴다.** → display 키를 **`current.`/`changed.` 로 분리**(확정, CF12-8-3) |
| **m** | **`ResultDisplayBuilder.putConditions(...)`** | `heldAssets`·`calcStartMonth`·`assumptions`를 **`isSingleResult`일 때만** 넣는다(= 비교 display에 아예 없다). C2-6이 의도적으로 정한 것 | 쟁점 X-B로 `HELD_ASSETS`를 열면 이 `if`를 풀고 **C2-6 개정**이 필요하다(비교 display에 `calcStartMonth` 추가 — CF12-7) |
| n | `calc/CalcInput.java:63-64` | `hasExceededGoal()` = `heldAssets >= goalAmount`, 매번 계산(캐시 없음) | 두 추가 필드가 **바로 이 판정의 두 변수** → 쟁점 X-A |
| o | `calc/application/CompareConditionsUseCase.java:88-92` | `current.input().hasExceededGoal()`이면 `current`도 계산하지 않고 `409 ALREADY_EXCEEDED`. 코드 주석: *"대화로 목표·보유 자산을 바꿀 수 없어 changed도 초과다"* | **이 주석의 전제가 깨진다** → 쟁점 X-A |
| p | `calc/application/CalcEngine.java:93-95,159` | 초과면 `CalcStatus.ALREADY_EXCEEDED` + `scenarios` 빈 목록. `principal = heldAssets + monthlySavingAmount * k` | `changed`가 초과가 되는 경우의 응답 모양은 **이미 엔진에 있다**(CF12-8-2) |

### CF12-4-2. ai-server (B팀)

| # | 파일·위치 | 사실 | 이번 변경에서 할 일 |
|---|---|---|---|
| q | `app/schemas.py:31-42` `ConditionChanges` | `extra="forbid"` + 4필드, docstring "조건 4개(M-2, D-040)" | `goal_amount`, `held_assets`: `StrictInt \| None` 추가, docstring D-번호 갱신 |
| r | `app/llm/agent.py:74-79,86-87` `_CONDITION_FIELDS`·`recalculate` 도구 | 4키, 설명문 "네 가지", "금액은 원 단위 정수" | 6키, "여섯 가지". `required`는 `list(_CONDITION_FIELDS)`라 자동. `strict: True` 규칙 유지 |
| **s** | **`app/llm/agent.py:165-230` `_stated_conditions`·`drop_carried_conditions`** | 발화 표현으로 "말한 조건"을 4개만 가려내고 **그 밖의 키는 history에서 이어받은 값으로 보고 지운다**(`:230` `if k in stated`) | **소비자 핵심 발견.** 새 두 키를 모르므로 **history 있는 대화에서 사용자가 말한 `goal_amount`·`held_assets`가 계산 전에 조용히 지워진다.** 결과: `:383` "바꿀 조건이 없습니다" CLARIFY(최선) 또는 같이 말한 다른 조건만 계산. 더 나쁜 것은 **`_MONTHLY`(`:186` `만원`·`\d\s*만`·`\d\s*원`)가 목표 금액 발화에도 걸려 "2,500만원"을 월 저축액으로 오인**하는 것 → 새 정규식 `_GOAL`(목표·모으려), `_HELD`(보유·가진·모아둔·이미·지금 있는) 추가 + 목표·보유 단어가 있으면 일반 금액 표현을 월 저축액으로 세지 않게 |
| **t** | **`app/tools/calc.py:86-102` `_select_for_model`, `:117-125` `_select_side`** | 모델에 `scenarios[].{scenario,isAchieved}`만 준다. **`status`를 안 준다.** `_check_display`(`:105-114`)는 빈 `scenarios`면 루프를 안 돌아 통과 | 한쪽이 `ALREADY_EXCEEDED, scenarios: []`면 모델은 "빈 목록"만 보고 사유를 모른다 → **`status` 통과 필수**(프롬프트 규칙 9가 동작하려면) |
| u | `app/llm/prompts.py:7-8` `GOAL_AMOUNT_COPY` | `= chat.unchangeableCondition` | 상수를 **삭제하지 않고 목표 종류·기존 납입액 전용 문구로 재사용**(소비자 권고. 삭제하면 고정 문장 보호가 사라진다) |
| v | `prompts.py:18` | "네 가지뿐" | "여섯 가지" |
| w | `prompts.py:21-22` | 목표 금액 발화 → `recalculate` 부르지 않고 전용 문구 | **삭제**(막다른 길의 직접 원인) |
| **x** | **`prompts.py:23-24`** | "이미 모은 돈이나 기존 납입액 … 입력 수정에서 바꿀 수 있다고" | v1이 빠뜨림. "이미 모은 돈"은 이제 `held_assets`다. **"기존 납입액"만 남기고** 목표 종류와 함께 전용 문구로. 이 줄이 남으면 "3,000만원 모았어요"에 옛 문장으로 답하는 회귀 |
| **y** | **`prompts.py:25-27`** | "네 조건을 더/덜…"(D-059 상대 표현 → CLARIFY) | "여섯 조건". 목표·보유도 상대 표현은 되묻는다 |
| **z** | **`prompts.py:30-31`** | "goalAmount는 같은 값이라 어느 쪽을 인용해도 됩니다" | **전제가 깨진다.** `current.goalAmount`/`changed.goalAmount`를 갈라 인용하게 고친다. 안 고치면 모델이 엉뚱한 쪽을 인용 |
| aa | `prompts.py:53-54` | 초과면 "목표 금액은 입력 수정에서 바꿀 수 있어요" | "대화로 목표 금액을 바꿔 볼 수 있어요"(문구표 문장 그대로 인용) |
| bb | `prompts.py:70,75` | 조건 변경 정의 4개 / "목표 금액 발화는 그 밖의 질문이 아니다" | `:70` 6개, `:75` **삭제** |
| cc | `agent.py:45-57` `out_of_scope_content`·`_CONDITION_COPY_KEYS`, `app/core/copy.py:93` `_CONDITION_CODES` | 범위 밖 안내가 "4개 조건 이름"을 잇는다 | 문구표에 `condition.goalAmount`·`condition.heldAssets` 추가 → 6개. `tests/test_out_of_scope.py:119-125`가 "목표 금액이 **없다**"를 단언하므로 **뒤집힌다** |
| dd | `agent.py:139-144` `_FIXED_COPY_KEYS` | `FIELD_NOT_CHANGEABLE → chat.unchangeableCondition` | **매핑·키 유지**(목표 종류·기존 납입액·오타 키의 방어선). 단 본문에서 "입력 수정에서 바꿀 수 있어요"를 빼고 **"여기서는 바꿀 수 없어요"로 끝낸다**(막다른 길 재발 방지) |
| ee | `agent.py:143,424,441` | `"ALREADY_EXCEEDED": "chat.alreadyExceeded"` 매핑과 분기가 **409 오류 경로 기준** | 쟁점 X-A가 3-1이면 "409 오류"와 "200 성공 안의 status" 둘을 구분하도록 개정 |
| ff | `agent.py:570,582` `load_copy()`·`with_tax_note` | ai-server가 문구표를 직접 읽고, `check_numbers` **뒤에** 문장을 덧붙이는 자리가 이미 있다 | `chat.heldAssetsBasis`·`chat.goalAmountChangedNote` 덧붙이기를 **같은 자리·같은 방식**으로(D-073) |

### CF12-4-3. chat 저장·프론트

| # | 위치 | 사실 | 할 일 |
|---|---|---|---|
| gg | chat 리스너(#41) camelCase 변환 | **4키 고정 맵** | 6키. **모르는 키가 올 때의 동작이 계약에 없다** → 쟁점 X-E |
| hh | `frontend/src/features/chat/ChatWindow.tsx` | 대화 비교 카드가 **아직 없다**(diff·changed 렌더링 없음). 초과는 `:112` `settledStatus === "ALREADY_EXCEEDED"` 고정 문장뿐 | 카드를 **처음부터** 설계하므로 한쪽 초과 카드가 지금이 가장 싸다(소비자) |
| ii | `frontend/src/features/chat/types.ts`, `copy.ts:5`, `shared/copy/copy.ts:30` | F-4 응답 타입에 `status` 없음. `alreadyExceeded` 본문이 프론트에 복제되어 있다 | `status` 필드 추가, 문구표와 동기화 |
| jj | `frontend/src/mocks/chat/post-apply.422-field-not-changeable.json` | `errors[].field = "goalAmount"` | 값 교체(`goalType` 등) |

### CF12-4-4. 테스트·fixture 깨짐 (확정 — 변경 범위에 명시)

| 대상 | 내용 |
|---|---|
| **`ConditionOverride` 생성자** | `new`로 부르는 테스트 **4파일 20여 곳**이 인자 개수 때문에 전부 컴파일 깨짐: `ConditionValidatorTest`, `ConditionResolverTest`, `ChatComparisonQueryTest`, `PlanContextProviderTest`. 기계적이지만 **≈0.5일** |
| **계약 fixture** | `backend/src/test/resources/contract/internal-calc/a4-response.json`이 `field: "goalAmount"` → **반드시 교체**. `a5-already-exceeded.json`은 쟁점 X-A가 3-1이면 성공 예시 **신설** |
| REST Docs | `backend/src/test/java/com/moeun/backend/docs/InternalCalcDocsTest.java` 스냅샷(CF12-4-1 k·l) |
| ai-server fixture | `tests/test_calc_client.py:269` + `docs/api/examples/.../field-not-changeable-response.json`의 `field: goalAmount` |
| **고정 문장 테스트(삭제 금지)** | CF12-9-2 표 |

> 한 줄 결론: **yml 2줄짜리 변경이 아니다.** yml(a) + 조건 레코드(d) + **컨트롤러 Set·validate(e·f)** + 해석기(g) + 적용 병합(h) + **planContext Set(i)** + **응답 레코드(k)** + **display 키 분리(l)** + ai-server 스키마·프롬프트·**`drop_carried_conditions`(q~ff)** + chat 맵(gg)을 같은 묶음으로 가야 "통과하지만 안 바뀜"과 "조용히 지워짐"을 피한다.

---

## CF12-5. `rules.yml` 변경 후 전문 (확정, 양쪽 수용)

`moeun/backend/src/main/resources/config/rules.yml`

```diff
     fields:   # 경로와 무관한 전역 한 벌 — 한 글자도 바뀌지 않는다
       GOAL_CUSTOM_NAME:       { required: false, min: 1, max: 100, unit: CHAR }
       GOAL_AMOUNT:            { required: true, min: 10000, max: 10000000000, unit: KRW, scale: 0 }
       TARGET_PERIOD_MONTHS:   { required: true, min: 1, max: 360, unit: MONTH, scale: 0 }
       HELD_ASSETS:            { required: true, min: 0, max: 10000000000, unit: KRW, scale: 0 }
       MONTHLY_SAVING_AMOUNT:  { required: true, min: 10000, max: 10000000, unit: KRW, scale: 0 }
       SAVINGS_RATE_INPUT_PCT: { required: false, min: 0, max: 20, unit: PCT, scale: 2 }
       SAVINGS_RATIO_PCT:      { required: false, min: 0, max: 100, unit: PCT, scale: 0 }
     change-paths:            # max-fields 0 = 제한 없음
       INPUT_EDIT:  { all-fields: true, max-fields: 0 }
       ALTERNATIVE: { fields: [MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT], max-fields: 1 }
-      COMPARE:     { fields: [MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 4 }
-      CHAT:        { fields: [MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 4 }
+      # CF12(D-040 대체): 입력 수정 버튼을 없애기 전에 목표 금액·보유 자산을 대화·비교로 바꿀 수 있게 한다.
+      # 목표 종류(GOAL_TYPE / GOAL_CUSTOM_NAME)·기존 납입액은 넣지 않는다.
+      COMPARE:     { fields: [GOAL_AMOUNT, HELD_ASSETS, MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 6 }
+      CHAT:        { fields: [GOAL_AMOUNT, HELD_ASSETS, MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 6 }
```

- `fields:` 블록은 **불변**(전역 한 벌이고 두 필드의 범위·단위·scale이 이미 있다). 범위 수치가 그대로라서 대화 경로의 오류 문구·`min`/`max` 인용도 그대로 쓸 수 있다. — 제공자·소비자 모두 확인.
- **주의**: 이 diff만으로는 `/internal/calc`에 **효과가 0**이다(CF12-4-1 e). 반드시 e·f·i와 같은 묶음.
- 위 diff는 쟁점 **X-B**(`HELD_ASSETS` 포함 여부)와 **X-C**(COMPARE 포함 여부)에 따라 줄이 줄어든다. `HELD_ASSETS`를 빼면 `max-fields: 5`, COMPARE를 빼면 `COMPARE:` 줄은 현행 유지.

---

## CF12-6. `max-fields` = **6** (확정, 양쪽 수용 — v1 쟁점 1 종결)

**사실**: `ConditionValidator.java:83-86`의 분기는 `maxFields() > 0 && changed.size() > maxFields`다. 지금 CHAT·COMPARE는 허용 4 = max 4이므로 **한 번도 도달한 적이 없다.** `TOO_MANY_CHANGES`는 `FieldError.java:22-24`에 생성자만 있고, 쓰이는 곳은 `ConditionValidator:84`와 `ConditionValidatorTest:25`(ALTERNATIVE) **뿐**이다.

**`4`를 거절하는 이유(양쪽 일치)**: 4로 두면 **처음으로 실제 제한이 생겨 `TOO_MANY_CHANGES`가 처음 발생한다.** 그런데
- `CopyBook.java:50` 코드 목록에 `TOO_MANY_CHANGES`가 **없다**(있는 것: `ALREADY_EXCEEDED`, `MALFORMED_REQUEST`, `INVALID_INTERNAL_KEY`, `CALC_FAILED`).
- 프론트 `src/api`에 `NOT_CHANGEABLE`/`reason` 분기 처리 코드가 **0건**.
- ai-server도 없다. 422 `VALIDATION_FAILED`의 `errors[].reason`으로 오면 `agent.py:352-363`이 `validation_failed → CLARIFY`로 처리하고 모델은 `min`·`max`가 없는 오류를 받아 "허용 범위를 벗어났어요"라고만 말한다 → **사용자에게 이유를 전할 수 없다.**
- 즉 4는 문구표 키 신설 + ai-server 매핑 + 프론트 분기 + 테스트가 새로 필요하다(≈0.5~1일, 가치 0).

`0`(제한 없음)은 가드가 사라져 나중에 허용 목록이 잘못 넓어져도 아무도 못 알아챈다.

**확정: `6`.** 왜: 지금 동작을 바꾸지 않으면서(새 오류 경로 0개) CP-07의 "한 번에 바꾸는 개수를 정한다"를 글자대로 지키고, 나중에 필드를 더 늘릴 때 숫자를 안 고치면 테스트가 깨져 **의도적 확장임이 드러나는** 가드만 남긴다. 비용 0.
**딸림 확정**: `TOO_MANY_CHANGES`의 문구·화면·ai-server 매핑은 **이번에 만들지 않는다**(6이면 발생하지 않는다). 나중에 값을 줄일 때 소비자 쪽에서 함께 만든다.

---

## CF12-7. `HELD_ASSETS`와 D-035 — 계산은 맞다, 가드가 필요하다

### CF12-7-1. 확정 사실 (제공자 확인)

- `CalcInput.java:18` 주석 "보유 자산. 0 이상이며 운용 수익 없이 원금에 더한다", `:46` `heldAssets >= 0` 검증.
- `CalcEngine:159` `principal = heldAssets + monthlySavingAmount * k` — **"시작월 시점의 출발 잔액" 한 가지 뜻**뿐. 그래프 첫 점(k=0) = `heldAssets`.
- `ConditionResolver.createInput:92-99`은 `calcStartMonth`를 **항상 계획 저장값**으로 쓴다(D-013·D-032).
- → **override로 `heldAssets`를 바꿔도 계산 자체는 올바르다. 엔진에 이중 계산 로직은 없다.**

**남는 위험은 전적으로 "사용자가 말한 숫자의 의미"다.** "지금 3,000만원 모았어요"는 *시작월 이후 납입이 이미 포함된 총액*이고, 그걸 `heldAssets`로 넣으면 시작월 이후 납입과 이중 계산된다. D-035가 입력 수정 화면에서 문구(`input.heldAssetsRecheck`, `{calcStartMonth}` 자리)로 막은 것과 **똑같은 위험**이고, 대화에는 그 문구가 없다.

### CF12-7-2. 가드 설계 (확정 — 양쪽 합의 교집합)

`HELD_ASSETS`를 1단계에 넣기로 하면(쟁점 X-B) 아래가 함께 간다.

1. **문장은 코드가 붙인다. 모델이 짓지 않는다.** `conditionChanges`에 `held_assets`가 **있을 때만** ai-server가 문구표 `chat.heldAssetsBasis`를 읽어 답변에 덧붙인다(`load_copy()` `agent.py:570`, `with_tax_note` `agent.py:582`와 **같은 자리·같은 방식**, D-073).
2. **위치는 답변 맨 끝, `check_numbers` 뒤.** `{calcStartMonth}`(`2026년 11월`)가 숫자 토큰이라 앞에 붙이면 `NUMBER_MISMATCH`가 난다.
3. **Spring은 문장이 아니라 자리 값만 내린다.** 비교 응답 `display`에 **`calcStartMonth`(표시 문자열)** 를 추가한다(지금 비교 display에는 없다 — CF12-4-1 m). `DISPLAY_KEY` 정규식(`schemas.py:54-59`)에 `calcStartMonth`는 **이미 있다.**
   - **문구 키를 `display` 맵에 넣지 않는다.** display는 "키 → 숫자 표시 문자열"이라는 뜻이 명확하고, 문장을 섞으면 PR-04 숫자 대조(#37)가 **오탐**한다(제공자). 서버가 문장을 내려야 할 일이 생기면 `display`가 아닌 **별도 `notes` 문자열 목록**을 쓴다(제공자 권고). 이번 범위에서는 ai-server가 문구표를 읽으므로 `notes`도 필요 없다(소비자).
   - `calcStartMonth` 키가 없으면 **문장을 생략하고 로그만 남긴다.** 틀린 월을 말하는 것보다 안전하다.
4. **카드에도 같은 문구.** 사용자는 답변 문장을 읽지 않고 카드의 적용 버튼만 누를 수 있다. F-4 `changedKeys`에 `heldAssets`가 있으면 카드 안에 같은 문구 키를 **정적으로** 표시한다.
5. **문장은 방향을 알려 준다.** 단순 경고가 아니라 사용자가 값을 다시 말하게 해야 한다. 본문 방향: **"이 값은 {calcStartMonth} 당시 기준이라, 그 뒤 납입분은 월 저축액으로 이미 계산돼요."** 용어는 D-035 문구("{시작월} 당시 쓸 수 있던 돈")를 그대로 재사용해 맞춘다.
6. **C2-6 개정 필요**: "비교에서는 `heldAssets`·`calcStartMonth`·`assumptions`를 만들지 않는다"는 의도적 규칙을 푼다(`ResultDisplayBuilder`의 `isSingleResult` 분기).

### CF12-7-3. 거절한 안

- **D-035를 "보유 자산 변경 시 시작월을 이번 달로 다시 잡는다"로 바꾸는 안**: 뜻은 가장 깨끗하지만 D-013·D-032를 뒤집고 계획 버전·그래프 축·`calc_run`까지 번진다. **제공자 반대, 3주 범위 밖. 폐기.**
- **조건 없이 허용(문구 없음)**: D-035가 막은 위험이 대화 경로로 되살아난다. **폐기.**

---

## CF12-8. 초과 판정과 비교 표시

목표 금액·보유 자산은 **초과 판정(`heldAssets >= goalAmount`)의 두 변수 그 자체**다. 그래서 이번 변경은 네 가지 상태를 만든다.

| 경우 | 지금 | 이번 변경 뒤 |
|---|---|---|
| (A) 미달 계획에서 기존 4필드만 바꿈 | 양쪽 계산, 비교 카드 | 그대로 |
| (B) **초과 계획**에서 조건을 바꿈 | `current`도 계산하지 않고 `409 ALREADY_EXCEEDED` 고정 문장(D-071) | **목표 금액을 올려 초과를 벗어나는 경로가 막혀 있다** → **쟁점 X-A** |
| (C) 미달 계획에서 **목표를 내리거나 보유 자산을 올려 `changed`가 초과** | 생길 수 없었다(코드 주석이 그 전제) | `changed.status = ALREADY_EXCEEDED`, `scenarios: []` → CF12-8-2 (**확정**) |
| (D) 미달 계획에서 목표 금액을 올림/내림 | 생길 수 없었다 | `gapToGoal`·`isAchieved`·`goalReachMonth`가 **양쪽에서 다른 목표선**으로 계산된다 → CF12-8-3 (**확정**) |

### CF12-8-0. internal-calc C2-4 불변식 개정 — **확정, 어느 선택지에서도 필수**

C2-4는 지금 *"`status`는 이 경로의 성공 응답에서 항상 `CALCULATED`… 대화로 목표 금액·보유 자산을 바꿀 수 없으므로(D-040) `changed`도 `CALCULATED`다"* 라고 적는다.

- **(C)를 받는 순간** `changed.status = ALREADY_EXCEEDED` + `scenarios: []`가 **성공 응답에 나온다.** (C)는 `HELD_ASSETS`를 빼도(X-B) "목표 금액을 내려서 초과"로 여전히 가능하다.
- 소비자도 **`current`·`changed` 각각의 `status`** 를 요구한다(그걸로 칸을 고른다, 문자열 해석 없음).
- → **확정: C2-4 불변식을 개정하고, `/internal/calc` 응답과 F-4 응답(`CalcResultView`) 양쪽에 `current.status`·`changed.status`를 담는다.** 프론트 타입(`features/chat/types.ts`)에 필드 추가.
- 제공자 조건 5(양보 불가) = 소비자 수용 조건 5의 일부. **쟁점 X-A를 어떻게 정하든 이 한 건은 범위에 넣는다.**
- 왜 이렇게 했는가: 소비자가 빈 `scenarios`의 **사유**를 알 수 없으면 카드가 "계산 실패"와 "이미 달성"을 구분할 수 없다.
- 딸림: **`calc.py:_select_for_model`·`_select_side`가 `status`를 모델에 통과시킨다**(지금 안 준다). 안 하면 프롬프트 규칙 9가 동작할 수 없다.
- 딸림: **별도 `comparable` 플래그는 두지 않는다**(status 두 개로 결정된다). — 소비자 "빼도 되는 것"

### CF12-8-1. 쟁점 X-A — 초과 계획에서 대화로 목표를 올려 초과를 벗어나는 경로 → **§X-A** (가장 큰 쟁점, 양쪽 정면 충돌)

사실 관계만 여기 적고, 선택지는 §X-A에.
- D-071은 *"초과 계획에서 대화로 **4개 조건(D-040)** 을 바꾸면 `ALREADY_EXCEEDED` 고정 문장"* 이라고 범위를 4개 조건으로 한정한다. 문자 그대로 읽으면 목표 금액·보유 자산 변경은 **D-071의 범위 밖(공백)** 이다.
- 그러나 구현 `CompareConditionsUseCase:88-92`는 **변경 키와 무관하게** `current` 초과만 보고 던진다 → **코드는 충돌한다.** 결정이 필요하다.

### CF12-8-2. (C) `changed`가 초과가 되는 경우 — **확정 (양쪽 수용)**

- `changed.status = ALREADY_EXCEEDED`, `changed.scenarios: []`, `diff.byScenario: []`.
- 카드의 "바꾼 조건" 칸은 **초과 문장**을 쓴다. 초과 **금액은 말하지 않는다**(plan-context 프롬프트 규칙 9).
- **적용 버튼은 활성.** 사용자가 사실(이미 모았다/목표를 낮췄다)을 계획에 반영할 수 있어야 한다. 적용 후 결과 화면의 초과 전환은 **이미 구현되어 있다**: `ChatWindow.tsx:112` `settledStatus`, `ResultPage.tsx`, mock `put-plan.200-exceeded.json`·`get-plan.seq-exceeded-toggle.json`, D-072(`revision` 구독 한 곳)·#52.
- **카드에 예고 한 줄이 필요하다**(소비자): `chat.alreadyExceeded`("이미 넘었어요")만 쓰면 사용자가 방금 말한 의도의 **확인**으로 읽힌다. **"이 조건으로 적용하면 이미 목표를 넘은 상태가 돼요"** 류 신규 키(`chat.changedAlreadyExceeded`, 이름은 #18에서).
- 초과 칸도 display가 필요하다: 초과 문장이 `result.alreadyExceeded`(`goalAmount`·`heldAssets` 자리, `frontend/src/shared/copy/copy.ts:30`에 이미 있음)를 쓰므로 **초과인 쪽에도 `*.goalAmount`·`*.heldAssets` display를 내린다.**
- 왜 이렇게 했는가: 응답 모양은 `CalcEngine:93-95`가 이미 만들고 적용 후 경로도 이미 있으므로, 추가 개념 없이 "사실을 반영할 수 있다"를 지킬 수 있다.
- **거절**: "적용 버튼 비활성 + 적용할 수 없어요" 안(사용자가 사실을 계획에 반영할 수 없게 된다).

### CF12-8-3. (D) 목표 금액이 바뀐 비교의 표시 — **확정 (수정 수용)**

1. **display 키를 쪽별로 분리한다(양보 불가).** 지금 `ResultDisplayBuilder`는 `goalAmount`를 **접두어 없이** 넣고(`build()` 첫 줄, 클래스 주석의 "비교에서도 두 계산의 목표가 같다" 전제) `CompareConditionsUseCase.buildDisplay:135-137`이 `build()`를 두 번 불러 `putAll`하므로, **목표가 바뀐 비교에서 changed 값이 current를 조용히 덮어쓴다.** → 쪽별 키로 분리하고 **ai-server `DISPLAY_KEY` 정규식(`schemas.py:54-59`)을 함께 개정**한다.
   - 분리 대상: 목표 금액, 그리고 `HELD_ASSETS`를 열면 보유 자산도.
   - **키를 `conditionChanges`에 해당 키가 있을 때만 만든다**(평소 비교 응답 모양을 바꾸지 않는다).
   - 키 **이름**은 제공자(`current.goalAmount`)와 소비자(`conditions.current.goalAmount`)가 **한 글자 다르다** → 재검토 질문(§재검토 P-2·C-2). 기획 권고는 **`conditions.current.goalAmount` / `conditions.changed.goalAmount`**: 목표 금액·보유 자산은 조건 값이고 C2-6에 이미 `conditions.<side>.…` 체계가 있어 새 접두어를 만들지 않는다.
   - 최상위 단일 `goalAmount` 키는 단일 계산(결과 화면) 경로에서 **그대로 두고**, 목표가 바뀐 비교에서는 **프롬프트가 인용하지 않게** 한다(`prompts.py:30-31` 개정).
2. **`achievementChange`(`diff.byScenario[].`)는 그대로 쓴다.** `null`로 숨기지 않는다(v1의 3-7 안 **폐기**, 소비자 반대). 이유: 이 필드가 주 사용 사례("목표를 낮추면 달성돼요")의 핵심 정보이고, 사용자가 목표를 직접 말했으므로 사실이다. 오해 위험은 "조건이 좋아졌다"로 읽히는 것뿐이다.
3. **주의 문구는 코드가 붙인다.** 신규 `chat.goalAmountChangedNote`를 `conditionChanges`에 `goal_amount`가 있을 때 ai-server가 덧붙이고(D-073 방식), 프론트 카드는 F-4 `changedKeys`에 `goalAmount`가 있으면 같은 키를 **정적으로** 보여 준다. 자리: `{currentGoal}`, `{changedGoal}`(display 문자열). 본문 방향: **"목표 금액이 {currentGoal}에서 {changedGoal}으로 바뀌어, 달성 여부는 각각 자기 목표 기준이에요."**
4. **`diff`에 목표 차이 키(`gapToGoalDelta` 등)를 두지 않는다**(C2-5 유지). 대신 프롬프트에 **"이전 값을 빼서 새 숫자를 만들지 않는다"를 목표 변경 비교용으로 한 번 더 못 박는다**(모델이 두 목표나 두 `gapToGoal`을 뺄 수 있으므로).
5. 각 시나리오의 `isAchieved`·`gapToGoal`은 **각자 자기 목표 기준**이고 이미 `<side>.<S>.gapToGoal`로 존재한다.
- 왜 이렇게 했는가: 목표선이 움직인 비교를 "좋아졌다"로 읽히게 하면 금융 조언으로서 사용자를 오해시킨다. 정보는 남기고 해석만 코드가 고정한다.

---

## CF12-9. ai-server의 "두 겹" 풀기 (확정)

internal-calc C3-2 아래 문장은 목표 금액 변경을 **두 겹으로 막는다**고 적는다: (1) 도구 스키마 4키 + 프롬프트 고정 문장, (2) Spring `FIELD_NOT_CHANGEABLE`. **둘 다 풀고, 대상을 목표 종류·기존 납입액으로 옮긴다.**

### CF12-9-1. 변경 지점

CF12-4-2의 q~ff 전체. v1은 프롬프트 `:21`·`:54`·`:75` 삭제만 적었는데 **필요하지만 충분하지 않다.**
**프롬프트 변경 범위(확정): `prompts.py:7-8, 18, 21-27, 30-31, 53-54, 70, 75` + 신규 규칙.** 한 군데라도 남으면 모델이 옛 고정 문장으로 답하는 회귀가 난다(예: `:23`이 남으면 "3,000만원 모았어요"에 "입력 수정에서…"로 답한다).

`drop_carried_conditions`(`agent.py:204-230`)와 `calc.py:_select_side`의 `status` 통과는 **반드시 같은 묶음**이다(CF12-4-2 s·t).

### CF12-9-2. 고정 문장 테스트는 **삭제하지 않고 대상을 바꿔 유지한다** (확정)

고정 문장은 D-056·CP-05의 약속(모델이 짓지 않음)이다. 그냥 지우면 **"대화로 못 바꾸는 요청도 `ANSWER`이고 `OUT_OF_SCOPE`가 아니다"는 보호가 같이 사라진다.**

| 테스트 | 처리 |
|---|---|
| `tests/test_agent_tools.py:22` `REMOVED_KEYS`, `:98` "4키뿐" | `goal_amount`·`held_assets`를 빼고 `existing_monthly_contribution`만 남긴 **6키 단언**으로 교체 |
| `tests/test_agent_tools.py:119-126`, `:130-141` (목표 금액 발화 → 전용 문구, `goal_amount` 도구 호출은 is_error) | **대상을 목표 종류 발화로 교체.** 새로 "목표 금액 발화는 `recalculate`를 부른다" 테스트 추가 |
| `tests/test_agent_tools.py:143-150` (프롬프트에 `GOAL_AMOUNT_COPY` 글자 그대로) | 재사용한 **새 전용 문구**(목표 종류·기존 납입액) 기준으로 |
| `tests/test_out_of_scope.py:119-125`("목표 금액이 없다"를 단언 → **뒤집힌다**), `:188-260` AC-4 | 대상 교체. **`:230`(ANSWER에 OUT_OF_SCOPE 치환이 번지지 않음)은 그대로 둔다** |
| `tests/test_copy.py:37, 100-102, 135, 208-221` | 문구 본문 하드코딩(`"목표 금액은 입력 수정에서 바꿀 수 있어요…"`)이 #18 문구 개정과 **같은 PR**에서 바뀌어야 한다 |
| `tests/test_calc_client.py:269` + `docs/api/examples/.../field-not-changeable-response.json` | fixture `field: goalAmount` → `goalType` 등 |
| **`tests/test_no_accumulate.py:337-372` 표 테스트** | **새 행 추가**: ① 목표·보유 발화가 history 있는 대화에서 **지워지지 않는다** ② 목표 금액 발화의 금액이 **월 저축액으로 오인되지 않는다** |

회귀 위험이 가장 큰 두 곳: `test_copy.py`의 문구 본문 단언(문구와 함께 안 바뀌면 CI 깨짐)과 `test_no_accumulate.py` 표(행을 안 더하면 **테스트가 통과한 채로 새 키가 조용히 지워진다**).

### CF12-9-3. 단위(만원 ↔ 원)와 역할 혼동 (확정 — v1의 예시를 정정)

**v1의 "'2,500만원'을 `2500`으로 보내면 통과한다"는 틀렸다.** `2500 < goalAmount min 10000`이라 `OUT_OF_RANGE`로 걸리고 `CLARIFY`(`min`·`max` 인용) 경로를 탄다. **실제로 통과하는 구멍은 아래다.**

| 발화 | 모델이 잘못 낸 값 | 서버 결과 |
|---|---|---|
| 목표 1억 | `10000`(만 단위 그대로) | **통과**, 목표 1만원 |
| 목표 1억 5천만원 | `15000` | **통과**, 목표 1.5만원 |
| 목표 2,500만원 | `250000000`(×10 과환산) | **통과**, 2.5억 |
| 목표 2,500만원 | `2500` | 걸림(`OUT_OF_RANGE`) |
| 보유 자산 3,000만원 | `3000` | **통과**(`min 0`) |
| 보유 자산 3,000만원 | `300000000` | **통과**(`max 1e10`) |

즉 구멍은 **(a) 목표가 1억 이상일 때 만 단위를 그대로 쓴 경우**(사회초년생 흔한 목표라 빈번) **(b) ×10·×100 과환산 (c) 보유 자산 전 구간(`min 0`)** 이다. 목표가 "약 1만원"으로 보이면 사용자가 알아챌 수 있지만, **보유 자산 3,000원은 "약 0만원"으로 보여 알아채기 어렵다.**

**확정 대응, 세 겹:**

| 겹 | 내용 | 비용 |
|---|---|---|
| (a) 프롬프트 | `## 숫자`에 두 줄. ① "만·억 단위는 원으로 바꿔 인자에 넣는다. 단위가 없거나 모호한 금액은 계산하지 말고 단위를 되묻는다(CLARIFY)." ② **역할 규칙**: "목표·모으려는 → 목표 금액, 이미·지금·모아둔·가진 → 보유 자산, 매달·월 → 월 저축액. 역할 단어가 없으면 되묻는다." | 매우 작음. 단 모델 준수는 보장이 아니다 |
| (b) **추출 후 결정적 대조** | 새 함수 `check_amount_units(text, changes)`를 `drop_carried_conditions` 옆에 둔다. 발화에서 **숫자 + 단위 토큰**(`N억`, `N천만원`, `N만원`, `N원`, 쉼표 금액, `1억 5천만원` 조합)을 정규식으로 파싱해 후보 집합을 만들고, 추출된 `goal_amount`·`held_assets`·`monthly_saving_amount`가 **후보에 없으면 Spring을 부르지 않고 `CLARIFY`로 끝낸다**(`turn.validation_failed`와 같은 모양). 발화에 숫자 토큰이 없으면(한글 수사 "이천오백만원") 검사를 건너뛴다 | 중간(정규식 + 표 테스트 ≈15행). **계산이 아니라 "모델이 낸 값이 발화와 일치하는지" 대조**라 FR-AI-02에 어긋나지 않는다(이미 `number_check.py`가 같은 성격) |
| (c) 확인 문장 + 카드 | 목표·보유 금액 display를 **카드와 답변에 그대로** 보여 준다. 적용은 D-022대로 버튼이므로 **카드가 두 번째 확인**이다. 바뀐 두 금액은 `changedKeys`로 강조 | 프론트 카드 변경은 어차피 필요 |

- **(b)는 `HELD_ASSETS`를 여는 전제 조건이다**(소비자). (b)가 3주 안에 서지 않으면 쟁점 X-B는 "목표 금액만"으로 간다.
- **하지 않는 것(확정, 양쪽 합의)**: **단위 자동 보정 금지**(`2500` → `25000000`으로 고쳐 주지 않는다). 금액을 코드가 추측하면 계산 결과가 사용자가 말한 것과 달라지고 PR-04(숫자 일치)를 정면으로 깬다. **범위 검증은 Spring 한 곳(D-033) 유지.** 서버 쪽 "목표가 너무 작다" 비정상 값 경고 규칙도 두지 않는다(새 규칙을 만드는 일, 3주 밖).
- **상대 표현은 절대값 되묻기(D-059)를 여섯 조건으로 넓힌다.** "목표를 조금 줄이면", "목표를 N만원 줄이면"은 `CLARIFY`.
- 비율(0~100)·기간(1~360)은 범위가 좁아 서버가 거의 항상 잡는다(새 위험 아님). **새 위험은 금액 세 개(목표·보유·월 저축액) 사이의 역할 혼동**이다: "3,000만원이요"는 세 필드 모두 문법적으로 맞고, "300만원 모으려면"이 월 저축액 300만원(범위 안)이 되면 **조용히 틀린다.** → (a)의 역할 규칙 + (b).
- `_PERIOD`(`agent.py:187`)가 "목표 10년 뒤 1억"에서 기한으로 잡히는 것은 현재 동작이며 문제없다.

### CF12-9-4. FR-AI-02 구멍 점검 (확정)

| # | 구멍 | 막는 방법 |
|---|---|---|
| 1 | 모델이 두 목표를 빼거나 두 `gapToGoal`을 뺀다 | `diff`에 목표 차이 키를 두지 않고(C2-5), **프롬프트로 금지**. 말하려면 양쪽 display만 인용. 상대 표현 → 절대값 되묻기 |
| 2 | 단위 환산 | CF12-9-3 (a)+(b)로 **대조**. 값을 코드가 고쳐 주지 않는다 |
| 3 | 보유 자산을 모델이 가공해 말한다("모은 3,000만원에서 납입분을 빼면…") | `chat.heldAssetsBasis`는 **코드가 붙인다** + 프롬프트에 "보유 자산 값을 가공하지 않는다" 한 줄 |
| 4 | 초과를 벗어난 카드에서 필요 월 저축액·초과 금액을 모델이 계산 | 기존 규칙(초과 금액 미언급, `requiredMonthlySaving` 미노출)이 유지되는지 **테스트로 고정** |
| 5 | `drop_carried_conditions`가 값을 **지운다**/월 저축액으로 오인한다 | CF12-4-2 s의 정규식 확장 + `test_no_accumulate.py` 새 행 |

소비자가 새로 필요로 하는 계산 값은 **없다**(양쪽 `goalAmount`/`heldAssets` 표시 문자열과 `status`로 충분).

---

## CF12-10. 저장·적용·DB (확정 — 스키마 변경 0)

| 점검 | 결과 |
|---|---|
| `plan_version` 컬럼 | `schema.sql:73` `goal_amount BIGINT NOT NULL`, `:76` `held_assets BIGINT NOT NULL DEFAULT 0`이 **이미 있다.** 제약 `ck_pv_goal_amount CHECK (goal_amount > 0)`·`ck_pv_amounts`도 있다 → **DB 스키마 변경 0** |
| `source` CHECK | `schema.sql:91`에 `'CHAT'`이 **이미 있다** → 대화 적용으로 목표 금액이 바뀐 버전도 정상 기록 |
| 적용 `PlanService.merge:202-216` | `firstNonNull(changes.goalAmount(), current.getGoalAmount())` **2줄**. 그 뒤 `inputValidator.validate(merged)`(`:138`)가 범위를 다시 검사 → **방어선 이미 있음**(D-033 유지) |
| 되돌리기 `PlanService.undo:159-179`·`copyVersion` | `plan_version` **전 컬럼 복사** → `goal_amount`·`held_assets`도 복원. **추가 작업 없음**(D-068) |
| 새 버전·낙관적 락 | `apply`는 INSERT + `replaceCurrent(… expectedRevision)` → 두 값이 바뀌어도 동일 |
| `calc_run` | `plan_version_id`와 데이터 버전만 남긴다(ADR-002). 조건 값은 `chat_message.condition_changes`에 → **스키마 변경 없음** |
| 초과 "캐시" | 없다. `CalcInput.hasExceededGoal()`로 매번 계산 → **적용 후 결과 화면이 자동으로 초과/정상 전환** |
| `STALE_COMPARISON` | 변화 없음(기준 버전 ≠ 현재면 거절이라 "다른 버전의 목표 위에 병합"이 없다) |
| `PLAN_CHANGED` | 변화 없음. 적용 성공 → `revision` 증가 → 모든 적용 버튼 비활성(D-069) → 초과가 되면 D-072 |
| 옛 메시지 호환 | 옛 `condition_changes`는 4키의 부분집합이라 영향 없다. `changedKeys`도 저장 키 그대로. 새 필드는 없는 것이 정상 |
| F-4 범위 검사 | F-4는 범위 검사를 하지 않는다(타입 변환만). ai-server는 Spring 422를 통과한 값만 저장(`agent.py:386-387`)하므로 범위 밖 값은 저장되지 않는다. 새 두 키도 같다 |
| F-4 `conditions` 행 | "고정 4키 순서"(C12b-6) → **6행**(목표·보유 추가). **프론트 행 레이블·순서 고정 목록과 목 JSON이 같이 바뀐다.** `changedKeys` 강조 방식은 그대로 |
| chat 리스너 변환 맵(#41) | **4키 고정 맵** → 6키(`goal_amount → goalAmount`, `held_assets → heldAssets`). **모르는 키가 올 때의 동작이 계약에 없다** → **쟁점 X-E** |
| 모듈 경계 | 새 타입 없음. `calc → plan` 단방향 유지, `plan`은 `calc`를 참조하지 않는다 → **`ModularityTests` 통과 예상, 순환 없음.** 단 `calc` 공개 타입(`CalcComparison`, display 키)이 바뀌므로 `calc/package-info.java` 공개 API 설명 한 줄 갱신 |
| ADR-002·인증 | 충돌 없음. `/internal/**`는 공유 비밀 헤더 그대로. JWT 영향 없음 |
| 오류 코드 | **새 오류 코드를 만들지 않는다**(기존 `FIELD_NOT_CHANGEABLE`/`VALIDATION_FAILED`/`ALREADY_EXCEEDED`). 단 쟁점 X-A가 3-1이면 `ALREADY_EXCEEDED`가 "409 오류"와 "200 성공 안의 status" 양쪽에 존재하게 되어 오류 코드 체계의 일관성이 **처음으로 흐려진다** |

---

## CF12-11. 배포 순서 (확정, 양쪽 합의)

> **Spring(CF12-4-1 전체: yml·`ConditionOverride`·컨트롤러 Set·`validate`·`ConditionResolver`·`merge`·`PlanContextProviderImpl`·`ConditionValues`·display) → ai-server(6키 스키마·도구·프롬프트·`drop_carried_conditions`·`status` 통과) → 프론트(카드·행·문구·목 JSON)**

- **역순이면 F-4 비교 조회가 전부 500이 된다.** ai-server가 6키를 저장하기 시작했는데 `PlanContextProviderImpl.CHANGEABLE_KEYS`(`:47-53`)가 4키면 허용 밖 키에 `IllegalArgumentException`(`:170-172`) → C12b-6이 말하는 "F-4가 500"이 바로 이 경로다.
- ai-server를 **마지막에** 켜면 중간 상태가 모두 fail-closed다(`/internal/calc`가 `FIELD_NOT_CHANGEABLE` 고정 문장으로 안전하게 거절).
- **`PlanService.merge`·`toOverride` 배선 없이 ai-server를 켜지 않는다**(소비자 수용 조건 9).
- 제공자 조건 3(양보 불가) = 소비자 수용 조건 9. 왜 이렇게 했는가: 어느 중간 배포 상태에서도 "조용한 불일치"가 아니라 "명시적 거절"이 되게 한다.

### CF12-11-1. 선행: moeun **#132** (확정, 제공자 양보 불가)

> **#132 `[calc] 대화 조건 변환 코드를 한 곳으로 모으기`(OPEN, in-progress)를 이번 변경의 선행으로 못 박는다.**

- #132가 `InternalCalcController.CHANGEABLE_KEYS`(e)·`PlanContextProviderImpl.CHANGEABLE_KEYS`(i)·chat 리스너 변환 맵(gg)의 **중복 3곳을 `calc.application.ConditionChanges` 한 곳으로 모으는 중**이다.
- #132 머지 **전에** 6키로 넓히면 중복 3곳을 각각 고치고 #132가 그걸 또 합치게 되어 **충돌**이 난다.
- #132를 먼저 머지하면 이번 변경의 e·i·gg가 **한 파일 한 곳**으로 줄어든다(제공자 추정 ≈0.3일 절감).

---

## CF12-12. 계약 문서별 "바꿀 줄" 표

### CF12-12-1. `docs/design/contracts/internal-calc.md`

| 줄 | 절 ID | 현재 | 바꿀 내용 |
|---|---|---|---|
| 65 | C2-2 | "`conditionChanges` 허용 키 (D-040, CP-07 — **4개뿐**)" + 4행 표 | "허용 키 (새 D-번호, CP-07 — **6개**)" + `goalAmount`·`heldAssets` 2행(KRW, scale 0, min/max는 `fields` 그대로) |
| 74 | C2-2 | "…`goalAmount`가 조용히 버려지고" | 예시 키를 **여전히 허용 밖인 키**(`goalType`, `existingMonthlyContribution`)로 교체. 이유 문장은 유지 |
| 83 | C2-2 검사 3 | "허용 4개 밖의 키(`goalAmount`, `heldAssets`, `existingMonthlyContribution`, 오타 키 등)" | "허용 **6개** 밖의 키(`goalType`, `goalCustomName`, `existingMonthlyContribution`, 오타 키 등)" |
| 88 | C2-2 검사 8 | "현재 계획이 이미 목표 초과 → `409 ALREADY_EXCEEDED`(`current`도 계산하지 않음)" | **쟁점 X-A 결과 반영** |
| 101 | C2-3 | "대화로 바꿀 수 있는 **4개** 조건… 4개 키가 항상 모두 있다" | "**6개** 조건… 6개 키가 항상 모두 있다". **코드 사실 메모 추가**: 이 문장의 실체는 `CalcComparison.ConditionValues`(`:29-45`) 4필드 레코드이므로 **공개 레코드에 2필드 추가 + REST Docs 스냅샷 변경**이다 |
| 115·132 | C2-4 | "`status`는 성공 응답에서 항상 `CALCULATED`… D-040 때문에 `changed`도 `CALCULATED`" | **전면 개정(확정, CF12-8-0).** `current`·`changed` **각각 `status`** 를 담고, `ALREADY_EXCEEDED`면 그 쪽 `scenarios: []` |
| 139~158 | C2-5 `diff` | 항상 `byScenario` 채움 | 한쪽이 `ALREADY_EXCEEDED`면 `byScenario: []`. `comparable` 플래그는 두지 않는다. 목표 차이 키도 두지 않는다 |
| 159~192 | C2-6 `display` | 키 표, "비교에서는 `heldAssets`·`calcStartMonth`·`assumptions`를 만들지 않는다" | ① **쪽별 목표 금액 키**(`conditions.current.goalAmount`/`conditions.changed.goalAmount`, `conditionChanges`에 있을 때만) ② 초과인 쪽에도 `*.goalAmount`·`*.heldAssets` ③ `HELD_ASSETS`를 열면 비교 display에 **`calcStartMonth` 추가**(`isSingleResult` 분기 해제) ④ 무접두어 `goalAmount`는 단일 계산 경로 전용임을 명시 |
| 248 | C3-2 | 409 `ALREADY_EXCEEDED` 행 | 쟁점 X-A 결과 반영 |
| 253 | C3-2 아래 | "목표 금액 변경은 두 겹으로 막는다 …" | **대상 교체**: "목표 **종류**·기존 납입액은 두 겹으로 막는다" |
| 254 | C3-2 아래 | "`ALREADY_EXCEEDED`를 409로 둔 이유: 대화로 목표·보유를 못 바꾸므로 `changed`도 반드시 초과라…" | **근거가 사라진다.** 쟁점 X-A 결과로 재작성 |
| 259 | C3-3 | "대화 경로 허용 키는 `rules.yml › change-paths.CHAT.fields`(4개)" | (6개) + **메모: `InternalCalcController.CHANGEABLE_KEYS`는 yml을 읽지 않는다**(CF12-4-1 e) |
| 576~596 | 부록 A-4 | `422 FIELD_NOT_CHANGEABLE` 예시가 `goalAmount` | **예시 키 교체 필수.** 더불어 **`backend/src/test/resources/contract/internal-calc/a4-response.json`의 `field: "goalAmount"`** 도 교체(변경 범위에 명시) |
| 597~618 | 부록 A-5 | 409 `ALREADY_EXCEEDED` 예시 | 쟁점 X-A가 3-1이면 "초과 + 목표 상향" **성공 fixture 신설** |

### CF12-12-2. `docs/design/contracts/frontend-api-chat.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 219·221 | C12b-6 | "허용 밖 키가 저장된 메시지는 F-4가 500" 유지(대상이 6키 밖으로 좁아짐). "허용 4키"류 표현 정정. **F-4 `conditions` 6행**과 **각 칸 `status`** 추가 |
| 292 | C12b-7-1 검사 6 | 유지. **메모 추가**: `validate(ConditionOverride)`가 4필드 레코드라 2필드 추가 필요(CF12-4-1 c·d) |
| 307~319 | C12b-7-2 | `FIELD_NOT_CHANGEABLE` 프론트 동작 유지 |
| 380·386 | C12b-9 | 422 표 유지 |
| 650·657 | C12b-12 | 목 `post-apply.422-field-not-changeable.json`의 `errors[].field = "goalAmount"` → 교체. `frontend/src/mocks/chat/` 실제 파일도 |
| 685·697 | C12b-14 | "chat 리스너(#41)가 camelCase로 바꿔 저장(**4키 고정 맵**)" → **6키**. **쟁점 X-E(모르는 키 동작)를 결정 후 명시** |
| 698 | C12b-14 | "`ConditionChanges`가 지금 7키라 D-040의 4키와 다르다. #21을 선행" → **"이미 4키로 축소됨(#21 완료)"으로 정정**하고 "#21을 6키로 재확장"을 후속으로 |
| 742·762 | C12b-18 | H-3b·H-14 후속 작업을 6키 기준으로 재확인 |

### CF12-12-3. `docs/design/contracts/plan-context.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 14 | 머리말 | "**D-071**: 초과 계획의 대화 재계산은 `ALREADY_EXCEEDED` 고정 문장, 비교·적용 없음" → 쟁점 X-A 결과로 **부분 대체**("목표·보유를 바꾸지 않는 변경 또는 바꿔도 여전히 초과면 고정 문장") |
| 233 | C1a-9 검사 4 | `mode=EXPLAIN` + `ALREADY_EXCEEDED` → LLM 없이 `chat.alreadyExceeded`. **유지**(EXPLAIN은 범위 밖) |
| 246·247 | C1a-8 요구 키 | 유지 |
| 282 | C1a-10 규칙 7 | "D-059 대화로 바꿀 수 있는 **네 조건**" → "**여섯 조건**" |
| 284 | C1a-10 규칙 9 | "초과면 초과 사실과 '목표 금액은 입력 수정에서 바꿀 수 있어요'만 말한다" → **"대화로 목표 금액을 바꿔 볼 수 있어요"**(막다른 길 제거의 핵심 한 줄). 더해서 **한쪽이 초과인 비교에서는 그쪽은 `result.alreadyExceeded` 문장만 인용하고 비교 문장을 만들지 않는다**를 추가 |
| 289·413 | G-3 / D-10 | "`SYSTEM_PROMPT`를 D-040 4개 조건으로 고치는 일은 #21 범위" → 6개 조건 |
| 348 | C1a-11 | "초과 계획에서도 `conditions.heldAssets` display를 남긴다" 유지(더 필요해진다) |
| 354 | C1a-12 문구표 | `chat.alreadyExceeded` 본문 개정(#18). **쟁점 X-A가 3-1이면 "그 값으로도 이미 넘었어요"처럼 읽혀야 한다**(목표를 올렸는데 여전히 초과인 경우가 생긴다) |

### CF12-12-4. `docs/design/contracts/frontend-api-plan.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 303~ | C12a-5-5 | 범위 수치 표 **수치 변경 없음.** "이 두 행이 이제 대화·비교 경로에도 쓰인다" 한 줄 |
| 524 | C12a-7 | 초과 안내 `result.alreadyExceeded` 안의 목표 수정 안내 대상을 **대화**로(문구 본문 개정 #18). `frontend/src/shared/copy/copy.ts:30`·`features/chat/copy.ts:5` 복제본 동기 |
| 527 | C12a-7 | `input.heldAssetsRecheck`(D-035) 유지 + **D-035 안내가 대화 경로에도 필요**해진다는 참조(CF12-7-2) |
| 613~618 | C12a-9 | P-6 `POST /api/plan/apply` 요청 모양 확정 때 **6키 기준**이라는 한 줄 |
| 633 | C12a-10 | 422 `FIELD_NOT_CHANGEABLE`(P-6) 유지(대상만 좁아짐) |

### CF12-12-5. `docs/design/b-team-contracts.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 93 | C-2 | "필드는 **4개로 줄임** — D-040" → "**필드 6개**(새 D-번호, D-040 대체)" |
| **101** | C-2 | 허용 키 목록에 **`goalAmount`, `heldAssets` 추가(6키)** |
| **141** | C-3 | "422 `FIELD_NOT_CHANGEABLE` \| 대화로 못 바꾸는 조건(**목표 금액 등**) \| `OUT_OF_SCOPE` 또는 '입력 수정에서 바꿀 수 있어요'(D-040)" → "대화로 못 바꾸는 조건(**목표 종류·기존 납입액 등**) \| `ANSWER` + `chat.unchangeableCondition`(D-056)". *이 줄은 D-056 이전 서술이라 이미 낡았다* |
| 143 | C-3 | 409 `ALREADY_EXCEEDED` "계산 없이 안내" → 쟁점 X-A 결과 |

### CF12-12-6. `docs/design/alignment.md`

| 줄 | 바꿀 내용 |
|---|---|
| 26 | 불일치 2번("D-040은 4개, moeun은 7개 → moeun 맞춤")을 **해소 이력**으로 정리 + 새 결정(6개)으로 갱신 |
| 58 | 같은 내용 상세 행을 6개 기준으로 다시 씀 |

### CF12-12-7. `../moeun` 사본 — **이 repo에서 고치지 않는다** (목록만)

해당 moeun Issue 작업에서 함께 고친다. 내용은 CF12-12-1~4와 같다.

| 파일 | 고칠 절 |
|---|---|
| `moeun/docs/api/internal-calc.md` | C2-2(허용 키·검사 3), C2-3, C2-4, C2-5, C2-6, C3-2(두 겹 문단·409), C3-3, 부록 A-4·A-5 |
| `moeun/docs/api/frontend-api-chat.md` | C12b-6(6행·`status`), C12b-7-1, C12b-12, C12b-14(6키 맵·모르는 키) |
| `moeun/docs/api/plan-context.md` | C1a-9, C1a-10(규칙 7·9), C1a-12 |
| `moeun/docs/api/frontend-api-plan.md` | C12a-5-5, C12a-7, C12a-9 |
| `moeun/ai-server/README.md` | `recalculate` 도구 설명(4키 → 6키), 프롬프트 범위 안내 |
| `moeun/docs/api/examples/.../field-not-changeable-response.json` | `field` 값 |
| `moeun/backend/src/test/resources/contract/internal-calc/a4-response.json` | `field: "goalAmount"` → 교체 |
| `moeun/frontend/src/mocks/chat/post-apply.422-field-not-changeable.json` | `errors[].field` |
| `moeun/frontend/src/mocks/README.md` | 목 개수·설명 |

---

## CF12-13. 문구표(#18) 신규·개정 키 목록 (확정)

### 신규 5

| 키 | 용도 | 자리 | 붙이는 주체 |
|---|---|---|---|
| `condition.goalAmount` | 조건 이름(F-4 행 레이블, 범위 밖 안내 열거) | — | 코드(`copy.py:93` `_CONDITION_CODES`) |
| `condition.heldAssets` | 같음 | — | 같음 |
| `chat.goalAmountChangedNote` | 목표가 바뀐 비교의 주의 문구 | `{currentGoal}`, `{changedGoal}` | ai-server 덧붙이기 + 프론트 카드 정적 표시 |
| `chat.heldAssetsBasis` | 보유 자산 시작월 기준 안내 | `{calcStartMonth}` | 같음. `check_numbers` **뒤** |
| `chat.changedAlreadyExceeded` | "이 조건으로 적용하면 이미 목표를 넘은 상태가 돼요"(이름은 #18에서) | `{goalAmount}` 등 | 프론트 카드 정적 표시 |

### 개정 3

| 키 | 개정 내용 |
|---|---|
| `chat.unchangeableCondition` | "입력 수정에서 바꿀 수 있어요"를 빼고 **"여기서는 바꿀 수 없어요"로 끝낸다.** 대상은 목표 종류·기존 납입액·오타 키 |
| `chat.alreadyExceeded` | "목표 금액은 입력 수정에서…" → **"대화로 목표 금액을 바꿔 볼 수 있어요."** 쟁점 X-A가 3-1이면 **"그 값으로도 이미 넘었어요"** 로도 읽힐 수 있어야 한다. `ChatWindow` 고정 문장(D-063)이 사용자를 대화로 끌어오는 **선행 조건**이다 |
| `result.alreadyExceeded` | 안내 대상을 입력 수정 → **대화**로 |

- **동기화 대상**: `CopyBook.java`(키 목록), `ai-server tests/test_copy.py`(본문 하드코딩), 프론트 `shared/copy/copy.ts:30`·`features/chat/copy.ts:5`(복제본). **문구 본문과 테스트는 같은 PR에서 바꾼다.**
- `GOAL_AMOUNT_COPY`(`prompts.py:7-8`) 상수는 **삭제하지 않고** 목표 종류·기존 납입액 전용 문구로 **재사용**한다.

---

## CF12-14. SRS 영향 행

| ID | 줄 | 바꿀 내용 | 상태 영향 |
|---|---|---|---|
| **CP-07** | 26 | "대화·비교로 바꿀 수 있는 조건은 **6개**(월 저축액·비중·적금 금리·기한 + 목표 금액 + 보유 자산). 목표 종류·기존 납입액은 대화로 바꾸지 않는다. 한 번에 바꾸는 개수 상한은 경로별 `rules.yml`(CHAT·COMPARE는 6)" | **확정 → 확정(개정)**. 출처에 새 D-번호, D-040은 대체 표기 |
| **FR-AI-06** | 141~ | 예외 수용 기준의 **대상을 목표 종류·기존 납입액으로 교체**. 목표 금액(·보유 자산)은 정상 인식 시나리오로 이동. **단위·역할 혼동 수용 기준 추가**(CF12-9-3 (a)(b)). `drop_carried_conditions`가 새 키를 지우지 않는다는 수용 기준 추가. D-059 "네 조건"→"여섯 조건". 보유 자산 변경 시 시작월 기준 안내(X-B 채택 시) | 수용 기준 다수 수정 |
| **FR-CMP-02** | 45, 241~ | "**6개 중 하나 이상**". 목표 금액이 바뀐 비교의 표시 규칙(CF12-8-3)과 `changed` 초과(CF12-8-2) 수용 기준 추가. 양쪽 `status`로 칸을 고른다 | 부분확정 유지 |
| **FR-RES-01** | 183~ | 초과 안내를 **대화로** 돌린다. 쟁점 X-A가 3-1이면 "초과 계획에서 대화로 목표 금액을 올려 초과를 벗어난다" 수용 기준 추가 | 수용 기준 추가·수정 |
| **FR-AI-01** | — | 쟁점 X-A 결과로 재작성(D-071 **부분 대체**) | D-071 부분 대체 |
| **FR-INP-03** | — | 목표 금액: "대화로도 바꿀 수 있다" 참조 한 줄. 범위 수치 그대로 | 비고만 |
| **FR-INP-05** | — | 보유 자산: "대화로 바꿀 때도 같은 기준 안내"(X-B 채택 시). D-035 범위 확장 | 수용 기준 추가 |
| **FR-INP-11** | — | 변경 없음. '입력 수정' 버튼 제거가 결정되면 이 행의 운명을 따로 묻는다(범위 밖) | — |
| FR-PLAN-03·04 | — | 적용·되돌리기: 적용이 6필드를 병합(`PlanService.merge`) — 수용 기준에 2필드 추가. 되돌리기는 전 컬럼 복사라 추가 없음 | 수용 기준 보강 |
| FR-ALT-02 | — | **변경 없음**(`ALTERNATIVE` 3필드·max 1 유지) | — |

---

## CF12-15. 후속 작업 표 (제공자 `gh` 대조 결과로 정정)

`gh issue list -R shinhan-career-next-team-4/moeun --limit 200 --state all` 기준. **CLOSED 표시는 reopen 정책(쟁점 X-D)이 필요하다는 뜻이다.**

| T | 작업 | 담당 | Issue (대조 후) | 상태 | 선행 |
|---|---|---|---|---|---|
| T-1 | `rules.yml` CHAT·COMPARE 허용 6필드 + `max-fields: 6` | A | **#17** `[plan] ConditionValidator와 rules.yml` | **CLOSED**(status:review) | 결정 확정, #132 |
| T-2 | `ConditionOverride` 2필드 + `ConditionValidator.changedFields` + 테스트 fixture 4파일 컴파일 수선 | A | **#17**(ConditionOverride·ConditionValidator 소관) — 또는 T-3·T-6과 함께 **신규 1건** | **CLOSED** | T-1 |
| T-3 | `ConditionResolver`에 `goalAmount`·`heldAssets` override 배선 + "override가 결과를 바꾼다" 단위 테스트 | A | **#10 아님**(#10은 계약 Issue). 코드는 **#25**(CLOSED, 시작월 고정 ConditionResolver) / **#32**(CLOSED, `POST /internal/calc`) 범위. **제공자 권고: T-2·T-3·T-6을 신규 1건 `[calc] 대화 조건 6필드 배선`으로 묶기** | #25·#32 **CLOSED** | T-2 |
| T-4 | `PlanService.merge` 2필드 배선(적용 경로) + 적용 테스트 | A | **#33** `[plan] 적용·되돌리기 서비스`(정확히 맞다. #68은 OPEN이지만 확인창·취소라 다른 범위) | **CLOSED** | T-2 |
| T-5 | `PlanContextProviderImpl` `CHANGEABLE_KEYS`·`toOverride` 6키 | A | **#132**에 합침(원래 후보 #78은 CLOSED, 그리고 #132가 바로 이 중복을 없애는 중) | **#132 OPEN**(in-progress) | — (T-5가 #132) |
| T-6 | `CompareConditionsUseCase` 초과 분기 + `current`/`changed` `status` 응답, `diff` 비움, display 쪽별 분리 | A | 코드는 #32(CLOSED). **쟁점 X-A가 3-1이면 신규 Issue 필수**(계약 불변식 변경이라 단독 추적). 3-2면 초과 분기는 거의 사라지지만 **CF12-8-0(C2-4 개정·`status`)은 남는다** | #32 **CLOSED** | X-A 결정 |
| T-7 | internal-calc 계약·fixture 개정(A-4 키 교체, `a4-response.json`, X-A가 3-1이면 A-5 성공 fixture 신설, REST Docs 스냅샷) | A | **#10** `[contract] /internal/calc 응답·검증 오류 형식 확정`(계약 Issue로 정확) | **CLOSED** | T-6 |
| T-8 | ai-server 도구 스키마·`ConditionChanges` 6키 + **`drop_carried_conditions` 확장**(`_GOAL`·`_HELD` 정규식, `_MONTHLY` 오인 방지) + **`calc.py` `status` 통과** | B | **#21** `[ai] 대화 조건 4개로 축소 — M-2`(되살림이므로 이력이 한 곳에 남는 reopen이 정직) | **CLOSED** | Spring 배포 완료(CF12-11) |
| T-9 | 프롬프트 개정(`:7-8,18,21-27,30-31,53-54,70,75`) + 단위·역할 규칙 + **`check_amount_units`**(X-B에서 HELD를 열면 필수) + fake 모델 테스트 + 고정 문장 테스트 대상 교체(`test_no_accumulate.py:337-372` 새 행 포함) | B | **#21**, 단위 변환·되묻기 테스트는 **#23** `[ai] 계산 응답 소비와 되묻기` | 둘 다 **CLOSED** | T-8 |
| T-10 | 문구표 신규 5 · 개정 3(CF12-13) + `CopyBook.java` 키 목록 + 프론트 `copy.ts` 2곳 동기 | 공통 | **#18** `[docs] 문구표 copy.ko.yml` | **CLOSED** | X-A·X-B 결정 |
| T-11 | chat 리스너 camelCase 변환 맵 6키 + **모르는 키 동작**(쟁점 X-E) 테스트 | A | **#132**에 합침(원래 후보 #41은 CLOSED이고, 이 변환도 #132 공통 변환기로 흡수) | **#132 OPEN** | — |
| T-12 | 프론트: 비교 카드(한쪽 초과 비대칭, 양쪽 목표 금액, `conditions` 6행, 주의 문구, `status` 타입), 목 JSON 갱신 | B | **#53** `[front] 대화창 비교 결과 카드와 '내 계획으로 적용' 버튼` (v1의 #54는 **틀렸다** — #54는 `[front] AI 설명 비동기 표시`) | **#53 OPEN**(in-progress) | T-6, T-7 |
| T-13 | '입력 수정' 버튼 제거 (**이번 범위 밖**) | B | **#51** `[front] 입력 수정 복귀…` | **CLOSED** | T-1~T-12 + 별도 결정. **소비자 조건: `HELD_ASSETS`까지 끝난 뒤에만** |

**v1 → v2 정정**: T-3(#10 → #32/신규), T-12(#54 → **#53**), T-5·T-11(→ **#132**로 합침). **#10·#17·#18·#21·#25·#32·#33·#41·#51·#78이 모두 CLOSED** → 쟁점 X-D.

---

## CF12-16. 작업량 추정

### Spring (A팀, 백엔드 1명)

| 구성 | 일수 |
|---|---|
| #132 선행(이미 in-progress) | 기존 작업 |
| `rules.yml` + `ConditionOverride` 2필드 + `changedFields` | 0.3 |
| `InternalCalcController`(e·f) — #132 후면 `ConditionChanges` 한 곳 | 0.3 (#132 없으면 0.6) |
| `PlanContextProviderImpl`(i·j) | 0.2 (#132에 흡수 가능) |
| `ConditionResolver` override 배선 + 단위 테스트 | 0.3 |
| `PlanService.merge` 2줄 + 적용 테스트 | 0.3 |
| `CalcComparison.ConditionValues` 2필드 + REST Docs 스냅샷 | 0.5 |
| display 키 쪽별 분리 + 비교 `heldAssets`/`calcStartMonth` + `ResultDisplayBuilderTest` | 0.7 |
| **C2-4 개정에 따른 `ALREADY_EXCEEDED` 성공응답 처리**(CF12-8-0·8-2) | 0.5 |
| 테스트 fixture 컴파일 수선(4파일 20여 곳) | 0.5 |
| 계약 문서·`moeun/docs/api` 사본 | 0.5 |
| **소계(X-A를 3-2로 할 때)** | **≈4.1일** |
| X-A를 3-1로 할 때 추가(Spring+계약+fixture만) | **+1.5일** |
| X-B에서 `HELD_ASSETS`까지(문구·display) | **+1.0일** |

### ai-server·chat·프론트 (B팀, 인일)

| 작업 | 추정 |
|---|---|
| 스키마·도구·`ConditionChanges` 6키 + 프롬프트 개정 + 기존 테스트 대상 교체 | 1.5 |
| `drop_carried_conditions` 확장 + 표 테스트 | 1 |
| `_select_side` `status` 통과 + 한쪽 초과 프롬프트·테스트 | 0.5 |
| 단위 대조 `check_amount_units` + 표 테스트 | 1 |
| `chat.goalAmountChangedNote`·`chat.heldAssetsBasis` 덧붙이기 + 테스트 | 0.5 |
| chat 리스너 6키 맵 + "모르는 키" 테스트 | 0.5 |
| 프론트: 카드 한쪽 초과 분기, 목표·보유 행, 주의 문구, 목 JSON | 1.5~2 |
| 문구표 개정·신규 + 프론트 `copy.ts` 동기 | 0.5 |
| **소계(B팀)** | **≈7~8인일** |

`GOAL_AMOUNT`만(X-B의 B안)으로 줄이면 B팀 **≈4.5인일**(HELD 단위 대조 일부·`heldAssetsBasis`·행 하나 제외), A팀 **≈3일**.

---

## 쟁점 (사람이 정한다. 에이전트가 대신 정하지 않는다)

---

## §X-A. 초과 계획에서 대화로 목표 금액을 올려 초과를 벗어나는 경로 — **양쪽 정면 충돌**

### 상황

`CompareConditionsUseCase:88-92`는 `current.input().hasExceededGoal()`이면 `current`도 계산하지 않고 `409 ALREADY_EXCEEDED`를 던진다. 코드 주석의 전제("대화로 목표·보유를 바꿀 수 없어 changed도 초과다")가 이번 변경으로 깨진다. **"초과 계획에서 목표를 올려 되살린다"는 이번 변경의 주 사용 사례**인데, 지금은 막혀 있다.

### 양쪽 의견

- **제공자(A팀)**: **3-2 권고.** 비용(+1.5일)이 아니라 **회귀 범위**가 이유다. 3-1은 *모든* 비교 응답의 불변식(C2-4)을 바꾸므로 초과와 무관한 정상 경로의 프론트·ai-server·목 fixture까지 전수 재검증해야 한다. 또 `ALREADY_EXCEEDED`가 **"409 오류"와 "200 성공 안의 status"** 양쪽에 생겨 오류 코드 체계의 일관성이 처음으로 흐려지고, `agent.py:143`(`"ALREADY_EXCEEDED" → chat.alreadyExceeded` 매핑)·`:424`·`:441`의 오류 경로 기준 분기와 프론트 `settledStatus`가 갈린다. 3-1을 하려면 **데모 이후 과제로 분리** 요청.
- **소비자(B팀)**: **3-1 수용, 3-2 거절.** 3-2는 ai-server가 `RECALC_RESULT`를 내려면 `calc_run_id`가 있어야 하고(`agent.py:546-561` `assemble`, DB CHECK `ck_cm_recalc`), 계산 없는 "확인 → 적용"은 `ANSWER`로는 `condition_changes`를 저장할 수 없다(F-5는 `RECALC_RESULT` 메시지에만 적용, 검사 3·6·7). 즉 **새 메시지 타입 + CHECK 개정**이 필요하고 **D-041("적용 버튼은 가장 최근 비교 결과에만")과 맞지 않는다.** v1이 "싸다"고 한 것은 Spring 쪽뿐이고 B팀에는 더 비싸다. 또 프론트 카드(#53)가 **아직 없으므로** 한쪽 초과 카드를 처음부터 설계하는 지금이 가장 싸다(`ChatWindow.tsx`에 diff·changed 렌더링 없음).

### 선택지

| | **A) 3-1 — 초과를 벗어나는 변경이면 계산한다** | **B) 3-2 — 비교 없이 확인 → 적용** | **C) 1단계에서는 아무 것도 하지 않는다** |
|---|---|---|---|
| 규칙 | `current` 초과일 때 `conditionChanges`에 `goalAmount`/`heldAssets`가 **있고** 해석된 `changed`가 초과가 아니면 정상 비교. `current.status = ALREADY_EXCEEDED`·`current.scenarios: []`로 **응답에 담고** `diff.byScenario: []`. 카드는 "현재: 이미 넘었어요 / 바꾼 조건: 계산 결과"의 **비대칭 2칸**. 그 밖은 D-071 고정 문장 | 초과 계획에서는 비교를 만들지 않고 대화가 `ANSWER`로 "목표 금액을 2,500만원으로 바꿀까요?" 확인 → 적용 경로(F-5/P-6)만 태운다 | `ALREADY_EXCEEDED` 409 고정 문장 유지. 문구만 "대화로 목표 금액을 바꿔 볼 수 있어요"로 바꾸면 **가리킨 곳이 실제로 안 된다** → 문구도 못 고친다 |
| D-071 | **부분 대체**("바꾸지 않거나 바꿔도 여전히 초과면 고정 문장") | 유지(비교는 여전히 없음). 단 "적용 없음"은 깨지므로 **부분 개정** 필요 | 그대로 |
| C2-4 | 전면 개정(`current`도 `ALREADY_EXCEEDED` 가능) | 개정(`changed` 초과 — CF12-8-0은 **어느 쪽이든 필수**) | 개정(CF12-8-0은 여전히 필수) |
| DB·메시지 타입 | 변경 없음 | **`ck_cm_recalc` CHECK 개정 + 새 메시지 타입** 가능성(소비자 지적) | 변경 없음 |
| D-041 | 그대로(비교 결과가 있다) | **충돌**("적용 버튼은 가장 최근 비교 결과에만") | 그대로 |
| 일정 | A팀 +1.5일 / B팀 카드 분기 1 + `status` 통과 + 프롬프트 + 테스트 2(≈1일) | A팀 +0.2~0.5일 / **B팀 새 흐름·CHECK·메시지 타입 = 불확정, 1~2인일 이상** | 0 |
| 회귀 | **높음.** 모든 비교 응답의 불변식이 바뀌어 기존 통합 테스트·목 전수 재검토. `agent.py:143·424·441`, 프론트 `settledStatus` 분기 | **중간.** 초과라는 드문 상태 하나만 새 흐름. 성공 응답 모양은 한 글자도 안 바뀜. 단 새 메시지 타입은 저장·조회 전 경로에 번진다 | 낮음 |
| 제품 | 막다른 길이 **풀린다.** 숫자를 보고 적용을 결정할 수 있다 | 막다른 길은 풀리지만 **숫자 없이 적용**한다(사용자가 결과를 모르고 누른다) | **막다른 길이 그대로 남는다** → 이번 변경 목적의 절반을 못 이룬다 |

### 기획 추천: **A) 3-1**

이유 세 줄.
1. **B안은 "싸다"는 전제가 깨졌다.** 제공자가 3-2를 권한 근거는 Spring 비용인데, 소비자 쪽에서 **DB CHECK 개정 + 새 메시지 타입 + D-041 충돌**이 드러났다. 두 팀 합계로는 3-2가 3-1보다 싸지 않을 가능성이 높다.
2. **C2-4 개정(CF12-8-0)은 어느 선택지에서도 필수**다(`changed` 초과 때문에). 제공자가 3-2를 권한 가장 큰 이유인 "불변식을 안 깬다"가 **실제로는 성립하지 않는다.** 3-1의 추가분은 "`current` 쪽도 같은 모양을 가질 수 있다"뿐이다.
3. 금융 조언 관점에서 **숫자 없이 적용 버튼을 누르게 하는 흐름**은 D-022(적용은 사용자가 결정)의 취지와 어긋난다.
단, 제공자의 회귀 우려는 실체가 있으므로 **조건**을 붙인다: `status`는 소비자가 **문자열 해석 없이 그것만 보고 칸을 고르는** 필드로 정의하고, `diff`는 한쪽이 초과면 **반드시 비운다**(`comparable` 플래그 없음). 그리고 X-B를 "목표 금액만"으로 줄여 3-1의 회귀 전수 검증에 시간을 쓰는 편을 권한다.

---

## §X-B. 1단계 범위를 `GOAL_AMOUNT`만으로 줄일까 — **사용자 범위를 바꾸는 일**

### 상황

사용자는 범위를 "`GOAL_AMOUNT`와 `HELD_ASSETS` 둘"로 못 박았다. 그런데 **양쪽 검토가 모두 1단계는 목표 금액만**을 권고한다.

### 양쪽 의견

- **소비자**: 단위 구멍(CF12-9-3)에서 **보유 자산이 가장 위험하다.** `min 0`이라 전 구간이 통과하고, "3,000원"이 카드에 "약 0만원"으로 보여 **사용자가 알아채기 어렵다.** 추출 후 대조(`check_amount_units`)가 3주 안에 서지 않으면 `HELD_ASSETS`는 열지 말자. 막다른 길(FR-RES-01)은 목표 금액만으로 풀린다. 단 **'입력 수정' 버튼 제거의 선행 조건으로 `HELD_ASSETS`를 명시**해야 한다(D-035가 "입력 수정으로만"이라 버튼이 사라지면 보유 자산을 바꿀 곳이 없어진다).
- **제공자**: 2-2로 줄이면 ①`chat.heldAssetsBasis` 신설 ②비교 display `calcStartMonth` 추가 ③`conditions.heldAssets` 비교 노출 ④D-035 범위 확장이 전부 사라져 **≈1일 절감.** **이견 없음.**

### 선택지

| | **A) 둘 다 이번에**(사용자 원안) | **B) 목표 금액만, 보유 자산은 2단계** |
|---|---|---|
| 일정 | A팀 +1.0일, B팀 +2.5~3인일(`check_amount_units` 포함) | 기준선 |
| 위험 | 보유 자산 단위 사고가 **조용히** 틀린 계획을 만든다(`min 0`). `check_amount_units`가 없으면 막을 수단이 프롬프트뿐 | 목표 금액은 "약 1만원"처럼 **눈에 보이는 범위**라 (a)+(c)만으로 받을 수 있다 |
| 계약 | C2-6 개정(비교 display에 `heldAssets`·`calcStartMonth`), 문구 `chat.heldAssetsBasis`, D-035 확장 | 위 4건 전부 **불필요** |
| 제품 | "저축을 더 했어요"류 발화를 대화로 반영 가능 | 그 발화는 여전히 반영 못 함(`chat.unchangeableCondition`이 "여기서는 바꿀 수 없어요"로 끝난다 → **작은 막다른 길이 남는다**) |
| T-13(버튼 제거) | 바로 선행 충족 | **버튼 제거를 할 수 없다**(보유 자산을 바꿀 곳이 사라진다) → T-13이 2단계 뒤로 |

### 기획 추천: **B) 목표 금액만** — 단 **조건 두 개**

1. **2단계(`HELD_ASSETS`)를 같은 결정에서 "할 일"로 못 박고**, D-035 확장·`chat.heldAssetsBasis`·`check_amount_units`를 2단계 범위로 적는다. 1단계 설계는 CF12-7-2를 그대로 둔 채 **구현만 미룬다**(계약을 두 번 고치지 않게).
2. **T-13('입력 수정' 버튼 제거)의 선행을 "2단계 완료"로 적는다.** 이걸 빼면 1단계만 하고 버튼을 없애 보유 자산이 막다른 길이 된다.
이유: 두 검토가 독립적으로 같은 결론에 왔고(위험 쪽·비용 쪽 각각), X-A를 3-1로 하면 회귀 검증에 시간이 필요하다. 다만 **사용자 원안을 바꾸는 일이므로 사람이 정한다.**

---

## §X-C. COMPARE 경로를 함께 열까

### 양쪽 의견

- **제공자**: **같이 열자.** 추가 비용 **거의 0**. `ChangePath.COMPARE`는 코드에서 `PlanService.APPLY_PATHS`(`:51`)와 테스트에만 쓰이고, 비교 API(#64)는 아직 **OPEN(Should)** 이라 조회 경로가 없다. 즉 yml 1줄이고 지금 깨질 것이 없다. **적용 경로(`merge`)는 CHAT·COMPARE 공용**이므로 어느 쪽을 열어도 `merge` 수정은 필요하다. 나중에 두 번 안 고친다. 단 소비자가 CHAT만 원하면 수용.
- **소비자**: **미룬다.** FR-CMP-02가 Should이고 프론트 비교 영역이 아직 없으므로 CHAT만 열어도 제품 방향("대화로만 바꾼다")에 지장이 없다. Should를 되살릴 때 6필드로 함께 연다. `ConditionOverride`는 COMPARE도 같은 타입이라 Spring 비용은 거의 같다(A팀 판단).

### 선택지

| | **A) CHAT·COMPARE 둘 다**(사용자 원안) | **B) CHAT만, COMPARE는 FR-CMP-02 되살릴 때** |
|---|---|---|
| 비용 | yml 1줄 + `ConditionValidator.changedFields`(이미 T-2에 포함) ≈0 | 0 |
| 위험 | 조회 경로(#64)가 없어 **지금 깨질 것이 없다.** 다만 "열어 두었지만 쓰이지 않는 허용"이 생긴다 | 없음 |
| 나중 | 두 번 안 고친다 | FR-CMP-02를 되살릴 때 yml·계약·테스트를 다시 건드린다 |
| 계약 문서 | b-team-contracts C-2 등 한 번에 6키로 정리 | COMPARE 줄은 "4키 유지"로 남아 문서 안에 **두 가지 숫자가 공존**한다 |

### 기획 추천: **A) 둘 다** (사용자 원안 유지)

이유: 제공자가 "추가 비용 0, 지금 깨질 것 없음"을 코드로 확인했고, 소비자의 반대 근거는 "필요 없다"일 뿐 "위험하다"가 아니다. 문서 안에 숫자 두 개가 공존하는 비용이 yml 한 줄보다 크다. **다만 FR-CMP-02는 Should 그대로 두고, COMPARE는 "허용만 열어 둔다"로 명시**한다(이번에 프론트 비교 영역을 만들지 않는다).

---

## §X-D. moeun Issue reopen 정책 — D-058과 부딪힌다

### 상황

D-058은 "기존 Issue **본문**(수용 기준·변경 범위·선행)을 고치고, 같은 범위의 기존 Issue가 있으면 새 Issue를 만들지 않는다"고 정한다. 그런데 후속 작업 담당 Issue가 **거의 다 CLOSED**다.

| Issue | 제목 | 상태 | 담당 T |
|---|---|---|---|
| #10 | `[contract] /internal/calc 응답·검증 오류 형식 확정` | **CLOSED** | T-7 |
| #17 | `[plan] ConditionValidator와 rules.yml` | **CLOSED**(status:review) | T-1, T-2 |
| #18 | `[docs] 문구표 copy.ko.yml` | **CLOSED** | T-10 |
| #21 | `[ai] 대화 조건 4개로 축소 — M-2` | **CLOSED** | T-8, T-9 |
| #23 | `[ai] 계산 응답 소비와 되묻기` | **CLOSED** | T-9(일부) |
| #25 | `[calc] 시작월 고정 ConditionResolver` | **CLOSED** | T-3 |
| #32 | `[calc] POST /internal/calc` | **CLOSED** | T-3, T-6 |
| #33 | `[plan] 적용·되돌리기 서비스` | **CLOSED** | T-4 |
| #41 | `[chat] Spring chat 모듈 기반` | **CLOSED** | T-11(→#132) |
| #51 | `[front] 입력 수정 복귀…` | **CLOSED** | T-13 |
| #78 | `[calc] PlanContextProvider` | **CLOSED** | T-5(→#132) |
| **#132** | `[calc] 대화 조건 변환 코드를 한 곳으로 모으기` | **OPEN**(in-progress) | T-5, T-11, 선행 |
| **#53** | `[front] 대화창 비교 결과 카드와 '내 계획으로 적용' 버튼` | **OPEN**(in-progress) | T-12 |

### 선택지

| | **A) 해당 Issue를 reopen해 본문 수정** | **B) 신규 Issue로 묶기** | **C) 혼합** |
|---|---|---|---|
| D-058 | 글자대로 지킨다 | "맞는 Issue가 없을 때만 신규"를 넓게 해석(닫힌 Issue = 없는 Issue) | 성격별로 나눔 |
| 장점 | 이력이 한 곳에 남는다(특히 **#21은 자기가 한 축소를 되돌리는 일**이라 reopen이 가장 정직 — 제공자) | 보드가 "닫은 걸 또 여는" 혼란 없이 깔끔. **제공자 권고: T-2·T-3·T-6을 신규 1건 `[calc] 대화 조건 6필드 배선`으로 묶기**(원래 Issue 3개에 흩어져 있고 #132와도 겹친다) | 둘의 장점 |
| 단점 | 11건을 reopen하면 보드가 어수선하고, "완료"의 뜻이 흐려진다. status:review였던 #17 등의 상태 되돌림 | 이력이 끊긴다. "#21에서 4키로 줄였다 → 왜 6키인가"를 추적하려면 링크를 따라가야 한다 | 규칙이 하나 더 생긴다 |
| 신규 수 | 0(+X-A가 3-1이면 계약 불변식용 1건) | 3~4건 | 2~3건 |

### 기획 추천: **C) 혼합** — 아래 규칙

1. **되살림(이력이 핵심)인 것은 reopen**: **#21**(4키 축소를 6키로 되돌림), **#18**(문구표 — 본문 개정이 곧 이력), **#10**(계약 문서·fixture).
2. **여러 Issue에 흩어진 코드 배선은 신규 1건으로 묶는다**: `[calc] 대화 조건 6필드 배선`(T-2·T-3·T-4·T-6). 선행에 **#132**, 본문에 CF12-4-1 전체 목록과 fixture 컴파일 수선을 적는다. 참조로 #17·#25·#32·#33을 링크.
3. **이미 OPEN인 것은 본문 수정**: **#132**(T-5·T-11 흡수 + 선행 선언), **#53**(T-12).
4. **X-A가 3-1이면 계약 불변식 변경은 신규 1건으로 단독 추적**(`[calc] C2-4 불변식 개정 — current/changed status`). 회귀 범위가 넓어 따로 보는 편이 안전하다.
5. **#51(T-13)은 이번에 건드리지 않는다**(별도 결정).
이유: reopen을 3건으로 제한하면 보드 혼란이 작고, "왜 되돌렸나"가 중요한 곳에만 이력이 남는다. 그래도 **D-058의 해석을 바꾸는 일이므로 사람이 정한다.**

---

## §X-E. chat 리스너의 고정 맵이 **모르는 키**를 만났을 때 — 계약에 없다

### 상황

C12b-14는 "chat 리스너(#41)가 `condition_changes`를 camelCase로 바꿔 저장(**4키 고정 맵**)"이라고만 적고, **맵에 없는 키가 왔을 때의 동작을 정하지 않았다.**

- **소비자 지적**: 고정 맵이 모르는 키를 **조용히 버리면** 저장값에서 목표 금액이 사라져 **F-4·F-5가 AI 문장과 다른 계산을 한다.** FK 위반 같은 명시적 실패가 아니라 **조용한 불일치**다. 배포 순서가 어긋난 중간 상태(ai-server가 먼저 6키를 보내는 경우)에서 바로 일어난다.
- **소비자 요구**: **"모르는 키는 저장 실패(500/FAILED)"로 계약에 명시**하고 테스트 1개를 둔다.
- **제공자 의견 없음** — 저장 실패가 chat 모듈(A팀) 쪽 동작이고, `ChatMessage` 저장이 턴 응답과 같은 트랜잭션인지에 따라 "턴 전체 실패"가 될 수 있어 **제공자 확인이 필요하다.**

### 선택지

| | A) 모르는 키 → 저장 실패(소비자 요구) | B) 조용히 버린다(현상 추정) | C) 버리되 경고 로그 + 메트릭 |
|---|---|---|---|
| 결과 | fail-closed. 중간 배포 상태에서 **눈에 보이는 실패** | **조용한 불일치**(카드와 적용 결과가 다름) | 실패는 아니고 추적만 가능. 사용자는 여전히 틀린 카드를 본다 |
| 위험 | 턴 응답까지 실패할 수 있다(트랜잭션 범위에 따라) → 사용자는 답을 못 받는다 | 금융 수치 불일치 = PR-04 취지 위반 | B와 같음 |

**기획 추천: A), 단 "저장 실패의 범위"를 제공자에게 확인한 뒤 확정.** 조용한 불일치는 이 제품에서 가장 피해야 할 실패 모양이다. 다만 턴 응답 전체가 500이 되는지, 메시지 저장만 FAILED로 남는지는 트랜잭션 구조에 달렸다 → **재검토 질문 P-5.**

---

## 재검토에서 두 쪽에 물을 것

### 제공자(A팀 Spring·계산 엔진)용

| # | 질문 |
|---|---|
| **P-1** | **X-A 재고 요청.** 3-2를 권한 핵심 근거가 "성공 응답 불변식을 안 깬다"였는데, **CF12-8-0에서 확인했듯 `changed` 초과 때문에 C2-4 개정은 어느 선택지에서도 필수**다(제공자 조건 5와 동일). 그렇다면 3-1의 **추가분은 "`current` 쪽도 같은 모양을 가질 수 있다"뿐**이다. 이 전제에서 3-1의 추가 비용·회귀 범위를 다시 추정해 달라. 그리고 소비자가 든 3-2의 비용(`ck_cm_recalc` CHECK 개정, `RECALC_RESULT`에 `calc_run_id` 필수, 새 메시지 타입, D-041 충돌)을 보고도 3-2가 여전히 더 싼가? |
| **P-2** | **display 쪽별 키 이름.** 제공자는 `current.goalAmount`/`changed.goalAmount`를, 소비자는 C2-6의 기존 체계에 맞춘 `conditions.current.goalAmount`/`conditions.changed.goalAmount`를 제안했다. v2 본문은 후자를 권고로 적었다. `ResultDisplayBuilder`·`DISPLAY_KEY` 정규식 쪽에서 어느 이름이 더 싼가? 초과인 쪽에도 `*.goalAmount`·`*.heldAssets`를 내리는 것(CF12-8-2)이 `isSingleResult` 분기와 충돌하지 않는가? |
| **P-3** | **`check_amount_units`의 서버 쪽 대칭.** ai-server가 "모델이 낸 값이 발화와 일치하는지" 대조하기로 했다(CF12-9-3 b). Spring 쪽에 **중복 검증을 두지 않는다**(D-033 유지)는 해석이 맞는가? `goalAmount min 10000`·`heldAssets min 0`은 그대로 두고 비정상 값 경고 규칙은 만들지 않는다는 것에 동의하는가? |
| **P-4** | **X-B가 B안(목표 금액만)이 되면** `rules.yml` `max-fields`를 `5`로 두는가, 아니면 2단계를 내다보고 `6`으로 두는가? 전자는 2단계에서 다시 고치고, 후자는 "허용 5 < max 6"으로 CF12-6의 가드 논리가 약해진다. 제공자 선호는? |
| **P-5** | **X-E: chat 리스너가 모르는 키를 만났을 때.** 소비자는 "저장 실패(500/FAILED)" 명시를 요구한다. ① `ChatMessage` 저장이 턴 응답과 같은 트랜잭션인가(= 저장 실패가 턴 전체 실패가 되는가)? ② `#132`의 공통 변환기로 모은 뒤라면 "모르는 키 → 예외"가 자연스러운가? ③ 제공자 권고는 A/B/C 중 무엇인가? |
| **P-6** | **#132와의 머지 순서.** #132가 언제 머지되는가? 만약 #132가 이번 변경보다 늦어질 조짐이면, CF12-4-1 e·i·gg를 각각 고치고 #132가 나중에 합치는 쪽이 나은가(제공자는 충돌을 이유로 반대했다) — 대안 일정이 있는가? |
| **P-7** | **X-D 신규 Issue 묶기.** 기획 추천(C 혼합)대로 `[calc] 대화 조건 6필드 배선` 신규 1건에 T-2·T-3·T-4·T-6을 묶고 #21·#18·#10만 reopen하는 안이 A팀 작업 추적에 맞는가? |

### 소비자(B팀 ai-server·chat·프론트)용

| # | 질문 |
|---|---|
| **C-1** | **X-A 조건 확인.** v2는 `status`를 "소비자가 문자열 해석 없이 그것만 보고 칸을 고르는" 필드로 정의하고, 한쪽 초과면 `diff.byScenario: []`, `comparable` 플래그 없음으로 확정했다. 이걸로 비대칭 카드 구현에 **빠진 정보가 없는가**? 특히 초과 칸에 내릴 display 키 목록(`*.goalAmount`, `*.heldAssets` 외에 더 필요한 것)을 **빠짐없이** 적어 달라 |
| **C-2** | **display 쪽별 키 이름**(P-2와 같은 질문). `conditions.current.goalAmount` 체계로 가면 ai-server `DISPLAY_KEY` 정규식 개정과 프롬프트 인용 규칙(`prompts.py:30-31`)이 어떻게 되는가? |
| **C-3** | **X-B가 B안(목표 금액만)이 되는 데 동의하는가**(소비자 권고와 같다). 그렇다면 **2단계로 미루는 항목 목록**을 확정해 달라: `check_amount_units`의 `held_assets` 부분, `chat.heldAssetsBasis`, 카드 보유 자산 행, `drop_carried_conditions`의 `_HELD` 정규식 — 이 중 **1단계에 미리 넣어 두는 편이 싼 것**이 있는가(두 번 고치지 않게)? |
| **C-4** | **X-C(COMPARE 동시 개방)에 대한 기획 추천은 A(둘 다)** 다. 제공자가 "비용 0, 깨질 것 없음"을 확인했고 프론트 비교 영역은 이번에 만들지 않는다. 이 조건이면 수용 가능한가? 수용 못 할 구체적 위험이 있는가? |
| **C-5** | **`check_amount_units` 실현 가능성.** 1인일 추정이 3주 일정 안에 실제로 서는가? 한글 수사("이천오백만원")를 건너뛰는 설계에서 **놓치는 비율**을 어떻게 볼 것인가? 서지 않으면 X-B는 자동으로 B안이 된다 — 이 연결을 확인해 달라 |
| **C-6** | **X-E 저장 실패의 사용자 경험.** 모르는 키로 저장이 실패하면 사용자는 답을 못 받거나 "다시 시도해 주세요"를 본다. 프론트·ai-server가 이 실패를 어떤 문구로 처리하는가(새 문구 키가 필요한가)? 아니면 턴은 성공시키고 메시지만 FAILED로 두는 쪽이 나은가? |
| **C-7** | **문구표 확정.** CF12-13의 신규 5 · 개정 3이 소비자가 필요한 전부인가? `chat.changedAlreadyExceeded`의 최종 이름과 자리 값, `chat.alreadyExceeded`가 "그 값으로도 이미 넘었어요"와 "대화로 목표 금액을 바꿔 볼 수 있어요" **두 상황을 한 문장으로 감당할 수 있는가**(아니면 키를 나눠야 하는가)? |
| **C-8** | **T-12(#53) 일정.** #53이 in-progress인데, 비대칭 카드·6행·`status`를 **지금 설계에 넣으면** 나중에 넣는 것보다 실제로 싼가(소비자 주장)? #53의 현재 진행도에서 추가 비용은 얼마인가? |

---

## CF12-17. 결정 요약 (사람이 채울 칸)

| 쟁점 | 기획 추천 | 양쪽 의견 | 결정 | D-번호 |
|---|---|---|---|---|
| **X-A** 초과 계획의 목표 상향 | **A) 3-1** | 제공자 3-2 / 소비자 3-1(3-2 거절) — **충돌** | | |
| **X-B** 1단계 범위 | **B) 목표 금액만**(+2단계 못 박기, T-13 선행) | 양쪽 모두 목표 금액만 권고. 사용자 원안은 둘 다 | | |
| **X-C** COMPARE 동시 개방 | **A) 둘 다**(허용만 열어 둠) | 제공자 같이 열자 / 소비자 보류 | | |
| **X-D** Issue reopen 정책 | **C) 혼합**(reopen 3건 + 신규 1~2건 + OPEN 본문 수정) | 제공자: 신규 묶기 권고, reopen도 수용 | | |
| **X-E** 모르는 키 저장 동작 | **A) 저장 실패**(범위는 P-5 확인 후) | 소비자 요구 / **제공자 의견 없음** | | |

### 확정(합의) 항목 — 결정 없이 본문대로 간다

| # | 항목 | 근거 절 |
|---|---|---|
| 1 | `max-fields` = **6**(4·0 거절, `TOO_MANY_CHANGES` 문구·화면 만들지 않음) | CF12-6 |
| 2 | `rules.yml` `fields:` 블록 **불변**, `change-paths` 허용 목록만 확장 | CF12-5 |
| 3 | **빠진 구현 지점 4건 명시**: `InternalCalcController:39-42` Set·`:66-72` 검사 3·`:86-110` `validate`·`:99-100` `hasValidatableValue`, `PlanContextProviderImpl:47-53` Set, `CalcComparison:29-45` `ConditionValues` 2필드, `ResultDisplayBuilder` display 키 쪽별 분리 + `schemas.py:54-59` `DISPLAY_KEY` 개정 | CF12-4-1 e·f·i·k·l |
| 4 | **`drop_carried_conditions`(`agent.py:204-230`) 확장** + `_MONTHLY`(`:186`) 오인 방지 + `test_no_accumulate.py:337-372` 표에 행 추가 | CF12-4-2 s, CF12-9-2 |
| 5 | **`calc.py:_select_for_model`·`_select_side`가 `status`를 모델에 통과** | CF12-4-2 t, CF12-8-0 |
| 6 | **C2-4 불변식 개정 + `current`·`changed` 각각의 `status`**(X-A를 어떻게 정하든 필수) | CF12-8-0 |
| 7 | 한쪽 초과면 `scenarios: []`·`diff.byScenario: []`, **`comparable` 플래그 없음** | CF12-8-0·8-2 |
| 8 | `changed` 초과 시 **적용 버튼 활성** + 카드에 "적용하면 초과 상태" 한 줄 | CF12-8-2 |
| 9 | `achievementChange`를 **null로 숨기지 않는다**, 주의 문구는 코드가 붙인다 | CF12-8-3 |
| 10 | **배포 순서 Spring → ai-server → 프론트** | CF12-11 |
| 11 | **#132를 선행으로 못 박는다** | CF12-11-1 |
| 12 | **단위 자동 보정 금지**, 범위 검증은 **Spring 한 곳(D-033)**, 비정상 값 경고 규칙 없음 | CF12-9-3 |
| 13 | 단위 구멍의 **실제 사례 정정**(1억→`10000`, ×10·×100 과환산, 보유 자산 전 구간). v1의 "2500" 예시는 **틀렸다** | CF12-9-3 |
| 14 | **고정 문장 테스트는 삭제하지 않고 목표 종류·기존 납입액으로 대상 교체** | CF12-9-2 |
| 15 | `chat.heldAssetsBasis`는 **display 문구 키가 아니다.** Spring은 `calcStartMonth` display만 추가, 문장은 ai-server가 문구표에서 읽어 `check_numbers` 뒤에 덧붙인다. `held_assets`가 있을 때만, **답변 끝과 카드 양쪽.** 문장은 방향을 알려 준다 | CF12-7-2 |
| 16 | 계산 엔진에 **이중 계산 로직 없음**(`CalcEngine:159`, `ConditionResolver.createInput:92-99`, `calcStartMonth`는 항상 저장값). D-035 위험은 **발화의 의미**뿐 | CF12-7-1 |
| 17 | **DB 스키마 변경 0**(`schema.sql:73,76` 컬럼·CHECK, `source` CHECK에 `'CHAT'`), `PlanService.merge:202-216`은 `firstNonNull` 2줄, 되돌리기 추가 작업 없음 | CF12-10 |
| 18 | **테스트 fixture 컴파일 깨짐 명시**: `ConditionOverride` 생성자로 4파일 20여 곳 + 계약 fixture `contract/internal-calc/a4-response.json`(`field:"goalAmount"`) + REST Docs 스냅샷 + ai-server fixture | CF12-4-4 |
| 19 | **문구표 신규 5 · 개정 3** 목록 확정, `CopyBook.java`·프론트 `copy.ts` 2곳 동기 | CF12-13 |
| 20 | 후속 작업 Issue 대조 정정: T-3(#10→#32/신규), T-12(#54→**#53**), T-5·T-11→**#132** | CF12-15 |
| 21 | **빼는 것**: `comparable` 플래그, `achievementChange` null 숨김, Spring display의 문구 키, `max-fields` 4·0, 1단계 목표 종류·자동 보정 | 여러 절 |

---

## §Z. v1 → v2 변경 표

| Z | v1 | v2 | 근거 |
|---|---|---|---|
| **Z-1** | 쟁점 1(`max-fields`) — 선택지 3개, 추천 1-1 | **삭제(확정)**. `6`으로 확정해 CF12-5·CF12-6 본문에 반영. `TOO_MANY_CHANGES` 문구·화면은 만들지 않음을 명시 | 양쪽 수용. `4`는 양쪽 반대(`CopyBook.java:50` 목록 없음, 프론트 분기 0건, ai-server 매핑 없음) |
| **Z-2** | CF12-4 코드 현황표 **6곳(a~n)** | **13곳(a~jj, 네 절로 분할)**. 추가: `InternalCalcController:39-42` Set(e), `:86-110` `validate`·`hasValidatableValue`(f), `PlanContextProviderImpl:47-53` Set(i), `CalcComparison:29-45` `ConditionValues`(k), `ResultDisplayBuilder` 무접두어 `goalAmount`(l), `putConditions`의 `isSingleResult` 분기(m), `drop_carried_conditions`(s), `calc.py` `status` 미전달(t), `prompts.py:23-24`(x)·`:25-27`(y)·`:30-31`(z), `agent.py:424·441`(ee), chat 리스너·프론트(gg~jj) | 제공자 1절 ①②③④, 소비자 1-1절 |
| **Z-3** | "yml 2줄 변경이 아니다 — 6군데" | "**yml diff는 `/internal/calc`에 효과가 0이다**"를 CF12-5에 경고로 추가 | 제공자 조건 1(양보 불가) |
| **Z-4** | 없음 | **CF12-4-4 신설**: 테스트·fixture 깨짐(`ConditionOverride` 4파일 20여 곳, `contract/internal-calc/a4-response.json`, REST Docs 스냅샷, ai-server fixture) | 제공자 1절 "테스트 fixture"·"계약 fixture", 사용자 지시 |
| **Z-5** | 쟁점 2(`HELD_ASSETS`) — 선택지 4개(2-1~2-4) | **설계는 CF12-7-2로 확정**(문장은 ai-server가 문구표에서 붙임, Spring은 `calcStartMonth` display만, 조건부, 답변 끝 + 카드, 방향 안내 문장). **2-3·2-4 폐기.** **포함 여부만 §X-B 쟁점으로 승격** | 양쪽이 방식은 수용, 범위는 둘 다 "목표 금액만" 권고 → 사용자 범위 변경이라 쟁점 |
| **Z-6** | 2-1: "Spring이 `display`에 문구 키 `chat.heldAssetsBasis`를 내려보낸다" | **폐기.** display는 숫자 표시 문자열 전용(문장을 섞으면 PR-04 숫자 대조 #37 오탐). 서버가 문장을 내려야 하면 **별도 `notes`**. 이번에는 ai-server가 `load_copy()`로 읽으므로 `notes`도 불필요 | 제공자 4절 (c), 소비자 4절 |
| **Z-7** | 쟁점 3-1 추천 **3-1** | **§X-A로 재구성.** 양쪽 충돌을 명시하고 선택지 **A)3-1 B)3-2 C)아무 것도 안 함** 3개 + D-071·C2-4·DB·D-041·일정·회귀·제품 영향 표. 기획 추천은 A(3-1)로 유지하되 **이유를 교체**(3-2가 소비자에 비싸다, C2-4는 어차피 깨진다) | 제공자 3절(3-2 권고) vs 소비자 3절(3-2 거절) |
| **Z-8** | C2-4 개정이 쟁점 3-1에 **종속**된 것처럼 적혀 있었다 | **CF12-8-0으로 독립 확정.** "어느 선택지에서도 필수" + `status`를 양쪽에 담기 + F-4에도 `status` + `calc.py` 통과 + `comparable` 없음 | 제공자 조건 5, 소비자 수용 조건 5·"꼭 필요한 것" |
| **Z-9** | 쟁점 3-4(`changed` 초과) | **확정.** 더해 **카드 예고 한 줄**(신규 `chat.changedAlreadyExceeded`)과 **초과 칸에도 `*.goalAmount`·`*.heldAssets` display**를 추가 | 소비자 X-3-4 |
| **Z-10** | 쟁점 3-6: `display["current.goalAmount"]`, "`goalAmount`는 이미 display 허용 키" | **확정 + 수정.** 무접두어 `goalAmount`가 **비교에서 changed가 current를 조용히 덮어쓴다**는 사실을 근거로 제시하고, 쪽별 분리 + `DISPLAY_KEY` 정규식 개정을 확정. **키 이름은 `conditions.current.goalAmount` 권고**, 제공자 안(`current.goalAmount`)과의 차이는 재검토 질문 P-2·C-2로 | 제공자 1절 ④·조건 4, 소비자 X-3-6 |
| **Z-11** | 쟁점 3-7(`achievementChange`를 null로 숨김) | **폐기.** 그대로 쓰고 카드·답변에 주의 문구를 **코드가** 붙인다. `{currentGoal}`·`{changedGoal}` 자리와 본문 방향 명시 | 소비자 3-7 반대 |
| **Z-12** | 쟁점 3-6의 `prompts.py` 영향 언급 없음 | **`prompts.py:30-31`("goalAmount는 같은 값이라 어느 쪽을 인용해도 됩니다")의 전제가 깨진다**를 CF12-4-2 z로 추가 | 소비자 1-1절 |
| **Z-13** | 쟁점 4(ai-server 두 겹) 프롬프트 변경 = `:18`·`:21`·`:54`·`:75` | **확정 범위 교체: `:7-8, 18, 21-27, 30-31, 53-54, 70, 75` + 신규 규칙.** "필요하지만 충분하지 않다"(예: `:23`이 남으면 "3,000만원 모았어요"에 옛 문장) | 소비자 1-1절 |
| **Z-14** | `GOAL_AMOUNT_COPY` 상수 **삭제** | **삭제하지 않고 목표 종류·기존 납입액 전용 문구로 재사용** | 소비자 1-1절·1-3절 |
| **Z-15** | 쟁점 4-1: "'2,500만원'을 `2500`으로 보내면 `min 10000`을 통과한다" | **틀렸음을 명시하고 정정.** 실제 구멍은 ①1억 이상 만 단위(`10000`) ②×10·×100 과환산 ③보유 자산 전 구간(`min 0`). 표로 제시 | 소비자 2-1절 |
| **Z-16** | 쟁점 4-2: 프롬프트 한 줄 + fake 테스트 | **세 겹으로 확정**: (a) 프롬프트 2줄(단위 + **역할 규칙**) (b) **추출 후 결정적 대조 `check_amount_units`**(HELD를 여는 전제) (c) 카드·답변의 두 번째 확인. 금액 세 개의 **역할 혼동**("300만원 모으려면" → 월 저축액 300만원이 조용히 통과)을 새 위험으로 추가 | 소비자 2-2·2-3절 |
| **Z-17** | 쟁점 4로 다루던 것 | 쟁점에서 **내려 확정 본문(CF12-9)으로**. 양쪽 모두 수용이고 결정할 것이 없다 | 양쪽 수용 |
| **Z-18** | 없음 | **CF12-9-2 신설**: 고정 문장 테스트 7그룹을 **삭제하지 않고 대상 교체**(D-056·CP-05 보호 유지). `test_out_of_scope.py:230`은 그대로 둔다 | 소비자 1-2절, 사용자 지시 |
| **Z-19** | 없음 | **CF12-9-4 신설**: FR-AI-02 구멍 5건과 막는 방법 | 소비자 7절 |
| **Z-20** | 없음 | **CF12-10 신설**: DB·저장·적용·모듈 경계·오류 코드 점검표. **DB 스키마 변경 0**, `merge` 2줄, 되돌리기 추가 작업 없음, `source` CHECK에 `'CHAT'` 있음, F-4 `conditions` 6행·`status`, `ModularityTests` 통과 예상 | 제공자 5·8절, 소비자 6절 |
| **Z-21** | 없음 | **CF12-11 신설**: 배포 순서 Spring → ai-server → 프론트(역순이면 F-4 전부 500) + **#132 선행 못 박기** | 제공자 조건 2·3, 소비자 6절 |
| **Z-22** | 없음 | **CF12-13 신설**: 문구표 신규 5(`condition.goalAmount`, `condition.heldAssets`, `chat.goalAmountChangedNote`, `chat.heldAssetsBasis`, `chat.changedAlreadyExceeded`) · 개정 3(`chat.unchangeableCondition`, `chat.alreadyExceeded`, `result.alreadyExceeded`) + 동기화 대상 | 소비자 X-3-6 말미·"꼭 필요한 것" |
| **Z-23** | CF12-10-1 C2-3: "문서 한 줄을 6개로" | **`CalcComparison.ConditionValues` 공개 레코드 2필드 + REST Docs 스냅샷 + ai-server `ComparisonResponse`** 라는 코드 사실을 메모로 추가 | 제공자 1절 ③ |
| **Z-24** | CF12-10-1 C2-6: "키 표" 한 줄 | 4항목으로 구체화(쪽별 목표 금액 / 초과 칸 display / 비교 `calcStartMonth`·`heldAssets` 노출 = **C2-6의 의도적 규칙 개정** / 무접두어 키의 용도 한정) | 제공자 1절 ④, 소비자 X-3-6 |
| **Z-25** | CF12-10-3 C1a-10 규칙 9: 문구 교체만 | **"한쪽이 초과인 비교에서는 그쪽은 `result.alreadyExceeded` 문장만 인용하고 비교 문장을 만들지 않는다"** 추가 | 소비자 3-1 조건 5 |
| **Z-26** | CF12-10-3 C1a-12: `chat.alreadyExceeded` 본문 개정 | **"그 값으로도 이미 넘었어요"로도 읽혀야 한다**(목표를 올렸는데 여전히 초과) + `ChatWindow` 고정 문장(D-063)이 사용자를 대화로 끌어오는 **선행 조건**임을 추가 | 소비자 3-1 조건 4·3절 말미 |
| **Z-27** | CF12-10-2 C12b-6 | **F-4 `conditions` 6행 + 각 칸 `status`**(프론트 타입 추가)를 명시 | 소비자 6절 |
| **Z-28** | CF12-10-2 C12b-14: "6키 고정 맵" | **모르는 키 동작이 계약에 없다**를 쟁점 **§X-E**로 승격(제공자 의견 없음 → 재검토 질문 P-5) | 소비자 6절, 사용자 지시 |
| **Z-29** | CF12-10-7 moeun 사본 목록 | `moeun/backend/src/test/resources/contract/internal-calc/a4-response.json`, `moeun/docs/api/examples/.../field-not-changeable-response.json` 추가 | 제공자 1절, 소비자 1-2절 |
| **Z-30** | CF12-11 SRS 표 FR-AI-06 | **단위·역할 혼동 수용 기준**과 **`drop_carried_conditions`가 새 키를 지우지 않는다**는 수용 기준 추가 | 소비자 1·2절 |
| **Z-31** | CF12-12 후속 표: Issue **후보(추정)**, 상태 표기 없음 | **`gh` 대조 결과로 정정 + CLOSED 표시.** T-3(#10→#32/신규), T-12(**#54→#53**), T-5·T-11→**#132**, T-12 선행 유지, T-13→#51. T-8·T-9에 `drop_carried_conditions`·`calc.py`·`check_amount_units` 추가, T-11에 "모르는 키" 테스트 추가, T-2에 fixture 컴파일 수선 추가 | 제공자 7절, 소비자 "CF12-12 후속 표" 판정, 사용자 지시 |
| **Z-32** | 없음 | **§X-D 신설**(Issue reopen 정책): CLOSED 13건 표 + 선택지 A/B/C + 혼합 추천 | 제공자 7절 말미(Q 후보), 사용자 지시 |
| **Z-33** | 없음 | **CF12-16 신설**: A팀·B팀 작업량 추정(제공자 ≈4.1일 + 조건별 가산, 소비자 ≈7~8인일, B안이면 각 ≈3일·4.5인일) | 제공자 6절, 소비자 8절 |
| **Z-34** | CF12-13 "검토자에게 묻는 질문" P-1~6 / C-1~6 | **전면 교체.** 1차 검토에서 **답을 받은 질문은 삭제**(P-1 터지지 않음 / P-2 영향 호출부 / P-3 문구·프론트 없음 / P-4 `tax.note` 재사용 가능 / P-5 `current.`·`changed.` 권고 / C-2 `settledStatus` 이미 처리 / C-5 이 변경이 먼저). **재검토 질문 P-1~7 · C-1~8로 새로 작성** | 두 검토의 답 |
| **Z-35** | CF12-14 결정 요약 6행 | **X-A~X-E 5행 + 양쪽 의견 칸** + **확정(합의) 항목 21건 표** 신설 | 분류 규칙 |
| **Z-36** | 쟁점 번호 1·2·3-1~3-7·4-1·4-2 (9개) | **X-A~X-E (5개)**. 매핑: 쟁점1→확정(Z-1), 쟁점2→**X-B**(설계는 확정), 쟁점3-1→**X-A**, 3-4·3-6→확정, 3-7→폐기, 쟁점4→확정, C-6→**X-C**, 신규 **X-D**·**X-E** | 분류 규칙 |
| **Z-37** | COMPARE 동시 개방이 소비자 질문 C-6 안에만 있었다 | **§X-C 쟁점으로 승격**(제공자 "비용 0, 같이 열자" vs 소비자 "보류", 사용자 원안은 둘 다) | 양쪽 의견 충돌, 사용자 지시 |
| **Z-38** | 범위 표에 사용자 못 박음만 적혀 있었다 | 못 박음은 유지하되 **"양쪽 검토가 축소를 권고 → X-B/X-C"** 를 같은 표에 표기해 사용자가 바꿀 지점을 바로 보게 함 | 분류 규칙(사용자 범위 변경은 쟁점) |
