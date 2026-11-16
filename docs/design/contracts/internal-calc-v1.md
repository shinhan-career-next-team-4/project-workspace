# `/internal/calc` 계약 v1 (moeun #10, C-2·C-3) — 기획 초안

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 1단계(기획 초안). **결정이 아니라 검토용 초안이다.**
> - 출발점: `docs/design/b-team-contracts.md` C-2·C-3, `docs/design/alignment.md` 2-3·2-7
> - 기준: `docs/srs.md`(CP-02, CP-04, CP-05, CP-07, FR-AI-02·06·07·09, NFR-INT-01·03), `docs/decisions.md`(D-013, D-030, D-033, D-040, D-041, D-045, D-046)
> - moeun 기준(develop, 읽기만 함, 경로는 `moeun/` 기준): `backend/src/main/java/com/moeun/backend/calc/`(`CalcResult`, `ScenarioResult`, `CalcInput`, `Assumptions`, `AppliedDataVersions`, `CalcStatus`, `Scenario`, `ScenarioMethod`, `ExcludedItem`, `MonthlyPoint`, `package-info.java`), `backend/src/main/resources/db/schema.sql`, `backend/.claude/rules/persistence.md`, `db/moved-to-code.md`, `ai-server/README.md` "Spring과의 계약", `ai-server/app/schemas.py`, `ai-server/app/tools/calc.py`, `ai-server/app/llm/agent.py`
>
> **표기**
> - **이미 있음**: moeun 코드·문서에 같은 내용이 있다. 경로를 적었다.
> - **새로 필요**: moeun에 아직 없다. 구현해야 한다.
> - **[기획 제안]**: 결정(D-번호)에 없는 내용을 기획이 초안으로 채운 것. 검토에서 쟁점이 될 수 있다.
> - 항목 ID(C2-x, C3-x)로 검토 의견을 주고받는다.

## 0. 이 계약의 원칙 (전 항목 공통)

1. **숫자는 Spring만 만든다.** ai-server가 말하는 금액·기간·차이는 모두 이 응답에 이미 있는 값이다. 차이(`diff`)와 표시 문자열(`display`)도 Spring이 만든다. 왜: LLM이 빼기·반올림만 해도 계산이 되어 NFR-INT-01·FR-AI-02를 어기고, 숫자 대조(PR-04)가 어려워진다.
2. **범위 검증은 Spring 한 곳**(D-033). ai-server는 타입 검사만 하고, 범위 오류는 이 계약의 오류 본문을 인용해 되묻는다.
3. **기준은 항상 현재 계획, 변경은 누적하지 않는다**(D-041). Spring은 요청 한 건만 보고 계산하며 대화 상태를 들고 있지 않다.
4. **JSON은 camelCase**, 금액은 원(KRW) 정수, 기간은 개월 정수, 퍼센트는 숫자(`3.12` = 3.12%). 왜: `ApiModel`(`ai-server/app/schemas.py`)과 Jackson 기본값을 그대로 쓴다.
5. **새 라이브러리 없음.** 오류는 Spring 내장 `ProblemDetail`, 직렬화는 Jackson 기본, ai-server는 기존 `httpx`·pydantic.

---

## C2. `POST /internal/calc` (ai-server → Spring)

### C2-1. 경로·헤더·호출 주체 — 이미 있음 (보완 1건 새로 필요)

| 항목 | 값 |
|---|---|
| 메서드·경로 | `POST /internal/calc` |
| 호출자 | ai-server만 (도구 `recalculate` → `CalcClient.recalculate`) |
| 인증 | 헤더 `X-Internal-Api-Key: <공유 비밀>`. 사용자 JWT 없음 |
| 요청 Content-Type | `application/json` |
| 성공 응답 | `200 OK`, `application/json` |
| 오류 응답 | C3-1 형식, `application/problem+json` |
| 담당 | Spring `calc` 모듈(A팀). 계약은 A·B 공동 |

- 브라우저에 노출하지 않는다. 프론트는 이 경로를 부르지 않는다.
- 요청 본문의 `memberId`를 믿는 유일한 경로다(`backend/.claude/rules/persistence.md` "ai-server 전용 `/internal/*`은 예외").
- 근거: NFR-INT-03, D-030(사용자 토큰을 ai-server에 넘기지 않음), `ai-server/README.md` "Spring과의 계약" 표, `ai-server/app/tools/calc.py`, `backend/.../calc/package-info.java`("ai-server용 POST /internal/calc도 여기 있다"), `backend/CLAUDE.md` 모듈 표.
- 이미 있음: 경로, 헤더 이름, 호출 코드(`CalcClient`). 새로 필요: Spring 컨트롤러와 내부 키 검사(현재 `calc` 패키지에 컨트롤러 없음), 키 불일치 시 C3 형식 `401`.

### C2-2. 요청 — 형식 이미 있음, 허용 키 축소 새로 필요

```json
{
  "memberId": 7,
  "baselineScenario": "AVG",
  "conditionChanges": { "monthlySavingAmount": 500000 }
}
```

| 필드 | 타입 | 필수 | 뜻 |
|---|---|---|---|
| `memberId` | integer | 예 | 계산할 회원. 그 회원의 **현재 계획**이 기준(C2-8) |
| `baselineScenario` | `"GOOD" \| "AVG" \| "BAD"` | 예 | 달성/미달 판정에 쓸 기준 시나리오. `current`·`changed` **양쪽에 같은 값**을 쓴다 |
| `conditionChanges` | object | 예 | 바꿀 조건만 담는다. 키가 없으면 "바꾸지 않음". 최소 1개 |

`conditionChanges` 허용 키 (D-040, CP-07 — **4개뿐**):

| 키 | 타입 | 단위 | 대응 컬럼(`plan_version`) |
|---|---|---|---|
| `monthlySavingAmount` | integer | KRW | `monthly_saving_amount` |
| `savingsRatioPct` | integer | PCT (적금 비중, 나머지 ETF) | `savings_ratio_pct` |
| `savingsRateInputPct` | number | PCT (연, 세전) | `savings_rate_input_pct` |
| `targetPeriodMonths` | integer | MONTH | `target_period_months` |

- 그 밖의 키(`goalAmount`, `heldAssets`, `existingMonthlyContribution`, 오타 키 포함)는 **요청 전체를 거절**한다: `422 FIELD_NOT_CHANGEABLE`(C3-2). 허용 키와 섞여 와도 일부만 계산하지 않는다. 왜: 일부만 계산하면 사용자가 말한 것과 다른 비교가 뜬다.
- 값이 `null`인 키는 "보내지 않음"과 같이 본다. 왜: 지금 `CalcClient`가 `exclude_none=True`로 보내므로 `null`이 오지 않지만, 와도 안전하게.
- `conditionChanges`가 비었거나 모든 값이 `null`이면 `422 VALIDATION_FAILED`, `errors[0] = {field: "conditionChanges", reason: "REQUIRED"}`. [기획 제안] 왜: ai-server가 이미 막지만(`agent.py` `_recalculate`) 서버도 같은 규칙을 가져야 D-033(검증은 Spring 한 곳)이 성립.
- 시작월(`calcStartMonth`)은 요청에 없다. 항상 현재 계획의 값(C2-8, D-013).
- `baselineScenario`: [기획 제안] Spring은 요청 값을 그대로 쓴다. 이 값은 Spring이 `/chat` 요청에 넣어 준 값(`ChatRequest.baselineScenario`)이 돌아온 것이다. 왜: 해커톤에서는 `plan.baseline_scenario`가 항상 AVG(FR-RES-09 Should, alignment 2-6)라 어긋날 일이 없고, 엔드포인트가 `plan`을 한 번 더 해석하지 않아도 된다. (검토자 질문 2)
- 근거: D-040, CP-07, D-041, D-013, `ai-server/app/tools/calc.py`(요청 본문 3필드), `ai-server/app/schemas.py` `ConditionChanges`(현재 7필드), `alignment.md` 2-3·M-2.
- 이미 있음: 3필드 구조와 camelCase 키(`CalcClient`가 `by_alias=True`로 보냄). 새로 필요: 허용 키 4개 제한 — ai-server 도구 스키마·`ConditionChanges`와 Spring `rules.yml › change-paths.CHAT.fields`(alignment M-2, 별도 Issue).

### C2-3. 응답 최상위 — 새로 필요 (`calcRunId`만 이미 있음)

```json
{
  "calcRunId": 552,
  "basePlanVersionId": 41,
  "baselineScenario": "AVG",
  "conditionChanges": { "monthlySavingAmount": 500000 },
  "conditions": {
    "current": { "monthlySavingAmount": 300000, "savingsRatioPct": 50, "savingsRateInputPct": 3.12, "targetPeriodMonths": 36 },
    "changed": { "monthlySavingAmount": 500000, "savingsRatioPct": 50, "savingsRateInputPct": 3.12, "targetPeriodMonths": 36 }
  },
  "current": { "...": "C2-4" },
  "changed": { "...": "C2-4" },
  "diff": { "...": "C2-5" },
  "display": { "...": "C2-6" }
}
```

| 필드 | 타입 | 뜻 | 상태 |
|---|---|---|---|
| `calcRunId` | integer | 이번 계산의 `calc_run(run_type=CHAT)` id(C2-7). ai-server는 이 값을 `/chat` 응답의 `calcRunId`로 넘긴다 | 이미 있음 (`CalcClient`가 정수인지 검사) |
| `basePlanVersionId` | integer | 기준으로 쓴 `plan.current_version_id`. `calc_run.plan_version_id`와 같다 | 새로 필요 |
| `baselineScenario` | string | 요청 값을 그대로 돌려줌 | 새로 필요 |
| `conditionChanges` | object | 실제 계산에 쓴 바꾼 값. 요청에서 `null` 키를 뺀 것. 키는 camelCase | 새로 필요 |
| `conditions.current` / `conditions.changed` | object | 대화로 바꿀 수 있는 4개 조건의 **계산에 실제 쓴 값**(기본금리·기본비중이 채워진 뒤). 4개 키가 항상 모두 있다 | 새로 필요 [기획 제안] |
| `current` / `changed` | object | C2-4 | 새로 필요 |
| `diff` | object | C2-5 | 새로 필요 |
| `display` | object | C2-6 | 새로 필요 |

- `conditions`가 필요한 이유: `CalcResult`에는 `monthlySavingAmount`·`targetPeriodMonths`가 없다(`Assumptions`에 금리·비중만 있음). "월 30만원 → 50만원" 비교 표와 AI 설명이 이 값을 응답 하나에서 읽게 한다. [기획 제안] 왜: `planContext`(C-1a)에서 따로 꺼내면 두 출처의 값이 어긋날 수 있다.
- `conditions.*.savingsRateInputPct`는 기본금리를 썼어도 실제로 쓴 금리를 넣는다(= `Assumptions.savingsRatePct`). 기본금리였는지는 `current.assumptions.isDefaultSavingsRate`.
- ai-server는 모르는 키를 무시한다(앞으로 필드가 늘어도 깨지지 않게). 지금 `CalcClient`는 `dict`로 받으므로 이미 그렇다.
- 근거: FR-AI-07, D-022("현재 조건과 바꾼 조건의 비교 결과"), D-041, `b-team-contracts.md` C-2 응답 초안, `alignment.md` 2-3 "비교 결과의 모양", 2-7 "비교 결과 타입".
- 구현 메모(b-team-contracts C-2): calc 모듈 공개 타입 `CalcComparison`(이름은 A팀이 정함) 하나로 만들어 F-4(대화 비교 조회)와 Should인 FR-CMP-02가 재사용.

### C2-4. `current` / `changed` — `CalcResult` 구조 이미 있음, JSON 직렬화 규칙 새로 필요

`current` = 현재 계획을 그대로 계산한 결과, `changed` = 현재 계획에 `conditionChanges`만 얹어 계산한 결과. **둘 다 `CalcResult`(`backend/.../calc/CalcResult.java`)를 Jackson 기본 규칙으로 직렬화하되 `scenarios[].monthlyPoints`만 뺀다.**

```json
{
  "status": "CALCULATED",
  "goalAmount": 20000000,
  "calcStartMonth": "2026-11",
  "targetMonth": "2029-11",
  "baselineScenario": "AVG",
  "scenarios": [
    { "scenario": "GOOD", "annualReturnPct": 14.2, "afterTaxAsset": 18450000, "principal": 15800000,
      "afterTaxGain": 2650000, "gapToGoal": -1550000, "isAchieved": false, "goalReachMonth": null },
    { "scenario": "AVG", "annualReturnPct": 9.8, "afterTaxAsset": 17120000, "principal": 15800000,
      "afterTaxGain": 1320000, "gapToGoal": -2880000, "isAchieved": false, "goalReachMonth": null },
    { "scenario": "BAD", "annualReturnPct": 1.1, "afterTaxAsset": 15980000, "principal": 15800000,
      "afterTaxGain": 180000, "gapToGoal": -4020000, "isAchieved": false, "goalReachMonth": null }
  ],
  "requiredMonthlySaving": null,
  "assumptions": {
    "savingsRatePct": 3.12, "isDefaultSavingsRate": true, "savingsRateBaseMonth": "2026-10",
    "savingsRatioPct": 50, "taxRatePct": 15.4, "scenarioMethod": "ROLLING_DISTRIBUTION",
    "sp500BaseDate": "2026-10-31",
    "excludedItems": ["ETF_TOTAL_EXPENSE", "EXCHANGE_RATE", "ETF_DISTRIBUTION", "HELD_ASSET_RETURN", "SAVINGS_REDEPOSIT"]
  },
  "dataVersions": { "savingsRateVersionId": 3, "sp500VersionId": 5, "calcParamVersionId": 2, "engineVersion": "1.0.0" }
}
```

같은 요청의 `changed`(월 50만원) 예시는 숫자만 다르다:

```json
{
  "status": "CALCULATED", "goalAmount": 20000000, "calcStartMonth": "2026-11", "targetMonth": "2029-11",
  "baselineScenario": "AVG",
  "scenarios": [
    { "scenario": "GOOD", "annualReturnPct": 14.2, "afterTaxAsset": 27020000, "principal": 23000000,
      "afterTaxGain": 4020000, "gapToGoal": 7020000, "isAchieved": true, "goalReachMonth": "2028-12" },
    { "scenario": "AVG", "annualReturnPct": 9.8, "afterTaxAsset": 25010000, "principal": 23000000,
      "afterTaxGain": 2010000, "gapToGoal": 5010000, "isAchieved": true, "goalReachMonth": "2029-03" },
    { "scenario": "BAD", "annualReturnPct": 1.1, "afterTaxAsset": 23240000, "principal": 23000000,
      "afterTaxGain": 240000, "gapToGoal": 3240000, "isAchieved": true, "goalReachMonth": "2029-10" }
  ],
  "requiredMonthlySaving": null,
  "assumptions": { "...": "current와 같음(이번 변경이 금리·비중이 아니므로)" },
  "dataVersions": { "...": "current와 같음(C2-7)" }
}
```

(숫자는 형식 예시다. 엔진 결과가 아니다.)

직렬화 규칙 — 목·테스트가 이 표기를 기준으로 삼는다:

| Java 타입 | JSON | 예 |
|---|---|---|
| `long`, `Long` | 정수 | `17120000` |
| `BigDecimal` | 숫자(문자열 아님) | `3.12` |
| `YearMonth` | `"YYYY-MM"` | `"2029-11"` |
| `LocalDate` | `"YYYY-MM-DD"` | `"2026-10-31"` |
| enum | 이름 문자열 | `"CALCULATED"` |
| `boolean isAchieved`, `isDefaultSavingsRate` | 키 이름 **`isAchieved`**, `isDefaultSavingsRate` (record 컴포넌트 이름 그대로) | `"isAchieved": false` |
| `null` | 키를 빼지 않고 `null` | `"goalReachMonth": null` |

필드 뜻(moeun 주석 그대로):
- `status`: `CALCULATED` / `ALREADY_EXCEEDED`. 이 경로에서 `ALREADY_EXCEEDED`는 오류로 돌린다(C3-2). 대화로 목표 금액·보유 자산을 바꿀 수 없으므로(D-040) `current`가 `CALCULATED`면 `changed`도 `CALCULATED`다.
- `scenarios`: ETF 포함이면 GOOD·AVG·BAD 3개, **ETF 0%(`savingsRatioPct=100`)면 AVG 1개**. 비중 변경으로 `current`와 `changed`의 시나리오 수가 다를 수 있다(C2-5 처리).
- `gapToGoal`: `afterTaxAsset - goalAmount`, 0 이상이면 달성(CP-01).
- `goalReachMonth`: 계산한 기간 안에 처음 목표 이상이 되는 달, 없으면 `null`.
- `requiredMonthlySaving`: 해커톤에서는 항상 `null`(D-045, 월 저축액 모름 분기 범위 밖).
- `targetMonth`: 해커톤에서는 항상 값이 있음(D-045, 목표 기간 필수).

빼는 것:
- `scenarios[].monthlyPoints` — **키 자체를 뺀다.** [기획 제안] 왜: 36~수백 개 점이라 LLM 토큰만 늘고 설명에 쓰지 않는다. 대화창 비교는 숫자만(Q-039 3번 권장, b-team-contracts F-4). 구현 방식(응답 전용 DTO vs `@JsonIgnore` 믹스인)은 A팀이 정한다(검토자 질문 1).

근거: `backend/.../calc/CalcResult.java`, `ScenarioResult.java`, `Assumptions.java`, `AppliedDataVersions.java`, `CalcStatus.java`, `Scenario.java`, `ScenarioMethod.java`, `ExcludedItem.java`; CP-01, FR-RES-03·06, D-045, `b-team-contracts.md` C-5.
- 이미 있음: 필드 이름과 타입 전부. 새로 필요: 위 직렬화 규칙을 고정하는 직렬화 테스트(REST Docs 스니펫이면 충분), `monthlyPoints` 제외.

### C2-5. `diff` — 새로 필요 [기획 제안]

`changed − current`. Spring이 계산한다.

```json
{
  "baseline": {
    "scenario": "AVG",
    "afterTaxAssetDelta": 7890000,
    "principalDelta": 7200000,
    "achievementChange": "MISS_TO_ACHIEVE"
  },
  "byScenario": [
    { "scenario": "GOOD", "afterTaxAssetDelta": 8570000, "principalDelta": 7200000, "achievementChange": "MISS_TO_ACHIEVE" },
    { "scenario": "AVG",  "afterTaxAssetDelta": 7890000, "principalDelta": 7200000, "achievementChange": "MISS_TO_ACHIEVE" },
    { "scenario": "BAD",  "afterTaxAssetDelta": 7260000, "principalDelta": 7200000, "achievementChange": "MISS_TO_ACHIEVE" }
  ]
}
```

| 필드 | 타입 | 뜻 |
|---|---|---|
| `afterTaxAssetDelta` | integer(KRW, 부호 있음) | `changed.afterTaxAsset − current.afterTaxAsset` |
| `principalDelta` | integer(KRW, 부호 있음) | `changed.principal − current.principal`. "더 넣은 돈" 설명용 |
| `achievementChange` | `STAYS_ACHIEVED` / `STAYS_MISSED` / `MISS_TO_ACHIEVE` / `ACHIEVE_TO_MISS` | `isAchieved` 전후 |
| `baseline` | object | 양쪽 모두 `CalcResult.findBaselineResult()`로 고른 결과끼리의 차이. ETF 0%면 AVG끼리. `scenario`는 `changed` 쪽에서 고른 시나리오 |
| `byScenario` | array | **양쪽에 모두 있는 시나리오만**, GOOD·AVG·BAD 순서 |

- `gapToGoalDelta`는 두지 않는다. 왜: 대화로 목표 금액을 바꿀 수 없어(D-040) 항상 `afterTaxAssetDelta`와 같다. 같은 값을 두 번 주면 LLM이 다른 숫자로 오해할 수 있다. (b-team-contracts C-2 초안에서 바뀐 점)
- 기간을 바꾸면 `targetMonth`가 달라져 서로 다른 달의 자산을 비교한다. 이 값이 맞다(사용자는 "기한을 늘리면 그때 얼마"를 묻는다). 기간 차이는 `conditions`로 설명한다(개월 수 빼기를 Spring이 줄 필요는 없음 — `display`의 `conditions.*.targetPeriodMonths` 문자열을 인용).
- 시나리오 수가 다르면(비중 100 ↔ 그 밖) `byScenario`에는 AVG만 남는다. ai-server는 `changed.scenarios`로 새 3구간을 설명한다.
- 근거: 원칙 1, NFR-INT-01, FR-AI-02, `alignment.md` 2-3 "비교 결과의 모양"(LLM이 빼기를 하면 위반 위험), `CalcResult.findBaselineResult()`(ADR-001 한계 1번).

### C2-6. `display` — 새로 필요 [기획 제안]

CP-04 표시 형식(`Formatter`, `db/moved-to-code.md` §4)으로 Spring이 만든 문자열. **LLM은 금액·기간을 말할 때 이 문자열을 그대로 인용한다.**

```json
{
  "current.AVG.afterTaxAsset": "약 1,712만원",
  "current.AVG.gapToGoal": "-약 288만원 미달",
  "changed.AVG.afterTaxAsset": "약 2,501만원",
  "changed.AVG.gapToGoal": "+약 501만원 달성",
  "diff.AVG.afterTaxAssetDelta": "+약 789만원",
  "diff.AVG.principalDelta": "+약 720만원",
  "diff.baseline.afterTaxAssetDelta": "+약 789만원",
  "conditions.current.monthlySavingAmount": "약 30만원",
  "conditions.changed.monthlySavingAmount": "약 50만원",
  "conditions.current.targetPeriodMonths": "3년 0개월",
  "conditions.current.savingsRatioPct": "적금 50 : ETF 50",
  "conditions.current.savingsRateInputPct": "연 3.12%"
}
```

키 규칙 (평평한 맵, 점으로 경로 표시):

| 키 패턴 | 형식(CP-04) | 대상 |
|---|---|---|
| `current.<SCENARIO>.afterTaxAsset`, `changed.<SCENARIO>.afterTaxAsset`, `….principal` | `약 N만원` | 응답에 있는 모든 시나리오 |
| `current.<SCENARIO>.gapToGoal`, `changed.<SCENARIO>.gapToGoal` | 부호 + `약 N만원` + `달성/미달` | 〃 |
| `diff.<SCENARIO>.<필드>`, `diff.baseline.<필드>` | 부호 + `약 N만원` | `afterTaxAssetDelta`, `principalDelta` |
| `conditions.<current\|changed>.<키>` | 금액 `약 N만원`, 기간 `n년 n개월`, 비중 `적금 a : ETF b` | 4개 키 모두 |

- `약 N만원`의 반올림은 TBD-16(천 단위 반올림)을 따른다. 0원·음수 처리도 `Formatter` 한 곳.
- 문구 템플릿(`달성`, `미달`, `적금 a : ETF b`)은 문구표 `copy/copy.ko.yml`(CP-05)에서 읽는다.
- **CP-04에 없는 형식 2가지는 [기획 제안]**: 차이 값의 `+약 N만원`/`-약 N만원`, 금리의 `연 N.NN%`.
- 왜: "약 N만원" 반올림을 LLM이 하면 그것도 계산이다. Spring이 문자열을 주면 숫자 대조(PR-04, alignment M-4)도 "본문의 금액 표현이 `display` 값 중 하나인가"로 단순해진다.
- 근거: CP-04, CP-05, FR-AI-02, `b-team-contracts.md` C-1a `display`, A-5(`Formatter` 이름만 있음).
- 이미 있음: `Formatter`·`copy.ko.yml` 이름(`db/moved-to-code.md` §4). 새로 필요: 구현 전부.

### C2-7. 계산 기록 — 테이블 이미 있음, 기록 규칙 새로 필요

- 성공한 요청 1건마다 `calc_run` **1행**을 INSERT한다: `plan_version_id = basePlanVersionId`, `run_type = 'CHAT'`, 데이터 버전 3종과 `engine_version`(`AppliedDataVersions`). 그 `id`가 `calcRunId`.
- `current`와 `changed`는 **같은 데이터 버전·같은 엔진 버전**으로 계산하고, 그 버전을 이 행에 남긴다. `current`용 행은 따로 만들지 않는다. [기획 제안] 왜: 차이가 조건 변경에서만 나오게 하고, F-4(대화 비교 조회)가 이 행 + `chat_message.condition_changes`만으로 같은 결과를 다시 계산할 수 있게(ADR-002 결과 미저장).
- 해커톤에서는 활성 데이터 버전을 쓴다(D-045: D-038 범위 밖. 해커톤 중 데이터 갱신 없음).
- **실패하면 기록하지 않는다**: C3의 모든 오류(검증 실패, 바꿀 수 없는 조건, 계획 없음, 이미 초과, 엔진 오류)에서 `calc_run`을 만들지 않는다. 그래서 `calcRunId`가 없으면 `RECALC_RESULT`도 없다(`agent.py` `assemble`, D-033 "검증을 통과한 뒤에만 비교 결과").
- 성공했지만 ai-server가 그 뒤 실패하거나 `OUT_OF_SCOPE`로 끝나면 `chat_message`가 참조하지 않는 CHAT 행이 남는다. 정리하지 않는다(alignment 2-3 "범위 밖이면 계산하지 않음": 화면 동작은 맞음).
- 요청마다 새 행이다(멱등 키 없음). 같은 발화를 두 번 계산해도 결과는 같고 행만 2개.
- 근거: `schema.sql` `calc_run`(`ck_cr_run_type IN ('PLAN','CHAT')`, "CHAT: chat_message가 참조하는 대화 재계산"), `chat_message.calc_run_id` FK, `ck_cm_recalc`, `backend/.claude/rules/persistence.md`(`DataVersionService.requireKind`, 결과 미저장), `db/moved-to-code.md` §1 `calc_run_override`, NFR-INT-02.

### C2-8. 기준 계획과 누적 금지 — 원칙 이미 있음(D-041), 서버 규칙 명시 새로 필요

- **기준은 항상 그 회원의 현재 계획**이다: `plan.current_version_id`가 가리키는 `plan_version`. 이전 대화에서 바꾼 조건은 **누적하지 않는다**(D-041). Spring은 요청 한 건의 `conditionChanges`만 현재 계획에 얹는다. 대화 상태를 저장하거나 읽지 않는다.
  - 예(FR-AI-06 수용 기준): 현재 계획 월 30만원. 1번째 요청 `{monthlySavingAmount: 500000}` → 월 50만원 비교. 2번째 요청 `{targetPeriodMonths: 60}` → **월 30만원 + 60개월** 비교. 2번째 계산에 월 50만원은 들어가지 않는다.
  - ai-server 쪽 짝 규칙: 도구 인자에는 **이번 발화에서 사용자가 말한 조건만** 넣는다. `history`에서 이전 턴의 값을 다시 넣지 않는다(alignment M-3, 프롬프트 + fake 모델 테스트). 사용자가 한 발화에서 둘 다 말하면("월 50만원에 5년으로") 두 키를 한 요청에 담는 것은 허용.
- **적용된 뒤에는 새 현재 계획이 기준**이다. 이전 비교 결과의 `basePlanVersionId`가 현재 계획과 다르면 그 결과는 적용할 수 없다(판정은 A-1 적용 API·F-4 `applicable`의 몫이며 이 계약 밖).
- **시작월은 현재 계획의 `calc_start_month`**를 그대로 쓴다. 요청 시각의 월로 바꾸지 않는다(D-013, D-032). `current.calcStartMonth == changed.calcStartMonth`가 항상 성립한다.
- 대화로 바꾸지 않은 조건(목표 금액, 보유 자산 등)은 현재 계획 값 그대로다. 금리를 비워 둔 계획이면 `changed`도 기본금리, 비중을 비워 둔 계획이면 기본 비중(5:5)을 쓴다(`ConditionResolver`, `RatioResolver`).
- 근거: D-041, D-013, D-032, FR-AI-06·07 수용 기준, `alignment.md` 2-3 "비교 기준(누적 여부)", 2-4 "시작월 고정", M-1·M-3, `db/moved-to-code.md` §2 `ConditionResolver.resolve(planVersion, changes, dataVersions)`.
- 새로 필요: `CalcInput.calcStartMonth` 주석("재계산할 때는 현재 월이 들어온다") 정정과 단위 테스트(alignment M-1, 별도 Issue), Spring 통합 테스트 "두 번째 요청에 첫 번째 변경이 섞이지 않음".

---

## C3. 검증·오류 형식

### C3-1. 오류 본문 형식 — 새로 필요 [기획 제안: 형식 전체]

Spring 내장 `ProblemDetail`(RFC 9457, 구 7807)에 확장 필드 `code`, `errors`를 더한다. `Content-Type: application/problem+json`.

**예시: 월 저축액이 허용 상한을 넘음** (FR-AI-06 수용 기준 "월 저축액 허용 상한(1000만원)을 넘는 값")

요청:
```json
{ "memberId": 7, "baselineScenario": "AVG", "conditionChanges": { "monthlySavingAmount": 12000000 } }
```
응답 `HTTP 422`:
```json
{
  "type": "about:blank",
  "title": "입력 범위를 벗어났어요",
  "status": 422,
  "detail": "monthlySavingAmount: OUT_OF_RANGE",
  "instance": "/internal/calc",
  "code": "VALIDATION_FAILED",
  "errors": [
    {
      "field": "monthlySavingAmount",
      "reason": "OUT_OF_RANGE",
      "min": 10000,
      "max": 10000000,
      "unit": "KRW",
      "copyKey": "validation.monthlySavingAmount.range"
    }
  ]
}
```

| 필드 | 타입 | 필수 | 뜻 |
|---|---|---|---|
| `type`, `title`, `status`, `detail`, `instance` | — | `status`만 필수 | `ProblemDetail` 기본 필드. `title`은 문구표에서, 사람이 읽는 용도. **기계 판단은 `code`로만** 한다 |
| `code` | string | 예 | C3-2 코드 표의 값 |
| `errors` | array | `VALIDATION_FAILED`·`FIELD_NOT_CHANGEABLE`일 때 1개 이상, 그 밖은 빈 배열 | 필드별 오류 |
| `errors[].field` | string | 예 | 요청 `conditionChanges`의 키(camelCase) 또는 `conditionChanges` |
| `errors[].reason` | string | 예 | `OUT_OF_RANGE` / `REQUIRED` / `NOT_INTEGER` / `TOO_MANY_DECIMALS` / `NOT_CHANGEABLE` |
| `errors[].min`, `errors[].max` | number | `OUT_OF_RANGE`일 때 | 허용 범위(포함). 단위는 `unit`. 요청 값과 같은 단위(원·개월·%) |
| `errors[].unit` | `KRW` / `MONTH` / `PCT` | `min`·`max`가 있을 때 | |
| `errors[].scale` | integer | `TOO_MANY_DECIMALS`일 때 | 허용 소수 자릿수(금리 2, TBD-09) |
| `errors[].copyKey` | string | 아니오 | 문구표 키(CP-05). 프론트가 같은 형식을 쓸 때 안내 문구를 찾는 용도 |

- 요청 값(`rejectedValue`)은 넣지 않는다. 왜: ai-server는 자기가 보낸 값을 이미 알고, 로그에 금융 값을 남기지 않기로 한 방침(`CalcInput` 주석)과 맞춘다.
- 근거: D-033, CP-02, FR-AI-06 수용 기준, `b-team-contracts.md` 원칙 5·C-3, `alignment.md` 2-3 "범위 검증 위치"(오류 본문 형식이 정해지지 않아 LLM이 원문 텍스트를 읽음).

### C3-2. 코드 표 — 새로 필요 [기획 제안: 코드 이름·HTTP 상태]

| HTTP | `code` | 언제 | `calc_run` | ai-server 동작 |
|---|---|---|---|---|
| 422 | `VALIDATION_FAILED` | 허용 키의 값이 CP-02 범위 밖(`OUT_OF_RANGE`), 정수가 아님(`NOT_INTEGER`), 금리 소수 자릿수 초과(`TOO_MANY_DECIMALS`), 바꿀 값이 없음(`REQUIRED`) | 없음 | `CLARIFY`로 끝낸다. `errors[].min`·`max`·`unit`을 인용해 범위를 알려주고 값을 다시 묻는다(D-033). 숫자는 `min`·`max`를 원 → 만원으로 말할 때도 Spring 값을 기준으로 한다(아래 C3-4) |
| 422 | `FIELD_NOT_CHANGEABLE` | 허용 4개 밖의 키(목표 금액, 보유 자산 등). `errors[].reason = NOT_CHANGEABLE` | 없음 | 계산·비교 없이 **"목표 금액은 입력 수정에서 바꿀 수 있어요"** 식으로 입력 수정을 안내하고, 대화로 바꿀 수 있는 4개 조건(월 저축액·비중·적금 금리·기한)을 알려준다. `messageType = OUT_OF_SCOPE`, 문구는 문구표 키 [기획 제안] (D-040, FR-AI-06 수용 기준, FR-AI-09) |
| 409 | `NO_PLAN` | 그 회원의 `plan` 행이 없음 | 없음 | `ANSWER`로 "먼저 목표와 조건을 입력해 계획을 만들어 주세요"(문구표) |
| 409 | `ALREADY_EXCEEDED` | 현재 계획이 이미 목표 초과(보유 자산 ≥ 목표 금액, FR-RES-01) | 없음 | `ANSWER`로 초과 사실과 "목표 금액은 입력 수정에서 바꿀 수 있어요" 안내 |
| 400 | `MALFORMED_REQUEST` | JSON 파싱 실패, 타입 불일치(문자열 금액 등), `memberId`·`baselineScenario` 누락, 모르는 `baselineScenario` 값 | 없음 | 모델에 넘기지 않고 `AgentError("CALC_BAD_REQUEST")` → Spring이 `FAILED`(FR-AI-04). 왜: ai-server 버그라 되물어도 고칠 수 없다 |
| 401 | `INVALID_INTERNAL_KEY` | `X-Internal-Api-Key` 없음·불일치 | 없음 | `AgentError("CALC_UNAUTHORIZED")` → `FAILED` |
| 500 | `CALC_FAILED` | 엔진 예외, 기준 데이터 없음 등 서버 오류 | 없음(롤백) | `AgentError("CALC_FAILED")` → `FAILED`(FR-AI-04) |

- 목표 금액 변경은 두 겹으로 막는다: (1) ai-server 도구 스키마에 4개 키만 있어 모델이 `goalAmount`를 보낼 수 없고, 프롬프트가 목표 금액 변경 의도에 위 안내로 답한다(alignment M-2). (2) 그래도 들어오면 Spring이 `FIELD_NOT_CHANGEABLE`로 거절한다. **두 경로의 사용자 결과(입력 수정 안내, 비교 결과 없음)는 같아야 한다.**
- `NOT_INTEGER`는 Jackson이 `500000.5`를 `Long`으로 받지 못할 때 400이 아니라 422로 돌려야 한다(LLM이 "50.5만원"을 원 단위로 바꾸며 생길 수 있는 값이라 되묻기 대상). 구현 방법은 A팀.
- `ALREADY_EXCEEDED`를 409 오류로 둔 이유: 대화로 목표 금액·보유 자산을 못 바꾸므로 `changed`도 반드시 초과라 비교가 의미 없다. [기획 제안] (검토자 질문 2)
- 근거: D-033, D-040, FR-AI-04·06·09, FR-RES-01, `b-team-contracts.md` C-3 표, `CalcStatus.ALREADY_EXCEEDED`, `ai-server/app/llm/agent.py` `AgentError`, `chat_message` CHECK(`ck_cm_out_of_scope`: `OUT_OF_SCOPE`면 `calc_run_id` NULL).

### C3-3. 범위 수치의 출처 — 새로 필요 (수치는 임시)

- 허용 범위는 **Spring 설정 `rules.yml › input.fields.<FIELD>.{required,min,max,unit,scale}`** 한 곳에 둔다. 대화 경로의 허용 키는 `rules.yml › change-paths.CHAT.fields`(4개). 검사는 `ConditionValidator.validate(ChangePath.CHAT, values)`(`db/moved-to-code.md` §1·§3). 입력·대안·비교·대화가 같은 함수를 거친다.
- 오류 본문의 `min`·`max`·`unit`·`scale`은 **이 설정 값을 그대로** 내보낸다. **ai-server는 범위 수치를 코드·프롬프트에 하드코딩하지 않는다.** 왜: TBD-09·TBD-10이 정해지면 Spring 설정 한 줄만 바뀌어야 한다.
- 지금 쓸 값(**임시**, 목·테스트용. TBD-09·TBD-10 확정 시 교체):

| 키 | min | max | unit | scale | 출처 |
|---|---|---|---|---|---|
| `monthlySavingAmount` | 10000 | 10000000 | KRW | — | max: TBD-09 "월저축액 상한 1000만원"(SRS FR-AI-06 수용 기준). min: [기획 제안] 1만원(TBD-39 "1만원부터" 넛지 문구에서 따옴, 미결) |
| `savingsRatioPct` | 0 | 100 | PCT | 0 | `CalcInput`·`schema.sql` `ck_pv_ratio`. 변경 단위(TBD-10)는 대화 경로에 적용하지 않음 [기획 제안] |
| `savingsRateInputPct` | 0 | 20 | PCT | 2 | scale: TBD-09 "금리 둘째자리". max: [기획 제안] 임시값 |
| `targetPeriodMonths` | 1 | 360 | MONTH | 0 | min: `CalcInput`(> 0). max: [기획 제안] 임시 30년(TBD-10·TBD-39 미결) |

- 원 단위 정수로 검증한다. 화면 입력 단위(만원, TBD-09)는 프론트 입력 단계에서만 바꾼다(alignment 2-7). 대화로 받은 "50만원"은 LLM이 `500000`으로 넣고 Spring이 검증한다.
- `rules.yml` 파일 위치: `db/moved-to-code.md`는 "두 서버가 함께 읽는 `config/rules.yml`"이라 적었지만 moeun에 아직 파일이 없다. 이 계약에서 ai-server는 이 파일을 읽을 필요가 없다(오류 본문으로 받음). 위치는 A팀이 정한다.
- 근거: CP-02, D-033, TBD-09·TBD-10(`docs/notion-decisions.md`), `db/moved-to-code.md` §1·§3, `CalcInput.java`, `schema.sql` `plan_version` CHECK.
- 이미 있음: 클래스·설정 키 이름(문서). 새로 필요: `rules.yml`, `ConditionValidator`, 위 임시값.

### C3-4. ai-server 처리 규칙 (`CalcClient`, 도구 결과) — 일부 이미 있음, 변경 새로 필요

| Spring 응답 | 지금(`ai-server/app/tools/calc.py`) | 계약 |
|---|---|---|
| 200 | `calcRunId` 정수 검사 후 `dict` 반환 | 그대로. 모델에 넘기는 도구 결과는 응답 JSON 그대로(또는 `display`·`diff`·`conditions`·`changed`만 추린 것. 추릴지는 B팀이 정함) |
| 422, 409 | `CalcError(resp.text[:500])` | `CalcError`로 모델에 넘기되 **본문을 파싱해 `{code, errors}`만** 넘긴다. 왜: 500자 자르기로 JSON이 깨질 수 있고, `title`·`type`은 모델에 필요 없다 |
| 400, 401, 5xx | 400은 `CalcError`, 401·5xx는 `raise_for_status()` → `httpx.HTTPStatusError`(현재 `_TOOL_ERRORS`에 없어 요청 실패로 올라감) | 모두 `AgentError(code)`로 바꿔 요청 실패 → Spring이 `FAILED`·`FAILURE` 기록(FR-AI-04). 400을 모델에 넘기지 않는다 |
| 타임아웃·연결 실패 | `httpx` 예외가 그대로 올라감 | `AgentError("CALC_UNAVAILABLE")` → `FAILED` [기획 제안] |

- **자동 보정 금지**: 범위 오류를 받은 모델은 `max`로 바꿔 다시 계산하지 않는다("1000만원으로 계산해 볼게요" 금지). 사용자에게 범위를 알리고 다시 묻는다(D-033 "범위를 알려주고 다시 묻는다", CP-02 수용 기준 "비교 결과는 뜨지 않으며"). 같은 요청 안의 재시도는 사용자가 이미 다른 값도 말한 경우에만.
- 되묻기 뒤 사용자가 새 값을 말하면 다음 `/chat` 요청에서 새로 `recalculate`를 부른다. 이때도 기준은 현재 계획이다(C2-8).
- 근거: D-033, FR-AI-04, `ai-server/.claude/rules/python.md`("예외는 의미 있는 도메인 예외로", 맨 `except Exception` 금지), `ai-server/app/llm/agent.py` `_TOOL_ERRORS`·`AgentError`, `ai-server/.claude/rules/langchain.md`("계산 노드는 … 실패는 `CalcError` → `AgentError(code)`").

### C3-5. 적용 범위 — [기획 제안]

- 같은 오류 형식(C3-1)을 프론트 ↔ Spring API에도 쓴다: 입력 검증(FR-INP-09), 적용·되돌리기(A-1·A-2), 대화 API(F-1~F-4). 코드는 각 계약에서 더한다(예: `PLAN_CHANGED`, `UNAUTHENTICATED`, `NOT_FOUND`). 왜: 파서 하나, 문구표 키 하나로 프론트·ai-server가 같은 안내를 낸다.
- 이 문서(moeun #10)가 확정하는 코드는 C3-2 표의 7개뿐이다. 나머지는 #12(프론트-Spring API) 등에서 정한다.

---

## 부록 A. Issue #10 수용 기준 대응

| 수용 기준 | 충족 항목 |
|---|---|
| 월 저축액이 허용 상한을 넘는 요청 → HTTP 422, `code=VALIDATION_FAILED`, `errors[].field/reason/min/max/unit` 예시 JSON | C3-1 예시(요청·응답 JSON), C3-2 첫 행, C3-3 수치 출처 |
| 대화로 바꿀 수 없는 조건(목표 금액) → `FIELD_NOT_CHANGEABLE` 코드와 ai-server 동작(입력 수정 안내) | C2-2 허용 키 4개, C3-2 둘째 행(입력 수정 안내, 비교 없음), C3-2 아래 "두 겹으로 막는다" |
| 이전 대화의 변경이 있는 상태 → 기준은 항상 현재 계획, 변경은 누적하지 않음(D-041) | C2-8(예시 포함), 원칙 3, C2-3 `basePlanVersionId` |

## 부록 B. b-team-contracts C-2·C-3 초안에서 바뀐 것

| 항목 | 초안 | v1 | 이유 |
|---|---|---|---|
| C2-3 | `conditionChanges`, `current`, `changed`, `diff`, `display` | `baselineScenario`, `conditions` 추가 | `CalcResult`에 월 저축액·기간이 없음 |
| C2-5 | `gapToGoalDelta` 있음 | 뺌, `principalDelta`·`baseline` 추가, `achievementChanged` → `achievementChange`(4값) | 목표 금액이 바뀌지 않아 중복. ETF 0% 기준 시나리오 처리 |
| C2-6 | 예시 2개 | 키 규칙 표, 차이·금리 형식 제안 | 숫자 대조 기준을 고정 |
| C2-4 | "CalcResult (monthlyPoints 제외)" | 직렬화 표기 표(YearMonth, BigDecimal, isAchieved, null) | 목 JSON이 실제 직렬화와 어긋나지 않게 |
| C3-1 | `type`·`title`·`status`·`code`·`errors` | `detail`·`instance`, `errors[].scale`, reason `TOO_MANY_DECIMALS`·`NOT_CHANGEABLE` 추가 | TBD-09 금리 둘째자리, 목표 금액 오류도 `errors`로 |
| C3-2 | 400 없음, 5xx `CALC_FAILED` | 400 `MALFORMED_REQUEST`, 500 `CALC_FAILED`, `calc_run` 열 추가 | 지금 `CalcClient`가 400을 모델에 넘기는 문제 |
| C3-4 | 없음 | ai-server 처리 규칙, 자동 보정 금지 | D-033 "다시 묻는다"를 코드 동작으로 |

## 부록 C. [기획 제안] 모음 (결정에 없음, 쟁점 후보)

C2-2 빈 변경 거절·`baselineScenario`는 요청 값 사용 / C2-3 `conditions` / C2-4 `monthlyPoints` 키 제외 / C2-5 `diff` 구성 전체 / C2-6 `display` 전체(특히 차이 `±약 N만원`, 금리 `연 N.NN%` 형식) / C2-7 `current`도 CHAT 행의 버전으로 계산 / C3-1 형식 전체 / C3-2 코드 이름·HTTP 상태, `FIELD_NOT_CHANGEABLE`의 `messageType=OUT_OF_SCOPE` / C3-3 임시 수치(월 저축 최소 1만원, 금리 상한 20%, 기간 상한 360개월, 대화 비중 변경 단위 미적용) / C3-4 타임아웃 코드 / C3-5 프론트 API 공용

## 부록 D. 이 계약 밖이지만 걸려 있는 것

- `/chat` 응답 `conditionChanges`와 `chat_message.condition_changes`의 키는 snake_case(`ConditionChanges.changed()`), 이 계약의 키는 camelCase. F-4 재계산 때 Spring `chat` 모듈이 바꿔야 한다. 통일 여부는 C-1(moeun #11)에서 정한다.
- `planContext`(C-1a)의 `display` 키 규칙은 C2-6과 같은 규칙을 쓰는 것을 권한다(#11).
- 확정되면 moeun `docs/api/internal-calc.md`와 `ai-server/README.md` "Spring과의 계약"을 같은 내용으로 고친다(#10 완료 조건). README 표의 `→ {calcRunId, ...결과}`가 이 문서로 대체된다.

---

## 검토자에게 묻고 싶은 것

1. **(제공자, C2-4)** `monthlyPoints`를 빼는 방법으로 응답 전용 DTO와 `CalcResult` + Jackson 믹스인 중 무엇이 쉬운가? 그리고 Spring Boot 4.1의 Jackson 기본 설정에서 `YearMonth`가 `"2029-11"`, `BigDecimal`이 숫자, record의 `boolean isAchieved`가 키 `isAchieved`로 나오는지 직렬화 테스트로 고정해 줄 수 있는가? (목 JSON이 이 표기를 따른다)
2. **(제공자, C2-2·C3-2)** `baselineScenario`를 요청 값으로 쓰는 것(해커톤에서는 항상 AVG)과 `plan.baseline_scenario`를 다시 읽는 것 중 어느 쪽이 맞나? 또 현재 계획이 이미 목표 초과일 때 `409 ALREADY_EXCEEDED`가 나은가, `200` + `status=ALREADY_EXCEEDED`(빈 `scenarios`)가 나은가?
3. **(소비자, C3-2)** `FIELD_NOT_CHANGEABLE`(목표 금액 변경)을 받았을 때 `messageType`을 `OUT_OF_SCOPE`로 둘지 `ANSWER`로 둘지. SRS 수용 기준은 "안내 문구는 FR-AI-09·TBD-30을 따른다"라서 `OUT_OF_SCOPE`로 초안을 썼지만, FR-AI-09의 "서비스가 다루지 않는 질문"과 뜻이 다르다.
4. **(양쪽, C2-6)** `display`를 1주차 계약에 넣으면 A팀 `Formatter`·문구표가 1주차에 필요하다. 어렵다면 (a) 1주차엔 `display`를 빈 객체로 허용하고 ai-server는 `display`가 없을 때 금액을 말하지 않음, (b) `display`를 아예 C-1a(`planContext`)와 같이 2주차로 미룸 — 어느 쪽이 덜 막히나? 차이 값 `+약 N만원`·금리 `연 N.NN%` 형식도 괜찮은가?
5. **(소비자, C3-4)** `CalcClient`를 "422·409만 `CalcError`(파싱한 `{code, errors}`)로 모델에 넘기고, 400·401·5xx·타임아웃은 `AgentError`"로 바꾸는 것을 받아들일 수 있나? 이 변경을 #10 PR에 넣을지, M-2(조건 4개 축소) Issue에 넣을지도 의견을 달라.
