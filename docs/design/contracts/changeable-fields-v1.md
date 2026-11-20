# 대화·비교로 바꿀 수 있는 조건 확장 — 계약 개정 초안 v1 (CF12)

- 작성: tech-architect, 2026-11-20
- 항목 ID: `CF12-1`부터. (기존 Notion `CF-xx`와 다른 체계다. 혼동 방지용 접두사)
- 상태: **초안**. 쟁점 1~4는 사람이 정한다. 이 문서만으로 코드·계약을 고치지 않는다.
- 다루는 범위: `rules.yml › change-paths`의 CHAT·COMPARE 허용 필드 확장과, 그로 인해 바뀌는 계약 문서·SRS·후속 작업.

---

## CF12-1. 배경과 제품 방향

- 입력 화면을 한 번 거친 뒤에는 계획 조건을 **AI 대화로만** 바꾸게 하고, 결과 화면의 '입력 수정' 버튼은 **나중에 없앤다**(버튼 제거 자체는 이번 결정 범위 밖).
- 그런데 지금 CHAT·COMPARE 허용 필드가 4개뿐이어서 **목표 금액·보유 자산은 대화로 바꿀 수 없다**(`FIELD_NOT_CHANGEABLE`).
- 특히 FR-RES-01의 초과 안내와 `chat.unchangeableCondition` 문구가 **"목표 금액은 입력 수정에서 바꿀 수 있어요"** 로 입력 수정 버튼을 가리킨다. 버튼이 사라지면 이 안내는 **막다른 길**이 된다.
- 그래서 버튼을 없애기 **전에** 대화·비교로 바꿀 수 있는 필드를 먼저 넓힌다.

### CF12-2. 범위 (사용자가 못 박은 것)

| 항목 | 내용 |
|---|---|
| 추가 필드 | **`GOAL_AMOUNT`, `HELD_ASSETS` 둘뿐** |
| 넣지 않는 것 | 목표 종류(`GOAL_TYPE`/`GOAL_CUSTOM_NAME`). 나중에 '새 목표 세우기'로 따로 다룬다 |
| 적용 경로 | **CHAT, COMPARE 둘 다** |
| 그대로 두는 경로 | `ALTERNATIVE`(3필드, `max-fields: 1`), `INPUT_EDIT`(`all-fields: true`) |

### CF12-3. D-040 대체 선언

> **이 변경은 D-040("대화로 바꿀 수 있는 조건은 기존 4개(월 저축액, 비중, 적금 금리, 기한)를 유지하고 목표 금액은 입력 수정으로 바꾼다")을 뒤집는다.**
> 결정되면 새 D-번호를 받아 **D-040을 대체**하고, D-040 상태는 "대체됨 → D-xxx"로 바꾼다.
> 같이 바뀌는 확정 항목: **CP-07**(SRS 26행, 상태 '확정'), **D-056**(문구 안의 "4개 조건"), **D-071**(초과 계획의 대화 재계산 — 쟁점 3), **D-035**(보유 자산 기준월 안내 — 쟁점 2).
> D-041(기준은 항상 내 계획, 누적 금지)과 D-033(검증은 Spring 한 곳)은 **그대로 유지**한다.

---

## CF12-4. 코드 현황 확인 결과 (읽기만 함, `../moeun` `feature/126-input-suggestion`)

`max-fields`가 실제로 어떻게 쓰이는지와, 필드 2개를 늘릴 때 **yml만으로는 안 되는 지점**을 확인했다.

| # | 파일·위치 | 사실 | 이번 변경에서 뜻하는 것 |
|---|---|---|---|
| a | `plan/application/PlanRules.java:38-42` `PathRule.allows()` | `allFields \|\| fields.contains(field)` | 허용 목록은 yml만 고치면 된다 |
| b | `plan/ConditionValidator.java:83-86` | `maxFields() > 0 && changed.size() > maxFields` → `TOO_MANY_CHANGES` 1건만 내고 **즉시 반환** | `0`은 "제한 없음". **지금 CHAT·COMPARE는 허용 4개 = max 4라 이 분기가 한 번도 걸리지 않는다**(사실상 제한이 아니었다) → 쟁점 1 |
| c | `plan/ConditionValidator.java:97-107` `changedFields(ConditionOverride)` | 4필드만 맵에 넣는다 | `ConditionOverride`를 안 늘리면 **COMPARE 경로의 새 2필드는 검증조차 되지 않고 조용히 사라진다** |
| d | `plan/ConditionOverride.java:6` | `record ConditionOverride(Long monthlySavingAmount, Integer targetPeriodMonths, Integer savingsRatioPct, BigDecimal savingsRateInputPct)` | **필드 2개 추가 필요**(공개 타입 변경 → calc·plan·chat 호출부 전부 영향) |
| e | `calc/application/ConditionResolver.java:54,57` | `long goalAmount = require(plan.goalAmount(), ...)` / `long heldAssets = require(plan.heldAssets(), ...)` — **`changes`를 아예 보지 않는다** | 엔진 입력에 override를 **배선해야** 한다. 이걸 빼먹으면 "요청은 통과하는데 결과가 안 바뀜"이라는 가장 나쁜 버그가 난다 |
| f | `plan/application/PlanService.java:205-206` `merge()` | `goalAmount`·`heldAssets`를 **현재 버전 값으로 고정**해 `fields`에 넣는다 | **적용(F-5/P-6) 경로도 배선 필요.** 비교만 고치면 "카드는 바뀌는데 적용하면 안 바뀜"이 된다 |
| g | `calc/application/PlanContextProviderImpl.java:168-181` `toOverride()` | 4키 고정 | planContext 재계산(#78 `recompute`)도 4키 → 저장된 대화의 재계산이 2키를 버린다 |
| h | `calc/CalcInput.java:64` | `hasExceededGoal()` = `heldAssets >= goalAmount` | 두 필드가 **바로 이 판정의 두 변수**다 → 쟁점 3 |
| i | `calc/application/CompareConditionsUseCase.java:88-92` | `current.input().hasExceededGoal()`이면 `current`도 계산하지 않고 `409 ALREADY_EXCEEDED`. 코드 주석: *"대화로 목표·보유 자산을 바꿀 수 없어 changed도 초과다"* | **이 주석의 전제가 깨진다.** 이번 변경의 핵심 쟁점(3) |
| j | `calc/application/CalcEngine.java:95` | 초과면 `CalcStatus.ALREADY_EXCEEDED` + `scenarios` 빈 목록 | `changed`가 초과가 되는 경우(보유 자산 상향)의 응답 모양은 이미 엔진에 있다 |
| k | `ai-server/app/llm/agent.py:74-96` `_CONDITION_FIELDS`·`recalculate` 도구 | **이미 4키로 축소됨**(#21 완료). 설명문에 "네 가지" |
| l | `ai-server/app/schemas.py:31-42` `ConditionChanges` | `extra="forbid"` + 4필드 | 6키로 늘려야 모델 호출이 통과 |
| m | `ai-server/app/llm/prompts.py:8,18,21,54,75` | `GOAL_AMOUNT_COPY = chat.unchangeableCondition`, "네 가지뿐", "목표 금액을 바꾸려는 발화에는 recalculate를 부르지 않고", "목표 금액은 입력 수정에서 바꿀 수 있어요" | **프롬프트 겹을 풀어야 한다** → 쟁점 4 |
| n | `ai-server/app/llm/agent.py:54,141` | 범위 밖 안내가 "4개 조건 이름"을 잇는다 / `FIELD_NOT_CHANGEABLE` → `chat.unchangeableCondition` 매핑 | 문구 키는 **남긴다**(목표 종류 등 여전히 못 바꾸는 조건의 방어선) |

> 한 줄 결론: **yml 2줄짜리 변경이 아니다.** 허용 목록(yml) + 조건 레코드(d) + 해석기(e) + 적용 병합(f) + planContext 변환(g) + ai-server 스키마·프롬프트(l·m) 여섯 군데를 같은 PR 묶음으로 가야 "통과하지만 안 바뀜"을 피한다.

---

## CF12-5. `rules.yml` 변경 후 전문 (diff)

`moeun/backend/src/main/resources/config/rules.yml`

```diff
     fields:   # 경로와 무관한 전역 한 벌
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
+      # 목표 종류(GOAL_TYPE / GOAL_CUSTOM_NAME)는 넣지 않는다(별도 '새 목표 세우기').
+      COMPARE:     { fields: [GOAL_AMOUNT, HELD_ASSETS, MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 6 }
+      CHAT:        { fields: [GOAL_AMOUNT, HELD_ASSETS, MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 6 }
```

- `fields:` 블록은 **한 글자도 바뀌지 않는다**(전역 한 벌이고 두 필드의 범위·단위·scale은 이미 있다). 범위 수치가 그대로라서 대화 경로의 오류 문구·`min`/`max` 인용도 그대로 쓸 수 있다.
- `max-fields: 6`은 쟁점 1의 추천안이다. 사람이 다르게 정하면 이 숫자만 바꾼다.

---

## CF12-6. 쟁점 1 — `max-fields`를 몇으로 둘까

**사실**: 지금 `4`는 허용 필드 전체 개수와 같아서 `ConditionValidator:83`의 분기가 **한 번도 걸리지 않는다**. 즉 "한 번에 바꾸는 개수"를 실제로 제한한 적이 없고, `TOO_MANY_CHANGES`는 `ALTERNATIVE`(max 1)에서만 살아 있는 코드다. CP-07 문장("경로마다 바꿀 수 있는 조건과 **한 번에 바꾸는 개수**를 정한다")은 숫자를 쓰라고만 하고 몇인지는 말하지 않는다.

| 선택지 | 내용 | 장점 | 단점 |
|---|---|---|---|
| **1-1 (추천)** ⟵ 쟁점 1-1 | CHAT·COMPARE `max-fields: 6`(= 허용 전체) | 지금과 **뜻이 같다**(상한은 두지만 정상 요청을 막지 않음). CP-07의 "개수를 정한다"를 문자 그대로 지킨다. 나중에 필드를 더 늘릴 때 숫자를 안 고치면 테스트가 깨져 **의도적 확장임이 드러난다**(가드 역할) | 숫자가 허용 개수와 중복 |
| 1-2 ⟵ 쟁점 1-2 | `4`로 그대로 | yml 1줄 덜 바뀜 | **처음으로 실제 제한이 생긴다.** "목표 금액 + 보유 자산 + 월 저축액 + 기한"은 되고 5개는 `TOO_MANY_CHANGES` — 사용자가 이유를 알 수 없고, 이 코드에는 **문구도 프론트 처리도 없다**(한 번도 안 걸렸으므로). 새 UX 분기·문구·테스트가 생겨 가장 비싸다 |
| 1-3 ⟵ 쟁점 1-3 | `0`(제한 없음) | 뜻이 명확 | 가드가 완전히 사라져, 나중에 허용 목록이 잘못 넓어져도 아무도 못 알아챈다. CP-07의 "개수를 정한다"와 글자가 어긋난다 |

**추천: 1-1 (`6`).** 왜: 지금 동작을 바꾸지 않으면서(= 새 오류 경로 0개) 확장 가드만 유지하는, 셋 중 가장 싼 선택이다.

---

## CF12-7. 쟁점 2 — `HELD_ASSETS`와 D-035(시작월 기준)

**사실(계산 엔진)**: `heldAssets`는 운용 수익 없이 원금에만 더한다. `CalcEngine:159` `principal = heldAssets + monthlySavingAmount * k`, `CalcInput:18` 주석 "0 이상이며 운용 수익 없이 원금에 더한다", 그래프 첫 점(k=0) = `heldAssets`(frontend-api-plan.md 417행). 즉 **"시작월 시점의 출발 잔액"** 한 가지 뜻으로만 쓰인다.
**위험**: 사용자가 대화에서 "지금 3,000만원 모았어요"라고 말하면 그 값은 *시작월 이후의 납입이 이미 포함된 총액*이다. 그걸 `heldAssets`로 넣으면 시작월 이후 납입과 **이중 계산**된다. 이건 D-035가 입력 수정 화면에서 문구(`input.heldAssetsRecheck`, `{calcStartMonth}` 자리)로 막은 것과 **똑같은 위험**이고, 대화에는 그 문구가 없다.

| 선택지 | 내용 |
|---|---|
| **2-1 (추천)** ⟵ 쟁점 2-1 | 허용하되 **결정적 안내 문구를 붙인다.** `conditionChanges`에 `heldAssets`가 있으면 Spring이 응답 `display`에 `conditions.heldAssets`와 함께 **새 문구 키 `chat.heldAssetsBasis`**(`{calcStartMonth}` 자리)를 내려보내고, ai-server는 **그 문장을 그대로 덧붙인다**(모델이 짓지 않는다 — `tax.note` 덧붙이기 D-073과 같은 방식). 비교 화면(COMPARE)에서는 조건 라벨 옆에 같은 문구를 쓴다 |
| 2-2 ⟵ 쟁점 2-2 | 이번에는 `GOAL_AMOUNT`만 넣고 `HELD_ASSETS`는 뒤로 미룬다. 막다른 길 문제(FR-RES-01 안내)는 목표 금액만으로 풀린다 → 가장 작다. 단 "저축을 더 했어요"류 발화는 여전히 대화로 반영 못 함 |
| 2-3 ⟵ 쟁점 2-3 | 조건 없이 허용(문구 없음). 가장 단순하지만 D-035가 막은 위험이 대화 경로로 되살아난다 |
| 2-4 ⟵ 쟁점 2-4 | 허용하되 **D-035를 "시작월을 다시 잡는다"로 바꾼다**(보유 자산 변경 시 `calc_start_month`를 이번 달로 재설정). 뜻은 가장 깨끗하지만 D-013·D-032("시작월은 다시 계산해도 바뀌지 않는다")를 뒤집고 계획 버전·그래프 축·`calc_run`까지 번진다 → **3주 범위에서는 반대** |

**추천: 2-1.** 왜: 계산은 코드가 결정적으로 하고 LLM은 설명만 하는 원칙에 맞고(문구를 서버가 내려준다), D-035와 같은 방어를 같은 방식으로 대화에 옮기는 것뿐이어서 새 개념이 없다. 2-2도 합리적인 축소안이므로 범위가 빠듯하면 2-2 → 나중에 2-1 순서를 권한다.

---

## CF12-8. 쟁점 3 — 달성 판정·초과 안내가 달라진다 (가장 큰 쟁점)

목표 금액·보유 자산은 **초과 판정(`heldAssets >= goalAmount`)의 두 변수 그 자체**다. 그래서 이번 변경은 네 가지 새로운 상태를 만든다.

| 경우 | 지금 | 이번 변경 뒤 |
|---|---|---|
| (A) 미달 계획에서 4필드만 바꿈 | `current`·`changed` 둘 다 계산, 비교 카드 | 그대로 |
| (B) **초과 계획**에서 조건을 바꿈 | `current`도 계산하지 않고 `409 ALREADY_EXCEEDED` 고정 문장, 비교·적용 없음(D-071, internal-calc C3-2 검사 8) | **목표 금액을 올려 초과를 벗어나는 경로가 막혀 있다.** D-071과 정면 충돌 → 아래 |
| (C) 미달 계획에서 **보유 자산을 올려 `changed`가 초과** | 생길 수 없었다(코드 주석이 그 전제) | `changed.status = ALREADY_EXCEEDED`, `scenarios: []`. `diff`·시나리오 비교가 성립하지 않는다 |
| (D) 미달 계획에서 목표 금액만 올림/내림 | 생길 수 없었다 | `gapToGoal`·`isAchieved`·`goalReachMonth`가 **양쪽에서 다른 목표선**으로 계산된다. `diff.byScenario[].achievementChanged`의 뜻이 "조건이 좋아졌다"가 아니라 "목표선이 움직였다"일 수 있다 |

### CF12-8-1. D-071 충돌 (핵심 사용 사례)

D-071은 *"초과 계획에서 대화로 **4개 조건(D-040)** 을 바꾸면 `ALREADY_EXCEEDED` 고정 문장"* 이라고 **범위를 4개 조건으로 한정**해 적는다. 따라서 **문자 그대로 읽으면 목표 금액·보유 자산 변경은 D-071의 범위 밖**이고, 충돌이 아니라 **공백**이다. 다만 구현(`CompareConditionsUseCase:89`)은 변경 키와 무관하게 `current` 초과만 보고 던지므로 **코드는 충돌한다.** 결정이 필요하다.

| 선택지 | 내용 |
|---|---|
| **3-1 (추천)** ⟵ 쟁점 3-1 | **초과를 벗어나게 하는 변경이면 계산을 진행한다.** 규칙: `current`가 초과일 때, `conditionChanges`에 `goalAmount` 또는 `heldAssets`가 **있고** 해석된 `changed`가 초과가 아니면 → 정상 비교를 돌린다. 이때 `current.status = ALREADY_EXCEEDED`·`current.scenarios: []`로 응답에 담고(지금은 `current`조차 계산하지 않음), `diff`는 **비교 불가**로 비운다(`diff.byScenario: []`). 카드는 "현재: 이미 목표를 넘었어요 / 바꾼 조건: 계산 결과"의 **비대칭 2칸**. 그 밖의 경우(두 키가 없거나, 바꿔도 여전히 초과)는 **D-071 그대로** 고정 문장. → 막다른 길이 풀린다. 비용: internal-calc 응답 불변식(`current`는 항상 `CALCULATED`)이 깨져 계약·프론트·목 fixture가 바뀐다 |
| 3-2 ⟵ 쟁점 3-2 | **초과 계획에서는 비교를 만들지 않고 '바로 적용'만 허용한다.** 대화는 `ANSWER`로 "목표 금액을 2,500만원으로 바꿀까요?" 확인 → 적용 경로(F-5/P-6)만 태운다. internal-calc 응답 모양이 안 바뀌어 **가장 싸다.** 비용: 비교 없는 적용이라는 새 대화 흐름(확인 → 적용)이 생기고, D-041의 "적용 버튼은 가장 최근 비교 결과에만"과 맞물려 UI 분기가 하나 늘어난다 |
| 3-3 ⟵ 쟁점 3-3 | D-071 유지(초과 계획은 무조건 고정 문장). **막다른 길이 남는다** → 이번 변경의 목적을 못 이룬다. 비추천 |

**추천: 3-1.** 왜: "초과 계획에서 목표를 올려 되살린다"가 이번 변경의 **주 사용 사례**이고, 그 결과가 숫자로 보이지 않으면 사용자는 적용을 결정할 근거가 없다. 다만 3-2는 3주 범위에서 눈에 띄게 싸므로, 범위가 빠듯하면 3-2를 데모안으로 받아들일 만하다.

### CF12-8-2. (C) `changed`가 초과가 되는 경우

| 선택지 | 내용 |
|---|---|
| **3-4 (추천)** ⟵ 쟁점 3-4 | `changed.status = ALREADY_EXCEEDED`, `scenarios: []`, `diff.byScenario: []`로 내리고 카드의 "바꾼 조건" 칸은 **초과 문장**(문구표 `chat.alreadyExceeded` 재사용, 초과 금액은 말하지 않음 — plan-context 프롬프트 규칙 9). **적용 버튼은 활성.** 적용하면 결과 화면이 초과 안내가 되는데 그 경로는 D-072·#52로 **이미 구현되어 있다** |
| 3-5 ⟵ 쟁점 3-5 | 적용 버튼 비활성 + "이 조건은 이미 목표를 넘어서 적용할 수 없어요". 사용자가 사실(이미 모았다)을 계획에 반영할 수 없게 되므로 비추천 |

### CF12-8-3. (D) 목표 금액이 바뀐 비교의 표시

- **추천** ⟵ 쟁점 3-6: `goalAmount`가 `conditionChanges`에 있으면 비교 카드에 **양쪽 목표 금액을 모두 표시**한다(`display["current.goalAmount"]`, `display["changed.goalAmount"]` — `goalAmount` 키는 이미 display 허용 키다). 그리고 `diff.byScenario[].achievementChanged`를 **그대로 쓰되**, 목표 금액이 바뀐 비교에서는 프론트·모델이 "조건을 이렇게 바꾸면 달성"이라고 말하지 않고 "목표를 이렇게 바꾸면 달성"으로 읽도록 **문구 키를 따로 둔다**(신규 `chat.goalAmountChangedNote`). 왜: 목표선이 움직인 비교를 "좋아졌다"로 읽히게 하면 사용자를 오해시킨다(금융 조언 위험).
- 선택지 ⟵ 쟁점 3-7: `goalAmount`가 바뀐 비교에서는 `achievementChanged`를 `null`로 내려 아예 말하지 않는다(더 보수적, 정보 손실).

---

## CF12-9. 쟁점 4 — FR-AI-06 / ai-server의 "두 겹" 풀기

internal-calc C3-2 아래 문장은 목표 금액 변경을 **두 겹으로 막는다**고 적는다: (1) 도구 스키마 4키 + 프롬프트 고정 문장, (2) Spring `FIELD_NOT_CHANGEABLE`. 둘 다 풀어야 한다.

| 겹 | 지금 | 바꿀 것 |
|---|---|---|
| 도구 스키마 | `agent.py:74-79` `_CONDITION_FIELDS` 4키, `agent.py:86` 설명문 "네 가지" | **6키**(`goal_amount`: integer, `held_assets`: integer), 설명문 "여섯 가지". `strict: True`·`required` 전체 나열 규칙은 그대로 |
| pydantic | `schemas.py:31-42` `extra="forbid"` + 4필드 | `goal_amount: StrictInt \| None`, `held_assets: StrictInt \| None` 추가. docstring의 "조건 4개(M-2, D-040)"를 새 D-번호로 |
| 프롬프트 | `prompts.py:18` "네 가지뿐", `:21` "목표 금액을 바꾸려는 발화에는 recalculate를 부르지 않고", `:54` "목표 금액은 입력 수정에서 바꿀 수 있어요", `:75` "목표 금액을 바꾸려는 발화는 그 밖의 질문이 아닙니다" | `:18`을 여섯 가지로. **`:21`·`:54`·`:75`의 목표 금액 전용 분기는 삭제**(이게 막다른 길의 원인) |
| 문구·매핑 | `agent.py:141` `FIELD_NOT_CHANGEABLE → chat.unchangeableCondition`, `agent.py:54` 범위 밖 안내가 4개 조건 이름을 잇는다, `prompts.py:8` `GOAL_AMOUNT_COPY` | **매핑과 문구 키는 남긴다**(목표 종류·오타 키의 방어선). 단 문구 본문에서 **"입력 수정에서 바꿀 수 있어요"를 뺀다**(버튼이 사라질 예정) → `chat.unchangeableCondition` 본문 개정 필요(#18). `GOAL_AMOUNT_COPY` 상수는 삭제 |

### CF12-9-1. 단위(만원 ↔ 원)와 모호한 발화

| 선택지 | 내용 |
|---|---|
| **4-1 (추천)** ⟵ 쟁점 4-1 | **새 규칙을 만들지 않는다.** 도구 description에 "금액은 원 단위 정수"가 이미 있고(`agent.py:87`), 변환이 틀리면 `rules.yml`의 하한이 잡아 준다(`goalAmount min 10000`, `heldAssets min 0`, 둘 다 `max 10000000000`). 범위를 벗어나면 `422 VALIDATION_FAILED` → ai-server가 `min`·`max`를 인용해 `CLARIFY`로 되묻는 **기존 경로**를 탄다(D-033). "목표를 2,500만원으로" = 절대값이므로 `25000000`으로 계산 **허용**. "목표를 조금 줄이면" = 상대 표현이므로 **D-059 그대로 `CLARIFY`로 절대값 되묻기**(D-059의 "네 조건"을 "여섯 조건"으로 넓히기만 한다) |
| 4-2 ⟵ 쟁점 4-2 | 프롬프트에 "만원·억을 원으로 바꿔 쓰고, 단위가 모호하면 CLARIFY" 한 줄 + fake 모델 테스트 1~2개 추가. `goalAmount min 10000` 때문에 `2500`("2500만원"을 그대로 보낸 경우)은 **범위 안이라 안 걸린다**는 구멍을 막는다 |

**추천: 4-1 + 4-2의 테스트만.** 왜: 4-2가 지적한 구멍(`2500`이 `goalAmount` 범위 안)은 실제로 존재한다. 프롬프트 한 줄과 고정 테스트는 싸므로, **규칙은 4-1(새 상태 없음), 프롬프트 한 줄과 테스트는 4-2**를 함께 받는 것이 가장 싸고 안전하다.
단위 자동 보정(예: `2500`이면 `25000000`으로 고쳐 주기)은 **하지 않는다** — 금액을 코드가 추측하면 계산 결과가 사용자가 말한 것과 달라진다.

---

## CF12-10. 계약 문서별 "바꿀 줄" 표

### CF12-10-1. `docs/design/contracts/internal-calc.md` (최종본)

| 줄 | 절 ID | 현재 | 바꿀 내용 |
|---|---|---|---|
| 65 | C2-2 | "`conditionChanges` 허용 키 (D-040, CP-07 — **4개뿐**)" + 4행 표 | "허용 키 (새 D-번호, CP-07 — **6개**)" + `goalAmount`·`heldAssets` 2행 추가(단위 KRW, scale 0, min/max는 `fields` 그대로) |
| 74 | C2-2 | "…`goalAmount`가 조용히 버려지고" | 예시 키를 `goalType` 등 **여전히 허용 밖인 키**로 교체(이유 문장 자체는 유지) |
| 83 | C2-2 검사 3 | "허용 4개 밖의 키(`goalAmount`, `heldAssets`, `existingMonthlyContribution`, 오타 키 등)" | "허용 **6개** 밖의 키(`goalType`, `goalCustomName`, `existingMonthlyContribution`, 오타 키 등)" |
| 88 | C2-2 검사 8 | "현재 계획이 이미 목표 초과 → `409 ALREADY_EXCEEDED`(`current`도 계산하지 않음)" | **쟁점 3-1 결과 반영.** 3-1이면 "초과이고 `goalAmount`·`heldAssets`가 변경에 없거나 바꿔도 여전히 초과일 때만 409" |
| 101 | C2-3 | "대화로 바꿀 수 있는 **4개** 조건… 4개 키가 항상 모두 있다" | "**6개** 조건… 6개 키가 항상 모두 있다"(`goalAmount`·`heldAssets` 추가. `goalAmount`는 최상위에도 있어 중복 표기 주의) |
| 115·132 | C2-4 | "`status`는 이 경로의 성공 응답에서 항상 `CALCULATED`… 대화로 목표 금액·보유 자산을 바꿀 수 없으므로(D-040) `changed`도 `CALCULATED`다" | **삭제·전면 개정**(쟁점 3-1·3-4). `current`·`changed` 각각 `ALREADY_EXCEEDED`가 올 수 있고 그때 `scenarios: []` |
| 139~158 | C2-5 `diff` | 항상 `byScenario` 채움 | 한쪽이 `ALREADY_EXCEEDED`면 `byScenario: []`(쟁점 3-1·3-4) |
| 159~192 | C2-6 `display` | 키 표 | `current.goalAmount`/`changed.goalAmount` 양쪽 표기 규칙(쟁점 3-6), `conditions.heldAssets` 변경 시 `chat.heldAssetsBasis`(쟁점 2-1) |
| 248 | C3-2 | 409 `ALREADY_EXCEEDED` 행 | 발동 조건을 좁힌다(쟁점 3-1) |
| 253 | C3-2 아래 | "목표 금액 변경은 두 겹으로 막는다 …" | **문단 삭제**, 대신 "목표 **종류**는 두 겹으로 막는다"로 대상 교체(CF12-9) |
| 254 | C3-2 아래 | "`ALREADY_EXCEEDED`를 409로 둔 이유: 대화로 목표·보유 자산을 못 바꾸므로 `changed`도 반드시 초과라…" | **근거가 사라진다.** 쟁점 3-1 결과로 재작성 |
| 259 | C3-3 | "대화 경로 허용 키는 `rules.yml › change-paths.CHAT.fields`(4개)" | (6개) |
| 576~596 | 부록 A-4 | `422 FIELD_NOT_CHANGEABLE` 예시가 `goalAmount` | **예시 키 교체 필수**(`goalType` 등). Issue #10 수용 기준이 이 fixture를 쓴다 |
| 597~618 | 부록 A-5 | 409 `ALREADY_EXCEEDED` 예시 | 쟁점 3-1이면 "초과 + 목표 금액 상향" 성공 예시 **fixture 신설** 필요 |

### CF12-10-2. `docs/design/contracts/frontend-api-chat.md` (최종본)

| 줄 | 절 ID | 현재 | 바꿀 내용 |
|---|---|---|---|
| 221 | C12b-6 | "허용 밖 키가 저장된 메시지는 F-4가 500… F-5의 `FIELD_NOT_CHANGEABLE`은 방어선" | 유지(대상이 6키 밖으로 좁아짐). 문장의 "허용 4키"류 표현만 정정 |
| 292 | C12b-7-1 검사 6 | `ConditionValidator.validate(ChangePath.CHAT, conditionChanges)` 허용 밖 키 | 유지. 단 **`validate(ConditionOverride)`가 4필드 레코드**라는 코드 사실(CF12-4 c·d)을 메모로 추가 |
| 307~319 | C12b-7-2 | `FIELD_NOT_CHANGEABLE` 프론트 동작 | 유지 |
| 380·386 | C12b-9 | 422 표 | 유지 |
| 650·657 | C12b-12 | 목 `post-apply.422-field-not-changeable.json`의 `errors[].field = "goalAmount"` | **목 JSON의 field 값 교체**(`goalType` 등). `frontend/src/mocks/chat/` 실제 파일도 함께 |
| 685·697 | C12b-14 | "chat 리스너(#41)가 camelCase로 바꿔 저장(**4키 고정 맵**)" | **6키 고정 맵** |
| 698 | C12b-14 | "`ConditionChanges`가 지금 7키라 D-040의 4키와 다르다. #21(4키로 축소)을 #44·#45 선행" | **이미 4키로 축소됨**(코드 확인). 문장을 "#21을 6키로 재확장" 후속으로 교체 |
| 742·762 | C12b-18 | H-3b·H-14 후속 작업 | 6키 기준으로 수용 기준 재확인 |

### CF12-10-3. `docs/design/contracts/plan-context.md` (최종본)

| 줄 | 절 ID | 현재 | 바꿀 내용 |
|---|---|---|---|
| 14 | 머리말 | "**D-071**: 초과 계획의 대화 재계산은 C1a-11대로 `ALREADY_EXCEEDED` 고정 문장, 비교·적용 없음" | 쟁점 3-1 결과로 개정(D-071 부분 대체) |
| 233 | C1a-9 검사 4 | `mode=EXPLAIN` + `ALREADY_EXCEEDED` → LLM 없이 `chat.alreadyExceeded` | 유지(EXPLAIN은 이번 범위 밖) |
| 246·247 | C1a-8 요구 키 | `ALREADY_EXCEEDED`면 `goalAmount`, `conditions.heldAssets` | 유지 |
| 282 | C1a-10 프롬프트 규칙 7 | "**D-059** 대화로 바꿀 수 있는 **네 조건**을 상대 표현으로…" | "**여섯 조건**"(CF12-9-1) |
| 284 | C1a-10 규칙 9 | "`ALREADY_EXCEEDED`면 초과 사실과 '목표 금액은 입력 수정에서 바꿀 수 있어요'만 말한다" | **"대화로 목표 금액을 바꿔 볼 수 있어요"로 교체**(막다른 길 제거의 핵심 한 줄) |
| 289·413 | G-3 / D-10 | "`SYSTEM_PROMPT`를 D-040 4개 조건으로 고치는 일은 #21 범위" | 6개 조건으로 교체 |
| 348 | C1a-11 | "초과 계획에서도 `conditions.heldAssets` display를 남긴다" | 유지(오히려 더 필요해진다) |
| 354 | C1a-12 문구표 | `chat.alreadyExceeded` = 초과 사실 + "목표 금액은 입력 수정에서…" | **본문 개정**(#18) |

### CF12-10-4. `docs/design/contracts/frontend-api-plan.md` (최종본)

| 줄 | 절 ID | 현재 | 바꿀 내용 |
|---|---|---|---|
| 303~ | C12a-5-5 | 범위 수치 표(`goalAmount` 10000~1e10, `heldAssets` 0~1e10) | **수치 변경 없음.** "이 두 행이 이제 대화·비교 경로에도 쓰인다"는 한 줄만 추가 |
| 524 | C12a-7 | 초과 안내 `result.alreadyExceeded` 안에 목표 수정 안내 | 안내 대상을 **대화**로 바꾼다(문구 키 본문 개정, #18) |
| 527 | C12a-7 | 입력 수정 채우기(FR-INP-11), `input.heldAssetsRecheck`(D-035) | 유지. 단 D-035 안내가 **대화 경로에도 필요**해진다는 참조 추가(쟁점 2-1) |
| 613~618 | C12a-9 | P-6 `POST /api/plan/apply`는 경로 예약만(#68, Should) | **COMPARE 경로가 6필드가 되므로 P-6 요청 모양 확정 때 6키 기준**이라는 한 줄 추가 |
| 633 | C12a-10 | 422 `FIELD_NOT_CHANGEABLE` (P-6) 경로 밖 키 | 유지(대상만 좁아짐) |

### CF12-10-5. `docs/design/b-team-contracts.md`

| 줄 | 절 ID | 현재 | 바꿀 내용 |
|---|---|---|---|
| 93 | C-2 | "요청(현재 정의 그대로, 단 필드는 **4개로 줄임** — D-040)" | "필드 6개(새 D-번호, D-040 대체)" |
| **101** | C-2 | "허용 키: `monthlySavingAmount`, `savingsRatioPct`, `savingsRateInputPct`, `targetPeriodMonths`" | **`goalAmount`, `heldAssets` 추가(6키)** |
| **141** | C-3 | "422 `FIELD_NOT_CHANGEABLE` \| 대화로 못 바꾸는 조건(**목표 금액 등**) \| `OUT_OF_SCOPE` 또는 '입력 수정에서 바꿀 수 있어요' 안내(D-040)" | "대화로 못 바꾸는 조건(**목표 종류 등**) \| `ANSWER` + `chat.unchangeableCondition`(D-056)". *참고: 이 줄은 D-056(=`ANSWER`) 이전 서술이라 이미 낡았다* |
| 143 | C-3 | 409 `ALREADY_EXCEEDED` "계산 없이 안내" | 쟁점 3-1 결과 반영 |

### CF12-10-6. `docs/design/alignment.md` (참고 문서, 정합성 유지용)

| 줄 | 현재 | 바꿀 내용 |
|---|---|---|
| 26 | 불일치 2번 "D-040은 4개, moeun은 7개 → moeun 맞춤" | 해소 이력으로 정리 + 새 결정(6개)으로 갱신 |
| 58 | 같은 내용 상세 행 | 6개 기준으로 다시 씀 |

### CF12-10-7. `../moeun/docs/api/` 사본 — **이 repo에서 고치지 않는다** (목록만)

아래 파일·절은 moeun 쪽 작업(해당 Issue)에서 함께 고쳐야 한다. 내용은 위 CF12-10-1~4와 동일하다.

| 파일 | 고칠 절 |
|---|---|
| `moeun/docs/api/internal-calc.md` | C2-2(허용 키·검사 3), C2-3, C2-4, C2-5, C2-6, C3-2(두 겹 문단·409), C3-3, 부록 A-4·A-5 |
| `moeun/docs/api/frontend-api-chat.md` | C12b-6, C12b-7-1, C12b-12(목 field 값), C12b-14(4키 고정 맵) |
| `moeun/docs/api/plan-context.md` | C1a-9, C1a-10(규칙 7·9), C1a-12(문구표) |
| `moeun/docs/api/frontend-api-plan.md` | C12a-5-5 메모, C12a-7(초과 안내 문구), C12a-9 |
| `moeun/ai-server/README.md` | `recalculate` 도구 설명(4키 → 6키), 프롬프트 범위 안내 |
| `moeun/frontend/src/mocks/chat/post-apply.422-field-not-changeable.json` | `errors[].field` 값 |
| `moeun/frontend/src/mocks/README.md` | 목 개수·설명(초과→목표 상향 fixture 신설 시) |

---

## CF12-11. SRS 영향 행

| ID | 줄 | 지금 | 바꿀 내용 | 상태 영향 |
|---|---|---|---|---|
| **CP-07** | 26 | "대화로 바꿀 수 있는 조건은 월 저축액·비중·적금 금리·기한 4개를 유지하고, 목표 금액은 입력 수정으로 바꾼다(D-040)" | "대화·비교로 바꿀 수 있는 조건은 **6개**(위 4개 + 목표 금액 + 보유 자산). 목표 종류는 대화로 바꾸지 않는다. 한 번에 바꾸는 개수 상한은 경로별 `rules.yml`" | **확정 → 확정(개정)**. 출처에 새 D-번호 추가, D-040은 대체 표기 |
| **FR-AI-06** | 141~ | 대화 조건 변경 인식. 예외 수용 기준이 "목표 금액 → `ANSWER` + 전용 문구"(D-056) | 예외 수용 기준의 **대상을 목표 종류로 교체**. 목표 금액·보유 자산은 정상 인식 시나리오로 이동. 보유 자산 변경 시 시작월 기준 안내(쟁점 2-1) 수용 기준 추가. D-059 "네 조건"→"여섯 조건" | 수용 기준 다수 수정 |
| **FR-CMP-02** | 45, 241~ | "월 저축액·비중·적금 금리·기한 중 하나 이상을 바꾸면…" | "**6개 중 하나 이상**". 목표 금액이 바뀐 비교의 표시 규칙(쟁점 3-6)과 `changed` 초과(쟁점 3-4) 수용 기준 추가 | 부분확정 유지 |
| **FR-RES-01** | 183~ | 초과 안내 + "목표 금액은 입력 수정에서 바꿀 수 있어요" | 안내를 **대화로** 돌린다. "초과 계획에서 대화로 목표 금액을 올려 초과를 벗어난다"는 수용 기준 추가(쟁점 3-1) | 수용 기준 추가·수정 |
| **FR-AI-01** | — | D-071이 고친 "초과 계획에서 조건 변경" 수용 기준 | 쟁점 3-1 결과로 재작성 | D-071 부분 대체 |
| **FR-INP-03** | — | 목표 금액 입력(입력 화면) | "대화로도 바꿀 수 있다"는 참조 한 줄. 범위 수치는 그대로 | 비고만 |
| **FR-INP-05** | — | 보유 자산 입력, D-035 시작월 기준 안내 | "대화로 바꿀 때도 같은 기준 안내"(쟁점 2-1) 추가. D-035 범위 확장 | 수용 기준 추가 |
| **FR-INP-11** | 527행 참조 | 입력 수정 채우기 | 변경 없음. 다만 '입력 수정' 버튼 제거가 결정되면 이 행의 운명을 따로 묻는다(이번 범위 밖) | — |
| FR-PLAN-03·04 | — | 적용·되돌리기 | 적용 경로가 6필드를 병합하게 됨(`PlanService.merge`) — 수용 기준에 2필드 추가 | 수용 기준 보강 |
| FR-ALT-02 | — | 부족 시 대안 | **변경 없음**(`ALTERNATIVE` 3필드·max 1 유지) | — |

---

## CF12-12. 후속 작업 표 (moeun Issue는 **후보**, 번호 확정 안 함)

D-058대로 **기존 Issue 본문**(수용 기준·변경 범위·선행)에 반영한다. 새 Issue는 맞는 것이 없을 때만.

| # | 작업 | 담당 | Issue 후보(추정) | 선행 |
|---|---|---|---|---|
| T-1 | `rules.yml` CHAT·COMPARE 허용 6필드 + `max-fields`(쟁점 1) | A | **#17**(rules.yml·입력 범위 담당 Issue로 보임) | 결정 확정 |
| T-2 | `ConditionOverride` 2필드 추가 + `ConditionValidator.changedFields` 갱신 | A | #17 또는 #10 | T-1 |
| T-3 | `ConditionResolver.resolveChanged`에 `goalAmount`·`heldAssets` override 배선 + 단위 테스트("override가 결과를 바꾼다") | A | **#10**(`/internal/calc`) | T-2 |
| T-4 | `PlanService.merge`에 2필드 배선(적용 경로) | A | **#33**(PlanApplyService) 또는 #12-b 적용 | T-2 |
| T-5 | `PlanContextProviderImpl.toOverride` 6키(저장된 대화 재계산) | A | **#78**(`ChatComparisonQuery.recompute`) | T-2 |
| T-6 | `CompareConditionsUseCase` 초과 분기 재설계(쟁점 3-1·3-4) + `current`/`changed`의 `ALREADY_EXCEEDED` 응답, `diff` 비움 | A | **#10** (+ `CalcComparison` 쪽 #27·#30 영향 가능) | 쟁점 3 결정 |
| T-7 | internal-calc 계약 문서·fixture 개정(A-4 키 교체, 초과→목표 상향 성공 fixture 신설) | A | **#10** | T-6 |
| T-8 | ai-server 도구 스키마·`ConditionChanges` 6키 | B | **#21** (4키 축소를 했던 Issue — 되살림) | 결정 확정 |
| T-9 | 프롬프트 목표 금액 전용 분기 삭제 + "여섯 가지" + 단위 규칙 한 줄(쟁점 4-2) + fake 모델 테스트 | B | **#21**, 테스트는 **#23** | T-8 |
| T-10 | 문구표 개정: `chat.unchangeableCondition`·`chat.alreadyExceeded`·`result.alreadyExceeded`에서 "입력 수정" 제거, 신규 `chat.heldAssetsBasis`(쟁점 2-1)·`chat.goalAmountChangedNote`(쟁점 3-6) | 공통 | **#18**(문구표) + `CopyBook.java` 키 목록 | 쟁점 2·3 결정 |
| T-11 | chat 리스너 camelCase 변환 맵 4키 → 6키 | A | **#41** | T-8 |
| T-12 | 프론트: 비교 카드 비대칭 표시(한쪽 초과), 양쪽 목표 금액 표시, 목 JSON 갱신 | B | **#54**(F-4 카드), 목은 #12-b 범위 | T-6, T-7 |
| T-13 | '입력 수정' 버튼 제거 (**이번 범위 밖**, 선행이 T-1~T-12) | B | #51·#49 등 | 별도 결정 |

---

## CF12-13. 검토자에게 묻는 질문

### 제공자(Spring·계산 엔진·ai-server 구현)용

1. **(P-1, 쟁점 3-1)** `current`를 `ALREADY_EXCEEDED` 상태로 **응답에 담는** 변경(`CompareConditionsUseCase` 분기 재설계 + `CalcComparison.of`의 양쪽 `scenarios` 빈 목록 처리)이 3주 안에 가능한가? `diff`·`display` 빌더(`ResultDisplayBuilder`)가 한쪽이 빈 시나리오일 때 터지지 않는가?
2. **(P-2)** `ConditionOverride`에 필드 2개를 더하면 영향받는 호출부가 몇 곳인가(현재 확인된 곳: `ConditionValidator`, `ConditionResolver`, `PlanService`, `PlanContextProviderImpl`, `InternalCalcController`). 빠뜨린 곳이 있는가?
3. **(P-3, 쟁점 1)** `max-fields`를 `4`로 두면 `TOO_MANY_CHANGES`가 **처음으로 실제 발생**한다. 이 코드의 오류 문구·프론트 처리가 지금 존재하는가?
4. **(P-4, 쟁점 2-1)** Spring이 `display`에 문구 키(`chat.heldAssetsBasis`)를 내려보내고 ai-server가 그 문장을 **그대로 덧붙이는** 방식이, `tax.note`(D-073)와 같은 구조로 재사용 가능한가?
5. **(P-5)** `goalAmount`가 **최상위 응답 키**이면서(`result.goalAmount`) 동시에 `conditions.goalAmount`로도 들어가면 display 키 정규식(`DISPLAY_KEY`, `schemas.py:54-59`)과 `conditions.*` 허용 목록을 어떻게 넓히는 게 깔끔한가?
6. **(P-6, 쟁점 4)** `recalculate` 도구를 6키로 되돌리는 것이 #21에서 이미 한 축소 작업을 **되돌리는 것**인데, 테스트를 포함해 얼마나 드는가?

### 소비자(프론트·ai-server 호출 쪽)용

1. **(C-1, 쟁점 3-1)** 비교 카드의 "현재" 칸이 **숫자 없이 초과 문장**인 비대칭 카드를 그릴 수 있는가? 아니면 3-2(비교 없이 확인 → 적용)가 프론트에 더 싼가?
2. **(C-2, 쟁점 3-4)** `changed`가 초과일 때 **적용 버튼을 활성**으로 두는 데 동의하는가? 적용 후 결과 화면 초과 전환은 `settledStatus`(D-072, #52)로 이미 처리되는가?
3. **(C-3, 쟁점 3-6)** 목표 금액이 바뀐 비교에서 "달성으로 바뀜(`achievementChanged`)"을 그대로 보여 주면 오해를 살 수 있다. 별도 주의 문구(`chat.goalAmountChangedNote`)로 충분한가, 아니면 `null`로 숨기는 편이 나은가?
4. **(C-4, 쟁점 2)** `HELD_ASSETS`를 이번에 넣는 것이 꼭 필요한가, 아니면 2-2(목표 금액만 먼저)로 범위를 줄여도 제품 방향에 지장이 없는가?
5. **(C-5)** '입력 수정' 버튼 제거 시점과 이 변경의 배포 순서가 어떻게 되는가? (이 변경이 **반드시 먼저**라는 전제가 맞는지 확인)
6. **(C-6)** `COMPARE` 경로(비교 영역, FR-CMP-02는 Should)에도 6필드를 함께 여는 것이 지금 필요한가, 아니면 CHAT만 먼저 열고 COMPARE는 Should 되살릴 때 함께 여는 편이 작은가? ⟵ 쟁점 범위 축소안

---

## CF12-14. 결정 요약 (사람이 채울 칸)

| 쟁점 | 추천 | 결정 | D-번호 |
|---|---|---|---|
| 1 `max-fields` | **1-1 (`6`)** | | |
| 2 `HELD_ASSETS` | **2-1 (허용 + 시작월 기준 안내)**, 축소안 2-2 | | |
| 3-1 초과 계획의 목표 상향 | **3-1 (초과 벗어나는 변경은 계산)**, 저가안 3-2 | | |
| 3-2 `changed`가 초과 | **3-4 (초과 문장 + 적용 버튼 활성)** | | |
| 3-3 목표 금액 바뀐 비교 표시 | **3-6 (양쪽 표시 + 주의 문구)** | | |
| 4 ai-server 두 겹 | **4-1 + 4-2의 프롬프트 한 줄·테스트** | | |
