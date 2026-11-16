# `planContext` 계약 v1 (moeun #11, C-1a) — 기획 초안

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 1단계(기획 초안). **결정이 아니라 검토용 초안이다.**
> - 출발점: `docs/design/b-team-contracts.md` C-1a(63행), A-0c, §5 순서 3
> - 재사용: `docs/design/contracts/internal-calc.md`(최종본) 원칙 0-1·4·6·7, C2-4 직렬화 표, **C2-6 display 키·형식**, 결정 D-055(차이·경계 형식), D-056, D-057
> - 기준: `docs/srs.md`(CP-04, CP-05, FR-AI-01·02·06·07·09, FR-RES-01·03·06, NFR-INT-01·02·03), `docs/decisions.md`(D-013, D-027, D-030, D-038, D-041, D-045, D-051, D-052, D-055)
> - moeun 기준(origin/develop, 읽기만 함, 경로는 `moeun/` 기준): `ai-server/app/schemas.py`(`ChatRequest.plan_context`), `ai-server/app/llm/agent.py`(`build_messages`), `ai-server/app/llm/prompts.py`, `ai-server/app/main.py`, `ai-server/README.md`, `ai-server/tests/test_agent.py`, `backend/src/main/java/com/moeun/backend/calc/`(`CalcResult`, `ScenarioResult`, `Assumptions`, `AppliedDataVersions`, `CalcStatus`, `Scenario`, `ScenarioMethod`, `ExcludedItem`, `package-info.java`), `backend/.../chat/package-info.java`, `backend/.../plan/package-info.java`, `backend/CLAUDE.md`(모듈 표), `db/erd.md`(`chat_message`, `calc_run`, §4 Q1), `db/decision.md`(ADR-002), `db/moved-to-code.md`
>
> **표기**
> - **이미 있음**: moeun 코드·문서에 같은 내용이 있다. 경로를 적었다.
> - **새로 필요**: moeun에 아직 없다. 구현해야 한다.
> - **[기획 제안]**: 결정(D-번호)·확정 계약에 없는 내용을 기획이 초안으로 채운 것. 검토에서 쟁점이 될 수 있다.
> - **[코드 차이]**: moeun 현재 코드와 이 계약이 다른 곳.
> - 항목 ID(C1a-x)로 검토 의견을 주고받는다. 검토 요청 질문은 맨 아래 "검토 요청"(R-x).

## 0. 이 계약의 원칙

`internal-calc.md` §0의 원칙을 **그대로** 따른다. 이 계약에서 특히 중요한 것만 다시 적는다.

1. **숫자는 Spring만 만든다. 모델이 말하는 금액·기간·시점·비율은 `display` 문자열을 그대로 인용한 것뿐이다**(internal-calc 원칙 1, NFR-INT-01, FR-AI-02). `planContext`에서는 한 걸음 더 나가 **raw 금액을 모델에 넘기지 않는다**(C1a-8). 왜: 모델 입력에 원 단위 숫자가 없으면 반올림·뺄셈을 할 재료 자체가 없다.
2. **JSON 키는 camelCase**, 금액은 원(KRW) 정수, 기간은 개월 정수, 퍼센트는 숫자(`3.12` = 3.12%)(internal-calc 원칙 4).
3. **null은 키를 빼지 않는다**(internal-calc 원칙 6). 단 `display`는 예외로, 값이 없으면 키를 만들지 않는다(C2-6과 같음).
4. **받는 쪽은 모르는 키를 무시한다**(internal-calc 원칙 7). 이 계약에서 "무시"는 "오류로 처리하지 않고, 모델에도 넘기지 않는다"는 뜻이다(C1a-8).
5. **계정 식별 정보는 넣지 않는다**(D-030). LLM에는 계산 결과와 조건만 들어간다.
6. **새 라이브러리 없음.** Spring은 Jackson 기본, ai-server는 기존 pydantic(`ApiModel`).

---

## C1a-1. 목적·범위

| 항목 | 값 |
|---|---|
| 무엇 | Spring → ai-server `POST /chat` 요청의 `planContext` 필드(`ChatRequest.plan_context`) |
| 뜻 | **한 계산 기록(`calc_run(PLAN)`)의 조건·결과·표시 문자열·가정**. 모델이 "지금 계획"을 설명하거나 질문에 답할 때 인용하는 유일한 숫자 출처 |
| 쓰는 곳 | `mode=EXPLAIN`(결과 설명, FR-AI-01·02), `mode=QUESTION`(질문 답변, FR-AI-06·09) 둘 다 |
| 쓰지 않는 곳 | 대화 재계산의 비교(현재 vs 바꾼 조건)는 `/internal/calc` 응답(C2-3~C2-6)이 맡는다. `planContext`는 비교·차이를 담지 않는다 |
| 담당 | 만드는 쪽 Spring `calc` 모듈(A팀, C1a-10). 쓰는 쪽 ai-server(B팀). 계약은 A·B 공동 |

- 근거: `ai-server/app/schemas.py` `ChatRequest.plan_context`(주석 "현재 조건과 계산 결과 요약(Spring이 만든 값 그대로)"), `agent.py` `build_messages`(`<plan_context>` 태그로 모델에 넣음), `prompts.py`(`EXPLAIN_INSTRUCTION`), b-team-contracts C-1a.
- 이미 있음: 필드 이름과 위치(`ChatRequest.plan_context: dict[str, Any] | None`). 새로 필요: 필드 목록·형식(이 문서), Spring 빌더, ai-server 타입 모델.

## C1a-2. 최상위 구조

```json
{
  "calcRunId": 540,
  "conditions": { "...": "C1a-3" },
  "result": { "...": "C1a-4 (= /internal/calc의 current와 같은 모양)" },
  "display": { "...": "C1a-6" }
}
```

| 필드 | 타입 | 항상 있음 | 뜻 |
|---|---|---|---|
| `calcRunId` | integer | 예 | 이 컨텍스트를 계산한 `calc_run(run_type=PLAN)`의 id. 숫자 대조(PR-04)와 로그용 |
| `conditions` | object | 예 | 계산에 실제로 쓴 조건(C1a-3) |
| `result` | object | 예 | 계산 결과(C1a-4). 가정(`assumptions`)은 이 안에 있다(C1a-5) |
| `display` | object(문자열 맵) | 예 | Spring이 만든 표시 문자열(C1a-6) |

- `planContext` 자체가 없을 수 있다: 저장된 계획이 없으면 `"planContext": null`(C1a-11).
- [기획 제안] **`result`는 `/internal/calc`의 `current`와 같은 DTO(`calc.web.CalcResultView`)를 그대로 쓴다.** 왜: Spring은 DTO를 하나만 만들면 되고(`monthlyPoints` 제외·`isAchieved` 키 이름 처리가 이미 C2-4에 정해져 있음), ai-server도 같은 pydantic 모델로 두 곳을 읽는다. b-team-contracts C-1a 초안은 `assumptions`를 최상위에 따로 두었는데, 이 이유로 `result.assumptions`로 옮겼다(R-5).
- `calcRunId`를 넣는 이유: `EXPLAIN`에서는 `ChatRequest.calcRunId`와 같아야 하고(C1a-10), `QUESTION`에서는 어떤 기록을 기준으로 답했는지 로그로 남길 방법이 이것뿐이다(`ChatRequest.calcRunId`는 `QUESTION`에서 `null`).

## C1a-3. `conditions`

계산에 **실제로 쓴 값**(기본금리·기본 비중이 채워진 뒤, `ConditionResolver` 결과). 6개 키가 항상 모두 있다.

| 키 | JSON 타입 | 단위 | 출처 | display 키 |
|---|---|---|---|---|
| `goalAmount` | integer | KRW | `plan_version.goal_amount` | `goalAmount` |
| `heldAssets` | integer | KRW | `plan_version.held_assets` | `conditions.heldAssets` |
| `monthlySavingAmount` | integer | KRW | `plan_version.monthly_saving_amount` | `conditions.monthlySavingAmount` |
| `targetPeriodMonths` | integer | MONTH | `plan_version.target_period_months` | `conditions.targetPeriodMonths` |
| `savingsRatioPct` | integer | PCT(적금 비중, 나머지 ETF) | 해석된 비중(= `Assumptions.savingsRatioPct`) | `conditions.savingsRatioPct` |
| `savingsRateInputPct` | number | PCT(연, 세전) | 실제로 쓴 금리(= `Assumptions.savingsRatePct`) | `conditions.savingsRateInputPct` |

- 뒤 4개는 `/internal/calc` `conditions.current`와 **키·뜻이 같다**(C2-3). 앞 2개(`goalAmount`, `heldAssets`)만 더했다. 왜: 대화로 못 바꾸는 조건이지만 결과 설명("보유 자산 약 500만원에 매달 약 30만원을 더하면")에 필요하다.
- `goalAmount`는 `result.goalAmount`와 항상 같다. 이 표에 둔 이유는 "조건"을 한곳에서 읽게 하려는 것뿐이다. display 키는 C2-6과 같은 최상위 `goalAmount` 하나다.
- 해커톤에서는 `monthlySavingAmount`·`targetPeriodMonths`가 항상 있다(D-045). 범위 밖 분기(월 저축액 모름, 기한 없음)를 되살리면 `null`이 될 수 있으며 그때 이 표를 다시 연다.
- 기본금리를 썼는지는 `result.assumptions.isDefaultSavingsRate`로 안다.
- 넣지 않는 조건: C1a-7.

## C1a-4. `result` (시나리오 GOOD·AVG·BAD)

`CalcResult`를 JSON으로 바꾼 것. **`internal-calc.md` C2-4의 모양·직렬화 표를 그대로 쓴다.** 다른 점만 적는다.

| 필드 | 이 계약에서의 규칙 |
|---|---|
| `status` | `CALCULATED` 또는 `ALREADY_EXCEEDED`. `/internal/calc`와 달리 **`ALREADY_EXCEEDED`도 올 수 있다**(이미 초과인 계획을 대화창에서 질문할 수 있으므로). 그때 `scenarios`는 `[]`(C1a-11) |
| `goalAmount`, `calcStartMonth`, `targetMonth` | C2-4와 같다(`"YYYY-MM"`) |
| `baselineScenario` | `plan.baseline_scenario`. `ChatRequest.baselineScenario`와 같은 값(C1a-10) |
| `scenarios[]` | **항상 GOOD·AVG·BAD 순서**. ETF 포함이면 3개, ETF 0%(`savingsRatioPct=100`)면 **AVG 1개**, `ALREADY_EXCEEDED`면 0개. 각 원소는 `scenario`, `annualReturnPct`, `afterTaxAsset`, `principal`, `afterTaxGain`, `gapToGoal`, `isAchieved`, `goalReachMonth`. `monthlyPoints` **키 자체가 없다**(C1a-7) |
| `requiredMonthlySaving` | 해커톤에서 항상 `null`(D-045). ai-server는 쓰지 않는다 |
| `assumptions` | C1a-5 |
| `dataVersions` | 보낸다(DTO 재사용). ai-server는 **모델에 넘기지 않는다**(C1a-8) |

- 시나리오 이름은 `GOOD`·`AVG`·`BAD`만 쓴다(`calc.Scenario`, `ai-server` `Scenario`, `schema.sql` CHECK와 같음). 화면·모델 문장에서 "좋았던 때·평균·나빴던 때"로 바꾸는 것은 문구(CP-05)의 일이다.
- `gapToGoal = afterTaxAsset − goalAmount`, `afterTaxGain = afterTaxAsset − principal`, 0원은 달성(CP-01). 모두 Spring이 계산한 값이다.
- 달성/미달 판단은 raw `isAchieved`로 한다. 표시 라벨도 같은 판정을 따른다(C2-6, TBD-16은 #9·#28에서).

## C1a-5. `assumptions` (`result.assumptions`)

`calc.Assumptions` 그대로. 가정 보기(FR-RES-06)와 같은 원천이다.

| 필드 | 타입 | 모델에 넘김 | display 키 | 비고 |
|---|---|---|---|---|
| `savingsRatePct` | number | 아니오 | (`conditions.savingsRateInputPct`로 말함) | `conditions.savingsRateInputPct`와 같은 값 |
| `isDefaultSavingsRate` | boolean | 예 | — | "은행연합회 평균금리를 썼어요" 같은 문장의 판단용 |
| `savingsRateBaseMonth` | `"YYYY-MM"` \| null | 아니오 | `assumptions.savingsRateBaseMonth` | 기본금리 기준월. null이면 display 키 없음 |
| `savingsRatioPct` | integer | 아니오 | (`conditions.savingsRatioPct`로 말함) | |
| `taxRatePct` | number | 아니오 | **없음**(R-3) | 모델은 세율 숫자를 말하지 않고 "세금을 뺀 금액"이라고만 말한다 |
| `scenarioMethod` | `CAGR` \| `ROLLING_DISTRIBUTION` \| null | 예 | — | 3구간을 어떻게 만들었는지 설명용(TBD-01 미결). null = ETF 0% |
| `sp500BaseDate` | `"YYYY-MM-DD"` \| null | 아니오 | `assumptions.sp500BaseDate` | 데이터 기준월(D-038 표시). null = ETF 0% |
| `excludedItems` | string[] (`ExcludedItem` 이름) | 예 | — | 반영하지 않은 항목 코드. 문장은 모델이 쉬운 말로 하되 숫자는 없다(R-6) |

- [기획 제안] 세율(`taxRatePct`)은 display를 두지 않는다. 왜: CP-04·C2-6에 세율 형식이 없어 새 형식을 만들어야 하고, 설명에는 "세금을 뺀 금액"이면 충분하다. 필요하면 R-3으로 정한다.

## C1a-6. `display` 키·형식 — **C2-6 재사용**

`internal-calc.md` **C2-6의 키 규칙·형식·경계 규칙(D-055)을 그대로 쓴다.** `planContext`에는 비교가 없으므로 C2-6 키에서 **`<side>.` 접두어(`current.`/`changed.`)를 뺀다.** 그 밖에 C2-6에 이미 있는 형식만 쓰는 키 4개를 더한다(표의 "추가").

평평한 문자열 맵(키는 점으로 경로 표시). 응답에 **실제로 있는 시나리오만** 키를 만든다(ETF 0%면 `AVG`만, `ALREADY_EXCEEDED`면 시나리오 키 없음).

| 키 | 형식 | C2-6 대응 |
|---|---|---|
| `goalAmount` | `약 N만원` | `goalAmount` 그대로 |
| `calcStartMonth` | `YYYY년 M월` | **추가**(형식은 C2-6 `targetMonth`와 같음) |
| `targetMonth` | `YYYY년 M월` | `<side>.targetMonth` |
| `<S>.afterTaxAsset`, `<S>.principal`, `<S>.afterTaxGain` | `약 N만원` | `<side>.<S>.*` |
| `<S>.gapToGoal` | **[D-055]** `부호 + 약 N만원 + 달성/미달` (`-약 288만원 미달`, `+약 501만원 달성`) | `<side>.<S>.gapToGoal` |
| `<S>.goalReachMonth` | `YYYY년 M월`. 값이 `null`이면 **키를 만들지 않는다** | `<side>.<S>.goalReachMonth` |
| `conditions.heldAssets` | `약 N만원` | **추가**(금액 형식) |
| `conditions.monthlySavingAmount` | `약 N만원` | `conditions.<side>.monthlySavingAmount` |
| `conditions.targetPeriodMonths` | `n년 n개월` | `conditions.<side>.targetPeriodMonths` |
| `conditions.savingsRatioPct` | `적금 a : ETF b` | `conditions.<side>.savingsRatioPct` |
| `conditions.savingsRateInputPct` | `연 N.NN%`(소수 둘째 자리, 끝의 0 유지) | `conditions.<side>.savingsRateInputPct` |
| `assumptions.savingsRateBaseMonth` | `YYYY년 M월`. null이면 키 없음 | **추가**(시점 형식) |
| `assumptions.sp500BaseDate` | `YYYY년 M월`(일은 버림). null이면 키 없음 | **추가**(시점 형식. "데이터 기준월", D-038·FR-RES-06) |

`<S>` = `GOOD` \| `AVG` \| `BAD`. 예: `AVG.afterTaxAsset` → `"약 1,712만원"`.

경계 형식(D-055, C2-6과 같음):

| 경우 | 형식 |
|---|---|
| 목표 대비 정확히 0원 | `0원 달성`(CP-01) |
| 목표 대비가 0원이 아니지만 `약 N만원`으로 0만원이 되는 값 | `-1만원 미만 미달` / `+1만원 미만 달성` |
| 1억 이상 | 단위를 바꾸지 않고 `약 12,345만원` |
| 금액이 정확히 0원(`afterTaxGain` 등) | [기획 제안] `0원`. C2-6에 없는 경우라 #28에서 함께 고정(R-7) |

- 반올림은 TBD-16(천 단위)을 따르고 `Formatter` 한 곳에서 한다. **결과 화면(#49)과 같은 `Formatter`·같은 키 규칙**을 쓰므로 화면 숫자와 AI가 말한 숫자가 글자까지 같다(PR-04 숫자 대조).
- 문구 템플릿(`달성`, `미달`, `적금 a : ETF b`)은 문구표 `copy/copy.ko.yml`(CP-05, #18)에서 읽는다.
- **display가 없는 값**(모델이 말하지 않음): `annualReturnPct`(수익 약속처럼 들릴 위험, C2-6과 같음), `dataVersions`, `requiredMonthlySaving`, `taxRatePct`(R-3), 초과 금액(`heldAssets − goalAmount`, C1a-11).
- **키 이름공간이 비교와 겹치지 않는다**: `planContext.display`는 접두어 없음(`AVG.afterTaxAsset`), `/internal/calc` `display`는 `current.`/`changed.`/`diff.` 접두어가 있다. 한 대화 턴에 둘이 함께 모델에 들어가도 어느 값인지 섞이지 않는다. **비교·차이를 말할 때는 도구 결과의 display만 인용한다**(프롬프트 규칙, C1a-8).

## C1a-7. 넣지 않는 필드 (D-030)

| 필드 | 이유 |
|---|---|
| `memberId`, `member.login_id`, 비밀번호 해시, JWT 등 계정 식별 정보 | D-030. `memberId`는 `ChatRequest` 최상위에만 있고(이미 있음) **프롬프트에 넣지 않는다**(지금 `build_messages`도 넣지 않음. 테스트로 고정, G-4) |
| `plan_version.id`, `plan.revision`, `plan.previous_version_id` | 설명에 쓰이지 않음. 적용·되돌리기 판단은 F-4·A-1의 몫 |
| `goalCustomName`(직접 입력한 목표명) | 사용자가 자유롭게 쓴 글이라 개인정보가 들어갈 수 있다. FR-INP-02는 Should. [기획 제안] 넣지 않음(R-2) |
| `goalType`(목표 종류 코드) | [기획 제안] v1에서는 넣지 않음. 넣으면 설명이 자연스러워지지만 D-030 "조건"의 범위인지 확인 필요(R-2) |
| `existingMonthlyContribution` | FR-INP-08 Won't(D-045) |
| `scenarios[].monthlyPoints` | 토큰 낭비, 설명에 불필요(b-team C-1a). 키 자체를 빼는 방식은 C2-4(`CalcResultView`)와 같다 |
| 대화 기록, 다른 계산 기록 | `history`는 `ChatRequest`의 별도 필드. `planContext`는 계산 1건만 담는다 |

## C1a-8. 규칙 밖 필드 처리와 모델에 넣는 필드 (ai-server)

**ai-server는 이 계약에 없는 필드를 무시한다.** "무시"의 뜻:
1. **오류로 처리하지 않는다**(요청을 거절하지 않음).
2. **모델에 넘기지 않는다.** ai-server는 `planContext`를 타입 있는 pydantic 모델 `PlanContext`(`ApiModel`, `extra="ignore"`)로 읽고, 아래 표에서 "모델에 넘김 = 예"인 필드만 `<plan_context>`에 직렬화한다. 왜: 지금처럼 받은 dict를 통째로 `json.dumps`하면 Spring이 실수로 넣은 필드(예: 계정 정보)가 그대로 LLM에 간다(D-030).

| 위치 | 모델에 넘김 |
|---|---|
| `calcRunId` | 아니오(검사·로그용) |
| `conditions.*` (raw 숫자) | **아니오**. 조건은 `display`의 `conditions.*`·`goalAmount`로 말한다 |
| `result.status`, `result.baselineScenario` | 예(판단용) |
| `result.scenarios[].scenario`, `result.scenarios[].isAchieved` | 예(판단용) |
| `result.scenarios[]`의 그 밖(`afterTaxAsset`, `principal`, `afterTaxGain`, `gapToGoal`, `annualReturnPct`, `goalReachMonth`) | **아니오**. 금액·시점은 `display`로만 |
| `result.goalAmount`, `calcStartMonth`, `targetMonth`, `requiredMonthlySaving`, `dataVersions` | 아니오 |
| `result.assumptions.isDefaultSavingsRate`, `scenarioMethod`, `excludedItems` | 예 |
| `result.assumptions`의 그 밖 | 아니오(숫자·시점은 `display`로) |
| `display` | 예. **단 C1a-6 표의 키 패턴에 맞고 값이 문자열인 항목만**. 패턴 밖 키는 버린다 |

- `display` 키 허용 패턴(ai-server 상수 하나, [기획 제안]):
  `^(goalAmount|calcStartMonth|targetMonth|(GOOD|AVG|BAD)\.(afterTaxAsset|principal|afterTaxGain|gapToGoal|goalReachMonth)|conditions\.(heldAssets|monthlySavingAmount|targetPeriodMonths|savingsRatioPct|savingsRateInputPct)|assumptions\.(savingsRateBaseMonth|sp500BaseDate))$`
- 모델 입력 예시(ai-server가 `<plan_context>`에 넣는 것)는 부록 A-5.
- 모델에 넣을 때도 키는 camelCase로 직렬화한다(`by_alias=True`, `ApiModel` 기본값). 왜: 프롬프트 규칙이 `AVG.afterTaxAsset` 같은 키 이름을 가리킨다.
- **이 계약이 정한 필드가 빠졌거나 타입이 틀리면**(예: `display`가 문자열 맵이 아님, `result.scenarios`가 배열이 아님) `ChatRequest` 검증 실패다. FastAPI 기본 422 → Spring은 4xx를 모두 `FAILED`(FR-AI-04)로 기록한다. [코드 차이] 이때 본문은 README가 말하는 `{"error": CODE}`가 아니라 FastAPI 기본 `{"detail": [...]}`이다(G-6).
- **display 누락 방어**: `status=CALCULATED`인데 `display`가 비었거나, `result.scenarios`에 있는 시나리오의 `<S>.afterTaxAsset` 키가 하나라도 없으면 `AgentError("CONTEXT_DISPLAY_MISSING")`로 실패(→ 502 → Spring `FAILED`). 왜: display 없이 금액을 말하면 NFR-INT-01을 어긴다(C2-6 전환기 규칙과 같은 판단). Spring 빌더 Issue는 #28(Formatter)에 의존하므로 정상 동작에서는 생기지 않는다.
- 프롬프트 규칙(G-3에서 반영): (1) 금액·기간·시점·비율은 `display` 값을 글자 그대로 인용한다. (2) 두 display 값을 빼거나 나눠 새 숫자를 만들지 않는다. (3) display 키가 없으면 숫자 없이 말한다(예: `<S>.goalReachMonth`가 없으면 "기간 안에 도달하지 않아요"). (4) 비교·차이는 `recalculate` 결과의 display만 인용한다.

## C1a-9. 키 표기 camelCase

- `planContext` 안의 **모든 JSON 키는 camelCase**다. snake_case 키는 없다. `display`의 키도 camelCase 경로를 점으로 이은 것이다(`conditions.monthlySavingAmount`).
- enum 값(`CALCULATED`, `AVG`, `ROLLING_DISTRIBUTION`, `EXCHANGE_RATE`)은 키가 아니라 값이며 Java enum 이름 그대로다(C2-4).
- Spring: Jackson 기본(record 컴포넌트 이름 = camelCase). `boolean isAchieved`·`isDefaultSavingsRate`는 DTO에 `@JsonProperty`로 키 이름을 고정한다(C2-4와 같음). [코드 차이] `calc.ScenarioResult`/`Assumptions`를 DTO 없이 그대로 직렬화하면 Jackson 설정에 따라 `achieved`처럼 바뀔 수 있으므로 반드시 `CalcResultView`를 거친다.
- ai-server: `ApiModel`(`alias_generator=to_camel`, `serialize_by_alias=True`)로 받으면 파이썬 이름은 snake_case, JSON은 camelCase(이미 있음).
- 범위 밖이지만 함께 적어 둠: `ChatResponse.conditionChanges`의 **키**는 지금 snake_case다(`ConditionChanges.changed()`, `chat_message.condition_changes`). `planContext`와 관계없고 #44(F-16)에서 다룬다.

## C1a-10. 누가 언제 만드는가 (Spring, A-0c 모듈 경계)

**만드는 곳: `calc` 모듈의 공개 API.** [기획 제안]

```java
// calc 루트 패키지(공개 API)
public interface PlanContextQuery {
    /** QUESTION용: 회원의 현재 계획(plan.current_version_id)의 최신 PLAN 계산 기록으로 만든다. 계획이 없으면 empty. */
    Optional<PlanContextView> findForCurrentPlan(long memberId);
    /** EXPLAIN용: 지정한 PLAN 계산 기록으로 만든다. 그 회원의 PLAN 기록이 아니면 empty. */
    Optional<PlanContextView> findForCalcRun(long memberId, long calcRunId);
}
```

- **왜 calc인가**: (1) `chat` 모듈은 `calc`, `rag`에만 의존할 수 있다(`chat/package-info.java` `allowedDependencies = {"calc", "rag"}`). `chat`이 `plan`을 직접 읽을 수 없다. (2) 표시 문자열은 calc 모듈의 `Formatter`에서만 만든다(internal-calc 원칙 1, C3-1). (3) calc → plan 의존은 이미 허용되어 있다(`calc/package-info.java`). 그래서 b-team-contracts A-0c("plan, PLAN calc_run 조회")를 **chat이 calc 하나만 부르는 형태**로 정리한다.
- `PlanContextView`는 calc 루트의 공개 record(`calcRunId`, `conditions`, `result: CalcResultView`, `display: Map<String,String>`). `chat`은 이것을 `ChatRequest.planContext`에 넣어 직렬화만 한다. 숫자·문자열을 가공하지 않는다.
- 내부 순서(calc 안): `plan.CurrentPlanQuery`(C2-8에서 새로 필요한 plan 공개 API)로 계획 버전 읽기 → `ConditionResolver` → `calc_run`의 버전으로 `CalcEngine` 다시 계산(ADR-002 결과 미저장) → `CalcResultView` → `Formatter`로 `display`.
- **언제**: `chat`의 `ChatAnswerRequested` 리스너가 ai-server `/chat`을 **호출하기 직전**에 만든다(질문 저장 시점이 아님). 저장하지 않고 호출마다 새로 만든다(ADR-002).
- **어느 계산 기록인가**:

| mode | `planContext`의 기준 | `ChatRequest.calcRunId` |
|---|---|---|
| `EXPLAIN` | 요청의 `calcRunId`(F-3, 그 회원의 PLAN 기록). 그 기록의 `plan_version`과 데이터 버전으로 계산. **현재 계획이 그 뒤 바뀌었어도 그 기록 기준** | `planContext.calcRunId`와 **같은 값** |
| `QUESTION` | 현재 계획 버전의 **최신 PLAN 기록**(`ix_calc_run_latest`). 기록이 아직 없으면(적용 직후 `PlanChanged` 처리 전) 결과 화면과 같은 규칙(`db/erd.md` §4 Q1-c)으로 계산하고 PLAN 1행을 기록한 뒤 그 id를 쓴다 | `null`(지금 그대로) |

- 소유권: `findForCalcRun`은 `calc_run → plan_version.member_id = memberId`를 확인한다(`persistence.md`). `memberId`는 F-1·F-3에서 JWT subject로 얻은 값이다(D-052). 사용자 토큰은 ai-server로 가지 않는다(D-030).
- `ChatRequest.baselineScenario` = `planContext.result.baselineScenario`. Spring이 같은 값을 넣는다.
- ai-server 검사([기획 제안], 1줄): `mode=EXPLAIN`이고 `planContext.calcRunId != ChatRequest.calcRunId`이면 `AgentError("BAD_REQUEST")`(기존 코드, 400). 왜: 다른 계산을 설명하면 FR-AI-02 대조가 깨진다.
- 데이터 버전: `planContext`는 **그 PLAN 기록의 버전**, 같은 턴의 `/internal/calc` `current`는 **활성 버전**(C2-7, D-045)으로 계산한다. 해커톤 중 기준 데이터를 다시 적재하지 않으면 둘은 같다. 달라질 수 있어 C1a-8 프롬프트 규칙 (4)를 둔다(R-4).

## C1a-11. 특수한 경우

| 경우 | `planContext` | ai-server |
|---|---|---|
| 저장된 계획이 없음(FR-PLAN-06 직후 대화, NFR-USA-01) | `null` | 숫자 없이 답한다. 계산·설명 요청이면 "먼저 목표와 조건을 입력해 계획을 만들어 주세요"(C3-2 `NO_PLAN`과 같은 문구표 키). `EXPLAIN`은 F-3이 PLAN 기록을 요구하므로 이 경우가 없다 |
| ETF 0%(`savingsRatioPct=100`) | `scenarios`에 AVG 1개, `annualReturnPct`·`scenarioMethod`·`sp500BaseDate`·`dataVersions.sp500VersionId` = `null`, display에 `AVG.*`만, `assumptions.sp500BaseDate` 키 없음 | 3구간을 말하지 않는다. 예시 부록 A-2 |
| 이미 목표 초과(`status=ALREADY_EXCEEDED`, FR-RES-01) | `scenarios: []`, display는 `goalAmount`, `calcStartMonth`, `targetMonth`, `conditions.*`, `assumptions.*`만 | 계산 없이 초과 사실과 "목표 금액은 입력 수정에서 바꿀 수 있어요"(C3-2 `ALREADY_EXCEEDED` 문구표 키). **초과 금액(보유 − 목표)은 말하지 않는다**(display에 없음). 예시 부록 A-3. EXPLAIN을 부르는지는 R-1 |
| 목표 기간 안에 도달 못 함 | `goalReachMonth: null`, display 키 없음 | "기간 안에 도달하지 않아요"처럼 시점 없이 |

## C1a-12. 크기·버전

- **크기**: 시나리오 3개 기준 JSON 약 3KB, 모델에 넘기는 부분(부록 A-5)은 약 1.5KB(대략 1,000 토큰 이하). 상한을 코드로 강제하지 않는다. 시계열(`monthlyPoints`)을 빼서 계획 기간과 무관하게 크기가 거의 일정하다.
- **버전**: [기획 제안] `planContext` 안에 버전 필드(`contextVersion` 등)를 **두지 않는다.** 왜: 한 repo(moeun)·한 Docker Compose로 함께 배포하고, 필드 추가는 "모르는 키 무시"(원칙 4)로 깨지지 않으며, 깨지는 변경은 양쪽 fixture 테스트(G-5)가 잡는다. 계약 문서 버전은 `docs/api/plan-context.md` 머리에 적는다(R-5).
- 필드를 **더하는** 변경: 이 문서 수정 → Spring이 보내기 시작 → ai-server가 `PlanContext` 모델·display 패턴에 더할 때까지 모델에는 안 들어감(안전).
- 필드를 **빼거나 뜻을 바꾸는** 변경: 계약 재협상(`/negotiate-contract`).

## C1a-13. 예시 JSON

- 부록 A-1~A-3: Spring이 보내는 `planContext`(wire). **ai-server 테스트 fixture로 그대로 쓴다**(줄임표 없음).
- 부록 A-4: `planContext`를 담은 `ChatRequest` 전체(EXPLAIN).
- 부록 A-5: ai-server가 모델에 넣는 `<plan_context>` 내용(C1a-8 적용 결과). 테스트의 기대값.
- 숫자는 형식 예시다(엔진 결과 아님). 단 서로 맞게 만들었다: `principal = heldAssets + monthlySavingAmount × targetPeriodMonths`, `afterTaxAsset = principal + afterTaxGain`, `gapToGoal = afterTaxAsset − goalAmount`. A-1은 internal-calc 부록 A-1의 `current`와 **같은 숫자**다(같은 계획, 같은 버전).
- fixture 위치: #11 `paths`는 `docs/api/plan-context.md`와 `ai-server/README.md`뿐이다. fixture 파일을 따로 두려면 G-1 참고.

## C1a-14. moeun 현재 코드와 다른 곳 [코드 차이]

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| D-1 | `ai-server/app/schemas.py` `ChatRequest.plan_context` | `dict[str, Any] \| None`(아무 키나 통과) | `PlanContext \| None`(`ApiModel`, `extra="ignore"`, C1a-8 표의 필드만 선언) | G-2 |
| D-2 | `ai-server/app/llm/agent.py` `build_messages` | `json.dumps(req.plan_context or {})`로 통째로 모델에 넣음, 계획 없으면 `{}` | `PlanContext`의 모델 전달 필드만 직렬화, display 패턴 필터, 계획 없으면 "계획 없음"을 알 수 있게(`null`) | G-2 |
| D-3 | `ai-server/app/llm/prompts.py` `SYSTEM_PROMPT` "`<plan_context>`에 있는 값이나 recalculate 도구가 돌려준 값만 그대로 인용" | raw 숫자 인용을 허용하는 문장 | "display 문자열만 그대로 인용, 빼기·나누기 금지, 키가 없으면 숫자 없이, 비교는 도구 display만"(C1a-8) | G-3 |
| D-4 | `ai-server/README.md` "Spring과의 계약" | `planContext` 설명 없음, 실패는 `{"error": CODE}`라고만 적힘 | `planContext` 필드 표·무시 규칙·예시 링크, 422 본문 예외(C1a-8) | #11 자신 |
| D-5 | `ai-server/tests/test_agent.py` | `planContext` 없는 요청만 테스트. `FakeCalc`가 옛 응답 모양(`goodCase.finalAmount`) | 부록 A fixture로 (1) 모델 입력에 `memberId`·raw 금액·패턴 밖 display 키가 없음 (2) EXPLAIN `calcRunId` 불일치 → 400 (3) display 누락 → `CONTEXT_DISPLAY_MISSING` | G-4 |
| D-6 | `backend/.../calc/` | `PlanContextQuery`, `PlanContextView`, `CalcResultView`, `Formatter` 없음 | C1a-10 | G-7 |
| D-7 | `backend/.../plan/` | 공개 조회 API(`CurrentPlanQuery`) 없음(`allowedDependencies = {}`, 루트에 조회 서비스 없음) | calc가 현재 계획 버전을 읽는 공개 API 필요(internal-calc C2-8과 같은 것) | #32와 공유 |
| D-8 | b-team-contracts C-1a 초안 | `assumptions` 최상위, `AVG.gapToGoal: "약 130만원 미달"`(부호 없음), `calcRunId`·`heldAssets` 없음, `excludedItems` 2개 | `result.assumptions`(R-5), D-055 부호 + 라벨, `calcRunId`·`conditions.heldAssets` 추가, `ExcludedItem` 선언 순서 5개 | 문서만 |

## C1a-15. Issue #11 수용 기준 대응

| # | 수용 기준 | 이 문서 |
|---|---|---|
| 1 | 예시에 `memberId`·계정 식별 정보가 없다(D-030) | C1a-7, 부록 A-1~A-3(`planContext` 안에 없음), A-5(모델 입력에도 없음) |
| 2 | 세후 예상 자산 display 키 `AVG.afterTaxAsset`(시나리오 GOOD·AVG·BAD), Spring이 만든 문자열, LLM이 반올림하지 않음 | C1a-4, C1a-6, C1a-8 프롬프트 규칙 (1)(2), 원칙 1(raw 금액을 모델에 넘기지 않음) |
| 3 | 규칙 밖 필드는 ai-server가 무시 | C1a-8("무시" = 거절하지 않고 모델에도 넘기지 않음), display 키 패턴 |
| 4 | display가 C2-6 규칙을 그대로 따름(금액·시점·기간·금리·비중·목표 대비·goalReachMonth null이면 키 없음) | C1a-6(C2-6 키에서 `<side>.`만 뺌, 추가 키 4개도 C2-6의 기존 형식만 씀) |
| 5 | (예외) snake_case 키가 없고 모두 camelCase | C1a-9, 부록 A 전체 |

---

## 검토 요청

에이전트가 정하지 않은 것. 제공자(A팀)·소비자(B팀) 검토에서 의견을 받고, 결정이 필요하면 Q-번호로 올린다.

| ID | 질문 | 기획 초안(임시) | 왜 묻는가 |
|---|---|---|---|
| R-1 | **이미 목표 초과(`ALREADY_EXCEEDED`) 계획에도 결과 화면이 F-3(설명 요청)을 부르는가?** | 계약은 두 경우 모두 형식을 정해 둠(C1a-11). 부를지는 F-3/#12에서 정함 | FR-RES-01은 "계산 대신 안내"만 정했고 AI 설명 여부는 결정에 없다. 부른다면 모델은 초과 금액 없이 안내해야 한다 |
| R-2 | **목표 종류(`goalType` 코드)와 직접 입력 목표명(`goalCustomName`)을 모델에 넘기는가?** | 둘 다 넣지 않음(C1a-7) | 목표 종류는 설명을 자연스럽게 하지만 D-030 "조건"에 드는지 결정에 없다. 직접 입력 목표명은 자유 글이라 개인정보가 섞일 수 있다(FR-INP-02는 Should) |
| R-3 | **세율(`taxRatePct`)을 모델이 말해도 되는가?** 된다면 표시 형식은? | display 없음, 모델은 "세금을 뺀 금액"이라고만 말함(C1a-5) | CP-04·C2-6에 세율 형식이 없다. 넣으려면 `Formatter`에 형식 하나(`15.4%`)가 늘고 #28 수용 기준이 바뀐다 |
| R-4 | **같은 대화 턴에서 `planContext`(PLAN 기록의 데이터 버전)와 `/internal/calc` `current`(활성 버전)가 다를 수 있는 것을 받아들이는가?** | 받아들이고 프롬프트 규칙 (4)로 막음(C1a-10). #10 계약은 다시 열지 않음 | 해커톤 중 기준 데이터를 다시 적재하면 "지금 계획" 숫자가 설명과 비교 카드에서 다르게 보일 수 있다. D-038(저장 버전 고정)은 범위 밖(D-045) |
| R-5 | **구조 두 가지: (a) `assumptions`를 `result` 안에 둠(`CalcResultView` 재사용), (b) 버전 필드를 두지 않음.** 괜찮은가? | (a)·(b) 모두 C1a-2·C1a-12대로 | Issue #11 본문과 b-team C-1a 초안은 `assumptions`를 조건·결과·display와 나란한 최상위로 적었다. 재사용 이득이 있어 바꿨지만 원래 표현과 다르다 |
| R-6 | **반영하지 않은 항목(`excludedItems`)을 모델이 말할 때 문구표 문장을 그대로 쓰는가, 모델이 쉬운 말로 바꾸는가?** | 코드만 넘기고 모델이 쉬운 말로(숫자 없음) | CP-05는 "모든 고정 문구를 문구표 하나로, 프론트와 AI 서버가 함께 읽음"이다. D-027 문구("환율 변동은 반영하지 않았어요")를 AI 문장에서도 글자 그대로 써야 한다면 Spring이 display처럼 문구 문자열을 보내거나 ai-server가 `copy.ko.yml`을 읽어야 한다(위치는 #18) |
| R-7 | **금액이 정확히 0원일 때(예: ETF 0%·금리 0%의 `afterTaxGain`) 표시는?** | `0원` | D-055는 차이·목표 대비의 0원만 정했다. 금액 0원은 C2-6에도 없다. `약 0만원`이 나오지 않게 #28에서 함께 고정해야 한다 |

## 이 계약 때문에 생기는 후속 작업 (초안)

> 합의 뒤 D-058에 따라 **기존 moeun Issue 본문에 반영**한다. Issue 번호를 모르는 것은 "확인 필요"로 적었다.

| # | 작업 | 팀 | Issue | 메모 |
|---|---|---|---|---|
| G-1 | 최종본을 `docs/api/plan-context.md`·`ai-server/README.md`로 옮김. fixture(부록 A) 위치 정하기 | 공통 | **#11** 자신 | #10(F-13)과 같은 문제: 공유 fixture 파일을 두려면 #11 `paths`에 `docs/api/examples/**` 추가, 아니면 ai-server·backend 테스트가 각각 복사하고 "계약 변경 시 두 복사본 동시 수정"을 README에 적음 |
| G-2 | `PlanContext` pydantic 모델(`extra="ignore"`, 모델 전달 필드만 선언), display 키 패턴 필터, `build_messages` 수정, EXPLAIN `calcRunId` 검사, display 누락 → `CONTEXT_DISPLAY_MISSING` | B | 확인 필요(ai-server `/chat` 설명 Issue) | `schemas.py`·`agent.py`를 고치므로 #21·#22·#23과 같은 파일. 순서 처리 |
| G-3 | 프롬프트 숫자 규칙 4개(C1a-8) | B | 확인 필요(프롬프트 Issue) | `prompts.py`. G-2와 같은 Issue로 합쳐도 됨 |
| G-4 | 부록 A fixture 테스트: 모델 입력에 `memberId`·raw 금액·패턴 밖 키 없음, camelCase 유지, 불일치 400, 누락 실패 | B | G-2와 같은 Issue | `ai-server/tests/` |
| G-5 | Spring `PlanContextView` 직렬화가 부록 A-1~A-3과 같은지 테스트(REST Docs 아님, 단위 테스트) | A | G-7과 같은 Issue | 양쪽 fixture가 계약 변경을 잡는 장치(C1a-12) |
| G-6 | ai-server 요청 검증 실패(422) 본문을 `{"error": "BAD_REQUEST"}`로 맞출지 | B | 확인 필요 | 선택. Spring은 4xx를 모두 FAILED로 처리하므로 동작은 같다. README 문장만 맞춰도 됨 |
| G-7 | calc `PlanContextQuery`·`PlanContextView`, QUESTION의 "최신 PLAN 기록 없으면 계산·기록", EXPLAIN 소유권 검사 | A | 확인 필요(A-0c 담당 Issue) | **#28(Formatter)에 의존**, `CalcResultView`는 #32와 공유, `plan.CurrentPlanQuery`도 #32와 공유 |
| G-8 | `Formatter`에 추가 키 4개(`calcStartMonth`, `conditions.heldAssets`, `assumptions.savingsRateBaseMonth`, `assumptions.sp500BaseDate`) 반영 — 새 형식은 없음. R-7(0원) 결과 | A | **#28** | 형식은 기존 것만 쓰므로 수용 기준 1줄 |
| G-9 | chat 모듈: `ChatAnswerRequested` 리스너가 호출 직전에 `PlanContextQuery`를 불러 `planContext`·`baselineScenario`를 채움, 계획 없으면 `null` | B(chat 모듈 담당 합의 필요, b-team §5 순서 6) | 확인 필요(chat 모듈 Issue, #41로 보임) | |

---

## 부록 A. 예시 JSON (fixture용, 줄임표 없음)

공통 계획(A-1): 목표 2,000만원, 보유 자산 500만원, 월 30만원, 36개월, 적금 금리 미입력(기본 3.12%), 비중 미입력(5:5), 시작월 2026-11. internal-calc 부록 A-1의 `current`와 같다.

### A-1. 기본 — ETF 포함, 3구간 모두 미달

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
    "assumptions.sp500BaseDate": "2026년 10월"
  }
}
```

(`goalReachMonth`가 모두 `null`이라 `<S>.goalReachMonth` 키는 없다.)

### A-2. ETF 0% — AVG 1개, 기간 안에 도달 못 함

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
    "assumptions.savingsRateBaseMonth": "2026년 10월"
  }
}
```

(`sp500BaseDate`가 `null`이라 `assumptions.sp500BaseDate` 키가 없다. `excludedItems`는 엔진이 정한 목록을 그대로 둔다.)

### A-3. 이미 목표 초과 — `ALREADY_EXCEEDED`

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
    "assumptions.sp500BaseDate": "2026년 10월"
  }
}
```

(`ALREADY_EXCEEDED`에서 엔진이 `assumptions`·`dataVersions`를 어떻게 채우는지는 #27(엔진) 구현을 따른다. `CalcResult`가 둘 다 non-null을 요구하므로 키는 항상 있다.)

### A-4. `ChatRequest` 전체 — EXPLAIN (Spring → ai-server `POST /chat`)

```json
{
  "memberId": 7,
  "messageId": 1029,
  "mode": "EXPLAIN",
  "text": null,
  "baselineScenario": "AVG",
  "calcRunId": 540,
  "planContext": "<부록 A-1의 객체를 그대로 넣는다>",
  "history": []
}
```

- 실제 fixture에서는 `"planContext"` 값 자리에 A-1 객체를 그대로 넣는다(문자열이 아님). 여기서는 중복을 피하려고 표시만 했다.
- `memberId`는 `ChatRequest` 최상위에만 있고 `planContext` 안과 모델 입력(A-5)에는 없다(D-030).
- `calcRunId`(540) = `planContext.calcRunId`(540)(C1a-10).

QUESTION, 계획 없음:

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

### A-5. 모델 입력 — ai-server가 `<plan_context>`에 넣는 내용 (A-1에 C1a-8 적용)

```json
{
  "result": {
    "status": "CALCULATED",
    "baselineScenario": "AVG",
    "scenarios": [
      { "scenario": "GOOD", "isAchieved": false },
      { "scenario": "AVG", "isAchieved": false },
      { "scenario": "BAD", "isAchieved": false }
    ],
    "assumptions": {
      "isDefaultSavingsRate": true,
      "scenarioMethod": "ROLLING_DISTRIBUTION",
      "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
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
    "assumptions.sp500BaseDate": "2026년 10월"
  }
}
```

- 없는 것: `calcRunId`, `conditions`(raw), `memberId`, 원 단위 금액·수익률, `dataVersions`, `taxRatePct`. 테스트는 "A-1에 `\"loginId\": \"demo01\"` 같은 규칙 밖 키와 `\"display\": {\"loginId\": \"demo01\"}`를 더해도 A-5가 그대로"를 확인한다(G-4).
- 계획이 없으면(`planContext: null`) `<plan_context>null</plan_context>`처럼 "없음"이 드러나게 넣는다(지금은 `{}`, D-2).
