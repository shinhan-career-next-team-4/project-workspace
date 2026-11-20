# 대화·비교로 바꿀 수 있는 조건 넓히기 — 계약 개정 v3 (CF12)

- 작성: tech-architect, 2026-11-20 (v1 → 1차 검토 2건 → v2 → **재검토 2건(마지막 라운드)** → v3)
- 입력: `changeable-fields-v2.md`, `review-changeable-fields-v2-provider.md`, `review-changeable-fields-v2-consumer.md` (+ 1차 검토 2건)
- 코드 근거: `../moeun` `feature/126-input-suggestion` **읽기 전용**(switch·fetch·수정 없음). 행 번호는 그 브랜치 기준.
- 상태: **협상 종료본.** 재검토에서 수렴한 것은 **합의로 확정**해 본문에 녹였고, **사람이 정할 것은 3건**(X-B, X-F, 결정 변경 확인)만 남는다. 합의안은 `changeable-fields-proposal.md`.
- 이 문서는 **자기완결**이다. v1·v2를 읽지 않아도 된다. v2 → v3 변경은 **§Z2**에 전부 적는다.

---

## CF12-1. 배경과 제품 방향 (확정)

- 입력 화면을 한 번 거친 뒤에는 계획 조건을 **AI 대화로만** 바꾸게 하고, 결과 화면의 '입력 수정' 버튼은 **나중에 없앤다**(버튼 제거 자체는 이번 결정 범위 밖 → T-13).
- 그런데 지금 CHAT·COMPARE 허용 필드가 4개(월 저축액, 비중, 적금 금리, 기한)뿐이어서 **목표 금액·보유 자산은 대화로 바꿀 수 없다**(`422 FIELD_NOT_CHANGEABLE`).
- 특히 FR-RES-01의 초과 안내와 `chat.unchangeableCondition`·`chat.alreadyExceeded` 문구가 **"목표 금액은 입력 수정에서 바꿀 수 있어요"** 로 입력 수정 버튼을 가리킨다. 버튼이 사라지면 이 안내는 **막다른 길**이 된다.
- 그래서 버튼을 없애기 **전에** 대화·비교로 바꿀 수 있는 필드를 먼저 넓힌다.
- 왜 이렇게 했는가: 안내가 가리키는 출구를 먼저 만들고 나서 기존 출구를 닫는 순서여야, 어느 시점에도 사용자가 갇히지 않는다.

### CF12-2. 범위

| 항목 | 내용 |
|---|---|
| 추가 필드 | 사용자가 못 박은 것은 **`GOAL_AMOUNT`, `HELD_ASSETS` 둘**. **제공자·소비자가 재검토에서도 모두 "1단계는 `GOAL_AMOUNT`만"** 을 권고 → **남은 쟁점 X-B**(사용자 지시를 바꾸는 일이라 사람이 정한다) |
| 넣지 않는 것 | 목표 종류(`GOAL_TYPE`/`GOAL_CUSTOM_NAME`), 기존 납입액(`existingMonthlyContribution`). 목표 종류는 나중에 '새 목표 세우기'로 따로 다룬다 |
| 적용 경로 | **CHAT·COMPARE 둘 다 개방(합의 확정, 전 X-C).** 소비자가 보류를 철회했다 |
| 그대로 두는 경로 | `ALTERNATIVE`(3필드, `max-fields: 1`), `INPUT_EDIT`(`all-fields: true`) |

### CF12-3. 결정 변경 선언 (사람 확인 필요 — 합의안 §결정 변경)

> 이 변경은 아래 세 가지를 바꾼다. **에이전트가 확정하지 않고 사람이 확인한다.**
> 1. **D-040 대체**: "대화로 바꿀 수 있는 조건은 기존 4개 유지, 목표 금액은 입력 수정으로" → 6개(또는 X-B가 B안이면 5개).
> 2. **D-071 변경**: X-A를 3-1로 합의했으므로 "초과 계획의 대화 재계산은 `ALREADY_EXCEEDED` 고정 문장, 비교·적용 없음"이 **"목표·보유를 바꾸지 않거나 바꿔도 여전히 초과일 때만 고정 문장"** 으로 좁아진다.
> 3. **internal-calc C2-4 불변식 개정**: 성공 응답의 `status`가 항상 `CALCULATED`라는 문장을 지운다(CF12-8-0).
>
> 같이 바뀌는 확정 항목: **CP-07**(SRS 26행), **D-056**(문구 안의 "4개 조건"), **D-035**(보유 자산 기준월 안내 — 범위 확장, X-B에 종속), **D-059**("네 조건" → "여섯 조건"/"다섯 조건").
> **그대로 유지**: D-041(기준은 항상 내 계획, 누적 금지), D-033(범위 검증은 Spring 한 곳), D-013·D-032(시작월은 재계산해도 바뀌지 않는다), D-022(적용은 버튼), D-058(Issue 본문 수정 우선 — 단 X-D 혼합으로 해석을 넓힌다), ADR-002(최소 저장).

---

## CF12-4. 코드 현황 — 구현 지점 전체 목록

v1은 6곳, v2는 13곳이라고 적었다. **재검토로 두 항목(k, gg)의 사실이 바뀌어 작업 내용이 줄었다.**

### CF12-4-1. Spring (A팀)

| # | 파일·위치 | 사실 | 이번 변경에서 할 일 |
|---|---|---|---|
| a | `plan/application/PlanRules.java:38-42` `PathRule.allows()` | `allFields \|\| fields.contains(field)` | 허용 목록은 yml만 고치면 된다 |
| b | `plan/ConditionValidator.java:83-86` | `maxFields() > 0 && changed.size() > maxFields` → `TOO_MANY_CHANGES` 1건 내고 즉시 반환 | `max-fields: 6`(확정, CF12-6). **`allows(field)`를 따로 보므로 "허용 5 < max 6"에 가드 구멍은 없다**(재검토 확인) |
| c | `plan/ConditionValidator.java:97-107` `changedFields(ConditionOverride)` | 4필드만 맵에 넣는다 | 2필드 추가. 안 하면 COMPARE 경로의 새 필드가 **검증조차 되지 않고 조용히 사라진다** |
| d | `plan/ConditionOverride.java:6` | 4필드 record | **필드 2개 추가**(`goalAmount: Long`, `heldAssets: Long`). 공개 타입 변경 → 테스트 fixture 컴파일 깨짐(CF12-4-4). **X-B가 B안이어도 타입은 2필드를 한 번에 넣고 yml·Set에서만 `heldAssets`를 뺀다**(fixture 수선을 한 번만 하려고 — 소비자 C-3-2) |
| **e** | **`calc/web/InternalCalcController.java:39-42` `CHANGEABLE_KEYS`** | `Set.of(MONTHLY_SAVING_AMOUNT, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT, TARGET_PERIOD_MONTHS)`. **이 Set은 `rules.yml`을 보지 않는다** | **양보 불가.** 안 고치면 **CF12-5의 yml diff는 `/internal/calc`에 효과가 0이다** |
| **f** | **`InternalCalcController.java:86-110` `validate()` / `:99-100` `hasValidatableValue`** | 키를 하드코딩해 하나씩 꺼낸다 | `goalAmount`(long) 2줄(+2단계 `heldAssets`) + `hasValidatableValue` 조건 추가. 빼먹으면 `conditionChanges: {goalAmount: …}` 하나만 온 요청이 **검증을 건너뛴다** |
| g | `calc/application/ConditionResolver.java:54,57` | `goalAmount`·`heldAssets`를 계획값에서만 읽고 **`changes`를 아예 보지 않는다** | 엔진 입력에 override 배선. 빼먹으면 "요청은 통과하는데 결과가 안 바뀜" |
| h | `plan/application/PlanService.java:202-216` `merge()` | 두 값을 **현재 버전 값으로 하드코딩** | `firstNonNull(changes.goalAmount(), current.getGoalAmount())` **2줄**. 빼먹으면 "카드는 바뀌는데 적용하면 안 바뀜". **CHAT·COMPARE 공용이라 어느 경로를 열어도 필요** |
| **i** | **`calc/application/PlanContextProviderImpl.java:47-53` `CHANGEABLE_KEYS`** | 허용 밖 키는 `toOverride`(`:168-172`)에서 `IllegalArgumentException` | **양보 불가.** 저장된 대화 재계산(F-4)에 `goalAmount`가 있으면 **500** → 배포 순서(CF12-11)의 근거 |
| j | `PlanContextProviderImpl.java:168-181` `toOverride()` | 4키 고정 | 6(5)키 |
| ~~k~~ | ~~`calc/CalcComparison.java:29-45` `ConditionValues` 2필드 확장~~ | **이번 범위에서 뺀다** | **쪽별 `goalAmount`는 `CalcResultView.java:21`에 이미 있다**(소비자 F-4 목 JSON 확인, 제공자 ≈0.5일 절감). 따라서 **internal-calc C2-3("4개 키가 항상 모두 있다")·REST Docs 스냅샷·`a4-response.json`의 `conditions` 부분은 고치지 않는다.** 2단계에서 raw 보유 자산이 필요해지면 그때 더한다 |
| **l** | **`calc/application/ResultDisplayBuilder.java`** | `build()` 첫 줄 `display.put("goalAmount", …)`(무접두어). `CompareConditionsUseCase.buildDisplay:128-137`이 current·changed 두 번 불러 `putAll` | **양보 불가.** 목표가 바뀐 비교에서 **changed 값이 current를 조용히 덮어쓴다** → 쪽별 분리(CF12-8-3). `build(input, result, resultPrefix, conditionPrefix)`가 **이미 조건 접두어를 받고** `CompareConditionsUseCase:33-36`에 `CONDITIONS_CURRENT`·`CONDITIONS_CHANGED` 상수가 있어 `putConditions`에 **한 줄** |
| **m** | **`ResultDisplayBuilder.putConditions(...)`** | `heldAssets`·`calcStartMonth`·`assumptions`를 **`isSingleResult`일 때만** 넣는다(C2-6이 의도적으로 정한 규칙) | **1단계에도 부분 해제 필요**: "그 쪽 `status`가 `ALREADY_EXCEEDED`면 `conditions.<side>.heldAssets`를 만든다"(CF12-8-2a). `calcStartMonth`·`assumptions`의 전면 해제와 **C2-6 개정은 2단계**(X-B) |
| n | `calc/CalcInput.java:63-64` | `hasExceededGoal()` = `heldAssets >= goalAmount`, 캐시 없음 | 두 추가 필드가 **바로 이 판정의 두 변수** → CF12-8 |
| o | `calc/application/CompareConditionsUseCase.java:88-92` | `current.input().hasExceededGoal()`이면 `current`도 계산하지 않고 `409 ALREADY_EXCEEDED` | **분기 역전**(합의 3-1): `changed`를 먼저 해석해 `changed`가 초과가 아니면 통과(CF12-8-1) |
| p | `calc/application/CalcEngine.java:93-95,159` | 초과면 `ALREADY_EXCEEDED` + `scenarios` 빈 목록 | 응답 모양은 **이미 엔진에 있다**. `Diff.between`은 교집합만 담아 `byScenario`가 자연히 빈다 → **수정 0** |
| **q0** | **`calc/CalcResultView.java:21`** | `record CalcResultView(CalcStatus status, long goalAmount, YearMonth calcStartMonth, …)` — **`status`가 이미 있고** `web/InternalCalcResponse.java:21-28`이 그대로 내보낸다 | **Spring 코드 변경 0.** javadoc(`:11` "이 경로의 성공 응답에서는 늘 CALCULATED")과 계약 문구만 고친다. 소비자 쪽 타입에 필드 추가만 남는다 |

### CF12-4-2. ai-server (B팀)

| # | 파일·위치 | 사실 | 이번 변경에서 할 일 |
|---|---|---|---|
| q | `app/schemas.py:31-42` `ConditionChanges` | `extra="forbid"` + 4필드 | `goal_amount`(1단계), `held_assets`(2단계): `StrictInt \| None` 추가, docstring D-번호 갱신 |
| r | `app/llm/agent.py:74-79,86-87` `_CONDITION_FIELDS`·`recalculate` 도구 | 4키, "네 가지" | 5(6)키, 설명문 수정. `required`는 `list(_CONDITION_FIELDS)`라 자동 |
| **s** | **`agent.py:165-230` `_stated_conditions`·`drop_carried_conditions`** | 발화 표현으로 "말한 조건"을 4개만 가려내고 그 밖의 키는 history에서 이어받은 값으로 보고 지운다(`:230` `if k in stated`). **단 `_count_numbers`의 "숫자 덩이 수 > 인식 조건 수면 유지" 가드가 있다** | **새 정규식 `_GOAL`(목표·모으려)·`_HELD`(보유·가진·모아둔·이미·지금 있는) 추가**(둘 다 1단계) + `test_no_accumulate.py:337-372` 표에 목표·보유 행. 조건부 서술은 CF12-4-2a |
| **t** | **`app/tools/calc.py:86-102` `_select_for_model`, `:117-125` `_select_side`** | 모델에 `scenarios[].{scenario,isAchieved}`만 주고 **`status`를 안 준다.** `display`는 **필터 없이 통째로 통과**시킨다 | **`status` 통과 필수**(CF12-8-0). display 쪽별 키는 **ai-server 비용 0** |
| u | `app/llm/prompts.py:7-8` `GOAL_AMOUNT_COPY` | `= chat.unchangeableCondition` | 상수를 **삭제하지 않고 목표 종류·기존 납입액 전용 문구로 재사용** |
| v | `prompts.py:18` | "네 가지뿐" | "다섯(여섯) 가지" |
| w | `prompts.py:21-22` | 목표 금액 발화 → `recalculate` 부르지 않고 전용 문구 | **삭제**(막다른 길의 직접 원인) |
| **x** | **`prompts.py:23-24`** | "이미 모은 돈이나 기존 납입액 … 입력 수정에서 바꿀 수 있다고" | **X-B가 B안이면 "이미 모은 돈"은 1단계에도 여전히 입력 수정이다** → 이 줄은 **대상을 좁혀 남긴다**(기존 납입액 + 보유 자산). A안이면 "기존 납입액"만 남긴다 |
| **y** | **`prompts.py:25-27`** | "네 조건을 더/덜…"(D-059 상대 표현 → CLARIFY) | "다섯(여섯) 조건". 목표도 상대 표현은 되묻는다 |
| **z** | **`prompts.py:30-31`** | "goalAmount는 같은 값이라 어느 쪽을 인용해도 됩니다" | **전제가 깨진다.** "목표 금액은 `conditions.current.goalAmount`·`conditions.changed.goalAmount`를 각각 인용한다. 무접두어 `goalAmount`는 비교 응답에 **없을 수 있다**"로 고친다 |
| **aa** | **`prompts.py:53-54` 규칙 9** | "status가 ALREADY_EXCEEDED이면 … 초과 금액은 말하지 않는다" — **단일 결과 기준으로 적혀 있다** | **쪽별로 다시 쓴다**(제공자가 재검토에서 새로 제기, T-8 범위): 비대칭 2칸에서 모델이 어느 쪽 `status`를 보는지 못 박고, **초과인 쪽은 초과 사실만 말하고 비교 문장을 만들지 않는다**. 문구는 "대화로 목표 금액을 바꿔 볼 수 있어요" |
| bb | `prompts.py:70,75` | 조건 변경 정의 4개 / "목표 금액 발화는 그 밖의 질문이 아니다" | `:70` 5(6)개, `:75` **삭제** |
| cc | `agent.py:45-57` `out_of_scope_content`·`_CONDITION_COPY_KEYS`, `app/core/copy.py:93` `_CONDITION_CODES` | 범위 밖 안내가 "4개 조건 이름"을 잇는다 | 문구표에 `condition.goalAmount`(+2단계 `condition.heldAssets`) 추가. `tests/test_out_of_scope.py:119-125`가 "목표 금액이 **없다**"를 단언하므로 **뒤집힌다** |
| dd | `agent.py:139-144` `_FIXED_COPY_KEYS` | `FIELD_NOT_CHANGEABLE → chat.unchangeableCondition`, `ALREADY_EXCEEDED → chat.alreadyExceeded`. **409 코드 → 문구 키 매핑이다** | **매핑·키 유지, 수정 0줄.** 3-1 뒤에도 409는 남는다(바꾸지 않거나 바꿔도 여전히 초과). 문구 **본문**만 개정(CF12-13) |
| ~~ee~~ | ~~`agent.py:424,441`~~ | **`check_plan_context`의 EXPLAIN 모드 planContext 분기이고 비교 응답을 보지 않는다** | **수정 0줄**(v2의 "개정" 서술은 틀렸다) |
| ff | `agent.py:570,582` `load_copy()`·`with_tax_note` | ai-server가 문구표를 직접 읽고 `check_numbers` **뒤에** 문장을 덧붙이는 자리가 이미 있다 | `chat.goalAmountChangedNote`·`chat.changedAlreadyExceeded`(+2단계 `chat.heldAssetsBasis`)를 **같은 자리·같은 방식**으로(D-073) |
| **gg0** | **`app/schemas.py:84-90` `DISPLAY_KEY`** | `PlanContext`의 `@field_validator("display")`에서만 쓰는 **planContext 전용 필터**. 비교 응답은 `calc.py:_select_for_model`이 필터 없이 통과시켜 `current.GOOD.afterTaxAsset` 같은 키가 **이미 통과 중** | **쪽별 키 때문에 고칠 일은 없다.** **단일 경로에 `conditions.goalAmount`가 새로 생기는 경우에만** 한 단어를 같은 PR에서 더한다(안 더하면 `_keep_allowed_display`가 **조용히 버린다**). ai-server에 `ComparisonResponse` 스키마는 **없다**(비교 응답은 dict로 읽는다) |

#### CF12-4-2a. `drop_carried_conditions` 위험의 정확한 조건 (재검토로 확정)

v2는 "history가 있으면 새 키가 지워진다"로 읽혔다. **정확히는 조건부다**(제공자가 손으로 재현):

| 발화 | `_count_numbers` | `_stated_conditions` | 결과 |
|---|---|---|---|
| "목표를 1억으로 올려줘" | 1 | `{}` (0개) | `1 > 0` → **유지된다**(지워지지 않는다) |
| "목표 2,500**만원**으로 바꿔줘" | 1 | `{monthly_saving_amount}`(`만원`이 `_MONTHLY:186`에 걸린다) | `1 > 1` 거짓 → `goal_amount`가 **조용히 지워진다** |

→ **위험은 "금액 단위 토큰이 붙은 목표·보유 발화에서, 그 발화의 숫자 덩이 수가 인식 조건 수를 넘지 않을 때"** 일어난다. 사용자가 거의 항상 "만원"을 붙여 말하므로 실제 빈도는 높다. `_GOAL`·`_HELD` 정규식은 **1단계 필수**다(보유 자산을 못 바꾸는 1단계에서도 "3,000만원 모았어요"가 월 저축액으로 오인되는 것을 막아야 한다).

### CF12-4-3. chat 저장·프론트

| # | 위치 | 사실 | 할 일 |
|---|---|---|---|
| **gg** | chat 리스너의 camelCase 변환 | **v2의 "4키 고정 맵"은 코드에 없다.** `backend/src/main/java/com/moeun/backend/chat/`은 `package-info.java` **한 파일뿐**이고 `origin/develop`도 같다(#41은 CLOSED지만 코드 없음). 저장·F-4·F-5는 **#44·#45·#128(모두 OPEN, `team:B`)** 이 앞으로 쓴다 | **"아직 안 쓴 코드의 설계를 정하는 일"** → 처음부터 6(5)키 + **모르는 키는 메시지 FAILED**(CF12-10-1). 비용 ≈0, 소유는 **B팀** |
| hh | `frontend/src/features/chat/ChatWindow.tsx` | 대화 비교 카드가 **아직 없다**(diff·changed 렌더링 없음). 초과는 `:112` `settledStatus === "ALREADY_EXCEEDED"` 고정 문장뿐. **`settledStatus`는 계획 조회(`PlanView.status`) 값이고 비교 응답과 무관하다** | 카드를 **처음부터** 설계하므로 비대칭 칸이 지금 가장 싸다(≈0.5~1일). `settledStatus` 분기는 **고치지 않는다** |
| ii | `frontend/src/features/chat/types.ts`, `copy.ts:5`, `shared/copy/copy.ts:30` | F-4 응답 타입에 `status` 없음. `alreadyExceeded` 본문이 프론트에 복제되어 있다 | `status` 필드 추가(목 JSON에는 이미 `current.status`·`current.goalAmount`가 있다), 문구표와 동기화 |
| jj | `frontend/src/mocks/chat/post-apply.422-field-not-changeable.json` | `errors[].field = "goalAmount"` | 값 교체(`goalType` 등) |

### CF12-4-4. 테스트·fixture 깨짐 (변경 범위에 명시)

| 대상 | 내용 |
|---|---|
| **`ConditionOverride` 생성자** | `new`로 부르는 테스트 **4파일 20여 곳** 컴파일 깨짐: `ConditionValidatorTest`, `ConditionResolverTest`, `ChatComparisonQueryTest`, `PlanContextProviderTest`. 기계적이지만 ≈0.5일. **2필드를 한 번에 넣어 한 번만 수선한다** |
| **계약 fixture** | `backend/src/test/resources/contract/internal-calc/a4-response.json`의 `field: "goalAmount"` → **교체 필수**. **`a5-already-exceeded.json`은 이미 있다 → 지우지 않는다.** "`current` 초과 + `changed` 정상"의 **200 성공 예시를 별 파일로 더하고**, 기존 409 예시는 **"바꿔도 여전히 초과" 사례로 의미를 재배치**한다(`InternalCalcApiTest:240`도 그 사례로 교체) |
| REST Docs | `docs/InternalCalcDocsTest.java` 스냅샷 — **`conditions` 부분은 바뀌지 않는다**(k 제외). display 키 추가분만 |
| ai-server fixture | `tests/test_calc_client.py:269` fake 응답 dict + `docs/api/examples/.../field-not-changeable-response.json`의 `field: goalAmount`. **`ComparisonResponse` 스냅샷은 없다** |
| **고정 문장 테스트(삭제 금지)** | CF12-9-2 표 |

> 한 줄 결론: **yml 2줄짜리 변경이 아니다.** yml(a) + 조건 레코드(d) + **컨트롤러 Set·validate(e·f)** + 해석기(g) + 적용 병합(h) + **planContext Set(i·j)** + **display 키 분리(l·m)** + ai-server 스키마·프롬프트·**`drop_carried_conditions`(q~gg0)** + chat 저장(gg)을 같은 묶음으로 가야 "통과하지만 안 바뀜"과 "조용히 지워짐"을 피한다.

---

## CF12-5. `rules.yml` 변경 후 전문 (확정)

`moeun/backend/src/main/resources/config/rules.yml`

```diff
     fields:   # 경로와 무관한 전역 한 벌 — 한 글자도 바뀌지 않는다
       GOAL_AMOUNT:            { required: true, min: 10000, max: 10000000000, unit: KRW, scale: 0 }
       HELD_ASSETS:            { required: true, min: 0, max: 10000000000, unit: KRW, scale: 0 }
       ...
     change-paths:            # max-fields 0 = 제한 없음
       INPUT_EDIT:  { all-fields: true, max-fields: 0 }
       ALTERNATIVE: { fields: [MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT], max-fields: 1 }
-      COMPARE:     { fields: [MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 4 }
-      CHAT:        { fields: [MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 4 }
+      # CF12(D-040 대체): 입력 수정 버튼을 없애기 전에 목표 금액(·보유 자산)을 대화·비교로 바꿀 수 있게 한다.
+      # 목표 종류(GOAL_TYPE / GOAL_CUSTOM_NAME)·기존 납입액은 넣지 않는다.
+      COMPARE:     { fields: [GOAL_AMOUNT, MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 6 }
+      CHAT:        { fields: [GOAL_AMOUNT, MONTHLY_SAVING_AMOUNT, TARGET_PERIOD_MONTHS, SAVINGS_RATIO_PCT, SAVINGS_RATE_INPUT_PCT], max-fields: 6 }
```

- 위 diff는 **X-B가 B안(목표 금액만, 1단계)** 일 때의 모양이다. **X-B가 A안이면 두 줄에 `HELD_ASSETS`를 함께 넣는다.** `max-fields`는 **어느 쪽이든 6**(CF12-6).
- `fields:` 블록은 **불변**(전역 한 벌이고 두 필드의 범위·단위·scale이 이미 있다). 범위 수치가 그대로라서 대화 경로의 오류 문구·`min`/`max` 인용도 그대로 쓸 수 있다.
- **주의**: 이 diff만으로는 `/internal/calc`에 **효과가 0이다**(CF12-4-1 e). 반드시 e·f·i·j와 같은 묶음.

---

## CF12-6. `max-fields` = **6** (확정)

- `ConditionValidator.java:83-86`의 분기는 `maxFields() > 0 && changed.size() > maxFields`다. 지금 허용 4 = max 4이므로 **한 번도 도달한 적이 없다.**
- **`5`(X-B가 B안일 때의 "딱 맞는 값")를 거절하는 이유**: `ConditionValidator.validateChanged:83-86`은 `maxFields()`와 **별도로 `pathRule.allows(field)`를 본다.** 허용 밖 키는 `FIELD_NOT_CHANGEABLE`로 **개별 거절**되므로 **"허용 5 < max 6"은 가드 구멍이 아니다**(v2가 걱정한 "가드 논리 약화"는 일어나지 않는다). 5로 두면 2단계에서 yml을 또 고치고 `PlanRulesTest`·계약 문서를 두 번 만진다.
- **`4`를 거절하는 이유**: 처음으로 실제 제한이 생겨 `TOO_MANY_CHANGES`가 처음 발생한다. 그런데 `CopyBook.java:50` 코드 목록에 그 코드가 **없고**, 프론트 분기 **0건**, ai-server 매핑도 없다 → 문구 키 신설 + 매핑 + 분기 + 테스트가 새로 필요하다(≈0.5~1일, 가치 0).
- **`0`(제한 없음)** 은 가드가 사라져 나중에 허용 목록이 잘못 넓어져도 아무도 못 알아챈다.
- **딸림 확정**: `TOO_MANY_CHANGES`의 문구·화면·ai-server 매핑은 **이번에 만들지 않는다**(6이면 발생하지 않는다).
- 왜 이렇게 했는가: 새 오류 경로를 0개로 유지하면서 "나중에 숫자를 안 고치면 테스트가 깨져 의도적 확장임이 드러나는" 가드만 남긴다. 비용 0.

---

## CF12-7. `HELD_ASSETS`와 D-035 (설계 확정, 구현 시점은 X-B)

### CF12-7-1. 확정 사실

- `CalcInput.java:18`·`:46`(`heldAssets >= 0`), `CalcEngine:159` `principal = heldAssets + monthlySavingAmount * k` — **"시작월 시점의 출발 잔액" 한 가지 뜻**뿐. 그래프 첫 점(k=0) = `heldAssets`.
- `ConditionResolver.createInput:92-99`은 `calcStartMonth`를 **항상 계획 저장값**으로 쓴다(D-013·D-032).
- → **override로 `heldAssets`를 바꿔도 계산 자체는 올바르다. 엔진에 이중 계산 로직은 없다.**
- **남는 위험은 전적으로 "사용자가 말한 숫자의 의미"다.** "지금 3,000만원 모았어요"는 *시작월 이후 납입이 이미 포함된 총액*이고, 그걸 `heldAssets`로 넣으면 이중 계산된다. D-035가 입력 화면 문구(`input.heldAssetsRecheck`, `{calcStartMonth}` 자리)로 막은 것과 똑같은 위험이고 대화에는 그 문구가 없다.

### CF12-7-2. 가드 설계 (2단계에 함께 간다)

1. **문장은 코드가 붙인다. 모델이 짓지 않는다.** `conditionChanges`에 `held_assets`가 **있을 때만** ai-server가 문구표 `chat.heldAssetsBasis`를 읽어 답변에 덧붙인다(`load_copy()`·`with_tax_note`와 같은 자리·같은 방식, D-073).
2. **위치는 답변 맨 끝, `check_numbers` 뒤.** `{calcStartMonth}`(`2026년 11월`)가 숫자 토큰이라 앞에 붙이면 `NUMBER_MISMATCH`가 난다.
3. **Spring은 문장이 아니라 자리 값만 내린다.** 비교 응답 `display`에 `calcStartMonth`를 추가한다. `DISPLAY_KEY`에 `calcStartMonth`는 이미 있다. 키가 없으면 **문장을 생략하고 로그만 남긴다**(틀린 월을 말하는 것보다 안전).
4. **카드에도 같은 문구**를 정적으로 표시한다(사용자가 답변을 안 읽고 적용 버튼만 누를 수 있다).
5. **문장은 방향을 알려 준다**: "이 값은 {calcStartMonth} 당시 기준이라, 그 뒤 납입분은 월 저축액으로 이미 계산돼요." 용어는 D-035 문구를 재사용한다.
6. **C2-6 개정이 2단계 범위에 들어온다** — 이것은 "display 한 줄"이 아니다(제공자 양보 불가). C2-6은 *"비교에서는 `calcStartMonth`·`heldAssets`·`assumptions`를 만들지 않는다 — 비교 답변이 세율·기준월을 인용하지 않게 하려는 것"* 이라고 **의도를 적어 둔 규칙**이다. 범위 = 규칙 개정 + **그 규칙이 막던 위험(비교 답변이 기준월·세율을 인용)을 프롬프트로 다시 막기**.
7. **`check_amount_units`(CF12-9-3 b)가 `HELD_ASSETS`를 여는 전제 조건이다.** 진입 조건 셋: ① 표 테스트 **15행 이상** 통과(1억 5천만원, 2천5백만원, 1.5억, 300만 원, 쉼표, 단위 없음, 역할 혼동 포함) ② fake 모델 고정 JSON 2건("1억 → 10000", "3,000만원 → 300000000"이면 Spring을 부르지 않고 CLARIFY) ③ **2주차 말까지 머지**. 못 하면 `HELD_ASSETS`는 이번 범위에서 빠지고 T-13도 하지 않는다.
8. **`held_assets`는 숫자 토큰이 없으면 검사를 건너뛰지 않고 CLARIFY**("숫자로 다시 말해 주세요"). 한글 수사 "삼천만원"을 모델이 `3000`으로 내면 카드가 "약 0만원"이라 사용자가 알아챌 수 없다(목표 금액은 건너뛰기 허용 — "약 1만원"은 눈에 보인다).

### CF12-7-3. 거절한 안

- **D-035를 "보유 자산 변경 시 시작월을 이번 달로 다시 잡는다"로 바꾸는 안**: 뜻은 깨끗하지만 D-013·D-032를 뒤집고 계획 버전·그래프 축·`calc_run`까지 번진다. **3주 밖. 폐기.**
- **조건 없이 허용(문구 없음)**: D-035가 막은 위험이 대화 경로로 되살아난다. **폐기.**

---

## CF12-8. 초과 판정과 비교 표시

목표 금액·보유 자산은 **초과 판정(`heldAssets >= goalAmount`)의 두 변수 그 자체**다. 그래서 이번 변경은 네 가지 상태를 만든다.

| 경우 | 지금 | 이번 변경 뒤 |
|---|---|---|
| (A) 미달 계획에서 기존 4필드만 바꿈 | 양쪽 계산, 비교 카드 | 그대로 |
| (B) **초과 계획**에서 목표를 올려 초과를 벗어남 | `current`도 계산하지 않고 `409 ALREADY_EXCEEDED`(D-071) | **정상 비교(비대칭 2칸)** — CF12-8-1 **합의 확정 3-1** |
| (B') 초과 계획에서 목표·보유를 바꾸지 않음, 또는 **올렸는데 여전히 초과** | 409 | **409 유지**(D-071 잔여 범위) |
| (C) 미달 계획에서 목표를 내려 `changed`가 초과 | 생길 수 없었다 | `changed.status = ALREADY_EXCEEDED`, `scenarios: []` — CF12-8-2 |
| (D) 미달 계획에서 목표 금액을 올림/내림 | 생길 수 없었다 | `gapToGoal`·`isAchieved`·`goalReachMonth`가 **양쪽에서 다른 목표선**으로 계산된다 — CF12-8-3 |

### CF12-8-0. internal-calc C2-4 불변식 개정 (확정 — 어느 선택지에서도 필수)

C2-4는 지금 *"`status`는 이 경로의 성공 응답에서 항상 `CALCULATED`… 대화로 목표 금액·보유 자산을 바꿀 수 없으므로(D-040) `changed`도 `CALCULATED`다"* 라고 적는다. (C)만 받아도 깨진다.

- **확정: C2-4 불변식을 개정한다.** `/internal/calc`·F-4 응답 양쪽에서 `current.status`·`changed.status`가 `ALREADY_EXCEEDED`일 수 있고, 그 쪽은 `scenarios: []`다.
- **사실 정정(v2의 과대 확정)**: **"응답에 `status`를 담는다"는 새 작업이 아니다.** `CalcResultView.java:21`에 `status` 필드가 **이미 있고** `InternalCalcResponse.java:21-28`이 그대로 내보낸다. F-4(`ChatComparisonView`)도 같은 `CalcComparison`을 담는다. → **Spring 코드 변경 0.** 남는 일은 **javadoc(`:11`)·계약 문구 수정**과 **소비자 타입에 필드 추가**뿐이다.
- `status`는 소비자가 **문자열을 해석하지 않고 그것만 보고 칸을 고르는** 필드로 정의한다. **별도 `comparable` 플래그는 두지 않는다.**
- **딸림**: `calc.py:_select_for_model`·`_select_side`가 `status`를 모델에 통과시킨다(지금 안 준다). 안 하면 프롬프트 규칙 9가 동작할 수 없다.
- 왜 이렇게 했는가: 소비자가 빈 `scenarios`의 **사유**를 알 수 없으면 카드가 "계산 실패"와 "이미 달성"을 구분할 수 없다.

### CF12-8-1. (B) 초과 계획에서 목표를 올려 초과를 벗어나는 경로 — **합의 확정: 3-1** (전 X-A)

**규칙**
- `current`가 초과이고 `conditionChanges`에 `goalAmount`(2단계에서는 `heldAssets`도)가 **있으며** 해석된 `changed`가 초과가 **아니면** → 정상 비교를 만든다.
- 응답: `current.status = ALREADY_EXCEEDED`, `current.scenarios: []`, `diff.byScenario: []`, `changed`는 정상 계산.
- 카드는 **"현재: 이미 넘었어요 / 바꾼 조건: 계산 결과"의 비대칭 2칸**.
- 그 밖(목표·보유를 바꾸지 않음, 또는 바꿔도 여전히 초과)은 **409 `ALREADY_EXCEEDED` 고정 문장 유지**(D-071 잔여 범위).

**구현 지점**: `CompareConditionsUseCase:88-92` 분기 역전(`changed`를 먼저 해석한 뒤 `current` 초과 + `changed` 비초과면 통과). `CalcEngine`·`CalcComparison.Diff.between`·`buildDisplay`는 **수정 0**(`Diff.between`은 교집합만 담아 `byScenario`가 자연히 비고, `build()`의 시나리오 루프가 0회 돈다).

**왜 3-1인가 (제공자가 v1의 3-2 권고를 철회하고 소비자와 같은 입장으로 옮겼다)**

| 근거 | 재검토 결과 |
|---|---|
| "3-2는 성공 응답 불변식(C2-4)을 안 깬다" | **성립 안 함.** (C)만 받아도 깨진다(CF12-8-0) |
| "3-1은 `agent.py:143·424·441`을 고쳐야 한다" | **틀렸다.** `:143` `_FIXED_COPY_KEYS`는 409 코드→문구 키 매핑이고 409는 그대로 남는다(**수정 0줄**). `:424`·`:441`은 EXPLAIN 모드 planContext 분기라 비교 응답을 안 본다(**수정 0줄**) |
| "프론트 `settledStatus`가 성공 응답의 `ALREADY_EXCEEDED`를 기대하지 않는다" | **틀렸다.** `settledStatus`는 계획 결과(F-3/결과 화면) 상태이고 비교 응답과 무관하다(`planStore.test.ts:157` AC-15) |
| 3-2(비교 없이 확인 → 적용)의 실제 비용 | **DB가 막는다**: `schema.sql:190-191` `ck_cm_recalc`가 `RECALC_RESULT`에 `calc_run_id`를 요구하고(계산을 안 하면 `calc_run`이 없다) `ck_cm_type`(`:184`)에 쓸 타입이 없다. `ANSWER`로 내리면 DB는 되지만 **F-4·F-5가 `RECALC_RESULT`만 받는 계약**(`frontend-api.md:1045, 1085-1086`)과 **D-041**이 막는다 |
| 3-2의 결정타 | **2턴 확인 흐름이 성립하지 않는다.** "바꿀까요?" → "네"의 두 번째 턴에는 숫자도 조건 표현도 없어 `drop_carried_conditions`(`agent.py:228-230`)가 조건을 모두 지우고 `:383`에서 "바꿀 조건이 없습니다" CLARIFY가 된다. 이어받기를 만들면 D-041(누적 금지)을 뒤집는다 |
| 3-1의 Spring 추가분 | **≈0.7일**(분기 역전 0.2 + 초과 쪽 display 0.2 + 계약·fixture·REST Docs 0.3). v1 추정(+1.5일)의 절반 이하 |
| 회귀 범위 | **깨지는 기존 테스트는 `InternalCalcApiTest:240` 한 건.** 나머지 `ALREADY_EXCEEDED` 단언 23곳은 모두 단일 계산(결과 화면·planContext·골든 G3) 경로. 정상 응답의 `status`는 늘 `"CALCULATED"`라 기존 fixture는 키 추가뿐 |
| 제품 | 막다른 길이 풀리고, 사용자가 **숫자를 보고** 적용을 결정한다(D-022 취지) |

> **이 합의는 D-071을 바꾼다 → 합의안의 "사람이 확인할 결정 변경"으로 따로 올린다.**

### CF12-8-2. (C) `changed`가 초과가 되는 경우 (확정)

- `changed.status = ALREADY_EXCEEDED`, `changed.scenarios: []`, `diff.byScenario: []`.
- 카드의 "바꾼 조건" 칸은 **초과 문장**을 쓴다. 초과 **금액은 말하지 않는다**(프롬프트 규칙 9).
- **적용 버튼은 활성.** 사용자가 사실(이미 모았다/목표를 낮췄다)을 계획에 반영할 수 있어야 한다. 적용 후 결과 화면의 초과 전환은 **이미 구현되어 있다**(`settledStatus`, `ResultPage.tsx`, mock `put-plan.200-exceeded.json`, D-072·#52).
- **카드에 예고 한 줄**: 신규 `chat.changedAlreadyExceeded`("이 조건으로 적용하면 이미 목표를 넘은 상태가 돼요"). 자리 값 **없음**(숫자가 없어 `check_numbers` 영향 없음). **모델이 아니라 ai-server가 `changed.status`를 보고 붙인다**(D-073 방식, 모델 준수에 기대지 않는다) + 프론트 카드 정적 표시.
- **거절**: "적용 버튼 비활성 + 적용할 수 없어요"(사용자가 사실을 계획에 반영할 수 없게 된다).

#### CF12-8-2a. 초과 칸의 `heldAssets` display — v2의 모순 해소 (소비자 지적)

- 초과 칸 문장은 자리 값 `{heldAssets}`·`{goalAmount}`를 쓴다. 그런데 `ResultDisplayBuilder.putConditions`는 `isSingleResult`일 때만 `heldAssets`를 만든다. v2는 한편으로 "초과 칸에 `*.heldAssets`를 내린다"고 쓰고 다른 한편 X-B B안에서 "비교 `heldAssets` 노출이 사라져 ≈1일 절감"이라고 썼다 — **둘 다 맞을 수 없다.**
- **확정: 목표 금액만 여는 1단계에서도 "그 쪽 `status`가 `ALREADY_EXCEEDED`면 `conditions.<side>.heldAssets`를 만든다"는 규칙이 들어간다.** B안의 절감은 ≈0.2일 줄어든다.
- **단 초과 칸 문구는 결과 화면 문구 `result.alreadyExceeded`를 재사용하지 않고 `chat.` 계열 신규 키(`chat.cardAlreadyExceeded`)로 한다**(제공자 반박 수용). 이유: `result.alreadyExceeded`(`CopyBook.java:40`)는 결과 화면 문장이라 카드 안에 들어가면 "내 계획 화면으로 간 것 같은" 문장이 되고, 방금 대화로 바꾼 사용자에게 "대화로 바꿔 보세요" 안내가 다시 붙는다.
- `{heldAssets}`를 문장에서 빼는 대안(목표 금액만 인용)은 "가진 자산이 얼마라서 넘었는지"가 안 보여 FR-RES-01과 달라진다 → **거절.**

### CF12-8-3. (D) 목표 금액이 바뀐 비교의 표시 (확정)

1. **display 키를 쪽별로 분리한다(양보 불가). 이름은 `conditions.current.goalAmount` / `conditions.changed.goalAmount`.**
   - **제공자가 자기 안(`current.goalAmount`)을 철회했다.** 근거: `ResultDisplayBuilder.build(input, result, resultPrefix, conditionPrefix)`가 **이미 조건 접두어를 받고** `CompareConditionsUseCase:33-36`에 `CONDITIONS_CURRENT`·`CONDITIONS_CHANGED` 상수가 있어 `putConditions`에 **한 줄**이면 끝난다. 결과 접두어 쪽으로 옮기면 단일 경로의 무접두어 `goalAmount`와 계열이 갈리고 `_CALCULATED_DISPLAY_KEYS`·`_EXCEEDED_DISPLAY_KEYS`와 어긋날 위험이 생겨 **더 비싸다.**
   - 개념 근거: `current.targetMonth`·`current.<G>.*`는 **계산 결과**, `goalAmount`는 **사용자가 말한 조건**이다. 결과 접두어에 조건을 섞지 않는다. 프론트도 조건 행 루프에 키 하나가 늘 뿐이다.
   - **키는 `conditionChanges`에 해당 키가 있을 때만 만든다**(평소 비교 응답 모양을 바꾸지 않는다).
   - **ai-server 비용 0**: 비교 display는 `DISPLAY_KEY`를 거치지 않는다(CF12-4-2 gg0).
2. **목표가 바뀐 비교에서는 무접두어 `goalAmount`를 Spring이 아예 만들지 않는다**(소비자 C-1). 비용은 `build()` 첫 줄에 분기 하나. 이렇게 하면 **조용한 덮어쓰기와 모델의 잘못 인용이 구조적으로 사라진다**(프롬프트 준수에 기대지 않는다). 무접두어 `goalAmount`는 **단일 계산(결과 화면) 경로 전용**이 된다. `prompts.py:30-31` 개정은 안전망으로 그대로 한다.
3. **`achievementChange`(`diff.byScenario[].`)는 그대로 쓴다.** `null`로 숨기지 않는다. 이 필드가 주 사용 사례("목표를 낮추면 달성돼요")의 핵심 정보이고 사용자가 목표를 직접 말했으므로 사실이다.
4. **주의 문구는 코드가 붙인다.** 신규 `chat.goalAmountChangedNote`를 `conditionChanges`에 `goal_amount`가 있을 때 ai-server가 **`check_numbers` 뒤에** 덧붙이고(D-073), 프론트 카드는 F-4 `changedKeys`에 `goalAmount`가 있으면 같은 키를 **정적으로** 보여 준다. 자리: `{currentGoal}`, `{changedGoal}`. 본문 방향: "목표 금액이 {currentGoal}에서 {changedGoal}으로 바뀌어, 달성 여부는 각각 자기 목표 기준이에요."
5. **`diff`에 목표 차이 키(`gapToGoalDelta` 등)를 두지 않는다**(C2-5 유지). 대신 프롬프트에 "이전 값을 빼서 새 숫자를 만들지 않는다"를 목표 변경 비교용으로 한 번 더 못 박는다.
6. 각 시나리오의 `isAchieved`·`gapToGoal`은 **각자 자기 목표 기준**이고 이미 `<side>.<S>.gapToGoal`로 존재한다.
- 왜 이렇게 했는가: 목표선이 움직인 비교를 "좋아졌다"로 읽히게 하면 금융 조언으로서 사용자를 오해시킨다. 정보는 남기고 해석만 코드가 고정한다.

### CF12-8-4. 비대칭 비교에 필요한 display 키 전수 목록 (소비자 C-1, 확정)

`S` = `current` | `changed`.

| 키 | 언제 | 쓰는 곳 |
|---|---|---|
| `conditions.S.goalAmount` | `conditionChanges`에 `goalAmount`가 있을 때 **양쪽 다** | 카드 "목표 금액" 행, `chat.goalAmountChangedNote`의 `{currentGoal}`·`{changedGoal}`, 초과 칸 문장의 `{goalAmount}` |
| `conditions.S.heldAssets` | **그 쪽 `status`가 `ALREADY_EXCEEDED`일 때(1단계에서도 필수)**, 2단계에서는 `conditionChanges`에 `heldAssets`가 있을 때도 | 초과 칸 문장 `chat.cardAlreadyExceeded`의 `{heldAssets}` |
| `S.<G>.afterTaxAsset·principal·afterTaxGain·gapToGoal`, `S.<G>.goalReachMonth`(달성 시), `S.targetMonth` | **그 쪽 `status = CALCULATED`일 때만**(초과 칸은 `scenarios: []`라 이미 안 만들어진다) | 기존 |
| `conditions.S.monthlySavingAmount·targetPeriodMonths·savingsRatioPct·savingsRateInputPct` | 기존 그대로(양쪽 항상) | 카드 조건 행 |
| `diff.<G>.afterTaxAssetDelta·principalDelta·afterTaxGainDelta` | **양쪽 `CALCULATED`일 때만** | 기존 |
| 무접두어 `goalAmount` | **목표가 바뀐 비교에서는 만들지 않는다** | — |
| `calcStartMonth`(무접두어, 비교에도) | **2단계(HELD)** | `chat.heldAssetsBasis`의 `{calcStartMonth}` |

- **빠진 정보는 없다**: 쪽별 `status`, `scenarios: []`, `diff.byScenario: []`, 위 키로 비대칭 카드를 다 그린다. `comparable` 플래그 불필요.
- `calc.py:_check_display`(`:105-114`)는 `display`가 **비면** `CALC_DISPLAY_MISSING`이다. 양쪽이 초과여도 목표·보유 키가 있어 비지 않으므로 지금 코드로 안전하지만, 이 가정을 **fake 테스트 1개**("한쪽 초과 + display에 시나리오 키 없음")로 고정한다.

---

## CF12-9. ai-server의 "두 겹" 풀기 (확정)

internal-calc C3-2는 목표 금액 변경을 **두 겹으로 막는다**고 적는다: (1) 도구 스키마 4키 + 프롬프트 고정 문장, (2) Spring `FIELD_NOT_CHANGEABLE`. **둘 다 풀고, 대상을 목표 종류·기존 납입액(+1단계에서는 보유 자산)으로 옮긴다.**

### CF12-9-1. 변경 지점

CF12-4-2의 q~gg0 전체. **프롬프트 변경 범위(확정): `prompts.py:7-8, 18, 21-27, 30-31, 53-54, 70, 75` + 규칙 9 쪽별 재작성 + 신규 규칙(단위·역할).** 한 군데라도 남으면 모델이 옛 고정 문장으로 답하는 회귀가 난다(예: `:23`이 그대로면 "3,000만원 모았어요"에 "입력 수정에서…"로 답한다. 단 **X-B가 B안이면 `:23`의 보유 자산 부분은 의도적으로 남긴다** — CF12-4-2 x).

`drop_carried_conditions`(`agent.py:204-230`)와 `calc.py`의 `status` 통과는 **반드시 같은 묶음**이다.

### CF12-9-2. 고정 문장 테스트는 삭제하지 않고 대상을 바꿔 유지한다 (확정)

고정 문장은 D-056·CP-05의 약속(모델이 짓지 않음)이다. 그냥 지우면 **"대화로 못 바꾸는 요청도 `ANSWER`이고 `OUT_OF_SCOPE`가 아니다"는 보호가 같이 사라진다.**

| 테스트 | 처리 |
|---|---|
| `tests/test_agent_tools.py:22` `REMOVED_KEYS`, `:98` "4키뿐" | `goal_amount`를 빼고(1단계) `existing_monthly_contribution`(+B안이면 `held_assets`)만 남긴 **5(6)키 단언**으로 교체 |
| `tests/test_agent_tools.py:119-126`, `:130-141` | **대상을 목표 종류 발화로 교체.** 새로 "목표 금액 발화는 `recalculate`를 부른다" 테스트 추가 |
| `tests/test_agent_tools.py:143-150` | 재사용한 새 전용 문구(목표 종류·기존 납입액) 기준으로 |
| `tests/test_out_of_scope.py:119-125`("목표 금액이 없다" → **뒤집힌다**), `:188-260` AC-4 | 대상 교체. **`:230`(ANSWER에 OUT_OF_SCOPE 치환이 번지지 않음)은 그대로 둔다** |
| `tests/test_copy.py:37, 100-102, 135, 208-221` | 문구 본문 하드코딩이 문구 개정과 **같은 PR**에서 바뀌어야 한다 |
| `tests/test_calc_client.py:269` + `docs/api/examples/.../field-not-changeable-response.json` | fixture `field: goalAmount` → `goalType` 등 |
| **`tests/test_no_accumulate.py:337-372` 표 테스트** | **새 행 추가**: ① 목표·보유 발화가 history 있는 대화에서 **지워지지 않는다**(CF12-4-2a의 두 사례 모두) ② 목표 금액 발화의 금액이 **월 저축액으로 오인되지 않는다** |

회귀 위험이 가장 큰 두 곳: `test_copy.py`의 문구 본문 단언(함께 안 바뀌면 CI 깨짐)과 `test_no_accumulate.py` 표(행을 안 더하면 **테스트가 통과한 채로 새 키가 조용히 지워진다**).

### CF12-9-3. 단위(만원 ↔ 원)와 역할 혼동 (확정)

실제로 통과하는 구멍:

| 발화 | 모델이 잘못 낸 값 | 서버 결과 |
|---|---|---|
| 목표 1억 | `10000` | **통과**, 목표 1만원 |
| 목표 1억 5천만원 | `15000` | **통과**, 목표 1.5만원 |
| 목표 2,500만원 | `250000000`(×10 과환산) | **통과**, 2.5억 |
| 목표 2,500만원 | `2500` | 걸림(`OUT_OF_RANGE`, `min 10000`) |
| 보유 자산 3,000만원 | `3000` / `300000000` | **통과**(`min 0` / `max 1e10`) |

**세 겹 대응:**

| 겹 | 내용 |
|---|---|
| (a) 프롬프트 | `## 숫자`에 두 줄. ① "만·억 단위는 원으로 바꿔 인자에 넣는다. 단위가 없거나 모호한 금액은 계산하지 말고 되묻는다(CLARIFY)." ② **역할 규칙**: "목표·모으려는 → 목표 금액, 이미·지금·모아둔·가진 → 보유 자산, 매달·월 → 월 저축액. 역할 단어가 없으면 되묻는다" |
| (b) **추출 후 결정적 대조** | 새 함수 `check_amount_units(text, changes)`를 `drop_carried_conditions` 옆에 둔다. **새 정규식을 처음부터 쓰지 말고 기존 `_NUMBER`·`_KO_MAN`·`_THOUSANDS_COMMA`(`agent.py:176-187`)를 재사용한다**(제공자 권고 — 한글 수사도 이미 꽤 넓게 세므로 건너뛰는 범위가 좁아져 **더 안전하고 비용도 준다**). 추출된 값이 발화 후보 집합에 없으면 Spring을 부르지 않고 `CLARIFY`. **1단계에서는 `goal_amount`만 대조하고 월 저축액은 넣지 않는다**(기존 fake 테스트의 "50만 → 500000" 류가 CLARIFY로 바뀌는 회귀 방지). `held_assets`는 **숫자 토큰이 없어도 건너뛰지 않고 CLARIFY**(CF12-7-2 8) |
| (c) 확인 문장 + 카드 | 목표·보유 금액 display를 카드와 답변에 그대로 보여 준다. 적용은 D-022대로 버튼이므로 **카드가 두 번째 확인**이다 |

- **하지 않는 것(확정)**: **단위 자동 보정 금지**(`2500` → `25000000`으로 고쳐 주지 않는다 — PR-04 정면 위반). **범위 검증은 Spring 한 곳(D-033) 유지**, 서버 쪽 비정상 값 경고 규칙도 두지 않는다(새 판정 규칙이고 3주 밖). `check_amount_units`는 "모델 출력 ↔ 발화 대조"이고 **범위 검증이 아니므로** 중복이 아니다.
- **기록할 것(제공자 요청)**: Spring은 `check_amount_units`가 돌지 않은 값도 그대로 받는다(공유 비밀 헤더만 보는 내부 경로). 즉 **단위 사고의 최종 방어선은 (c) 카드 확인뿐**이다. 제공자가 더 할 수 있는 일은 없다.
- **상대 표현은 절대값 되묻기(D-059)를 늘어난 조건 수로 넓힌다.** "목표를 조금 줄이면", "목표를 N만원 줄이면"은 `CLARIFY`.
- **새 위험은 금액 세 개(목표·보유·월 저축액) 사이의 역할 혼동**이다: "300만원 모으려면"이 월 저축액 300만원(범위 안)이 되면 **조용히 틀린다**.

### CF12-9-4. FR-AI-02 구멍 점검 (확정)

| # | 구멍 | 막는 방법 |
|---|---|---|
| 1 | 모델이 두 목표를 빼거나 두 `gapToGoal`을 뺀다 | `diff`에 목표 차이 키를 두지 않고(C2-5) **프롬프트로 금지**. 말하려면 양쪽 display만 인용 |
| 2 | 단위 환산 | CF12-9-3 (a)+(b)로 **대조**. 값을 코드가 고쳐 주지 않는다 |
| 3 | 보유 자산을 모델이 가공해 말한다 | `chat.heldAssetsBasis`는 **코드가 붙인다** + 프롬프트에 "보유 자산 값을 가공하지 않는다" 한 줄(2단계) |
| 4 | 초과를 벗어난 카드에서 필요 월 저축액·초과 금액을 모델이 계산 | 기존 규칙(초과 금액 미언급, `requiredMonthlySaving` 미노출) 유지를 **테스트로 고정**. 규칙 9를 쪽별로 재작성(CF12-4-2 aa) |
| 5 | `drop_carried_conditions`가 값을 지운다/월 저축액으로 오인한다 | `_GOAL`·`_HELD` 정규식 + `test_no_accumulate.py` 새 행(CF12-4-2a) |

소비자가 새로 필요로 하는 계산 값은 **없다**.

---

## CF12-10. 저장·적용·DB (확정 — DB 스키마 변경 0)

| 점검 | 결과 |
|---|---|
| `plan_version` 컬럼 | `schema.sql:73` `goal_amount BIGINT NOT NULL`, `:76` `held_assets BIGINT NOT NULL DEFAULT 0`이 **이미 있다**(제약 `ck_pv_goal_amount`·`ck_pv_amounts` 포함) → **스키마 변경 0** |
| `source` CHECK | `schema.sql:91`에 `'CHAT'`이 **이미 있다** |
| 적용 `PlanService.merge:202-216` | `firstNonNull` 2줄. 그 뒤 `inputValidator.validate(merged)`(`:138`)가 범위를 다시 검사 → 방어선 이미 있음 |
| 되돌리기 `undo:159-179`·`copyVersion` | `plan_version` **전 컬럼 복사** → **추가 작업 없음**(D-068) |
| 새 버전·낙관적 락 | `apply`는 INSERT + `replaceCurrent(… expectedRevision)` → 동일 |
| `calc_run` | `plan_version_id`와 데이터 버전만 남긴다(ADR-002). 조건 값은 `chat_message.condition_changes`에 → **스키마 변경 없음** |
| 초과 "캐시" | 없다(`CalcInput.hasExceededGoal()` 매번 계산) → 적용 후 결과 화면이 자동 전환 |
| `STALE_COMPARISON`·`PLAN_CHANGED` | 변화 없음(D-069, 초과 전환은 D-072) |
| 옛 메시지 호환 | 옛 `condition_changes`는 새 허용 키의 부분집합이라 영향 없다 |
| F-4 범위 검사 | F-4는 범위 검사를 하지 않는다(타입 변환만). ai-server는 Spring 422를 통과한 값만 저장(`agent.py:386-387`) |
| F-4 `conditions` 행 | "고정 4키 순서"(C12b-6) → **5(6)행**. 프론트 행 레이블·순서 고정 목록과 목 JSON이 같이 바뀐다 |
| 모듈 경계 | 새 타입 없음. `calc → plan` 단방향 유지 → `ModularityTests` 통과 예상. `calc/package-info.java` 공개 API 설명 한 줄 갱신(display 키) |
| ADR-002·인증 | 충돌 없음. `/internal/**`는 공유 비밀 헤더 그대로 |
| 오류 코드 | **새 오류 코드를 만들지 않는다.** `ALREADY_EXCEEDED`가 409와 200 `status` 양쪽에 존재하지만 **두 경로는 분리되어 있다**(409는 `CalcRejected` → `_FIXED_COPY_KEYS`, 200의 `status`는 `_select_side` 통과). 소비자는 문자열을 해석하지 않는다 |

### CF12-10-1. chat 저장에서 모르는 키를 만났을 때 — **합의 확정: A) 저장 실패** (전 X-E)

**사실 정정**: v2가 "현상"으로 적은 **"chat 리스너의 4키 고정 맵"은 코드에 없다**(CF12-4-3 gg). 따라서 이것은 "기존 동작을 바꾸는 일"이 아니라 **"아직 안 쓴 코드의 설계를 정하는 일"** 이고, 비용 ≈0, 소유는 **B팀(#44·#45·#128)** 이다.

**확정 규칙**

> chat 리스너가 `condition_changes`를 camelCase로 바꿀 때 **맵에 없는 키가 하나라도 있으면 그 키만 버리지 않고 변환을 실패로 보고, 해당 ASSISTANT 메시지를 `FAILED`로 남긴다.** `RECALC_RESULT`로 저장하지 않는다. **턴 전체 500이 아니다.** 사용자에게는 **기존 `chat.failed`**("답변을 만들지 못했어요. 잠시 후 다시 질문해 주세요", `copy.ko.yml:31`, FR-AI-04) 안내가 나가고 **새 문구 키는 만들지 않는다.** USER 질문 메시지는 이미 저장되어 있어 대화 기록이 끊기지 않는다.

- **근거(트랜잭션)**: `chat/package-info.java`가 "메시지를 영속 저장하고 ai-server를 **비동기로** 호출한다. `ChatAnswerRequested` → 호출 후 **PENDING을 COMPLETED/FAILED로** 바꾼다"로 모듈 구조를 못 박아 두었다. 대화는 F-1이 202 + 폴링이라 **"500을 보는" 사용자가 없다.** 프론트는 이미 `FAILED`·`pollingFailed`를 처리한다.
- **근거(일관성)**: 읽기 쪽은 이미 fail-closed다 — `PlanContextProviderImpl.toOverride:168-172`가 허용 밖 키에 `IllegalArgumentException`을 던지고 #44 본문이 "허용 키 밖이 저장된 메시지는 `500 INTERNAL_ERROR`"로 계약에 담고 있다. 쓰기만 "조용히 버린다"로 두면 **쓰기는 통과·읽기는 500**이라는 가장 나쁜 짝이 된다.
- **`condition_changes`만 비우는 부분 저장은 양보 불가로 반대**(제공자): `ck_cm_recalc`(`schema.sql:190`)가 `RECALC_RESULT`에 `condition_changes NOT NULL`을 요구하므로 **DB가 거절**하고 "애플리케이션이 성공했다고 믿는 저장이 DB에서 터지는" 모양이 된다. **메시지 단위 FAILED가 유일하게 깨끗하다.**
- 모르는 키가 닿는 경우는 **배포 순서 위반(ai-server가 Spring보다 먼저)** 뿐이다(ai-server는 `ConditionChanges`가 `extra="forbid"`라 스스로 내지 않는다) → "시끄럽게 실패"가 맞다.
- **한계(문서에 적는다)**: 재시도해도 Spring 배포 전에는 같은 결과다. "잠시 후"가 거짓일 수 있지만 운영 사고 상황이라 새 문구까지 만들지 않는다.
- **#44·#45·#128 본문에 "맵은 처음부터 5(6)키, 모르는 키는 메시지 FAILED"를 넣는다.**

---

## CF12-11. 배포 순서 (확정)

> **Spring(CF12-4-1 전체: yml·`ConditionOverride`·컨트롤러 Set·`validate`·`ConditionResolver`·`merge`·`PlanContextProviderImpl`·display) → ai-server(5·6키 스키마·도구·프롬프트·`drop_carried_conditions`·`status` 통과) → 프론트(카드·행·목 JSON)**

- **역순이면 F-4 비교 조회가 전부 500이 된다**(`PlanContextProviderImpl.CHANGEABLE_KEYS`가 4키인데 6키가 저장되면 `IllegalArgumentException`).
- ai-server를 **나중에** 켜면 중간 상태가 모두 fail-closed다(`/internal/calc`가 `FIELD_NOT_CHANGEABLE` 고정 문장으로 안전하게 거절).
- **`PlanService.merge`·`toOverride` 배선 없이 ai-server를 켜지 않는다.**
- **(추가 — 소비자 보강)** **문구 본문 개정(`chat.alreadyExceeded`·`chat.unchangeableCondition`·`result.alreadyExceeded`·프론트 `features/chat/copy.ts:5`·`shared/copy/copy.ts:30`)은 ai-server가 새 키를 켜는 PR과 같은 날 함께 나간다.** 문구가 "대화로 목표 금액을 바꿔 보세요"를 먼저 말하면(Spring `CopyBook` 선배포) **가리킨 곳이 아직 안 된다.** 프론트·ai-server의 상대 순서는 무관하다.
- **(위험 이동)** gg 정정으로 "ai-server가 먼저 6키를 저장해 버리는" 중간 상태는 지금 일어날 수 없다(저장 코드가 없다). 위험은 **"#44·#45·#128이 4키로 먼저 완성되고 그 뒤 ai-server가 새 키를 보내는"** 쪽으로 옮겨 간다 → 그 세 Issue 본문에 6(5)키·FAILED를 처음부터 넣는다(CF12-10-1).
- 왜 이렇게 했는가: 어느 중간 배포 상태에서도 "조용한 불일치"가 아니라 "명시적 거절"이 되게 한다.

### CF12-11-1. 선행: moeun **#132** (남은 쟁점 X-F)

- #132 `[calc] 대화 조건 변환 코드를 한 곳으로 모으기`가 `InternalCalcController.CHANGEABLE_KEYS`(e)·`PlanContextProviderImpl.CHANGEABLE_KEYS`(i)·chat 변환(gg)의 **중복 3곳을 `calc.application.ConditionChanges` 한 곳으로 모으는 중**이다. 먼저 머지되면 이번 변경의 e·i·gg가 **한 파일 한 곳**으로 줄어든다(≈0.3일 절감).
- **현황(2026-11-20 `gh` 대조)**: #132 **OPEN**, `status:in-progress`, **열린 PR 0건**, `origin`에 132 관련 브랜치 없음, `calc/application/ConditionChanges.java` **아직 없음**. 즉 **작업물이 아직 나오지 않았다.**
- 제공자는 **선행 요구를 유지**하되(#132 본문 수용 기준이 "`/internal/calc` 응답이 바뀌지 않는다"라 4키 기준으로 끝내야 리뷰가 쉽다), **늦어지면 "#132를 이번 변경에 흡수"** 를 대안으로 제시한다. **"각각 고치고 나중에 합치는" 안만 반대**(세 곳을 넓힌 뒤 합치면 "세 곳의 동작이 서로 다르지 않다"를 증명하는 테스트를 두 번 쓴다).
- **언제 흡수로 전환할지는 사람이 정한다 → 쟁점 X-F.**

---

## CF12-12. 계약 문서별 "바꿀 줄" 표

### CF12-12-1. `docs/design/contracts/internal-calc.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 65 | C2-2 | "허용 키 (D-040, CP-07 — **4개뿐**)" → "허용 키 (새 D-번호, CP-07 — **5개**(X-B B안) / **6개**(A안))" + `goalAmount`(·`heldAssets`) 행 추가. min/max는 `fields` 그대로 |
| 74 | C2-2 | 예시 키를 **여전히 허용 밖인 키**(`goalType`, `existingMonthlyContribution`)로 교체. 이유 문장 유지 |
| 83 | C2-2 검사 3 | "허용 4개 밖의 키(`goalAmount`, `heldAssets`, …)" → "허용 **5(6)개** 밖의 키(`goalType`, `goalCustomName`, `existingMonthlyContribution`, 오타 키 등)" |
| 88 | C2-2 검사 8 | "현재 계획이 이미 목표 초과 → 409(`current`도 계산하지 않음)" → **CF12-8-1 3-1 규칙으로 재작성**(바꿔서 초과를 벗어나면 정상 비교, 그 밖은 409) |
| 101 | C2-3 | **고치지 않는다**(k 제외 — `ConditionValues`는 4필드 유지). 단 "쪽별 목표 금액 raw 값은 `CalcResultView.goalAmount`에 이미 있다"는 메모 한 줄 |
| 115·132 | C2-4 | **전면 개정(CF12-8-0).** `current`·`changed` 각각 `status`(이미 응답에 있다), `ALREADY_EXCEEDED`면 그 쪽 `scenarios: []`. "늘 `CALCULATED`" 문장 삭제 |
| 139~158 | C2-5 `diff` | 한쪽이 `ALREADY_EXCEEDED`면 `byScenario: []`. `comparable` 플래그 없음, 목표 차이 키 없음 |
| 159~192 | C2-6 `display` | ① **쪽별 목표 금액 키**(`conditions.current.goalAmount`/`conditions.changed.goalAmount`, `conditionChanges`에 있을 때만) ② **초과인 쪽에 `conditions.<side>.heldAssets`**(1단계에도) ③ 무접두어 `goalAmount`는 **단일 계산 경로 전용**이며 목표가 바뀐 비교에서는 **만들지 않는다** ④ `calcStartMonth`·`assumptions`의 전면 해제와 **C2-6 의도 규칙 개정은 2단계**(X-B A안이면 이번) |
| 248 | C3-2 | 409 `ALREADY_EXCEEDED` 행 → 3-1 규칙 반영 |
| 253 | C3-2 아래 | "목표 금액 변경은 두 겹으로 막는다" → **대상 교체**: "목표 **종류**·기존 납입액(·1단계에서는 보유 자산)" |
| 254 | C3-2 아래 | "409로 둔 이유: 대화로 목표·보유를 못 바꾸므로 `changed`도 반드시 초과라…" → **근거가 사라진다. 3-1 기준으로 재작성** |
| 259 | C3-3 | "허용 키는 `rules.yml › change-paths.CHAT.fields`(4개)" → (5·6개) + **메모: `InternalCalcController.CHANGEABLE_KEYS`는 yml을 읽지 않는다** |
| 576~596 | 부록 A-4 | `422 FIELD_NOT_CHANGEABLE` 예시 키 교체 + `contract/internal-calc/a4-response.json` |
| 597~618 | 부록 A-5 | **기존 409 예시를 지우지 않고** "바꿔도 여전히 초과" 사례로 **의미 재배치**하고, "`current` 초과 + `changed` 정상"의 **200 성공 예시를 별 파일로 추가**(`InternalCalcApiTest:240`도 그 사례로 교체) |

### CF12-12-2. `docs/design/contracts/frontend-api-chat.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 219·221 | C12b-6 | "허용 4키"류 표현 정정. **F-4 `conditions` 5(6)행**과 **각 칸 `status`** 추가. "허용 밖 키가 저장된 메시지는 F-4가 500"은 유지(대상만 좁아짐) |
| 292 | C12b-7-1 검사 6 | 유지. **메모**: `validate(ConditionOverride)`가 4필드 레코드라 2필드 추가 필요(c·d) |
| 307~319 | C12b-7-2 | `FIELD_NOT_CHANGEABLE` 프론트 동작 유지 |
| 650·657 | C12b-12 | 목 `post-apply.422-field-not-changeable.json`의 `field` 교체(실제 파일도) |
| 685·697 | C12b-14 | "chat 리스너(#41)가 4키 고정 맵으로 저장" → **"저장 코드는 아직 없다(#44·#45·#128이 쓴다). 맵은 처음부터 5(6)키, 모르는 키는 그 ASSISTANT 메시지를 `FAILED`로 남기고 `RECALC_RESULT`로 저장하지 않는다"**(CF12-10-1) |
| 698 | C12b-14 | "`ConditionChanges`가 7키라 D-040의 4키와 다르다, #21 선행" → "이미 4키로 축소됨(#21 완료)"으로 정정 + "#21을 5(6)키로 재확장"을 후속으로 |
| 742·762 | C12b-18 | H-3b·H-14 후속을 새 키 수 기준으로 재확인 |

### CF12-12-3. `docs/design/contracts/plan-context.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 14 | 머리말 | **D-071 변경**: "초과 계획의 대화 재계산은 고정 문장, 비교·적용 없음" → **"목표(·보유)를 바꾸지 않거나 바꿔도 여전히 초과면 고정 문장"** |
| 233 | C1a-9 검사 4 | `mode=EXPLAIN` + `ALREADY_EXCEEDED` → LLM 없이 `chat.alreadyExceeded`. **유지**(EXPLAIN은 범위 밖, `agent.py:424·441` 수정 0) |
| 282 | C1a-10 규칙 7 | "대화로 바꿀 수 있는 **네 조건**"(D-059) → "**다섯(여섯) 조건**" |
| **284** | C1a-10 규칙 9 | ① 문구를 **"대화로 목표 금액을 바꿔 볼 수 있어요"** 로(막다른 길 제거의 핵심 한 줄) ② **규칙 9를 쪽별로 다시 쓴다**(`prompts.py:53-54`가 단일 결과 기준이라 비대칭 2칸에서 어느 쪽 `status`를 보는지 애매하다 — 제공자 재검토) ③ "한쪽이 초과인 비교에서는 그쪽은 초과 사실만 말하고 비교 문장을 만들지 않는다" |
| 289·413 | G-3 / D-10 | "`SYSTEM_PROMPT`를 D-040 4개 조건으로 고치는 일은 #21 범위" → 5(6)개 조건 |
| 348 | C1a-11 | "초과 계획에서도 `conditions.heldAssets` display를 남긴다" 유지(**더 필요해진다** — CF12-8-2a) |
| 354 | C1a-12 문구표 | `chat.alreadyExceeded` 본문 개정(CF12-13) |

### CF12-12-4. `docs/design/contracts/frontend-api-plan.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 303~ | C12a-5-5 | 범위 수치 **변경 없음.** "이 행이 이제 대화·비교 경로에도 쓰인다" 한 줄 |
| 524 | C12a-7 | 초과 안내 `result.alreadyExceeded`의 목표 수정 안내 대상을 **대화**로. 프론트 복제본 2곳 동기 |
| 527 | C12a-7 | `input.heldAssetsRecheck`(D-035) 유지 + **2단계에서 대화 경로에도 필요**해진다는 참조(CF12-7-2) |
| 613~618 | C12a-9 | P-6 `POST /api/plan/apply` 요청 모양을 **5(6)키 기준**이라는 한 줄 |
| 633 | C12a-10 | 422 `FIELD_NOT_CHANGEABLE`(P-6) 유지(대상만 좁아짐) |

### CF12-12-5. `docs/design/b-team-contracts.md`

| 줄 | 절 ID | 바꿀 내용 |
|---|---|---|
| 93 | C-2 | "필드는 4개로 줄임 — D-040" → "**필드 5(6)개**(새 D-번호, D-040 대체)" |
| 101 | C-2 | 허용 키 목록에 `goalAmount`(·`heldAssets`) 추가 |
| 141 | C-3 | "422 `FIELD_NOT_CHANGEABLE` \| 대화로 못 바꾸는 조건(**목표 금액 등**) \| … (D-040)" → "대화로 못 바꾸는 조건(**목표 종류·기존 납입액 등**) \| `ANSWER` + `chat.unchangeableCondition`(D-056)". *이 줄은 D-056 이전 서술이라 이미 낡았다* |
| 143 | C-3 | 409 `ALREADY_EXCEEDED` "계산 없이 안내" → 3-1 규칙 반영 |

### CF12-12-6. `docs/design/alignment.md`

| 줄 | 바꿀 내용 |
|---|---|
| 26 | 불일치 2번("D-040은 4개, moeun은 7개 → moeun 맞춤")을 **해소 이력**으로 정리 + 새 결정으로 갱신 |
| 58 | 같은 내용 상세 행을 새 키 수 기준으로 다시 씀 |

### CF12-12-7. `../moeun` 사본 — 이 repo에서 고치지 않는다 (목록만)

| 파일 | 고칠 절 |
|---|---|
| `moeun/docs/api/internal-calc.md` | C2-2(허용 키·검사 3·8), **C2-4**, C2-5, C2-6, C3-2, C3-3, 부록 A-4·A-5. **C2-3은 고치지 않는다** |
| `moeun/docs/api/frontend-api-chat.md` | C12b-6, C12b-7-1, C12b-12, **C12b-14**(저장 코드 없음 + 모르는 키 FAILED) |
| `moeun/docs/api/plan-context.md` | C1a-9, C1a-10(규칙 7·**9 쪽별 재작성**), C1a-11, C1a-12 |
| `moeun/docs/api/frontend-api-plan.md` | C12a-5-5, C12a-7, C12a-9 |
| `moeun/ai-server/README.md` | `recalculate` 도구 설명(4키 → 5·6키), 프롬프트 범위 안내 |
| `moeun/docs/api/examples/.../field-not-changeable-response.json` | `field` 값 |
| `moeun/backend/src/test/resources/contract/internal-calc/a4-response.json` | `field: "goalAmount"` → 교체 |
| `moeun/frontend/src/mocks/chat/post-apply.422-field-not-changeable.json` | `errors[].field` |
| `moeun/frontend/src/mocks/README.md` | 목 개수·설명 |

---

## CF12-13. 문구표(#18) 신규·개정 키 목록 (확정 — 소비자 C-7로 재확정)

### 1단계 신규 4

| 키 | 용도 | 자리 | 붙이는 주체 |
|---|---|---|---|
| `condition.goalAmount` | 조건 이름(F-4 행 레이블, 범위 밖 안내 열거) | — | 코드(`copy.py:93` `_CONDITION_CODES`) |
| `chat.goalAmountChangedNote` | 목표가 바뀐 비교의 주의 문구 | `{currentGoal}`, `{changedGoal}` | ai-server가 `check_numbers` **뒤**에 덧붙임 + 프론트 카드 정적 표시 |
| `chat.changedAlreadyExceeded` | "이 조건으로 적용하면 이미 목표를 넘은 상태가 돼요" | **없음**(숫자 없음 → `check_numbers` 영향 없음) | **ai-server가 `changed.status`를 보고 붙인다**(모델 아님, D-073) + 프론트 카드 |
| `chat.cardAlreadyExceeded` | **카드의 초과 칸**(양쪽 어느 쪽이든). 안내 없이 사실만 | `{heldAssets}`, `{goalAmount}` | 프론트 카드 정적 표시. **`result.alreadyExceeded` 재사용 금지**(CF12-8-2a) |

### 2단계 신규 2

| 키 | 자리 |
|---|---|
| `condition.heldAssets` | — |
| `chat.heldAssetsBasis` | `{calcStartMonth}` |

### 개정 3

| 키 | 개정 내용 |
|---|---|
| `chat.alreadyExceeded` | **409 경로만 맡는다**: (i) 초과 계획에서 목표·보유를 바꾸지 않는 변경, (ii) 목표를 올렸는데 **여전히 초과**. 한 문장으로 둘 다 받는다 — **"이미 가진 자산이 목표 금액을 넘었어요. 대화로 목표 금액을 더 높게 바꿔 볼 수 있어요."**("더 높게"가 (ii)를 받는다). **"적용하면 초과"는 200 안의 `changed.status`라 경로가 달라 `chat.changedAlreadyExceeded`가 맡는다 → 키를 나눌 필요가 없다.** `ChatWindow` 고정 문장(D-063)과 `features/chat/copy.ts:5` 복제본도 같은 본문으로 맞춘다 |
| `result.alreadyExceeded` | 안내 대상을 입력 수정 → **대화**로. 자리 `{heldAssets}`·`{goalAmount}` 유지 |
| `chat.unchangeableCondition` | **X-B에 종속.** **B안(1단계 목표 금액만)이면 "보유 자산은 입력 수정에서 바꿀 수 있어요"를 유지한다** — 보유 자산은 여전히 입력 수정으로만 바꾸므로 빼면 **막다른 길이 새로 생긴다**(v2가 "입력 수정에서를 뺀다"고 한 것은 B안에서 **틀렸다**). 1단계 본문: "목표 종류·기존 납입액은 여기서 바꿀 수 없어요. 보유 자산은 입력 수정에서 바꿀 수 있어요." **A안(둘 다)이면** 대상이 목표 종류·기존 납입액뿐이라 "여기서는 바꿀 수 없어요"로 끝낸다 |

- **동기화 대상**: `CopyBook.java`(키 목록), ai-server `tests/test_copy.py`(본문 하드코딩), 프론트 `shared/copy/copy.ts:30`·`features/chat/copy.ts:5`. **문구 본문과 테스트는 같은 PR에서 바꾸고, ai-server 활성화와 같은 날 배포한다**(CF12-11).
- `GOAL_AMOUNT_COPY`(`prompts.py:7-8`) 상수는 **삭제하지 않고** 목표 종류·기존 납입액 전용 문구로 재사용한다.

---

## CF12-14. SRS 영향 행

| ID | 줄 | 바꿀 내용 | 상태 영향 |
|---|---|---|---|
| **CP-07** | 26 | "대화·비교로 바꿀 수 있는 조건은 **5개**(X-B B안) 또는 **6개**(A안). 목표 종류·기존 납입액은 대화로 바꾸지 않는다. 한 번에 바꾸는 개수 상한은 경로별 `rules.yml`(CHAT·COMPARE는 6)" | **확정 → 확정(개정)**. 출처에 새 D-번호, D-040은 대체 표기 |
| **FR-AI-06** | 141~ | 예외 수용 기준의 **대상을 목표 종류·기존 납입액(+B안이면 보유 자산)으로 교체**. 목표 금액은 정상 인식 시나리오로 이동. **단위·역할 혼동 수용 기준 추가**(CF12-9-3 a·b). `drop_carried_conditions`가 새 키를 지우지 않는다는 수용 기준 추가(CF12-4-2a의 두 사례). D-059 "네 조건"→"다섯(여섯) 조건" | 수용 기준 다수 수정 |
| **FR-CMP-02** | 45, 241~ | "**5(6)개 중 하나 이상**". 목표가 바뀐 비교의 표시 규칙(CF12-8-3)·`changed` 초과(CF12-8-2)·**비대칭 2칸**(CF12-8-1) 수용 기준 추가. 양쪽 `status`로 칸을 고른다. **Should 그대로**(COMPARE는 허용만 열고 프론트 비교 영역은 만들지 않는다) | 부분확정 유지 |
| **FR-RES-01** | 183~ | 초과 안내를 **대화로** 돌린다 + **"초과 계획에서 대화로 목표 금액을 올려 초과를 벗어난다"** 수용 기준 추가(3-1) | 수용 기준 추가·수정 |
| **FR-AI-01** | — | 3-1 기준으로 재작성(**D-071 변경**) | D-071 변경 |
| **FR-INP-03** | — | 목표 금액: "대화로도 바꿀 수 있다" 참조 한 줄. 범위 수치 그대로 | 비고만 |
| **FR-INP-05** | — | 보유 자산: **X-B A안이면** "대화로 바꿀 때도 같은 기준 안내"(D-035 범위 확장). **B안이면 변경 없음** | X-B에 종속 |
| **FR-INP-11** | — | 변경 없음. '입력 수정' 버튼 제거가 결정되면 이 행의 운명을 따로 묻는다(범위 밖) | — |
| FR-PLAN-03·04 | — | 적용이 5(6)필드를 병합(`PlanService.merge`) — 수용 기준에 필드 추가. 되돌리기는 전 컬럼 복사라 추가 없음 | 수용 기준 보강 |
| FR-ALT-02 | — | **변경 없음**(`ALTERNATIVE` 3필드·max 1 유지) | — |

---

## CF12-15. 후속 작업 표

> Issue 상태는 제공자가 `gh`로 대조한 2026-11-20 값이다. **#53·#132·#44·#45·#128이 OPEN, #10·#17·#18·#21·#25·#32·#33·#41·#51·#78이 CLOSED.** 처리 방식(reopen/신규/본문 수정)은 **X-D 혼합 합의**를 따르되 reopen 대상은 **#21·#18 중심**이다. 자세한 표는 합의안 §후속 작업.

| T | 작업 | 담당 | Issue | 상태 | 선행 |
|---|---|---|---|---|---|
| T-1 | `rules.yml` CHAT·COMPARE 허용 확장 + `max-fields: 6` | A | 신규 1건 `[calc] 대화 조건 5(6)필드 배선`(참조 #17) | 신규 | 결정, #132(X-F) |
| T-2 | `ConditionOverride` **2필드**(B안도 2필드) + `ConditionValidator.changedFields` + fixture 4파일 컴파일 수선 | A | 같은 신규 1건(참조 #17) | 신규 | T-1 |
| T-3 | `ConditionResolver` override 배선 + "override가 결과를 바꾼다" 단위 테스트 | A | 같은 신규 1건(참조 #25·#32) | 신규 | T-2 |
| T-4 | `PlanService.merge` 배선 + 적용 테스트 | A | 같은 신규 1건(참조 #33) | 신규 | T-2 |
| T-5 | `PlanContextProviderImpl` `CHANGEABLE_KEYS`·`toOverride` | A | **#132**에 합침 | **OPEN** | — |
| T-6 | `CompareConditionsUseCase` 초과 분기 역전 + **C2-4 불변식 개정 문구**(Spring 코드 0) + `diff` 비움 + display 쪽별 분리 + 초과 칸 `heldAssets` | A | 같은 신규 1건에 포함. **"C2-4 불변식" 단독 신규 Issue는 만들지 않는다**(같은 파일, `status` 이미 존재) | 신규 | — |
| T-7 | internal-calc 계약·fixture(A-4 키 교체, a4-response.json, **a5 의미 재배치 + 200 성공 예시 추가**, REST Docs display 분) | A | **#10**(계약 Issue) | **CLOSED** → X-D | T-6 |
| T-8 | ai-server 도구·`ConditionChanges` 키 확장 + **`drop_carried_conditions` `_GOAL`·`_HELD`** + **`calc.py` `status` 통과** + **`prompts.py:53-54` 규칙 9 쪽별 재작성** | B | **#21** | **CLOSED** → X-D | Spring 배포 완료 |
| T-9 | 프롬프트 개정(`:7-8,18,21-27,30-31,53-54,70,75`) + 단위·역할 규칙 + **`check_amount_units`**(2단계 전제, 기존 정규식 재사용) + fake 테스트 + 고정 문장 테스트 대상 교체 | B | **#21**, 단위·되묻기 테스트는 **#23** | 둘 다 **CLOSED** → X-D | T-8 |
| T-10 | 문구표 1단계 신규 4 · 개정 3 + `CopyBook.java` + 프론트 `copy.ts` 2곳 | 공통 | **#18** | **CLOSED** → X-D | X-B 결정 |
| T-11 | chat 저장 맵을 **처음부터 5(6)키** + **모르는 키 → 메시지 FAILED** 테스트 | **B** | **#44·#45·#128 본문에 수용 기준 추가**(#132의 공통 변환기를 쓴다) | **모두 OPEN** | — |
| T-12 | 프론트: 비교 카드(비대칭 초과 칸, 쪽별 목표 금액, `conditions` 5(6)행, 주의 문구, `status` 타입), 목 JSON 3개 | B | **#53** 본문 수정 | **OPEN**(in-progress) | T-6, T-7 |
| T-13 | '입력 수정' 버튼 제거 (**이번 범위 밖**) | B | **#51** | **CLOSED** | **X-B가 B안이면 2단계(HELD) 완료 뒤** + 별도 결정 |

---

## CF12-16. 작업량 추정 (재검토 반영)

### Spring (A팀, 백엔드 1명)

| 구성 | 일수 |
|---|---|
| `rules.yml` + `ConditionOverride` 2필드 + `changedFields` | 0.3 |
| `InternalCalcController`(e·f) — #132 후면 한 곳 | 0.3 (#132 없으면 0.6) |
| `PlanContextProviderImpl`(i·j) | 0.2 (#132에 흡수 가능) |
| `ConditionResolver` override 배선 + 단위 테스트 | 0.3 |
| `PlanService.merge` + 적용 테스트 | 0.3 |
| ~~`ConditionValues` 2필드 + REST Docs~~ | **0** (−0.5, 범위에서 뺐다) |
| display 쪽별 분리 + 초과 칸 `heldAssets` + `ResultDisplayBuilderTest` | 0.5 |
| C2-4 개정(javadoc·계약 문구만, 코드 0) + 초과 분기 역전 | 0.4 |
| 테스트 fixture 컴파일 수선(4파일 20여 곳) | 0.5 |
| 계약 문서·`moeun/docs/api` 사본 | 0.5 |
| **소계(X-B B안 = 목표 금액만, 3-1 포함)** | **≈3.3일** |
| X-B A안(`HELD_ASSETS`까지: C2-6 개정·비교 `calcStartMonth`·display) 추가 | **+1.0일** |

### ai-server·chat·프론트 (B팀, 인일)

| 작업 | 추정 |
|---|---|
| 스키마·도구·`ConditionChanges` 키 확장 + 프롬프트 개정(규칙 9 쪽별 포함) + 기존 테스트 대상 교체 | 1.5 |
| `drop_carried_conditions` 확장(`_GOAL`·`_HELD`) + 표 테스트 | 1 |
| `_select_side` `status` 통과 + 비대칭 프롬프트·테스트 | 0.2 |
| `chat.goalAmountChangedNote`·`chat.changedAlreadyExceeded` 덧붙이기 + 테스트 | 0.5 |
| chat 저장 5(6)키 맵 + "모르는 키 → FAILED" 테스트 (#44·#45·#128에 흡수) | ≈0 |
| 프론트: 카드 비대칭 칸, 목표 금액 행, 주의 문구, 목 JSON 3개 | 0.5~1 |
| 문구표 개정·신규 + 프론트 `copy.ts` 동기 | 0.5 |
| **소계(B팀, X-B B안)** | **≈4.2~4.7인일** |
| X-B A안 추가(`check_amount_units` 1 + `heldAssetsBasis` 0.5 + 카드 행·display 0.5 + D-035 확장) | **+2~2.5인일** |

---

## CF12-17. 합의 확정 항목 (결정 없이 본문대로 간다)

| # | 항목 | 근거 절 |
|---|---|---|
| 1 | `max-fields` = **6**(5·4·0 거절. `allows(field)`를 따로 보므로 "허용 5 < max 6"에 가드 구멍 없음). `TOO_MANY_CHANGES` 문구·화면 만들지 않음 | CF12-6 |
| 2 | `rules.yml` `fields:` 블록 **불변**, `change-paths` 허용 목록만 확장. **yml만으로는 효과 0** | CF12-5 |
| 3 | **CHAT·COMPARE 둘 다 개방**(전 X-C, 소비자 보류 철회). 추가 비용 0, 조회 경로 없음. FR-CMP-02는 Should 그대로, 프론트 비교 영역은 만들지 않는다 | CF12-2 |
| 4 | **초과 계획에서 바꾼 조건이 초과를 벗어나면 계산 진행(3-1)**(전 X-A, 제공자가 3-2 권고 철회). 그 밖은 409 유지 | CF12-8-1 |
| 5 | **C2-4 불변식 개정 + 쪽별 `status`.** 단 **`CalcResultView.status`는 이미 응답에 있어 Spring 코드 변경 0**(javadoc·계약 문구·소비자 타입만) | CF12-8-0 |
| 6 | 한쪽 초과면 `scenarios: []`·`diff.byScenario: []`, **`comparable` 플래그 없음** | CF12-8-0·8-2 |
| 7 | `changed` 초과 시 **적용 버튼 활성** + `chat.changedAlreadyExceeded`를 **ai-server가 `changed.status`를 보고** 붙임 | CF12-8-2 |
| 8 | **초과인 쪽에 `conditions.<side>.heldAssets` 생성(1단계에도)** + 초과 칸 문구는 **`chat.cardAlreadyExceeded` 신규 키**(`result.alreadyExceeded` 재사용 금지) | CF12-8-2a |
| 9 | display 쪽별 키 이름 = **`conditions.current.…` / `conditions.changed.…`**(제공자가 자기 안 철회) + **목표가 바뀐 비교에서 무접두어 `goalAmount` 미생성** | CF12-8-3 |
| 10 | **`DISPLAY_KEY`(`schemas.py:84-90`) 개정은 필요 없다**(planContext 전용 필터, 비교 display는 무필터 통과). **단일 경로에 `conditions.goalAmount`가 생길 때만** 한 단어 추가(안 더하면 조용히 버려진다). **ai-server에 `ComparisonResponse` 스키마는 없다** | CF12-4-2 gg0 |
| 11 | **`CalcComparison.ConditionValues` 2필드 확장과 딸린 REST Docs·C2-3 개정은 뺀다**(쪽별 `goalAmount`는 `CalcResultView`에 이미 있다) | CF12-4-1 k |
| 12 | `achievementChange`를 **null로 숨기지 않는다**, 주의 문구는 **코드가** 붙인다 | CF12-8-3 |
| 13 | **`drop_carried_conditions` 확장**(`_GOAL`·`_HELD`, 둘 다 **1단계**) + `test_no_accumulate.py` 새 행. 위험은 **조건부**("만원" 등 단위 토큰 + 숫자 덩이 수 ≤ 인식 조건 수) | CF12-4-2a |
| 14 | **`calc.py:_select_for_model`·`_select_side`가 `status`를 모델에 통과** | CF12-8-0 |
| 15 | **`prompts.py:53-54` 규칙 9를 쪽별로 다시 쓴다**(제공자 재검토 신규, T-8 범위) | CF12-4-2 aa |
| 16 | **`agent.py:143`(`_FIXED_COPY_KEYS`)·`:424`·`:441`·프론트 `settledStatus`는 수정 0줄**(v2·v1의 회귀 추정 정정) | CF12-8-1 |
| 17 | **모르는 키 → 해당 ASSISTANT 메시지 `FAILED`**(턴 전체 500 아님, `RECALC_RESULT` 저장 금지, 기존 `chat.failed` 재사용, 새 문구 키 없음). **부분 저장 금지(양보 불가)**. **저장 코드는 아직 없고 소유는 B팀(#44·#45·#128)** | CF12-10-1 |
| 18 | **배포 순서 Spring → ai-server → 프론트** + **문구 본문 개정은 ai-server 활성화와 같은 날** | CF12-11 |
| 19 | **단위 자동 보정 금지**, 범위 검증은 **Spring 한 곳(D-033)**, 비정상 값 경고 규칙 없음. `check_amount_units`는 **기존 `_NUMBER`·`_KO_MAN` 재사용**, `held_assets`는 숫자 토큰 없으면 **CLARIFY** | CF12-9-3 |
| 20 | **고정 문장 테스트는 삭제하지 않고 대상 교체**(D-056·CP-05 보호 유지), `test_out_of_scope.py:230`은 그대로 | CF12-9-2 |
| 21 | **`a5-already-exceeded.json`은 이미 있다 → 지우지 않고 의미 재배치** + 200 성공 예시 별 파일 추가. 깨지는 기존 테스트는 **`InternalCalcApiTest:240` 한 건** | CF12-4-4 |
| 22 | 문구 **1단계 신규 4**(`condition.goalAmount`, `chat.goalAmountChangedNote`, `chat.changedAlreadyExceeded`, `chat.cardAlreadyExceeded`) · **개정 3**. `chat.alreadyExceeded`는 **409 경로만** 맡고 키를 나누지 않는다 | CF12-13 |
| 23 | **DB 스키마 변경 0**, `merge` 2줄, 되돌리기 추가 작업 없음, `source` CHECK에 `'CHAT'` 있음 | CF12-10 |
| 24 | **`ConditionOverride`는 X-B가 B안이어도 2필드를 한 번에** 넣고 yml·Set에서만 `heldAssets`를 뺀다(fixture 수선 1회) | CF12-4-1 d |
| 25 | **제공자의 `notes` 경로(`chat.heldAssetsBasis`를 Spring이 내림)는 폐기 확정** — `_select_for_model`이 새 최상위 키를 조용히 버리고, 받으려면 `test_calc_client.py:318-322,379` 단언까지 바꾼다. ai-server가 문구표를 읽는다 | CF12-7-2 |
| 26 | **X-D 혼합 수용. 단 "C2-4 불변식" 단독 신규 Issue는 만들지 않는다**(같은 파일, `status` 이미 존재). reopen 대상은 **#21·#18 중심** | CF12-15 |

### 남은 쟁점 3건 (사람이 정한다 — 합의안 참조)

| 쟁점 | 내용 |
|---|---|
| **X-B** | 1단계 범위: A) `GOAL_AMOUNT`+`HELD_ASSETS` 둘 다(사용자 원안) / B) 목표 금액만, 보유 자산은 2단계(제공자·소비자 모두 권고) |
| **X-F**(신규) | #132 선행을 유지할지, 언제 "이번 변경에 흡수"로 전환할지 |
| 결정 변경 확인 | **D-040 대체**, **D-071 변경**, **internal-calc C2-4 불변식 개정** 세 건 |

---

## §Z2. v2 → v3 변경 표

| Z2 | v2 | v3 | 근거 |
|---|---|---|---|
| **Z2-1** | §X-A 쟁점(제공자 3-2 vs 소비자 3-1, 정면 충돌) | **삭제 → 합의 확정 3-1**(CF12-8-1). 양쪽 입장·근거·비용을 본문 표로 흡수 | 제공자 P-1 입장 변경(3-2 권고 철회), 소비자 4절 |
| **Z2-2** | X-A에서 "3-1은 `agent.py:143·424·441`·프론트 `settledStatus`를 고쳐야 한다"(회귀 높음) | **정정: 수정 0줄.** `:143`은 409 코드→문구 키 매핑, `:424`·`:441`은 EXPLAIN planContext 분기, `settledStatus`는 계획 결과 상태 | 제공자 P-1 표, 소비자 2-2 |
| **Z2-3** | "3-2는 `ck_cm_recalc` CHECK 개정 + 새 메시지 타입이 필요"(소비자 주장) | **확정 사실로 승격 + 결정타 추가**: `ck_cm_type`에 쓸 타입 없음, 그리고 **2턴 확인이 `drop_carried_conditions`로 성립하지 않는다**("네"에 숫자·조건 없음 → `:383` CLARIFY) | 제공자 P-1(코드 확인), 소비자 2-1 |
| **Z2-4** | 3-1의 Spring 추가분 +1.5일, 회귀 "높음" | **≈0.7일, 깨지는 기존 테스트 1건(`InternalCalcApiTest:240`)** | 제공자 P-1 측정 |
| **Z2-5** | §X-C 쟁점(제공자 둘 다 / 소비자 보류) | **삭제 → 합의 확정: CHAT·COMPARE 둘 다 개방**(CF12-2·CF12-17 3) | 소비자 C-4 보류 철회(`COMPARE`는 `rules.yml:17`·`PlanService:51`·`ChangePath:7`·`schema.sql:91`에만 있고 조회 경로 없음) |
| **Z2-6** | §X-E 쟁점(저장 실패 범위 미정, "제공자 확인 필요") | **삭제 → 합의 확정: 해당 ASSISTANT 메시지 FAILED**(CF12-10-1). 턴 전체 500 아님, 기존 `chat.failed`, 새 문구 키 없음, `RECALC_RESULT` 저장 금지, **부분 저장 금지(양보 불가)** | 제공자 P-5, 소비자 C-6 |
| **Z2-7** | CF12-10 "chat 리스너 변환 맵(#41) **4키 고정 맵**" | **정정: 그 코드는 없다.** `chat/`은 `package-info.java` 하나뿐이고 `origin/develop`도 같다. #44·#45·#128(OPEN, team:B)이 앞으로 쓴다 → X-E 비용 ≈0, 소유 B팀 | 제공자 2절 (나), 소비자 0절 |
| **Z2-8** | CF12-8-0 "응답에 `status`를 **담는다**"(새 작업) | **정정(과대 확정): 이미 담겨 있다.** `CalcResultView.java:21`에 `status` 필드, `InternalCalcResponse`가 그대로 내보낸다 → **Spring 코드 변경 0**, javadoc·계약 문구·소비자 타입만 | 제공자 2절 (가) |
| **Z2-9** | 확정 3 / CF12-8-3 1항: "`schemas.py` `DISPLAY_KEY` 정규식을 함께 개정" + "ai-server `ComparisonResponse` 동반 변경" | **정정(삭제): 필요 없다.** `DISPLAY_KEY`(`:84-90`)는 `PlanContext.display` 전용 필터이고 비교 display는 `_select_for_model`이 무필터 통과(`current.GOOD.afterTaxAsset`가 이미 통과). **`ComparisonResponse` 클래스는 없다.** 단 **단일 경로에 `conditions.goalAmount`가 생기면 한 단어 추가 필수**(안 하면 조용히 버려진다) | 양쪽(제공자 2절 (다), 소비자 0절·3절 오류 1·2) |
| **Z2-10** | CF12-4-4·CF12-12 "`a5` 성공 fixture **신설**" | **정정: `a5-already-exceeded.json`이 이미 있다 → 지우지 않고 "바꿔도 여전히 초과" 사례로 의미 재배치**하고 200 성공 예시를 별 파일로 추가 | 제공자 2절 (라) |
| **Z2-11** | CF12-4-1 k: `CalcComparison.ConditionValues` 2필드 확장 + REST Docs 스냅샷 + C2-3 개정 | **범위에서 뺀다.** 쪽별 `goalAmount` raw는 `CalcResultView`에 이미 있다(F-4 목 JSON 확인). 제공자 ≈0.5일 절감, C2-3·`a4-response.json`의 `conditions`·REST Docs `conditions` 스냅샷 **불변** | 소비자 2-4, 제공자 수용 |
| **Z2-12** | display 쪽별 키 이름: 기획 권고(`conditions.current.goalAmount`) vs 제공자 안(`current.goalAmount`) — 재검토 질문 | **확정: `conditions.current.…`/`conditions.changed.…`.** 제공자가 자기 안 철회(`build(…, resultPrefix, conditionPrefix)`가 이미 조건 접두어를 받고 `CompareConditionsUseCase:33-36`에 상수가 있어 `putConditions` 한 줄) | 제공자 P-2, 소비자 C-2 |
| **Z2-13** | 무접두어 `goalAmount`는 **프롬프트로** 인용을 막는다 | **구조적으로 막는다: 목표가 바뀐 비교에서 Spring이 무접두어 `goalAmount`를 아예 만들지 않는다**(`build()` 첫 줄 분기 하나). 조용한 덮어쓰기와 잘못 인용이 한 번에 사라진다. 프롬프트 개정은 안전망으로 유지 | 소비자 C-1 |
| **Z2-14** | CF12-8-2 "초과 칸에 `*.goalAmount`·`*.heldAssets` display" ↔ X-B B안 "비교 `heldAssets` 노출이 사라져 ≈1일 절감" (**모순**) | **해소(CF12-8-2a): 1단계에서도 "초과인 쪽이면 `conditions.<side>.heldAssets` 생성" 규칙이 들어간다.** B안 절감은 ≈0.2일 줄어든다 | 소비자 C-1 "충돌" |
| **Z2-15** | 초과 칸 문구로 `result.alreadyExceeded`(결과 화면 문구) 재사용 | **거절. `chat.cardAlreadyExceeded` 신규 키**(`{heldAssets}`,`{goalAmount}`)로 뽑는다 | 제공자 3절 반박 2, 소비자 C-7 |
| **Z2-16** | 문구표 "신규 5 · 개정 3"(`chat.changedAlreadyExceeded`는 프론트 정적, 자리 `{goalAmount}` 등) | **재확정: 1단계 신규 4 + 2단계 신규 2 · 개정 3.** `chat.cardAlreadyExceeded` 추가, `chat.changedAlreadyExceeded`는 **자리 값 없음**이고 **ai-server가 `changed.status`를 보고** 붙인다 | 소비자 C-7 |
| **Z2-17** | `chat.alreadyExceeded`가 "현재 초과 / 적용하면 초과" 두 상황을 감당해야 한다 | **전제 교체: 두 상황은 경로가 다르다.** `chat.alreadyExceeded`는 **409 경로만**(현재 초과, 또는 올렸는데 여전히 초과), "적용하면 초과"는 200 안의 `changed.status`라 `chat.changedAlreadyExceeded`가 맡는다 → **키를 나눌 필요 없음.** 제안 문장 확정: "이미 가진 자산이 목표 금액을 넘었어요. 대화로 목표 금액을 더 높게 바꿔 볼 수 있어요." | 소비자 C-7 |
| **Z2-18** | 개정 3의 `chat.unchangeableCondition`: "입력 수정에서를 **빼고** '여기서는 바꿀 수 없어요'로 끝낸다" | **정정: X-B가 B안이면 틀렸다.** 1단계에서 보유 자산은 여전히 입력 수정으로만 바꾸므로 **"보유 자산은 입력 수정에서" 안내를 유지**해야 한다(빼면 막다른 길이 새로 생긴다). A안이면 v2대로 | 소비자 3절 오류 3 |
| **Z2-19** | 배포 순서 3단계 | **문구 본문 개정은 ai-server 활성화와 같은 날 나간다**를 추가(Spring `CopyBook` 선배포 시 "가리킨 곳이 아직 안 된다") + 위험이 "#44·#45·#128이 4키로 먼저 완성되는" 쪽으로 옮겨 감 | 소비자 확정 10 보강, 제공자 3절 |
| **Z2-20** | CF12-4-2 s: "history 있는 대화에서 새 키가 조용히 지워진다" | **조건을 붙였다**(CF12-4-2a 표): "목표를 1억으로"는 **유지**되고(숫자 수 > 조건 수 가드), "목표 2,500**만원**으로"는 지워진다. `_GOAL`·`_HELD`는 **1단계 필수** | 제공자 3절 재현, 소비자 C-3-1 |
| **Z2-21** | `check_amount_units`에 새 정규식 | **기존 `_NUMBER`·`_KO_MAN`·`_THOUSANDS_COMMA` 재사용 권고**(한글 수사도 꽤 넓게 세므로 건너뛰는 범위가 좁아져 더 안전, 비용도 준다) + **`held_assets`는 숫자 토큰 없으면 CLARIFY** + 1단계는 `goal_amount`만 대조 | 제공자 3절, 소비자 C-5 |
| **Z2-22** | `prompts.py` 변경 범위에 규칙 9의 **쪽별 재작성** 없음 | **추가(CF12-4-2 aa, T-8 범위)**: `:53-54`가 단일 결과 기준이라 비대칭 2칸에서 모델이 어느 쪽 `status`를 보는지 애매하다 | 제공자 P-1 말미(신규 제기) |
| **Z2-23** | 제공자 `notes` 경로가 "서버가 문장을 내릴 때의 대안"으로 남아 있었다 | **폐기 확정.** `_select_for_model`이 새 최상위 키를 조용히 버리고, 받으려면 `test_calc_client.py:318-322,379` 단언까지 바꾼다 | 소비자 2-5, 제공자 6절 수용 |
| **Z2-24** | §X-B 제공자 의견 "B안이면 ≈1일 절감"(display 한 줄 수준) | **비용 서술 정정**: A안을 고르면 **C2-6 개정 + 그 규칙이 막던 위험(비교 답변이 기준월·세율 인용)을 프롬프트로 다시 막기**까지가 범위다(제공자 양보 불가). 절감도 Z2-14로 ≈0.2일 줄어든다 | 제공자 3절 비동의 1 |
| **Z2-25** | §X-D 추천: reopen 3건(#21·#18·#10) + 신규 1~2건 | **혼합 수용 + 수정: "C2-4 불변식" 단독 신규 Issue는 만들지 않는다**(같은 파일, `status` 이미 존재). reopen 대상은 **#21·#18 중심**, #10은 X-D 결정에 따라 갈린다 | 제공자 P-7, 소비자 X-D |
| **Z2-26** | CF12-11-1 #132 선행이 "확정(제공자 양보 불가)" | **쟁점 X-F로 승격.** 현황(OPEN·in-progress·열린 PR 0건·`ConditionChanges.java` 없음)과 대안("흡수")을 적고 **전환 시점을 사람이 정한다** | 제공자 P-6 |
| **Z2-27** | `max-fields` 6에 "허용 5 < max 6이면 가드 논리가 약해진다"는 우려 | **불성립.** `validateChanged:83-86`이 `allows(field)`를 따로 보므로 허용 밖 키는 개별 거절된다. 6 유지(5로 두면 2단계에서 또 고친다) | 제공자 P-4, 소비자 C-3-3 |
| **Z2-28** | T-11(chat 저장) 담당 **A팀**, Issue **#132** | **담당 B팀, #44·#45·#128 본문에 수용 기준 추가**(변환기는 #132의 공통 코드를 쓴다) | 제공자 P-5 (나) |
| **Z2-29** | CF12-4-2 ee: `agent.py:424·441` 개정 | **삭제(수정 0줄)** | 제공자 P-1, 소비자 2-2 |
| **Z2-30** | CF12-16 추정: Spring ≈4.1일 + 3-1 +1.5일 / B팀 ≈7~8인일 | **재산정**: B안 기준 Spring **≈3.3일**(k 제외 −0.5, 3-1 +0.7, C2-4 코드 0), B팀 **≈4.2~4.7인일**(chat 저장 ≈0, 3-1 증분 0.2). A안은 각 +1.0일 / +2~2.5인일 | 제공자 P-1·2절, 소비자 C-8 |
| **Z2-31** | "확정(합의) 항목 21건" | **26건으로 재작성**(CF12-17). 사실 정정 6건(Z2-7~11, Z2-29)을 확정에 반영하고, 전 X-A·X-C·X-E를 확정으로 옮겼다 | 재검토 2건 |
| **Z2-32** | 쟁점 5건(X-A~X-E) | **쟁점 3건**: **X-B**(유지), **X-F**(신규, #132 선행), **결정 변경 확인**(D-040 대체·D-071 변경·C2-4 개정 묶음). X-A·X-C·X-D·X-E는 합의로 종결 | 재검토 수렴 |
| **Z2-33** | §재검토 질문 P-1~7 / C-1~8 | **삭제**(답을 모두 받았다). 협상 종료 | — |
