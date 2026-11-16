# planContext 계약 합의안 (moeun #11)

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 4단계(재검토 반영) 마무리, 5단계(사람에게 넘기기) 준비.
> - 계약 본문: `plan-context-v3.md` (쟁점은 본문에 `[X-n 임시 A]`와 `⟵ X-n 결정 시 바꿀 줄`로 표시)
> - 입력: `plan-context-v1.md`, `review-plancontext-v1-provider.md`(A팀), `review-plancontext-v1-consumer.md`(B팀), `plan-context-v2.md`, `review-plancontext-v2-provider.md`(A팀 재검토), `review-plancontext-v2-consumer.md`(B팀 재검토)
> - **에이전트는 결정하지 않았다.** 아래 "사람이 정할 쟁점" 4개만 답해 주면 v3을 최종본으로 확정할 수 있다. 재검토는 이번이 마지막이다(더 반복하지 않음).

## 합의된 것 (그대로 구현 가능) — 55항목

전체 표는 `plan-context-v3.md` "합의 목록". 묶어서 요약한다.

| 묶음 | 내용 | 근거 |
|---|---|---|
| 원칙·모양 | 숫자는 Spring만 만들고 모델은 `display`만 인용, raw 금액 미전달. 최상위 `calcRunId`·`conditions`·`result`·`display`. `result`는 `/internal/calc` `current`와 같은 DTO(`calc.CalcResultView`, calc 루트). camelCase, `@JsonProperty("isAchieved")`. 버전 필드 없음. 계정 식별 정보·`goalType`·`goalCustomName`·`monthlyPoints` 없음 | 양쪽 (합의 1~8, 14, 21, 37) |
| `conditions` | 출처 `CalcInput` 6키, 와이어 유지·모델 미전달·ai-server 선택 필드 | 제공자 (5) |
| 가정 문장 | Spring은 `excludedItems`·`scenarioMethod` 코드만, ai-server가 문구표 문장(`excludedNotes`, `scenarioMethodNote`)으로 바꿔 넘김. 문구표 키 `chat.noPlan`·`chat.alreadyExceeded`·`excluded.<CODE>`·`scenarioMethod.<CODE>`(TBD-01 전 임시 문장) | 소비자 (9, 36) |
| display | internal-calc C2-6 재사용 + 추가 키 4개. **`<S>.goalReachMonth`는 `isAchieved=true`이고 non-null일 때만**. 음수 금액 `-약 N만원`/`-1만원 미만`(X-3과 무관). `goalAmount` 이름 겹침 허용 | 양쪽 (11~13, 42, 45) |
| 빌더 | `ResultDisplayBuilder` 하나를 결과 화면(#30)·`/internal/calc`(#32)·planContext가 공유. **#28에서 만들고**(불가 시 #29 + 선행 #28) 빌더 테스트(요구 키 불변식 포함)도 함께 | 제공자 (10, 43, 44) |
| ai-server 받기·검사 | 필수/선택 목록, `extra` 기본(ignore), display 필터(패턴 + 문자열), 검사 순서 1~6(422 / EXPLAIN null·불일치 400 / 초과 EXPLAIN은 LLM 없이 고정 문장 / 요구 키 누락 502 `CONTEXT_DISPLAY_MISSING`). 422는 FastAPI 기본 본문. planContext 본문 로그 금지 | 소비자 (15~20, 30, 35) |
| 프롬프트 | 규칙 1~9, 규칙별 Issue(#35/#21/#23), `prompts.py` 순서 #21→#22→#23→#35, 수동 평가 3~5건 | 소비자 (41, 53) |
| Spring 생성 | `calc.PlanContextProvider` 3메서드(`findPlanRun`, `findForCalcRun(…, baselineScenario)`, `findForCurrentPlan`). 소유권 2단계(JOIN 금지), plan 공개 API `findVersion` + 기준 시나리오는 문자열로 받아 calc가 변환. QUESTION은 #29 Q1 서비스 재사용. 생성 실패 → ai-server 미호출 `FAILED`. F-3 404는 없는·남의·CHAT 기록 모두 같음 | 제공자 (22~27, 29, 31~33, 47) |
| 트랜잭션 | ai-server 호출 리스너는 트랜잭션 없이 돈다: `@ApplicationModuleListener`가 전파 속성을 받으면 `NOT_SUPPORTED`, 아니면 `@Async @TransactionalEventListener` + `TransactionTemplate`. `modulith.md`에 예외 1줄. **전파 속성 지원 여부는 아직 확인하지 않음**(#41 착수 시 확인) | 제공자 (28, 48) |
| 엔진 불변식 | `isAchieved=true` ⇒ `goalReachMonth` non-null·목표월 이하(#27) | 제공자 (46) |
| fixture | 공유 위치 `docs/api/examples/plan-context/` 14개. `plan-context-*`는 객체만(테스트 헬퍼 `make_request`가 감쌈), `chat-request-*`는 전체 JSON(A-10 포함 줄임 없음), `model-input-basic.json`은 문구 두 키 없이(테스트가 `COPY`로 채움). Spring/ai-server 사용 열. G-5a(빌더)·G-5b(직렬화), 숫자는 `BigDecimal` 스케일 무시 비교 | 양쪽 (38, 39, 49~52) |
| Issue 배치 | G-7은 새 A팀 Issue, 나머지는 모두 기존 Issue에 합침(아래 "후속 작업") | 양쪽 (54, 55) |

**쟁점 후보였지만 합의로 처리한 것** (사람이 보고 이견이 있으면 말해 주면 된다)
- **G-7 Issue 배치 충돌**: 소비자는 `PlanContextProvider`를 #29에 합치자고 했고, 제공자는 새 A팀 Issue를 원했다. calc는 A팀 영역이라 **제공자안을 채택**했다. 이유: #29는 #32의 선행인데 G-7은 #32의 `CalcResultView`를 쓰므로, #29에 넣으면 #29와 #32가 서로를 기다린다. 같은 범위의 기존 Issue도 없다(D-058 조건 충족). 소비자는 "합칠지는 A팀 판단"이라고 했으므로 반대가 아니다.
- **`goalReachMonth` 방출 규칙**: 소비자의 유일한 반대였다. 엔진 정의("처음 닿은 달")와 달성 판정("목표월 기준")이 달라 미달인데 도달 달이 나갈 수 있어서다. 빌더 한 줄 조건이고 제공자 불변식(G-17)과 부딪히지 않아 합의로 처리했다.
- **음수 금액 형식**: v2에서는 X-3에 묶였지만, 값이 실제로 나오므로 X-3을 무엇으로 정하든 필요하다(제공자). 소비자도 수용했다. X-3과 분리해 합의로 옮겼다.
- **와이어 `conditions`**: 소비자는 "X-1이 A로 확정되면 빼도 된다(선택)"고 했지만 요구하지 않았다. 비용이 작아 유지한다.

## 사람이 정할 쟁점

네 쟁점 모두 **양쪽 팀과 기획이 A를 지지한다.** 그래도 사람에게 올리는 이유는 decisions.md에 없는 **새 정책**(대화 행동, 금융 표시, D-055 범위 확장, 화면 정책)이라서다. 넷 다 **#11 머지를 막지 않는다.** v3 본문에는 A가 임시로 적혀 있고, 다르게 정하면 `⟵ X-n 결정 시 바꿀 줄` 표시만 바꾼다.

### X-1. 상대 표현("월 10만원 더")을 어떻게 recalculate 인자로 만드는가
- **문제**: 모델에는 `conditions.monthlySavingAmount: "약 30만원"`만 있다. "10만원 더"를 처리하려면 반올림된 문자열에서 덧셈해야 하고, 이것은 LLM 계산(NFR-INT-01)이다.
- **제공자 의견**: A. Spring·#10 변경이 0이고, C는 확정된 #10(허용 키 4개)을 다시 열어 #32를 키운다.
- **소비자 의견**: A. 조건: 월 저축액뿐 아니라 네 조건(월 저축액·비중·적금 금리·기한) 모두의 "더/덜/늘리면/줄이면"에 적용하고, 수용 기준은 #21 "모호한 발화는 되묻는다"에 사례로 넣는다. B는 raw 전달이라 반대, C는 해커톤 뒤 후보.
- **기획 의견**: A. 프롬프트 한 줄로 원칙 1을 지키고 확정 계약을 다시 열지 않는다.
- **선택지**
  - A) 되묻기: 상대 표현이면 계산하지 않고 `CLARIFY`로 절대값을 되묻는다(지금 값은 display로 인용). (영향: 프롬프트 규칙 7 + #21 사례 1줄. 대화가 한 턴 늘어남)
  - B) raw 4개 전달: 바꿀 수 있는 조건의 raw 값을 "인자 전용"으로 모델에 넣고 덧셈은 모델이 한다. (영향: Spring 변경 없음. 원칙 1의 예외가 생기고 덧셈 실수를 막을 장치가 없음)
  - C) 증감 인자: 도구에 `monthlySavingAmountDelta` 같은 키를 두고 Spring이 더한다. (영향: 계산이 코드로 가 원칙에 가장 맞지만 #10 C2-2를 재협상, #21·#23·#32 범위 증가)
- **추천: A.** 3주 안에서 가장 작은 변경으로 "숫자는 코드가 만든다"를 지킨다. C는 해커톤 뒤 개선 후보로 남긴다.

### X-2. 세율을 모델이 말해도 되는가
- **문제**: "세금 얼마 떼요?"는 첫 질문 후보다. display가 없으면 모델이 기억으로 15.4% 또는 22%를 말할 수 있다. 세율 표시 형식은 CP-04·C2-6에 없다.
- **제공자 의견**: A(v1의 B에서 바꿈). 빌더가 하나로 합의돼 비용이 형식 1개·키 1줄로 줄었고, B는 RAG 세율과 엔진 세율이 어긋날 위험이 남는다. **조건: 형식은 `taxRatePct`의 끝 0을 제거한 `N.N%`**(예 `15.4%`, `BigDecimal` 스케일 때문에 `15.40%`가 나오지 않게)로 #28에 고정.
- **소비자 의견**: A. 안 넣으면 숫자 출처가 모델 기억이 된다. B로 가면 규칙 8의 B 문장이 필수이고 RAG 세율과 엔진 세율이 같아야 하므로 finance-domain-reviewer 확인을 권한다.
- **기획 의견**: A. 엔진이 실제로 쓴 세율 하나만 말하게 되어 원칙 1에 가장 맞다. 금리 형식(`연 N.NN%`)을 계약에서 더한 선례가 있다. 다만 **금융 표현이 바뀌는 것이라 finance-domain-reviewer 확인을 권한다**(예: "15.4%"만 말해도 되는지, 비과세·분리과세 안내가 필요한지).
- **선택지**
  - A) display 추가: `assumptions.taxRatePct: "15.4%"`를 빌더·허용 패턴·요구 키에 더하고 모델은 이 값만 인용. (영향: #28 형식 1줄(`N.N%`, 끝 0 제거), 빌더 1줄, ai-server 패턴 1개. 결과 화면(#30)도 같은 키를 받음)
  - B) 숫자 금지: display 없음. 세율 숫자는 말하지 않고 세금 질문은 `search_documents` 결과만 인용. (영향: Spring 변경 없음. RAG 자료 세율이 엔진과 다르면 화면과 설명이 어긋남. 부록 A의 `assumptions.taxRatePct` 줄 삭제)
- **추천: A**, 단 finance-domain-reviewer 확인 뒤 확정.

### X-3. 일반 금액의 0원·1만원 미만 표기 (D-055 확장)
- **문제**: D-055는 차이·목표 대비 경계만 정했다. 일반 금액은 `heldAssets=0`(DB 기본값 0, 데모에서 흔함)이면 `약 0만원`, 5,000원 미만 이득도 `약 0만원`이 된다. (음수 금액은 X-3과 분리해 합의했다.)
- **제공자 의견**: A. `heldAssets` 기본값이 0이라 "약 0만원"이 데모에 바로 보이고, #28 범위 문장("0원·1만원 미만 경계도 여기서 정한다") 안이다.
- **소비자 의견**: A. 형식만 정해지면 되고, D-055 경계와 같은 결이라 모델이 새 규칙을 배울 일이 없다. fixture A-7의 두 값이 이 결정에 달려 있다.
- **기획 의견**: A. 양쪽이 같은 형식을 냈다. 다만 D-055의 범위를 일반 금액으로 넓히는 표시 정책이라 사람이 확인한다.
- **선택지**
  - A) 경계 2줄 고정: 정확히 0원 → `0원`, 0원이 아니지만 0만원으로 반올림 → `1만원 미만`. (영향: #28 수용 기준 2줄. 빌더 공유라 `/internal/calc` C2-6에도 같은 규칙, internal-calc 경계 표 추가(G-11))
  - B) 0원만: `0원`만 지금 고정. (영향: 소액 이득은 `약 0만원`으로 남음. A-7의 `AVG.afterTaxGain`이 `"약 0만원"`)
  - C) 그대로: `약 0만원` 허용. (영향: 형식 변경 없음. 데모에서 "보유 자산 약 0만원"이 보임. A-7 두 값 모두 `"약 0만원"`)
- **추천: A.**

### X-4. 이미 목표 초과 계획에도 결과 화면이 F-3(설명 요청)을 부르는가
- **문제**: FR-RES-01은 "계산 대신 초과 안내"만 정했고 AI 설명을 부를지는 결정에 없다. 화면 정책이다.
- **제공자 의견**: A. 설명할 숫자가 없고 PENDING 행·ai 호출·테스트가 하나씩 준다. ai-server의 초과 EXPLAIN 가드는 방어로 남겨도 Spring 비용 0.
- **소비자 의견**: A. 같은 문장을 두 번 보일 이유가 없다. 호출 주체는 B팀 프론트(#54)라 그쪽 수용 기준에 한 줄 필요.
- **기획 의견**: A. 계약 본문은 어느 쪽이든 그대로다(초과 planContext는 QUESTION에서 필요하고, ai-server 검사 4가 B에서도 LLM 호출을 막는다).
- **선택지**
  - A) 부르지 않음: 결과 화면은 FR-RES-01 문구표 안내만. (영향: #54·#49 수용 기준 1줄씩, #12 계약 문장 1줄. 대화창에 첫 설명 메시지가 없음)
  - B) 부름: F-3을 부르고 ai-server가 LLM 없이 `chat.alreadyExceeded`로 즉시 답함. (영향: 대화창에 화면 안내와 같은 문장이 한 번 더 뜸. #54·#43 테스트 1건 증가)
- **추천: A.**

## 후속 작업

> D-058: 각 moeun Issue **본문(수용 기준·변경 범위·선행)**에 반영한다. 댓글로 덧붙이지 않는다. 새 Issue는 G-7(+G-5b, G-13 포함) 하나뿐이다.
> 번호 출처: 양쪽 재검토자가 moeun Issue를 조회한 결과. #74는 2026-11-16 `gh api`로 확인함: closed(not_planned), #17에 합쳐짐 → G-15b는 #17.

| G-번호 | 내용 | 팀 | 대상 moeun Issue | 선행 변경 |
|---|---|---|---|---|
| G-1 | 최종본을 `docs/api/plan-context.md`·`ai-server/README.md`로, fixture 14개(A-10 전체 JSON, model-input 두 키 제외), 422 예외 문장(G-6 흡수) | 공통 | #11 | paths에 `docs/api/examples/**` |
| G-2 | `PlanContext` 모델, display 필터·패턴, `build_messages`, `run()` 검사 2~5, 로그 금지 | B | #35 | 선행 #11·#21에 **#22·#23·#18 추가**. paths에 `tests/test_plan_context.py`·fixture 헬퍼 |
| G-3 | 프롬프트 규칙 1·2·3·5·6·8·9 / 7(X-1) / 4 | B | #35 / #21 / #23 | D-10(조건 7→4)은 #21 기존 범위라 제외. #35 선행에 `prompts.py` 순서 #21→#22→#23→#35 |
| G-4 | fixture 테스트, `make_request` 헬퍼, 수동 평가 3~5건 | B | #35 | `FakeCalc` 교체는 #23(선행) |
| G-5a | 빌더 단위 테스트(display = fixture, 요구 키 불변식, 미달 BAD `goalReachMonth` 키 없음, 라벨-`isAchieved`) | A | #28 | — |
| G-5b | `PlanContextView` 직렬화 = fixture(숫자 스케일 무시, `memberId` 없음, `isAchieved` 키) | A | 새 Issue(G-7) | — |
| G-6 | (G-1에 흡수) | B | #11 | — |
| G-7 | `PlanContextProvider`·`PlanRunRef`·`PlanContextView`·`ConditionsView`, 소유권 2단계, #29 Q1 재사용 | A | **새 Issue** `[calc] PlanContextProvider(C-1a)` | 선행 #19·#28·#29·#32 |
| G-8a | `ResultDisplayBuilder`(공유, 접두어 2개, 추가 키 4개, `goalReachMonth` 방출 규칙) | A | #28 (불가 시 #29) | #28 paths에 빌더·테스트. #29로 가면 #29 선행에 #28. #30·#32 본문 "공유 빌더 사용" |
| G-8b | Formatter: 음수 금액(지금), X-3·X-2(A면 `N.N%` 끝 0 제거)(결정 뒤) | A | #28 | — |
| G-9a | chat 리스너: 트랜잭션 없이 HTTP(방법 (a)/(b)), 생성 실패 → 미호출 `FAILED`·`FAILURE`, `baselineScenario` 전달 | B | #41 | paths에 `backend/.claude/rules/modulith.md`(예외 1줄) |
| G-9b | F-3: `findPlanRun`, `chat_message.baseline_scenario` 저장, EXPLAIN 요청 | B | #43 | 선행에 **G-7 새 Issue** |
| G-10 | `CalcResultView`·`ScenarioResultView`를 calc 루트로, paths 설명 정정 | A | #32 | — |
| G-11 | internal-calc.md 문구 정정(루트 타입, `/internal/calc` 한정 문장, 빌더 위치, 금액 경계, 문구표 키) | 기획 | 문서 + #10 본문 | X-3 결정 뒤 경계 표 |
| G-12 | plan `findVersion(memberId, planVersionId)` + 현재 계획 조회에 기준 시나리오(문자열) | A | #19 | — |
| G-13 | `persistence.md` calc_run 소유권 예외 1줄 | A | 새 Issue(G-7) | 새 Issue paths에 이 파일 |
| G-14 | 문구표 키 이름 `chat.noPlan`·`chat.alreadyExceeded`·`excluded.<CODE>` 5개·`scenarioMethod.<CODE>` 2개(임시 문장 필수) | 공통 | #18 | — |
| G-15a | F-3 404: 없는·남의·CHAT 기록 모두 `NOT_FOUND` | B | #43 | — |
| G-15b | 전역 오류 처리 `NOT_FOUND` ProblemDetail | A | #17 (#74 합침) | — |
| G-15c | 프론트 API 계약 문장 2개(F-3 404 규칙, X-4 결과). 구현 수용 기준은 넣지 않음 | 공통 | #12 | X-4 전에는 "결정 대기" |
| G-15d | X-4: 초과 계획이면 설명 요청 안 함 | B / A | #54 / #49 | X-4 결정 뒤 |
| G-16 | `b-team-contracts.md` C-1a와 #11 본문을 v3에 맞춤 | 기획 | 문서 + #11 | — |
| G-17 | 엔진 불변식 `isAchieved=true` ⇒ `goalReachMonth` non-null·목표월 이하 | A | #27 | — |
| G-18 | Q1 서비스 "활성 버전과 같은 최신 기록이 있으면 재기록 안 함" 확인 | A | #29 | — |

**#12 판단**: #12는 프론트-Spring API 계약 문서 Issue(별도 계약 협상 대상)라 구현 수용 기준을 넣을 곳이 아니다. F-3이 프론트 API이므로 **계약 문장 2개만** 필요하다: "없는·남의·CHAT 기록 `calcRunId`는 모두 `404 NOT_FOUND`", "(X-4 A일 때) 초과 계획은 F-3을 부르지 않는다". 구현은 #43(Spring)·#54(프론트)·#17(오류 형식).

**task-planner 전달**: #30과 #32는 paths `calc/web/**`가 겹쳐 동시에 진행할 수 없다. 빌더를 #28로 옮겨 공유 코드 때문에 기다릴 일은 없어졌다.

## 협상 기록

**v1 → v2** (상세 표는 `plan-context-v2.md` 부록 B)
- 판정: 제공자 "수정하면 수용", 소비자 "수정하면 수용".
- 제공자 반영: `CalcResultView` calc 루트, `conditions` 출처 `CalcInput`, display 빌더 하나(결과·조건 접두어), plan `findVersion`, 소유권 2단계, `findPlanRun`·`baselineScenario` 인자, 이름 `PlanContextProvider`, Q1 서비스 재사용, 트랜잭션 순서, 생성 실패 처리, G-5 단위 테스트화.
- 소비자 반영: `baselineScenario` 모델 입력 제외, 문구표 문장 매핑(`excludedNotes`·`scenarioMethodNote`), 필수/선택 목록, display 필터 충돌 해소, 요구 키 전체 검사, 검사 순서 1~6, dict 비교·`ensure_ascii=False`·로그 금지, 초과 EXPLAIN LLM 미호출, 문구표 키 고정, fixture 14개.
- 쟁점화: R-1 → X-4, R-3 → X-2, R-7 → X-3, H-1 → X-1.

**v2 → v3** (상세 표는 `plan-context-v3.md` 부록 B)
- 판정: 제공자 "수정하면 수용"(남은 수정은 대부분 Issue 배치), 소비자 "수정하면 수용"(반대 1건).
- 소비자 반영: `goalReachMonth` display는 `isAchieved=true`·non-null일 때만 + 테스트 1건, `model-input-basic.json` 자리표시자 제거, fixture 파일 쓰임·`make_request` 헬퍼, A-10·question-with-plan 전체 JSON, G-3에서 D-10 제외(#21), 프롬프트 규칙별 Issue, #18 키 이름·임시 문장.
- 제공자 반영: 빌더를 #28로(테스트 함께), 리스너 트랜잭션 없이 + `modulith.md` 예외(전파 속성 지원 미확인), `PlanRunRef.baselineScenario` 출처(문자열·plan 조회), G-5 숫자 스케일 무시 비교, fixture 표 Spring/ai-server 열, G-17(#27 불변식), 음수 금액을 X-3에서 분리, Issue 번호 정정(#19·#29·#41·#43·#17).
- Issue 배치 충돌 1건(G-7)은 A팀 영역이라 제공자안 채택, 이유 기록.
- 쟁점 X-1~X-4는 그대로. v2 이후 양쪽 모두 A로 모였다(제공자는 X-2를 B → A로 바꿈).

**검토 파일**
- [`plan-context-v1.md`](plan-context-v1.md), [`review-plancontext-v1-provider.md`](review-plancontext-v1-provider.md), [`review-plancontext-v1-consumer.md`](review-plancontext-v1-consumer.md)
- [`plan-context-v2.md`](plan-context-v2.md), [`review-plancontext-v2-provider.md`](review-plancontext-v2-provider.md), [`review-plancontext-v2-consumer.md`](review-plancontext-v2-consumer.md)
- [`plan-context-v3.md`](plan-context-v3.md) (최신 본문)
