# planContext 계약 최종본 (moeun #11, C-1a)

> **최종본** (2026-11-16). 협상 결과 v3에 쟁점 결정 D-059(상대 표현 되묻기), D-060(세율 display `N.N%`), D-061(0원·1만원 미만·음수 금액), D-062(초과 계획은 설명 요청 안 함)를 반영했다.
> 협상 기록: `plan-context-v1.md` → 검토 2건 → `-v2.md` → 재검토 2건 → `-v3.md`, 합의안 `plan-context-proposal.md`.
> 이 문서를 moeun #11이 `docs/api/plan-context.md`·`docs/api/examples/plan-context/`·`ai-server/README.md`로 옮긴다.
> 본문에서 "B면 …" 같은 대안 설명은 기록용이며 적용하지 않는다.

> **최종본 보충 (2026-11-16, D-063~D-067, 본문보다 우선)**
> - **D-067 세금**: ai-server는 모델 입력에 문구표 `tax.note`(일반 과세 기준 가정, 비과세·세금우대 상품·금융소득·세법 변경 시 달라질 수 있음, 정확한 세금은 금융기관·세무 전문가 확인)를 `taxNote`로 넣는다(C1a-8 "모델에 넣는 것" 표에 1줄, `excludedNotes`처럼 ai-server가 문구표에서 붙임, Spring 변경 없음). 프롬프트 규칙 8 보강: 세율을 말할 때는 `taxNote`를 함께 쓰고 "~로 가정했어요"로 말한다. 상품별 세제 혜택·개인 세금 계산·절세 방법 질문은 FR-AI-09 범위 밖 안내 + 전문가 확인 안내. 같은 `tax.note`를 가정 보기(FR-RES-06)에도 쓴다. → #35, #18, (#30 가정 보기 화면은 프론트 결과 화면 Issue)
> - **D-059 보강(도메인 검토)**: 규칙 7(D-059)로 되물을 때 예시 금액·금리를 지어내지 않는다(지금 값은 display 인용만). → #21
> - **D-065 부호**: C1a-6 경계 표의 `-1만원 미만 미달`/`+1만원 미만 달성`이 확정. "1억 이상 `약 12,345만원`"은 모든 금액. → #28(이미 같음)
> - **D-063·D-066**: 대화창 표시 규칙은 `frontend-api-chat.md` 머리말 보충. ai-server 가드(초과 계획 EXPLAIN은 LLM 미호출)는 그대로.
> - **D-073 세금 응답 보장(D-067 구체화)**: 응답에 `assumptions.taxRatePct` 표시값이 있으면 ai-server가 `tax.note`를 글자 그대로 덧붙인다(모델이 이미 넣었으면 중복 안 함). 범위 밖 세금 질문은 `OUT_OF_SCOPE` + 문구표 `outOfScope.tax`. 모델 위반을 실패로 처리하지 않는다. → #35, #18
> - **D-092 (D-071 변경)**: 초과 계획의 대화 재계산은 목표를 바꾸지 않거나 바꿔도 여전히 초과일 때만 `409 ALREADY_EXCEEDED` 고정 문장(`chat.alreadyExceeded`)이며, 목표를 올려 초과를 벗어나면 `200` 비대칭 비교(3-1)를 반환한다. (EXPLAIN 모드는 기존대로 LLM 없이 `chat.alreadyExceeded`)


# `planContext` 계약 v3 (moeun #11, C-1a) — 재검토 반영본

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 4단계 마무리(재검토 반영, **마지막**). **결정이 아니라 합의안이다.** 쟁점(X-1~X-4)은 사람이 정한다.
> - 입력: `plan-context-v2.md`, `review-plancontext-v2-provider.md`(A팀 "수정하면 수용"), `review-plancontext-v2-consumer.md`(B팀 "수정하면 수용"). v1 검토 두 건도 참고.
> - 재사용: `internal-calc.md`(최종본) 원칙 0, C2-4 직렬화 표, C2-6 display 키·형식, C3-2 고정 문장, D-055·D-056·D-057
> - 기준: `docs/srs.md`(CP-04, CP-05, FR-AI-01·02·04·06·09·10, FR-RES-01·06, NFR-INT-01·03), `docs/decisions.md`(D-027, D-030, D-033, D-040, D-041, D-045, D-055, D-058)
>
> **표기**
> - **[합의]**: 양쪽이 수용했거나, 한쪽 수정 제안에 다른 쪽 이견이 없어 반영한 것.
> - **[D-059]~[D-062]**: 협상 쟁점이었다가 사람이 결정한 항목(모두 선택지 A).
> - **[v3]**: v2 → v3에서 바뀐 곳. 전체 목록은 맨 아래 "부록 B".
> - 항목 ID(C1a-x, G-x, R-x, H-x)는 v1·v2·검토와 같다.

## 0. 이 계약의 원칙 (v1과 같음)

`internal-calc.md` §0을 그대로 따른다. 이 계약에서 중요한 것만 다시 적는다.

1. **숫자는 Spring만 만든다.** 모델이 말하는 금액·기간·시점·비율은 `display` 문자열을 그대로 인용한 것뿐이다(NFR-INT-01, FR-AI-02). **raw 금액은 모델에 넘기지 않는다**(C1a-8). 왜: 모델 입력에 원 단위 숫자가 없으면 반올림·뺄셈할 재료가 없다.
2. **JSON 키는 camelCase**, 금액은 원 정수, 기간은 개월 정수, 퍼센트는 숫자(`3.12` = 3.12%).
3. **null은 키를 빼지 않는다.** 단 `display`는 값이 없으면 키를 만들지 않는다(C2-6과 같음).
4. **받는 쪽은 모르는 키를 무시한다.** 이 계약에서 "무시" = 오류로 처리하지 않고 **모델에도 넘기지 않는다**.
5. **계정 식별 정보는 넣지 않는다**(D-030).
6. **새 라이브러리 없음.** Spring은 Jackson 기본, ai-server는 기존 pydantic `ApiModel`.

---

## C1a-1. 목적·범위 [합의]

| 항목 | 값 |
|---|---|
| 무엇 | Spring → ai-server `POST /chat` 요청의 `planContext` 필드(`ChatRequest.plan_context`) |
| 뜻 | **한 계산 기록(`calc_run(PLAN)`)의 조건·결과·표시 문자열·가정**. 모델이 "지금 계획"을 말할 때 인용하는 유일한 숫자 출처 |
| 쓰는 곳 | `mode=EXPLAIN`(FR-AI-01·02), `mode=QUESTION`(FR-AI-06·09) |
| 쓰지 않는 곳 | 대화 재계산의 비교·차이는 `/internal/calc`(C2-3~C2-6)가 맡는다 |
| 담당 | 만드는 쪽 Spring `calc` 모듈(A팀, C1a-10). 쓰는 쪽 ai-server와 Spring `chat`(B팀). 계약은 A·B 공동 |

## C1a-2. 최상위 구조 [합의]

```json
{
  "calcRunId": 540,
  "conditions": { "...": "C1a-3" },
  "result": { "...": "C1a-4 (= /internal/calc의 current와 같은 모양)" },
  "display": { "...": "C1a-6" }
}
```

| 필드 | 타입 | Spring이 항상 보냄 | ai-server 필수 여부(C1a-8) | 뜻 |
|---|---|---|---|---|
| `calcRunId` | integer | 예 | 선택(EXPLAIN에서는 일치 검사) | 이 컨텍스트를 계산한 `calc_run(PLAN)` id |
| `conditions` | object | 예 | 선택(읽지 않음) | 계산에 실제 쓴 조건(C1a-3) |
| `result` | object | 예 | **필수** | 계산 결과(C1a-4). 가정은 `result.assumptions`(C1a-5) |
| `display` | object | 예 | **필수** | Spring이 만든 표시 문자열(C1a-6) |

- 계획이 없으면 `"planContext": null`(C1a-11).
- `result`는 `/internal/calc`의 `current`와 같은 DTO를 쓰고, 그 DTO는 **calc 루트 공개 타입** `calc.CalcResultView`, `calc.ScenarioResultView`다. 왜: `PlanContextView`(calc 루트, 공개 API)가 calc 하위 패키지(비공개) 타입을 노출하면 chat이 참조하는 순간 `ModularityTests`가 깨진다(`modulith.md`). internal-calc C2-4의 같은 문구 정정은 후속 G-11.
- `calcRunId` 최상위 유지. 왜: EXPLAIN 일치 검사와, QUESTION에서 어떤 기록을 기준으로 답했는지 로그로 남길 유일한 값.
- 이 계약의 `result`는 internal-calc C2-4와 두 곳이 다르다: `status`에 `ALREADY_EXCEEDED`가 올 수 있고, `assumptions.excludedItems`를 소비자가 쓴다. ai-server가 두 계약에 같은 pydantic 모델을 쓰면 `status`를 `Literal["CALCULATED"]`로 만들지 않는다. internal-calc C2-4 문장 정정은 후속 G-11.

## C1a-3. `conditions` [합의]

계산에 **실제로 쓴 값**. 6개 키가 항상 모두 있다.

| 키 | JSON 타입 | 단위 | 출처 | display 키 |
|---|---|---|---|---|
| `goalAmount` | integer | KRW | `CalcInput.goalAmount` | `goalAmount` |
| `heldAssets` | integer | KRW | `CalcInput.heldAssets` | `conditions.heldAssets` |
| `monthlySavingAmount` | integer | KRW | `CalcInput.monthlySavingAmount` | `conditions.monthlySavingAmount` |
| `targetPeriodMonths` | integer | MONTH | `CalcInput.targetPeriodMonths` | `conditions.targetPeriodMonths` |
| `savingsRatioPct` | integer | PCT | `CalcInput.savingsRatioPct`(해석된 비중) | `conditions.savingsRatioPct` |
| `savingsRateInputPct` | number | PCT(연, 세전) | `CalcInput.savingsRatePct`(실제 쓴 금리) | `conditions.savingsRateInputPct` |

- 출처는 `CalcInput`(ConditionResolver 결과) 하나. 왜: `plan_version.savings_rate_input_pct`는 NULL일 수 있어 raw 컬럼을 읽으면 틀린다. #32 `conditions.current`(4키)와 같은 매퍼를 쓴다.
- `CalcInput`의 `monthlySavingAmount`·`targetPeriodMonths`는 nullable 타입이다. 해커톤에서는 항상 값이 있지만(D-045) DTO는 nullable 그대로 두고 null이면 `null`로 보낸다(원칙 3).
- **와이어에는 남기고 모델에는 넘기지 않는다.** ai-server `PlanContext`는 이 객체를 **선택 필드**로 둔다. 왜 남기나: 제공자 비용이 매퍼 하나이고 로그·fixture 대조에 쓰인다. (소비자 참고: X-1이 A로 확정되면 "X-1 B 대비"라는 이유 하나는 사라진다. 그래도 빼자는 요구는 없어 유지한다.)

## C1a-4. `result` [합의]

`CalcResult`를 JSON으로 바꾼 것. internal-calc C2-4의 모양·직렬화 표를 그대로 쓴다. 다른 점만 적는다.

| 필드 | 이 계약에서의 규칙 |
|---|---|
| `status` | `CALCULATED` 또는 `ALREADY_EXCEEDED`. 초과면 `scenarios: []`(C1a-11) |
| `goalAmount`, `calcStartMonth`, `targetMonth` | C2-4와 같다(`"YYYY-MM"`) |
| `baselineScenario` | EXPLAIN: chat이 F-3 때 `chat_message.baseline_scenario`에 저장한 값. QUESTION: `plan.baseline_scenario`(C1a-10). 어느 경우든 `ChatRequest.baselineScenario`와 같다 |
| `scenarios[]` | **항상 GOOD·AVG·BAD 순서**. ETF 포함 3개, ETF 0% AVG 1개, 초과 0개. `monthlyPoints` **키 자체가 없다** |
| `scenarios[].goalReachMonth` | raw는 엔진 값 그대로(`"YYYY-MM"` \| null). **[v3]** 엔진 정의상 "처음 목표 이상이 된 달"이라 `isAchieved=false`여도 non-null일 수 있다(중간에 넘었다가 목표월에 내려온 경우). raw는 모델에 넘기지 않으므로 무해하고, display 키 규칙은 C1a-6 |
| `requiredMonthlySaving` | 해커톤에서 항상 `null`(D-045) |
| `assumptions` | C1a-5 |
| `dataVersions` | 보낸다. 모델에 넘기지 않는다 |

- `gapToGoal = afterTaxAsset − goalAmount`, `afterTaxGain = afterTaxAsset − principal`, 0원은 달성(CP-01). 모두 Spring 값.
- 달성/미달은 raw `isAchieved`로 판단하고 display 라벨도 같은 판정을 따른다. 라벨과 `isAchieved`가 어긋나지 않는지는 **Spring 빌더 단위 테스트(G-5a)**에서 잡고 ai-server fixture에는 두지 않는다.
- `baselineScenario`는 모델 입력(`<plan_context>`)에서 뺀다. 왜: `build_messages`가 이미 `<baseline_scenario>` 태그로 넣는다. 와이어에는 남는다.
- **[v3] 엔진 불변식(G-17, #27)**: `isAchieved=true`인 시나리오는 `goalReachMonth`가 null이 아니고 `targetMonth` 이하다. 왜: ai-server가 이 키를 요구 키로 검사하므로(C1a-8) 어기면 설명이 502로 실패한다. 판정(TBD-16 반올림 기준)과 월별 시계열 비교가 같은 값을 써야 성립한다. `ScenarioResult` 생성자 검사로 막을지, #27 테스트로만 고정할지는 A팀 재량.

## C1a-5. `assumptions` (`result.assumptions`) [합의, 세율 display는 X-2]

`calc.Assumptions` 그대로. 가정 보기(FR-RES-06)와 같은 원천. **`result` 안에 둔다**(R-5 a). 왜: `CalcResult.assumptions`가 이미 결과 안에 있어 최상위로 꺼내면 DTO가 하나 는다.

| 필드 | 타입 | 모델에 넘김 | display 키 | 비고 |
|---|---|---|---|---|
| `savingsRatePct` | number | 아니오 | (`conditions.savingsRateInputPct`) | |
| `isDefaultSavingsRate` | boolean | 예 | — | 기본금리 사용 여부 판단용 |
| `savingsRateBaseMonth` | `"YYYY-MM"` \| null | 아니오 | `assumptions.savingsRateBaseMonth` | null이면 display 키 없음 |
| `savingsRatioPct` | integer | 아니오 | (`conditions.savingsRatioPct`) | |
| `taxRatePct` | number | 아니오 | **[D-060]** `assumptions.taxRatePct` | raw는 어느 안이든 모델에 넘기지 않는다 |
| `scenarioMethod` | `CAGR` \| `ROLLING_DISTRIBUTION` \| null | **코드는 아니오. 문구로 바꿔서 넘김** | — | ai-server가 문구표 `scenarioMethod.<CODE>` 문장으로 바꿔 `scenarioMethodNote`로 넣는다. null(ETF 0%)이면 넣지 않음 |
| `sp500BaseDate` | `"YYYY-MM-DD"` \| null | 아니오 | `assumptions.sp500BaseDate` | null이면 display 키 없음 |
| `excludedItems` | string[] | **코드는 아니오. 문구로 바꿔서 넘김** | — | ai-server가 문구표 `excluded.<CODE>` 문장 배열로 바꿔 `excludedNotes`로 넣는다 |

**반영하지 않은 항목·3구간 산정 방식 문장 (R-6, H-5)**
- Spring은 **코드만** 보낸다. 왜: planContext에 문구표 의존이 생기지 않고 display와 성격이 다른 맵이 늘지 않는다.
- ai-server가 코드 → 문구표 문장으로 바꿔 모델에 넣고, **모델은 그 문장을 글자 그대로 인용**한다. 왜: D-027 "환율 변동은 반영하지 않았어요"가 AI 문장에서도 화면과 같아야 하고, 코드의 뜻을 모델이 지어내면 안 된다. CP-05(프론트와 AI 서버가 문구표를 함께 읽음)를 그대로 이행하는 것이라 새 정책이 아니다.
- **[v3] 문구표 출처**: #18(week:1)이 `ai-server/app/core/copy.py` 로더를 먼저 만들고 #35가 그 뒤에 온다(#35 선행에 #18). 그래서 ai-server 상수 dict는 **#18이 늦어질 때만 쓰는 대체 경로**다. 테스트: "`ExcludedItem`·`ScenarioMethod` enum의 모든 코드에 문장이 있다".
- 모르는 코드(문장 없음)는 **버리고 경고 로그**를 남긴다(모델에 코드를 넘기지 않음).
- `scenarioMethod.<CODE>` 문장 내용은 TBD-01(3구간 산정 방식, 미결)을 따른다. **[v3]** #18의 "없는 키를 읽으면 실패" 규칙 때문에 TBD-01이 끝나기 전에도 **임시 문장을 넣는다**(빈 값 금지, G-14).
- (선택, 제공자 메모) `ExcludedItem`·`ScenarioMethod` enum 값을 늘리면 #18 문구표도 같이 고친다는 것을 Javadoc 한 줄로 알린다.

## C1a-6. `display` 키·형식 — C2-6 재사용 [합의, 경계 형식 일부는 X-2·X-3]

internal-calc **C2-6의 키 규칙·형식·경계 규칙(D-055)을 그대로 쓴다.** 비교가 없으므로 `<side>.` 접두어를 뺀다. C2-6의 기존 형식만 쓰는 키 4개를 더한다.

| 키 | 형식 | C2-6 대응 |
|---|---|---|
| `goalAmount` | `약 N만원` | `goalAmount` |
| `calcStartMonth` | `YYYY년 M월` | **추가** |
| `targetMonth` | `YYYY년 M월` | `<side>.targetMonth` |
| `<S>.afterTaxAsset`, `<S>.principal`, `<S>.afterTaxGain` | `약 N만원` | `<side>.<S>.*` |
| `<S>.gapToGoal` | [D-055] `-약 288만원 미달`, `+약 501만원 달성` | `<side>.<S>.gapToGoal` |
| `<S>.goalReachMonth` | `YYYY년 M월`. **[v3] `isAchieved=true`이고 raw 값이 non-null일 때만 키를 만든다.** 그 밖(미달, 또는 null)은 키 없음 | `<side>.<S>.goalReachMonth` |
| `conditions.heldAssets` | `약 N만원` | **추가** |
| `conditions.monthlySavingAmount` | `약 N만원` | `conditions.<side>.monthlySavingAmount` |
| `conditions.targetPeriodMonths` | `n년 n개월` | `conditions.<side>.targetPeriodMonths` |
| `conditions.savingsRatioPct` | `적금 a : ETF b` | `conditions.<side>.savingsRatioPct` |
| `conditions.savingsRateInputPct` | `연 N.NN%` | `conditions.<side>.savingsRateInputPct` |
| `assumptions.savingsRateBaseMonth` | `YYYY년 M월`. null이면 키 없음 | **추가** |
| `assumptions.sp500BaseDate` | `YYYY년 M월`(일은 버림). null이면 키 없음 | **추가** |
| `assumptions.taxRatePct` | **[D-060]** `N.N%`, 끝 0 제거(`15.4`·`15.40` → `15.4%`) | 새 형식(쟁점) |

`<S>` = `GOOD` \| `AVG` \| `BAD`. 실제로 있는 시나리오만 키를 만든다.

**[v3] `<S>.goalReachMonth` 방출 규칙을 좁힌 이유**(소비자 반대 1): 엔진의 `goalReachMonth`는 "처음 목표 이상이 된 달", `isAchieved`는 "목표월 값 기준"이라 뜻이 다르다. BAD 시나리오가 중간에 목표를 넘었다가 목표월에 내려오면 `BAD.gapToGoal: "-약 38만원 미달"`과 `BAD.goalReachMonth: "2029년 5월"`이 함께 나가 모델이 "미달인데 5월에 도달"이라는 모순 문장을 만든다. 빌더가 미달이면 키를 만들지 않으면 프롬프트 규칙 3이 그대로 참이 된다. ai-server는 이 값을 보정하지 않는다(계산 금지). 테스트: G-5a "중간에 닿았다가 목표월에 내려온 BAD(`isAchieved=false`, raw `goalReachMonth` non-null) → `BAD.goalReachMonth` 키 없음" 1건.

경계 형식:

| 경우 | 형식 | 근거 |
|---|---|---|
| 목표 대비 정확히 0원 | `0원 달성` | D-055 |
| 목표 대비가 0원은 아니지만 0만원으로 반올림 | `-1만원 미만 미달` / `+1만원 미만 달성` | D-055 |
| 1억 이상 | `약 12,345만원` | D-055 |
| **금액**(`heldAssets`, `afterTaxGain` 등)이 정확히 0원 | **[D-061]** `0원` | 쟁점 |
| **금액**이 0원이 아니지만 0만원으로 반올림 | **[D-061]** `1만원 미만` | 쟁점 |
| **금액**이 음수(`afterTaxGain` 손실) | **[합의, v3]** `-약 N만원`. 0만원으로 반올림되면 `-1만원 미만` | X-3과 무관하게 #28에 넣는다. 왜: BAD 단기 계획에서 실제로 나오는 값이라 X-3을 B·C로 정해도 형식이 필요하고, 목표 대비(`-약 288만원 미달`)와 부호 위치가 같다(양쪽 수용) |

**[합의] 만드는 곳: display 맵 빌더 하나**
- `calc.application.ResultDisplayBuilder` 하나를 결과 화면(#30), `/internal/calc`(#32), planContext(G-7)가 같이 쓴다. 입력: `CalcInput` + `CalcResult` + **결과 접두어**(`""` / `"current."` / `"changed."`) + **조건 접두어**(`"conditions."` / `"conditions.current."` / `"conditions.changed."`). 왜: 같은 값을 세 곳에서 만들면 "화면 숫자 = AI 숫자 글자까지"(PR-04)를 코드로 보장할 수 없다. 계약 키는 그대로다.
- **[v3] 빌더는 #28에서 만든다**(#28 범위를 "Formatter + 공유 display 맵 빌더"로 넓힘). #28을 키우기 어렵다고 A팀이 판단하면 #29에 넣고 #29 선행에 #28을 더한다. 왜: #30은 #32를 선행으로 두지 않으므로(#30 선행: #17·#19·#27·#28·#29), v2처럼 #32에서 처음 만들면 #30이 먼저 끝날 때 자기 맵을 따로 만들게 되어 "빌더 하나" 합의가 깨진다. #28·#29는 #30·#32 둘 다의 선행이다(제공자).
- 빌더 단위 테스트(G-5a)도 빌더와 같은 Issue로 옮긴다. 왜: 빌더가 생기는 시점에 키·형식을 고정해야 #30·#32가 같은 키를 받는다.
- **[v3] 빌더 불변식(G-5a 테스트)**: `CALCULATED`면 C1a-8 요구 키 표의 키가 모두 있다. `ALREADY_EXCEEDED`면 `goalAmount`·`conditions.heldAssets`가 있다. 왜: 소비자가 요구 키를 넓혀서 빌더가 그 키를 반드시 만들 의무가 생겼다. 이 테스트가 계약 표와 빌더를 묶는다.
- `Formatter`(#28)는 형식만 맡는다. 추가 키 4개는 기존 두 형식(금액, 시점)만 써서 Formatter 변경이 없다. Formatter 수용 기준을 바꾸는 것은 음수 금액(합의), X-3·X-2 결과뿐이다(G-8b).
- 반올림은 TBD-16을 따르고 `Formatter` 한 곳에서 한다. 문구 템플릿(`달성`, `미달`, `적금 a : ETF b`)은 문구표(CP-05, #18).

**[합의] 모델 규칙에 쓰이는 display 해석**
- **`<S>.goalReachMonth` 키가 없을 때**: [v3] 빌더 규칙상 키가 없으면 그 시나리오는 미달이거나 계약 위반이다. 모델은 `isAchieved=false`일 때 "기간 안에 도달하지 않아요"라고 말한다. `isAchieved=true`인데 키가 없으면 C1a-8 요구 키 검사에서 502로 실패한다(엔진 불변식 G-17이 이 경우를 막는다).
- **`goalAmount` 키 이름 겹침**: `planContext.display.goalAmount`와 `/internal/calc` `display.goalAmount`는 이름이 같다. 목표 금액은 입력값이라 항상 같은 값이므로 허용한다. 그 밖의 키는 접두어로 갈린다. **비교·차이는 도구 결과의 접두어 키만 인용한다**(프롬프트 규칙 4).
- **display가 없는 값**(모델이 말하지 않음): `annualReturnPct`, `dataVersions`, `requiredMonthlySaving`, 초과 금액(`heldAssets − goalAmount`), 그리고 X-2에서 B를 고르면 세율.

## C1a-7. 넣지 않는 필드 (D-030) [합의]

| 필드 | 이유 |
|---|---|
| `memberId`, `login_id`, 비밀번호 해시, JWT 등 | D-030. `memberId`는 `ChatRequest` 최상위에만 있고 프롬프트에 넣지 않는다(테스트로 고정) |
| `plan_version.id`, `plan.revision`, `plan.previous_version_id` | 설명에 쓰이지 않음 |
| `goalCustomName` | 자유 글이라 개인정보·프롬프트 주입 경로가 될 수 있다(R-2) |
| `goalType` | `CalcInput`에 없어 넣으려면 plan 조회·DTO가 늘고, 소비자 요구도 없다(R-2) |
| `existingMonthlyContribution` | FR-INP-08 Won't(D-045) |
| `scenarios[].monthlyPoints` | 토큰 낭비, 설명에 불필요 |
| 대화 기록, 다른 계산 기록 | `history`는 `ChatRequest`의 별도 필드 |

- Spring 쪽은 `PlanContextView`에 계정 필드가 아예 없어 타입으로 보장된다. 직렬화 결과에 `memberId` 키가 없는지 G-5b에서 확인.

## C1a-8. ai-server 처리 [합의]

### 받기 (pydantic `PlanContext`)

- `PlanContext`와 하위 모델은 `ApiModel`을 상속하고 `extra`를 덮어쓰지 않는다(pydantic 기본 `ignore`). 시나리오 이름은 기존 `Scenario` enum 재사용.
- **필수/선택 목록**:

| 위치 | 필수 | 비고 |
|---|---|---|
| `result` | 필수 | |
| `result.status` | 필수 | `CALCULATED` \| `ALREADY_EXCEEDED` 외의 값 → 422 |
| `result.scenarios` | 필수 | 배열(빈 배열 가능) |
| `result.scenarios[].scenario`, `.isAchieved` | 필수 | |
| `result.assumptions.isDefaultSavingsRate` | 필수 | |
| `result.assumptions.scenarioMethod`, `.excludedItems` | 키 필수, 값 null 가능 | |
| `display` | 필수 | JSON 객체가 아니면 422. 값 타입은 아래 필터에서 처리 |
| `calcRunId` | 선택 | EXPLAIN에서는 아래 검사로 사실상 필수 |
| `conditions`, 그 밖의 raw 필드 | 선택(선언하지 않아도 됨) | 이름이 바뀌어도 모델 입력이 깨지지 않음 |

  왜: 모델이 쓰는 필드가 사라지면 즉시 422로 드러나고, 모델이 안 쓰는 raw 필드 변경에는 깨지지 않는다.
- **display 필터**: `display`는 `dict[str, Any]`로 받고, **키가 허용 패턴에 맞고 값이 문자열인 항목만** 남긴다. 나머지는 조용히 버린다. 값 내용 필터는 두지 않는다.
- 허용 패턴(ai-server 상수 하나, `re.fullmatch`):
  ```
  (goalAmount|calcStartMonth|targetMonth|(GOOD|AVG|BAD)\.(afterTaxAsset|principal|afterTaxGain|gapToGoal|goalReachMonth)|conditions\.(heldAssets|monthlySavingAmount|targetPeriodMonths|savingsRatioPct|savingsRateInputPct)|assumptions\.(savingsRateBaseMonth|sp500BaseDate|taxRatePct))
  ```
  `|taxRatePct`는 **[D-060]**일 때만. B면 뺀다 테스트: `AVG.afterTaxAsset` 통과, `loginId`·`current.AVG.afterTaxAsset`(비교 키) 차단.

### 검사 (`ChatAgent.run()`의 기존 mode 분기에 추가)

| 순서 | 조건 | 결과 |
|---|---|---|
| 1 | 스키마 위반(필수 누락, 타입, enum) | FastAPI 기본 422 `{"detail": [...]}` |
| 2 | `mode=EXPLAIN`이고 `planContext`가 `null` | `AgentError("BAD_REQUEST")` → 400. 왜: 모델이 "없음"을 받고 설명을 지어내는 것을 막는다 |
| 3 | `mode=EXPLAIN`이고 `planContext.calcRunId != ChatRequest.calcRunId` | `AgentError("BAD_REQUEST")` → 400. 왜: 다른 계산을 설명하면 FR-AI-02 대조가 깨진다 |
| 4 | `mode=EXPLAIN`이고 `result.status=ALREADY_EXCEEDED` | **LLM을 부르지 않고** 문구표 `chat.alreadyExceeded` 문장으로 `EXPLANATION` 응답(`calcRunId` 그대로). F-3이 이 경우를 부를지는 X-4 |
| 5 | display 요구 키 누락(아래) | `AgentError("CONTEXT_DISPLAY_MISSING")` → 502 |
| 6 | 그 밖 | 모델 호출 |

- 400·422·502 모두 Spring은 `FAILED`로 기록한다(FR-AI-04, #41 기준과 같아 Spring 추가 분기 없음).
- **422 본문은 FastAPI 기본을 그대로 둔다**(G-6). README의 "실패는 `{"error": CODE}`"에 "요청 검증 실패(422)는 FastAPI 기본 본문" 예외를 적는다.
- **`planContext` 본문을 로그에 남기지 않는다.** 422 `detail`에 값이 에코될 수 있으므로 로그에는 `calcRunId`와 오류 코드만.
- `CONTEXT_DISPLAY_MISSING`은 도구 쪽 `CALC_DISPLAY_MISSING`과 쌍으로 상수화한다.

**display 요구 키**(필터를 거친 뒤 기준):

| `status` | 반드시 있어야 하는 키 |
|---|---|
| `CALCULATED` | `goalAmount`, `calcStartMonth`, `targetMonth`, `conditions.{heldAssets, monthlySavingAmount, targetPeriodMonths, savingsRatioPct, savingsRateInputPct}`, `result.scenarios`의 각 `<S>`에 대해 `<S>.{afterTaxAsset, principal, afterTaxGain, gapToGoal}`, 그리고 `isAchieved=true`인 `<S>`의 `<S>.goalReachMonth`. **[D-060]** `assumptions.taxRatePct` |
| `ALREADY_EXCEEDED` | `goalAmount`, `conditions.heldAssets` |
| 선택(없어도 됨) | `assumptions.savingsRateBaseMonth`, `assumptions.sp500BaseDate`. (`isAchieved=false`인 `<S>.goalReachMonth`는 [v3] 빌더가 만들지 않는다. 와도 검사는 하지 않는다) |

왜 전체인가: `<S>.afterTaxAsset`만 보면 `gapToGoal`이 빠졌을 때 모델 앞에 `goalAmount`와 `afterTaxAsset`만 남아 뺄셈 유혹이 생긴다.

### 모델에 넣는 것 (`<plan_context>`)

| 위치 | 모델에 넘김 |
|---|---|
| `calcRunId`, `conditions.*`, `dataVersions`, `requiredMonthlySaving` | 아니오 |
| `result.status` | 예 |
| `result.baselineScenario` | **아니오**(`<baseline_scenario>` 태그와 중복) |
| `result.scenarios[].scenario`, `.isAchieved` | 예 |
| `result.scenarios[]`의 금액·수익률·시점 raw | 아니오 |
| `result.goalAmount`, `calcStartMonth`, `targetMonth` raw | 아니오 |
| `result.assumptions.isDefaultSavingsRate` | 예 |
| `result.assumptions.scenarioMethod` | 코드 대신 `scenarioMethodNote`(문구표 문장, null이면 키 없음) |
| `result.assumptions.excludedItems` | 코드 대신 `excludedNotes`(문구표 문장 배열) |
| `result.assumptions`의 그 밖 | 아니오 |
| `display` | 필터를 통과한 항목만 |

- 직렬화: 키는 camelCase(`by_alias=True`), `json.dumps(..., ensure_ascii=False)`.
- **테스트 기대값(A-5)은 `json.loads`한 dict 비교**로 한다. 키 순서·공백은 계약하지 않는다.
- 계획이 없으면(`planContext: null`) `<plan_context>null</plan_context>`처럼 "없음"이 드러나게 넣는다.

### 프롬프트 규칙 (G-3)

| # | 규칙 | 넣는 Issue(v3) |
|---|---|---|
| 1 | 금액·기간·시점·비율은 `display` 값을 글자 그대로 인용한다 | #35 |
| 2 | 두 display 값을 빼거나 나눠 새 숫자를 만들지 않는다(초과 금액 포함) | #35 |
| 3 | `isAchieved=false`이고 `<S>.goalReachMonth` 키가 없으면 "기간 안에 도달하지 않아요"처럼 시점 없이 말한다 | #35 |
| 4 | 비교·차이는 `recalculate` 결과의 접두어 키(`current.`/`changed.`/`diff.`)만 인용하고 planContext의 `<S>.*`와 섞지 않는다(R-4 방어) | #23 |
| 5 | 반영하지 않은 항목·3구간 산정 방식은 `excludedNotes`·`scenarioMethodNote` 문장을 그대로 쓴다 | #35 |
| 6 | 구체적인 연 수익률은 말하지 않는다. "과거 데이터로 만든 구간이며 수익을 약속하지 않는다"고만 답한다. 주어지지 않은 정보는 모른다고 한다 | #35 |
| 7 | **[D-059·D-092]** 대화로 바꿀 수 있는 다섯 조건(목표 금액·월 저축액·비중·적금 금리·기한)을 "더/덜/늘리면/줄이면"처럼 상대 표현으로 바꾸면 계산하지 않고 `CLARIFY`로 바꿀 값을 절대값으로 되묻는다(지금 값은 display로 인용 가능) | #21 |
| 8 | **[D-060]** 세율은 `assumptions.taxRatePct`만 인용한다. (B면: 세율 숫자는 말하지 않고, 세금 질문은 `search_documents` 결과만 인용) | #35 |
| 9 | (쪽별 적용) `status=ALREADY_EXCEEDED`인 쪽은 초과 사실만 말하고 초과 금액·비교 문장을 만들지 않는다. 409 초과 안내는 "대화로 목표 금액을 더 높게 바꿔 볼 수 있어요"를 안내한다(D-092) | #35 |

- `afterTaxGain`이 `-`로 시작할 때 "손실로 말한다" 같은 해석 규칙은 **넣지 않는다**(소비자 요청. 규칙이 늘어남). 음수 형식은 #28 Formatter 테스트로 고정한다.
- 모델이 실제로 규칙을 지키는지는 FakeClaude로 검증되지 않는다. **소량 수동 평가 목록 3~5건**(예: A-1에서 "목표까지 얼마나 모자라요?" → `-약 288만원 미달`을 인용하는지)을 실행하고 결과를 #35 PR 본문에 적는다(G-4).
- `prompts.py`는 #21·#22·#23·#35·#38이 같이 고친다. **#21 → #22 → #23 → #35 순서**로 처리한다(#35 선행에 명시).
- `SYSTEM_PROMPT`의 대화 변경 가능 조건은 D-090·D-092에 따라 **5개**(목표 금액 추가, 1단계)로 갱신한다(#21).

## C1a-9. 키 표기 camelCase [합의]

- `planContext` 안의 모든 JSON 키는 camelCase. `display` 키도 camelCase 경로를 점으로 이은 것.
- Spring: View DTO에 `@JsonProperty("isAchieved")`·`@JsonProperty("isDefaultSavingsRate")`. Spring Boot 4(Jackson 3)에서 record의 `boolean isAchieved` 접근자가 is-getter 규칙과 겹쳐 `achieved`로 나갈 수 있으므로 도메인 `ScenarioResult`/`Assumptions`를 직접 직렬화하지 않는다. G-5b가 고정한다.
- ai-server: `ApiModel`(`alias_generator=to_camel`, `serialize_by_alias=True`). `display`는 `dict`라 alias 영향 없음.
- 범위 밖: `ChatResponse.conditionChanges`의 snake_case 키는 #44(F-16).

## C1a-10. 누가 언제 만드는가 (Spring) [합의]

**만드는 곳: `calc` 모듈의 공개 API `PlanContextProvider`.** 왜 이 이름: QUESTION 경로가 `calc_run`을 INSERT할 수 있어 `Query`는 오해를 부른다.

```java
// calc 루트 패키지(공개 API)
public interface PlanContextProvider {
    /** F-3 요청 시점: 그 회원의 PLAN 기록인지와 기준 시나리오만 확인한다. 재계산 없음. 아니면 empty. */
    Optional<PlanRunRef> findPlanRun(long memberId, long calcRunId);
    /** EXPLAIN: 지정한 PLAN 기록으로 만든다. baselineScenario는 chat이 F-3 때 저장한 값. 아니면 empty. */
    Optional<PlanContextView> findForCalcRun(long memberId, long calcRunId, Scenario baselineScenario);
    /** QUESTION: 현재 계획의 최신 PLAN 기록으로 만든다. 계획이 없으면 empty. */
    Optional<PlanContextView> findForCurrentPlan(long memberId);
}
public record PlanRunRef(long calcRunId, long planVersionId, Scenario baselineScenario) {}
public record PlanContextView(long calcRunId, ConditionsView conditions, CalcResultView result, Map<String, String> display) {}
```

- 시그니처 세부는 제공자 재량. 위 세 가지 책임과 인자는 계약이다.
- **의존 방향**: `plan {}` ← `calc {plan, refdata}` ← `chat {calc, rag}`. chat은 calc 루트만, calc는 plan 루트 공개 API만 부른다. 새 순환 없음.
- **소유권 확인은 2단계, JOIN 금지**: ① calc 리포지토리 `findByIdAndRunType(calcRunId, PLAN)` ② plan 공개 API `findVersion(memberId, run.planVersionId)` → 비면 empty. 왜: `calc_run`에는 `member_id`가 없고, calc가 plan 테이블을 JOIN하면 `modulith.md`의 "다른 모듈의 엔티티·리포지토리를 쓰지 않는다"를 어긴다. `persistence.md`에 calc_run 예외를 한 줄 적는다(G-13).
- **plan 공개 API(#19)에 두 가지를 둔다**(G-12): 현재 계획 조회(이미 #19 범위) + `findVersion(long memberId, long planVersionId)`(소유권 포함). EXPLAIN은 현재 버전이 아닌 그 기록의 버전을 읽어야 한다.
- **[v3] `findPlanRun`의 기준 시나리오 출처**: `PlanRunRef.baselineScenario`는 조회 시점의 `plan.baseline_scenario`다. 이 컬럼은 `plan` 테이블에 있고 `plan_version`에는 없으므로(`schema.sql`) `findVersion`만으로는 못 얻는다. 그래서 `findPlanRun`은 PK 조회 3번: `calc_run` → `findVersion`(소유권) → 현재 계획 조회(기준 시나리오). 또 plan은 의존이 `{}`라 `calc.Scenario`를 쓸 수 없으므로 **plan 공개 API는 기준 시나리오를 문자열(또는 plan 자체 enum)로 돌려주고, calc가 `Scenario`로 바꿔 `PlanRunRef`에 담는다.** 왜 계약에 적나: 구현자가 `plan_version`에서 찾다가 헤매지 않게(제공자).
- **EXPLAIN의 `baselineScenario`는 인자로 받는다.** `calc_run`에 기준 시나리오가 저장되지 않으므로, F-3 이후 기준 시나리오가 바뀌어도 `ChatRequest.baselineScenario == planContext.result.baselineScenario`가 깨지지 않게 chat이 `chat_message.baseline_scenario`에 저장한 값을 넘긴다. QUESTION은 `plan.baseline_scenario`(현재).
- **F-3 404**(구현 #43, 계약 문장 #12): "없는 기록", "남의 기록", "PLAN이 아닌(CHAT) 기록"을 모두 같은 `404 NOT_FOUND`로 낸다(id 추측 방지). `findPlanRun`이 셋 다 empty → #43 컨트롤러가 `NOT_FOUND` 예외 → 전역 `@RestControllerAdvice`(#17)가 ProblemDetail `code=NOT_FOUND`. 한 경로라 일관된다.
- **언제**: chat의 `ChatAnswerRequested` 리스너가 ai-server `/chat`을 호출하기 직전에 만든다. 저장하지 않고 호출마다 만든다(ADR-002).
- **[v3] 트랜잭션: ai-server 호출 리스너는 트랜잭션 없이 돈다**(G-9a, #41). 순서: "planContext 만들기(`PlanContextProvider`의 자체 `@Transactional`) → **트랜잭션 밖** ai-server HTTP 호출 → 결과 저장(짧은 트랜잭션)". 왜: 30초 호출 동안 DB 커넥션을 잡지 않는다.
  - 문제: `modulith.md` 이벤트 절은 "수신은 `@ApplicationModuleListener`로 한다(커밋 후, 비동기, **새 트랜잭션**)"이다. 그대로 쓰면 리스너 메서드 전체가 새 트랜잭션이라 위 순서가 깨진다(제공자 확인).
  - 방법(둘 중 하나, #41 담당 재량): (a) 쓰는 Spring Modulith 버전의 `@ApplicationModuleListener`가 전파 속성을 받으면 `propagation = NOT_SUPPORTED`. (b) 받지 않으면 `@Async @TransactionalEventListener` + 저장 구간만 `TransactionTemplate`. **(a)의 전파 속성 지원 여부는 아직 확인하지 않았다** — #41 착수 시 먼저 확인한다. 어느 쪽이든 `event_publication` 기록은 유지되어야 한다.
  - `backend/.claude/rules/modulith.md` 이벤트 절에 예외 1줄을 더한다: "외부 HTTP를 부르는 리스너는 트랜잭션 없이 돈다(방법은 위 (a)/(b), 전파 속성 지원 여부는 버전 확인 필요)". #41 paths 밖이므로 #41 본문 paths에 이 파일을 추가한다.
- **생성 실패**: `Optional.empty()`는 "계획 없음"(QUESTION → `planContext: null`) 또는 "기록 없음"(EXPLAIN, 정상 경로에서는 F-3에서 걸러짐). 엔진·기준 데이터 오류는 예외로 올라오고, **chat 리스너는 ai-server를 부르지 않고 메시지를 `FAILED`·`FAILURE`로 바꾼다**(FR-AI-04, #41).

| mode | `planContext`의 기준 | `ChatRequest.calcRunId` |
|---|---|---|
| `EXPLAIN` | 요청의 `calcRunId`. 그 기록의 `plan_version`과 데이터 버전으로 계산. 현재 계획이 그 뒤 바뀌었어도 그 기록 기준 | `planContext.calcRunId`와 같은 값 |
| `QUESTION` | 현재 계획 버전의 최신 PLAN 기록. **[v3] #29의 "현재 계획의 결과를 조회하는 공개 서비스"(결과 화면 Q1(a)~(c), `db/erd.md` §4 Q1)를 그대로 호출**해 얻는다(없거나 활성 버전과 다르면 계산·기록). planContext용으로 따로 구현하지 않는다 | `null`. **`planContext.calcRunId`는 있는 것이 정상** |

- **[v3] QUESTION 매 턴 INSERT 방지**(소비자 요청): Q1 서비스는 "활성 버전과 같은 최신 PLAN 기록이 있으면 재기록하지 않는다". 그래서 대화 질문마다 `calc_run`이 쌓이지 않는다. 이 문장을 #29 본문에서 확인한다(G-18).
- QUESTION에서 `PlanChanged` 리스너와 동시에 PLAN 행이 2개 생길 수 있으나 `ix_calc_run_latest`가 최신 1행을 고르므로 무해하다(C2-7과 같은 방침). **[정정 2026-11-16, #12-a Y-17]** 이 문장은 `frontend-api-plan.md` C12a-6-6으로 대체: 기준 데이터 활성 버전·`engine_version`이 그대로인 동안 같은 (버전, PLAN) 기록은 #29 advisory 잠금으로 하나만 생긴다(같은 revision = 같은 `calcRunId`).
- **데이터 버전(R-4)**: planContext는 그 PLAN 기록의 버전, 같은 턴의 `/internal/calc` `current`는 활성 버전. QUESTION은 Q1-c 때문에 같고, 차이는 오래된 EXPLAIN 기록에서만 생기며 해커톤 중 재적재가 없으면 생기지 않는다(D-045). #10은 다시 열지 않고 프롬프트 규칙 4로 막는다.

## C1a-11. 특수한 경우 [합의, F-3 호출 여부는 X-4]

| 경우 | `planContext` | ai-server |
|---|---|---|
| 저장된 계획이 없음 | `null` | QUESTION: 숫자 없이 답한다. 계산·설명 요청이면 문구표 `chat.noPlan`. EXPLAIN: 400(C1a-8 검사 2) |
| ETF 0% | `scenarios`에 AVG 1개, `annualReturnPct`·`scenarioMethod`·`sp500BaseDate`·`dataVersions.sp500VersionId` = `null`, display에 `AVG.*`만 | 3구간을 말하지 않는다. `scenarioMethodNote` 없음. 부록 A-2 |
| 이미 목표 초과 | `scenarios: []`, display는 `goalAmount`, `calcStartMonth`, `targetMonth`, `conditions.*`, `assumptions.*` | EXPLAIN: LLM 없이 `chat.alreadyExceeded`(C1a-8 검사 4). QUESTION: 모델에 주되 초과 금액은 말하지 않는다(프롬프트 규칙 2·9). 부록 A-3 |
| 목표 기간 안에 도달 못 함(`isAchieved=false`) | [v3] raw `goalReachMonth`는 null 또는 "중간에 처음 닿은 달". **어느 경우든 display 키 없음** | "기간 안에 도달하지 않아요" |

- 초과 계획에서도 `conditions.heldAssets` display를 남긴다(사용자가 입력한 값이고 화면 조건 바에도 있다). 초과 금액 차단은 프롬프트 규칙 2·9가 맡는다.
- **문구표 키 고정**(#18이 이 이름을 쓴다, G-14):

| 키 | 쓰는 곳 | 문장(확정은 #18) |
|---|---|---|
| `chat.noPlan` | 계획 없음, `/internal/calc` `NO_PLAN`(C3-2)과 같은 문장 | "먼저 목표와 조건을 입력해 계획을 만들어 주세요" |
| `chat.alreadyExceeded` | 초과 EXPLAIN, `/internal/calc` `409 ALREADY_EXCEEDED`(C3-2)와 같은 문장 | "이미 가진 자산이 목표 금액을 넘었어요. 대화로 목표 금액을 더 높게 바꿔 볼 수 있어요." |
| `excluded.<CODE>` | `ExcludedItem` 5개. `excluded.EXCHANGE_RATE` = "환율 변동은 반영하지 않았어요"(D-027) | 나머지 4개는 #18 |
| `scenarioMethod.<CODE>` | `CAGR`, `ROLLING_DISTRIBUTION` | TBD-01 결과에 따름. **결정 전에도 임시 문장을 넣는다**(빈 값 금지) |

  왜 C3-2와 같은 키인가: 같은 상황(계획 없음·초과)에 경로마다 다른 문장이 나오지 않게 한다.

## C1a-12. 크기·버전 [합의]

- 크기: 시나리오 3개 기준 JSON 약 3KB, 모델 입력 약 1.5KB. 상한을 코드로 강제하지 않는다.
- **버전 필드(`contextVersion`)를 두지 않는다**(R-5 b). 한 repo·한 Compose 배포이고, 필드 추가는 "모르는 키 무시"로 안전하며, 모델이 쓰는 필드의 이름 변경은 필수 필드 누락 422와 양쪽 fixture 테스트(G-4·G-5)가 바로 잡는다.
- 필드를 더하는 변경: 이 문서 수정 → Spring이 보냄 → ai-server가 모델·패턴에 더할 때까지 모델에는 안 들어감(안전). 빼거나 뜻을 바꾸는 변경: 재협상.

## C1a-13. 예시 JSON과 fixture [합의]

- **fixture 위치: 공유 파일 `docs/api/examples/plan-context/*.json`**(moeun). backend 테스트와 ai-server 테스트가 같은 파일을 읽는다. #11 `paths`에 `docs/api/examples/**`를 더한다(G-1). 왜: 복사본 두 벌은 반드시 어긋난다.
- 숫자는 형식 예시다(엔진 결과 아님). 서로 맞게 만들었다: `principal = heldAssets + monthlySavingAmount × targetPeriodMonths`, `afterTaxAsset = principal + afterTaxGain`, `gapToGoal = afterTaxAsset − goalAmount`, display는 만원 반올림.
- **[v3] 파일 두 종류의 쓰임**
  - `plan-context-*.json`: **`planContext` 객체만** 담는다. ai-server 테스트는 헬퍼 `make_request(plan_context, mode, calc_run_id)`(테스트 코드, #35)로 `ChatRequest`에 감싸 쓴다.
  - `chat-request-*.json`: **`ChatRequest` 전체**를 담는다. 그대로 `/chat` 요청 본문으로 쓴다. 문서 안의 모든 `chat-request-*` 예시는 줄임 없는 전체 JSON이다(부록 A-4, A-10). G-1이 그대로 파일로 옮긴다.
  - `model-input-basic.json`: A-1의 모델 입력 기대값. **`excludedNotes`·`scenarioMethodNote` 두 키는 파일에 넣지 않는다.** 테스트가 문구표(`COPY`)에서 `[COPY[f"excluded.{c}"] for c in excludedItems]`, `COPY[f"scenarioMethod.{m}"]`로 두 키를 만들어 기대값 dict의 `result.assumptions`에 덧붙인 뒤 비교한다. 왜: 자리표시자 문자열을 파일에 두면 `json.loads` 비교가 항상 실패하고 사람이 "진짜 값인가" 헷갈린다(소비자).
- **[v3] G-5는 둘로 나뉜다**(엔진을 돌리지 않는 단위 테스트):
  - **G-5a(빌더 Issue, #28)**: 부록 A의 raw 값으로 손으로 만든 `CalcInput`/`CalcResult` → `ResultDisplayBuilder`(접두어 `""`, `"conditions."`) 결과 = fixture의 `display` 객체. 요구 키 불변식, `goalReachMonth` 방출 규칙(미달 BAD 1건), 라벨-`isAchieved` 일치.
  - **G-5b(G-7 새 Issue)**: 같은 입력 → `PlanContextView` 직렬화 결과 = fixture 전체. `memberId` 키 없음, `isAchieved`·`isDefaultSavingsRate` 키 이름.
  - **숫자는 값으로 비교한다(`BigDecimal` 스케일 무시).** 왜: `Assumptions.taxRatePct`·`savingsRatePct`가 `BigDecimal`이라 `15.4`와 `15.40`이 JSON 트리 비교에서 다르게 판정될 수 있다(제공자). 비교 방법은 구현 재량(새 라이브러리 없이).
- ai-server 테스트는 A-5와 dict 비교(C1a-8).

| 파일 | 내용 | 부록 | Spring 테스트가 읽음(G-5) | ai-server 테스트가 읽음(G-4) | 기대 |
|---|---|---|---|---|---|
| `plan-context-basic.json` | 기본, 3구간 모두 미달 | A-1 | 예 | 예 | — |
| `plan-context-etf0.json` | ETF 0% | A-2 | 예 | 예 | — |
| `plan-context-exceeded.json` | 이미 초과 | A-3 | 예 | 예 | — |
| `plan-context-achieved.json` | 달성·미달 섞임, `goalReachMonth` 있음 | A-6 | 예 | 예 | `<S>.goalReachMonth` 키 패턴 통과 |
| `plan-context-zero-held.json` | `heldAssets=0`, 1만원 미만 이득 | A-7 | 예 | 예 | **X-3 결정에 따라 display 두 값만 바뀜** |
| `plan-context-polluted.json` | 규칙 밖 키 | A-8 | 아니오(ai-server 전용) | 예 | 모델 입력이 A-5와 같음 |
| `plan-context-display-missing.json` | `AVG.gapToGoal` 없음 | A-9 | 아니오(ai-server 전용) | 예 | `CONTEXT_DISPLAY_MISSING` 502 |
| `chat-request-explain.json` | EXPLAIN 전체 요청 | A-4 | 아니오(ai-server 전용) | 예 | — |
| `chat-request-question-no-plan.json` | QUESTION, 계획 없음 | A-4 | 아니오(ai-server 전용) | 예 | `<plan_context>null</plan_context>` |
| `chat-request-question-with-plan.json` | QUESTION, 계획 있음 | A-4 | 아니오(ai-server 전용) | 예 | `calcRunId: null`이 정상 |
| `chat-request-explain-mismatch.json` | EXPLAIN, calcRunId 불일치 | A-10 | 아니오(ai-server 전용) | 예 | 400 |
| `chat-request-explain-null.json` | EXPLAIN, planContext null | A-10 | 아니오(ai-server 전용) | 예 | 400 |
| `chat-request-explain-exceeded.json` | EXPLAIN, 초과 계획 | A-10 | 아니오(ai-server 전용) | 예 | LLM 미호출, `chat.alreadyExceeded` |
| `model-input-basic.json` | A-1의 모델 입력(문구 두 키 제외) | A-5 | 아니오(ai-server 전용) | 예 | dict 비교 기대값 |

- ai-server의 `FakeCalc.recalculate` 반환 모양은 옛 모양(`goodCase.finalAmount`)이다. "planContext display + 도구 display가 같은 턴에 들어가는" 테스트를 하려면 internal-calc 부록 A-1 fixture로 바꿔야 한다. 이 교체는 **#23**(`tests/fakes/**`가 paths)이 하고 #35의 선행이다.
- (선택 제안, 반영 안 함) 음수 `afterTaxGain` fixture 추가: fixture를 늘리지 않고 #28 Formatter 테스트로 고정한다.

## C1a-14. moeun 현재 코드와 다른 곳 [합의]

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| D-1 | `ai-server/app/schemas.py` `ChatRequest.plan_context` | `dict[str, Any] \| None` | `PlanContext \| None`(C1a-8 필수/선택 목록) | G-2 |
| D-2 | `ai-server/app/llm/agent.py` `build_messages` | dict 통째로 `json.dumps`, 계획 없으면 `{}` | 모델 전달 필드만, display 필터, 문구 매핑, `null` 표시 | G-2 |
| D-3 | `ai-server/app/llm/prompts.py` | raw 숫자 인용 허용 문장 | 프롬프트 규칙 1~9 | G-3 |
| D-4 | `ai-server/README.md` | planContext 설명 없음, 실패는 `{"error": CODE}`만 | 필드 표·무시 규칙·fixture 링크, 422 예외 | G-1 |
| D-5 | `ai-server/tests/test_agent.py` | planContext 없는 요청만, `FakeCalc` 옛 모양 | C1a-13 fixture 테스트 | G-4(+#23 FakeCalc 교체) |
| D-6 | `backend/.../calc/` | `PlanContextProvider`·`PlanContextView`·`ConditionsView`·`CalcResultView`·`ScenarioResultView`·`ResultDisplayBuilder`·`Formatter` 없음 | `CalcResultView`·`ScenarioResultView`는 calc 루트(#32), `ResultDisplayBuilder`는 #28에서 만들어 #30·#32·planContext 공유, `findPlanRun` 경량 조회 | G-7, G-8a, G-10 |
| D-7 | `backend/.../plan/` | 공개 조회 API 없음 | 현재 계획 조회(기준 시나리오 문자열 포함) + `findVersion`(소유권 포함) | G-12 |
| D-8 | `b-team-contracts.md` C-1a, Issue #11 본문 | `assumptions` 최상위, 부호 없는 `gapToGoal`, `calcRunId`·`heldAssets` 없음 | 이 문서 | G-16 |
| D-9 | `agent.py` `run()` EXPLAIN 검사 | `calc_run_id is None`만 | C1a-8 검사 2~4 추가 | G-2 |
| D-10 | `prompts.py` `SYSTEM_PROMPT` | 조건 7개 안내 | 대화로 바꿀 수 있는 조건 **5개**(D-090·D-092) | #21 |
| D-11 | `backend/.claude/rules/modulith.md` 이벤트 절 | 수신은 `@ApplicationModuleListener`(새 트랜잭션)만 | 외부 HTTP 리스너는 트랜잭션 없이 예외 1줄 | **[v3]** G-9a(#41) |

## C1a-15. Issue #11 수용 기준 대응 [합의]

| # | 수용 기준 | 이 문서 |
|---|---|---|
| 1 | 예시에 `memberId`·계정 식별 정보가 없다(D-030) | C1a-7, 부록 A(planContext 안·모델 입력 모두 없음), G-5b |
| 2 | `AVG.afterTaxAsset` 등 display는 Spring 문자열, LLM이 반올림하지 않음 | C1a-4, C1a-6, C1a-8(raw 금액 미전달, 프롬프트 규칙 1·2) |
| 3 | 규칙 밖 필드는 ai-server가 무시 | C1a-8, A-8 |
| 4 | display가 C2-6 규칙을 따름 | C1a-6 |
| 5 | snake_case 키 없음 | C1a-9, 부록 A |

---

## 합의 목록

v2의 41건 + v3 재검토에서 더한 14건 = **55건.**

| # | 항목 | 내용 | 제안 |
|---|---|---|---|
| 1 | C1a-1 | 목적·범위 그대로 | 양쪽 수용 |
| 2 | C1a-2 | `CalcResultView`·`ScenarioResultView`를 calc 루트로 | 제공자 |
| 3 | C1a-2 | `calcRunId` 최상위 유지 | 양쪽 |
| 4 | C1a-2 | 이 계약에서는 `ALREADY_EXCEEDED`·`excludedItems` 사용(C2-4 문장 정정은 후속) | 소비자 |
| 5 | C1a-3 | 출처 `CalcInput`, 와이어 유지·모델 미전달·ai-server 선택 필드 | 제공자 + 기획 정리 |
| 6 | C1a-4 | `result` 규칙 그대로, `ALREADY_EXCEEDED` 허용 | 양쪽 |
| 7 | C1a-4 | `baselineScenario`를 모델 입력에서 뺌 | 소비자 |
| 8 | C1a-5 | `assumptions`는 `result` 안(R-5 a) | 양쪽 |
| 9 | C1a-5 | `excludedItems`·`scenarioMethod`: Spring은 코드만, ai-server가 문구표 문장으로 바꿔 넘김(R-6) | 소비자, 제공자 이견 없음 |
| 10 | C1a-6 | `ResultDisplayBuilder` 하나를 #30·#32·planContext가 공유, 결과·조건 접두어 분리 | 제공자 |
| 11 | C1a-6 | 추가 키 4개(Formatter 변경 없음) | 양쪽 |
| 12 | C1a-6 | `goalReachMonth` 키 없음 해석을 `isAchieved=false`로 좁힘 | 소비자 |
| 13 | C1a-6 | `goalAmount` 키 이름 겹침 허용 + 비교는 접두어 키만 | 소비자 |
| 14 | C1a-7 | `goalType`·`goalCustomName` 제외(R-2) | 양쪽 |
| 15 | C1a-8 | 필수/선택 필드 목록 | 소비자 |
| 16 | C1a-8 | display 필터(`dict[str, Any]`, 패턴 + 문자열), 값 필터 없음 | 소비자 |
| 17 | C1a-8 | display 요구 키 전체 검사 → `CONTEXT_DISPLAY_MISSING` | 소비자 |
| 18 | C1a-8 | `ensure_ascii=False`, A-5 dict 비교, planContext 본문 로그 금지 | 소비자 |
| 19 | C1a-8 | 422는 FastAPI 기본 본문 유지, README 정정(G-6) | 양쪽 |
| 20 | C1a-8 | `extra` 덮어쓰기 금지, `Scenario` enum 재사용 | 소비자 |
| 21 | C1a-9 | camelCase, View DTO `@JsonProperty` | 양쪽 |
| 22 | C1a-10 | plan 공개 API `findVersion(memberId, planVersionId)` | 제공자 |
| 23 | C1a-10 | 소유권 2단계(JOIN 금지) | 제공자 |
| 24 | C1a-10 | `findPlanRun` 경량 조회 | 제공자 |
| 25 | C1a-10 | EXPLAIN `baselineScenario`는 인자로 | 제공자 |
| 26 | C1a-10 | 이름 `PlanContextProvider` | 제공자 |
| 27 | C1a-10 | QUESTION은 결과 조회 Q1 서비스(#29) 재사용 | 제공자 |
| 28 | C1a-10 | 트랜잭션 순서(호출은 트랜잭션 밖) | 제공자 |
| 29 | C1a-10 | 생성 실패 → ai-server 미호출, `FAILED` | 제공자 |
| 30 | C1a-8 | EXPLAIN `calcRunId` 불일치·`planContext=null` → `BAD_REQUEST` | 기획 + 소비자 |
| 31 | C1a-10 | F-3 404는 없는 기록·남의 기록(·CHAT 기록) 구분 없음 | 제공자 |
| 32 | C1a-10 | QUESTION에서 `ChatRequest.calcRunId=null` + `planContext.calcRunId` 있음이 정상 | 소비자 |
| 33 | C1a-10 | 데이터 버전 차이 수용, #10 재오픈 없음(R-4) | 양쪽 |
| 34 | C1a-11 | 초과 계획에서도 `conditions.heldAssets` display 유지 | 소비자(제공자 위임) |
| 35 | C1a-11 | EXPLAIN + 초과 → ai-server가 LLM 없이 고정 문구(F-3 호출 여부와 무관한 방어) | 소비자 |
| 36 | C1a-11 | 문구표 키 `chat.noPlan`, `chat.alreadyExceeded`, `excluded.<CODE>`, `scenarioMethod.<CODE>` | 소비자 |
| 37 | C1a-12 | 버전 필드 없음(R-5 b) | 양쪽 |
| 38 | C1a-13 | fixture 위치 `docs/api/examples/plan-context/`, A-4 실제 JSON, 추가 fixture | 양쪽 |
| 39 | C1a-13 | G-5를 손으로 만든 입력의 단위 테스트로 | 제공자 |
| 40 | C1a-14 | D-6·D-7 보강, D-9·D-10 추가(D-10의 후속은 v3에서 #21로) | 양쪽 |
| 41 | G-8, H-6 | G-8 재배치(키는 빌더, 형식만 #28), 수익률 질문 프롬프트 규칙 + 수동 평가 목록 | 제공자, 소비자 |
| 42 | C1a-6 | **[v3]** `<S>.goalReachMonth` display 키는 `isAchieved=true`이고 non-null일 때만, 미달 BAD 테스트 1건 | 소비자 반대 1 |
| 43 | C1a-6 | **[v3]** `ResultDisplayBuilder`는 #28에서 만든다(불가 시 #29 + 선행 #28), 빌더 테스트 함께 이동, #30·#32는 공유 빌더 사용 | 제공자 |
| 44 | C1a-6 | **[v3]** 빌더 불변식 테스트(CALCULATED 요구 키 전부, ALREADY_EXCEEDED 2키) | 제공자 |
| 45 | C1a-6 | **[v3]** 음수 금액 `-약 N만원`/`-1만원 미만`은 X-3과 무관하게 #28 | 제공자, 소비자 수용 |
| 46 | C1a-4 | **[v3]** 엔진 불변식 `isAchieved=true` ⇒ `goalReachMonth` non-null·목표월 이하(G-17, #27) | 제공자 |
| 47 | C1a-10 | **[v3]** `PlanRunRef.baselineScenario`: plan 공개 API가 문자열로 돌려주고 calc가 변환, PK 조회 3번 | 제공자 |
| 48 | C1a-10 | **[v3]** ai-server 호출 리스너는 트랜잭션 없이(`NOT_SUPPORTED` 또는 `@Async @TransactionalEventListener` + `TransactionTemplate`), `modulith.md` 예외 1줄(전파 속성 지원 여부 미확인) | 제공자 |
| 49 | C1a-13 | **[v3]** G-5를 5a(빌더)·5b(직렬화)로 나눔, 숫자는 스케일 무시 값 비교 | 제공자 |
| 50 | C1a-13 | **[v3]** fixture 표에 Spring/ai-server 사용 열 | 제공자 |
| 51 | C1a-13 | **[v3]** `model-input-basic.json`에서 자리표시자 제거, 문구 두 키는 테스트가 `COPY`로 채움 | 소비자 |
| 52 | C1a-13 | **[v3]** `plan-context-*`(객체만)·`chat-request-*`(전체) 쓰임과 `make_request` 헬퍼 명시, A-10·question-with-plan 전체 JSON | 소비자 |
| 53 | C1a-8 | **[v3]** 프롬프트 규칙별 Issue 배치(#35/#21/#23), D-10은 #21 기존 범위라 G-3에서 제외, `prompts.py` 순서 #21→#22→#23→#35 | 소비자 |
| 54 | G-7 | **[v3]** `PlanContextProvider`는 새 A팀 Issue(소비자 "#29에 합치기" 미채택, 아래 "후속 작업" 이유) | 제공자 |
| 55 | 후속 | **[v3]** G-2·G-4(#35), G-9(#41·#43), G-12(#19), G-14(#18), G-15(#43·#17·#12·#54·#49), G-18(#29) 배치 | 양쪽 일치 |

## 쟁점 (사람이 정함)

> 넷 다 사람이 선택지 A로 결정했다(D-059~D-062). 선택지와 영향 기록은 `plan-context-proposal.md`.

| 쟁점 | 내용 | 제공자 | 소비자 | 기획 추천 | 바뀌는 곳 |
|---|---|---|---|---|---|
| X-1 | 상대 표현("월 10만원 더")을 recalculate 인자로 만드는 법 | A | A(네 조건 모두 적용, 수용 기준은 #21 사례) | A(되묻기) | 프롬프트 규칙 7, #21 |
| X-2 | 세율을 모델이 말해도 되는가 | A(v1의 B에서 바꿈, 형식 `N.N%` 끝 0 제거 조건) | A(B면 finance-domain-reviewer 확인) | A(display 추가), finance-domain-reviewer 확인 권고 | C1a-5·C1a-6 표, 허용 패턴, 요구 키, 프롬프트 규칙 8, 부록 A의 `assumptions.taxRatePct` 줄, #28 |
| X-3 | 일반 금액 0원·1만원 미만 표기 | A | A | A(경계 고정) | C1a-6 경계 표 두 줄, 부록 A-7 두 값, #28, internal-calc C2-6(G-11) |
| X-4 | 이미 초과 계획에 F-3(설명 요청)을 부르는가 | A | A | A(부르지 않음) | #54·#49 수용 기준, #12 계약 문장. 이 계약 본문은 바뀌지 않음 |

## 이 계약 때문에 생기는 후속 작업

> D-058: **기존 moeun Issue 본문(수용 기준·변경 범위·선행)에 반영**한다. 같은 범위의 Issue가 없을 때만 새로 만든다. 번호는 양쪽 검토자가 moeun Issue를 조회해 확인한 것이다.

| # | 작업 | 팀 | Issue | 선행 변경·메모 |
|---|---|---|---|---|
| G-1 | 최종본을 moeun `docs/api/plan-context.md`·`ai-server/README.md`로 옮김(422 예외 문장 포함, G-6 흡수). fixture 14개를 `docs/api/examples/plan-context/`에 둠(A-10·question-with-plan은 부록의 전체 JSON, `model-input-basic.json`은 문구 두 키 제외) | 공통 | **#11** | #11 `paths`에 `docs/api/examples/**` 추가 |
| G-2 | `PlanContext` 모델(필수/선택), display 필터·패턴, `build_messages`(모델 전달 필드, 문구 매핑, `null` 표시, `ensure_ascii=False`), `run()` 검사 2~5, 로그에 본문 안 남김 | B | **#35** | 수용 기준을 C1a-8 검사 표로 교체. paths에 `ai-server/tests/test_plan_context.py`, fixture 읽기 헬퍼 추가. 선행 `#11, #21`에 **#22, #23, #18** 추가 |
| G-3 | 프롬프트 규칙: 1·2·3·5·6·8·9 → #35, 7(X-1) → #21, 4 → #23 | B | **#35, #21, #23** | D-10(조건 7→4)은 #21 기존 범위라 G-3에서 제외. #21에는 "더/덜" 되묻기 사례를 "모호한 발화는 되묻는다"에 추가. #35 선행에 `prompts.py` 순서(#21→#22→#23→#35) 명시 |
| G-4 | C1a-13 fixture 테스트(dict 비교, 오염·누락·불일치·null·초과 EXPLAIN), `make_request` 헬퍼, 수동 평가 3~5건 결과를 PR 본문에 | B | **#35** | `FakeCalc`를 internal-calc A-1 모양으로 바꾸는 일은 #23(선행). #35 paths에 `docs/api/examples/**` 읽기 |
| G-5a | 빌더 단위 테스트: 손으로 만든 입력 → display = fixture `display`, 요구 키 불변식, `goalReachMonth` 방출 규칙(미달 BAD 1건), 라벨-`isAchieved` 일치 | A | **#28**(G-8a와 같은 Issue) | |
| G-5b | `PlanContextView` 직렬화 = fixture 전체, 숫자 스케일 무시, `memberId` 없음, `isAchieved` 키 이름 | A | **새 Issue**(G-7) | |
| G-6 | (G-1에 흡수) 422 본문 FastAPI 기본 유지, README 문장만 정정 | B | **#11** | 코드 변경 없음 |
| G-7 | `PlanContextProvider`(3메서드)·`PlanRunRef`·`PlanContextView`·`ConditionsView`, 소유권 2단계, QUESTION은 #29 Q1 서비스 재사용, 메서드별 `@Transactional` | A | **새 Issue** `[calc] PlanContextProvider(C-1a)` | 선행 **#19·#28·#29·#32**. 소비자의 "#29에 합치기"안을 채택하지 않음(이유 아래) |
| G-8a | `ResultDisplayBuilder`(공유, 결과·조건 접두어, 추가 키 4개, `goalReachMonth` 방출 규칙) | A | **#28**(불가 시 #29 + #29 선행에 #28) | #28 paths에 `calc/application/ResultDisplayBuilder.java`와 테스트 추가, 범위를 "Formatter + 공유 display 맵 빌더"로. #30·#32 본문의 "display 맵 빌더"를 "공유 빌더 사용"으로 |
| G-8b | Formatter 형식: 음수 금액(합의), X-3 결과, X-2 A면 `N.N%`(끝 0 제거) | A | **#28** | 음수 줄은 지금 넣음. X-3·X-2 줄은 결정 뒤 |
| G-9a | chat 리스너: 호출 직전 `findForCalcRun`/`findForCurrentPlan`, `baselineScenario`는 `chat_message` 값, 생성 실패 → 미호출 `FAILED`·`FAILURE`, **트랜잭션 없이 HTTP 호출**(C1a-10 방법 (a)/(b), 전파 속성 지원 여부 먼저 확인) | B | **#41** | paths에 `backend/.claude/rules/modulith.md` 추가(예외 1줄) |
| G-9b | F-3: `findPlanRun`으로 404 판단·`chat_message.baseline_scenario` 저장, EXPLAIN 요청 발행 | B | **#43** | 선행에 **G-7 새 Issue** 추가(지금 #41·#29뿐) |
| G-10 | `CalcResultView`·`ScenarioResultView`를 calc 루트에 둠. #32 paths에 `calc/CalcResultView.java`, `calc/ScenarioResultView.java` 추가, paths 설명의 `calc/web/**` 괄호에서 두 이름을 뺌 | A | **#32** | 동작 변화 없음 |
| G-11 | internal-calc.md 문서 정정: C2-4 `calc.CalcResultView`(루트), C2-4 "`CALCULATED`만"·"`excludedItems` 미사용"은 `/internal/calc` 한정, `ResultDisplayBuilder`(#28) 반영, 음수 금액·X-3 결과 경계 표 추가, C3-2 문구표 키 연결 | 기획 | 문서(+ **#10** 본문 정정) | 동작 변화 없음 |
| G-12 | plan 공개 API `findVersion(memberId, planVersionId)` + 현재 계획 조회에 기준 시나리오(문자열) 포함 | A | **#19** | 수용 기준 1줄 추가 |
| G-13 | `backend/.claude/rules/persistence.md`에 "calc_run은 회원 키가 없어 plan 공개 API로 소유권 확인" 예외 1줄 | A | **새 Issue**(G-7) | 새 Issue paths에 이 파일 |
| G-14 | 문구표 키 이름 고정 `chat.noPlan`, `chat.alreadyExceeded`, `excluded.<CODE>` 5개, `scenarioMethod.<CODE>` 2개(TBD-01 전 **임시 문장**, 빈 값 금지) | 공통 | **#18** | ai-server 상수 dict는 #18이 늦을 때만 |
| G-15a | F-3 404: 없는 calcRunId·남의 기록·CHAT 기록 모두 `404 NOT_FOUND` | B | **#43** | |
| G-15b | 전역 오류 처리에서 `NOT_FOUND` → ProblemDetail `code=NOT_FOUND` | A | **#17**(#74는 #17에 합쳐 닫힘) | |
| G-15c | 프론트 API 계약 문장 2개: F-3 404 규칙, X-4 결과(초과 계획은 F-3을 부르지 않음) | 공통 | **#12**(계약 문장만) | X-4 결정 전에는 "결정 대기" |
| G-15d | X-4: 결과 화면이 초과 계획이면 설명을 요청하지 않음 | B·A | **#54**(B), **#49**(A, 초과 안내 수용 기준에 교차참조) | X-4 결정 뒤 |
| G-16 | `b-team-contracts.md` C-1a와 Issue #11 본문을 이 계약에 맞춤 | 기획 | 문서 + **#11** 본문 | D-058 |
| G-17 | 엔진 불변식: `isAchieved=true` ⇒ `goalReachMonth` non-null·`targetMonth` 이하 | A | **#27** | 수용 기준 1줄 |
| G-18 | Q1 서비스가 "활성 버전과 같은 최신 PLAN 기록이 있으면 재기록 안 함"을 본문에서 확인 | A | **#29** | 소비자 요청(반대 아님) |

**G-7을 새 Issue로 하는 이유(제공자안 채택)**: G-7은 A팀 영역(calc)이라 A팀 의견을 따른다. 소비자는 Q1 서비스가 #29에 있으니 #29에 합치자고 했지만, #29는 #32의 선행이다. G-7은 `CalcResultView`(#32, G-10)를 써야 하므로 #29에 넣으면 "#29가 #32를 기다리고 #32가 #29를 기다리는" 순서가 생긴다. 같은 범위의 기존 Issue도 없다(D-058의 "합칠 Issue 없음" 조건 충족).

**task-planner 전달(이 계약 범위 밖)**: #30과 #32는 paths `calc/web/**`가 겹쳐 동시에 진행할 수 없다(moeun 루트 `CLAUDE.md`). 빌더를 #28로 빼서 공유 코드 때문에 서로 기다릴 일은 없어졌다.

---

## 부록 A. 예시 JSON (fixture용)

공통 계획(A-1): 목표 2,000만원, 보유 자산 500만원, 월 30만원, 36개월, 적금 금리 미입력(기본 3.12%), 비중 미입력(5:5), 시작월 2026-11. internal-calc 부록 A-1의 `current`와 같다.

> `assumptions.taxRatePct` display 줄은 **[D-060]**일 때만 있다. B면 A-1~A-7, A-10의 이 줄을 지운다

### A-1. 기본 — ETF 포함, 3구간 모두 미달 (`plan-context-basic.json`)

```json
{
  "calcRunId": 540,
  "conditions": {
    "goalAmount": 20000000,
    "heldAssets": 5000000,
    "monthlySavingAmount": 300000,
    "targetPeriodMonths": 36,
    "savingsRatioPct": 50,
    "savingsRateInputPct": 3.12
  },
  "result": {
    "status": "CALCULATED",
    "goalAmount": 20000000,
    "calcStartMonth": "2026-11",
    "targetMonth": "2029-11",
    "baselineScenario": "AVG",
    "scenarios": [
      {
        "scenario": "GOOD",
        "annualReturnPct": 14.2,
        "afterTaxAsset": 18450000,
        "principal": 15800000,
        "afterTaxGain": 2650000,
        "gapToGoal": -1550000,
        "isAchieved": false,
        "goalReachMonth": null
      },
      {
        "scenario": "AVG",
        "annualReturnPct": 9.8,
        "afterTaxAsset": 17120000,
        "principal": 15800000,
        "afterTaxGain": 1320000,
        "gapToGoal": -2880000,
        "isAchieved": false,
        "goalReachMonth": null
      },
      {
        "scenario": "BAD",
        "annualReturnPct": 1.1,
        "afterTaxAsset": 15980000,
        "principal": 15800000,
        "afterTaxGain": 180000,
        "gapToGoal": -4020000,
        "isAchieved": false,
        "goalReachMonth": null
      }
    ],
    "requiredMonthlySaving": null,
    "assumptions": {
      "savingsRatePct": 3.12,
      "isDefaultSavingsRate": true,
      "savingsRateBaseMonth": "2026-10",
      "savingsRatioPct": 50,
      "taxRatePct": 15.4,
      "scenarioMethod": "ROLLING_DISTRIBUTION",
      "sp500BaseDate": "2026-10-31",
      "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
    },
    "dataVersions": {
      "savingsRateVersionId": 3,
      "sp500VersionId": 5,
      "calcParamVersionId": 2,
      "engineVersion": "1.0.0"
    }
  },
  "display": {
    "goalAmount": "약 2,000만원",
    "calcStartMonth": "2026년 11월",
    "targetMonth": "2029년 11월",
    "GOOD.afterTaxAsset": "약 1,845만원",
    "GOOD.principal": "약 1,580만원",
    "GOOD.afterTaxGain": "약 265만원",
    "GOOD.gapToGoal": "-약 155만원 미달",
    "AVG.afterTaxAsset": "약 1,712만원",
    "AVG.principal": "약 1,580만원",
    "AVG.afterTaxGain": "약 132만원",
    "AVG.gapToGoal": "-약 288만원 미달",
    "BAD.afterTaxAsset": "약 1,598만원",
    "BAD.principal": "약 1,580만원",
    "BAD.afterTaxGain": "약 18만원",
    "BAD.gapToGoal": "-약 402만원 미달",
    "conditions.heldAssets": "약 500만원",
    "conditions.monthlySavingAmount": "약 30만원",
    "conditions.targetPeriodMonths": "3년 0개월",
    "conditions.savingsRatioPct": "적금 50 : ETF 50",
    "conditions.savingsRateInputPct": "연 3.12%",
    "assumptions.savingsRateBaseMonth": "2026년 10월",
    "assumptions.sp500BaseDate": "2026년 10월",
    "assumptions.taxRatePct": "15.4%"
  }
}
```

### A-2. ETF 0% — AVG 1개 (`plan-context-etf0.json`)

계획: A-1과 같고 비중만 `적금 100 : ETF 0`.

```json
{
  "calcRunId": 541,
  "conditions": {
    "goalAmount": 20000000,
    "heldAssets": 5000000,
    "monthlySavingAmount": 300000,
    "targetPeriodMonths": 36,
    "savingsRatioPct": 100,
    "savingsRateInputPct": 3.12
  },
  "result": {
    "status": "CALCULATED",
    "goalAmount": 20000000,
    "calcStartMonth": "2026-11",
    "targetMonth": "2029-11",
    "baselineScenario": "AVG",
    "scenarios": [
      {
        "scenario": "AVG",
        "annualReturnPct": null,
        "afterTaxAsset": 15954412,
        "principal": 15800000,
        "afterTaxGain": 154412,
        "gapToGoal": -4045588,
        "isAchieved": false,
        "goalReachMonth": null
      }
    ],
    "requiredMonthlySaving": null,
    "assumptions": {
      "savingsRatePct": 3.12,
      "isDefaultSavingsRate": true,
      "savingsRateBaseMonth": "2026-10",
      "savingsRatioPct": 100,
      "taxRatePct": 15.4,
      "scenarioMethod": null,
      "sp500BaseDate": null,
      "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
    },
    "dataVersions": {
      "savingsRateVersionId": 3,
      "sp500VersionId": null,
      "calcParamVersionId": 2,
      "engineVersion": "1.0.0"
    }
  },
  "display": {
    "goalAmount": "약 2,000만원",
    "calcStartMonth": "2026년 11월",
    "targetMonth": "2029년 11월",
    "AVG.afterTaxAsset": "약 1,595만원",
    "AVG.principal": "약 1,580만원",
    "AVG.afterTaxGain": "약 15만원",
    "AVG.gapToGoal": "-약 405만원 미달",
    "conditions.heldAssets": "약 500만원",
    "conditions.monthlySavingAmount": "약 30만원",
    "conditions.targetPeriodMonths": "3년 0개월",
    "conditions.savingsRatioPct": "적금 100 : ETF 0",
    "conditions.savingsRateInputPct": "연 3.12%",
    "assumptions.savingsRateBaseMonth": "2026년 10월",
    "assumptions.taxRatePct": "15.4%"
  }
}
```

### A-3. 이미 목표 초과 (`plan-context-exceeded.json`)

계획: A-1에서 보유 자산만 2,500만원.

```json
{
  "calcRunId": 542,
  "conditions": {
    "goalAmount": 20000000,
    "heldAssets": 25000000,
    "monthlySavingAmount": 300000,
    "targetPeriodMonths": 36,
    "savingsRatioPct": 50,
    "savingsRateInputPct": 3.12
  },
  "result": {
    "status": "ALREADY_EXCEEDED",
    "goalAmount": 20000000,
    "calcStartMonth": "2026-11",
    "targetMonth": "2029-11",
    "baselineScenario": "AVG",
    "scenarios": [],
    "requiredMonthlySaving": null,
    "assumptions": {
      "savingsRatePct": 3.12,
      "isDefaultSavingsRate": true,
      "savingsRateBaseMonth": "2026-10",
      "savingsRatioPct": 50,
      "taxRatePct": 15.4,
      "scenarioMethod": "ROLLING_DISTRIBUTION",
      "sp500BaseDate": "2026-10-31",
      "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
    },
    "dataVersions": {
      "savingsRateVersionId": 3,
      "sp500VersionId": 5,
      "calcParamVersionId": 2,
      "engineVersion": "1.0.0"
    }
  },
  "display": {
    "goalAmount": "약 2,000만원",
    "calcStartMonth": "2026년 11월",
    "targetMonth": "2029년 11월",
    "conditions.heldAssets": "약 2,500만원",
    "conditions.monthlySavingAmount": "약 30만원",
    "conditions.targetPeriodMonths": "3년 0개월",
    "conditions.savingsRatioPct": "적금 50 : ETF 50",
    "conditions.savingsRateInputPct": "연 3.12%",
    "assumptions.savingsRateBaseMonth": "2026년 10월",
    "assumptions.sp500BaseDate": "2026년 10월",
    "assumptions.taxRatePct": "15.4%"
  }
}
```

(`ALREADY_EXCEEDED`에서 엔진이 `assumptions`·`dataVersions`를 어떻게 채우는지는 #27 구현을 따른다. 키는 항상 있다.)

### A-4. `ChatRequest` 전체

#### EXPLAIN (`chat-request-explain.json`)

```json
{
  "memberId": 7,
  "messageId": 1029,
  "mode": "EXPLAIN",
  "text": null,
  "baselineScenario": "AVG",
  "calcRunId": 540,
  "planContext": {
    "calcRunId": 540,
    "conditions": {
      "goalAmount": 20000000,
      "heldAssets": 5000000,
      "monthlySavingAmount": 300000,
      "targetPeriodMonths": 36,
      "savingsRatioPct": 50,
      "savingsRateInputPct": 3.12
    },
    "result": {
      "status": "CALCULATED",
      "goalAmount": 20000000,
      "calcStartMonth": "2026-11",
      "targetMonth": "2029-11",
      "baselineScenario": "AVG",
      "scenarios": [
        {
          "scenario": "GOOD",
          "annualReturnPct": 14.2,
          "afterTaxAsset": 18450000,
          "principal": 15800000,
          "afterTaxGain": 2650000,
          "gapToGoal": -1550000,
          "isAchieved": false,
          "goalReachMonth": null
        },
        {
          "scenario": "AVG",
          "annualReturnPct": 9.8,
          "afterTaxAsset": 17120000,
          "principal": 15800000,
          "afterTaxGain": 1320000,
          "gapToGoal": -2880000,
          "isAchieved": false,
          "goalReachMonth": null
        },
        {
          "scenario": "BAD",
          "annualReturnPct": 1.1,
          "afterTaxAsset": 15980000,
          "principal": 15800000,
          "afterTaxGain": 180000,
          "gapToGoal": -4020000,
          "isAchieved": false,
          "goalReachMonth": null
        }
      ],
      "requiredMonthlySaving": null,
      "assumptions": {
        "savingsRatePct": 3.12,
        "isDefaultSavingsRate": true,
        "savingsRateBaseMonth": "2026-10",
        "savingsRatioPct": 50,
        "taxRatePct": 15.4,
        "scenarioMethod": "ROLLING_DISTRIBUTION",
        "sp500BaseDate": "2026-10-31",
        "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
      },
      "dataVersions": {
        "savingsRateVersionId": 3,
        "sp500VersionId": 5,
        "calcParamVersionId": 2,
        "engineVersion": "1.0.0"
      }
    },
    "display": {
      "goalAmount": "약 2,000만원",
      "calcStartMonth": "2026년 11월",
      "targetMonth": "2029년 11월",
      "GOOD.afterTaxAsset": "약 1,845만원",
      "GOOD.principal": "약 1,580만원",
      "GOOD.afterTaxGain": "약 265만원",
      "GOOD.gapToGoal": "-약 155만원 미달",
      "AVG.afterTaxAsset": "약 1,712만원",
      "AVG.principal": "약 1,580만원",
      "AVG.afterTaxGain": "약 132만원",
      "AVG.gapToGoal": "-약 288만원 미달",
      "BAD.afterTaxAsset": "약 1,598만원",
      "BAD.principal": "약 1,580만원",
      "BAD.afterTaxGain": "약 18만원",
      "BAD.gapToGoal": "-약 402만원 미달",
      "conditions.heldAssets": "약 500만원",
      "conditions.monthlySavingAmount": "약 30만원",
      "conditions.targetPeriodMonths": "3년 0개월",
      "conditions.savingsRatioPct": "적금 50 : ETF 50",
      "conditions.savingsRateInputPct": "연 3.12%",
      "assumptions.savingsRateBaseMonth": "2026년 10월",
      "assumptions.sp500BaseDate": "2026년 10월",
      "assumptions.taxRatePct": "15.4%"
    }
  },
  "history": []
}
```

- `memberId`는 `ChatRequest` 최상위에만 있다(D-030). `calcRunId`(540) = `planContext.calcRunId`(540).

#### QUESTION, 계획 없음 (`chat-request-question-no-plan.json`)

```json
{
  "memberId": 7,
  "messageId": 1030,
  "mode": "QUESTION",
  "text": "ETF가 뭐예요?",
  "baselineScenario": "AVG",
  "calcRunId": null,
  "planContext": null,
  "history": []
}
```

#### QUESTION, 계획 있음 (`chat-request-question-with-plan.json`)

**`ChatRequest.calcRunId=null`이고 `planContext.calcRunId=540`인 것이 정상**이며 400이 나지 않는다.

```json
{
  "memberId": 7,
  "messageId": 1031,
  "mode": "QUESTION",
  "text": "세금은 얼마나 떼요?",
  "baselineScenario": "AVG",
  "calcRunId": null,
  "planContext": {
    "calcRunId": 540,
    "conditions": {
      "goalAmount": 20000000,
      "heldAssets": 5000000,
      "monthlySavingAmount": 300000,
      "targetPeriodMonths": 36,
      "savingsRatioPct": 50,
      "savingsRateInputPct": 3.12
    },
    "result": {
      "status": "CALCULATED",
      "goalAmount": 20000000,
      "calcStartMonth": "2026-11",
      "targetMonth": "2029-11",
      "baselineScenario": "AVG",
      "scenarios": [
        {
          "scenario": "GOOD",
          "annualReturnPct": 14.2,
          "afterTaxAsset": 18450000,
          "principal": 15800000,
          "afterTaxGain": 2650000,
          "gapToGoal": -1550000,
          "isAchieved": false,
          "goalReachMonth": null
        },
        {
          "scenario": "AVG",
          "annualReturnPct": 9.8,
          "afterTaxAsset": 17120000,
          "principal": 15800000,
          "afterTaxGain": 1320000,
          "gapToGoal": -2880000,
          "isAchieved": false,
          "goalReachMonth": null
        },
        {
          "scenario": "BAD",
          "annualReturnPct": 1.1,
          "afterTaxAsset": 15980000,
          "principal": 15800000,
          "afterTaxGain": 180000,
          "gapToGoal": -4020000,
          "isAchieved": false,
          "goalReachMonth": null
        }
      ],
      "requiredMonthlySaving": null,
      "assumptions": {
        "savingsRatePct": 3.12,
        "isDefaultSavingsRate": true,
        "savingsRateBaseMonth": "2026-10",
        "savingsRatioPct": 50,
        "taxRatePct": 15.4,
        "scenarioMethod": "ROLLING_DISTRIBUTION",
        "sp500BaseDate": "2026-10-31",
        "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
      },
      "dataVersions": {
        "savingsRateVersionId": 3,
        "sp500VersionId": 5,
        "calcParamVersionId": 2,
        "engineVersion": "1.0.0"
      }
    },
    "display": {
      "goalAmount": "약 2,000만원",
      "calcStartMonth": "2026년 11월",
      "targetMonth": "2029년 11월",
      "GOOD.afterTaxAsset": "약 1,845만원",
      "GOOD.principal": "약 1,580만원",
      "GOOD.afterTaxGain": "약 265만원",
      "GOOD.gapToGoal": "-약 155만원 미달",
      "AVG.afterTaxAsset": "약 1,712만원",
      "AVG.principal": "약 1,580만원",
      "AVG.afterTaxGain": "약 132만원",
      "AVG.gapToGoal": "-약 288만원 미달",
      "BAD.afterTaxAsset": "약 1,598만원",
      "BAD.principal": "약 1,580만원",
      "BAD.afterTaxGain": "약 18만원",
      "BAD.gapToGoal": "-약 402만원 미달",
      "conditions.heldAssets": "약 500만원",
      "conditions.monthlySavingAmount": "약 30만원",
      "conditions.targetPeriodMonths": "3년 0개월",
      "conditions.savingsRatioPct": "적금 50 : ETF 50",
      "conditions.savingsRateInputPct": "연 3.12%",
      "assumptions.savingsRateBaseMonth": "2026년 10월",
      "assumptions.sp500BaseDate": "2026년 10월",
      "assumptions.taxRatePct": "15.4%"
    }
  },
  "history": []
}
```

### A-5. 모델 입력 — A-1에 C1a-8 적용 (`model-input-basic.json`)

**[v3]** 파일에는 `excludedNotes`·`scenarioMethodNote`가 없다. 테스트가 두 키를 문구표에서 만들어 `result.assumptions`에 덧붙인 뒤 dict 비교한다(C1a-13).

```json
{
  "result": {
    "status": "CALCULATED",
    "scenarios": [
      { "scenario": "GOOD", "isAchieved": false },
      { "scenario": "AVG", "isAchieved": false },
      { "scenario": "BAD", "isAchieved": false }
    ],
    "assumptions": {
      "isDefaultSavingsRate": true
    }
  },
  "display": {
    "goalAmount": "약 2,000만원",
    "calcStartMonth": "2026년 11월",
    "targetMonth": "2029년 11월",
    "GOOD.afterTaxAsset": "약 1,845만원",
    "GOOD.principal": "약 1,580만원",
    "GOOD.afterTaxGain": "약 265만원",
    "GOOD.gapToGoal": "-약 155만원 미달",
    "AVG.afterTaxAsset": "약 1,712만원",
    "AVG.principal": "약 1,580만원",
    "AVG.afterTaxGain": "약 132만원",
    "AVG.gapToGoal": "-약 288만원 미달",
    "BAD.afterTaxAsset": "약 1,598만원",
    "BAD.principal": "약 1,580만원",
    "BAD.afterTaxGain": "약 18만원",
    "BAD.gapToGoal": "-약 402만원 미달",
    "conditions.heldAssets": "약 500만원",
    "conditions.monthlySavingAmount": "약 30만원",
    "conditions.targetPeriodMonths": "3년 0개월",
    "conditions.savingsRatioPct": "적금 50 : ETF 50",
    "conditions.savingsRateInputPct": "연 3.12%",
    "assumptions.savingsRateBaseMonth": "2026년 10월",
    "assumptions.sp500BaseDate": "2026년 10월",
    "assumptions.taxRatePct": "15.4%"
  }
}
```

테스트가 덧붙이는 두 키(A-1 기준):
```python
expected["result"]["assumptions"]["scenarioMethodNote"] = COPY["scenarioMethod.ROLLING_DISTRIBUTION"]
expected["result"]["assumptions"]["excludedNotes"] = [COPY[f"excluded.{c}"] for c in plan_context["result"]["assumptions"]["excludedItems"]]
```
`excluded.EXCHANGE_RATE`만 D-027 문장("환율 변동은 반영하지 않았어요")으로 고정이고, 이 값은 별도 단언 1건으로 확인한다.

- 없는 것: `calcRunId`, `conditions`(raw), `memberId`, `baselineScenario`(별도 태그), 원 단위 금액·수익률, 코드(`excludedItems`, `scenarioMethod`), `dataVersions`, raw `taxRatePct`.

### A-6. 달성·미달 섞임 (`plan-context-achieved.json`)

계획: A-1에서 월 저축액만 40만원. GOOD·AVG 달성, BAD 미달.

```json
{
  "calcRunId": 543,
  "conditions": {
    "goalAmount": 20000000,
    "heldAssets": 5000000,
    "monthlySavingAmount": 400000,
    "targetPeriodMonths": 36,
    "savingsRatioPct": 50,
    "savingsRateInputPct": 3.12
  },
  "result": {
    "status": "CALCULATED",
    "goalAmount": 20000000,
    "calcStartMonth": "2026-11",
    "targetMonth": "2029-11",
    "baselineScenario": "AVG",
    "scenarios": [
      {
        "scenario": "GOOD",
        "annualReturnPct": 14.2,
        "afterTaxAsset": 22710000,
        "principal": 19400000,
        "afterTaxGain": 3310000,
        "gapToGoal": 2710000,
        "isAchieved": true,
        "goalReachMonth": "2029-05"
      },
      {
        "scenario": "AVG",
        "annualReturnPct": 9.8,
        "afterTaxAsset": 21020000,
        "principal": 19400000,
        "afterTaxGain": 1620000,
        "gapToGoal": 1020000,
        "isAchieved": true,
        "goalReachMonth": "2029-09"
      },
      {
        "scenario": "BAD",
        "annualReturnPct": 1.1,
        "afterTaxAsset": 19620000,
        "principal": 19400000,
        "afterTaxGain": 220000,
        "gapToGoal": -380000,
        "isAchieved": false,
        "goalReachMonth": null
      }
    ],
    "requiredMonthlySaving": null,
    "assumptions": {
      "savingsRatePct": 3.12,
      "isDefaultSavingsRate": true,
      "savingsRateBaseMonth": "2026-10",
      "savingsRatioPct": 50,
      "taxRatePct": 15.4,
      "scenarioMethod": "ROLLING_DISTRIBUTION",
      "sp500BaseDate": "2026-10-31",
      "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
    },
    "dataVersions": {
      "savingsRateVersionId": 3,
      "sp500VersionId": 5,
      "calcParamVersionId": 2,
      "engineVersion": "1.0.0"
    }
  },
  "display": {
    "goalAmount": "약 2,000만원",
    "calcStartMonth": "2026년 11월",
    "targetMonth": "2029년 11월",
    "GOOD.afterTaxAsset": "약 2,271만원",
    "GOOD.principal": "약 1,940만원",
    "GOOD.afterTaxGain": "약 331만원",
    "GOOD.gapToGoal": "+약 271만원 달성",
    "GOOD.goalReachMonth": "2029년 5월",
    "AVG.afterTaxAsset": "약 2,102만원",
    "AVG.principal": "약 1,940만원",
    "AVG.afterTaxGain": "약 162만원",
    "AVG.gapToGoal": "+약 102만원 달성",
    "AVG.goalReachMonth": "2029년 9월",
    "BAD.afterTaxAsset": "약 1,962만원",
    "BAD.principal": "약 1,940만원",
    "BAD.afterTaxGain": "약 22만원",
    "BAD.gapToGoal": "-약 38만원 미달",
    "conditions.heldAssets": "약 500만원",
    "conditions.monthlySavingAmount": "약 40만원",
    "conditions.targetPeriodMonths": "3년 0개월",
    "conditions.savingsRatioPct": "적금 50 : ETF 50",
    "conditions.savingsRateInputPct": "연 3.12%",
    "assumptions.savingsRateBaseMonth": "2026년 10월",
    "assumptions.sp500BaseDate": "2026년 10월",
    "assumptions.taxRatePct": "15.4%"
  }
}
```

(검산: `19,400,000 = 5,000,000 + 400,000 × 36`. `isAchieved=true`인 GOOD·AVG는 `goalReachMonth` 키가 요구 키다. GOOD 2029-05, AVG 2029-09 모두 목표월 2029-11 이하(G-17). "중간에 닿았다가 목표월에 내려온 BAD"는 fixture가 아니라 G-5a 빌더 테스트에서 raw `goalReachMonth`를 non-null로 바꿔 확인한다.)

### A-7. 보유 자산 0원·1만원 미만 이득 (`plan-context-zero-held.json`, **X-3 의존**)

계획: 목표 100만원, 보유 자산 0원, 월 10만원, 3개월, 적금 100%, 기본금리 3.12%.

```json
{
  "calcRunId": 544,
  "conditions": {
    "goalAmount": 1000000,
    "heldAssets": 0,
    "monthlySavingAmount": 100000,
    "targetPeriodMonths": 3,
    "savingsRatioPct": 100,
    "savingsRateInputPct": 3.12
  },
  "result": {
    "status": "CALCULATED",
    "goalAmount": 1000000,
    "calcStartMonth": "2026-11",
    "targetMonth": "2027-02",
    "baselineScenario": "AVG",
    "scenarios": [
      {
        "scenario": "AVG",
        "annualReturnPct": null,
        "afterTaxAsset": 301320,
        "principal": 300000,
        "afterTaxGain": 1320,
        "gapToGoal": -698680,
        "isAchieved": false,
        "goalReachMonth": null
      }
    ],
    "requiredMonthlySaving": null,
    "assumptions": {
      "savingsRatePct": 3.12,
      "isDefaultSavingsRate": true,
      "savingsRateBaseMonth": "2026-10",
      "savingsRatioPct": 100,
      "taxRatePct": 15.4,
      "scenarioMethod": null,
      "sp500BaseDate": null,
      "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
    },
    "dataVersions": {
      "savingsRateVersionId": 3,
      "sp500VersionId": null,
      "calcParamVersionId": 2,
      "engineVersion": "1.0.0"
    }
  },
  "display": {
    "goalAmount": "약 100만원",
    "calcStartMonth": "2026년 11월",
    "targetMonth": "2027년 2월",
    "AVG.afterTaxAsset": "약 30만원",
    "AVG.principal": "약 30만원",
    "AVG.afterTaxGain": "1만원 미만",
    "AVG.gapToGoal": "-약 70만원 미달",
    "conditions.heldAssets": "0원",
    "conditions.monthlySavingAmount": "약 10만원",
    "conditions.targetPeriodMonths": "0년 3개월",
    "conditions.savingsRatioPct": "적금 100 : ETF 0",
    "conditions.savingsRateInputPct": "연 3.12%",
    "assumptions.savingsRateBaseMonth": "2026년 10월",
    "assumptions.taxRatePct": "15.4%"
  }
}
```

(`conditions.heldAssets: "0원"`, `AVG.afterTaxGain: "1만원 미만"` 두 값은 **[D-061]** 기준이다 B면 `AVG.afterTaxGain`만 `"약 0만원"`, C면 둘 다 `"약 0만원"`.)

### A-8. 오염 입력 (`plan-context-polluted.json`)

A-1에 다음을 **더한** 것. 기대: 요청 성공, 모델 입력이 A-5(+ 테스트가 덧붙이는 두 키)와 dict로 같다.
- 최상위 `"loginId": "demo01"`, `result` 안 `"memberId": 7`
- `display`에 `"loginId": "demo01"`, `"current.AVG.afterTaxAsset": "약 1,712만원"`(비교 키), `"AVG.annualReturnPct": "연 9.8%"`(패턴 밖), `"BAD.goalReachMonth": 202911`(패턴 안이지만 값이 숫자 → 버림, `isAchieved=false`라 요구 키 아님)

### A-9. display 누락 (`plan-context-display-missing.json`)

A-1에서 `display`의 `"AVG.gapToGoal"` 한 줄만 지운 것. 기대: `AgentError("CONTEXT_DISPLAY_MISSING")` → 502, 모델 호출 없음.

### A-10. EXPLAIN 오류·초과 — 전체 JSON [v3]

#### `chat-request-explain-mismatch.json` — 기대: 400 `BAD_REQUEST`, 모델 호출 없음

A-4 EXPLAIN과 같고 최상위 `calcRunId`만 `999`(planContext는 540).

```json
{
  "memberId": 7,
  "messageId": 1032,
  "mode": "EXPLAIN",
  "text": null,
  "baselineScenario": "AVG",
  "calcRunId": 999,
  "planContext": {
    "calcRunId": 540,
    "conditions": {
      "goalAmount": 20000000,
      "heldAssets": 5000000,
      "monthlySavingAmount": 300000,
      "targetPeriodMonths": 36,
      "savingsRatioPct": 50,
      "savingsRateInputPct": 3.12
    },
    "result": {
      "status": "CALCULATED",
      "goalAmount": 20000000,
      "calcStartMonth": "2026-11",
      "targetMonth": "2029-11",
      "baselineScenario": "AVG",
      "scenarios": [
        {
          "scenario": "GOOD",
          "annualReturnPct": 14.2,
          "afterTaxAsset": 18450000,
          "principal": 15800000,
          "afterTaxGain": 2650000,
          "gapToGoal": -1550000,
          "isAchieved": false,
          "goalReachMonth": null
        },
        {
          "scenario": "AVG",
          "annualReturnPct": 9.8,
          "afterTaxAsset": 17120000,
          "principal": 15800000,
          "afterTaxGain": 1320000,
          "gapToGoal": -2880000,
          "isAchieved": false,
          "goalReachMonth": null
        },
        {
          "scenario": "BAD",
          "annualReturnPct": 1.1,
          "afterTaxAsset": 15980000,
          "principal": 15800000,
          "afterTaxGain": 180000,
          "gapToGoal": -4020000,
          "isAchieved": false,
          "goalReachMonth": null
        }
      ],
      "requiredMonthlySaving": null,
      "assumptions": {
        "savingsRatePct": 3.12,
        "isDefaultSavingsRate": true,
        "savingsRateBaseMonth": "2026-10",
        "savingsRatioPct": 50,
        "taxRatePct": 15.4,
        "scenarioMethod": "ROLLING_DISTRIBUTION",
        "sp500BaseDate": "2026-10-31",
        "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
      },
      "dataVersions": {
        "savingsRateVersionId": 3,
        "sp500VersionId": 5,
        "calcParamVersionId": 2,
        "engineVersion": "1.0.0"
      }
    },
    "display": {
      "goalAmount": "약 2,000만원",
      "calcStartMonth": "2026년 11월",
      "targetMonth": "2029년 11월",
      "GOOD.afterTaxAsset": "약 1,845만원",
      "GOOD.principal": "약 1,580만원",
      "GOOD.afterTaxGain": "약 265만원",
      "GOOD.gapToGoal": "-약 155만원 미달",
      "AVG.afterTaxAsset": "약 1,712만원",
      "AVG.principal": "약 1,580만원",
      "AVG.afterTaxGain": "약 132만원",
      "AVG.gapToGoal": "-약 288만원 미달",
      "BAD.afterTaxAsset": "약 1,598만원",
      "BAD.principal": "약 1,580만원",
      "BAD.afterTaxGain": "약 18만원",
      "BAD.gapToGoal": "-약 402만원 미달",
      "conditions.heldAssets": "약 500만원",
      "conditions.monthlySavingAmount": "약 30만원",
      "conditions.targetPeriodMonths": "3년 0개월",
      "conditions.savingsRatioPct": "적금 50 : ETF 50",
      "conditions.savingsRateInputPct": "연 3.12%",
      "assumptions.savingsRateBaseMonth": "2026년 10월",
      "assumptions.sp500BaseDate": "2026년 10월",
      "assumptions.taxRatePct": "15.4%"
    }
  },
  "history": []
}
```

#### `chat-request-explain-null.json` — 기대: 400 `BAD_REQUEST`, 모델 호출 없음

```json
{
  "memberId": 7,
  "messageId": 1033,
  "mode": "EXPLAIN",
  "text": null,
  "baselineScenario": "AVG",
  "calcRunId": 540,
  "planContext": null,
  "history": []
}
```

#### `chat-request-explain-exceeded.json` — 기대: 200, 모델 호출 없음, `messageType=EXPLANATION`, 본문 = 문구표 `chat.alreadyExceeded`, `calcRunId` 542

```json
{
  "memberId": 7,
  "messageId": 1034,
  "mode": "EXPLAIN",
  "text": null,
  "baselineScenario": "AVG",
  "calcRunId": 542,
  "planContext": {
    "calcRunId": 542,
    "conditions": {
      "goalAmount": 20000000,
      "heldAssets": 25000000,
      "monthlySavingAmount": 300000,
      "targetPeriodMonths": 36,
      "savingsRatioPct": 50,
      "savingsRateInputPct": 3.12
    },
    "result": {
      "status": "ALREADY_EXCEEDED",
      "goalAmount": 20000000,
      "calcStartMonth": "2026-11",
      "targetMonth": "2029-11",
      "baselineScenario": "AVG",
      "scenarios": [],
      "requiredMonthlySaving": null,
      "assumptions": {
        "savingsRatePct": 3.12,
        "isDefaultSavingsRate": true,
        "savingsRateBaseMonth": "2026-10",
        "savingsRatioPct": 50,
        "taxRatePct": 15.4,
        "scenarioMethod": "ROLLING_DISTRIBUTION",
        "sp500BaseDate": "2026-10-31",
        "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
      },
      "dataVersions": {
        "savingsRateVersionId": 3,
        "sp500VersionId": 5,
        "calcParamVersionId": 2,
        "engineVersion": "1.0.0"
      }
    },
    "display": {
      "goalAmount": "약 2,000만원",
      "calcStartMonth": "2026년 11월",
      "targetMonth": "2029년 11월",
      "conditions.heldAssets": "약 2,500만원",
      "conditions.monthlySavingAmount": "약 30만원",
      "conditions.targetPeriodMonths": "3년 0개월",
      "conditions.savingsRatioPct": "적금 50 : ETF 50",
      "conditions.savingsRateInputPct": "연 3.12%",
      "assumptions.savingsRateBaseMonth": "2026년 10월",
      "assumptions.sp500BaseDate": "2026년 10월",
      "assumptions.taxRatePct": "15.4%"
    }
  },
  "history": []
}
```

---

## 부록 B. v2 → v3에서 바뀐 것

| 항목 | v2 | v3 | 출처 |
|---|---|---|---|
| C1a-4·C1a-6·C1a-11 | `<S>.goalReachMonth`는 "값이 null이면 키 없음" | **`isAchieved=true`이고 non-null일 때만 키**. raw는 미달이어도 non-null일 수 있음을 명시. 미달 BAD 테스트 1건 | 소비자 반대 1 |
| C1a-4 | 불변식 없음 | `isAchieved=true` ⇒ `goalReachMonth` non-null·목표월 이하(G-17, #27) | 제공자 |
| C1a-6 | 빌더는 #32에서 처음 만듦 | **#28에서 만듦**(불가 시 #29 + 선행 #28), 빌더 테스트 함께, 요구 키 불변식 테스트 | 제공자 |
| C1a-6 | 음수 금액은 X-3에 묶임 | **X-3과 무관하게 합의, #28** | 제공자, 소비자 수용 |
| C1a-6 | 세율 형식 `15.4%` | X-2 A일 때 `N.N%` 끝 0 제거 조건 | 제공자 |
| C1a-5 | 문구 매핑 [전환기] 상수 dict로 시작 | #18이 먼저, 상수 dict는 대체 경로. `scenarioMethod.*` 임시 문장 필수 | 소비자 |
| C1a-8 | 프롬프트 규칙 목록 | 규칙별 Issue 열, 규칙 7을 네 조건 모두로, `prompts.py` 순서, D-10은 #21 | 소비자 |
| C1a-10 | `findPlanRun` 기준 시나리오 출처 미기재 | plan 공개 API가 문자열로 돌려주고 calc가 변환, PK 조회 3번 | 제공자 |
| C1a-10 | "트랜잭션 밖 HTTP"만 | `@ApplicationModuleListener` 새 트랜잭션 규칙과의 충돌 명시, 방법 (a)/(b), `modulith.md` 예외 1줄(전파 속성 지원 여부 미확인) | 제공자 |
| C1a-10 | Q1 서비스 "결과 화면" | #29 공개 서비스로 정정, 매 턴 INSERT 방지 확인(G-18) | 제공자, 소비자 |
| C1a-10 | F-3 404 → #12 | 구현 #43, ProblemDetail #17, 계약 문장 #12. CHAT 기록도 404 | 제공자, 소비자 |
| C1a-13 | G-5 하나, fixture 표 열 없음, 쓰임 설명 없음 | G-5a/5b, 숫자 스케일 무시 비교, Spring/ai-server 열, 파일 쓰임·`make_request` 헬퍼 | 제공자, 소비자 |
| A-5 | 자리표시자 `(문구표 ...)` 포함 | 두 키 제거, 테스트가 `COPY`로 덧붙임 | 소비자 |
| A-4·A-10 | question-with-plan·A-10은 "A-4에서 바꾼 값"만 | 전체 JSON | 소비자 |
| C1a-14 | D-10 → G-3 | D-10 → #21, D-11(`modulith.md`) 추가 | 소비자, 제공자 |
| 후속 작업 | "확인 필요" 다수 | 모두 Issue 번호로. G-5·G-9·G-15 분할, G-17·G-18 추가. G-7은 새 A팀 Issue(제공자안) | 양쪽 |
| 합의 목록 | 41건 | 55건 | — |
| 쟁점 | X-1~X-4 | 그대로 사람 결정. 네 쟁점 모두 양쪽·기획이 A | — |
