# planContext 계약 v2 소비자 재검토 (moeun #11, C-1a) - 4단계(마지막 1회)

> 검토자: 소비자(B팀: ai-server, Spring chat, 대화창 프론트). 2026-11-16. 대상 `plan-context-v2.md`. 파일은 고치지 않았다.
> 본 것: v2 전체(부록 A·B 포함), 내 v1 검토, 제공자 v1 검토, moeun `ScenarioResult.java`(goalReachMonth 정의), `ai-server/app/core/`(copy.py 없음), moeun Issue #11·#12·#18·#21·#22·#23·#28·#29·#31·#32·#35·#41·#43 본문(gh api). moeun에 `docs/` 폴더는 아직 없다(G-1이 만든다).

```
판정: 수정하면 수용
```

v1에서 요구한 9개는 모두 들어갔다. 남은 반대는 **1건(goalReachMonth 방출 규칙)**이고 나머지는 문서·Issue 정리다. 이 1건만 고치면 소비자는 막히는 곳이 없다.

## (1) 내 수정 제안 반영 확인

| 내 제안 | v2 위치 | 판정 |
|---|---|---|
| 필수/선택 필드 목록(H-7) | C1a-8 표 | 반영됨. 목록이 나와 같다. `conditions` 선택, `extra` 덮어쓰기 금지도 있다 |
| display 요구 키 전체 검사(H-2) | C1a-8 요구 키 표, 검사 5 | 반영됨. `CALCULATED`는 `<S>.{afterTaxAsset, principal, afterTaxGain, gapToGoal}`, `ALREADY_EXCEEDED`는 `goalAmount`·`conditions.heldAssets`. 필터를 거친 뒤 기준이라 "값이 숫자인 키"도 누락으로 잡힌다(좋음) |
| 값 타입 충돌 해소 | C1a-8 display 필터 | 반영됨. `dict[str, Any]`, 패턴+문자열만 남김, 객체가 아니면 422 |
| 검사 순서 | C1a-8 검사 1~6 | 반영됨. EXPLAIN `planContext=null` 400, calcRunId 불일치 400, 초과는 LLM 미호출, 그다음 요구 키 502. 기계적으로 고를 수 있다(문자열 해석 없음). 400·422·502 모두 Spring `FAILED` |
| excludedNotes·scenarioMethodNote 매핑 | C1a-5, C1a-8 "모델에 넣는 것" | 반영됨. Spring은 코드만, ai-server가 `excluded.<CODE>`·`scenarioMethod.<CODE>`로 바꿈, 모르는 코드는 버리고 경고 로그, enum 전체 문장 테스트. 문구표 키 4종 고정(C1a-11)도 요청대로 |
| dict 비교, `ensure_ascii=False`, 로그에 본문 금지 | C1a-8 | 반영됨 |
| `baselineScenario` 모델 입력 제외 | C1a-4, "모델에 넣는 것" | 반영됨 |
| EXPLAIN+초과는 LLM 없이 고정 문장 | 검사 4, A-10 | 반영됨 |
| 실제 JSON fixture + 달성/0원/오염/누락/불일치 | C1a-13, 부록 A-6~A-10 | 반영됨. 14개 수를 셌다(plan-context 7 + chat-request 6 + model-input 1) |

**fixture 14개가 Spring 없이 테스트 가능한가: 가능. 단 2가지를 고쳐야 "고정 JSON"이 된다.**

1. **`model-input-basic.json`은 순수 JSON이 아니다.** A-5에 `"(문구표 excluded.ETF_TOTAL_EXPENSE)"` 같은 자리표시자 문자열이 들어 있다. 파일을 그대로 `json.loads`해 비교하면 항상 실패한다. v2는 "테스트가 같은 매핑에서 기대값을 만든다"고 했으므로, 파일에는 `excludedNotes`/`scenarioMethodNote` 키를 **아예 넣지 않고**(나머지만 고정 비교) 테스트가 그 두 키를 COPY에서 만들어 덧붙이는 방식이 낫다. 자리표시자 문자열을 파일에 두면 사람이 "이게 진짜 값인가" 헷갈린다. 수정안: A-5 파일에서 두 키를 빼고, 설명 한 줄로 "두 키는 테스트가 `COPY`로 채운다"고 적는다.
2. **파일 두 종류의 쓰임을 한 줄로 못 박을 것**: `plan-context-*.json`은 `planContext` 객체만이고 `chat-request-*.json`은 `ChatRequest` 전체다. A-8·A-9·A-6·A-7은 planContext 파일이라 ai-server 테스트가 `ChatRequest`로 감싸는 헬퍼(`make_request(plan_context, mode, calc_run_id)`)가 필요하다. 계약에 "테스트 헬퍼가 감싼다"만 적으면 된다. 또 A-10의 `chat-request-explain-*` 3개는 문서에 "A-4에서 바꾼 값"만 있고 전체 JSON이 없으므로, G-1에서 완전한 파일로 만든다고 적을 것(v1에서 A-4 자리표시자를 지적한 것과 같은 문제를 막는다).

그 밖: FakeClaude `calls`에서 `<plan_context>` 태그를 `json.loads`하는 방식, `FakeCalc`를 internal-calc A-1 모양으로 바꾸는 선행(G-4), 수동 평가 목록은 그대로 충분하다.

## (2) 제공자 제안 반영으로 소비자 쪽에 생긴 변화

| 제공자 제안 | 소비자(ai-server) 영향 | 소비자(B팀 Spring chat·프론트) 영향 |
|---|---|---|
| `CalcResultView`를 calc 루트로, `PlanContextProvider` 개명 | 없음(와이어 동일) | chat이 `calc.PlanContextProvider`·`calc.PlanContextView`를 의존. `chat {calc, rag}`라 허용. 타입 import 경로만 맞추면 됨 |
| `findPlanRun` 경량 조회 + `baselineScenario` 인자 | 없음 | **#43이 바뀐다.** 지금 #43 본문은 "calcRunId가 PLAN 기록인지 확인하고 planContext를 만들어 ai-server를 부른다"이다. 요청 시점엔 `findPlanRun`(404·`baseline_scenario` 저장), 리스너에서 `findForCalcRun(…, baselineScenario)`로 나뉜다. `ChatAnswerRequested`가 `baselineScenario`를 `chat_message`에서 읽어 넘겨야 한다 |
| 트랜잭션 순서(호출은 트랜잭션 밖), 생성 실패 시 ai-server 미호출 `FAILED` | 없음 | **#41이 바뀐다.** 리스너가 "planContext 만들기 → HTTP → 저장" 3단계이고, 생성 예외는 FAILED·FAILURE. 수용 기준 1줄 추가 |
| 소유권 2단계, `findVersion` | 없음 | 없음(A팀 내부) |
| 404를 "없는 기록/남의 기록" 통일 | 없음 | #43 수용 기준에 "없는 calcRunId도 404"가 빠져 있다(지금은 남의 것만) |
| 초과 계획 `conditions.heldAssets` 유지 | 요구 키 2개로 반영됨 | 없음 |
| QUESTION은 Q1 서비스 재사용 → `planContext.calcRunId`가 있고 `ChatRequest.calcRunId`는 null | 정상으로 명시됨, fixture 있음 | **QUESTION 매 턴마다 PLAN 행이 생길 수 있다**(Q1-c). `ix_calc_run_latest`로 무해하다고 했으나, 대화 중 매 질문이 `calc_run` INSERT를 유발하지는 않는지 A팀이 "활성 버전과 같은 최신 기록이 있으면 재기록 안 함"을 지킨다고 #29 본문에 한 줄 확인받을 것(소비자 요청, 반대 아님) |

소비자가 새로 얻은 부담은 없다. 다만 **#41·#43 본문(B팀)이 낡은 채 남아 있으면 구현자가 `PlanContextProvider`를 모르고 만든다.** 후속 Issue 배치에 포함한다((5) 참고).

## (3) [기획 보완] 2건

v2에서 `[기획 보완]`이 붙은 것은 두 가지다: (i) `isAchieved=true`인 `<S>.goalReachMonth`를 요구 키에 넣음(C1a-6, C1a-8), (ii) 음수 금액 형식 `-약 N만원`·`-1만원 미만`(C1a-6 경계 표, X-3).

- **(i) 수정(반대 1건).** 요구 키 추가 자체는 맞다. 그러나 `ScenarioResult.goalReachMonth` 정의가 **"세후 예상 자산이 처음 목표 금액 이상이 되는 달"**이고 `isAchieved`는 **목표월(마지막 달)의 `afterTaxAsset ≥ goal`**이다(`calc/ScenarioResult.java` 주석). 둘은 같은 값이 아니다. ETF BAD처럼 중간에 목표를 넘었다가 마지막 달에 내려오면 **`isAchieved=false`인데 `goalReachMonth`는 non-null**일 수 있다. 그러면 display에 `BAD.goalReachMonth: "2029년 5월"`이 들어가고 `BAD.gapToGoal`은 `-약 38만원 미달`이다. 모델은 "미달인데 5월에 도달"을 문장으로 만들거나 둘을 어떻게 말할지 헤맨다. 반대 방향(`isAchieved=true`인데 null)은 마지막 달이 목표 이상이므로 생기지 않는다(요구 키는 안전).
  - **수정안**: 빌더가 `<S>.goalReachMonth` display 키를 **`isAchieved=true`이고 값이 non-null일 때만** 만든다(지금 문구는 "값이 null이면 키 없음"). 그러면 프롬프트 규칙 3("키가 없고 `isAchieved=false`이면 도달하지 않아요")이 그대로 참이 된다. G-5에 "중간에 닿았다가 마지막에 내려온 BAD → 키 없음" 테스트 1건. A-8의 `"BAD.goalReachMonth": 202911` 오염 예시는 그대로 유효(버려짐).
  - 이 수정이 없으면 소비자가 막히지는 않지만 달성 설명에 모순 문장이 나올 수 있다. 소비자 쪽에서 같은 판정을 하려고 `goalReachMonth`를 파이썬에서 보정하는 일은 하지 않는다(계산 금지).
- **(ii) 수용.** BAD 단기 계획에서 `afterTaxGain`이 음수인 경우를 기획이 찾아 메운 것이고 소비자 영향은 문자열 하나다(패턴·필터는 값 내용을 보지 않음). 요청 하나: 부호가 `gapToGoal`의 `-약 288만원 미달`과 같은 `-약`이라 모델이 "미달"과 헷갈리지 않도록, 프롬프트에 "`afterTaxGain`이 `-`로 시작하면 손실로 말한다"는 한 줄은 **넣지 않는다**(해석 규칙이 늘어남). 대신 부록 A-7(또는 별도)에 `AVG.afterTaxGain` 음수 예시 한 건을 넣어 두면 충분하다. 이것은 선택이다.

## (4) 쟁점 X-1~X-4 최종 의견

| 쟁점 | 지지 | 한 줄 이유 |
|---|---|---|
| **X-1** 상대 표현 | **A(되묻기)** | 프롬프트 한 줄로 NFR-INT-01을 지키고 #10 확정 계약을 안 열며, 반올림된 `약 30만원`에서 덧셈하는 사고를 원천 차단한다. 조건: 규칙 7은 월 저축액뿐 아니라 **네 조건(월 저축액·비중·적금 금리·기한) 모두의 "더/덜/늘리면/줄이면"**에 적용하고, 수용 기준은 #21의 "모호한 발화는 되묻는다"에 사례로 넣는다(별도 Issue 불필요). B는 raw 전달이라 반대, C는 해커톤 뒤 후보로 지지 |
| **X-2** 세율 | **A(display 추가)** | 세율 질문은 첫 질문 후보이고, 안 넣으면 숫자 출처가 모델 기억(15.4%/22% 혼선)이 된다. 비용은 형식 1개·키 1개. 안 넣을 경우 규칙 8의 B 문장을 필수로 하고 RAG 세율과 엔진 세율이 다르면 안 되므로 finance-domain-reviewer 확인을 권한다 |
| **X-3** 금액 0원·1만원 미만·음수 | **A(3줄 고정)** | `heldAssets=0`은 DB 기본값이라 데모에서 흔하고 `약 0만원`은 어색하다. 소비자는 형식이 정해지기만 하면 되고, D-055 경계와 같은 결이라 모델이 새 규칙을 배울 일이 없다. fixture A-7의 두 값이 이 결정에 달려 있으니 A로 확정되면 그대로 둔다 |
| **X-4** 초과 계획에 F-3 호출 | **A(부르지 않음)** | 설명할 숫자가 없고 같은 문장을 두 번 보일 이유가 없다. ai-server 가드(검사 4)는 어느 쪽이든 남기므로 B를 택해도 안전하다. 호출 주체는 B팀 프론트(#54)라 그쪽 수용 기준에 한 줄 필요 |

넷 다 #11 머지를 막지 않는다는 기획 판단에 동의한다. 단 **X-2·X-3 결정이 늦어지면 fixture 값이 바뀌므로**, #11 머지 때는 추천안 A로 fixture를 올리고 결정이 다르면 표시된 줄만 바꾸는 방식(v2 방침)이 맞다.

## (5) 후속 작업 Issue 배치 (moeun Issue 목록을 gh api로 확인함)

번호는 모두 실제 Issue다. D-058에 따라 본문(수용 기준·변경 범위·선행)을 고친다.

| 작업 | 배치 | 근거와 수정할 본문 |
|---|---|---|
| **G-2** `PlanContext` 모델, display 필터, `build_messages`, `run()` 검사 2~5 | **#35**(`[ai] planContext 기반 설명 모드(EXPLAIN)와 display 인용 규칙`, team:B, week:2) | 이미 `agent.py`·`prompts.py`·`schemas.py`가 paths다. 새 Issue 불필요. 수용 기준 현재 3줄뿐이라 C1a-8 검사 표(필수 누락 422, EXPLAIN null/불일치 400, 초과 LLM 미호출, 요구 키 누락 502, 오염 입력 무시, `memberId` 없음)로 교체. paths에 `ai-server/tests/test_plan_context.py`, `ai-server/tests/fixtures` 읽기 헬퍼 추가. 선행 `#11, #21`에 **#22, #23(`agent.py`·`schemas.py` 겹침: #23 본문이 이미 #21 → #22 → #23 순서를 요구)과 #18(문구표 로더)** 추가 |
| **G-3** 프롬프트 규칙 | **#35**(규칙 1·2·3·5·6·8·9), **#21**(규칙 7 = X-1 A. "더/덜" 되묻기 사례), **#23**(규칙 4 = 비교·차이는 도구 결과 접두어 키만, `FakeCalc`를 internal-calc A-1 모양으로 바꾸는 작업과 같은 곳) | **G-3의 D-10(조건 7개 → 4개)은 #21이 이미 범위다.** G-3에서 빼고 중복 작업이 생기지 않게 한다. `prompts.py`는 #21·#22·#23·#35·#38이 겹치므로 같은 순서 처리를 #35 선행에 명시 |
| **G-4** fixture 테스트, 수동 평가 목록 | **#35**(G-2와 같은 Issue) | 완료 조건에 "수동 평가 목록 3~5건 실행 결과를 PR 본문에"를 추가. 선행 `FakeCalc` 교체는 #23(`tests/fakes/**`가 paths) |
| **G-14** 문구표 키 | **#18**(`[docs] 문구표 copy.ko.yml 초기 키와 Spring·ai-server 로더`, team:common, week:1) | #18 본문에는 NO_PLAN·ALREADY_EXCEEDED "대화 안내 키"만 있고 **키 이름이 없다.** 이름을 `chat.noPlan`, `chat.alreadyExceeded`로 못 박고, `excluded.<CODE>` 5개와 `scenarioMethod.<CODE>` 2개를 수용 기준에 추가. #18 수용 기준 "없는 키를 읽으면 실패"가 있으므로 TBD-01이 안 끝났어도 `scenarioMethod.*`에 **임시 문장**을 반드시 넣는다(빈 값 금지). `ai-server/app/core/copy.py`가 아직 없고 #18이 week:1이라, #35가 #18 뒤에 오면 G-2의 "[전환기] 상수 dict"는 필요 없다. #18이 늦을 때만 쓰는 대체 경로로 남긴다 |
| **G-15** F-3 404 통일, X-4 | **#12**(계약 문서 `docs/api/frontend-api.md`: 없는/남의 기록 모두 404 `NOT_FOUND`, 초과 계획은 F-3을 부르지 않음) + **#43**(구현: 수용 기준에 "없는 calcRunId도 404", `findPlanRun` 사용, `chat_message.baseline_scenario` 저장, 선행에 `PlanContextProvider` Issue 추가) + **#54**(`[front] AI 설명 비동기 표시`, 초과면 설명을 요청하지 않음) | X-4 결정 전에는 #54·#12의 초과 문장을 "결정 대기"로 둔다. #49(`결과 화면 1`, team:A)의 "목표 초과 안내" 수용 기준에도 "이때 설명 요청 없음"을 교차참조 |
| (참고) #41 | 수용 기준에 "planContext 생성 실패 → ai-server 미호출·FAILED·FAILURE", "HTTP 호출은 트랜잭션 밖" 추가 | 제공자 제안 반영 |
| (참고) G-7 담당 | 새 Issue를 만들지 않고 **#29**(`calc_run 기록… 결과 조회 서비스`, `calc/**`)에 합치는 쪽을 권한다 | `PlanContextProvider`의 QUESTION 경로가 Q1 서비스를 그대로 부르는데 그 서비스가 #29 범위다. 단 #29 선행(#19, #27)에 #28·#32(`ResultDisplayBuilder`)와 plan `findVersion` Issue가 더 필요하다. 합칠지는 A팀 판단. #43의 선행에 G-7 담당 Issue를 추가 |

## 남은 반대 항목

1. **goalReachMonth 방출 규칙**(3-i): `isAchieved=true`일 때만 display 키를 만든다. 그렇지 않으면 "미달인데 도달 달이 있음"이 생긴다. 이것이 유일한 필수 수정이다.
2. (문서) `model-input-basic.json` 자리표시자 제거, `plan-context-*`/`chat-request-*` 쓰임·헬퍼 명시, A-10 파일 전체 JSON 작성(1항 fixture).
3. (Issue) G-3의 D-10은 #21과 중복이라 제외, #18에 키 이름 명시, #35 선행에 #22·#23·#18 추가, #41·#43 본문 갱신.

## 소비자 쪽에서 꼭 필요한 것

위 반대 1(goalReachMonth) 외에는 없다. v2대로면 AI·파이썬이 계산할 곳이 남지 않는다: 금액·차이·시점은 display, 상대 표현은 되묻기(X-1 A), 세율은 display(X-2 A), 0원·소액은 문자열로 확정(X-3 A).

## 빼도 되는 것

- 와이어 `conditions`: 소비자는 읽지 않는다. v2가 남기는 이유(로그·fixture·X-1 B 대비)는 타당하고 비용이 작아 반대하지 않는다. X-1을 A로 확정하면 "B 대비" 이유는 사라지므로, 그때는 제거해도 된다(선택).
- 제거 제안 없음.

## 새로 알게 된 것(진행자 참고)

- moeun에는 아직 `docs/` 폴더와 `ai-server/app/core/copy.py`가 없다. G-1·#18이 처음 만든다.
- `ScenarioResult.goalReachMonth`는 "처음 닿은 달", `isAchieved`는 "마지막 달 기준"이라 의미가 다르다(`backend/.../calc/ScenarioResult.java`).
