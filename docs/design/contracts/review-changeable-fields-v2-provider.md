# 제공자(A팀 Spring) 재검토 — 계약 개정 v2 (CF12), 마지막 라운드

- 검토: contract-provider(A팀 Spring: calc·plan·auth), 2026-11-20
- 읽은 것: v2 전문, 소비자 1차 검토, `../moeun` `feature/126-input-suggestion`·`origin/develop`(읽기만 함. switch·fetch·수정 없음), `gh` Issue/PR 조회
- **결론 한 줄: v2 수용. 그리고 §X-A에서 내 v1 권고(3-2)를 철회하고 소비자와 같은 A) 3-1로 옮긴다.** 코드를 다시 재어 보니 3-1의 Spring 쪽 추가분이 v1 추정(+1.5일)의 **1/3 이하**이고, v1이 든 회귀 근거 세 개 중 **두 개가 사실이 아니었다.**

---

## 0. 판정

| | |
|---|---|
| 판정 | **수정하면 수용** (수정은 아래 2절의 확정 오류 4건 정정 + §X-E 범위 명시) |
| X-A | **A) 3-1로 입장 변경**(v1의 3-2 권고 철회) |
| X-B | B) 목표 금액만 — v1과 같음(이견 없음) |
| X-C | A) 둘 다 — v1과 같음 |
| X-D | C) 혼합 수용 |
| X-E | A) 저장 실패 — 단 **"메시지 저장 실패 = 그 턴 실패"**이고, 이 코드는 chat 모듈(team:B)이 아직 **쓰지 않았다** |

---

## 1. P-1~P-7 답

### P-1 — X-A: **3-1(A안)로 옮긴다.** v1 권고 철회

v1에서 3-2를 권한 근거는 세 개였다. 코드로 다시 재어 보니 **(1)은 v2 지적대로 성립하지 않고, (2)·(3)은 애초에 사실이 아니었다.**

| v1 근거 | 재측정 결과 |
|---|---|
| (1) "성공 응답 불변식(C2-4)을 안 깬다" | **성립 안 함.** v2 CF12-8-0 그대로. (C)만 받아도 깨진다 |
| (2) "`ALREADY_EXCEEDED`가 409와 200 양쪽에 생겨 ai-server `agent.py:143·424·441`을 고쳐야 한다" | **틀렸다.** `:143`의 `_FIXED_COPY_KEYS`는 **Spring이 409로 거절한 코드 → 문구 키** 매핑이고, 3-1 뒤에도 409는 그대로 남는다(목표를 올려도 여전히 초과인 경우 = D-071 잔여 범위). **수정 0줄.** `:424`·`:441`은 `check_plan_context`의 **EXPLAIN 모드 planContext 분기**이고 비교 응답을 보지 않는다. **수정 0줄** |
| (3) "프론트 `settledStatus`가 성공 응답 안의 `ALREADY_EXCEEDED`를 기대하지 않는다" | **틀렸다.** `settledStatus`는 `planStore`의 **계획 결과(F-3/결과 화면)** 상태이고 비교 응답과 무관하다(`frontend/src/api/__tests__/planStore.test.ts:157` AC-15). 비교 카드는 아직 없다(#53 in-progress) |

더해서 v1·v2가 둘 다 몰랐던 **더 센 사실 두 개**:

1. **`CalcResultView`에 `status` 필드가 이미 있다.** `backend/.../calc/CalcResultView.java:21`
   ```java
   public record CalcResultView(CalcStatus status, long goalAmount, YearMonth calcStartMonth, ...)
   ```
   `InternalCalcResponse`는 `current`/`changed`를 이 View로 내보내므로(`web/InternalCalcResponse.java:21-28`) **`/internal/calc` 성공 응답에는 이미 `current.status`·`changed.status`가 들어 있다.** F-4(`ChatComparisonView`)도 같은 `CalcComparison`을 그대로 담는다. → **CF12-8-0의 "status를 담는다"는 Spring 쪽에서 코드 변경 0, javadoc 한 줄(`:11` "이 경로의 성공 응답에서는 늘 CALCULATED")과 계약 문구만 고치는 일이다.** 소비자 쪽은 타입에 필드를 더하는 일이 남는다.
2. **"한쪽이 초과일 때의 display" 개념이 이미 코드에 있다.** `ResultDisplayBuilderTest:205` "ALREADY_EXCEEDED면 goalAmount·conditions.heldAssets가 있고 시나리오 키는 없다(G-5a 불변식)", ai-server `agent.py:158` `_EXCEEDED_DISPLAY_KEYS = ("goalAmount", "conditions.heldAssets")`. 비교 경로도 **같은 두 키를 쪽별 접두어로** 내리면 되므로 새 설계가 아니다.

**3-1의 Spring 실제 추가분(3-2 대비)**

| 항목 | 일수 |
|---|---|
| `CompareConditionsUseCase:88-92` 분기 역전(`changed`를 먼저 해석한 뒤, `current` 초과 + `changed` 비초과면 통과) | 0.2 |
| `CalcEngine`·`CalcComparison.Diff.between`·`buildDisplay` | **0** (`Diff.between`은 교집합만 담아 `byScenario`가 자연히 비고, `build()`의 `for (ScenarioResult …)`가 0회 돌 뿐이다. v1에서 이미 확인) |
| 초과 쪽 `conditions.<side>.goalAmount`·`heldAssets` display | P-2 그대로 0.2(아래) |
| 계약·fixture·REST Docs(A-5 성공 예시 신설, `InternalCalcApiTest:240` 수정) | 0.3 |
| **소계 추가분** | **≈0.7일** (v1 추정 +1.5일 → 절반 이하) |

회귀 범위도 v1 추정보다 좁다. "성공 응답에서 `current.status`가 `ALREADY_EXCEEDED`일 수 있다"를 전제로 깨지는 **기존 테스트는 `InternalCalcApiTest:240` 한 건**(409를 단언)이고, `a5-already-exceeded.json`은 **이미 있다**(409 오류 fixture). 나머지 `ALREADY_EXCEEDED` 단언 23곳은 모두 **단일 계산(결과 화면·planContext·골든 G3)** 경로다.

**소비자가 든 3-2의 비용은 사실로 확인했다.** `schema.sql:190-191`
```sql
CONSTRAINT ck_cm_recalc CHECK (message_type <> 'RECALC_RESULT'
      OR (calc_run_id IS NOT NULL AND condition_changes IS NOT NULL AND baseline_scenario IS NOT NULL)),
```
계산을 안 하면 `calc_run`이 없고 → `RECALC_RESULT`로 저장할 수 없다. `ck_cm_type`(`:184`)에도 쓸 수 있는 타입이 없다. 즉 3-2는 **DB CHECK 개정 + 새 메시지 타입**이 맞다. 그건 chat 모듈(아직 구현 전, team:B)과 F-5 적용 경로(`PlanApplyService`, A팀)가 **둘 다** 바뀌는 일이라 A팀 몫도 0.2일이 아니다.

> **결론: 두 팀 합계로 3-1 < 3-2다. 제공자는 A) 3-1을 지지하고, 3-1을 "데모 이후로 분리"하자던 v1 요청도 철회한다.**
> 다만 **3-1을 받으려면 ai-server 쪽 선행 하나가 더 필요하다**(v2에 없다): CHAT 모드에서는 초과 계획이어도 ai-server가 `/internal/calc`를 부르므로 지금 흐름 자체는 산다. 그런데 `prompts.py:53-54`가 **"status가 ALREADY_EXCEEDED이면 … 초과 금액은 말하지 않습니다"** 를 **단일 결과 기준으로** 적고 있어, 비대칭 2칸에서 모델이 양쪽 중 어느 status를 보는지 애매하다. 프롬프트 규칙 9를 **쪽별로** 다시 쓰는 것을 T-8 범위에 명시해야 한다.

### P-2 — display 키 이름: **소비자·v2 안(`conditions.current.goalAmount`)을 받는다.** 내 v1 안 철회

코드를 보면 이건 취향 문제가 아니라 **한쪽이 거의 공짜다.**

`ResultDisplayBuilder.build`는 이미 **조건 접두어를 인자로 받는다**:
```java
public Map<String, String> build(CalcInput input, CalcResult result, String resultPrefix, String conditionPrefix)
```
그리고 `CompareConditionsUseCase:33-36`에 `CONDITIONS_CURRENT = "conditions.current."`, `CONDITIONS_CHANGED = "conditions.changed."`가 **이미 상수로 있고 호출부가 넘긴다**(`:128-130`).

- **`conditions.<side>.goalAmount` 안**: `putConditions(...)`에 `display.put(prefix + "goalAmount", …)` **한 줄**. `heldAssets`는 같은 메서드의 `if (isSingleResult)` 가드를 푸는 것뿐이다. 새 접두어 개념 0, `CompareConditionsUseCase` 수정 0.
- **`current.goalAmount`(내 v1 안)**: `goalAmount`를 결과 접두어 쪽으로 옮기는 일이라 단일 경로의 키 이름(`goalAmount`)과 비교 경로가 **다른 계열**이 되고, `ResultDisplayBuilder` 클래스 주석의 키 규칙 3줄을 다시 쓰고 `_CALCULATED_DISPLAY_KEYS`/`_EXCEEDED_DISPLAY_KEYS`(단일 경로)와 어긋날 위험이 생긴다. **더 비싸다.**

→ **`conditions.current.goalAmount` / `conditions.changed.goalAmount`(+ 2단계에서 `…heldAssets`)로 합의한다.**

정규식 비용에 대한 정정: **`DISPLAY_KEY`(`ai-server/app/schemas.py:54-59`)는 비교 display를 거르지 않는다.** 그건 planContext(C1a-8) 전용 필터이고, `/internal/calc` 응답은 `tools/calc.py:_select_for_model:96-98`이 `display`를 **통째로 통과**시킨다. 따라서 정규식 개정이 필요한 경우는 **단일 경로에 `conditions.goalAmount`가 새로 생기는 때뿐**이고, 그때 `conditions\.(?:goalAmount|heldAssets|…)` 한 단어를 더하면 끝이다. (안 더하면 **조용히 버려진다** — `_keep_allowed_display`가 필터다. 이 한 줄은 꼭 범위에 넣어야 한다.)

초과 쪽 display와 `isSingleResult` 충돌: **없다.** 초과 쪽은 `result.scenarios()`가 빈 목록이라 시나리오 키만 안 생기고, `putConditions`는 그대로 돈다. 내가 할 일은 `heldAssets`의 `isSingleResult` 가드를 2단계에 푸는 것과 `goalAmount` 한 줄뿐이다.

### P-3 — 서버 쪽 중복 검증: **맞다. 두지 않는다.**

- D-033(범위 검증은 Spring 한 곳) 유지에 동의. `check_amount_units`는 "모델 출력 ↔ 발화 대조"이고 **범위 검증이 아니다.** 성격이 다르므로 중복이 아니다.
- `GOAL_AMOUNT min 10000 / max 1e10`, `HELD_ASSETS min 0 / max 1e10`(`resources/config/rules.yml:9·11`)을 **그대로 둔다.** 비정상 값 경고 규칙(예: "목표가 너무 작다")은 **만들지 않는다.** 근거: 그건 `rules.yml` 밖의 새 판정 규칙이고, 금액의 "정상 범위"를 서버가 추측하는 순간 PR-04(숫자 일치)·FR-AI-02의 경계가 흐려진다. 3주 밖.
- 단 한 가지 **기록 요청**: Spring은 `check_amount_units`가 돌지 않은 값도 그대로 받는다(공유 비밀 헤더만 보는 내부 경로). 즉 **단위 사고의 최종 방어선은 (c) 카드 확인뿐**이라는 사실을 결정에 적어 두자. 제공자가 더 할 수 있는 일은 없다.

### P-4 — `max-fields`: **6으로 둔다.**

X-B가 B안(목표 금액만)이면 CHAT 허용은 5필드가 된다. 그래도 **6을 권한다.**
- 근거: `ConditionValidator.validateChanged:83-86`은 `maxFields()`보다 **`pathRule.allows(field)`를 따로 본다.** 허용 밖 키는 `FIELD_NOT_CHANGEABLE`로 **개별 거절**되므로, `max-fields`가 5든 6이든 2단계 전에는 `heldAssets`가 통과하지 못한다. 즉 "허용 5 < max 6"은 **가드 구멍이 아니다**(v2가 걱정한 "가드 논리 약화"는 실제로 일어나지 않는다).
- 그리고 `max-fields` 분기는 지금도 **도달 불가**하다(허용 = max). 5로 두면 2단계에서 yml을 또 고치고 `PlanRulesTest`·계약 문서를 두 번 만진다.
- 6으로 두면 `rules.yml` CHAT·COMPARE 두 줄을 **이번에 한 번만** 고친다. `TOO_MANY_CHANGES`는 계속 비활성이고 문구·프론트도 그대로 없다(`CopyBook.java:50`에 코드 없음 — v1에서 확인).

### P-5 — X-E: **A) 저장 실패.** 단 범위와 소유를 바로잡아야 한다

**먼저 사실 정정(v2가 "현상 추정"으로 적은 것):** chat 리스너의 "4키 고정 맵"은 **아직 코드에 없다.**
`backend/src/main/java/com/moeun/backend/chat/`에는 `package-info.java` **한 파일뿐**이고, `origin/develop`도 같다(`git ls-tree -r origin/develop backend/src | grep -i chat` → `calc/ChatComparisonQuery.java`, `calc/ChatComparisonView.java`, `chat/package-info.java`). #41은 CLOSED지만 그 코드는 develop에 없다. 저장·F-4·F-5는 **#44·#45·#128(모두 OPEN, `team:B`, `area:backend`)** 이 앞으로 쓴다.
→ **X-E는 "기존 동작을 바꾸는 일"이 아니라 "아직 안 쓴 코드의 설계를 정하는 일"이다. 비용 ≈0이고, 소유도 A팀이 아니라 B팀의 Spring 코드다.** v2의 "제공자 확인이 필요하다"는 전제 자체를 이 사실로 바꿔야 한다.

그 전제에서 세 질문 답:

1. **트랜잭션**: 저장과 ai-server 호출은 **같은 트랜잭션이 아니다.** `chat/package-info.java`가 "메시지를 영속 저장하고 ai-server POST /chat을 **비동기로** 호출한다. 내부 이벤트: `ChatAnswerRequested` → ai-server 호출 후 **PENDING을 COMPLETED/FAILED로** 바꾼다"로 모듈 구조를 못 박아 두었다. 즉 **USER 질문 저장과 턴 응답은 이미 분리**되어 있고, ASSISTANT 메시지는 `PENDING`으로 먼저 생긴 뒤 갱신된다.
   → **"모르는 키 → 저장 실패"는 턴 전체 500이 아니라 그 메시지를 `FAILED`로 두는 모양이 자연스럽다.** 사용자는 FR-AI-04의 기존 실패 안내(`chat.failed`)를 보고, **새 문구 키가 필요하지 않다.** 이게 소비자 C-6의 "턴은 성공시키고 메시지만 FAILED" 쪽이고, 제공자도 이걸 권한다.
2. **#132 뒤라면 "모르는 키 → 예외"가 자연스럽나**: 그렇다. 지금 `PlanContextProviderImpl.toOverride`(`:168-172`)가 이미 똑같이 한다 —
   ```java
   if (!CHANGEABLE_KEYS.contains(entry.getKey())) {
       throw new IllegalArgumentException("condition is not changeable: " + entry.getKey());
   }
   ```
   그리고 **F-4는 이 동작을 이미 계약에 담고 있다**: #44 본문 "타입 변환 실패나 허용 4키 밖의 키가 저장된 메시지는 `500 INTERNAL_ERROR`". 즉 **읽기 쪽이 이미 fail-closed다.** 쓰기 쪽만 "조용히 버린다"로 두면 **같은 데이터에 대해 쓰기는 통과·읽기는 500**이라는 가장 나쁜 짝이 된다. → A안은 일관성 쪽으로도 맞다.
3. **제공자 권고: A).** 범위를 다음 한 문장으로 계약에 적자.
   > chat 리스너가 `condition_changes`를 camelCase로 바꿀 때 **맵에 없는 키가 하나라도 있으면 그 키만 버리지 않고 변환을 실패로 보고 그 ASSISTANT 메시지를 `FAILED`로 남긴다**(`condition_changes`만 비우지 않는다. 부분 저장 금지). 사용자에게는 기존 `chat.failed` 안내가 나간다. USER 질문 메시지는 이미 저장되어 있어 대화 기록이 끊기지 않는다.
   - **`condition_changes`만 비우는 변형(부분 저장)은 반대한다.** 그러면 `ck_cm_recalc`(`schema.sql:190`)가 `RECALC_RESULT`에 `condition_changes NOT NULL`을 요구하므로 **DB가 거절**하고, 애플리케이션이 "성공했다고 믿는 저장이 DB에서 터지는" 모양이 된다. 메시지 단위 FAILED가 유일하게 깨끗하다.

### P-6 — #132: **선행 요구는 유지하되, 일정 조건부로 완화한다**

`gh` 재확인(2026-11-20):
- #132 `OPEN`, `status:in-progress`, 담당 `01tjdus`, `updatedAt 2026-11-20T02:27Z`.
- **열린 PR이 하나도 없다**(`gh pr list --state open` → 비어 있음). `origin`에 132 관련 브랜치도 없다(`origin/feature/126-input-suggestion`만).
- develop 최신은 `ed9c9d3 feat(plan): 적용 공개 API …(#33)(#122)`. 즉 **#132는 아직 작업물이 나오지 않았다.**
- 코드로도 확인: `calc/application/`에 `ConditionChanges.java`가 **없다.**

대안 일정:
- **권고(변경 없음)**: #132를 먼저 머지한다. #132 본문 수용 기준이 "`/internal/calc` 응답이 바뀌지 않는다"라 **4키 기준으로 끝내야 리뷰가 쉽다.** 6키 확장과 섞으면 "동작 변경 없음"을 단언할 수 없다.
- **#132가 이번 변경보다 늦어질 조짐이면**: 순서를 뒤집지 말고 **#132를 이번 변경에 흡수**한다(= #132를 닫고 신규 `[calc] 대화 조건 6필드 배선`에 "변환기 한 곳으로 모으기 + 6키"를 함께 넣는다). 각각 고치고 나중에 합치는 쪽은 **반대**: 고칠 곳이 `InternalCalcController:39-42`+`:86-110`, `PlanContextProviderImpl:47-53`+`:168-181`, 그리고 아직 안 쓴 chat 리스너 **세 곳**인데, 세 곳을 6키로 넓힌 뒤 합치면 "세 곳의 6키 동작이 서로 다르지 않다"를 증명하는 테스트를 두 번 쓴다.
- 판단 시점: **#132 PR이 올라오지 않은 채 하루가 더 지나면 흡수 쪽**으로 가자(사람이 정한다).

### P-7 — X-D: **C) 혼합 수용.** 단 두 곳 수정

v2 추천(reopen 3건 + 신규 1건 + OPEN 2건 본문 수정)이 A팀 추적에 맞다. 두 가지만 바꿔 달라.

1. **신규 `[calc] 대화 조건 6필드 배선`의 선행에 #132를 적되, "흡수 가능"도 함께 적는다**(P-6의 대안 일정).
2. **X-A가 3-1이므로 v2 규칙 4의 신규 Issue(`[calc] C2-4 불변식 개정 — current/changed status`)는 필요 없다.** 이유: P-1에서 확인했듯 `CalcResultView.status`가 **이미 응답에 있다.** 남은 일은 (a) javadoc·계약 문구, (b) `CompareConditionsUseCase` 초과 분기, (c) 초과 쪽 display, (d) fixture·REST Docs 뿐이고 **전부 `[calc] 대화 조건 6필드 배선`과 같은 파일**이다. 단독 Issue로 쪼개면 같은 파일을 두 PR이 건드린다. → **T-6을 신규 1건에 그대로 두고, 본문에 "C2-4 불변식 개정" 수용 기준 3줄을 넣는다.**
3. (유지) #51(T-13)은 건드리지 않는다. 다만 X-B가 B안이면 **T-13의 선행은 "2단계(HELD_ASSETS) 완료"** 라는 v2 조건에 전적으로 동의한다.

---

## 2. v2의 "확정" 21건 중 잘못 확정된 것

중대한 것 2건, 문구 정정 2건.

### (가) CF12-8-0 — "**`status`를 담는다**"를 **새 작업처럼** 적은 것 (과대 확정)

`CalcResultView.java:21`에 `status`가 **이미 있고** `InternalCalcResponse`가 그걸 내보낸다. F-4도 `CalcComparison`을 그대로 담으므로 같다. → **"응답에 담는다"가 아니라 "이미 담겨 있으니 계약·javadoc의 '늘 CALCULATED'를 지우고, 소비자 타입에 필드를 더한다"로 고쳐야 한다.** 그대로 두면 A팀 작업 추정과 Issue 수용 기준이 실제보다 커진다(P-7-2와 연결).

### (나) CF12-10 "chat 리스너 변환 맵(#41) — **4키 고정 맵**" (존재하지 않는 코드를 현황으로 확정)

`backend/.../chat/`은 `package-info.java` 하나뿐이고 develop도 같다. #44·#45·#128이 앞으로 쓴다. → **"#41이 이미 4키 맵으로 저장한다"가 아니라 "저장 코드는 아직 없고, #44·#45·#128이 쓸 때 6키 + 모르는 키 실패로 정한다"로 고쳐야 한다.** 이 정정으로 X-E의 비용은 ≈0, 배포 순서의 "중간 상태" 걱정도 한 겹 줄어든다(쓰기 코드가 처음부터 6키로 태어난다).

### (다) CF12-8-3-1 "**`DISPLAY_KEY` 정규식을 함께 개정**한다" (범위 과장)

`DISPLAY_KEY`는 planContext(C1a-8) 필터다(`schemas.py:84-88` `_keep_allowed_display`). 비교 display는 `tools/calc.py:_select_for_model`이 **필터 없이 통과**시킨다. → **"쪽별 키 때문에" 정규식을 고치는 게 아니라, "단일 경로에 `conditions.goalAmount`를 새로 넣을 때만" 한 단어 더한다**로 좁혀야 한다. (그리고 안 더하면 조용히 버려지니 범위에서 빼면 안 된다.)

### (라) CF12-4-4 / CF12-12 "`a5` 성공 fixture **신설**" 류 표현

`backend/src/test/resources/contract/internal-calc/`에 **`a5-already-exceeded.json`이 이미 있다**(409 오류 예시). 3-1을 받으면 **그 파일을 지우지 말고**, "`current` 초과 + `changed` 정상"의 **200 성공 예시를 별 파일로 더하고** 기존 409 예시는 "바꿔도 여전히 초과" 사례로 **의미를 다시 붙인다**(`InternalCalcApiTest:240`도 그 사례로 교체). 문구가 "신설"로만 적혀 있으면 기존 fixture가 지워질 위험이 있다.

> 그 밖의 확정 건(CF12-1·2·3, CF12-5, CF12-6 max 6, CF12-7-1·7-2, CF12-8-2, CF12-9-1·9-2·9-3·9-4, CF12-10 나머지, CF12-11, CF12-11-1, CF12-13)은 **코드와 일치한다. 이견 없음.**

---

## 3. 소비자 검토에 대한 제공자 의견 (요청한 4개 항목)

### `drop_carried_conditions` — **소비자가 맞다. 구체 사례까지 재현했다**

`agent.py:218-230` + `_stated_conditions:205-216` + `_MONTHLY:186`을 손으로 돌려 보면:

| 발화 | `_count_numbers` | `_stated_conditions` | 결과 |
|---|---|---|---|
| "목표를 1억으로 올려줘" | 1 | `{}` (0개) | `1 > 0` → **changes 그대로 유지**(지워지지 않는다) |
| "목표 2,500**만원**으로 바꿔줘" | 1(쉼표 금액 1덩이) | `{monthly_saving_amount}` (`만원`이 `_MONTHLY`에 걸린다) | `1 > 1` 거짓 → `goal_amount`가 **조용히 지워진다** |

즉 위험은 **"만원·원 같은 금액 단위가 붙은 목표 발화"** 에서 실제로 일어난다(사용자가 거의 항상 그렇게 말한다). 소비자 요구(`_GOAL`·`_HELD` 정규식 추가 + `test_no_accumulate.py` 새 행)를 **그대로 지지한다.** 다만 v2 본문에 위 "숫자 수 > 인식 조건 수면 유지" 가드가 적혀 있지 않아, **"history가 있으면 항상 지워진다"로 읽히면 과장**이다. 조건을 붙여 적자: *금액 단위 토큰이 붙은 목표·보유 발화에서, 그리고 그 발화의 숫자 덩이 수가 인식 조건 수를 넘지 않을 때* 지워진다.

### `check_amount_units` — **동의. Spring에는 대칭을 두지 않는다**(P-3)

하나만 보탠다. 소비자가 "한글 수사는 건너뛴다"고 했는데, `_KO_NUMERAL`·`_KO_MAN`(`agent.py:176-184`)이 **이미 한글 수사를 꽤 넓게 센다.** `_NUMBER`를 그대로 재사용하면 "이천오백만원"도 후보 집합에 넣을 수 있어 **건너뛰는 범위가 소비자 추정보다 좁아진다**(= 더 안전하다). 새 정규식을 처음부터 쓰지 말고 `_NUMBER`·`_KO_MAN`을 재사용하길 권한다(비용도 준다).

### 배포 순서 — **소비자가 맞다. 내 v1 근거는 유지된다**

`PlanContextProviderImpl:168-172`가 허용 밖 키에 `IllegalArgumentException`을 던지는 것은 그대로다. **Spring → ai-server → 프론트** 순서에 전적으로 동의한다. 다만 (나)의 정정 때문에 "ai-server가 먼저 6키를 저장해 버리는" 중간 상태는 **저장 코드 자체가 없어서 지금은 일어날 수 없다.** 위험은 "#44·#45·#128이 4키로 먼저 완성되고 그 뒤 ai-server가 6키를 보내는" 쪽으로 옮겨 간다. → **#44·#45·#128 본문에 "맵은 6키, 모르는 키는 메시지 FAILED"를 처음부터 넣자**(X-E A안과 같은 작업).

### F-4 500 설명 — **소비자가 맞고, 제공자 쪽 사실과 일치한다**

#44 본문 "타입 변환 실패나 허용 4키 밖의 키가 저장된 RECALC_RESULT → `500 INTERNAL_ERROR`(`detail`에 내부 메시지 없음)"는 `PlanContextProviderImpl.toOverride`의 `IllegalArgumentException`이 그대로 드러난 것이다. **이 500은 "버그"가 아니라 의도된 fail-closed다.** 따라서 "허용 4키"를 6키로 넓히는 일(T-5)을 **ai-server 배포보다 먼저** 하는 것이 유일한 요건이고, 소비자 서술에 고칠 것이 없다.

### 소비자 주장 중 **동의하지 않는 것** (2건, 둘 다 작다)

1. **"`chat.heldAssetsBasis`를 Spring display의 문구 키로 내리는 것은 빼도 된다 / Spring은 `calcStartMonth` display만 추가하면 된다"** — 결론은 같지만 **전제가 틀렸다.** 비교 경로 display에는 `calcStartMonth`가 **없고**(`ResultDisplayBuilder.build`의 `if (isSingleResult)`), 그걸 추가하는 것은 C2-6이 *"비교에서는 `calcStartMonth`·`heldAssets`·`assumptions`를 만들지 않는다 — 비교 답변이 세율·기준월을 인용하지 않게 하려는 것"* 이라고 **의도적으로 정한 규칙을 되돌리는 계약 개정**이다(클래스 주석에 이유까지 적혀 있다). "Spring은 한 줄만"이 아니라 **C2-6 개정 + 그 규칙이 막던 위험(비교 답변이 기준월·세율을 인용)을 프롬프트로 다시 막기**까지가 범위다. → 2단계(X-B B안)로 미루는 결론은 그대로 지지하되, **비용을 "display 한 줄"로 적지 말자.**
2. **"3-1 수용 조건 3: 초과 칸 display는 `result.alreadyExceeded`를 쓴다"** — `result.alreadyExceeded`는 **결과 화면 문구**다(`CopyBook.java:40`, 자리 `goalAmount`·`heldAssets`). 비교 카드의 한 칸에 결과 화면 문구를 재사용하면 "내 계획 화면으로 간 것 같은" 문장이 카드 안에 들어온다. **`chat.` 계열 키**(예: `chat.currentAlreadyExceeded`)로 #18에서 따로 뽑길 권한다. 제공자가 내려 줄 display 키 목록(`conditions.<side>.goalAmount`, 2단계에 `…heldAssets`)은 어느 쪽이든 같으므로 **계약 영향은 없다**(문구표 쪽 의견).

---

## 4. 쟁점 최종 입장 (한 줄씩)

| 쟁점 | 제공자 최종 입장 |
|---|---|
| **X-A** | **A) 3-1 수용**(v1의 3-2 권고 철회). Spring 추가분 ≈0.7일, v1이 든 회귀 근거 2개는 사실이 아니었다. **B) 3-2는 이제 반대**(`ck_cm_recalc`·새 메시지 타입은 A팀 몫도 늘린다). C) 무조치는 제품 목적의 절반을 버리므로 반대 |
| **X-B** | **B) 목표 금액만** 지지(v2 조건 2개 포함). A) 둘 다여도 구현한다(+1.0일). **양보 불가: A)를 고르면 C2-6 개정(비교 display `calcStartMonth`·`heldAssets`)이 범위에 들어온다 — "display 한 줄"이 아니다** |
| **X-C** | **A) 둘 다** 지지(yml 2줄, 추가 비용 0, 지금 깨질 것 없음). B)여도 수용. 단 어느 쪽이든 `PlanService.merge` 수정은 필요하다 |
| **X-D** | **C) 혼합 수용.** 단 ① 신규 1건의 선행에 #132(흡수 가능 단서 포함) ② **v2 규칙 4의 "C2-4 불변식" 단독 Issue는 만들지 않는다**(같은 파일, status는 이미 응답에 있다) |
| **X-E** | **A) 저장 실패 — 범위는 "그 ASSISTANT 메시지를 FAILED", 턴 전체 500 아님.** `condition_changes`만 비우는 부분 저장은 **양보 불가로 반대**(`ck_cm_recalc`가 DB에서 터진다). 그리고 이 코드는 아직 없고 소유는 B팀(#44·#45·#128)이다 |

---

## 5. 제공자 쪽 양보 불가 (v1에서 이어지는 것 + 이번에 추가)

1. **`InternalCalcController.CHANGEABLE_KEYS`(`:39-42`)와 `validate(...)`(`:86-110`), `PlanContextProviderImpl.CHANGEABLE_KEYS`(`:47-53`)·`toOverride`(`:168-181`)를 변경 범위에 명시한다.** 이 Set들은 `rules.yml`을 읽지 않는다. 빠지면 yml 변경이 무효(CHAT)거나 F-4가 전부 500이다. (v1과 같음)
2. **배포 순서 Spring → ai-server → 프론트.** (v1과 같음)
3. **`conditions.<side>.goalAmount`로 display 키를 쪽별 분리한다.** 분리하지 않으면 `buildDisplay`(`CompareConditionsUseCase:128-130`)가 current 값을 **조용히 덮어쓴다**. (v1과 같음, 이름만 소비자 안으로 양보)
4. **단일 경로에 `conditions.goalAmount`를 넣으면 `DISPLAY_KEY` 정규식에 그 단어를 같은 PR에서 더한다.** 안 더하면 planContext에서 조용히 버려진다.
5. **C2-4 불변식 개정은 어느 선택지에서도 범위에 넣는다.** (v2 CF12-8-0 동의. 단 "status 추가"는 문서 작업이다)
6. **범위 검증은 Spring 한 곳(D-033), 단위 자동 보정 금지.** (v1·v2·소비자 모두 같음)
7. **X-E에서 부분 저장(`condition_changes`만 비움) 금지.**

## 6. 양보 가능한 것

- **X-A**: 사람이 C)를 고르면 따른다(그때는 `chat.alreadyExceeded` 문구도 "대화로 바꿔 보세요"로 고칠 수 없다는 사실을 함께 기록해야 한다).
- **X-B**: A) 둘 다여도 구현한다. 2단계 분리는 선호일 뿐이다.
- **X-C**: CHAT만이어도 수용.
- **X-D**: reopen 11건 전부여도 따른다.
- **#132 선행**: PR이 늦으면 "#132를 이번 변경에 흡수"로 바꾸는 것까지 수용. **각각 고치고 나중에 합치는 안만 반대.**
- **문구 전달 경로**: `chat.heldAssetsBasis`를 ai-server가 문구표에서 읽는 소비자 안 수용(Spring은 자리 값만 내린다).
