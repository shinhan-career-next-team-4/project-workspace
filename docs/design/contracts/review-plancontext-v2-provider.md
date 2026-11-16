# planContext 계약 v2 — 제공자(A팀 Spring: calc·plan·Formatter) 재검토

> 검토자: contract-provider, 2026-11-16. `/negotiate-contract` 4단계 재검토(마지막 1회). 대상 `plan-context-v2.md`(moeun #11).
> 함께 본 것: 내 v1 검토 `review-plancontext-v1-provider.md`, 소비자 v1 검토 `review-plancontext-v1-consumer.md`.
> 근거로 읽은 것(moeun origin/develop `7cef22e`, 읽기만 함): `calc/ScenarioResult.java`, `CalcResult.java`, `Assumptions.java`, 모듈별 `package-info.java`, `backend/.claude/rules/modulith.md`·`persistence.md`, `schema.sql`, moeun Issue #19·#28·#29·#30·#31·#32·#35·#41·#43 본문과 전체 Issue 목록(REST API), `b-team-contracts.md` F-3·A-0c, `internal-calc.md` C2-8.

```
판정: 수정하면 수용
```

계약 본문(키·형식·필드·검사 순서)은 그대로 받는다. 남은 수정은 거의 **후속 작업의 Issue 배치**다. v2가 "확인 필요"로 둔 Issue 대부분은 이미 있고, 몇 개는 다른 Issue를 가리키고 있다. 그대로 Issue 본문에 옮기면 선행 순서가 어긋난다(특히 display 빌더를 #32에서 처음 만든다는 부분은 #30이 #32를 기다리지 않으므로 순서가 맞지 않는다). 아래 1~3을 고치면 수용한다.

## 1. 내 v1 수정 제안 반영 확인

| v1 제안 | v2 반영 | 판정 |
|---|---|---|
| `CalcResultView`·`ScenarioResultView`를 calc 루트로 | C1a-2, G-10 | 반영됨. 단 #32 본문 paths 설명 "`calc/web/**` (CalcResultView·ScenarioResultView, …)"에서 두 이름을 **빼는** 것까지 G-10에 적어야 한다(지금은 "추가"만 있음) |
| `conditions` 출처 `CalcInput` | C1a-3 | 반영됨 |
| display 빌더 하나(`ResultDisplayBuilder`), 결과·조건 접두어 분리 | C1a-6 | 반영됨. **만드는 Issue는 틀림** → 아래 3번 G-8a |
| G-8 분리(키는 빌더, 형식만 #28) | G-8a·G-8b | 반영됨 |
| plan 공개 API `findVersion(memberId, planVersionId)` | C1a-10, G-12 | 반영됨. Issue는 #19(아래 3번) |
| 소유권 2단계, JOIN 금지 | C1a-10, G-13 | 반영됨 |
| `findPlanRun` 경량 조회, EXPLAIN `baselineScenario` 인자 | C1a-10 | 반영됨. 구현 메모 1줄 추가 요청(아래 2-2) |
| QUESTION은 결과 화면 Q1 서비스 재사용 | C1a-10 | 반영됨. 그 서비스는 **#29**("현재 계획의 결과를 조회하는 공개 서비스")이지 #30이 아니다 |
| 이름 `PlanContextProvider` | C1a-10 | 반영됨 |
| 트랜잭션 순서(HTTP는 트랜잭션 밖) | C1a-10, G-9 | 반영됨. 단 기존 규칙과 충돌 → 아래 2-1 |
| 생성 실패 → ai-server 미호출 `FAILED` | C1a-10 | 반영됨 |
| G-5를 손으로 만든 입력의 단위 테스트로 | C1a-13, G-5 | 반영됨. 비교 방법 1줄 추가 요청(아래 2-4) |
| fixture 공유 파일 | C1a-13, G-1 | 반영됨 |
| F-3 404 통일 | C1a-10, G-15 | 반영됨. Issue는 #43·#74(아래 3번) |
| 결과는 저장하지 않음(ADR-002) | C1a-10 "언제" | 반영됨 |

## 2. 소비자 제안 반영으로 생긴 제공자 쪽 부담·모듈 경계

- **[2-1. 트랜잭션 밖 HTTP 호출 vs `@ApplicationModuleListener`] 수정** — `modulith.md:23-24`는 "수신은 `@ApplicationModuleListener`로 한다(커밋 후, 비동기, **새 트랜잭션**)"이다. 이 어노테이션은 리스너 메서드 전체를 새 트랜잭션으로 감싸므로, 그대로 쓰면 C1a-10이 약속한 "planContext 만들기 → (트랜잭션 밖) HTTP 30초 → 짧은 트랜잭션 저장"이 되지 않는다(JPA가 연 커넥션을 호출 내내 잡는다). 내가 v1에서 요청한 것이 규칙과 부딪힌다는 것을 이번에 확인했다.
  - 수정안: G-9(#41)에 "ai-server 호출 리스너는 트랜잭션 없이 돈다. 방법: 쓰는 Modulith 버전의 `@ApplicationModuleListener`가 전파 속성을 받으면 `NOT_SUPPORTED`로, 아니면 `@Async @TransactionalEventListener` + `TransactionTemplate`(저장 구간만). 어느 쪽이든 `event_publication` 기록은 유지된다"를 적고, `modulith.md` 이벤트 절에 이 예외 1줄을 더한다(#41 paths 밖이므로 Issue 본문에 rules 파일 경로 추가). 제공자 코드 영향은 없다(`PlanContextProvider`는 자체 `@Transactional`).
- **[2-2. `findPlanRun`의 기준 시나리오 출처] 수정(작음)** — `PlanRunRef.baselineScenario`는 "조회 시점의 `plan.baseline_scenario`"인데, `baseline_scenario`는 `plan` 테이블에 있고 `plan_version`에는 없다(`schema.sql:94-100`). 그래서 `findVersion`만으로는 못 얻고 현재 계획 조회를 한 번 더 부른다(PK 조회 3번: calc_run → `findVersion` → 현재 계획). 문제는 없지만 계약에 적어 두면 구현자가 헤매지 않는다. 또 plan은 의존이 `{}`라(`plan/package-info.java`) `calc.Scenario`를 쓸 수 없으므로 plan 공개 API는 문자열(또는 plan 자체 enum)로 돌려주고 calc가 `Scenario`로 바꾼다. G-12에 한 줄.
- **[2-3. display 요구 키 전체 검사(H-2)] 수용 + 제공자 불변식 명시** — 소비자가 요구 키를 넓혀서 **Spring 빌더가 그 키를 반드시 만들어야 하는 의무**가 생겼다. 빌더가 하나라 비용은 테스트 몇 건뿐이다. 다만 `CalcInput.monthlySavingAmount`·`targetPeriodMonths`가 nullable이라(`CalcInput.java`) null이면 display 키가 빠져 502가 난다. D-045로 해커톤 중에는 null이 없지만, G-5에 "CALCULATED면 요구 키 표의 키가 모두 있다", "ALREADY_EXCEEDED면 `goalAmount`·`conditions.heldAssets`가 있다"를 테스트로 넣어 계약 표와 빌더를 묶어 달라.
- **[2-4. G-5 비교 방법] 수정(작음)** — fixture와 직렬화 결과를 JSON 트리로 비교할 때 `BigDecimal` 스케일(`15.4` vs `15.40`)이 다르면 같은 값이 다르게 판정될 수 있다. `Assumptions.taxRatePct`·`savingsRatePct`는 `BigDecimal`이다(`Assumptions.java`). G-5에 "숫자는 값으로 비교(스케일 무시)" 한 줄. 그리고 Spring G-5가 읽는 fixture는 Spring이 만드는 것(basic·etf0·exceeded·achieved·zero-held)뿐이고 polluted·display-missing·chat-request-*·model-input은 ai-server 전용임을 C1a-13 표에 열로 표시해 달라.
- **[2-5. 문구 매핑(`excludedNotes`·`scenarioMethodNote`)] 수용** — ai-server 쪽 일이고 Spring은 코드만 보낸다. 제공자 부담 0. `ExcludedItem`·`ScenarioMethod` enum 값이 늘면 ai-server 테스트("모든 코드에 문장")가 깨지므로, enum 변경 시 #18 문구표도 같이 고친다는 것을 `ExcludedItem` Javadoc 수준으로만 알리면 된다(선택).
- **[2-6. 모듈 경계] 문제 없음** — v2에서 새로 생긴 타입은 모두 calc 루트(`PlanContextProvider`, `PlanRunRef`, `PlanContextView`, `ConditionsView`, `CalcResultView`, `ScenarioResultView`) 또는 calc 내부(`calc.application.ResultDisplayBuilder`)다. chat → calc 루트, calc → plan 루트만 쓴다. `chat`이 `chat_message.baseline_scenario`를 `calc.Scenario`로 넘기는 것은 chat → calc 허용 방향(`chat/package-info.java`). 새 순환 없음.

## 3. [기획 보완] 2건

- **[isAchieved=true면 `<S>.goalReachMonth` 필수] 수용, 단 엔진 불변식으로 보장** — `ScenarioResult` 정의상 `goalReachMonth`는 "세후 예상 자산이 처음 목표 이상이 되는 달"이고 `isAchieved`는 목표월 값 기준이다(`ScenarioResult.java` Javadoc). 목표월 값이 목표 이상이면 그 달이 후보이므로 논리적으로는 항상 성립한다. 다만 **판정(TBD-16 반올림 기준)과 월별 시계열 비교가 같은 값을 써야** 성립한다. 어긋나면 ai-server에서 502가 나고 사용자는 설명 실패를 본다.
  - 수정안: #27(CalcEngine 2, 달성 판정) 수용 기준에 "`isAchieved=true`인 시나리오는 `goalReachMonth`가 null이 아니고 목표월 이하다"를 더한다. 원하면 `ScenarioResult` 생성자 검사 1줄로 막을 수 있다(엔진 버그를 계산 시점에 잡음). 후속 표에 G-17로 추가 요청.
- **[음수 금액 `-약 N만원`, 0만원이면 `-1만원 미만`] 수용** — BAD 시나리오 단기 계획에서 `afterTaxGain < 0`은 실제로 나온다(`afterTaxGain = afterTaxAsset − principal`). 지금 #28에는 음수 일반 금액 형식이 없어 `약 -5만원` 같은 값이 나올 수 있다. 목표 대비(`-약 288만원 미달`)와 부호 위치가 같아 일관된다. 비용: Formatter 분기 1개 + 테스트 2건. 빌더 공유라 `/internal/calc` C2-6에도 같이 적용되므로 G-11 경계 표 추가가 필요하다(v2에 이미 있음).
  - 덧붙임: X-3에서 B·C를 골라도 **음수 형식은 따로 정해야 한다**(값이 실제로 나오므로). X-3과 묶지 말고 음수 줄은 결정과 무관하게 #28에 넣기를 권한다.

## 4. 쟁점 X-1~X-4 최종 의견

| 쟁점 | 지지 | 한 줄 이유 |
|---|---|---|
| X-1 상대 표현 | **A(되묻기)** | Spring·#10 변경 0이고, C는 확정된 #10(허용 키 4개)을 다시 열어 #32를 키운다. |
| X-2 세율 | **A(display 추가)** — v1의 B에서 바꿈 | 빌더가 하나로 합의돼 비용이 형식 1개·키 1줄로 줄었고, B는 RAG 세율과 엔진 세율이 어긋날 위험을 남긴다. 조건: 형식을 "`taxRatePct`를 끝 0 제거해 `N.N%`"(예 `15.4%`)로 #28에 고정(`BigDecimal` 스케일 때문에 `15.40%`가 나오지 않게). |
| X-3 금액 경계 | **A(3줄 고정)** | `heldAssets` DB 기본값이 0이라(`schema.sql:76`) "약 0만원"이 데모에 바로 보이고, #28 "무엇을 왜"가 이미 "0원·1만원 미만 경계도 여기서 정한다"고 적어 범위 안이다. 음수 줄은 X-3과 별개로 필수(3번). |
| X-4 초과 시 F-3 호출 | **A(부르지 않음)** | 설명할 숫자가 없고 PENDING 행·ai 호출·테스트가 하나씩 준다. ai-server의 초과 EXPLAIN 가드(검사 4)는 방어로 남겨도 Spring 비용 0. |

## 5. 후속 작업 G-1~G-16 Issue 배치

moeun Issue 목록과 본문을 확인한 결과다. "확인 필요"였던 것 중 대부분은 이미 맞는 Issue가 있다(D-058: 새로 만들지 말고 합침).

| # | v2 배치 | 제공자 의견 | 근거 |
|---|---|---|---|
| G-1 | #11 | 수용 | |
| G-2 | 확인 필요 | **#35**(`[ai] planContext 기반 설명 모드(EXPLAIN)`) | #35 paths가 `schemas.py`·`agent.py`·`prompts.py`이고 선행이 #11 |
| G-3 | 확인 필요 | **#35**(규칙 1~9) + **#21**(D-10 조건 4개 정정) | #21 제목이 "대화 조건 4개로 축소(도구 스키마·프롬프트)" |
| G-4 | G-2와 같은 Issue | **#35** 수용. #35 paths `tests/test_explain.py`에 fixture 경로 `docs/api/examples/**` 읽기만 추가 | |
| G-5 | G-7과 같은 Issue | **수정: 빌더 테스트(키·형식·요구 키 불변식)는 빌더 Issue(G-8a 자리)로, `PlanContextView` 직렬화 비교만 G-7로** | 빌더가 G-7보다 먼저 생기므로 테스트도 그때 고정해야 #30·#32가 같은 키를 받는다 |
| G-6 | #11 | 수용 | |
| G-7 | 확인 필요(새 Issue 권장) | **새 A팀 Issue** `[calc] PlanContextProvider(C-1a)`. 선행 **#19·#29·#32**(+빌더 Issue). v2의 선행 "#28·#30·#32·G-12"에서 **#30을 빼고 #29·#19를 넣는다** | 같은 범위의 기존 Issue가 없다. #29는 #32의 선행이라 #29에 합치면 `CalcResultView`(#32)를 쓸 수 없어 순서가 꼬인다. Q1 서비스는 #29, plan 공개 조회는 #19 |
| G-8a | **#32** | **반대 → #28로 옮김(또는 #29)** | **#30은 #32를 선행으로 두지 않는다**(#30 선행: #17·#19·#27·#28·#29). "#32에서 처음 만들고 #30이 쓴다"면 #30이 먼저 끝날 때 맵을 따로 만들게 되어 빌더 하나 합의가 깨진다. #28은 #30·#32 둘 다의 선행이므로 #28 paths에 `calc/application/ResultDisplayBuilder.java`와 테스트를 더하고 "Formatter + 공유 display 맵 빌더"로 넓히는 것이 가장 싸다(규모 +0.5일). #28을 키우기 싫으면 #29(paths `calc/**`, 역시 #30·#32 선행)에 넣되 #29 선행에 #28 추가. 그리고 #32 본문 "display 맵 빌더"를 "공유 빌더 사용"으로 고친다 |
| G-8b | #28 | 수용. 음수 금액 줄은 X-3과 무관하게 넣음(3번) | |
| G-9 | 확인 필요(#41) + #12 | **수정: 리스너·트랜잭션(2-1)·실패 처리는 #41, F-3의 `findPlanRun`·`baseline_scenario` 저장·EXPLAIN 호출은 #43**. #12는 계약 문서 Issue라 구현 수용 기준을 넣을 곳이 아니다. #43 선행에 **G-7 새 Issue** 추가(지금 #43 선행은 #41·#29뿐이라 planContext 없이 시작하게 됨) | #43 본문 "planContext(T-003)를 만들어 ai-server를 mode=EXPLAIN으로 부른다" |
| G-10 | #32 | 수용 + #32 paths 설명에서 `CalcResultView·ScenarioResultView`를 `calc/web/**` 괄호 밖으로 옮기는 정정 포함 | |
| G-11 | 문서(+#10 본문) | 수용 | |
| G-12 | 확인 필요 | **#19**(`[plan] 계획 저장 서비스 …`) | #19 "다른 모듈이 쓸 공개 조회 서비스(현재 계획 조회)도 둔다", 수용 기준 "다른 회원의 plan_version ID When 조회하면 찾을 수 없다(memberId 조건)"가 `findVersion`과 같다. 수용 기준에 "버전 id로 조회 공개 API, 현재 계획의 기준 시나리오 포함(문자열)" 1줄만 추가 |
| G-13 | G-7과 같은 Issue | 수용(새 G-7 Issue paths에 `backend/.claude/rules/persistence.md` 추가). `modulith.md` 예외(2-1)는 #41 쪽 | |
| G-14 | #18 | 수용 | |
| G-15 | #12(+결과 화면 프론트) "A·프론트" | **수정: 팀은 B**. 404 통일은 **#43**(수용 기준에 "없는 calcRunId·CHAT 기록 calcRunId도 404 NOT_FOUND" 추가), `NOT_FOUND` ProblemDetail 처리는 **#74**(전역 오류 처리). X-4 호출 여부는 F-3을 부르는 **#54**(`[front] AI 설명 비동기 표시`, B) + 초과 안내 화면 **#49**(A). #12에는 F-3 계약 문장만 | |
| G-16 | 문서 + #11 | 수용 | |
| **G-17(새로)** | — | **#27**: `isAchieved=true` ⇒ `goalReachMonth` non-null·목표월 이하 불변식(3번) | |

### #30과 #32의 paths 겹침(참고)
#30 paths에 `calc/web/**`가 있고 #32도 `calc/web/**`라, moeun 규칙상 둘을 동시에 진행할 수 없다(루트 `CLAUDE.md` "paths가 겹치는 Issue는 동시에 하지 않는다"). 빌더를 #28로 빼면 두 Issue가 공유 코드 때문에 서로 기다릴 일은 없어진다. 이 계약 범위 밖이지만 task-planner에 전달할 가치가 있다.

## 오류 처리

- planContext는 내부 호출이라 HTTP 오류가 없다(`Optional.empty()`·예외). v2 C1a-10 그대로 수용.
- F-3 404: `findPlanRun`이 "없음·남의 것·PLAN 아님(CHAT 기록)" 모두 empty → #43 컨트롤러가 `NOT_FOUND` 예외 → #74 `@RestControllerAdvice`가 ProblemDetail `code=NOT_FOUND`. 한 경로라 일관된다.
- ai-server 400·422·502는 Spring에서 구분 없이 `FAILED`(#41 수용 기준 그대로). 추가 분기 없음.

## 구현 규모(v1 대비 변화)

| 작업 | v1 추정 | v2 추정 | 변화 이유 |
|---|---|---|---|
| 공유 빌더 + 추가 키 4개 | +0.25일 | +0.5일 | 요구 키 불변식 테스트(2-3), 빌더를 #28로 앞당기며 `CalcInput`/`CalcResult` 입력 테스트를 그곳에서 작성 |
| Formatter 경계(X-3 A + 음수 + X-2 A) | — | +0.25일 | 분기 4개, 테스트 6~8건 |
| `PlanContextProvider` 등(G-7) | 0.75일 | 0.75일 | 변화 없음(`findPlanRun`이 현재 계획 조회 1번 더) |
| plan `findVersion`(G-12, #19) | 0.1일 | 0.1일 | |
| **A팀 합계** | 약 1.5일 | **약 1.75일** | 백엔드 1명 3주 기준 감당 가능 |

리스너 트랜잭션 처리(2-1)는 B팀 chat(#41) 몫이라 위 합계에 넣지 않았다.

## 제공자 쪽에서 꼭 지켜야 할 것

1. **display 맵 빌더는 하나이고, #30·#32 둘 다보다 먼저 생긴다.** 왜: #30은 #32를 기다리지 않으므로 빌더가 #32에 있으면 결과 화면이 자기 맵을 만들게 되고, "화면 숫자 = AI 숫자 글자까지"(PR-04)를 코드가 보장하지 못한다.
2. **공개 API에 calc 하위 패키지 타입을 노출하지 않는다**(`CalcResultView`·`ScenarioResultView`는 루트). 왜: `modulith.md:12-15`, `ModularityTests`.
3. **calc는 plan 테이블을 직접 읽지 않는다.** 소유권은 `calc_run` 조회 → plan 공개 API(#19) 순서. 왜: `modulith.md:16`, `persistence.md:12`.
4. **QUESTION은 #29의 결과 조회 서비스를 재사용한다.** 왜: Q1(a~c) 재기록 규칙을 두 번 짜지 않기 위해.
5. **planContext는 저장하지 않는다**(ADR-002). 
6. **`isAchieved=true` ⇒ `goalReachMonth` 존재는 엔진(#27)이 보장한다.** 왜: ai-server가 이것을 요구 키로 검사하므로 어기면 설명이 502로 실패한다.

## 양보 가능한 것

- 빌더를 #28에 넣을지 #29에 넣을지(둘 다 #30·#32의 선행이면 됨).
- G-7을 새 Issue로 할지, 빌더와 함께 한 Issue로 묶을지.
- `PlanRunRef.baselineScenario`를 calc가 채우지 않고 chat이 F-3 요청 때 따로 정하는 방식(단 chat은 plan을 못 읽으므로 결국 calc 공개 API가 필요하다).
- X-2에서 B로 결정되면 그대로 따름(빌더·패턴에서 1줄 빼면 끝).
- 리스너 트랜잭션 처리 방식(2-1)의 구체 선택은 #41 담당 재량. "HTTP 호출 동안 트랜잭션 없음"만 지키면 된다.
- `ScenarioResult` 생성자 검사 대신 #27 테스트로만 불변식을 고정하는 것.
