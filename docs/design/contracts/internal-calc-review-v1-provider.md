# internal-calc v1 검토 — 제공자(A팀: Spring calc·plan)

> /negotiate-contract 2단계, 독립 검토. 근거: moeun backend/src/.../calc/{CalcInput,CalcResult,ScenarioResult,package-info}.java, plan·refdata package-info, config/SecurityConfig.java, application.yml, db/schema.sql, backend/.claude/rules/{modulith,persistence}.md, db/decision.md(ADR-002), db/moved-to-code.md
> Jackson 3 기본 동작(YearMonth 표기, isAchieved 키, ACCEPT_FLOAT_AS_INT)은 실행으로 확인하지 못함. 구현 PR의 REST Docs 테스트로 확정.

판정: **수정하면 수용**

## 항목별 의견
- [원칙 0] 수용. 수정안: "전역 `default-property-inclusion: non_null`을 켜지 않는다" 추가(null 유지 규칙이 깨짐).
- [C2-1] 수용. `/internal/**` 전용 `SecurityFilterChain`(API 키 필터)이 새로 필요(지금은 `anyRequest().authenticated()` 하나, SecurityConfig.java:20-24). 401은 필터에서 나므로 `@RestControllerAdvice`로 C3 형식을 못 냄 → 필터가 ProblemDetail을 직접 씀. 수정안: "401 본문은 필터가 직접 쓴다, `instance`는 없을 수 있다" 허용.
- [C2-2] 수정. (1) 4개 키 제한·섞이면 전체 거절은 수용. **단 `conditionChanges`를 타입 있는 record로 받으면 지킬 수 없음**(Boot 기본 `FAIL_ON_UNKNOWN_PROPERTIES=false`로 `goalAmount`가 조용히 버려지고, `ACCEPT_FLOAT_AS_INT=true`로 500000.5가 잘림) → Spring은 `Map<String, JsonNode>`로 받고 `plan.ConditionValidator.validate(ChangePath.CHAT, …)`에서 검사. (2) **검사 순서 명시**: ① 허용 밖 키 → FIELD_NOT_CHANGEABLE(NOT_CHANGEABLE 키만) ② 숫자 아님 → 400 MALFORMED ③ 범위·정수·자릿수 → 422 VALIDATION_FAILED(키마다 모두). (3) **빠진 경우**: 비중을 기존 납입액으로 산출하는 계획(DERIVED_EXISTING)에서 월 저축액만 바꾸면 산출 비중이 같이 바뀌고, 기존 납입액보다 작으면 비중이 100을 넘어 `CalcInput`이 예외(CalcInput.java:45-46) → 500. 사용자가 비중을 말하지 않았는데 `changed.savingsRatioPct`가 달라짐. 수정안: "CHAT 경로에서 `savingsRatioPct`가 없으면 **현재 계획의 해석된 비중을 고정**"을 C2-8에 추가. **의미 결정이라 기획 질문(FR-INP-08)으로.**
- [C2-3] 수용. `conditions`는 `CalcInput` 값을 옮기기만 하면 됨. 수정안: 공개 타입 `calc.CalcComparison(current, changed, conditions, diff)`를 calc 루트에, `monthlyPoints` 제거와 `display`는 웹 DTO(`calc.web`)에서만.
- [C2-4] 수용. 수정안: (a) "`scenarios`는 GOOD·AVG·BAD 순서"를 엔진 보장으로 계약에 적고 테스트로 고정(지금은 보장 안 함). (b) `savingsRatePct`가 NUMERIC(6,3)이라 `3.120`처럼 나올 수 있음 → 목·테스트는 숫자로 비교.
- [C2-5] 수용. 메모: `baseline.scenario`는 changed 쪽 값이며 current 쪽과 다를 수 있음(해커톤은 항상 AVG라 문제없음).
- [C2-6] 수정(1주차는 형식만 고정). 형식 `+약 N만원`, `연 N.NN%` 수용. 빠진 경계: 0원 차이, 반올림 단위 미만(+3,000원) 표기 — TBD-16과 함께 정해야 Formatter 테스트 가능.
- [C2-7] 수정. 성공 1건당 `calc_run(CHAT)` 1행, 같은 버전, 실패하면 기록 안 함은 쉬움. **단 ADR-002 문구("CHAT 재계산은 메시지가 참조할 때만 1행", db/decision.md:121)와 어긋남** — v1은 참조되지 않는 행(ai 실패, OUT_OF_SCOPE)을 남김. 수정안: 해커톤 비용 기준 v1 방식 유지 + ADR-002 문장을 "대화 재계산 요청마다 1행, 참조되지 않는 행은 남을 수 있음"으로 고치는 **D-번호 결정** 필요. (원래 방식대로 하면 ai-server가 calcRunId 대신 버전 묶음을 들고 다녀야 해 CalcClient·/chat 계약이 함께 바뀜.)
- [C2-8] 수용. calc → plan 공개 API(`plan.CurrentPlanQuery`)로 읽음, 순환 없음. `CalcInput.calcStartMonth` 주석은 D-013과 충돌하므로 고침(별도 Issue). 위 C2-2 (3) 비중 고정 규칙 추가.
- [C3-1] 수정. ProblemDetail + `code`·`errors` 속성 가능. 수정안: (a) 1주차 `title`은 코드별 고정 상수, 문구표 연결은 Formatter Issue에서. `copyKey`는 1주차 생략. (b) 전역 처리는 `config`에 `@RestControllerAdvice` 하나, 각 모듈은 자기 루트에 예외(`plan.ConditionViolationException`, `calc.CalcRejectedException`). 공용 `common` 모듈은 만들지 않음(plan·refdata `allowedDependencies={}`). Spring 기본 예외는 400 `MALFORMED_REQUEST`로. **CP-02 범위 검증을 Bean Validation 애너테이션으로 하지 않는다**를 계약 메모로.
- [C3-2] 수용. 7개 코드 모두 가능. 500은 `detail`에 내부 메시지 안 넣음.
- [C3-3] 수정. 위치 제안: `backend/src/main/resources/config/rules.yml`, plan 모듈 `@ConfigurationProperties`. ai-server는 이 계약에서 읽을 필요 없으니 지금은 Spring 전용(필요해지면 repo 루트로 옮기고 moved-to-code.md 수정). 임시 수치 수용. `InputField` enum ↔ camelCase 매핑 필요(작은 일).
- [C3-4] 수용(소비자 쪽 일).
- [C3-5] 수정. 전역 핸들러가 프론트 API도 덮으므로 비용 거의 없음. 단 프론트 API의 401(JWT 만료)은 리소스 서버 `AuthenticationEntryPoint`가 따로 냄 → "#12에서 401 형식 맞춘다" 메모.

## 질문 답변
- **Q1 monthlyPoints 제외**: 응답 전용 DTO(`calc.web.CalcResultView`, `ScenarioResultView`)가 쉽고 안전. 전역 믹스인은 그래프 API(FR-RES-04)까지 시계열을 지움. `@JsonProperty("isAchieved")`·`("isDefaultSavingsRate")` 명시. REST Docs 스니펫으로 직렬화 고정.
- **Q2 (a) baselineScenario**: **`plan.baseline_scenario`를 읽기 권장**(같은 행이라 비용 0, 원천 한 곳). 요청 필드는 "선택, Spring은 무시"로 두고 다음 버전에서 삭제. **(b) ALREADY_EXCEEDED는 409 오류 지지**(current 계산 전에 걸러 changed·diff·display 분기가 사라짐. 대화로 목표·보유 자산을 못 바꾸니 200이 줄 정보도 없음).
- **Q4 display 1주차 비용**: Formatter 0.5일 + copy.ko.yml 로더·위치 0.5일. 백엔드 1명의 1주차가 이미 꽉 참, TBD-16 미결. **권장 (a)**: v1 계약에 display 키 규칙과 형식은 지금 확정, **Spring 1주차 구현은 `display: {}` 허용**, Formatter와 문구표는 2주차 C-1a(planContext.display)와 같은 Issue에서. 계약 자체를 미루면 B팀 목·프롬프트가 2주차에 바뀌어 더 막힘. 0원·반올림 미만 표기만 정해 달라.

## 제공자 쪽에서 꼭 지켜야 할 것
- 범위·허용 키 검증은 plan `ConditionValidator`(rules.yml) 한 곳, `conditionChanges`는 Map/JsonNode로 받음
- 의존 방향 calc → plan·refdata만, 공개 API로만. 전역 오류 처리는 `config`, 공용 모듈 신설 안 함
- 결과 저장 안 함(ADR-002). `calc_run`은 성공할 때만. 고아 CHAT 행 허용하려면 ADR-002 수정 결정 필요
- `monthlyPoints` 제거와 `display`는 웹 DTO에서만, 도메인 타입 불변
- ALREADY_EXCEEDED는 409
- **CHAT에서 비중을 안 바꾼 요청은 현재 계획의 해석된 비중을 고정**(안 그러면 500 경로). 기획 결정 필요

## 양보 가능한 것
- `baselineScenario` 요청 필드 유지(무시 조건)
- NO_PLAN·ALREADY_EXCEEDED의 HTTP 숫자(code만 고정되면 됨)
- display 키 개수(모든 시나리오 vs 기준만)
- `title` 문구표 연결 시점, `copyKey`, `instance` 유무
- `rules.yml`을 나중에 repo 루트로 옮기기
- CHAT `calc_run`을 "메시지가 참조할 때만" 남기는 ADR-002 원래 방식(단 ai-server·/chat 계약 변경 비용)
