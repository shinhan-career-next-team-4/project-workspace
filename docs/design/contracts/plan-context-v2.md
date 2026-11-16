# `planContext` 계약 v2 (moeun #11, C-1a) — 검토 반영본

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 3단계(검토 반영). **결정이 아니라 합의안 초안이다.** 쟁점(X-1~X-4)은 사람이 정한다.
> - 입력: `plan-context-v1.md`(기획 초안), `review-plancontext-v1-provider.md`(A팀, "수정하면 수용"), `review-plancontext-v1-consumer.md`(B팀, "수정하면 수용")
> - 재사용: `internal-calc.md`(최종본) 원칙 0, C2-4 직렬화 표, C2-6 display 키·형식, C3-2 고정 문장, D-055·D-056·D-057
> - 기준: `docs/srs.md`(CP-04, CP-05, FR-AI-01·02·04·06·09·10, FR-RES-01·06, NFR-INT-01·03), `docs/decisions.md`(D-027, D-030, D-033, D-040, D-041, D-045, D-055, D-058)
>
> **표기**
> - **[합의]**: 양쪽이 수용했거나, 한쪽 수정 제안에 다른 쪽 이견이 없어 반영한 것.
> - **[X-n]**: 쟁점. 사람이 정한다. 본문에는 **기획 추천안을 임시로** 적고 표시해 두었다. 결정이 다르면 그 줄만 바꾼다.
> - **[기획 보완]**: 검토 의견에서 이어지는 빈칸을 기획이 메운 것(새 정책 아님). 재검토에서 확인한다.
> - 항목 ID(C1a-x, G-x, R-x, H-x)는 v1·검토와 같다. v1 → v2 변경은 맨 아래 "부록 B".

## 0. 이 계약의 원칙 (v1과 같음)

`internal-calc.md` §0을 그대로 따른다. 이 계약에서 중요한 것만 다시 적는다.

1. **숫자는 Spring만 만든다.** 모델이 말하는 금액·기간·시점·비율은 `display` 문자열을 그대로 인용한 것뿐이다(NFR-INT-01, FR-AI-02). **raw 금액은 모델에 넘기지 않는다**(C1a-8). 왜: 모델 입력에 원 단위 숫자가 없으면 반올림·뺄셈할 재료가 없다.
2. **JSON 키는 camelCase**, 금액은 원 정수, 기간은 개월 정수, 퍼센트는 숫자(`3.12` = 3.12%).
3. **null은 키를 빼지 않는다.** 단 `display`는 값이 없으면 키를 만들지 않는다(C2-6과 같음).
4. **받는 쪽은 모르는 키를 무시한다.** 이 계약에서 "무시" = 오류로 처리하지 않고 **모델에도 넘기지 않는다**.
5. **계정 식별 정보는 넣지 않는다**(D-030).
6. **새 라이브러리 없음.** Spring은 Jackson 기본, ai-server는 기존 pydantic `ApiModel`.

---

## C1a-1. 목적·범위 [합의, v1과 같음]

| 항목 | 값 |
|---|---|
| 무엇 | Spring → ai-server `POST /chat` 요청의 `planContext` 필드(`ChatRequest.plan_context`) |
| 뜻 | **한 계산 기록(`calc_run(PLAN)`)의 조건·결과·표시 문자열·가정**. 모델이 "지금 계획"을 말할 때 인용하는 유일한 숫자 출처 |
| 쓰는 곳 | `mode=EXPLAIN`(FR-AI-01·02), `mode=QUESTION`(FR-AI-06·09) |
| 쓰지 않는 곳 | 대화 재계산의 비교·차이는 `/internal/calc`(C2-3~C2-6)가 맡는다 |
| 담당 | 만드는 쪽 Spring `calc` 모듈(A팀, C1a-10). 쓰는 쪽 ai-server(B팀). 계약은 A·B 공동 |

## C1a-2. 최상위 구조

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
- **[합의] `result`는 `/internal/calc`의 `current`와 같은 DTO를 쓰되, 그 DTO를 calc 루트 공개 타입으로 둔다**: `calc.CalcResultView`, `calc.ScenarioResultView`(v1의 `calc.web.CalcResultView`에서 위치만 바뀜). 왜: `PlanContextView`(calc 루트, 공개 API)가 calc 하위 패키지(비공개) 타입을 노출하면 chat이 참조하는 순간 `ModularityTests`가 깨진다(제공자, `modulith.md`). `calc.CalcComparison`이 이미 루트에 있으므로 같은 자리다. internal-calc C2-4의 같은 문구 정정은 후속 G-10(동작 변화 없음).
- **[합의]** `calcRunId` 최상위 유지. 왜: EXPLAIN 일치 검사와, QUESTION에서 어떤 기록을 기준으로 답했는지 로그로 남길 유일한 값.
- **[합의]** 이 계약의 `result`는 internal-calc C2-4와 두 곳이 다르다: `status`에 `ALREADY_EXCEEDED`가 올 수 있고, `assumptions.excludedItems`를 소비자가 쓴다(C1a-11, C1a-8). ai-server가 두 계약에 같은 pydantic 모델을 쓰면 `status`를 `Literal["CALCULATED"]`로 만들지 않는다. internal-calc C2-4의 "항상 `CALCULATED`"·"`excludedItems` 미사용" 문장은 **그 경로에 대한 설명**이며, 문장 정정은 후속 G-11(internal-calc.md는 이 단계에서 고치지 않음).

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

- **[합의] 출처를 "`CalcInput`(ConditionResolver 결과)"로 통일**(제공자). 왜: `plan_version.savings_rate_input_pct`는 NULL일 수 있어 raw 컬럼을 읽으면 틀린다. 6개 값이 모두 `CalcInput`에 있으므로 투영 하나로 끝나고, #32 `conditions.current`(4키)와 같은 매퍼를 쓴다(키 2개만 더함).
- `CalcInput`의 `monthlySavingAmount`·`targetPeriodMonths`는 nullable 타입이다. 해커톤에서는 항상 값이 있지만(D-045) DTO는 nullable 그대로 두고 null이면 `null`로 보낸다(원칙 3).
- **[합의] 와이어에는 남기고 모델에는 넘기지 않는다.** 소비자는 "읽지 않으므로 빼도 된다"고 했지만 요구하지는 않았다. 남기는 이유: 제공자 비용이 매퍼 하나로 거의 없고, 로그·fixture 대조에 쓰이며, X-1에서 (B)를 고르면 그대로 쓴다. ai-server `PlanContext`는 이 객체를 **선택 필드**로 둔다(없거나 키가 바뀌어도 422가 나지 않음).

## C1a-4. `result` [합의]

`CalcResult`를 JSON으로 바꾼 것. internal-calc C2-4의 모양·직렬화 표를 그대로 쓴다. 다른 점만 적는다.

| 필드 | 이 계약에서의 규칙 |
|---|---|
| `status` | `CALCULATED` 또는 `ALREADY_EXCEEDED`. 초과면 `scenarios: []`(C1a-11) |
| `goalAmount`, `calcStartMonth`, `targetMonth` | C2-4와 같다(`"YYYY-MM"`) |
| `baselineScenario` | EXPLAIN: chat이 F-3 때 `chat_message.baseline_scenario`에 저장한 값. QUESTION: `plan.baseline_scenario`(C1a-10). 어느 경우든 `ChatRequest.baselineScenario`와 같다 |
| `scenarios[]` | **항상 GOOD·AVG·BAD 순서**. ETF 포함 3개, ETF 0% AVG 1개, 초과 0개. `monthlyPoints` **키 자체가 없다** |
| `requiredMonthlySaving` | 해커톤에서 항상 `null`(D-045) |
| `assumptions` | C1a-5 |
| `dataVersions` | 보낸다. 모델에 넘기지 않는다 |

- `gapToGoal = afterTaxAsset − goalAmount`, `afterTaxGain = afterTaxAsset − principal`, 0원은 달성(CP-01). 모두 Spring 값.
- 달성/미달은 raw `isAchieved`로 판단하고 display 라벨도 같은 판정을 따른다. 라벨과 `isAchieved`가 어긋나지 않는지는 **Spring 단위 테스트(G-5)**에서 잡고 ai-server fixture에는 두지 않는다(소비자).
- **[합의] `baselineScenario`는 모델 입력(`<plan_context>`)에서 뺀다.** 왜: `build_messages`가 이미 `<baseline_scenario>` 태그로 넣는다(소비자). 와이어에는 남는다.

## C1a-5. `assumptions` (`result.assumptions`) [합의, 세율은 X-2]

`calc.Assumptions` 그대로. 가정 보기(FR-RES-06)와 같은 원천. **`result` 안에 둔다**(R-5 a, 양쪽 찬성. 왜: `CalcResult.assumptions`가 이미 결과 안에 있어 최상위로 꺼내면 DTO가 하나 는다).

| 필드 | 타입 | 모델에 넘김 | display 키 | 비고 |
|---|---|---|---|---|
| `savingsRatePct` | number | 아니오 | (`conditions.savingsRateInputPct`) | |
| `isDefaultSavingsRate` | boolean | 예 | — | 기본금리 사용 여부 판단용 |
| `savingsRateBaseMonth` | `"YYYY-MM"` \| null | 아니오 | `assumptions.savingsRateBaseMonth` | null이면 display 키 없음 |
| `savingsRatioPct` | integer | 아니오 | (`conditions.savingsRatioPct`) | |
| `taxRatePct` | number | 아니오 | **[X-2]** 추천안: `assumptions.taxRatePct` | raw는 어느 안이든 모델에 넘기지 않는다 |
| `scenarioMethod` | `CAGR` \| `ROLLING_DISTRIBUTION` \| null | **코드는 아니오. 문구로 바꿔서 넘김** | — | ai-server가 문구표 `scenarioMethod.<CODE>` 문장으로 바꿔 `scenarioMethodNote`로 넣는다. null(ETF 0%)이면 넣지 않음 |
| `sp500BaseDate` | `"YYYY-MM-DD"` \| null | 아니오 | `assumptions.sp500BaseDate` | null이면 display 키 없음 |
| `excludedItems` | string[] | **코드는 아니오. 문구로 바꿔서 넘김** | — | ai-server가 문구표 `excluded.<CODE>` 문장 배열로 바꿔 `excludedNotes`로 넣는다 |

**[합의] 반영하지 않은 항목·3구간 산정 방식 문장 (R-6, H-5)**
- Spring은 **코드만** 보낸다(문구 문자열을 보내지 않음). 왜: planContext에 문구표 의존이 생기지 않고 display와 성격이 다른 맵이 늘지 않는다(제공자).
- ai-server가 코드 → 문구표 문장으로 바꿔 모델에 넣고, **모델은 그 문장을 글자 그대로 인용**한다. 모델이 코드를 풀어 쓰지 않는다. 왜: D-027 "환율 변동은 반영하지 않았어요"가 AI 문장에서도 화면과 같아야 하고, `ETF_DISTRIBUTION` 같은 코드의 뜻을 모델이 지어내면 안 된다(소비자). CP-05("프론트와 AI 서버가 문구표를 함께 읽음")를 그대로 이행하는 것이라 새 정책이 아니다. 제공자는 "글자 그대로가 필요하면 ai-server가 문구표를 읽는 쪽이 맞다 — 소비자 판단"으로 이견 없음.
- [전환기] 문구표 파일(#18)이 생기기 전에는 ai-server 상수 dict로 시작하고 #18에서 옮긴다. 테스트: "`ExcludedItem`·`ScenarioMethod` enum의 모든 코드에 문장이 있다".
- 모르는 코드(문장 없음)는 **버리고 경고 로그**를 남긴다(모델에 코드를 넘기지 않음).
- `scenarioMethod.<CODE>` 문장 내용은 TBD-01(3구간 산정 방식, 미결)을 따른다. 키만 이 계약에서 정한다.

## C1a-6. `display` 키·형식 — C2-6 재사용 [합의, 경계 형식은 X-3]

internal-calc **C2-6의 키 규칙·형식·경계 규칙(D-055)을 그대로 쓴다.** 비교가 없으므로 `<side>.` 접두어를 뺀다. C2-6의 기존 형식만 쓰는 키 4개를 더한다.

| 키 | 형식 | C2-6 대응 |
|---|---|---|
| `goalAmount` | `약 N만원` | `goalAmount` |
| `calcStartMonth` | `YYYY년 M월` | **추가** |
| `targetMonth` | `YYYY년 M월` | `<side>.targetMonth` |
| `<S>.afterTaxAsset`, `<S>.principal`, `<S>.afterTaxGain` | `약 N만원` | `<side>.<S>.*` |
| `<S>.gapToGoal` | [D-055] `-약 288만원 미달`, `+약 501만원 달성` | `<side>.<S>.gapToGoal` |
| `<S>.goalReachMonth` | `YYYY년 M월`. 값이 `null`이면 키 없음 | `<side>.<S>.goalReachMonth` |
| `conditions.heldAssets` | `약 N만원` | **추가** |
| `conditions.monthlySavingAmount` | `약 N만원` | `conditions.<side>.monthlySavingAmount` |
| `conditions.targetPeriodMonths` | `n년 n개월` | `conditions.<side>.targetPeriodMonths` |
| `conditions.savingsRatioPct` | `적금 a : ETF b` | `conditions.<side>.savingsRatioPct` |
| `conditions.savingsRateInputPct` | `연 N.NN%` | `conditions.<side>.savingsRateInputPct` |
| `assumptions.savingsRateBaseMonth` | `YYYY년 M월`. null이면 키 없음 | **추가** |
| `assumptions.sp500BaseDate` | `YYYY년 M월`(일은 버림). null이면 키 없음 | **추가** |
| `assumptions.taxRatePct` | **[X-2 추천안 A]** `15.4%` | 새 형식(쟁점) |

`<S>` = `GOOD` \| `AVG` \| `BAD`. 실제로 있는 시나리오만 키를 만든다.

경계 형식:

| 경우 | 형식 | 근거 |
|---|---|---|
| 목표 대비 정확히 0원 | `0원 달성` | D-055 |
| 목표 대비가 0원은 아니지만 0만원으로 반올림 | `-1만원 미만 미달` / `+1만원 미만 달성` | D-055 |
| 1억 이상 | `약 12,345만원` | D-055 |
| **금액**(`heldAssets`, `afterTaxGain` 등)이 정확히 0원 | **[X-3 추천안 A]** `0원` | 쟁점 |
| **금액**이 0원이 아니지만 0만원으로 반올림 | **[X-3 추천안 A]** `1만원 미만` | 쟁점 |
| **금액**이 음수(`afterTaxGain` 손실) | **[X-3 추천안 A]** `-약 N만원`, 0만원으로 반올림되면 `-1만원 미만` | 쟁점(기획 보완) |

**[합의] 만드는 곳: display 맵 빌더 하나 (제공자)**
- `calc.application.ResultDisplayBuilder` 하나를 결과 화면(#30), `/internal/calc`(#32), planContext가 같이 쓴다. 입력: `CalcInput` + `CalcResult` + **결과 접두어**(`""` / `"current."` / `"changed."`) + **조건 접두어**(`"conditions."` / `"conditions.current."` / `"conditions.changed."`). 왜: 같은 값을 세 곳에서 만들면 "화면 숫자 = AI 숫자 글자까지"(PR-04)를 코드로 보장할 수 없다. C2-6은 `conditions.<side>.*`, planContext는 `conditions.*`라 접두어를 둘로 나눠 받는다. 계약 키는 그대로다.
- 이 빌더는 #32에서 처음 만들고, 추가 키 4개도 이 빌더에 넣는다. 그래서 #30 결과 화면도 같은 키(`assumptions.sp500BaseDate` = 가정 보기 "데이터 기준월", D-038)를 받는다.
- `Formatter`(#28)는 형식만 맡는다. 추가 키 4개는 기존 두 형식(금액, 시점)만 써서 **Formatter 변경이 없다**. X-3·X-2 결과만 #28 수용 기준을 바꾼다(G-8 재배치).
- 반올림은 TBD-16을 따르고 `Formatter` 한 곳에서 한다. 문구 템플릿(`달성`, `미달`, `적금 a : ETF b`)은 문구표(CP-05, #18).

**[합의] 모델 규칙에 쓰이는 display 해석**
- **`<S>.goalReachMonth` 키가 없을 때**: 그 시나리오가 `isAchieved=false`일 때만 "기간 안에 도달하지 않아요"라고 말한다(소비자). `isAchieved=true`인데 키가 없으면 계약 위반이며 C1a-8 요구 키 검사에서 실패한다([기획 보완]: 달성이면 도달 달이 항상 있으므로 요구 키에 넣음).
- **`goalAmount` 키 이름 겹침**: `planContext.display.goalAmount`와 `/internal/calc` `display.goalAmount`는 이름이 같다. 목표 금액은 입력값이라 데이터 버전(R-4)과 무관하게 항상 같은 값이므로 허용한다. 그 밖의 키는 접두어로 갈린다(planContext는 접두어 없음, 도구 결과는 `current.`/`changed.`/`diff.`/`conditions.<side>.`). **비교·차이는 도구 결과의 접두어 키만 인용한다**(프롬프트 규칙 4).
- **display가 없는 값**(모델이 말하지 않음): `annualReturnPct`, `dataVersions`, `requiredMonthlySaving`, 초과 금액(`heldAssets − goalAmount`), 그리고 X-2에서 B를 고르면 세율.

## C1a-7. 넣지 않는 필드 (D-030) [합의, v1과 같음]

| 필드 | 이유 |
|---|---|
| `memberId`, `login_id`, 비밀번호 해시, JWT 등 | D-030. `memberId`는 `ChatRequest` 최상위에만 있고 프롬프트에 넣지 않는다(테스트로 고정) |
| `plan_version.id`, `plan.revision`, `plan.previous_version_id` | 설명에 쓰이지 않음 |
| `goalCustomName` | 자유 글이라 개인정보·프롬프트 주입 경로가 될 수 있다(R-2, 양쪽 찬성) |
| `goalType` | `CalcInput`에 없어 넣으려면 plan 조회·DTO가 늘고, 소비자 요구도 없다(R-2, 양쪽 찬성) |
| `existingMonthlyContribution` | FR-INP-08 Won't(D-045) |
| `scenarios[].monthlyPoints` | 토큰 낭비, 설명에 불필요 |
| 대화 기록, 다른 계산 기록 | `history`는 `ChatRequest`의 별도 필드 |

- Spring 쪽은 `PlanContextView`에 계정 필드가 아예 없어 타입으로 보장된다. 직렬화 결과에 `memberId` 키가 없는지 G-5에서 확인.

## C1a-8. ai-server 처리 [합의]

### 받기 (pydantic `PlanContext`)

- `PlanContext`와 하위 모델은 `ApiModel`을 상속하고 `extra`를 덮어쓰지 않는다(pydantic 기본 `ignore`). `ConditionChanges`처럼 `extra="forbid"`로 바꾸지 않는다. 시나리오 이름은 기존 `Scenario` enum 재사용.
- **필수/선택 목록**(소비자 제안 그대로):

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
- **display 필터**: `display`는 `dict[str, Any]`로 받고, **키가 허용 패턴에 맞고 값이 문자열인 항목만** 남긴다. 나머지는 조용히 버린다. 왜: v1의 "값이 문자열인 항목만"(필터)과 "문자열 맵이 아니면 422"(검증)가 충돌했다(소비자). 값 내용에 대한 필터는 두지 않는다(Spring이 만든 값, 과잉).
- 허용 패턴(ai-server 상수 하나, `re.fullmatch`):
  ```
  (goalAmount|calcStartMonth|targetMonth|(GOOD|AVG|BAD)\.(afterTaxAsset|principal|afterTaxGain|gapToGoal|goalReachMonth)|conditions\.(heldAssets|monthlySavingAmount|targetPeriodMonths|savingsRatioPct|savingsRateInputPct)|assumptions\.(savingsRateBaseMonth|sp500BaseDate|taxRatePct))
  ```
  `|taxRatePct`는 **[X-2] 추천안 A일 때만**. B면 뺀다. 테스트: `AVG.afterTaxAsset` 통과, `loginId`·`current.AVG.afterTaxAsset`(비교 키) 차단.

### 검사 (`ChatAgent.run()`의 기존 mode 분기에 추가)

| 순서 | 조건 | 결과 |
|---|---|---|
| 1 | 스키마 위반(필수 누락, 타입, enum) | FastAPI 기본 422 `{"detail": [...]}` |
| 2 | `mode=EXPLAIN`이고 `planContext`가 `null` | `AgentError("BAD_REQUEST")` → 400. 왜: 모델이 "없음"을 받고 설명을 지어내는 것을 막는다(소비자) |
| 3 | `mode=EXPLAIN`이고 `planContext.calcRunId != ChatRequest.calcRunId` | `AgentError("BAD_REQUEST")` → 400. 왜: 다른 계산을 설명하면 FR-AI-02 대조가 깨진다 |
| 4 | `mode=EXPLAIN`이고 `result.status=ALREADY_EXCEEDED` | **LLM을 부르지 않고** 문구표 `chat.alreadyExceeded` 문장으로 `EXPLANATION` 응답(`calcRunId` 그대로). F-3이 이 경우를 부를지는 X-4 |
| 5 | display 요구 키 누락(아래) | `AgentError("CONTEXT_DISPLAY_MISSING")` → 502 |
| 6 | 그 밖 | 모델 호출 |

- 400·422·502 모두 Spring은 `FAILED`로 기록한다(FR-AI-04, #41 기준과 같아 Spring 추가 분기 없음, 제공자 확인).
- **422 본문은 FastAPI 기본을 그대로 둔다**(G-6). 양쪽 모두 동작이 같다고 했고 소비자가 README 문장만 고치는 쪽을 권했다. README의 "실패는 `{"error": CODE}`"에 "요청 검증 실패(422)는 FastAPI 기본 본문" 예외를 적는다.
- **`planContext` 본문을 로그에 남기지 않는다.** 422 `detail`에 값이 에코될 수 있으므로 로그에는 `calcRunId`와 오류 코드만.
- `CONTEXT_DISPLAY_MISSING`은 도구 쪽 `CALC_DISPLAY_MISSING`과 쌍으로 상수화한다.

**display 요구 키**(필터를 거친 뒤 기준, 소비자 H-2 + [기획 보완] 1줄):

| `status` | 반드시 있어야 하는 키 |
|---|---|
| `CALCULATED` | `goalAmount`, `calcStartMonth`, `targetMonth`, `conditions.{heldAssets, monthlySavingAmount, targetPeriodMonths, savingsRatioPct, savingsRateInputPct}`, `result.scenarios`의 각 `<S>`에 대해 `<S>.{afterTaxAsset, principal, afterTaxGain, gapToGoal}`, 그리고 `isAchieved=true`인 `<S>`의 `<S>.goalReachMonth`([기획 보완]). X-2 A면 `assumptions.taxRatePct` |
| `ALREADY_EXCEEDED` | `goalAmount`, `conditions.heldAssets` |
| 선택(없어도 됨) | `isAchieved=false`인 `<S>.goalReachMonth`, `assumptions.savingsRateBaseMonth`, `assumptions.sp500BaseDate` |

왜 전체인가: `<S>.afterTaxAsset`만 보면 `gapToGoal`이 빠졌을 때 모델 앞에 `goalAmount`와 `afterTaxAsset`만 남아 뺄셈 유혹이 생긴다(소비자).

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

- 직렬화: 키는 camelCase(`by_alias=True`), `json.dumps(..., ensure_ascii=False)`(한국어 이스케이프 안 함).
- **테스트 기대값(A-5)은 `json.loads`한 dict 비교**로 한다. 키 순서·공백은 계약하지 않는다. 왜: 바이트 비교면 프롬프트 포맷만 바꿔도 깨진다(소비자).
- 계획이 없으면(`planContext: null`) `<plan_context>null</plan_context>`처럼 "없음"이 드러나게 넣는다.

### 프롬프트 규칙 (G-3)

1. 금액·기간·시점·비율은 `display` 값을 글자 그대로 인용한다.
2. 두 display 값을 빼거나 나눠 새 숫자를 만들지 않는다(초과 금액 포함).
3. `isAchieved=false`이고 `<S>.goalReachMonth` 키가 없으면 "기간 안에 도달하지 않아요"처럼 시점 없이 말한다.
4. 비교·차이는 `recalculate` 결과의 접두어 키(`current.`/`changed.`/`diff.`)만 인용하고 planContext의 `<S>.*`와 섞지 않는다(R-4 방어).
5. 반영하지 않은 항목·3구간 산정 방식은 `excludedNotes`·`scenarioMethodNote` 문장을 그대로 쓴다.
6. **[합의, H-6]** 구체적인 연 수익률은 말하지 않는다. "과거 데이터로 만든 구간이며 수익을 약속하지 않는다"고만 답한다. 몇 년치 데이터인지 같은, 주어지지 않은 정보는 모른다고 한다.
7. **[X-1 추천안 A]** "월 10만원 더"처럼 상대 표현으로 조건을 바꾸면 계산하지 않고 `CLARIFY`로 바꿀 값을 절대값으로 되묻는다(지금 값은 display로 인용 가능).
8. **[X-2]** 추천안 A면 "세율은 `assumptions.taxRatePct`만 인용". B면 "세율 숫자는 말하지 않고, 세금 질문은 `search_documents` 결과만 인용".
9. `status=ALREADY_EXCEEDED`이면 초과 사실과 "목표 금액은 입력 수정에서 바꿀 수 있어요"만 말하고 초과 금액은 말하지 않는다.

- 모델이 실제로 규칙을 지키는지는 FakeClaude로 검증되지 않는다. **소량 수동 평가 목록**(예: A-1에서 "목표까지 얼마나 모자라요?" → `-약 288만원 미달`을 인용하는지)을 G-4 완료 조건에 둔다(소비자).

## C1a-9. 키 표기 camelCase [합의, v1과 같음]

- `planContext` 안의 모든 JSON 키는 camelCase. `display` 키도 camelCase 경로를 점으로 이은 것.
- Spring: View DTO에 `@JsonProperty("isAchieved")`·`@JsonProperty("isDefaultSavingsRate")`. Spring Boot 4(Jackson 3)에서 record의 `boolean isAchieved` 접근자가 is-getter 규칙과 겹쳐 `achieved`로 나갈 수 있으므로 도메인 `ScenarioResult`/`Assumptions`를 직접 직렬화하지 않는다(제공자 보강). G-5가 고정한다.
- ai-server: `ApiModel`(`alias_generator=to_camel`, `serialize_by_alias=True`). `display`는 `dict`라 alias 영향 없음.
- 범위 밖: `ChatResponse.conditionChanges`의 snake_case 키는 #44(F-16).

## C1a-10. 누가 언제 만드는가 (Spring) [합의]

**만드는 곳: `calc` 모듈의 공개 API `PlanContextProvider`.** 이름을 v1 `PlanContextQuery`에서 바꾼다. 왜: QUESTION 경로가 `calc_run`을 INSERT할 수 있어 `Query`는 오해를 부른다(제공자, 소비자 이견 없음).

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

- 시그니처 세부는 제공자 재량(양보 가능 항목). 위 세 가지 책임과 인자는 계약이다.
- **의존 방향**: `plan {}` ← `calc {plan, refdata}` ← `chat {calc, rag}`. chat은 calc 루트만, calc는 plan 루트 공개 API만 부른다. 새 순환 없음(제공자 확인).
- **[합의] 소유권 확인은 2단계, JOIN 금지**: ① calc 리포지토리 `findByIdAndRunType(calcRunId, PLAN)` ② plan 공개 API `findVersion(memberId, run.planVersionId)` → 비면 empty. 왜: `calc_run`에는 `member_id`가 없고, calc가 plan 테이블을 JOIN하면 "다른 모듈의 엔티티·리포지토리를 쓰지 않는다"(`modulith.md`)를 어긴다. PK 조회 2번이라 성능 문제 없음. `persistence.md`의 "리포지토리 메서드는 memberId 조건"에 calc_run 예외를 한 줄 적는다(G-13).
- **[합의] plan 공개 API에 `findVersion(long memberId, long planVersionId)`를 더한다.** EXPLAIN은 현재 버전이 아닌 그 기록의 버전을 읽어야 한다. internal-calc C2-8의 현재 계획 조회와 같은 인터페이스에 둘지 따로 둘지는 plan Issue에서 정한다(G-12).
- **[합의] `findPlanRun`**: F-3은 요청 시점에 404 판단과 `chat_message.baseline_scenario`(NOT NULL) 저장이 필요한데, 재계산하는 `findForCalcRun`을 부르면 낭비다. `PlanRunRef.baselineScenario`는 조회 시점의 `plan.baseline_scenario`.
- **[합의] EXPLAIN의 `baselineScenario`는 인자로 받는다.** `calc_run`에 기준 시나리오가 저장되지 않으므로, F-3 이후 기준 시나리오가 바뀌어도 `ChatRequest.baselineScenario == planContext.result.baselineScenario`가 깨지지 않게 chat이 저장한 값을 넘긴다. QUESTION은 `plan.baseline_scenario`(현재).
- **F-3 404**(#12): "없는 기록"과 "남의 기록"을 같은 `404 NOT_FOUND`로 낸다(id 추측 방지). `findPlanRun`이 둘 다 empty이므로 전역 `@RestControllerAdvice`에서 일관되게 낸다.
- **언제**: chat의 `ChatAnswerRequested` 리스너가 ai-server `/chat`을 호출하기 직전에 만든다. 저장하지 않고 호출마다 만든다(ADR-002). planContext를 `chat_message`에 저장하는 변경은 하지 않는다.
- **[합의] 트랜잭션 순서**: `PlanContextProvider` 메서드는 자체 `@Transactional`. chat 리스너는 "planContext 만들기 → (트랜잭션 밖) ai-server HTTP 호출 → 결과 저장(짧은 트랜잭션)". 왜: 30초 호출 동안 DB 커넥션을 잡지 않는다(G-9).
- **[합의] 생성 실패**: `Optional.empty()`는 "계획 없음"(QUESTION → `planContext: null`) 또는 "기록 없음"(EXPLAIN, 정상 경로에서는 F-3에서 걸러짐). 엔진·기준 데이터 오류는 예외로 올라오고, **chat 리스너는 ai-server를 부르지 않고 메시지를 `FAILED`·`FAILURE`로 바꾼다**(FR-AI-04, #41).

| mode | `planContext`의 기준 | `ChatRequest.calcRunId` |
|---|---|---|
| `EXPLAIN` | 요청의 `calcRunId`. 그 기록의 `plan_version`과 데이터 버전으로 계산. 현재 계획이 그 뒤 바뀌었어도 그 기록 기준 | `planContext.calcRunId`와 같은 값 |
| `QUESTION` | 현재 계획 버전의 최신 PLAN 기록. **결과 화면 Q1(a)~(c)(`db/erd.md` §4 Q1) 서비스를 그대로 호출**해 얻는다(없거나 활성 버전과 다르면 계산·기록). planContext용으로 따로 구현하지 않는다 | `null`. **`planContext.calcRunId`는 있는 것이 정상** |

- QUESTION에서 `PlanChanged` 리스너와 동시에 PLAN 행이 2개 생길 수 있으나 `ix_calc_run_latest`가 최신 1행을 고르므로 무해하다(멱등 키 없음, C2-7과 같은 방침).
- **[합의, R-4] 데이터 버전**: planContext는 그 PLAN 기록의 버전, 같은 턴의 `/internal/calc` `current`는 활성 버전. QUESTION은 Q1-c 때문에 활성 버전으로 재기록되므로 같고, 차이는 오래된 EXPLAIN 기록에서만 생기며 해커톤 중 재적재가 없으면 생기지 않는다(D-045). #10은 다시 열지 않고 프롬프트 규칙 4로 막는다(양쪽 수용).

## C1a-11. 특수한 경우 [합의, F-3 호출 여부는 X-4]

| 경우 | `planContext` | ai-server |
|---|---|---|
| 저장된 계획이 없음 | `null` | QUESTION: 숫자 없이 답한다. 계산·설명 요청이면 문구표 `chat.noPlan`("먼저 목표와 조건을 입력해 계획을 만들어 주세요"). EXPLAIN: 400(C1a-8 검사 2) |
| ETF 0% | `scenarios`에 AVG 1개, `annualReturnPct`·`scenarioMethod`·`sp500BaseDate`·`dataVersions.sp500VersionId` = `null`, display에 `AVG.*`만 | 3구간을 말하지 않는다. `scenarioMethodNote` 없음. 부록 A-2 |
| 이미 목표 초과 | `scenarios: []`, display는 `goalAmount`, `calcStartMonth`, `targetMonth`, `conditions.*`, `assumptions.*` | EXPLAIN: LLM 없이 `chat.alreadyExceeded`(C1a-8 검사 4). QUESTION: 모델에 주되 초과 금액은 말하지 않는다(프롬프트 규칙 2·9). 부록 A-3 |
| 목표 기간 안에 도달 못 함 | `goalReachMonth: null`, display 키 없음 | `isAchieved=false`일 때만 "기간 안에 도달하지 않아요" |

- **[합의] 초과 계획에서도 `conditions.heldAssets` display를 남긴다.** 제공자는 "빼는 것도 빌더 한 줄, 소비자 판단"이라 했고, 소비자는 초과 상태의 요구 키에 `conditions.heldAssets`를 넣었다(사용자가 입력한 값이고 화면 조건 바에도 있다). 초과 금액 차단은 프롬프트 규칙 2·9가 맡는다.
- **[합의] 문구표 키 고정**(소비자 요청, #18이 이 이름을 쓴다):

| 키 | 쓰는 곳 | 문장(확정은 #18) |
|---|---|---|
| `chat.noPlan` | 계획 없음, `/internal/calc` `NO_PLAN`(C3-2)과 같은 문장 | "먼저 목표와 조건을 입력해 계획을 만들어 주세요" |
| `chat.alreadyExceeded` | 초과 EXPLAIN, `/internal/calc` `ALREADY_EXCEEDED`(C3-2)와 같은 문장 | 초과 사실 + "목표 금액은 입력 수정에서 바꿀 수 있어요" |
| `excluded.<CODE>` | `ExcludedItem` 5개. `excluded.EXCHANGE_RATE` = "환율 변동은 반영하지 않았어요"(D-027) | 나머지 4개는 #18 |
| `scenarioMethod.<CODE>` | `CAGR`, `ROLLING_DISTRIBUTION` | TBD-01 결과에 따름 |

  왜 C3-2와 같은 키인가: 같은 상황(계획 없음·초과)에 경로마다 다른 문장이 나오지 않게 한다.

## C1a-12. 크기·버전 [합의, v1과 같음]

- 크기: 시나리오 3개 기준 JSON 약 3KB, 모델 입력 약 1.5KB. 상한을 코드로 강제하지 않는다.
- **버전 필드(`contextVersion`)를 두지 않는다**(R-5 b, 양쪽 찬성). 한 repo·한 Compose 배포이고, 필드 추가는 "모르는 키 무시"로 안전하며, 모델이 쓰는 필드의 이름 변경은 필수 필드 누락 422와 양쪽 fixture 테스트(G-4·G-5)가 바로 잡는다.
- 필드를 더하는 변경: 이 문서 수정 → Spring이 보냄 → ai-server가 모델·패턴에 더할 때까지 모델에는 안 들어감(안전). 빼거나 뜻을 바꾸는 변경: 재협상.

## C1a-13. 예시 JSON과 fixture [합의]

- **fixture 위치: 공유 파일 `docs/api/examples/plan-context/*.json`**. backend 테스트와 ai-server 테스트가 같은 파일을 읽는다. #11 `paths`에 `docs/api/examples/**`를 더한다(G-1). 왜: 복사본 두 벌은 반드시 어긋난다(양쪽 같은 의견, #10과 같은 결론).
- 숫자는 형식 예시다(엔진 결과 아님). 서로 맞게 만들었다: `principal = heldAssets + monthlySavingAmount × targetPeriodMonths`, `afterTaxAsset = principal + afterTaxGain`, `gapToGoal = afterTaxAsset − goalAmount`, display는 만원 반올림(양쪽 검산 완료).
- **[합의] G-5(Spring)는 엔진을 돌리지 않는 단위 테스트**다: 부록 A의 raw 값으로 손으로 만든 `CalcInput`/`CalcResult`를 빌더에 넣은 결과가 fixture JSON과 같다. 왜: 엔진 값은 fixture와 다르다.
- **[합의] ai-server 테스트는 A-5와 dict 비교**(C1a-8).

| 파일 | 내용 | 부록 | 기대 |
|---|---|---|---|
| `plan-context-basic.json` | 기본, 3구간 모두 미달 | A-1 | — |
| `plan-context-etf0.json` | ETF 0% | A-2 | — |
| `plan-context-exceeded.json` | 이미 초과 | A-3 | — |
| `plan-context-achieved.json` | **새로**: 달성·미달 섞임, `goalReachMonth` 있음 | A-6 | `<S>.goalReachMonth` 키 패턴 통과 |
| `plan-context-zero-held.json` | **새로**: `heldAssets=0`, 1만원 미만 이득 | A-7 | **X-3 결정에 따라 display 두 값만 바뀜** |
| `plan-context-polluted.json` | **새로**: 규칙 밖 키 | A-8 | 모델 입력이 A-1 기준 A-5와 같음 |
| `plan-context-display-missing.json` | **새로**: `AVG.gapToGoal` 없음 | A-9 | `CONTEXT_DISPLAY_MISSING` 502 |
| `chat-request-explain.json` | EXPLAIN 전체 요청 | A-4 | — |
| `chat-request-question-no-plan.json` | QUESTION, 계획 없음 | A-4 | `<plan_context>null</plan_context>` |
| `chat-request-question-with-plan.json` | **새로**: QUESTION, 계획 있음 | A-4 변형 | `calcRunId: null`이 정상 |
| `chat-request-explain-mismatch.json` | **새로** | A-10 | 400 |
| `chat-request-explain-null.json` | **새로** | A-10 | 400 |
| `chat-request-explain-exceeded.json` | **새로** | A-10 | LLM 미호출, `chat.alreadyExceeded` |
| `model-input-basic.json` | A-1의 모델 입력 | A-5 | dict 비교 기대값 |

- ai-server의 `FakeCalc.recalculate` 반환 모양은 옛 모양(`goodCase.finalAmount`)이다. "planContext display + 도구 display가 같은 턴에 들어가는" 테스트를 하려면 internal-calc 부록 A-1 fixture로 바꿔야 한다(G-4 선행, #10 후속과 함께).

## C1a-14. moeun 현재 코드와 다른 곳 [합의]

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| D-1 | `ai-server/app/schemas.py` `ChatRequest.plan_context` | `dict[str, Any] \| None` | `PlanContext \| None`(C1a-8 필수/선택 목록) | G-2 |
| D-2 | `ai-server/app/llm/agent.py` `build_messages` | dict 통째로 `json.dumps`, 계획 없으면 `{}` | 모델 전달 필드만, display 필터, 문구 매핑, `null` 표시 | G-2 |
| D-3 | `ai-server/app/llm/prompts.py` | raw 숫자 인용 허용 문장 | 프롬프트 규칙 1~9 | G-3 |
| D-4 | `ai-server/README.md` | planContext 설명 없음, 실패는 `{"error": CODE}`만 | 필드 표·무시 규칙·fixture 링크, 422 예외 | G-1 |
| D-5 | `ai-server/tests/test_agent.py` | planContext 없는 요청만, `FakeCalc` 옛 모양 | C1a-13 fixture 테스트 | G-4 |
| D-6 | `backend/.../calc/` | `PlanContextProvider`·`PlanContextView`·`ConditionsView`·`CalcResultView`·`ScenarioResultView`·`ResultDisplayBuilder`·`Formatter` 없음 | `CalcResultView`·`ScenarioResultView`는 **calc 루트**, `ResultDisplayBuilder`는 **#30·#32·planContext 공유**, `findPlanRun` 경량 조회 | G-7, G-8a, G-10 |
| D-7 | `backend/.../plan/` | 공개 조회 API 없음 | 현재 계획 조회 + **버전 id로 조회(`findVersion`, 소유권 포함)** 2개 | G-12 |
| D-8 | `b-team-contracts.md` C-1a, Issue #11 본문 | `assumptions` 최상위, 부호 없는 `gapToGoal`, `calcRunId`·`heldAssets` 없음 | 이 문서 | G-16 |
| D-9 | `agent.py` `run()` EXPLAIN 검사 | `calc_run_id is None`만 | C1a-8 검사 2~4 추가 | G-2 |
| D-10 | `prompts.py` `SYSTEM_PROMPT` | 조건 7개 안내(`existing_monthly_contribution`, 목표 금액 포함) | 대화로 바꿀 수 있는 조건 4개(D-040) | G-3 |

## C1a-15. Issue #11 수용 기준 대응 [합의]

| # | 수용 기준 | 이 문서 |
|---|---|---|
| 1 | 예시에 `memberId`·계정 식별 정보가 없다(D-030) | C1a-7, 부록 A(planContext 안·모델 입력 모두 없음), G-5(직렬화 결과에 `memberId` 키 없음) |
| 2 | `AVG.afterTaxAsset` 등 display는 Spring 문자열, LLM이 반올림하지 않음 | C1a-4, C1a-6, C1a-8(raw 금액 미전달, 프롬프트 규칙 1·2) |
| 3 | 규칙 밖 필드는 ai-server가 무시 | C1a-8("무시" = 거절하지 않고 모델에도 넘기지 않음), A-8 |
| 4 | display가 C2-6 규칙을 따름 | C1a-6 |
| 5 | snake_case 키 없음 | C1a-9, 부록 A |

---

## 합의 목록

검토 두 건에서 양쪽 수용, 또는 한쪽 수정 제안에 다른 쪽 이견이 없어 반영한 것. **41건.**

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
| 9 | C1a-5 | `excludedItems`·`scenarioMethod`: Spring은 코드만, ai-server가 문구표 문장으로 바꿔 넘김, 모델은 그대로 인용(R-6) | 소비자 제안, 제공자 "소비자 판단" |
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
| 27 | C1a-10 | QUESTION은 결과 화면 Q1 서비스 재사용 | 제공자 |
| 28 | C1a-10 | 트랜잭션 순서(호출은 트랜잭션 밖) | 제공자 |
| 29 | C1a-10 | 생성 실패 → ai-server 미호출, `FAILED` | 제공자 |
| 30 | C1a-10 | EXPLAIN `calcRunId` 불일치·`planContext=null` → `BAD_REQUEST` | 기획 + 소비자 |
| 31 | C1a-10 | F-3 404는 없는 기록·남의 기록 구분 없음 | 제공자 |
| 32 | C1a-10 | QUESTION에서 `ChatRequest.calcRunId=null` + `planContext.calcRunId` 있음이 정상 | 소비자 |
| 33 | C1a-10 | 데이터 버전 차이 수용, #10 재오픈 없음(R-4) | 양쪽 |
| 34 | C1a-11 | 초과 계획에서도 `conditions.heldAssets` display 유지 | 소비자(제공자 위임) |
| 35 | C1a-11 | EXPLAIN + 초과 → ai-server가 LLM 없이 고정 문구(F-3 호출 여부와 무관한 방어) | 소비자 |
| 36 | C1a-11 | 문구표 키 `chat.noPlan`, `chat.alreadyExceeded`, `excluded.<CODE>`, `scenarioMethod.<CODE>` | 소비자 |
| 37 | C1a-12 | 버전 필드 없음(R-5 b) | 양쪽 |
| 38 | C1a-13 | fixture 위치 `docs/api/examples/plan-context/`, A-4 실제 JSON, 추가 fixture | 양쪽 |
| 39 | C1a-13 | G-5를 손으로 만든 입력의 단위 테스트로 | 제공자 |
| 40 | C1a-14 | D-6·D-7 보강, D-9·D-10 추가 | 양쪽 |
| 41 | G-8, H-6 | G-8 재배치(키는 빌더, 형식만 #28), 수익률 질문 프롬프트 규칙 + 수동 평가 목록 | 제공자, 소비자 |

## 쟁점 (사람이 정함)

> 넷 다 **#11 계약 문서 머지를 막지 않는다.** 본문에는 기획 추천안을 임시로 적었고, 결정이 다르면 표시된 줄만 바꾼다. 영향받는 것은 G-3(프롬프트), #28(형식), #12·프론트(F-3 호출)다.

### X-1. 상대 표현("월 10만원 더")을 어떻게 recalculate 인자로 만드는가 (H-1)

**문제**: 모델에는 `conditions.monthlySavingAmount: "약 30만원"`만 있다. "10만원 더 넣으면?"이면 모델이 `300000 + 100000`을 만들어야 하는데, 반올림된 문자열에서 출발하면 틀린 값이 된다(예: 보유 자산 345,000원 → `약 35만원`). 입력 값 산술이지만 "LLM이 직접 계산"(NFR-INT-01)에 해당한다.

| 안 | 내용 | 영향 |
|---|---|---|
| **A. 되묻기** | 프롬프트 규칙: 상대 표현은 계산하지 않고 `CLARIFY`로 절대값을 되묻는다("월 저축액을 얼마로 바꿔 볼까요? 지금은 약 30만원이에요") | Spring·#10 변경 없음. 프롬프트 1줄 + 테스트. 대화가 한 턴 늘어난다. D-033·FR-AI-06 "모호하면 되묻는다"와 같은 방향 |
| B. raw 4개 전달 | 대화로 바꿀 수 있는 조건 4개의 raw 값을 `<plan_context>`에 "recalculate 인자 전용, 인용 금지"로 넣고 덧셈은 모델이 한다 | Spring 변경 없음(`conditions`가 이미 와이어에 있음). 원칙 1(raw 미전달)의 예외가 생기고, 덧셈 실수를 막을 장치가 없다 |
| C. 증감 인자(기획 추가안) | 도구에 `monthlySavingAmountDelta` 같은 증감 키를 두고 Spring이 현재 값에 더한다 | 계산이 코드로 가서 원칙에 가장 맞지만 **확정된 #10 계약(C2-2 허용 키 4개)을 다시 연다.** 해커톤 뒤 후보 |

- 소비자: A 권장(B는 사람이 정할 것). "소비자 쪽에서 가장 큰 열린 구멍".
- 제공자: 의견 없음(A·B는 제공자 영향 없음, C면 #10 재협상).
- **기획 추천: A.** 왜: 바꾸는 것이 프롬프트 한 줄이고, 원칙 1·NFR-INT-01을 그대로 지키며, 확정 계약을 다시 열지 않는다. UX 비용은 한 번 더 묻는 것뿐이고 사용자가 지금 값을 display로 바로 본다.

### X-2. 세율을 모델이 말해도 되는가 (R-3, H-4)

**문제**: "세금 얼마 떼요?"는 첫 질문 후보다. display가 없으면 모델이 기억으로 15.4% 또는 22%(해외 주식 양도세)를 말할 수 있다. 반면 세율 형식은 CP-04·C2-6에 없다.

| 안 | 내용 | 영향 |
|---|---|---|
| **A. display 추가** | `assumptions.taxRatePct: "15.4%"` 키 1개를 빌더·허용 패턴·요구 키에 더한다. 모델은 이 값만 인용 | #28 수용 기준 1줄(새 형식 `N.N%`), 빌더 1줄, ai-server 패턴 1개. 빌더 공유라 결과 화면(#30)도 같은 키를 받는다(가정 보기에서 쓸지는 프론트 판단) |
| B. 숫자 금지 | display 없음. 프롬프트: "세율 숫자는 말하지 않고 세금 질문은 `search_documents` 결과만 인용" | Spring 변경 없음. RAG 자료의 세율이 엔진 세율과 다를 수 있다(그때 화면 숫자와 설명이 어긋날 위험) |

- 제공자: B(형식이 없고 #28 수용 기준이 는다). 단 "가정 보기가 세율을 보여야 하면 그때 빌더에 넣는다".
- 소비자: A(없으면 숫자 출처가 모델 기억이 된다). 안 넣으면 B의 프롬프트 규칙 필수.
- **기획 추천: A.** 왜: 비용이 형식 1개·키 1개로 작고, 엔진이 실제로 쓴 세율 하나만 말하게 되어 "숫자는 Spring만"(원칙 1)에 가장 맞다. 금리 형식(`연 N.NN%`)도 계약에서 더한 선례가 있다. 금융 표현이 바뀌는 것이라 finance-domain-reviewer 확인을 권한다.

### X-3. 일반 금액의 0원·1만원 미만·음수 표기 (R-7, H-3, D-055 확장 여부)

**문제**: D-055는 **차이와 목표 대비**의 경계만 정했다. 일반 금액은 `heldAssets=0`(DB 기본값 0, 데모에서 흔함)이면 `약 0만원`, 5,000원 미만 `afterTaxGain`도 `약 0만원`이 된다. 또 [기획 보완] BAD 시나리오 단기 계획에서는 `afterTaxGain`이 음수(손실)일 수 있는데 C2-6에 음수 금액 형식이 없다.

| 안 | 내용 | 영향 |
|---|---|---|
| **A. 경계 3줄 고정** | 정확히 0원 → `0원`, 0원이 아니지만 0만원으로 반올림 → `1만원 미만`, 음수 → `-약 N만원`(0만원이면 `-1만원 미만`) | #28 수용 기준 3줄. 빌더 공유라 `/internal/calc` C2-6에도 같은 규칙이 적용되므로 internal-calc 경계 표에 3줄 추가(후속 G-11, 동작은 Formatter 하나) |
| B. 0원만 | `0원`만 지금 고정, 나머지는 나중 | `약 0만원`(소액 이득), 음수 형식 미정이 남는다 |
| C. 그대로 | `약 0만원` 허용 | 형식 변경 없음. 데모에서 "보유 자산 약 0만원"이 보인다 |

- 제공자: `0원` 찬성 + `1만원 미만` 확장 제안(D-055와 같은 결). "Q-번호로 미뤄도 됨".
- 소비자: `0원` + `1만원 미만` 필수, `heldAssets=0` fixture 추가 요청.
- 음수 금액: 양쪽 다 언급하지 않음(기획이 발견).
- **기획 추천: A.** 왜: 양쪽이 0원·1만원 미만에 이미 같은 형식을 냈고 D-055 목표 대비 경계와 결이 같다. 다만 D-055의 범위를 일반 금액으로 넓히는 표시 정책이라 사람이 확인해야 한다. 부록 A-7 fixture의 display 두 값(`conditions.heldAssets`, `AVG.afterTaxGain`)이 이 결정에 따라 바뀐다.

### X-4. 이미 목표 초과 계획에도 결과 화면이 F-3(설명 요청)을 부르는가 (R-1)

**문제**: FR-RES-01은 "계산 대신 초과 안내"만 정했고 AI 설명을 부를지는 결정에 없다. 화면 정책이다.

| 안 | 내용 | 영향 |
|---|---|---|
| **A. 부르지 않음** | 결과 화면은 FR-RES-01 문구표 안내만 보이고 F-3을 부르지 않는다 | ai 호출 1회·PENDING 행 1개 감소. 대화창에 첫 설명 메시지가 없다 |
| B. 부름 | F-3을 부르고 ai-server가 LLM 없이 `chat.alreadyExceeded`로 즉시 답한다(C1a-8 검사 4) | 대화창에 안내가 한 번 더 뜬다(화면 안내와 같은 문장) |

- 제공자: A. 설명할 숫자가 없고 테스트가 하나 준다.
- 소비자: A. 호출하면 LLM이 초과 금액을 지어낼 위험만 는다(그래서 B여도 LLM은 부르지 않게 방어를 넣음).
- 양쪽이 같은 의견이지만 decisions.md에 없는 화면 정책이라 쟁점으로 남긴다. 계약은 어느 쪽이든 그대로다(초과 planContext는 QUESTION에서 필요).
- **기획 추천: A.** 왜: 같은 문장을 두 번 보여줄 이유가 없고 호출·기록·테스트가 줄어든다.

## 이 계약 때문에 생기는 후속 작업

> 합의 뒤 D-058에 따라 **기존 moeun Issue 본문(수용 기준·변경 범위·선행)에 반영**한다. Issue 번호를 모르는 것은 "확인 필요".

| # | 작업 | 팀 | Issue | 메모 |
|---|---|---|---|---|
| G-1 | 최종본을 `docs/api/plan-context.md`·`ai-server/README.md`로 옮김(422 예외 문장 포함, G-6 흡수). fixture 14개를 `docs/api/examples/plan-context/`에 둠 | 공통 | **#11** | #11 `paths`에 `docs/api/examples/**` 추가 |
| G-2 | `PlanContext` 모델(필수/선택), display 필터·패턴, `build_messages`(모델 전달 필드, `excludedNotes`·`scenarioMethodNote` 매핑, `null` 표시, `ensure_ascii=False`), `run()` 검사 2~5, 로그에 본문 안 남김 | B | 확인 필요(ai-server `/chat` 설명 Issue) | #21·#22·#23과 같은 파일. 문구 매핑은 [전환기] 상수 dict |
| G-3 | 프롬프트 규칙 1~9, D-040 조건 4개로 정정(D-10) | B | 확인 필요(프롬프트 Issue) | 규칙 7은 X-1, 8은 X-2 결정 뒤 확정 |
| G-4 | C1a-13 fixture 테스트(dict 비교, 오염·누락·불일치·null·초과 EXPLAIN), 수동 평가 목록 | B | G-2와 같은 Issue | 선행: `FakeCalc`를 internal-calc A-1 모양으로 교체 |
| G-5 | 손으로 만든 `CalcInput`/`CalcResult` → 빌더·직렬화 결과 = fixture JSON. `memberId` 키 없음, `isAchieved` 키 이름, 라벨-`isAchieved` 일치 | A | G-7과 같은 Issue | 엔진 미사용 단위 테스트 |
| G-6 | (G-1에 흡수) 422 본문은 FastAPI 기본 유지, README 문장만 정정 | B | #11 | 코드 변경 없음 |
| G-7 | `PlanContextProvider`(3메서드)·`PlanRunRef`·`PlanContextView`·`ConditionsView`, 소유권 2단계, QUESTION은 Q1 서비스 재사용, 메서드별 `@Transactional` | A | 확인 필요(A-0c 담당. 새 Issue 권장이나 D-058로 #32에 합칠지 판단) | 선행: #28·#30·#32·G-12 |
| G-8a | 추가 키 4개를 `ResultDisplayBuilder`에 | A | **#32** | 빌더를 공유형(결과·조건 접두어 인자)으로 만드는 것 포함 |
| G-8b | 금액 경계 형식(X-3), 세율 형식(X-2 A일 때) | A | **#28** | 결정 뒤 수용 기준 추가 |
| G-9 | chat 리스너: 호출 직전 `PlanContextProvider` 호출, `baselineScenario`는 `chat_message` 값 전달, 생성 실패면 ai-server 미호출 `FAILED`, 트랜잭션 밖 HTTP 호출. F-3은 `findPlanRun`으로 404·`baseline_scenario` 저장 | B(chat 담당 합의 필요) | 확인 필요(#41로 보임) + #12 | |
| G-10 | `CalcResultView`·`ScenarioResultView`를 calc 루트에 둠. #32 `paths`에 `calc/CalcResultView.java`, `calc/ScenarioResultView.java` 추가 | A | **#32** | 위치만, 동작 변화 없음 |
| G-11 | **internal-calc.md 문서 정정**(이 단계에서는 고치지 않음): C2-4 `calc.web.CalcResultView` → `calc.CalcResultView`(루트), C2-4 "`status` 항상 `CALCULATED`"·"`excludedItems` 미사용"이 `/internal/calc` 경로 한정임을 명시, 원칙 1·C3-1의 "calc.web + Formatter"에 `ResultDisplayBuilder` 반영, X-3 결정 시 C2-6 경계 표에 금액 경계 추가, C3-2 고정 문장에 문구표 키(`chat.noPlan`, `chat.alreadyExceeded`) 연결 | 기획 | 문서(+ #10 본문 정정) | 동작 변화 없음 |
| G-12 | plan 공개 API `findVersion(memberId, planVersionId)`(현재 계획 조회와 함께) | A | 확인 필요(plan 공개 API Issue, #32와 공유) | 인터페이스 이름은 이 Issue에서 |
| G-13 | `backend/.claude/rules/persistence.md`에 "calc_run은 회원 키가 없어 plan 공개 API로 소유권 확인" 예외 1줄 | A | G-7과 같은 Issue | |
| G-14 | 문구표 키 `chat.noPlan`, `chat.alreadyExceeded`, `excluded.<CODE>`(5개), `scenarioMethod.<CODE>`(2개, TBD-01 뒤 문장) | 공통 | **#18** | ai-server [전환기] 상수 dict를 여기로 옮김 |
| G-15 | F-3: 없는 기록·남의 기록 모두 404 `NOT_FOUND`, 초과 계획 F-3 호출 여부(X-4) | A·프론트 | **#12** (+ 결과 화면 프론트 Issue) | X-4 결정 뒤 |
| G-16 | `b-team-contracts.md` C-1a와 Issue #11 본문을 이 계약에 맞춤(`assumptions` 위치, `gapToGoal` 부호, `calcRunId`·`heldAssets`) | 기획 | 문서 + **#11** 본문 | D-058 |

---

## 부록 A. 예시 JSON (fixture용)

공통 계획(A-1): 목표 2,000만원, 보유 자산 500만원, 월 30만원, 36개월, 적금 금리 미입력(기본 3.12%), 비중 미입력(5:5), 시작월 2026-11. internal-calc 부록 A-1의 `current`와 같다.

### A-1. 기본 — ETF 포함, 3구간 모두 미달 (`plan-context-basic.json`, v1과 같음)

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

(`assumptions.taxRatePct` 줄은 **X-2 추천안 A일 때만** 있다. B면 이 줄을 지운다. A-2·A-3·A-6·A-7도 같다.)

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

### A-4. `ChatRequest` 전체 — EXPLAIN (`chat-request-explain.json`)

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

QUESTION, 계획 없음 (`chat-request-question-no-plan.json`):

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

QUESTION, 계획 있음 (`chat-request-question-with-plan.json`): **A-4 EXPLAIN 파일에서 최상위 네 값만 바꾼다** — `"messageId": 1031`, `"mode": "QUESTION"`, `"text": "세금은 얼마나 떼요?"`, `"calcRunId": null`. `planContext`(그 안의 `calcRunId: 540` 포함)는 그대로. **`ChatRequest.calcRunId=null`이고 `planContext.calcRunId=540`인 것이 정상**이며 400이 나지 않는다.

### A-5. 모델 입력 — A-1에 C1a-8 적용 (`model-input-basic.json`)

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
      "isDefaultSavingsRate": true,
      "scenarioMethodNote": "(문구표 scenarioMethod.ROLLING_DISTRIBUTION)",
      "excludedNotes": [
        "(문구표 excluded.ETF_TOTAL_EXPENSE)",
        "환율 변동은 반영하지 않았어요",
        "(문구표 excluded.ETF_DISTRIBUTION)",
        "(문구표 excluded.HELD_ASSET_RETURN)",
        "(문구표 excluded.SAVINGS_REDEPOSIT)"
      ]
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

- `(문구표 ...)` 자리는 #18(전환기에는 ai-server 상수)의 문장이 들어간다. **테스트는 이 자리를 하드코딩하지 않고** `[COPY[f"excluded.{c}"] for c in excludedItems]`처럼 같은 매핑에서 기대값을 만든다. `excluded.EXCHANGE_RATE`만 D-027 문장으로 고정이다.
- 없는 것: `calcRunId`, `conditions`(raw), `memberId`, `baselineScenario`(별도 태그), 원 단위 금액·수익률, 코드(`excludedItems`, `scenarioMethod`), `dataVersions`, raw `taxRatePct`.

### A-6. 달성·미달 섞임 (`plan-context-achieved.json`, 새로)

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

(검산: `19,400,000 = 5,000,000 + 400,000 × 36`. `isAchieved=true`인 GOOD·AVG는 `goalReachMonth` 키가 요구 키다.)

### A-7. 보유 자산 0원·1만원 미만 이득 (`plan-context-zero-held.json`, 새로, **X-3 의존**)

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

(`conditions.heldAssets: "0원"`, `AVG.afterTaxGain: "1만원 미만"` 두 값은 **X-3 추천안 A** 기준이다. B면 `"약 0만원"` 하나만 바뀌고, C면 둘 다 `"약 0만원"`.)

### A-8. 오염 입력 (`plan-context-polluted.json`, 새로)

A-1에 다음을 **더한** 것. 기대: 요청 성공, 모델 입력이 A-5와 dict로 같다.
- 최상위 `"loginId": "demo01"`, `result` 안 `"memberId": 7`
- `display`에 `"loginId": "demo01"`, `"current.AVG.afterTaxAsset": "약 1,712만원"`(비교 키), `"AVG.annualReturnPct": "연 9.8%"`(패턴 밖), `"BAD.goalReachMonth": 202911`(패턴 안이지만 값이 숫자 → 버림, `isAchieved=false`라 요구 키 아님)

### A-9. display 누락 (`plan-context-display-missing.json`, 새로)

A-1에서 `display`의 `"AVG.gapToGoal"` 한 줄만 지운 것. 기대: `AgentError("CONTEXT_DISPLAY_MISSING")` → 502, 모델 호출 없음.

### A-10. EXPLAIN 오류·초과 (새로)

| 파일 | A-4에서 바꾼 것 | 기대 |
|---|---|---|
| `chat-request-explain-mismatch.json` | 최상위 `"calcRunId": 999` | 400 `BAD_REQUEST`, 모델 호출 없음 |
| `chat-request-explain-null.json` | `"planContext": null` | 400 `BAD_REQUEST`, 모델 호출 없음 |
| `chat-request-explain-exceeded.json` | `"calcRunId": 542`, `planContext` = A-3 객체 | 200, 모델 호출 없음, `messageType=EXPLANATION`, 본문 = 문구표 `chat.alreadyExceeded`, `calcRunId` 542 |

---

## 부록 B. v1 → v2에서 바뀐 것

| 항목 | v1 | v2 | 출처 |
|---|---|---|---|
| C1a-2 | `result` 타입 `calc.web.CalcResultView` | `calc.CalcResultView`(루트), 필수/선택 열 추가, C2-4와 다른 두 점 명시 | 제공자, 소비자 |
| C1a-3 | 출처 `plan_version.*` | 출처 `CalcInput`, 와이어 유지·ai-server 선택 필드 | 제공자 |
| C1a-4 | `baselineScenario` = `plan.baseline_scenario` | EXPLAIN은 chat 저장값, 모델 입력에서 제외 | 제공자, 소비자 |
| C1a-5 | `excludedItems`·`scenarioMethod` 코드를 모델이 풀어 씀(R-6 기획 초안) | Spring은 코드만, ai-server가 문구표 문장(`excludedNotes`, `scenarioMethodNote`)으로 바꿔 넘김, 모델은 그대로 인용 | 소비자(제공자 이견 없음) |
| C1a-5·C1a-6 | 세율 display 없음 | X-2 쟁점, 추천안 A로 `assumptions.taxRatePct` 임시 표기 | 소비자 반대 |
| C1a-6 | 빌더 위치 미정, 금액 0원만 `0원` 제안 | `ResultDisplayBuilder` 공유, 금액 경계 3줄은 X-3, `goalReachMonth` 해석 좁힘, `goalAmount` 겹침 규칙 | 제공자, 소비자, 기획 보완(음수) |
| C1a-8 | 필수 목록 없음, 필터·422 충돌, 누락 검사 `afterTaxAsset`만, EXPLAIN 검사 1개 | 필수/선택 표, `dict[str, Any]` 필터, 요구 키 전체, 검사 순서 1~6, 로그 금지, dict 비교, 프롬프트 규칙 9개 | 소비자 |
| C1a-10 | `PlanContextQuery` 2메서드, 소유권 JOIN처럼 읽힘, 버전 조회 없음 | `PlanContextProvider` 3메서드(`findPlanRun` 추가, `baselineScenario` 인자), 소유권 2단계, `findVersion`, Q1 서비스 재사용, 트랜잭션 순서, 실패 → `FAILED`, 404 통일 | 제공자, 소비자 |
| C1a-11 | 초과 EXPLAIN 처리 미정, 문구표 키 미정 | EXPLAIN + 초과는 LLM 없이 고정 문구, `conditions.heldAssets` 유지, 문구표 키 4종 고정 | 소비자 |
| C1a-13 | fixture 3개 + 자리표시자 A-4, 위치 미정 | `docs/api/examples/plan-context/` 14개, A-4 실제 JSON, A-6~A-10 추가, G-5 단위 테스트화 | 양쪽 |
| C1a-14 | D-1~D-8 | D-6·D-7 보강, D-9·D-10 추가 | 양쪽 |
| 검토 요청 R-1~R-7 | 7개 질문 | R-2·R-4·R-5·R-6 합의, R-1 → X-4, R-3 → X-2, R-7 → X-3. H-1 → X-1 | 양쪽 |
| 후속 작업 | G-1~G-9 | G-6은 G-1에 흡수, G-8을 8a(#32)·8b(#28)로 나눔, G-10~G-16 추가 | 제공자, 소비자 |
