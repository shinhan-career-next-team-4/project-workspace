# internal-calc v2 재검토 — 제공자(A팀)

> /negotiate-contract 4단계. 소비자 의견을 함께 보고 v2에 새로 들어간 항목만 검토.

판정: **수정하면 수용** (고칠 곳 1개 + 보강 몇 개)

## 새 항목
- `afterTaxGainDelta` + display: 수용. `ScenarioResult.afterTaxGain`이 이미 있어 뺄셈 1줄.
- `diff.baselineScenario` 포인터: 수용 + 보강. "포인터는 항상 `byScenario`에 있는 시나리오(없으면 AVG)"를 적고 #32 테스트로 고정(`CalcResult.findBaselineResult()` 폴백 때문).
- 추가 display 키·경계 형식: 수용. #32에서 display 맵 빌더 약 0.5일. **#28 Formatter 수용 기준에 방향 단어, 경계값 4가지, `YYYY년 M월`, `연 N.NN%`, `약` 없는 경계값 표시를 추가해야 함.** X-1 확정 전 #28 시작 금지. 사소: 비중 표시를 `conditions`(`적금 50 : ETF 50`)와 `minDisplay`(`적금 0%`) 중 한쪽으로 통일.
- **`errors[].minDisplay`/`maxDisplay`: 수정 (가장 중요).** plan은 `allowedDependencies = {}`이고 calc → plan 방향이라, plan의 `ConditionValidator`(#17)가 calc의 Formatter를 부르면 **순환 의존**(ModularityTests 실패). → #17은 `min`·`max`·`unit`·`scale`만. `minDisplay`·`maxDisplay`는 #32의 `calc.web`이 `plan.ConditionViolationException`을 잡아 Formatter로 붙이고 `calc.CalcRejectedException`으로 다시 던진다. 이 필드는 `/internal/calc`에서만 보장(프론트 API #30에는 없음). #32는 #28에 의존하므로 [전환기] 표시는 사실상 불필요.
- 응답 필드 삭제: 수용(Spring 내부도 안 씀).

## v1 의견 반영 확인
- 검사 순서·Map<String, JsonNode>·config 전역 핸들러·409·display {}·비중 고정: 반영됨.
- 보강: (a) `memberId`도 `JsonNode.isIntegralNumber()`로 검사(7.5가 7로 잘림 방지). (b) **모순**: C2-2는 `baselineScenario` "무시", C3-2 표는 "모르는 값이면 400" → String으로 받고 값은 보지 않음(400 삭제).
- `config/error/**`가 어느 Issue paths에도 없음 → 새 Issue(전역 핸들러)를 1주차 #17과 같이 진행 필수.

## 쟁점 입장
- X-1: **C + 경계 규칙 찬성.**
- X-2: 이해관계 없음, A 반대하지 않음.
- X-3: **A 강하게 지지.**

## 꼭 지킬 것
- 모든 display(minDisplay 포함)는 calc(`calc.web` + Formatter)에서만. plan은 raw 범위만(순환 금지)
- `conditionChanges`·`memberId`는 JsonNode로 검사
- 전역 오류 핸들러 Issue를 1주차에
- X-1 확정 전 #28 시작 금지, #28 수용 기준 보강

## 양보 가능
- [전환기] 문구 유지, 모르는 baselineScenario 400/무시, 비중 표시 형식, X-2, display 키 개수
