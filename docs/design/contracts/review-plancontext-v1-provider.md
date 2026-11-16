# planContext 계약 v1 — 제공자(A팀 Spring: calc·plan·Formatter) 검토

> 검토자: contract-provider, 2026-11-16. `/negotiate-contract` 2단계 독립 검토. 대상 `plan-context-v1.md`(moeun #11).
> 근거로 읽은 것(moeun origin/develop `7cef22e`, 읽기만 함): `backend/CLAUDE.md` 모듈 표, `backend/.claude/rules/modulith.md`·`persistence.md`, `calc/*.java`(CalcInput, CalcResult, ScenarioResult, Assumptions, AppliedDataVersions, package-info), `plan/`·`chat/` `package-info.java`, `ModularityTests.java`, `schema.sql`, `db/erd.md` §4 Q1, `db/decision.md` ADR-002, moeun Issue #25·#28·#30·#32·#41·#49 본문, `internal-calc.md`(최종본), `b-team-contracts.md` F-3·A-0c, `decisions.md`(D-030·D-038·D-045·D-055·D-057).

```
판정: 수정하면 수용
```

큰 방향(calc가 만들고 chat은 싣기만 함, C2-6 display 재사용, raw 금액을 모델에 넘기지 않음, 버전 필드 없음)은 그대로 받는다. 다만 Spring 쪽에서 그대로 만들면 (1) 공개 API가 내부 패키지 타입을 노출하고, (2) display 맵을 세 군데(#30 결과 화면, #32 `/internal/calc`, planContext)에서 따로 만들게 되며, (3) EXPLAIN 경로에 필요한 plan 조회·소유권 확인·기준 시나리오 출처가 빠져 있다. 아래 수정이 들어가면 수용한다.

## 항목별 의견

- **[C1a-1 목적·범위] 수용** — 비교·차이를 `/internal/calc`에 두고 planContext는 계산 1건만 담는 경계가 맞다. calc 책임과 `CalcResult` 주석("내 계획 결과·비교·대화 재계산이 모두 이 형태", `CalcResult.java:9`)과 맞다.

- **[C1a-2 최상위 구조 / `result` = `CalcResultView` 재사용] 수정** — 재사용 자체는 찬성(DTO 하나, `monthlyPoints` 제거·`isAchieved` 키 고정이 C2-4에서 이미 정해짐). 그러나 초안은 `PlanContextView`(calc **루트**, 공개 API)의 필드 타입으로 `calc.web.CalcResultView`(calc **내부** 하위 패키지)를 쓴다. modulith 규칙상 루트만 공개 API이고 하위 패키지는 밖에서 접근할 수 없다(`modulith.md:12-15`). chat이 `planContext.result()`를 한 번이라도 참조하면 `ModularityTests.verifyModules()`가 실패하고, 참조하지 않더라도 공개 타입이 비공개 타입을 노출하는 구조가 된다. 또 #32 `paths`가 `calc/web/**`라 이 타입의 소유가 #32에 묶여 있다.
  - 수정안: `CalcResultView`·`ScenarioResultView`를 **calc 루트의 공개 record**로 둔다(`calc.CalcResultView`). `calc.CalcComparison`이 이미 루트에 있으므로(C2-3 구현 메모) 같은 자리다. #32 본문 `paths`에 `calc/CalcResultView.java`, `calc/ScenarioResultView.java`를 더하고 "`calc.web` 아래에 두지 않음"을 적는다. 계약 문구 "`calc.web.CalcResultView`" → "`calc.CalcResultView`(루트)". internal-calc C2-4의 같은 문구도 후속으로 맞춘다(동작 변화 없음, 위치만).
  - `calcRunId` 최상위 유지는 수용.

- **[C1a-3 `conditions`] 수정(출처 표기만)** — 6개 키 모두 수용. 다만 "출처" 열을 `plan_version.*`로 쓰면 구현자가 raw 컬럼(`savings_rate_input_pct`가 NULL일 수 있음, `schema.sql:78`)을 읽을 수 있다. 6개 값은 모두 **해석 뒤 `CalcInput`에 이미 있다**(`goalAmount`, `heldAssets`, `monthlySavingAmount`, `targetPeriodMonths`, `savingsRatePct`, `savingsRatioPct` — `CalcInput.java:22-30`).
  - 수정안: 출처 열을 "`CalcInput`(ConditionResolver 결과)"로 통일. 그러면 `conditions`는 `CalcInput`의 투영 하나로 끝나고, #32의 `conditions.current`(4키)와 같은 매퍼를 쓴다(키 2개만 더함).
  - D-045 때문에 `monthlySavingAmount`·`targetPeriodMonths`가 항상 non-null인 것도 수용. 단 `CalcInput`은 둘 다 nullable 타입(`Integer`, `Long`)이므로 DTO는 nullable 그대로 두고 null이면 `null` 직렬화(원칙 3).

- **[C1a-4 `result`] 수용** — C2-4 직렬화 표를 그대로 쓰고 `ALREADY_EXCEEDED`도 허용하는 것은 `CalcStatus`·`CalcResult`(scenarios 빈 목록, assumptions·dataVersions non-null, `CalcResult.java:34-41`)와 맞다. `dataVersions`를 보내되 모델에 안 넘기는 것도 수용.
  - 덧붙임: `baselineScenario`는 `calc_run`에 저장되지 않는다(`schema.sql:109-119`). 출처는 C1a-10 의견 참고.

- **[C1a-5 `assumptions` 위치(`result.assumptions`)] 수용** — `CalcResult.assumptions`가 이미 결과 안에 있으므로(`CalcResult.java:31`) 최상위로 꺼내면 오히려 Spring이 DTO를 하나 더 만든다. `result` 안에 두는 쪽이 구현 비용이 가장 낮다(R-5 a 찬성).
  - `taxRatePct` display 없음 찬성(R-3).
  - `sp500BaseDate`는 `LocalDate`, display는 월만 → `YearMonth.from(date)` 한 줄. 비용 없음.

- **[C1a-6 display 키(추가 4개)] 수용 + 구현 위치 수정** — 추가 4개(`calcStartMonth`, `conditions.heldAssets`, `assumptions.savingsRateBaseMonth`, `assumptions.sp500BaseDate`)는 #28 Formatter가 이미 가진 두 형식(금액 `약 N만원`, 시점 `YYYY년 M월`)만 쓴다. **Formatter 자체 변경은 0**, 맵 빌더에 키 4줄 + 테스트 4건, 반나절 미만. 비용 문제 없다.
  - 진짜 비용은 키 4개가 아니라 **display 맵 빌더가 몇 개냐**다. 지금 Issue대로면 #30(결과 보기 API, `calc/web/**`), #32(`/internal/calc`, `calc/web/**` "display 맵 빌더"), planContext가 각각 맵을 만든다. 같은 값을 세 곳에서 만들면 "결과 화면 숫자와 AI 숫자가 글자까지 같다"(C1a-6 마지막 문단, PR-04)를 코드가 보장하지 못한다.
  - 수정안: **`calc.application.ResultDisplayBuilder` 하나**(입력: `CalcInput` + `CalcResult` + 접두어 `""`/`"current."`/`"changed."`)를 두고 셋이 같이 쓴다. 이 빌더를 #32에서 처음 만들고(#32 본문의 "display 맵 빌더 약 0.5일"이 이것), planContext 추가 키 4개도 이 빌더에 넣어 #30 결과 화면도 같은 키를 받게 한다(#49 가정 보기 "데이터 기준월"이 바로 `assumptions.sp500BaseDate`). C2-6의 `conditions.<side>.*` 순서(`conditions.current.monthlySavingAmount`)와 planContext의 `conditions.*`가 접두어 위치가 다르다(`<side>`가 `conditions.` 뒤). 빌더 인자로 "결과 접두어"와 "조건 접두어"를 따로 받으면 된다 — 계약은 그대로 둬도 된다.
  - G-8을 #28에 두는 것은 **반대**: #28 `paths`는 `Formatter.java`·`FormatterTest.java`뿐이고 키 규칙은 Formatter가 아니라 맵 빌더의 일이다. G-8의 "키 4개"는 빌더 Issue(#32 또는 G-7)로, "R-7 0원 형식"만 #28로 보낸다.

- **[C1a-7 넣지 않는 필드] 수용** — `PlanContextView`에 계정 필드가 아예 없으므로 Spring 쪽은 타입으로 보장된다. `goalCustomName`·`goalType` 제외 찬성(R-2). `goalType`은 `CalcInput`에 없어(`CalcInput.java:22-30`) 넣으려면 plan 공개 API에서 따로 읽어야 하므로 v1 제외가 더 싸다.

- **[C1a-8 ai-server 처리] 수용(제공자 영향 없음)** — 소비자 쪽 규칙. 제공자 관점에서 `CONTEXT_DISPLAY_MISSING` → 502 → Spring `FAILED`, FastAPI 기본 422 → Spring 4xx 일괄 `FAILED`는 #41 수용 기준("4xx/5xx이면 FAILED·FAILURE")과 같아 Spring 추가 분기가 필요 없다. G-6은 선택으로 둔다.

- **[C1a-9 camelCase] 수용** — 원칙 그대로. 근거 보강: Spring Boot 4는 Jackson 3이고, record의 `boolean isAchieved` 컴포넌트는 접근자 `isAchieved()`가 is-getter 규칙과 겹쳐 `achieved`로 나갈 수 있다. 그래서 `@JsonProperty("isAchieved")`를 View DTO에 두는 C2-4 규칙이 맞다(도메인 `ScenarioResult`/`Assumptions`를 직접 직렬화 금지). G-5 직렬화 테스트가 이를 고정한다.

- **[C1a-10 만드는 곳·의존 방향] 수정** — 
  - **의존 방향·순환: 문제 없음.** `plan {}` ← `calc {plan, refdata}` ← `chat {calc, rag}`(`plan/package-info.java:8`, `calc/package-info.java:8`, `chat/package-info.java:6`). chat → calc 루트 `PlanContextQuery`, calc → plan 루트 공개 API, plan은 아무것도 부르지 않는다. 역방향(plan → calc)은 기존 `PlanChanged` 이벤트뿐(`modulith.md:34`). 새 순환 없음. `chat`이 `plan`을 직접 못 읽으므로 calc에 두는 결정이 맞다.
  - **빠진 것 1 — EXPLAIN은 "현재" 계획이 아닌 버전을 읽는다.** `findForCalcRun`은 `calc_run.plan_version_id`의 버전을 읽어야 하는데, 초안은 `plan.CurrentPlanQuery`(현재 버전만, C2-8)만 적었다. 수정안: plan 공개 API에 **`findVersion(long memberId, long planVersionId)`** 1개를 더한다(같은 `CurrentPlanQuery` 또는 `PlanVersionQuery`). 이 메서드가 `member_id` 조건으로 조회하므로 **소유권 확인도 여기서 끝난다**.
  - **빠진 것 2 — 소유권 확인 방법.** 초안 "`calc_run → plan_version.member_id = memberId`를 확인"을 calc 리포지토리의 JOIN으로 구현하면 calc가 plan의 테이블을 직접 읽어 "다른 모듈의 엔티티와 리포지토리를 쓰지 않는다"(`modulith.md:16`)를 어긴다. `calc_run`에는 `member_id`가 없다(`schema.sql:109-119`). 수정안(2단계): ① calc 리포지토리 `findByIdAndRunType(calcRunId, PLAN)` ② plan 공개 API `findVersion(memberId, run.planVersionId)` → 비면 empty. 쿼리 2번(둘 다 PK)이라 성능 문제 없다. `persistence.md:47`("리포지토리 메서드는 memberId 조건")에는 calc_run이 회원 키가 없는 예외로 한 줄 적어 둔다.
  - **빠진 것 3 — F-3 요청 시점 검사.** F-3은 **요청 시점에** "그 회원의 PLAN 기록이 아니면 404"(`b-team-contracts.md:191`)이고, `EXPLANATION` PENDING 행을 넣을 때 `baseline_scenario NOT NULL`이 필요하다(`schema.sql:191` `ck_cm_explain`). 이때 무거운 `findForCalcRun`(재계산 + Formatter)을 부르면 낭비다. 수정안: calc 루트에 가벼운 조회 **`findPlanRun(long memberId, long calcRunId): Optional<PlanRunRef(calcRunId, planVersionId, baselineScenario)>`**를 같이 공개한다(재계산 없음). chat은 F-3에서 이것으로 404 판단과 `baseline_scenario` 저장을 하고, 리스너에서 `findForCalcRun`을 부른다.
  - **빠진 것 4 — `baselineScenario` 출처.** `calc_run`에 저장되지 않으므로 출처를 정해야 한다. 수정안: `findForCalcRun(memberId, calcRunId, Scenario baselineScenario)` — chat이 F-3 때 `chat_message.baseline_scenario`에 저장한 값을 그대로 넘긴다. 그래야 `ChatRequest.baselineScenario == planContext.result.baselineScenario`(C1a-10 끝)가 F-3 이후 기준 시나리오를 바꿔도 깨지지 않는다. QUESTION은 `plan.baseline_scenario`(현재).
  - **QUESTION "기록 없으면 계산하고 PLAN 1행 기록"**: 수용하되 조건 — **결과 화면의 Q1(a)~(c)(`db/erd.md` §4 Q1) 서비스를 그대로 호출**하고 planContext용으로 따로 만들지 않는다. 이 서비스는 #30/결과 조회가 어차피 만든다. 별도 구현이면 "최신 기록이 활성 버전과 다르면 재기록"(Q1-c)까지 두 번 짜게 된다. `PlanChanged` 리스너와 동시에 PLAN 행이 2개 생길 수 있으나 `ix_calc_run_latest`가 최신 1행을 고르므로 무해하다(멱등 키 없음은 C2-7과 같은 방침).
  - **이름**: QUESTION 경로가 `calc_run`을 INSERT하므로 `...Query`는 오해를 부른다. `PlanContextProvider`(또는 `PlanContextService`)로 바꾸기를 권한다. 양보 가능.
  - **트랜잭션**: `@ApplicationModuleListener`는 새 트랜잭션에서 돈다(`modulith.md:24`). chat 리스너가 트랜잭션을 연 채 ai-server 30초 호출을 하면 커넥션을 오래 잡는다. calc 쪽은 `PlanContextProvider` 메서드에 자체 `@Transactional`을 두고, chat은 "planContext 만들기 → (트랜잭션 밖) HTTP 호출 → 결과 저장(짧은 트랜잭션)" 순서로 하도록 #41/G-9에 한 줄 적어 달라.
  - **데이터 버전(EXPLAIN = 기록의 버전)**: 수용. Q1 주석이 이미 "기록된 버전의 기준 데이터를 PK 범위로 읽어 계산"(`erd.md:479`)이라 refdata에 "버전 id로 읽기"는 결과 화면 때문에 어차피 필요하다. 추가 비용 없음.
  - ai-server의 EXPLAIN `calcRunId` 불일치 400 검사: 수용(Spring은 같은 값을 넣으므로 정상 경로에서 안 생김).

- **[C1a-11 특수한 경우] 수용** — 계획 없음 → `null`, ETF 0% → AVG만, 초과 → `scenarios: []`. 모두 `CalcResult` 불변식과 같다. 단 **초과 계획에서 `display.conditions.heldAssets`가 들어간다**는 점은 짚어 둔다: 모델은 `goalAmount`와 `conditions.heldAssets` 두 display를 나란히 받으므로 "초과 금액을 말하지 않음"은 프롬프트 규칙 (2)(빼기 금지)에만 기대게 된다. 제공자는 그대로 둬도 괜찮다고 보며(두 값 각각은 사용자가 입력한 값), 막고 싶으면 초과일 때 `conditions.heldAssets` 키를 빼는 것이 빌더 한 줄이다(소비자 판단).

- **[C1a-12 크기·버전] 수용** — `contextVersion` 없음 찬성(R-5 b). 같은 repo·같은 Compose 배포이고 G-5/G-4 fixture 테스트가 깨지는 변경을 잡는다.

- **[C1a-13 예시 JSON] 수정(작음)** — 숫자 정합성 확인함: A-1·A-2·A-3의 `principal = 5,000,000 + 300,000 × 36 = 15,800,000`, `afterTaxAsset = principal + afterTaxGain`, `gapToGoal = afterTaxAsset − goalAmount` 모두 맞고, display도 원 → 만원 반올림과 맞다(예: A-2 `-4,045,588` → `-약 405만원 미달`). 다만 G-5는 **엔진 결과가 아니라 손으로 만든 `CalcResult`·`CalcInput`을 넣어 직렬화·display를 비교하는 단위 테스트**여야 한다(엔진 값이 fixture와 다를 것이므로). G-5 문구를 "부록 A의 raw 값으로 만든 `CalcInput`/`CalcResult`를 빌더에 넣은 결과가 부록 A JSON과 같다"로 고쳐 달라.
  - fixture 위치(G-1): #10과 같은 결론을 원한다. 제공자는 **공유 파일 `docs/api/examples/plan-context/*.json`**을 선호(backend 테스트가 `../docs/...`를 읽음). 복사본 두 벌은 한 사람이 양쪽을 맞춰야 해서 실수가 난다.

- **[C1a-14 코드 차이] 수정** — D-6·D-7 보강: D-6에 "`CalcResultView`·`ScenarioResultView`를 calc 루트로", "`ResultDisplayBuilder` 공유", "`findPlanRun` 경량 조회" 추가. D-7에 "현재 계획 + **버전 id로 조회**(소유권 포함) 2개 메서드".

- **[C1a-15 수용 기준 대응] 수용** — 5개 모두 대응된다. 제공자 쪽 테스트로 옮길 것은 1(타입에 계정 필드 없음, 직렬화 결과에 `memberId` 키 없음), 4(빌더 키·형식), 5(camelCase, `isAchieved`).

## 검토 요청(R-1~R-7)에 대한 제공자 의견

| ID | 제공자 의견 | 이유 |
|---|---|---|
| R-1 (초과 계획도 F-3 부름?) | **부르지 않는 쪽을 권함.** 단 계약에 두 경우 형식이 있는 것은 그대로 둔다 | 결과 화면이 이미 문구표 초과 안내를 보이고(#49), 설명할 숫자가 없다. 부르지 않으면 ai 호출 1회와 PENDING 행이 줄고 테스트 1건이 준다. QUESTION에서는 초과 planContext가 올 수 있으므로 형식은 필요하다. 결정은 F-3/#12에서 |
| R-2 (goalType·goalCustomName) | **둘 다 넣지 않음 찬성** | 둘 다 `CalcInput`에 없어 넣으면 plan 조회·DTO가 늘고, `goalCustomName`은 자유 글이라 D-030 위험 |
| R-3 (세율) | **display 없음 찬성** | CP-04·C2-6·#28에 형식이 없다. 넣으면 #28 수용 기준 추가. 단 결과 화면 가정 보기(FR-RES-06)가 세율을 보여야 한다면 그때 빌더에 같이 넣는다(같은 키를 planContext도 받게 됨) |
| R-4 (planContext vs `/internal/calc` 데이터 버전 차이) | **받아들임** | QUESTION은 Q1-c 때문에 활성 버전으로 재기록되므로 `/internal/calc` `current`와 같다. 차이는 "오래된 EXPLAIN 기록"에서만 생기고 해커톤 중 재적재가 없으면 생기지 않는다(D-045). #10을 다시 열 이유 없음 |
| R-5 (a) assumptions를 result 안 (b) 버전 필드 없음 | **(a)(b) 모두 찬성** | (a) `CalcResult` 구조 그대로라 DTO가 하나 준다. (b) C1a-12 이유에 동의 |
| R-6 (excludedItems 문구) | **코드만 넘김 찬성(Spring은 문구 문자열을 보내지 않음)** | Spring이 문구까지 보내면 planContext에 문구표 의존이 생기고 display와 성격이 다른 맵이 하나 더 는다. 문구 글자 그대로가 필요하면 ai-server가 `copy.ko.yml`을 읽는 쪽이 맞다(CP-05 "AI 서버가 함께 읽음") — 소비자 판단 |
| R-7 (금액 정확히 0원) | **`0원` 찬성 + 범위 확장 요청** | `heldAssets` 기본값이 0이라(`schema.sql:76` `DEFAULT 0`) `conditions.heldAssets`가 `약 0만원`이 되는 일이 데모에서 흔하다. 또 0 < x < 5,000원 금액(짧은 기간·저금리의 `afterTaxGain`)도 `약 0만원`이 된다. #28에 일반 금액 경계 2줄을 함께 넣기를 제안: **정확히 0원 → `0원`, 0원 초과 1만원 미만으로 반올림되는 금액 → `1만원 미만`**(D-055의 차이·목표 대비 경계와 같은 결). 결정 필요 시 Q-번호로 |

## 오류 처리

- planContext는 Spring 내부 호출이라 HTTP 오류 형식이 없다. `Optional.empty()`(계획 없음/기록 없음)와 예외(엔진·기준 데이터 오류)만 있다. chat 리스너는 예외를 잡아 메시지를 `FAILED`·`FAILURE`로 바꾼다(FR-AI-04, #41 수용 기준과 같음). 계약에 이 한 줄("planContext 생성 실패 → ai-server를 부르지 않고 `FAILED`")을 C1a-10에 더해 달라.
- F-3의 404는 이 계약 밖(#12)이지만, **"없는 기록"과 "남의 기록"을 같은 404 `NOT_FOUND`로** 내야 한다(id 추측 방지). `findPlanRun`이 둘 다 empty를 돌려주므로 ProblemDetail 전역 처리(`config` `@RestControllerAdvice`, internal-calc C3-1)에서 일관되게 낼 수 있다.
- ai-server 쪽 422/502는 Spring에서 구분하지 않고 `FAILED`로 기록 — 지금 #41 기준과 같아 추가 분기 없음.

## 구현 규모(제공자 추정, 백엔드 1명 기준)

| 작업 | 새로 만듦/재사용 | 규모 |
|---|---|---|
| `CalcResultView`·`ScenarioResultView`(루트) | #32와 공유, 위치만 이동 | 0 (이미 #32 범위) |
| `ResultDisplayBuilder`(공유) + 추가 키 4개 | #32의 맵 빌더를 공유형으로, 키 4줄 | +0.25일 |
| `PlanContextView`, `ConditionsView`(6키) | 새 record 2개 | 0.25일 |
| `PlanContextProvider`(2메서드) + `findPlanRun` | 새로. Q1 서비스·ConditionResolver·CalcEngine 재사용 | 0.5일 |
| plan 공개 API `findVersion(memberId, versionId)` | `CurrentPlanQuery`에 1메서드 | 0.1일 |
| 테스트: 직렬화 fixture(G-5), 소유권(남의 기록 empty), 계획 없음 null, ETF 0%·초과 | 새로 | 0.5일 |
| **합계** | | **약 1.5일** (#28·#30·#32 선행 완료 가정. 빌더를 공유하지 않으면 +0.5일) |

## 제공자 쪽에서 꼭 지켜야 할 것

1. **공개 API에 내부 타입을 노출하지 않는다** — `PlanContextView`가 담는 `CalcResultView`·`ScenarioResultView`는 calc 루트에 둔다. 왜: 하위 패키지는 비공개(`modulith.md:12`)이고, chat이 참조하는 순간 `ModularityTests`가 깨진다.
2. **calc가 plan 테이블을 직접 JOIN하지 않는다** — 소유권은 `calc_run` 조회 → plan 공개 API `findVersion(memberId, versionId)` 2단계. 왜: `modulith.md:16`, `persistence.md:47`.
3. **display 맵 빌더는 하나** — 결과 화면(#30)·`/internal/calc`(#32)·planContext가 같은 빌더와 같은 `Formatter`를 쓴다. 왜: 계약이 약속한 "화면 숫자 = AI 숫자 글자까지"(PR-04)를 코드로 보장하는 유일한 방법이고, 1인 백엔드에서 세 벌 유지는 비싸다.
4. **QUESTION 경로는 결과 화면 Q1(a~c) 서비스를 재사용**한다. 왜: 기록·재기록 규칙을 두 번 구현하지 않기 위해(ADR-002 재계산 원칙과 같은 경로).
5. **EXPLAIN의 `baselineScenario`는 chat이 F-3 때 저장한 값을 인자로 받는다.** 왜: `calc_run`에 기준 시나리오가 없고(`schema.sql:109-119`), `ChatRequest.baselineScenario == planContext.result.baselineScenario`를 보장해야 한다.
6. 결과는 저장하지 않고 호출마다 만든다(ADR-002 §2-2). planContext를 `chat_message`에 저장하자는 변경이 나오면 반대한다.

## 양보 가능한 것

- 인터페이스 이름(`PlanContextQuery` 유지 가능), 메서드 시그니처 세부.
- `findPlanRun`을 따로 두지 않고 chat이 F-3 때 `findForCalcRun`을 그대로 불러 404 판단(재계산 1회 낭비를 감수)하는 것.
- 초과 계획 display에 `conditions.heldAssets` 포함 여부(소비자 판단).
- R-7의 "1만원 미만" 확장은 Q-번호로 미뤄도 됨(`0원`만 먼저 #28에).
- fixture를 공유 파일 대신 두 벌 복사로 하는 것(단 README에 동시 수정 규칙 명시).
- G-7을 새 Issue로 둘지 #32에 합칠지(#32가 이미 커서 새 Issue 권장이나, D-058에 따라 합치는 판단이면 따름. 선행: #28·#30·#32, 그리고 plan 공개 API Issue).
