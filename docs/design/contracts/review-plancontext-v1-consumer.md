# planContext 계약 v1 소비자 검토 (moeun #11, C-1a)

> 검토자: 소비자(B팀: ai-server, Spring chat, 프론트 대화창) 관점. 2026-11-16. 대상: `docs/design/contracts/plan-context-v1.md`. 파일은 고치지 않았다.
> 근거: `moeun/ai-server/app/schemas.py`(`ApiModel`, `ChatRequest.plan_context: dict[str, Any]`), `app/llm/agent.py`(`build_messages`가 `json.dumps(req.plan_context or {})`로 통째 삽입, `run()`의 EXPLAIN 검사는 `calc_run_id is None`만), `app/llm/prompts.py`, `app/main.py`(AgentError: BAD_REQUEST만 400, 나머지 502, 본문 `{"error": CODE}`), `tests/test_agent.py`(FakeClaude/FakeCalc), `internal-calc.md` 최종본(C2-4·C2-6·C3-3·C3-4), `decisions.md`(D-022·030·033·040·041·045·055·056), `srs.md`(FR-AI-01·02·06·09, FR-RES-01·06, NFR-INT-01·03).
> 숫자 검증: 부록 A-1~A-3의 원금·세후자산·차이 산식과 만원 반올림은 모두 서로 맞는다(1,580=500+30×36, 1,845−1,580=265 등). fixture 값 자체는 문제 없다.

## 판정: 수정하면 수용

방향(raw 금액을 모델에 안 넘기고 display만 인용, 패턴 필터, 타입 모델)은 소비자가 원하던 것이다. 다만 아래 4가지는 고쳐야 LLM이 계산·추정하게 되는 구멍이 닫힌다.

1. **상대 표현("월 10만원 더") 구멍**: raw `conditions`를 모델에 안 주면서 recalculate 인자(원 단위 절대값)를 만들 재료가 `약 N만원`(반올림) 문자열뿐이다(아래 H-1).
2. **display 누락 방어가 `afterTaxAsset`만 검사**: `gapToGoal`만 빠지면 모델이 `goalAmount`와 `afterTaxAsset`을 보고 직접 뺀다(C1a-8, H-2).
3. **금액 0원·1만원 미만 형식 미정**: `heldAssets=0`(보유 자산 없음)은 흔한 입력이고 `약 0만원`이 나온다(R-7, H-3).
4. **세율·excludedItems·수익률 질문의 출처**: 모델이 기억으로 숫자를 말하게 된다(H-4~H-6).

## 항목별 의견

- [C1a-1 목적·범위] **수용** — `ChatRequest.plan_context` 위치 그대로, EXPLAIN·QUESTION 공용, 비교는 `/internal/calc`가 맡는 구분은 D-022·D-041(기준은 항상 내 계획)과 맞는다. 수정안: 없음.

- [C1a-2 최상위 구조] **수정** — `result`를 `CalcResultView`와 공유하는 것은 수용(R-5a). 다만 두 가지 정정. (1) `internal-calc.md` C2-4는 "`status`는 항상 `CALCULATED`", "소비자가 안 쓰는 필드: `status`, `assumptions.excludedItems`"라고 적었는데 이 계약은 `ALREADY_EXCEEDED`를 허용하고 `excludedItems`를 모델에 넘긴다. ai-server가 하나의 pydantic 모델을 공유하면 `status: Literal["CALCULATED"]`로 만들지 말고 enum 둘 다 받아야 한다. 최종본 문장을 이 계약에 맞게 정정하거나 "이 계약이 우선"이라고 적을 것. (2) `calcRunId`는 EXPLAIN 일치 검사용으로 필요하니 유지.

- [C1a-3 conditions] **수정(소비자는 안 쓰지만 H-1 결정에 따라 달라짐)** — 현재 안대로면 ai-server는 `conditions` 6개 raw를 하나도 읽지 않는다(C1a-8 표). 그러면 와이어에서 빼도 소비자 손해는 없다(제공자 비용만 줄임). 반대로 H-1에서 "모델에 변경 가능한 조건 4개 raw를 준다"로 결정하면 이 객체가 필요하다. 어느 쪽이든 결정 후 확정. 6개 키가 항상 있다는 점, `savingsRateInputPct`가 실제로 쓴 금리라는 점은 수용.

- [C1a-4 result] **수정** — (1) `scenarios[]` 순서·개수 규칙, `monthlyPoints` 키 없음은 수용. (2) ai-server가 `ALREADY_EXCEEDED`에서 `scenarios=[]`일 때 "달성 여부"를 모델에 전달하지 않으므로 status만으로 분기한다. 수용. (3) `isAchieved`와 display의 `달성/미달` 라벨이 같은 판정을 따른다는 보장은 #28 몫인데, ai-server fixture 테스트에는 "라벨과 `isAchieved`가 어긋난 fixture"가 필요 없다(Spring 단위 테스트에서 잡을 것, G-5 확장). (4) `baselineScenario`는 이미 `build_messages`의 `<baseline_scenario>` 태그로 들어가므로 `<plan_context>` 안에서는 빼도 된다(중복, "빼도 되는 것" 참조).

- [C1a-5 assumptions] **수정** — (1) `taxRatePct`: R-3 참고, display 키 `assumptions.taxRatePct`(`15.4%`) 하나를 더하길 권한다(H-4). (2) `excludedItems`: R-6 참고, 코드만 주고 모델이 풀어 쓰는 방식은 반대(H-5). (3) `scenarioMethod`도 코드만 오므로 같은 문제: 모델이 `ROLLING_DISTRIBUTION`을 사용자 말로 풀어쓸 때 근거가 없다(TBD-01 미결). 문구표 키(`scenarioMethod.<CODE>`)로 같이 해결할 것. (4) `savingsRatePct`/`savingsRatioPct` 중복 필드는 소비자 쓰임 없음.

- [C1a-6 display] **수정** — C2-6 재사용·접두어 제거·추가 4키는 수용. 아래를 더한다. (1) **금액 0원·1만원 미만**: `afterTaxGain`이 4,000원이거나 `heldAssets=0`이면 `약 0만원`이 된다. D-055는 차이·목표 대비만 정했다. `0원`(R-7)과 함께 **0원이 아닌데 만원 단위로 0이 되는 금액은 `1만원 미만`** 형식을 #28에서 같이 고정(H-3). (2) 금액 키 공통 규칙에 `conditions.heldAssets`가 들어갔으니 0원 처리 필수. (3) `goalReachMonth` 키 없음 규칙: 모델이 "키가 없으면 도달 못 한다"고 말하려면 `isAchieved=false`일 때만 해당한다. 규칙 (3)을 "`isAchieved=false`이고 `goalReachMonth` 키가 없으면"으로 좁혀 달성인데 키가 빠진 버그를 "도달 못 함"으로 말하지 않게 한다. (4) 키 이름 충돌: `planContext.display`의 `goalAmount`와 `/internal/calc` `display`의 `goalAmount`가 이름이 같고 값도 같아야 한다. 다르면(R-4) 모델이 구분할 방법이 없다. 이름 충돌 키는 이것 하나뿐이므로 허용하되, ai-server는 도구 결과를 모델에 넘길 때 `current`/`changed`/`diff` 접두어 키만 인용하라고 프롬프트에 못 박는다.

- [C1a-7 넣지 않는 필드] **수용** — D-030·NFR-INT-03에 맞다. `memberId`는 `build_messages`가 지금도 프롬프트에 넣지 않으므로 "넣지 않음" 테스트가 현 동작을 고정한다. `goalType`·`goalCustomName` 제외(R-2)도 수용.

- [C1a-8 무시 규칙·display 패턴] **수정(구현 가능, 아래 조건 추가)** — 상세는 아래 "C1a-8 구현 가능성". 핵심: (a) 필수/선택 필드를 명시해야 422와 "무시"가 결정적으로 갈린다, (b) 패턴 밖 키를 버리는 규칙과 "문자열 맵이 아니면 422"가 값 타입에서 충돌, (c) 누락 방어 범위 확대, (d) EXPLAIN에서 `planContext`가 null일 때 검사 추가.

- [C1a-9 camelCase] **수용** — `ApiModel`(`alias_generator=to_camel`, `serialize_by_alias=True`)이 `is_achieved`→`isAchieved`, `is_default_savings_rate`→`isDefaultSavingsRate`로 그대로 맞는다(`schemas.py`). display 키는 점 포함 문자열이라 `dict[str, str]`로 선언하면 alias 영향이 없다. 단 `ConditionChanges.changed()`의 snake_case 키 문제는 이 계약 밖이라는 정리도 수용.

- [C1a-10 누가 언제 만드는가] **수용(소비자 요청 2건)** — chat→calc 한 곳 호출, 호출 직전 생성, 저장 안 함은 D-033(검증 Spring 한 곳)·ADR-002와 맞고 ai-server는 영향 없다. 요청: (1) EXPLAIN 불일치 검사를 `ChatAgent.run()`의 기존 `match`에 한 줄 추가하는 형태로 수용. 현재 EXPLAIN 검사는 `calc_run_id=None`만 본다. (2) **EXPLAIN인데 `planContext`가 `null`이면 `BAD_REQUEST`**를 추가(C1a-11은 "EXPLAIN은 이 경우가 없다"고만 적었지 ai-server가 어떻게 하는지 없음). 모델이 `{}` 대신 "없음"을 받고 설명을 지어내는 것을 막는다. (3) QUESTION에서 `ChatRequest.calcRunId`가 `null`인데 `planContext.calcRunId`는 있는 것은 정상임을 fixture 설명에 적을 것(A-4 아래 문장은 EXPLAIN만 말함).

- [C1a-11 특수한 경우] **수정** — ETF 0%·도달 못 함은 수용. `ALREADY_EXCEEDED`: R-1 의견 참고. ai-server는 이 상태에서 **LLM을 부르지 않고** 문구표 고정 문장으로 답하는 편이 안전하다(EXPLAIN일 때). QUESTION이면 모델에 주되 "초과 금액은 말하지 않는다"를 프롬프트로 강제. `NO_PLAN`(`planContext=null`)인 QUESTION의 "먼저 목표와 조건을 입력해 주세요"는 문구표 키를 ai-server가 읽어야 하는데 #18(문구표) 위치가 미정이라 키 이름을 이 계약에 못 박아 달라(예: `chat.noPlan`).

- [C1a-12 크기·버전] **수용** — 버전 필드 없음(R-5b) 수용. 필드 추가 시 ai-server가 `extra=ignore`로 안전하다는 점이 중요하고, 대신 필드 이름이 바뀌면 required 필드 누락으로 422가 나서 fixture 테스트가 즉시 잡는다(그러므로 required 목록 명시가 필요, H-7).

- [C1a-13 예시 JSON] **수정** — A-1~A-3은 fixture로 그대로 쓸 수 있다. 문제: (1) **A-4는 `"planContext": "<부록 A-1의 객체를 그대로 넣는다>"` 문자열이라 JSON fixture로 못 쓴다.** `ChatRequest.model_validate`가 실패한다. 실제 파일이 필요하다(G-1에서 `docs/api/examples/**`를 #11 paths에 추가하길 권한다. 복사본 2개는 반드시 어긋난다). (2) A-5의 직렬화 기대값은 **dict 비교**(`json.loads`한 객체 동등)로 하고 키 순서·공백은 계약하지 않는다고 적을 것. 안 적으면 바이트 비교 테스트가 생겨 프롬프트 포맷 변경마다 깨진다. (3) fixture를 두 개 더: 달성 시나리오가 섞인 경우(`+약 501만원 달성`, `goalReachMonth` 있음)와 `heldAssets=0` 경우(H-3). 지금 A-1~A-3은 `isAchieved=true`가 한 번도 없어 `goalReachMonth` display 키 허용 패턴이 테스트되지 않는다.

- [C1a-14 코드 차이] **수용** — D-1~D-5가 실제 코드와 일치한다(`schemas.py` `dict[str, Any]`, `build_messages` `json.dumps`, `prompts.py`의 "plan_context에 있는 값이나 ... 그대로 인용", `test_agent.py`의 `FakeCalc`가 옛 모양 `goodCase.finalAmount`). 추가: D-9 `agent.py`의 `ChatRequest(mode=EXPLAIN)` 검사 보강(위 C1a-10), D-10 `prompts.py` `SYSTEM_PROMPT`가 조건 7개(`existing_monthly_contribution`, 목표 금액 포함)를 안내하는데 D-040은 4개다. 이 계약 밖이지만 같은 Issue(G-3)에서 프롬프트를 고치므로 한 번에 맞출 것.

- [C1a-15 수용 기준 대응] **수용** — 5개 모두 문서 안에서 추적된다. 수용 기준 3("규칙 밖 필드는 무시")이 "모델에도 넘기지 않음"까지 포함한다는 해석은 소비자가 원하는 쪽이다.

## 구멍 목록 (LLM이 계산·추정하게 되는 곳)

- **H-1. 상대 표현 → recalculate 인자** (반대, 필수 수정). 모델에는 `conditions.monthlySavingAmount: "약 30만원"`만 주어진다. 사용자가 "월 10만원 더 넣으면?"이라고 하면 recalculate 인자 `monthly_saving_amount`(원 단위 정수, `ConditionChanges`)를 모델이 `300000+100000`으로 만들어야 한다. `monthlySavingAmount`의 scale이 0원 단위이고(C3-3, min 10,000) `heldAssets` 같은 값이 345,000원일 수 있어 `약 35만원`에서 시작하면 **틀린 값으로 계산**된다. 이것은 입력 값의 산술이라 결과 숫자 계산은 아니지만, "LLM이 직접 계산·반올림"에 해당한다. 선택지:
  - (A, 권장·가장 단순) 프롬프트 규칙: "상대 표현(더, 덜, 늘리면, 줄이면)은 계산하지 않고 `CLARIFY`로 절대값을 되묻는다"(D-033·FR-AI-06 "모호하면 되묻는다"와 일치). Spring 변경 없음. UX는 한 번 더 묻는 비용.
  - (B) `conditions` 중 대화로 바꿀 수 있는 4개의 raw 값을 모델에 `<plan_context>`로 주되 "recalculate 인자 전용, 문장에 인용 금지"로 표시. 덧셈은 모델이 한다. 원칙 1(raw 모델 미전달)과 충돌하므로 사람이 정할 것.
  - 이 쟁점은 소비자 쪽에서 가장 큰 열린 구멍이다. Q-번호로 올려 달라.
- **H-2. display 누락 방어 범위**. `CONTEXT_DISPLAY_MISSING`을 `<S>.afterTaxAsset` 하나만 보면 안 된다. `gapToGoal`이 빠지면 모델 입장에서 `goalAmount`와 `afterTaxAsset` 둘 다 있고 규칙(2)만 믿고 뺄셈을 하지 않기를 기대해야 한다. 요구 키 집합을 계약에 못 박을 것: `status=CALCULATED`이면 `goalAmount`, `targetMonth`, `calcStartMonth`, `conditions.{heldAssets,monthlySavingAmount,targetPeriodMonths,savingsRatioPct,savingsRateInputPct}`, 각 시나리오의 `afterTaxAsset·principal·afterTaxGain·gapToGoal`. `ALREADY_EXCEEDED`이면 `goalAmount`, `conditions.heldAssets`. `goalReachMonth`·`savingsRateBaseMonth`·`sp500BaseDate`만 선택.
- **H-3. 0원·소액 형식**. R-7 `0원` 수용. 추가로 `1만원 미만`(금액)을 같이 고정. `heldAssets=0`은 현실 입력이다(FR-INP 보유 자산 0 허용, `ConditionChanges.held_assets ge=0`).
- **H-4. 세율 질문**. QUESTION에서 "세금 얼마 떼요?"는 첫 질문 후보다. display가 없으면 모델이 기억으로 `15.4%` 또는 `22%`(해외 ETF 양도세)를 말한다. 엔진이 쓰는 값만 말하도록 `assumptions.taxRatePct: "15.4%"` display 한 개를 허용 패턴에 더할 것(R-3: 반대, 소비자는 필요). 형식이 늘어 #28 수용 기준이 한 줄 늘지만, 안 두면 숫자 출처가 모델 기억이 된다. 두지 않기로 하면 프롬프트에 "세율 숫자는 말하지 않는다. 세금 질문은 search_documents 결과만 인용"을 명시.
- **H-5. excludedItems 문장**(R-6). 코드(`ETF_TOTAL_EXPENSE`, `EXCHANGE_RATE`, `ETF_DISTRIBUTION`, `HELD_ASSET_RETURN`, `SAVINGS_REDEPOSIT`)만 주고 모델이 풀어쓰게 하면 D-027 "환율 변동은 반영하지 않았어요"가 글자 그대로 안 나오고, `ETF_DISTRIBUTION` 같은 코드는 뜻을 모델이 지어낸다. 반대. 수정안: **코드→문구는 문구표에 두고 ai-server가 읽어 `<plan_context>`에 `excludedNotes`(문장 배열)로 넣는다**(Spring 변경 없음, CP-05 부합). 문구표가 아직 없으면 ai-server 상수 dict로 시작하고 #18에서 옮긴다. 코드 목록이 `ExcludedItem` enum 5개로 닫혀 있으니 테스트는 "모든 enum 코드에 문구가 있다" 한 줄.
- **H-6. 수익률 질문**. `annualReturnPct` display 없음은 C2-6과 같은 결정이라 수용. 다만 사용자가 "좋았던 때는 연 몇 %예요?"라고 물으면 모델이 RAG/기억으로 숫자를 말한다. 프롬프트에 "구체 수익률은 안내하지 않는다. 과거 데이터 기반 구간이고 약속이 아니라고만 답한다" 규칙 추가를 G-3에 넣을 것. 마찬가지로 `scenarioMethod`가 말해 주지 않는 "과거 몇 년치 기준인가"는 모르는 것으로 처리.
- **H-7. required/선택 미정**(C1a-8 구현성에 이어서 아래).

## C1a-8 구현 가능성

구현 가능하다. 다만 아래를 계약에 적어야 fixture 테스트가 결정적이다.

1. **`PlanContext` 모델**: `ApiModel`은 `extra`를 지정하지 않아 pydantic 기본(`ignore`)이므로 하위 모델도 별도 설정 없이 모르는 키를 버린다. `ConditionChanges`는 `extra="forbid"`로 덮어쓰니, 하위 클래스 `model_config`에서 실수로 덮어쓰지 말 것. `result.scenarios[].scenario`는 기존 `Scenario` enum 재사용.
2. **required 필드 목록**을 못 박을 것(제안): `result`, `result.status`, `result.scenarios`(배열, 빈 배열 가능), 각 원소 `scenario`·`isAchieved`, `result.assumptions.isDefaultSavingsRate`, `scenarioMethod`·`excludedItems`(null 가능이지만 키는 필수), `display`. 선택: `calcRunId`(QUESTION 검사에는 불필요. EXPLAIN일 때만 필수 → 모델 validator), `conditions`, 나머지 raw. 이렇게 하면 Spring이 raw 필드명을 바꿔도 모델 입력이 안 깨지고, 모델이 쓰는 필드가 사라지면 즉시 422.
3. **display 값 타입 충돌**: "값이 문자열인 항목만"(필터)과 "문자열 맵이 아니면 422"(검증)가 한 문서에 공존한다. `display: dict[str, Any]`로 받아 패턴과 `isinstance(str)`을 모두 통과한 것만 남기는 쪽을 권한다(필터). 맵 자체가 객체가 아니면 422.
4. **패턴 정규식**은 ASCII 전용 `re.fullmatch`로 쓰면 되고(`$` 대신 fullmatch) 문서의 패턴은 키 표와 일치한다. 확인: `AVG.afterTaxAsset` 통과, `loginId` 차단, `current.AVG.afterTaxAsset`(비교 키)도 `planContext.display`에서는 차단되는지 테스트에 포함할 것. **값에 대한 필터는 없다**: display 값에 `"ignore previous instructions"` 같은 문자열이 와도 통과한다. Spring이 만드는 값이라 위험은 낮지만, 값도 `^[0-9,\-+약원만년월달성미적금ETF :.%()연개 ]+$` 수준으로 막을지는 선택(과잉일 수 있음, 소비자는 불요).
5. **프롬프트 삽입 포맷**: `<plan_context>` JSON 직렬화는 `ensure_ascii=False`(기존과 같음)로 한국어가 이스케이프되지 않게. 이 결정은 A-5가 깨지지 않게 dict 비교와 한 쌍.
6. **`CONTEXT_DISPLAY_MISSING`**: `main.py`는 BAD_REQUEST 외의 AgentError를 모두 502로 돌려주므로 계약이 말한 502가 그대로 나온다. 수용. 코드 문자열은 `CALC_DISPLAY_MISSING`(도구 쪽)과 쌍으로 상수화.
7. **422 본문**(G-6): Spring이 4xx를 모두 FAILED로 처리하므로 소비자는 어느 쪽이든 동일하다. FastAPI 기본 `{"detail": [...]}`를 그대로 두고 README 문장만 고치는 쪽이 싸다(권장). 단 `detail`에 사용자 입력이 에코될 수 있어 로그에 `planContext` 전체를 남기지 말 것(개인정보 최소화).

## 오류 처리 (소비자가 기계적으로 고를 수 있나)

| 상황 | 신호 | 소비자 동작 | 판정 |
|---|---|---|---|
| 계획 없음(QUESTION) | `planContext=null` | 문구표 `NO_PLAN` 안내, LLM 숫자 없음 | OK, 문구표 키 이름 고정 필요 |
| 이미 초과 | `result.status=ALREADY_EXCEEDED` | 고정 안내(EXPLAIN은 LLM 미호출 권장) | OK |
| ETF 0% | `scenarios.length==1` | 3구간 설명 안 함 | OK |
| 도달 못 함 | `isAchieved=false` + 키 없음 | "기간 안에 도달하지 않아요" | OK(조건 좁힐 것) |
| display 누락 | `CONTEXT_DISPLAY_MISSING` 502 | Spring FAILED | OK |
| 계약 위반 | 422 | Spring FAILED | OK |
| EXPLAIN `calcRunId` 불일치 / `planContext` null | `BAD_REQUEST` 400 | Spring FAILED | 후자 추가 필요 |

문자열 해석이 필요한 곳은 없다. 단 오류 코드 3종(`CONTEXT_DISPLAY_MISSING`, `BAD_REQUEST`, 422)은 Spring이 모두 FAILED로 합치므로 소비자에게는 구분이 로그용뿐이다(문제 없음, FR-AI-04).

## 검토 요청 R-1~R-7

- **R-1 (`ALREADY_EXCEEDED`에 EXPLAIN 호출?)**: 호출하든 안 하든 ai-server는 처리한다. 의견은 **호출하지 않는 쪽**(프론트가 FR-RES-01 고정 문구만 보여줌). 이유: 설명할 시나리오가 없고, 호출하면 LLM이 초과 금액을 뺄셈으로 지어낼 위험만 는다. 만약 호출한다면 ai-server가 LLM 없이 문구표 고정 문장(`EXPLANATION`, `calcRunId` 그대로)으로 즉시 답한다. QUESTION에서 사용자가 "얼마나 넘었어요?"를 물으면 display에 없으므로 답하지 않는다(화면에도 없는 값이므로 일관). 결정은 F-3(#12)·A팀이 하되 ai-server 쪽 가드는 어느 경우든 넣는다.
- **R-2 (`goalType`·`goalCustomName`)**: **수용(넣지 않음)**. 소비자 요구 없음. `goalCustomName`은 자유 글이라 오히려 프롬프트 주입 경로가 된다.
- **R-3 (세율)**: **수정**. display `assumptions.taxRatePct`(`15.4%`) 한 키 추가 권장(H-4). 넣지 않으면 프롬프트로 숫자 금지 + RAG로만 답하도록.
- **R-4 (planContext 데이터 버전 vs 활성 버전)**: **수용**. 단 비교를 말할 때는 도구 결과의 `current.*`만 인용하고 planContext의 `<S>.*`와 섞지 않는다는 프롬프트 규칙을 G-3에 포함하고, 테스트로 고정(프롬프트 문자열에 해당 문장이 있는지 정도). D-041(기준은 항상 내 계획)에 따라 비교 카드와 문장은 도구 결과 한 쪽으로만 구성.
- **R-5 (a) `assumptions`를 `result` 안, (b) 버전 필드 없음**: **둘 다 수용**. 단 Issue #11 본문과 `b-team-contracts.md` C-1a의 문장을 D-058대로 본문에서 고치고(`assumptions` 위치), C2-4의 "항상 `CALCULATED`"·"`excludedItems` 미사용" 문장도 함께 정정.
- **R-6 (excludedItems 문장)**: **수정**. 문구표 문장을 글자 그대로(D-027). Spring이 display처럼 보내는 대신 **ai-server가 문구표/상수에서 코드→문장을 붙인다**(H-5). 모델이 풀어쓰는 방식은 반대.
- **R-7 (금액 0원)**: **수정**. `0원` 수용하고 `1만원 미만`도 같이 고정(H-3). `conditions.heldAssets=0`용 fixture를 추가.

## fixture(A-1~A-5)로 Spring 없이 테스트 가능한가

대부분 가능하다. 조건:

- A-1~A-3은 그대로 `ChatRequest.model_validate`에 넣을 수 있다. FakeClaude가 받는 `messages[0]["content"]`에서 `<plan_context>` 태그 안 JSON을 `json.loads`해 A-5와 dict 비교하면 된다(`test_agent.py`의 `FakeClaude.calls` 패턴 그대로).
- **A-4는 지금 형태로는 불가**(문자열 자리표시자). 실제 JSON 파일 필요.
- 필요한 fixture 추가: ① 달성 시나리오 포함(`isAchieved=true`, `goalReachMonth` 있음), ② `heldAssets=0`·소액 이득(0원·1만원 미만), ③ 오염 입력(규칙 밖 `loginId`, 패턴 밖 display 키, `display` 값이 숫자) → A-5 불변, ④ display 일부 누락(`AVG.gapToGoal`만 없음) → `CONTEXT_DISPLAY_MISSING`, ⑤ EXPLAIN calcRunId 불일치·`planContext=null` → 400.
- `FakeCalc.recalculate`의 반환 모양은 아직 옛 모양(`goodCase.finalAmount`)이다. 이 Issue의 범위는 아니지만 `internal-calc.md` A-1 fixture로 교체해야 "planContext display + 도구 결과 display가 같은 턴에 모델에 들어가는" 테스트가 가능하다(G-4 의존).
- 모델이 실제로 규칙을 지키는지는 FakeClaude로는 검증되지 않는다. 계약으로 보장되는 것은 "모델 입력에 raw 금액·`memberId`가 없다"까지이고, "모델이 뺄셈을 하지 않는다"는 프롬프트 규칙 + 소량 수동 평가 목록(예: A-1에서 "목표까지 얼마나 모자라요?"가 `-약 288만원 미달`에서 나오는지)이 별도로 필요하다. 이를 G-4 완료 조건에 적을 것.

## 결정과의 일치

- D-022(비교 결과는 대화창): 일치. planContext는 비교를 담지 않는다.
- D-033(범위 검증은 Spring 한 곳): 일치. planContext는 범위 값을 담지 않는다. H-1 (A)안은 D-033의 "모호하면 되묻는다"와도 맞는다.
- D-040(대화 조건 4개): planContext는 영향 없음. 단 `prompts.py`의 7개 조건 안내는 낡았으니 G-3에서 함께 정정.
- D-041(누적 금지·기준은 내 계획): 일치. planContext는 현재 계획 1건. R-4의 버전 불일치만 프롬프트로 방어.
- D-030/NFR-INT-03: 일치. 프롬프트 삽입이 `dict` 통째 직렬화에서 필드 선택으로 바뀌는 것이 이 결정의 실질 이행이다(현 코드는 위반 가능 상태).
- D-045: `requiredMonthlySaving`, 월 저축액 모름·기한 없음 분기는 null/미사용. 일치.
- D-055/D-056: display 형식 일치(0원·1만원 미만 금액만 비어 있음). D-056 문구(입력 수정 안내)는 recalculate 쪽 일이라 planContext와 무관.

## 소비자 쪽에서 꼭 필요한 것

1. 상대 표현 처리 결정(H-1): (A) 되묻기 규칙 또는 (B) 4개 raw 조건 전달. 결정 전에는 모델이 `약 30만원`에서 덧셈을 한다.
2. display 누락 방어를 요구 키 전체로 확대(H-2).
3. 금액 `0원`·`1만원 미만` 형식 고정(H-3, #28).
4. `excludedItems`·`scenarioMethod`의 코드→문장 출처(문구표 키 또는 ai-server 상수)(H-5).
5. `assumptions.taxRatePct` display 추가 또는 "세율 숫자 금지" 규칙 중 택일(H-4).
6. required/선택 필드 목록과 display 값 필터 규칙 확정(C1a-8 구현성 2·3).
7. EXPLAIN에서 `planContext=null`이면 `BAD_REQUEST` 한 줄.
8. 실제 JSON fixture 파일(A-4 포함)과 위치 결정(G-1: `docs/api/examples/**`를 paths에 추가 권장).
9. 문구표 키 이름: `NO_PLAN`, `ALREADY_EXCEEDED`, `excluded.<CODE>`, `scenarioMethod.<CODE>`(#18).

## 빼도 되는 것

- `planContext.conditions` 전체(raw): ai-server는 읽지 않는다. 로그·디버그용이면 유지해도 되나, H-1(B)을 택하지 않으면 와이어에서 빼고 `calcRunId`만 남기면 제공자 비용이 줄어든다.
- `result.assumptions.savingsRatePct`, `savingsRatioPct`, `taxRatePct`(raw), `result.goalAmount`, `calcStartMonth`, `targetMonth`, 시나리오의 raw 금액·`annualReturnPct`·`goalReachMonth`(raw), `dataVersions`, `requiredMonthlySaving`: 전부 모델에 넘기지 않는다. 와이어에 남아도 되지만 ai-server 모델에 선언하지 않는다. (`result`를 `CalcResultView` 공유로 두는 이득 때문에 제공자는 어차피 보내므로 요구하지 않음. 요청: ai-server 모델에서 선언하지 않는 것으로 충분.)
- `<plan_context>` 안의 `result.baselineScenario`: `build_messages`가 이미 `<baseline_scenario>` 태그로 넣는다. 중복이므로 모델 입력에서 뺀다(A-5 수정).
- `result.status`가 `CALCULATED`일 때 `isAchieved`: display의 `달성/미달` 라벨과 중복이지만 판단용으로 유지(소비자 취향이 아니라 라벨 문자열 파싱을 막기 위해). 빼자는 제안은 아님.
- G-6(422 본문 통일): 선택 사항이므로 README 문장 정정으로 대체.

## 반대·수정 제안 요약(진행자 보고용)

반대: H-1 상대 표현(필수), R-6 excludedItems를 모델이 풀어쓰는 방식.
수정: C1a-2(C2-4 문장 정정), C1a-3(conditions 와이어 존치 여부는 H-1에 종속), C1a-5(taxRatePct display, scenarioMethod 문장), C1a-6(0원·1만원 미만, goalReachMonth 규칙 좁히기), C1a-8(required 목록, display 값 타입, 누락 방어 범위, EXPLAIN null), C1a-10(EXPLAIN null 검사), C1a-11(문구표 키 이름, EXPLAIN+초과 가드), C1a-13(A-4 실제 JSON, dict 비교, 달성·0원 fixture), R-3, R-7.
