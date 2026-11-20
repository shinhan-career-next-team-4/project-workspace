# changeable-fields-v2 소비자 재검토 (B팀: ai-server·chat·프론트)

- 대상: `changeable-fields-v2.md`(CF12) + 제공자 1차 검토(`review-changeable-fields-v1-provider.md`). 마지막 라운드.
- 근거 코드: `../moeun` `feature/126-input-suggestion`(읽기만). 이 브랜치에는 chat 리스너(#41 계열)·프론트 비교 카드가 **아직 없다**(`backend/.../chat`은 `package-info.java`뿐, 프론트는 `features/chat/ChatWindow.tsx`와 `mocks/chat/get-comparison.*.json`뿐).
- 표기: 아래 "확정 N"은 v2 `CF12-17`의 확정(합의) 21건 번호.

판정: **수정하면 수용**

수용 못 할 것은 없다. 다만 v2의 "확정" 중 **사실과 다른 것 3건**(DISPLAY_KEY 개정, `ComparisonResponse` 스키마, 개정 문구 `chat.unchangeableCondition`)과, **X-B(목표 금액만)와 X-A(초과 칸 표시)가 서로 부딪히는 곳 1건**(초과 칸의 `heldAssets` display)이 있다. 이 4건을 고치면 수용한다.

---

## 0. 먼저 알아 둘 코드 사실 (이 재검토의 근거 3개)

1. **`DISPLAY_KEY` 정규식은 비교(`/internal/calc`) display에 쓰이지 않는다.**
   - `ai-server/app/schemas.py:84-90`: `PlanContext`의 `@field_validator("display")` 안에서만 `DISPLAY_KEY.fullmatch`로 거른다(= EXPLAIN의 planContext).
   - 비교 응답은 `ai-server/app/tools/calc.py:_select_for_model`이 `body["display"]`를 **걸러내지 않고 그대로** 넘긴다. 이미 `current.GOOD.afterTaxAsset`·`diff.AVG.afterTaxAssetDelta`처럼 정규식에 **맞지 않는** 키가 매일 통과한다. 숫자 대조의 근거도 `agent.py:388-390`이 display 값 전부를 모은다.
   - 그러므로 v2 확정 3·CF12-8-3 1항·CF12-4-2의 "`schemas.py:54-59` `DISPLAY_KEY` 개정"은 **필요 없다.** 또 제공자 ③의 "ai-server `ComparisonResponse` 스키마가 함께 바뀐다"도 **그런 클래스가 없다**(`grep ComparisonResponse ai-server/app` 0건). 비교 응답은 dict로 읽는다.
2. **프론트 F-4 응답은 이미 쪽별 `status`·`goalAmount`와 `display`를 같이 가진다.** `frontend/src/mocks/chat/get-comparison.200.json`: `current.status`, `current.goalAmount`(raw), 최상위 `display`(`conditions.current.monthlySavingAmount` 등). 즉 프론트는 쪽별 키 문자열만 있으면 그리고, 새 raw 필드가 필요 없다.
3. **`drop_carried_conditions`는 "네" 같은 되묻기 답을 전부 지운다.** `agent.py:204-230`: 발화에 조건 표현도 숫자도 없으면 `stated`가 비어 `changes`가 전부 빠진다(`:230`). 이 점이 3-2를 거절하는 가장 강한 코드 근거다(2절).

---

## 1. C-1~C-8 답

### C-1. 비대칭 비교에 필요한 display 키 전수 목록 — **수정(목록 확정)**

범위: **X-B가 B안(목표 금액만)이어도 필요한 것**과 **2단계(HELD)에서 더하는 것**을 나눠 적는다. `S`는 `current`·`changed`.

| 키 | 언제 | 쓰는 곳 | 근거 |
|---|---|---|---|
| `conditions.S.goalAmount` | `conditionChanges`에 `goalAmount`가 있을 때 **양쪽 다** | 카드 "목표 금액" 행, `chat.goalAmountChangedNote`의 `{currentGoal}`·`{changedGoal}`, 초과 칸 문장의 `{goalAmount}` | CF12-8-3 1항 |
| `conditions.S.heldAssets` | **그 쪽 `status`가 `ALREADY_EXCEEDED`일 때(B안에서도 필수)**, 2단계에서는 `conditionChanges`에 `heldAssets`가 있을 때도 | 초과 칸 문장 `{heldAssets}`(`copy.ko.yml:131` `result.alreadyExceeded` 슬롯 `{heldAssets}`·`{goalAmount}`) | 아래 "충돌" |
| `S.<G>.afterTaxAsset·principal·afterTaxGain·gapToGoal`, `S.<G>.goalReachMonth`(달성 시), `S.targetMonth` | **그 쪽 `status = CALCULATED`일 때만**(초과 칸은 `scenarios: []`라 이미 안 만들어진다) | 기존 | `ResultDisplayBuilder.putScenario`, 코드 확인 |
| `conditions.S.monthlySavingAmount·targetPeriodMonths·savingsRatioPct·savingsRateInputPct` | 기존 그대로(양쪽 항상) | 카드 조건 행 | 기존 |
| `diff.<G>.afterTaxAssetDelta·principalDelta·afterTaxGainDelta` | **양쪽 `CALCULATED`일 때만** | 기존 | 확정 7 |
| (없앨 것) 무접두어 `goalAmount` | **`conditionChanges`에 `goalAmount`가 있는 비교에서는 만들지 않는다** | — | 아래 |
| `calcStartMonth`(무접두어, 비교에도) | **2단계(HELD)** | `chat.heldAssetsBasis`의 `{calcStartMonth}` | CF12-7-2 3항 |

**충돌 (v2 안의 모순, 반드시 정리)**: v2 CF12-8-2는 "초과인 쪽에도 `*.goalAmount`·`*.heldAssets` display를 내린다"고 쓰고, 제공자 4절·6절·§X-B는 B안에서 "`conditions.heldAssets` 비교 노출이 사라져 ≈1일 절감"이라고 쓴다. **둘 다 맞을 수 없다.** 초과 칸 문장이 `{heldAssets}`를 쓰는 한(결과 화면용 `result.alreadyExceeded` 슬롯) 비교 display에 보유 자산이 필요하다. `ResultDisplayBuilder.putConditions`는 `isSingleResult`일 때만 `heldAssets`를 만든다(코드 확인). 따라서 B안에서도 **"그 쪽이 초과일 때만 `conditions.S.heldAssets`를 만든다"** 규칙은 들어가야 한다(절감 1일은 ≈0.2일 줄어든다). 문장에서 `{heldAssets}`를 빼는 대안(`chat.cardAlreadyExceeded`가 목표 금액만 인용)도 가능하지만 사용자에게 "가진 자산이 얼마라서 넘었는지"가 안 보여 FR-RES-01과 달라진다 → 소비자는 위 규칙을 택한다.

**무접두어 `goalAmount`를 구조적으로 없애는 이유**: v2는 "프롬프트가 인용하지 않게 한다"(CF12-8-3 1항 마지막)로 막는다. 모델 준수에 기대는 방식이다. Spring이 목표가 바뀐 비교에서 키 자체를 만들지 않으면 **조용한 덮어쓰기(제공자 ④)와 잘못 인용이 한 번에 사라진다.** 비용은 `build()` 첫 줄 `display.put("goalAmount", …)`에 분기 하나(비교 + `goalAmount` 변경)뿐이다. `prompts.py:30-31`의 문장 수정은 그래도 한다("goalAmount는 같은 값이라"를 지운다).

**빠진 정보는 없다**: `status`(양쪽), `scenarios: []`, `diff.byScenario: []`(`CalcComparison.Diff.between`이 빈 목록에서 터지지 않는다고 제공자가 확인), 위 키. 별도 `comparable` 플래그는 불필요(확정 7 유지).

### C-2. 쪽별 키 이름 — **`conditions.S.goalAmount`로 합의 가능. 제공자 안(`S.goalAmount`)은 접는다**

- ai-server 비용은 **0**이다(0절 1): 어느 이름이든 `DISPLAY_KEY`를 안 거치고, 숫자 대조는 display 값 전체를 모은다. 그러니 이름은 Spring·프론트에서 싼 쪽으로 고르면 된다.
- Spring: `ResultDisplayBuilder.build(input, result, resultPrefix, conditionPrefix)`는 두 접두어를 이미 받는다. 조건 키는 `putConditions(display, conditionPrefix, …)`가 만든다(코드 확인). `conditionPrefix + "goalAmount"`는 그 메서드에 한 줄이다. 제공자 안(`resultPrefix + "goalAmount"`)도 한 줄이라 **비용 차이는 없다.**
- 프론트: 카드가 조건 행을 `conditions.current.<k>`/`conditions.changed.<k>` 템플릿 루프로 그리면 목표 금액 행은 `<k>`가 하나 더 늘 뿐이다. `current.goalAmount`로 가면 "조건 행 중 하나만 결과 접두어를 쓰는" 예외가 생겨 행 렌더링에 분기가 든다.
- 개념: `current.targetMonth`·`current.<G>.*`는 **계산 결과**, `goalAmount`는 **사용자가 말한 조건**이다. 결과 접두어에 조건을 섞지 않는다.
- 프롬프트 인용 규칙(`prompts.py:30-31`) 개정: "goalAmount는 같은 값이라…"를 **"목표 금액을 말할 때는 `conditions.current.goalAmount`·`conditions.changed.goalAmount`를 각각 인용한다. 무접두어 `goalAmount`는 비교 응답에 없을 수 있다"**로. 그리고 위 구조적 제거 덕에 이 문장이 안전망이 된다.
- 합의 제안: 제공자 P-2에 **`conditions.S.goalAmount`·`conditions.S.heldAssets`로 확정**한다고 적고, `DISPLAY_KEY` 개정 줄(확정 3, CF12-4-2)은 **삭제**한다.

### C-3. B안 동의와 2단계 목록 — **수용(B안). 1단계에 미리 넣을 것 3개**

동의한다. 2단계로 미루는 것:
- `ConditionChanges`·도구 스키마의 `held_assets` 키(두 곳 다 1단계는 **5키**, `extra="forbid"`라 모델이 못 보낸다).
- `check_amount_units`의 `held_assets` 분기(아래 C-5 기준).
- `chat.heldAssetsBasis` 덧붙이기, `condition.heldAssets` 문구, 카드 보유 자산 행, 비교 display의 `calcStartMonth`, `conditions.S.heldAssets`의 "변경 시" 조건(단 초과 칸용은 1단계).
- D-035 확장 결정(새 D-번호).

**1단계에 같이 넣는 편이 싼 것(두 번 고치지 않게)**:
1. **`_stated_conditions`에 `_GOAL`·`_HELD` 정규식**(`agent.py:196-205`). 보유 자산을 못 바꿔도 "이미 3,000만원 모았어요"가 `_MONTHLY`(`\d\s*만`, `만원`)에 걸려 **월 저축액 발화로 오인**되는 것은 막아야 한다. 1단계에서 `held_assets`가 닫혀도 필요하다. `test_no_accumulate.py:337-372` 표에 목표·보유 행 둘 다 지금 넣는다.
2. **`ConditionOverride`·`PlanService.merge`·`ConditionResolver`의 `heldAssets` 필드 타입 추가**는 A팀 판단이지만, 제공자 1절 "테스트 fixture 4파일 20여 곳 컴파일 수선"이 **한 번만** 일어나게 하려면 타입은 2필드를 한 번에 넣고 `rules.yml` 허용 목록과 `CHANGEABLE_KEYS`에서만 `heldAssets`를 뺀다. 이렇게 하면 2단계는 yml·Set 한 줄이다.
3. **`max-fields`는 6 그대로**(P-4 답): 허용 5 < max 6이면 가드가 안 걸릴 뿐이고, 4·5로 두면 2단계에 다시 고친다. 가드는 어느 쪽이든 도달 불가이므로 6이 싸다(확정 1과 일치).

### C-4. COMPARE 동시 개방 — **보류를 철회, 수용**

제공자 주장을 코드로 확인했다: `COMPARE`는 `rules.yml:17`, `PlanService.java:51` `APPLY_PATHS`, `ChangePath.java:7`, `schema.sql:91`(`source` CHECK)에만 있고, 조회·비교 컨트롤러·유스케이스에는 쓰이지 않는다(`backend/src/main`에서 `COMPARE` 검색 결과가 그 4곳). 비교 API(#64)가 아직 없으니 소비자 쪽에서 깨질 것이 없다. 내 보류 근거("필요 없다")는 약했다. 조건:
- FR-CMP-02는 Should 그대로, **프론트 비교 영역은 만들지 않는다**(v2 §X-C와 같음).
- COMPARE 허용은 `ConditionValidator` 단위 테스트 한 줄(COMPARE에서도 6→5필드 허용·`ALTERNATIVE`는 3필드 유지)로 고정한다.

### C-5. `check_amount_units` — **1단계 필수 아님, HELD를 여는 전제. 닫는 기준 명시**

- **서는가**: 숫자 토큰(`N억`, `N천만원`, `N만원`, `N원`, 쉼표 금액, `1억 5천만원`, `1.5억`, `300만 원`)은 정규식 하나와 표 테스트로 1인일에 선다. 이미 `agent.py:_NUMBER`·`_KO_MAN`·`_THOUSANDS_COMMA`가 같은 성격의 파싱을 갖고 있어 재사용이 된다. 위험은 **비용이 아니라 회귀**다: 월 저축액까지 대조하면 기존 fake 테스트의 "50만 → 500000" 류가 후보 집합에 없어 CLARIFY로 바뀔 수 있다(예: `50만`처럼 `원` 없는 표기). 그래서 **1단계에서는 `goal_amount`만** 대조하고 월 저축액은 대조 대상에 넣지 않는다.
- **한글 수사를 건너뛰는 설계의 놓침**: v2는 "숫자 토큰이 없으면 검사를 건너뛴다"(CF12-9-3 b). 목표 금액은 눈에 보이는 범위라 건너뛰어도 받을 수 있지만, **보유 자산은 안 된다**: "삼천만원 모았어요"를 모델이 `3000`으로 내면 카드가 "약 0만원"이다. 그래서 **`held_assets`는 숫자 토큰이 없으면 건너뛰지 않고 CLARIFY("숫자로 다시 말해 주세요")** 로 닫는다(fail-closed). 목표 금액은 건너뛰기를 허용.
- **HELD를 닫는 기준(2단계 진입 조건, 셋 다)**:
  1. `check_amount_units`가 머지되어 표 테스트 **15행 이상**(1억 5천만원, 2천5백만원, 1.5억, 300만 원, 쉼표, 단위 없음, 역할 혼동 포함)이 통과.
  2. fake 모델 고정 JSON 테스트: **"1억 → 10000"·"3,000만원 → 300000000"을 모델이 낸 경우 Spring을 부르지 않고 CLARIFY**.
  3. 3주 일정의 **2주차 말까지** 머지. 못 하면 `HELD_ASSETS`는 이번 범위에서 빠지고 T-13(입력 수정 버튼 제거)은 이번에 하지 않는다.
- 연결: 서지 않으면 X-B는 자동으로 B안이다(확인).

### C-6. X-E 저장 실패 UX — **새 문구 키 불필요. "턴 500"이 아니라 "메시지 FAILED"로**

- 대화는 비동기다(F-1이 202, 이후 폴링). 따라서 "500을 보는" 사용자는 없고, 리스너가 저장에 실패하면 **assistant 메시지가 `FAILED`로 끝나는 것**이 곧 "턴 실패"다. 사용자 질문(QUESTION)은 남는다.
- 프론트는 이미 `FAILED`를 처리한다: 문구표 `chat.failed`("답변을 만들지 못했어요. 잠시 후 다시 질문해 주세요", `copy.ko.yml:31`, FR-AI-04)와 `pollingFailed`. **새 키는 필요 없다.**
- 모르는 키는 `RECALC_RESULT`로 저장하지 않고(저장하면 `ck_cm_recalc`·F-4 재계산이 AI 문장과 다른 값을 쓴다) **메시지를 FAILED + 원인 로그**로 끝낸다. 이것이 "조용한 불일치"보다 낫다. ai-server는 `ConditionChanges`가 `extra="forbid"`(`schemas.py:31-42`)라 **모르는 키를 스스로 내지 않는다.** 모르는 키가 닿는 경우는 배포 순서 위반(ai-server가 Spring보다 먼저)뿐이므로 "시끄럽게 실패"가 맞다.
- 한계(문서에 적을 것): 재시도해도 Spring 배포 전에는 같은 결과다. "잠시 후"가 거짓일 수 있지만 운영 사고 상황이라 새 문구까지는 안 만든다.
- 제공자 P-5(같은 트랜잭션인지)는 A팀 확인이 맞다. 소비자 요구는 "RECALC_RESULT로 저장되지 않을 것"과 "FAILED로 끝나 폴링이 멈출 것" 둘뿐이다.

### C-7. 문구표 — **"신규 5·개정 3"은 부족. 1단계 신규 4·개정 3으로 다시 확정**

3-1(X-A)을 택하면 **초과 칸을 그리는 문장**이 필요한데 v2 목록에 없다. 카드 칸의 초과 문장에 결과 화면용 `result.alreadyExceeded`를 재사용하면 "목표 금액은 대화로 바꿀 수 있어요"라는 안내가 **방금 대화로 바꾼 사용자에게** 붙는다(어색). 그래서 슬롯만 있는 문장을 따로 둔다.

| 구분 | 키 | 자리 | 비고 |
|---|---|---|---|
| 신규(1단계) | `condition.goalAmount` | — | F-4 행 레이블·범위 밖 안내 열거(`copy.py:93` `_CONDITION_CODES`) |
| 신규 | `chat.goalAmountChangedNote` | `{currentGoal}`, `{changedGoal}` | ai-server 덧붙이기 + 프론트 카드. `check_numbers` **뒤**(`with_tax_note`와 같은 자리) |
| 신규 | `chat.changedAlreadyExceeded` | **없음** | "이 조건으로 적용하면 이미 목표를 넘은 상태가 돼요". 숫자가 없으므로 `check_numbers` 영향 없음. **모델이 아니라 ai-server가 `changed.status`를 보고 붙인다**(D-073 방식, 모델 준수에 기대지 않음) |
| 신규 | `chat.cardAlreadyExceeded` | `{heldAssets}`, `{goalAmount}` | 카드의 초과 칸(양쪽 어느 쪽이든). 안내 문장 없이 사실만 |
| 신규(2단계) | `condition.heldAssets`, `chat.heldAssetsBasis` | — / `{calcStartMonth}` | |
| 개정 | `chat.alreadyExceeded` | 없음 | 아래 |
| 개정 | `result.alreadyExceeded` | `{heldAssets}`,`{goalAmount}` | "입력 수정" → "대화로" |
| 개정 | `chat.unchangeableCondition` | 없음 | **v2 개정안 정정(아래 3절 오류 3)** |

- **`chat.alreadyExceeded`는 두 상황을 한 문장으로 감당할 수 있다 — 단 그 두 상황이 서로 다르다는 전제를 바꿔야 한다.** v2가 묶은 "현재 초과 / 적용하면 초과"는 **전달 경로가 다르다**: 전자는 409 고정 문장(`agent.py:143`, `ChatWindow` D-063 고정 문장), 후자는 200 성공 안의 `changed.status`라서 `chat.alreadyExceeded`가 나갈 일이 없다. 후자는 위 `chat.changedAlreadyExceeded`가 맡는다. 키를 나눌 필요 없이 이미 다른 키다.
- 409가 나가는 경우는 (i) 초과 계획에서 목표·보유를 안 바꾸는 변경, (ii) 목표를 올렸는데 **여전히 초과**다. 한 문장으로: **"이미 가진 자산이 목표 금액을 넘었어요. 대화로 목표 금액을 더 높게 바꿔 볼 수 있어요."** (i)(ii) 모두 어색하지 않다("더 높게"가 (ii)를 받는다). `ChatWindow`의 고정 문장(D-063)과 `features/chat/copy.ts:5` 복제본도 같은 본문으로 맞춘다.

### C-8. #53 추가 비용 — **지금 설계에 넣으면 +0.5일 안팎, 나중에 끼우면 재작업**

- 이 브랜치에는 카드 코드가 없다(`features/chat`에 diff·changed 렌더링 없음). 존재하는 것은 `mocks/chat/get-comparison.200*.json` 3개뿐이다. 즉 지금이 "타입(`status`, 쪽별 `goalAmount`)과 칸 분기를 처음부터 넣는" 가장 싼 때다. F-4 목 JSON에는 이미 `current.status`·`current.goalAmount`가 있어 **타입 추가가 거의 없다.**
- 추가 비용: 초과 칸 컴포넌트 변형 1개 + 목표 금액 행 + 주의 문구 정적 표시 + 목 JSON 3개(`get-comparison.200-current-exceeded.json`, `…-changed-exceeded.json`, `…-goal-changed.json`) + 테스트. **≈0.5~1일**(제공자가 쓴 0.5~1일과 같다).
- 정정: 제공자 표는 3-1의 ai-server 비용을 0.5일로 적었다. `status` 통과(`_select_side`)는 **CF12-8-0 때문에 어차피 필요**(3-2에서도)하므로 **3-1 증분은 ≈0.2일**(초과 칸 프롬프트 한 문장 + 테스트 하나)이다.

---

## 2. 제공자 주장 중 동의하지 않는 것 (코드 근거)

### 2-1. "3-2는 비용이 작다" — **반대 유지, 단 거절 근거 한 건 정정**

| 내가 v1에서 쓴 근거 | 재확인 | 판정 |
|---|---|---|
| `RECALC_RESULT`에는 `calc_run_id` 필수 | `schema.sql:190-191` `ck_cm_recalc CHECK (message_type <> 'RECALC_RESULT' OR (calc_run_id IS NOT NULL AND condition_changes IS NOT NULL AND baseline_scenario IS NOT NULL))`. `agent.py:560-561`은 `turn.calc_run_id`가 있을 때만 `RECALC_RESULT`로 만든다(`:386`에서 계산 성공 시 채움). `:564-565`는 calc_run 없는 `RECALC_RESULT`를 **`ANSWER`로 내린다** | **유지** |
| "DB CHECK `ck_cm_recalc` 개정 + 새 메시지 타입이 필요하다" | `ck_cm_changes`(`schema.sql:189`)는 `condition_changes`가 NULL이거나 객체이기만 하면 되고 `ANSWER`에도 값을 막지 않는다. 즉 **`ANSWER`에 `condition_changes`를 싣는 길은 DB 변경 없이 가능하다** | **정정**: "CHECK 개정 필수"는 과장. 정확히는 *(a) `RECALC_RESULT`로 하면 calc_run이 필요해 계산을 해야 한다(=3-1), (b) `ANSWER`로 하면 DB는 되지만 계약이 막는다* |
| 새 메시지 타입 / F-5 계약 | (b)로 가도 F-5 검사 2는 "`RECALC_RESULT` 아님 → 404"(`moeun/docs/api/frontend-api.md:1045`, `:1085`), 검사 3은 "그 회원의 `COMPLETED RECALC_RESULT` 중 최대 id가 아님 → `STALE_COMPARISON`"(`:1086`), F-4도 `RECALC_RESULT`만 받는다(`:1045`). 즉 **F-4·F-5 계약 개정이 필수**이고, 적용 버튼은 F-4 `applicable`로 켜지므로 **F-4가 비교 없이 확인 카드를 돌려주는 새 응답 모양**이 필요하다 | **유지**(새 타입이 필요하다는 말은 "F-4·F-5가 `ANSWER`를 받는 새 경로" 로 바꿔 적는다) |
| D-041 충돌 | D-041은 "적용 버튼은 가장 최근 **비교 결과**에만 활성화"(`decisions.md:47`). 3-2는 비교 결과가 없는 적용이므로 문자 그대로 어긋난다 | **유지** |
| (새로 발견) **상태 없는 ai-server와 2턴 확인 흐름이 안 맞는다** | 3-2는 "목표 금액을 2,500만원으로 바꿀까요?" → 사용자 "네" 두 턴이다. 두 번째 턴 "네"에는 조건 표현도 숫자도 없으므로 `drop_carried_conditions`(`agent.py:228-230`: `if k in stated`)가 **조건을 전부 지운다**, `agent.py:383` `if not changes.changed()`로 "바꿀 조건이 없습니다" CLARIFY가 된다. D-041의 "누적 금지"가 정확히 이 구조이고 `test_no_accumulate.py`가 고정하고 있다. 3-2를 하려면 ai-server가 **이전 턴 제안값을 이어받는** 새 상태 로직이 필요하고, 그건 D-041을 뒤집는 일이다 | **가장 강한 근거로 추가** |

종합: 3-2는 Spring 0.2일이 맞더라도 **B팀에서 F-4·F-5 개정 + 이어받기 예외 + 새 카드**가 되어 3-1보다 싸지 않다. 제공자가 든 비용 비교표의 "프론트 0.3일"은 확인 카드를 새로 그린다는 전제가 빠졌다.

### 2-2. "ALREADY_EXCEEDED가 409와 200 양쪽에 있어 ai-server·프론트 분기가 갈린다" — **영향이 작다**

- ai-server: 409는 `calc.py`가 `CalcRejected`로 올리고 `agent.py:143`의 매핑을 탄다. 200 본문의 `status`는 `_select_side`가 통과시킬 뿐 **별도 채널**이다. 두 경로가 같은 분기를 공유하지 않는다. `agent.py:424·441`은 **planContext(EXPLAIN)** 쪽 `plan.result.status` 분기라 비교 응답과 무관하다.
- 프론트: `settledStatus`(`ChatWindow.tsx:112`)는 **계획 조회(`PlanView.status`)** 에서 오는 값이지 F-4 응답이 아니다. F-4의 `current.status`·`changed.status`는 카드가 읽는 새 값이라 겹치지 않는다.
- 그래서 오류 코드 체계가 "흐려진다"는 우려는 코드 이름이 같다는 사실에 그치고, 소비자가 **문자열을 해석할 일은 없다**(`status` 필드만 본다).

### 2-3. "C2-4 불변식이 3-1에서 처음 깨진다" — **이미 깨진다(제공자 조건 5와 모순)**

제공자도 3절 마지막에 "C2-4 개정은 어느 조합을 골라도 피할 수 없다"고 썼다. 그러면 3-1의 회귀 범위는 "모든 비교 응답의 불변식 변경"이 아니라 **"`current`도 같은 모양일 수 있다"는 증분**이다. 정상 응답의 `status`는 늘 `"CALCULATED"`로 키만 추가되므로 기존 fixture(a1~)는 `status` 키만 추가하면 그대로다. 실제 회귀 후보는 `computeComparison:88-92`의 분기 재배치 한 곳이다(제공자가 10줄로 추정). 고정 JSON 계약 fixture 두 개(a4 교체, a5 신설)로 가드가 된다.

### 2-4. `ConditionValues` 2필드 확장(제공자 ③) — **소비자는 필요 없다(빼도 됨)**

- `/internal/calc`의 `current`·`changed`는 `CalcResultView`라 **이미 `goalAmount`(raw)를 쪽별로 갖는다**(F-4 목 JSON 확인). 목표 금액이 바뀐 비교에서 "응답에 바뀐 목표가 안 보이는" 문제는 이미 없다.
- 모델에는 `conditions`가 **그대로** 넘어간다(`calc.py:_select_for_model`의 `for key in ("display","diff","conditions")`, internal-calc.md:279 "raw 금액은 판단용이며 인용하지 않는다"). raw 목표·보유 금액을 거기에 더하면 모델에 인용 후보가 하나 늘 뿐 소비자가 얻는 것이 없다(숫자 대조가 막기는 한다).
- 그러므로 **1단계에서는 `ConditionValues`를 4필드로 두고 internal-calc C2-3("4개 키가 항상 모두 있다")·REST Docs 스냅샷·`a4-response.json`의 `conditions` 부분을 바꾸지 않는다.** 제공자 0.5일 절감. (HELD를 2단계에 열 때 raw 보유 자산이 필요해지면 그때 `CalcResultView`나 `ConditionValues`에 더한다.)

### 2-5. `chat.heldAssetsBasis`를 `notes`로 내리자(제공자 4절 (c)) — **받을 수 없다**

v2는 이미 이 안을 폐기하고 "ai-server가 `load_copy()`로 읽는다"로 확정했다(Z-6). 확정이 옳다. 이유를 코드로 남긴다:
- `calc.py:_select_for_model`은 `("display","diff","conditions")` + `current`·`changed`만 모델·후처리로 넘긴다. **`notes`라는 새 최상위 키는 코드를 고치지 않으면 조용히 버려진다.** 받으려면 `_select_for_model`·`test_calc_client.py:379` `SELECTED_KEYS`·`:318-322`의 `set(sent) <= {…}` 단언을 전부 바꾼다.
- 문장이 Spring에서 오면 **`check_numbers` 뒤에 붙인다**는 순서 규칙(`{calcStartMonth}`가 숫자 토큰)을 ai-server가 문장 출처를 가려서 지켜야 한다. 문구표를 ai-server가 읽으면 `with_tax_note`(`agent.py:582`)와 똑같은 한 줄이다.
- 문구 본문이 Spring `copy.ko.yml`과 ai-server `load_copy()` 한 곳(같은 파일)에서 나오므로 Spring이 문장을 내릴 이유가 없다.

---

## 3. v2 "확정 21건" 중 잘못 확정된 것

| 번호 | 내용 | 판정 | 이유 |
|---|---|---|---|
| **확정 3** | `schemas.py:54-59` `DISPLAY_KEY` 개정 | **오류 1(삭제)** | 0절 1. `DISPLAY_KEY`는 `PlanContext.display`만 거른다. 비교 display는 거르지 않는다. 개정해도 효과가 없고, 안 해도 깨지지 않는다. CF12-4-2·CF12-8-3 1항·Z-10도 같이 지운다 |
| 확정 3(같은 줄) / 제공자 ③ | "ai-server `ComparisonResponse` 스키마" | **오류 2(삭제)** | 그런 클래스가 없다(2-4와 0절) |
| **확정 19 / CF12-13 개정 3** | `chat.unchangeableCondition`에서 "입력 수정에서 바꿀 수 있어요"를 **빼고** "여기서는 바꿀 수 없어요"로 끝낸다 | **오류 3(1단계 B안에서 틀림)** | B안이면 **보유 자산은 여전히 입력 수정으로만** 바꾼다(D-035, 입력 수정 버튼도 존속). 이 문구가 닿는 대상은 목표 종류·기존 납입액·**보유 자산**이다. 보유 자산을 빼고 끝내면 **막다른 길이 하나 새로 생긴다**(v2 §X-B가 스스로 쓴 "작은 막다른 길"). 1단계 본문: "목표 종류·기존 납입액은 여기서 바꿀 수 없어요. 보유 자산은 입력 수정에서 바꿀 수 있어요"(보유 자산 대화 변경은 2단계에서 문구 개정) |
| **확정 8 + CF12-8-2** | `changed` 초과 시 적용 버튼 활성 + "적용하면 초과" 한 줄 | **수정**(문구 주체) | 한 줄을 **프론트 정적 + ai-server 코드 덧붙이기**로 못 박는다(C-7). 모델에 "이런 문장을 만들라"로 맡기는 것은 확정 14(고정 문장은 코드)와 모순이다 |
| 확정 10 | 배포 순서 Spring → ai-server → 프론트 | **보강** | **문구 본문 개정(`chat.alreadyExceeded`·`unchangeableCondition`·`result.alreadyExceeded`·`features/chat/copy.ts:5`)은 ai-server가 6(5)키를 켜는 PR과 같은 날 함께 나간다.** 문구가 "대화로 목표 금액을 바꿔 보세요"를 먼저 말하면(Spring `CopyBook` 선배포) 가리킨 곳이 아직 안 된다. 프론트·ai-server의 상대 순서는 무관하다(F-4는 Spring이 먼저 새 모양을 내면 프론트가 읽는다) |
| 확정 15 | `chat.heldAssetsBasis`는 display 키가 아니고 ai-server가 문구표에서 읽는다 | **수용(옳음)** | 2-5. 제공자의 `notes` 안은 받을 수 없다 |
| 확정 18 | 테스트 fixture 깨짐 명시 | **수정** | "ai-server fixture"에서 `ComparisonResponse` 스냅샷을 뺀다(없음). 실제는 `ai-server/tests/test_calc_client.py`의 fake 응답 dict와 `docs/api/examples/.../field-not-changeable-response.json`(`field: goalAmount` → 다른 키)이다 |
| 확정 12 | 단위 자동 보정 금지·범위 검증은 Spring 한 곳 | 수용 | |
| 확정 1·2·4~7·9·11·13·14·16·17·20·21 | | 수용 | 코드와 일치하는 것을 확인했다(확정 4: `agent.py:204-230`, 확정 5: `calc.py:_select_side`는 `scenarios[].{scenario,isAchieved}`와 `baselineScenario`·`assumptions.isDefaultSavingsRate`만 내보냄) |

추가로 **v2가 확정에 넣지 않은 것 중 수용 조건으로 올릴 것**:
- (C-1) 목표가 바뀐 비교에서 무접두어 `goalAmount` 미생성, 초과 칸에 `conditions.S.heldAssets`(B안에서도).
- (C-5) `held_assets`는 숫자 토큰이 없으면 건너뛰지 않고 CLARIFY.
- (C-6) 모르는 키는 `RECALC_RESULT`로 저장하지 않고 assistant 메시지 FAILED.
- `calc.py:_check_display`(`:105-114`)는 `scenarios`가 빈 쪽을 그대로 통과하지만, **`display`가 비면 `CALC_DISPLAY_MISSING`**(`:107`)이다. 양쪽이 초과·`display`가 목표·보유 키뿐이어도 비지 않으므로 지금 코드로 안전하지만, 이 가정을 fake 테스트 1개("한쪽 초과 + display에 시나리오 키 없음")로 고정한다.

---

## 4. 쟁점별 최종 입장 (한 줄)

| 쟁점 | 최종 입장 |
|---|---|
| **X-A** | **3-1 수용**(`current`·`changed` 각각 `status`, 한쪽 초과면 `scenarios: []`·`diff.byScenario: []`, 계산 못 하는 여전히 초과는 409 유지). **3-2는 양보 불가로 거절**(`ck_cm_recalc` `schema.sql:190-191`, F-4·F-5가 `RECALC_RESULT`만 받는 계약 `frontend-api.md:1045·1085-1086`, D-041, 그리고 `drop_carried_conditions`가 "네"를 지워 2턴 확인이 안 선다). **C안(아무 것도 안 함)은 수용 불가**(문구가 가리킨 곳이 안 된다). 단 사람이 3-2를 골라도 CF12-8-0(`status`)은 필수다 |
| **X-B** | **B안(목표 금액만) 수용.** 양보 불가: ① `held_assets`를 열기 전에 `check_amount_units`(C-5 기준 셋) ② T-13(버튼 제거)은 2단계 완료 뒤 ③ 1단계 `chat.unchangeableCondition`에 "보유 자산은 입력 수정에서" 유지 ④ `_GOAL`·`_HELD` 정규식은 1단계에 |
| **X-C** | **A안(둘 다 열기) 수용**(보류 철회). 프론트 비교 영역은 만들지 않고 Should 유지 |
| **X-D** | **C 혼합 수용.** 소비자 쪽 대상: #21·#18 reopen, #23은 테스트만 흡수, #53·#132는 OPEN 본문 수정. 이력 보존이 필요한 **#21(4키 축소를 되돌림)** 은 reopen이 맞다 |
| **X-E** | **A안(모르는 키 저장 실패) 수용**, 단 **"저장 실패 = 메시지 `FAILED`·`RECALC_RESULT`로 저장하지 않음"** 으로 한정한다. 새 문구 키 없음(`chat.failed` 재사용). 트랜잭션 범위는 A팀이 확정 |

---

## 소비자 쪽에서 꼭 필요한 것

1. 쪽별 `status`(`/internal/calc`·F-4 둘 다), 초과 칸 `scenarios: []`, 한쪽이 초과면 `diff.byScenario: []`.
2. display 키: `conditions.current.goalAmount`·`conditions.changed.goalAmount`(목표가 바뀐 비교), **초과인 쪽의 `conditions.S.heldAssets`**(B안 포함), 목표가 바뀐 비교에서 **무접두어 `goalAmount` 미생성**. `DISPLAY_KEY` 개정은 필요 없다.
3. 문구: 신규 4(`condition.goalAmount`, `chat.goalAmountChangedNote`, `chat.changedAlreadyExceeded`, `chat.cardAlreadyExceeded`) + 개정 3(`chat.alreadyExceeded`는 "더 높게", `chat.unchangeableCondition`은 **보유 자산 입력 수정 유지**, `result.alreadyExceeded`). 문구 개정은 ai-server 활성화와 같은 날.
4. ai-server: `_select_side`의 `status` 통과, `drop_carried_conditions`·`_stated_conditions`에 `_GOAL`·`_HELD`(1단계), `chat.changedAlreadyExceeded`·`chat.goalAmountChangedNote`를 코드가 `check_numbers` 뒤에 덧붙임.
5. HELD(2단계) 진입 조건: `check_amount_units` 15행 이상·고정 JSON 2건·2주차 말, `held_assets`는 숫자 토큰 없으면 CLARIFY.
6. 모르는 키 → assistant 메시지 FAILED(`RECALC_RESULT` 저장 금지).
7. 테스트용 고정 JSON: ai-server `recalculate` 응답 3개(현재 초과 / 변경 초과 / 목표 변경), 프론트 `get-comparison.200-*.json` 3개, 계약 fixture a4 교체·a5 신설.

## 빼도 되는 것

- **`CalcComparison.ConditionValues` 2필드 확장과 그에 딸린 REST Docs 스냅샷·internal-calc C2-3 개정**(1단계, 제공자 0.5일 절감). 쪽별 `goalAmount`는 `CalcResultView`에 이미 있다.
- **`DISPLAY_KEY` 정규식 개정**과 `ComparisonResponse` 스키마 언급(없는 코드).
- 제공자의 `notes` 필드(확정 15로 이미 폐기, 받을 코드도 없다).
- `comparable` 플래그, `achievementChange` null 숨김, `TOO_MANY_CHANGES` 문구(v2에서 이미 뺌).
- 3-2 전체(`ANSWER` 확인 흐름).
- 1단계의 `held_assets` 도구 키·`condition.heldAssets`·`chat.heldAssetsBasis`·카드 보유 자산 행·비교 `calcStartMonth`.
