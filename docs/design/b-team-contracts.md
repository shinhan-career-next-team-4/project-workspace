# B팀 인터페이스 계약 (조건 탐색: AI 대화·설명·RAG)

> 작성: tech-architect, 2026-11-16. 기준: D-046(B팀 = 대안·비교·AI 대화·설명·RAG, 계산은 A팀 엔진 호출, 적용은 A팀 흐름), D-045(범위), moeun에 이미 있는 계약.
> - **있음(경로)**: moeun에 이미 정의된 것. 경로는 `moeun/` 기준.
> - **필요(초안)**: 아직 없는 것. 아래 초안은 결정이 아니며 **합의 필요**다.
> - 차이 분석은 `docs/design/alignment.md`. 이 문서는 그 결과를 전제로 한다(특히 대화 조건 4개, 시작월 고정).

## 0. 원칙 (계약 전체에 적용)

1. **숫자는 Spring만 만든다.** AI가 말하는 모든 금액·기간·차이는 Spring 응답에 이미 있는 값이어야 한다(NFR-INT-01, FR-AI-02). 그래서 "현재 대비 얼마 늘었나"(차이)도 Spring이 계산해 준다. 이유: LLM이 빼기만 해도 계산 엔진 분리 원칙이 깨지고 숫자 대조(PR-04)가 어려워진다.
2. **범위 검증은 Spring 한 곳**(D-033). ai-server는 타입 검사만 하고, 범위 오류는 Spring 오류 본문을 그대로 인용해 되묻는다.
3. **프론트는 Spring만 호출하고, ai-server는 Spring 내부 API만 호출한다**(`ai-server/README.md`). 사용자 토큰은 ai-server로 가지 않는다(D-030).
4. **JSON은 camelCase**, 금액은 원 단위 정수, 기간은 개월 정수(`ai-server/app/schemas.py` `ApiModel`, `CalcInput`).
5. **오류 본문은 Spring 기본 `ProblemDetail`(RFC 7807)에 `code`·`errors`를 더한 형식 하나**. 이유: 새 라이브러리 없이 Spring Boot에 내장되어 있고 프론트·ai-server가 같은 파서를 쓴다.

## 1. B팀 Must 10건과 필요한 계약

| 요구사항 | 필요한 계약 | 상태 |
|---|---|---|
| FR-AI-01 AI 설명 비동기 표시 | F-1 질문 전송, F-2 메시지 폴링, F-3 설명 요청, C-1 `/chat` | C-1 있음, F-1~3 필요 |
| FR-AI-02 AI 설명의 숫자 일치 | C-1 `planContext` 필드 목록, C-2 계산 응답의 `diff` | 필요(초안) |
| FR-AI-03 ETF 위험 설명 출처 | F-2 메시지 응답의 `citations`, C-4 `/rag/search` | C-4 있음, citations 형식 필요 |
| FR-AI-04 AI 설명 실패 처리 | C-1 실패 응답 `{"error": CODE}`, F-2의 `FAILED` 상태 | C-1 있음, F-2 필요 |
| FR-AI-06 대화 조건 변경 인식 | C-2 `/internal/calc`, C-3 검증 오류 형식 | 요청 형식 있음, 응답·오류 필요 |
| FR-AI-07 대화 재계산 결과 표시·적용 | F-4 비교 결과 조회, A-1 적용, A-2 되돌리기 | 모두 필요 |
| FR-AI-09 범위 밖 질문 안내 | C-1 `messageType=OUT_OF_SCOPE`, 문구표 키 | 있음(문구표 키만 필요) |
| FR-AI-10 근거 자료 기반 설명 | C-4 `/rag/search`, 적재 CLI | 있음 |
| NFR-INT-03 AI-백엔드 연동 | C-1, C-2, C-3, 내부 키 헤더 | 일부 있음 |
| NFR-INT-04 RAG 검색 연동 | C-4, `rag_*` 테이블 | 있음 |

## 2. 이미 있는 계약 (moeun)

### C-1. Spring → ai-server `POST /chat` — 있음
- 경로: `ai-server/app/api/chat.py`, `ai-server/app/schemas.py` (`ChatRequest`, `ChatResponse`), `ai-server/README.md` "Spring과의 계약"
- 헤더: `X-Internal-Api-Key`
- 요청(현재 정의 그대로):
```json
{
  "memberId": 7,
  "messageId": 1031,
  "mode": "QUESTION",
  "text": "월 50만원으로 하면 어때요?",
  "baselineScenario": "AVG",
  "calcRunId": null,
  "planContext": { "...": "아래 C-1a" },
  "history": [{ "role": "user", "content": "..." }, { "role": "assistant", "content": "..." }]
}
```
- 응답:
```json
{
  "messageType": "RECALC_RESULT",
  "content": "월 저축액을 50만원으로 바꾸면 ...",
  "baselineScenario": "AVG",
  "calcRunId": 552,
  "conditionChanges": { "monthly_saving_amount": 500000 },
  "citationChunkIds": [88, 120]
}
```
- 실패: 4xx/5xx `{"error": "MAX_TOKENS" | "BAD_OUTPUT" | "TOO_MANY_ROUNDS" | "BAD_REQUEST" | ...}` → Spring이 `chat_message.status=FAILED`, `message_type=FAILURE`로 기록(FR-AI-04).
- 주의: `conditionChanges`의 **키는 snake_case**(`plan_version` 컬럼명, `ConditionChanges.changed()`)다. 다른 필드는 camelCase. 그대로 두되 계약에 명시한다(합의 필요: 그대로 둘지).

#### C-1a. `planContext` 필드 목록 — 필요(초안), 합의 필요
`plan_context`는 "Spring이 만든 값 그대로"라고만 정의되어 있다. LLM에 들어가는 값이므로 D-030(계산 결과와 조건만)에 맞게 필드를 고정한다.
```json
{
  "conditions": {
    "goalAmount": 30000000, "targetPeriodMonths": 36, "calcStartMonth": "2026-11",
    "heldAssets": 5000000, "monthlySavingAmount": 300000,
    "savingsRatePct": 3.12, "isDefaultSavingsRate": true, "savingsRatioPct": 50
  },
  "result": {
    "status": "CALCULATED", "targetMonth": "2029-11", "baselineScenario": "AVG",
    "scenarios": [
      { "scenario": "GOOD", "afterTaxAsset": 0, "gapToGoal": 0, "isAchieved": true },
      { "scenario": "AVG",  "afterTaxAsset": 0, "gapToGoal": 0, "isAchieved": false },
      { "scenario": "BAD",  "afterTaxAsset": 0, "gapToGoal": 0, "isAchieved": false }
    ]
  },
  "display": { "AVG.afterTaxAsset": "약 2,870만원", "AVG.gapToGoal": "약 130만원 미달" },
  "assumptions": { "taxRatePct": 15.4, "sp500BaseDate": "2026-10-31", "excludedItems": ["EXCHANGE_RATE", "ETF_TOTAL_EXPENSE"] }
}
```
- 넣지 않는 것: `memberId`, 로그인 아이디, `monthlyPoints`(토큰 낭비, 설명에 불필요).
- `display`: CP-04 표시 형식(`Formatter`)으로 Spring이 만든 문자열. LLM은 이 문자열을 그대로 인용한다. 이유: "약 N만원" 반올림을 LLM이 하면 계산이 된다.

### C-2. ai-server → Spring `POST /internal/calc` — 요청 있음, 응답 필요(초안)
- 경로: `ai-server/README.md`, `ai-server/app/tools/calc.py`(`CalcClient.recalculate`), `backend/.../calc/package-info.java`
- 헤더: `X-Internal-Api-Key`
- 요청(현재 정의 그대로, 단 필드는 4개로 줄임 — D-040):
```json
{
  "memberId": 7,
  "baselineScenario": "AVG",
  "conditionChanges": { "monthlySavingAmount": 500000 }
}
```
  - 허용 키: `monthlySavingAmount`, `savingsRatioPct`, `savingsRateInputPct`, `targetPeriodMonths`. 그 밖의 키는 C-3 `FIELD_NOT_CHANGEABLE`.
  - 기준은 항상 그 회원의 **현재 계획**(`plan.current_version_id`)이다. 이전 대화의 변경을 누적하지 않는다(D-041).
  - 시작월은 현재 계획의 `calc_start_month`를 쓴다(D-013).
- 응답(필요, 초안):
```json
{
  "calcRunId": 552,
  "basePlanVersionId": 41,
  "conditionChanges": { "monthlySavingAmount": 500000 },
  "current": { "...": "CalcResult (monthlyPoints 제외)" },
  "changed": { "...": "CalcResult (monthlyPoints 제외)" },
  "diff": {
    "byScenario": [
      { "scenario": "AVG", "afterTaxAssetDelta": 7340000, "gapToGoalDelta": 7340000, "achievementChanged": "MISS_TO_ACHIEVE" }
    ]
  },
  "display": { "changed.AVG.afterTaxAsset": "약 3,604만원", "diff.AVG.afterTaxAssetDelta": "약 734만원 늘어요" }
}
```
  - `current`·`changed`는 `CalcResult`(`backend/.../calc/CalcResult.java`)를 JSON으로 바꾼 것. 계산 기록은 `calc_run(run_type=CHAT)` 1행.
  - 구현 메모: calc 모듈 공개 타입으로 `CalcComparison(current, changed, changes, diff)`를 하나 둔다. 같은 타입을 F-4(화면용)와 Should인 비교 영역(FR-CMP-02)이 재사용한다.

### C-3. 검증 오류 형식 (Spring 공통) — 필요(초안), 합의 필요
`CalcClient`는 지금 400/409/422 본문을 문자열로 모델에 넘긴다. 형식을 고정한다.
```json
HTTP 422
{
  "type": "about:blank",
  "title": "입력 범위를 벗어났어요",
  "status": 422,
  "code": "VALIDATION_FAILED",
  "errors": [
    { "field": "monthlySavingAmount", "reason": "OUT_OF_RANGE", "min": 10000, "max": 10000000, "unit": "KRW",
      "copyKey": "validation.monthlySavingAmount.range" }
  ]
}
```
| HTTP | code | 언제 | ai-server 동작 |
|---|---|---|---|
| 422 | `VALIDATION_FAILED` (`reason`: `OUT_OF_RANGE`, `REQUIRED`, `NOT_INTEGER`) | CP-02 범위 밖 | `CLARIFY`로 끝내며 `min`·`max`·`unit`을 인용해 되묻기(D-033) |
| 422 | `FIELD_NOT_CHANGEABLE` | 대화로 못 바꾸는 조건(목표 금액 등) | `OUT_OF_SCOPE` 또는 "입력 수정에서 바꿀 수 있어요" 안내(D-040) |
| 409 | `NO_PLAN` | 저장된 계획이 없음 | `ANSWER`로 "먼저 계획을 만들어 주세요" |
| 409 | `ALREADY_EXCEEDED` | 현재 계획이 이미 목표 초과(FR-RES-01) | 계산 없이 안내 |
| 401 | `INVALID_INTERNAL_KEY` | 내부 키 불일치 | `AgentError` → FAILED |
| 5xx | `CALC_FAILED` | 엔진 오류 | `AgentError` → FAILED(FR-AI-04) |
- 범위 수치(`min`, `max`)는 TBD-09·TBD-10이 정해지기 전까지 `rules.yml`의 임시값을 그대로 내보낸다. ai-server는 수치를 하드코딩하지 않는다.
- 같은 형식을 프론트용 API에도 쓴다(입력 검증 FR-INP-09 포함).

### C-4. Spring(또는 디버그) → ai-server `POST /rag/search` — 있음
- 경로: `ai-server/app/api/rag.py`, `ai-server/app/schemas.py`(`SearchRequest`, `RetrievedChunk`)
- 요청 `{ "query": "...", "docType": "DISCLOSURE", "topK": 5 }`, 응답 `RetrievedChunk[]`(`chunkId`, `content`, `title`, `sourceUrl`, `docType`, `orgName`, `distance`)
- 적재: `uv run moeun-ingest ...`(`ai-server/README.md`). 테이블 `source_org`, `rag_document`, `rag_chunk`, `chunk_embedding`(`schema.sql`).
- B팀 추가 작업 없음(계약 그대로). 화면 출처 표시는 F-2가 Spring `rag` 모듈로 조회한다.

### C-5. 계산 엔진 타입 — 있음
- `CalcInput`, `CalcResult`, `ScenarioResult`, `MonthlyPoint`, `Assumptions`, `AppliedDataVersions`, `CalcStatus`, `Scenario`, `ScenarioMethod`, `ExcludedItem` (`backend/src/main/java/com/moeun/backend/calc/`)
- B팀은 이 타입을 JSON으로 받기만 한다. 해커톤에서 `targetPeriodMonths`·`monthlySavingAmount`는 항상 값이 있고(D-045), `requiredMonthlySaving`은 항상 null이다.

## 3. 프론트 ↔ Spring 계약 (B팀 화면용) — 모두 필요(초안)

모든 엔드포인트는 JWT 쿠키 인증, 소유권은 토큰의 회원으로만 판단(요청 본문에 `memberId` 없음, `backend/.claude/rules/persistence.md`). 담당: Spring `chat` 모듈 = B팀(합의 필요).

### F-1. 질문 보내기 `POST /api/chat/messages`
```json
요청 { "text": "월 50만원으로 하면 어때요?" }
응답 202 { "userMessageId": 1030, "assistantMessageId": 1031, "status": "PENDING" }
```
- 서버: USER 메시지 + ASSISTANT `PENDING` 저장 → `ChatAnswerRequested` 이벤트 → ai `/chat`(mode=QUESTION). `history`는 같은 회원의 최근 20개(Q-041 후보 결정에 따라 "이번 로그인 이후"로 제한).
- 오류: 422 `VALIDATION_FAILED`(빈 문자열, 2000자 초과), 409 `ANSWER_PENDING`(이전 답이 아직 PENDING이면 거절, TBD-37 중복 클릭).

### F-2. 메시지 폴링 `GET /api/chat/messages?afterId=1029`
```json
응답 200
{
  "messages": [
    { "id": 1030, "role": "USER", "messageType": "QUESTION", "status": "COMPLETED", "content": "월 50만원으로 하면 어때요?" },
    { "id": 1031, "role": "ASSISTANT", "messageType": "RECALC_RESULT", "status": "COMPLETED",
      "content": "...", "calcRunId": 552, "conditionChanges": { "monthlySavingAmount": 500000 },
      "citations": [ { "rank": 1, "title": "OO S&P500 투자설명서", "sourceUrl": "https://...", "orgName": "OO자산운용" } ] }
  ]
}
```
- `status=PENDING`이면 `content` null. `FAILED`면 `messageType=FAILURE`, `content`는 문구표의 실패 안내(FR-AI-04).
- 토큰 만료 연장 제외(`@SkipRenewal`, Q-042 후보).
- 폴링 간격 1초, 시간 초과는 Spring → ai 호출 30초(임시, TBD-33 실측 후 조정). 시간 초과 시 Spring이 `FAILED`로 바꿈.
- 출처 표시: 링크 텍스트는 문서 제목(상품명 포함 가능), 본문은 'S&P500 추종 ETF'(D-028).

### F-3. 설명 요청 `POST /api/chat/explanations`
```json
요청 { "calcRunId": 540 }
응답 202 { "assistantMessageId": 1029, "status": "PENDING" }
```
- 결과 화면이 계산 결과를 그린 직후 프론트가 부른다(FR-AI-01). 서버는 ASSISTANT `EXPLANATION` PENDING을 만들고 ai `/chat`(mode=EXPLAIN) 호출.
- `calcRunId`는 그 회원의 PLAN 기록이어야 한다(아니면 404 `NOT_FOUND`).
- FR-AI-05(Should)를 되살리면 `{ "calcRunId": 540, "retryOfMessageId": 1029 }`로 같은 엔드포인트를 쓴다(`chat_message.retry_of_message_id`).

### F-4. 대화 비교 결과 조회 `GET /api/chat/messages/{id}/comparison`
```json
응답 200
{
  "messageId": 1031,
  "conditionChanges": { "monthlySavingAmount": 500000 },
  "current": { "...": "CalcResult" },
  "changed": { "...": "CalcResult" },
  "diff": { "...": "C-2와 같음" },
  "applicable": true,
  "planRevision": 12
}
```
- `RECALC_RESULT` 메시지에만 있다(그 밖은 404). 결과는 저장하지 않으므로 `calc_run`의 버전과 `chat_message.condition_changes`로 다시 계산한다(ADR-002).
- `applicable`: 이 메시지가 회원의 **가장 최근** `RECALC_RESULT`이고, 그 `calc_run.plan_version_id`가 현재 계획과 같을 때 true(D-041). 되돌리기 후 비활성은 프론트 상태로 처리(아래 A-2 주석).
- 그래프(`monthlyPoints`)는 넣지 않아도 된다(Q-039 3번 권장: 대화창은 숫자 비교만). 합의 필요.

### 오류 공통
- 401 `UNAUTHENTICATED`(만료 토큰, FR-AUTH-02) → 프론트는 로그인 화면으로.
- 404 `NOT_FOUND`(남의 메시지 포함, 존재 여부를 숨김).
- 형식은 C-3과 같은 `ProblemDetail`.

## 4. B팀이 A팀에 의존하는 지점

| # | 의존 대상 (A팀) | B팀이 쓰는 곳 | 계약 | 상태 |
|---|---|---|---|---|
| A-0 | 계산 엔진 `CalcEngine` + `/internal/calc` | ai 도구 `recalculate`, F-4 | C-2 | 요청만 있음, 응답 필요 |
| A-0b | 범위 검증 `ConditionValidator` + `rules.yml › change-paths.CHAT` | C-3 오류, 되묻기 | C-3 | 필요 |
| A-0c | 현재 계획 + 결과 조회(`plan`, PLAN `calc_run`) | `planContext` 만들기(C-1a), F-3의 `calcRunId` | 내부 서비스 호출(모듈 간) | 필요 |
| A-1 | 적용 `POST /api/plan/apply` | 대화창 '내 계획으로 적용'(FR-AI-07), Should인 대안·비교 적용 | 아래 초안 | 필요 |
| A-2 | 되돌리기 `POST /api/plan/undo` | 적용 직후 토스트 10초(FR-PLAN-04, D-041) | 아래 초안 | 필요 |
| A-3 | `PlanChanged` 이벤트 | 적용 후 대화창 버튼 비활성, 결과 화면 갱신 | `backend/.claude/rules/modulith.md` 이벤트 표 | 있음 |
| A-4 | 인증·쿠키·401 처리, 로그아웃 | 모든 F-* | 로그아웃 엔드포인트 필요(alignment M-6) | 일부 있음 |
| A-5 | 문구표 `copy/copy.ko.yml`, 표시 형식 `Formatter` | `display` 문자열, 범위 밖·실패 안내 | `db/moved-to-code.md` §4 | 이름만 있음 |
| A-6 | 기준 데이터 적재(금리·지수) | 계산 결과가 있어야 설명 가능 | `refdata` | A팀 |

### A-1. 적용 `POST /api/plan/apply` — 필요(초안), 합의 필요
```json
대화에서 적용(확인창 없음, D-016)
요청 { "source": "CHAT", "chatMessageId": 1031, "expectedRevision": 12 }

대안·비교에서 적용(확인창 뒤, FR-PLAN-01, Should)
요청 { "source": "ALTERNATIVE", "conditionChanges": { "targetPeriodMonths": 48 }, "expectedRevision": 12 }

응답 200
{ "planVersionId": 42, "previousVersionId": 41, "revision": 13, "calcRunId": 553, "undoAvailable": true }
```
- 대화 적용은 값 대신 `chatMessageId`를 보낸다. 서버가 `chat_message.condition_changes`를 읽어 **다시 검증**(D-033)하고 새 `plan_version(source=CHAT)`을 만든다. 시작월은 현재 버전에서 복사(D-013).
- 오류: 409 `PLAN_CHANGED`(revision 불일치, PR-08) / 409 `STALE_COMPARISON`(가장 최근 비교 결과가 아니거나 기준 버전이 현재 계획과 다름, D-041) / 422 `VALIDATION_FAILED`.
- 성공 후 프론트는 결과 화면 전체를 다시 불러오고(FR-PLAN-03) 토스트 10초를 띄운다.

### A-2. 되돌리기 `POST /api/plan/undo` — 필요(초안), 합의 필요
```json
요청 { "expectedRevision": 13 }
응답 200 { "planVersionId": 41, "previousVersionId": null, "revision": 14, "calcRunId": 540, "undoAvailable": false }
```
- 직전 1개만(TBD-21·22). 시작월 유지(D-013). 오류: 409 `PLAN_CHANGED`, 409 `NOTHING_TO_UNDO`.
- 합의할 것: 되돌리기가 포인터만 바꾸는지(`current ↔ previous`), 새 `plan_version`을 INSERT하는지. 포인터만 바꾸면 되돌린 뒤 최신 비교 결과의 기준 버전이 다시 현재 계획과 같아져 F-4 `applicable`이 true로 돌아온다. D-041(되돌린 뒤 이전 버튼 모두 비활성)은 **프론트가 "되돌리기 이후 받은 비교 결과만 활성"으로 처리**하는 것을 초안으로 한다.

## 5. 1주차에 합의할 계약 (목으로 병렬 개발하기 위한 최소 목록)

순서대로 정하면 B팀이 A팀 구현을 기다리지 않는다.

| 순서 | 계약 | 합의 대상 | 목(mock)으로 개발하는 방법 | 늦으면 막히는 것 |
|---|---|---|---|---|
| 1 | C-2 `/internal/calc` 요청·응답(`current`, `changed`, `diff`, `display`) | A팀 계산 담당 | ai-server 테스트의 fake `Calculator`가 고정 JSON을 돌려줌(`ai-server/.claude/rules/langchain.md` 테스트 규칙) | 대화 재계산 설명 전체 |
| 2 | C-3 오류 형식과 코드 표, CHAT 경로 허용 필드 4개 | A팀 `plan` 담당 | fake `Calculator`가 422 본문을 던지는 케이스 | 되묻기(D-033) |
| 3 | C-1a `planContext` 필드 목록과 `display` 문자열 규칙 | A팀(`Formatter`) | Spring 없이 JSON 파일로 `/chat` 호출 | 설명 품질, 숫자 대조(PR-04) |
| 4 | F-1~F-4 응답 형식(OpenAPI 초안) | 프론트 담당(A·B) | 프론트는 고정 JSON 목(새 라이브러리 없이 `fetch` 래퍼에서 분기) | 대화창 UI |
| 5 | A-1·A-2 적용·되돌리기 요청·응답·오류 코드, 되돌리기 방식 | A팀 `plan` 담당 | 프론트 목에서 revision만 올림 | 적용 버튼·토스트 |
| 6 | 모듈 담당(Spring `chat` = B팀), 이벤트 `ChatAnswerRequested` 처리 방식, ai 호출 시간 초과 임시값 | 팀 전체 | — | Spring 쪽 B팀 작업 시작 |
| 7 | Q-041 후보(대화 보관), Q-042 후보(세션·폴링) | 팀 결정 | A안을 임시로 두고 개발 | F-1 `history` 범위, F-2 토큰 연장 |

합의 결과는 moeun의 `ai-server/README.md` "Spring과의 계약"과 backend REST Docs(OpenAPI)에 옮겨 하나만 기준으로 삼는다(문서가 두 곳에 갈라지지 않게).

## 6. 결정에 없어 초안으로만 쓴 것 (합의 필요 목록)

- `/internal/calc` 응답의 `diff`, `display`, `current` 포함 여부
- 오류 코드 이름과 HTTP 상태
- 설명 요청을 프론트가 시작(F-3)하는 방식
- 폴링 간격 1초, ai 호출 시간 초과 30초(TBD-33 미결)
- `applicable` 판정 규칙과 되돌리기 후 비활성 처리 위치
- 되돌리기 구현 방식(포인터 교체 vs 새 버전)
- `conditionChanges` 키 표기(ai 응답은 snake_case, 요청은 camelCase)를 통일할지
- 대화창 비교에 그래프를 넣지 않음(Q-039 3번 권장안)
- Spring `chat` 모듈 담당을 B팀으로
