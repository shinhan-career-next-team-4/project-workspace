# 프론트 ↔ Spring 대화 API 계약 v1 (moeun #12-b) — 기획 초안

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 1단계(기획 초안). **결정이 아니라 검토용 초안이다.**
> - 범위: moeun #12 중 **#12-b(B팀 대화 부분)**. F-1 질문 보내기, F-2 메시지 폴링, F-3 설명 요청, F-4 대화 비교 결과 조회, 대화 비교 결과 적용(A-1의 대화 쪽), 대화 기록 삭제(D-051), 이 API들의 오류 공통 규칙, **적용 API의 위치와 모듈 의존 방향**(이번 협상의 핵심).
> - 범위 밖(#12-a, 따로 협상): 로그인·로그아웃 엔드포인트 자체, 입력 저장·결과 보기·현재 계획 조회, 되돌리기(A-2) 엔드포인트. #12-b가 기대하는 것만 C12b-13 "#12-a에 요구하는 것"에 적는다.
> - 출발 초안: `docs/design/b-team-contracts.md` §3(F-1~F-4, 오류 공통), §4(A-1, A-2), §5, §6, `docs/design/alignment.md` 2-2·2-3·2-4
> - 재사용(최종본): `internal-calc.md` C3-1(오류 형식), C3-5(프론트 API 적용 범위), C2-3~C2-6(비교 모양·display), `plan-context.md` C1a-10(F-3 404·`findPlanRun`), C1a-11
> - 기준: `docs/srs.md`(FR-AI-01·04·05·06·07, FR-PLAN-03·04, FR-RES-01, FR-AUTH-02·03, NFR-INT-03, NFR-SEC-02), `docs/decisions.md`(D-016, D-022, D-030, D-033, D-040, D-041, D-051, D-052, D-056, D-057, D-062)
> - moeun 기준(origin/develop, 읽기만 함, 경로는 `moeun/` 기준): `backend/CLAUDE.md`(모듈 표), `backend/.claude/rules/modulith.md`·`persistence.md`, `backend/.../chat/package-info.java`(`allowedDependencies = {"calc", "rag"}`), `backend/.../plan/package-info.java`(`{}`), `db/erd.md`(§2 `chat_message`, §4 Q2·Q4, §5-G), `db/decision.md`(ADR-002), `ai-server/app/schemas.py`(`ChatRequest`, `ChatResponse`, `ConditionChanges.changed()`), `ai-server/README.md`
> - **확인하지 못한 것**: 이 단계에는 셸이 없어 moeun Issue 본문(#41, #43, #44 등)을 직접 조회하지 못했다. Issue 번호는 최종본 `plan-context.md` 후속 작업 표에 나온 것만 썼고, 거기 없는 것(F-1·F-2·대화 적용 담당 Issue)은 "번호 확인 필요"로 적었다. 검토자가 조회해 바로잡아 주기 바란다.
>
> **표기**
> - **이미 있음**: moeun 코드·문서·최종 계약에 같은 내용이 있다.
> - **새로 필요**: 아직 없다.
> - **[기획 제안]**: 결정(D-번호)·최종 계약에 없는 것을 기획이 초안으로 채운 것. 검토에서 쟁점이 될 수 있다.
> - **[코드 차이]**: moeun 현재 코드·문서와 이 계약이 다른 곳(C12b-15에 모음).
> - 항목 ID(C12b-x)로 검토 의견을 주고받는다. 검토 요청 질문은 맨 아래 "검토 요청"(R-x).

## 0. 이 계약의 원칙

`internal-calc.md` §0을 그대로 따른다. 프론트 API에서 특히 중요한 것만 다시 적는다.

1. **프론트는 Spring만 부른다. ai-server는 브라우저에 노출하지 않는다**(NFR-INT-03, `ai-server/README.md`). 사용자 토큰은 ai-server로 가지 않는다(D-030).
2. **회원은 JWT subject로만 정한다.** 요청 본문·쿼리에 `memberId`가 없다(`persistence.md`). 남의 리소스는 존재 여부를 숨기고 `404 NOT_FOUND`로 답한다.
3. **숫자는 Spring만 만든다.** 대화창 비교 카드의 표시 문자열도 Spring `display`를 그대로 쓴다(C12b-6). 왜: AI 문장의 "약 789만원 증가"와 카드의 숫자가 글자까지 같아야 한다(PR-04, FR-AI-02).
4. **적용은 값이 아니라 `chatMessageId`로 한다.** 브라우저가 조건 값을 보내지 않으므로 검증을 통과한 비교 결과와 다른 값이 내 계획에 들어갈 길이 없다(D-033).
5. **JSON은 camelCase**, 금액은 원 정수, 기간은 개월 정수, 퍼센트는 숫자. 시각은 ISO-8601(오프셋 포함, `2026-11-16T10:15:30+09:00`).
6. **null은 키를 빼지 않는다. 받는 쪽은 모르는 키를 무시한다**(internal-calc 원칙 6·7).
7. **오류 본문은 하나의 형식**: `ProblemDetail` + `code` + `errors[]`, `application/problem+json`(C3-1). **기계 판단은 `code`로만** 한다. `title`은 사람용이며 화면 문구는 문구표(CP-05)에서 `code`로 찾는다.
8. **새 라이브러리 없음.** Spring 내장 `ProblemDetail`, Jackson 기본. 프론트 목은 JSON 파일 + 기존 `fetch` 래퍼 분기(C12b-12).

---

## C12b-1. 범위와 엔드포인트 목록

| ID | 메서드·경로 | 하는 일 | 성공 | 담당 모듈(팀) | 토큰 연장 |
|---|---|---|---|---|---|
| F-1 | `POST /api/chat/messages` | 질문 보내기 | `202` | chat(B) | 예 |
| F-2 | `GET /api/chat/messages?afterId={id}` | 메시지 폴링·대화 복원 | `200` | chat(B) | **아니오**(D-052) |
| F-3 | `POST /api/chat/explanations` | 계산 결과 설명 요청 | `202` | chat(B) | 예 |
| F-4 | `GET /api/chat/messages/{messageId}/comparison` | 대화 비교 결과 조회 | `200` | chat(B), 계산은 calc(A) | 예 |
| F-5 | `POST /api/chat/messages/{messageId}/apply` | 대화 비교 결과를 내 계획에 적용 | `200` | chat(B) 컨트롤러 → plan(A) 서비스 | 예 |
| — | (엔드포인트 없음) 대화 기록 삭제 | 로그인·로그아웃 때 이전 대화 삭제(D-051) | — | chat(B) 서비스, auth(A)가 호출 | — |

- **F-5는 b-team-contracts A-1의 대화 쪽을 대신한다.** A-1의 `POST /api/plan/apply {source:"CHAT", chatMessageId}`는 쓰지 않는다(이유 C12b-7, C12b-10). 대안·비교 적용(`source: ALTERNATIVE/COMPARE`, Should)은 plan 컨트롤러의 조건값 적용 API로 남으며 #12-a(또는 FR-CMP 되살릴 때)에서 정한다.
- 대화 기록 삭제에 **프론트용 엔드포인트를 두지 않는다**[기획 제안]. 왜: D-051은 "로그인·로그아웃 때" 삭제이고 사용자가 따로 지우는 기능은 요구사항에 없다. 로그인·로그아웃 처리가 서버 안에서 삭제를 부른다(C12b-8).
- 모든 경로는 JWT 쿠키 인증이 필요하다. ai-server가 부르는 `/internal/**`과 필터 체인이 다르다(internal-calc C2-1).

## C12b-2. 인증·공통 헤더·공통 응답

| 항목 | 값 |
|---|---|
| 인증 | HttpOnly·Secure 쿠키의 JWT(D-052, ADR-002). 쿠키 이름·`SameSite`는 #12-a가 정한다(alignment 2-1 권장 `Lax` 이상) |
| 요청 헤더 | 본문이 있으면 `Content-Type: application/json`. 프론트는 `fetch(..., { credentials: "include" })` |
| 성공 `Content-Type` | `application/json` |
| 오류 `Content-Type` | `application/problem+json`(C12b-9) |
| 토큰 연장 | 사용자 조작 요청은 `TokenRenewalFilter`가 새 쿠키를 내린다. **F-2만 `@SkipRenewal`**(D-052, FR-AUTH-02 수용 기준 "폴링만 계속 보내도 30분 뒤 만료") |
| 만료·없는 토큰 | 모든 엔드포인트 `401 UNAUTHENTICATED`(C12b-9 예시). 프론트는 폴링을 멈추고 로그인 화면으로 보낸다 |

- 이미 있음: JWT 방식·`TokenRenewalFilter`·`@SkipRenewal` 이름(`db/moved-to-code.md` §1, ADR-002). 새로 필요: 401 본문을 C3-1 형식으로 쓰는 `AuthenticationEntryPoint`(#12-a, C12b-13 요구 2).
- **폴링이 401을 받으면 사용자 조작 없이 만료된 것**이므로 프론트는 다른 요청을 다시 보내지 않고 바로 로그인 화면으로 간다(FR-AUTH-02 예외).

## C12b-3. 메시지 모양 (F-1·F-2·F-3이 공유)

F-2가 돌려주는 메시지 한 건의 모양. `chat_message` 한 행 + 출처(`chat_message_citation` → `rag_*`).

```json
{
  "id": 1031,
  "role": "ASSISTANT",
  "messageType": "RECALC_RESULT",
  "status": "COMPLETED",
  "content": "월 저축액을 약 50만원으로 바꾸면 평균일 때 약 2,501만원으로 목표를 달성해요. 지금보다 약 789만원 증가해요.",
  "conditionChanges": { "monthlySavingAmount": 500000 },
  "citations": [],
  "createdAt": "2026-11-16T10:15:31+09:00"
}
```

| 필드 | 타입 | 뜻 |
|---|---|---|
| `id` | integer | `chat_message.id`. 회원별로 단조 증가(BIGSERIAL) |
| `role` | `USER` \| `ASSISTANT` | |
| `messageType` | `QUESTION` \| `ANSWER` \| `EXPLANATION` \| `RECALC_RESULT` \| `CLARIFY` \| `OUT_OF_SCOPE` \| `FAILURE` \| **`null`** | `schema.sql` `ck_cm_type`과 같다. **`status=PENDING`이면 `null`**[기획 제안] |
| `status` | `PENDING` \| `COMPLETED` \| `FAILED` | USER는 항상 `COMPLETED` |
| `content` | string \| null | `PENDING`이면 `null`. `FAILED`면 문구표의 실패 안내 문장(FR-AI-04) |
| `conditionChanges` | object \| null | `RECALC_RESULT`일 때만 값. **키는 camelCase**(C2-2 허용 4키). 그 밖은 `null` |
| `citations` | array | 출처. 없으면 `[]` |
| `citations[].rank` | integer | 1부터 |
| `citations[].title` | string | 문서 제목. 상품명이 들어갈 수 있다(D-028: 링크에는 상품명 허용) |
| `citations[].sourceUrl` | string | |
| `citations[].orgName` | string | 운용사·기관명 |
| `createdAt` | string | ISO-8601 |

- `PENDING`의 `messageType`을 `null`로 가리는 이유: `chat_message.message_type`은 NOT NULL이라 Spring이 질문 답변 대기 행에 자리표시 값(예: `ANSWER`)을 넣어야 한다(`ck_cm_role_type`). 그 값이 화면에 새면 프론트가 분기를 잘못 탄다. 확정 유형은 `COMPLETED`/`FAILED`에서만 의미가 있다. [코드 차이 X-3]
- `FAILED`는 항상 `messageType=FAILURE`다(FR-AI-04, `b-team-contracts` C-1). 실패 이유 코드는 응답에 넣지 않고 로그(`ai.attempt.error`)에만 남긴다. 왜: 사용자 행동이 달라지지 않는다.
- `calcRunId`는 **넣지 않는다**[기획 제안]. 왜: RECALC_RESULT의 `calcRunId`는 CHAT 기록이라 F-3에 넣으면 404가 나고, F-4·F-5는 메시지 id로 충분하다. FR-AI-05(Should, 설명 다시 요청)를 되살릴 때 `EXPLANATION`에만 더한다.
- `conditionChanges`가 있어도 **비교 숫자는 F-4로 받는다.** 메시지 목록에 비교 결과(수 KB)를 싣지 않아 폴링 응답이 작다.
- `retry_of_message_id`, `baseline_scenario`는 내보내지 않는다(화면이 쓰지 않음).

## C12b-4. F-1 질문 보내기 `POST /api/chat/messages`

요청:
```json
{ "text": "월 50만원으로 하면 어때요?" }
```

응답 `202 Accepted`:
```json
{ "userMessageId": 1030, "assistantMessageId": 1031, "status": "PENDING" }
```

| 필드 | 규칙 |
|---|---|
| `text` | 필수. 앞뒤 공백을 지운 길이가 1 이상 **2000 이하**. 2000은 ai-server `ChatRequest.text`의 `max_length`와 같다(이미 있음) |

서버 동작(한 트랜잭션):
1. 오래된 `PENDING` 정리(C12b-11-3).
2. 그 회원의 **질문 답변 대기**(F-1이 만든 ASSISTANT `PENDING`)가 있으면 `409 ANSWER_PENDING`. F-3이 만든 설명 대기는 막지 않는다[기획 제안, R-4].
3. USER(`QUESTION`, `COMPLETED`) + ASSISTANT(`PENDING`) 저장 → 내부 이벤트 `ChatAnswerRequested{assistantMessageId, memberId}` 발행(이미 있음, `modulith.md` 이벤트 표).
4. 커밋 뒤 리스너가 ai-server `POST /chat`(mode=`QUESTION`)을 부르고 결과로 행을 `COMPLETED`/`FAILED`로 바꾼다(#41).

- **계획이 없어도 질문을 받는다**(NFR-USA-01). 리스너는 `planContext: null`로 부르고 ai-server가 문구표 `chat.noPlan`으로 답한다(C1a-11). 그래서 F-1에 `NO_PLAN` 오류는 없다.
- `history`는 같은 회원의 `COMPLETED` 메시지 최근 20개(`ChatRequest.history` `max_length=20`, 이미 있음). D-051로 로그인 이후 대화만 남으므로 따로 자르지 않는다.
- 이미 목표를 넘은 계획에서도 F-1은 평소대로 받는다(C1a-11 QUESTION 처리, `/internal/calc` `ALREADY_EXCEEDED`). 대화창을 어떻게 보이는지는 **Q-051(미결)** 이다(C12b-16).

오류:

| HTTP | `code` | 언제 | `errors` |
|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | JSON 파싱 실패, `text`가 문자열이 아님 | `[]` |
| 422 | `VALIDATION_FAILED` | 빈 문자열·공백뿐 | `[{field:"text", reason:"REQUIRED"}]` |
| 422 | `VALIDATION_FAILED` | 2000자 초과 | `[{field:"text", reason:"OUT_OF_RANGE", min:1, max:2000, unit:"CHAR"}]` [기획 제안, R-7] |
| 409 | `ANSWER_PENDING` | 앞 질문의 답이 아직 `PENDING` | `[]` |
| 401 | `UNAUTHENTICATED` | 만료·없는 토큰 | `[]` |

- 프론트는 질문 답변이 `PENDING`인 동안 보내기 버튼을 막는다. 409는 같은 화면 두 탭·빠른 연타의 방어선이다(TBD-37 중복 클릭).
- 2·3 사이 경쟁(같은 회원이 동시에 두 번 보냄)은 데모 범위에서 허용한다. 왜: 버튼을 막는 것으로 충분하고, 막으려면 회원 행 잠금이 필요하다.

## C12b-5. F-2 메시지 폴링·복원 `GET /api/chat/messages?afterId={id}`

응답 `200`:
```json
{
  "messages": [
    { "id": 1030, "role": "USER", "messageType": "QUESTION", "status": "COMPLETED",
      "content": "월 50만원으로 하면 어때요?", "conditionChanges": null, "citations": [],
      "createdAt": "2026-11-16T10:15:30+09:00" },
    { "id": 1031, "role": "ASSISTANT", "messageType": null, "status": "PENDING",
      "content": null, "conditionChanges": null, "citations": [],
      "createdAt": "2026-11-16T10:15:30+09:00" }
  ],
  "hasPending": true
}
```

| 쿼리 | 규칙 |
|---|---|
| `afterId` 없음 | **복원**: 그 회원의 최근 50개를 `id` 오름차순으로(ERD Q2-a). 결과 화면에 들어올 때 1회 |
| `afterId=N` | **폴링**: `id > N`인 메시지 전부를 `id` 오름차순으로. 정수가 아니면 `400 MALFORMED_REQUEST` |

| 응답 필드 | 뜻 |
|---|---|
| `messages[]` | C12b-3 모양 |
| `hasPending` | 그 회원에게 `PENDING` 메시지가 하나라도 있는지(응답 목록 밖 포함). 프론트가 폴링을 멈출 기준 |

**프론트 폴링 규칙**[기획 제안, R-3]
- `afterId` = **가지고 있는 메시지 중 가장 작은 `PENDING` id − 1**. `PENDING`이 없으면 가지고 있는 가장 큰 id.
- 받은 메시지는 **`id`로 덮어쓴다**(upsert). 같은 메시지를 다시 받는 것은 정상이다.
- 간격 **1초**. `hasPending=false`를 받으면 멈춘다. F-1·F-3을 보내면 다시 시작한다.
- 왜 이 방식: 서버는 "클라이언트가 무엇을 봤는지"를 몰라도 되고 쿼리 파라미터가 하나다. ERD Q2-b의 `pendingIds` 파라미터는 쓰지 않는다[코드 차이 X-4]. 인덱스 `ix_chat_message_member(member_id, id)`는 그대로 쓰인다.

- 서버는 응답 전에 오래된 `PENDING`을 정리한다(C12b-11-3). 그래서 폴링은 항상 끝난다.
- **토큰을 연장하지 않는다**(`@SkipRenewal`, D-052). `401`이면 폴링을 멈추고 로그인 화면으로.
- 다른 회원의 메시지는 나오지 않는다(`member_id` 조건). `afterId`가 남의 메시지 id여도 오류 없이 자기 메시지만 나온다(존재 여부 노출 없음).

## C12b-6. F-4 대화 비교 결과 조회 `GET /api/chat/messages/{messageId}/comparison`

응답 `200`:
```json
{
  "messageId": 1031,
  "applicable": true,
  "conditions": { "current": { "...": "C2-3과 같음(4키)" }, "changed": { "...": "" } },
  "current": { "...": "C2-4 CalcResultView (monthlyPoints 키 없음)" },
  "changed": { "...": "C2-4" },
  "diff": { "...": "C2-5" },
  "display": { "...": "C2-6 키·형식 그대로" }
}
```

- 본문은 **`/internal/calc` 성공 응답(C2-3~C2-6)에서 `calcRunId`를 빼고 `messageId`·`applicable`을 더한 것**이다. 전체 예시는 internal-calc 부록 A-1과 같은 값이며 목 파일(C12b-12)에는 줄임 없이 넣는다. 왜 같은 모양: calc의 공개 타입 `CalcComparison`과 공유 `ResultDisplayBuilder`(C2-3 구현 메모, C1a-6)를 그대로 쓰고, AI 문장과 카드 숫자가 같은 `display`에서 나온다.
- `display`를 넣는 이유[기획 제안, R-6]: 프론트가 원 → 만원 반올림을 따로 구현하면 AI 문장("약 789만원 증가")과 카드가 어긋날 수 있다(TBD-16 반올림, D-055 경계). `minDisplay`류(C3-5)와 달리 이 값은 calc가 직접 만드는 응답이라 제공 비용이 없다.
- **그래프 시계열(`monthlyPoints`)은 넣지 않는다.** 대화창은 숫자 비교만(Q-039 3번 권장, 미결이라 R-6에 같이 올림). 대표 그래프는 대안 영역에만(D-039).

**계산 방식**(이미 있음: ADR-002 결과 미저장, C2-7):
- 메시지의 `calc_run(CHAT)` 행에 기록된 **계획 버전·데이터 버전·`engine_version`** 과 `chat_message.condition_changes`로 다시 계산한다. 그래서 그 뒤 내 계획이 바뀌어도 이 비교는 **당시 기준**의 숫자다(AI 문장과 같다).
- chat은 calc 공개 API를 부른다(C12b-13 요구 6). chat → calc는 이미 허용된 의존이다.

**`applicable` 판정**(D-041, 서버 힌트):
1. 이 메시지가 그 회원의 `COMPLETED` `RECALC_RESULT` 중 **id가 가장 큰 것**이고,
2. 그 `calc_run.plan_version_id`가 **지금 `plan.current_version_id`와 같을 때** `true`.
- 되돌리기 뒤의 비활성(D-041)은 이 값만으로는 보장되지 않는다(C12b-7-4, R-2). 프론트 규칙을 함께 쓴다.

오류:

| HTTP | `code` | 언제 |
|---|---|---|
| 404 | `NOT_FOUND` | 없는 id, 남의 메시지, `RECALC_RESULT`가 아님, `COMPLETED`가 아님 — **모두 같은 404** |
| 500 | `INTERNAL_ERROR` | 재계산 실패(기준 데이터 없음 등). 프론트는 카드 자리에 "비교 결과를 불러오지 못했어요"(문구표) |
| 401 | `UNAUTHENTICATED` | |

- 프론트는 F-2에서 `COMPLETED` `RECALC_RESULT`를 받으면 F-4를 부른다. 이미 받은 비교는 다시 부르지 않고, 적용·되돌리기 뒤에는 `applicable`을 다시 받지 않고 C12b-7-4 규칙으로 버튼만 바꾼다.

## C12b-7. F-5 대화 비교 결과 적용 `POST /api/chat/messages/{messageId}/apply`

확인창 없이 바로 적용한다(D-016, D-022).

요청:
```json
{ "expectedRevision": 12 }
```

응답 `200`:
```json
{ "planVersionId": 42, "previousVersionId": 41, "revision": 13, "undoAvailable": true }
```

| 필드 | 뜻 |
|---|---|
| `expectedRevision` | 프론트가 **지금 들고 있는 내 계획의 `revision`**. 출처는 #12-a의 현재 계획 응답, 직전 적용·되돌리기·입력 저장 응답 하나뿐이다(C12b-13 요구 4)[기획 제안, R-8] |
| `planVersionId` | 새 현재 계획 버전(`plan_version.source='CHAT'`) |
| `previousVersionId` | 되돌리기 대상(직전 버전) |
| `revision` | 새 revision. 프론트는 이 값으로 계획 상태를 바꾼다(되돌리기 토스트가 쓴다) |
| `undoAvailable` | 항상 `true`(적용 직후 직전 버전이 있음). 토스트 표시 여부는 프론트가 10초로 관리(D-041) |

- **`calcRunId`는 응답에 없다.** 새 버전의 `calc_run(PLAN)`은 `PlanChanged` 리스너(calc)가 비동기로 기록하기 때문이다(`modulith.md` 이벤트 표). plan이 calc를 부르면 순환이다. 결과 화면은 적용 뒤 #12-a의 현재 계획·결과 조회를 다시 부르고(FR-PLAN-03 "결과 화면 전체 갱신"), 그 조회가 기록이 없으면 계산·기록한다(ERD Q1-c). 받은 `calcRunId`로 F-3을 부른다(TBD-26: 적용 뒤에도 설명이 온다).

### C12b-7-1. 서버 검사 순서

| 순서 | 어디서 | 검사 | 결과 |
|---|---|---|---|
| 0 | 필터 | 토큰 | `401 UNAUTHENTICATED` |
| 1 | chat 컨트롤러 | 본문 파싱, `expectedRevision`이 정수 | `400 MALFORMED_REQUEST` |
| 2 | chat 서비스 | `findByIdAndMemberId`. 없음·남의 것·`RECALC_RESULT` 아님·`COMPLETED` 아님 | `404 NOT_FOUND`(F-4와 같은 규칙) |
| 3 | chat 서비스 | 그 회원의 `COMPLETED` `RECALC_RESULT` 중 가장 큰 id가 아님 | `409 STALE_COMPARISON` |
| 4 | chat 서비스 → calc | `calc_run.plan_version_id` 읽기 = **기준 버전** | (실패 없음. 행은 FK로 보장) |
| 5 | plan 서비스 | `plan` 행 없음 | `409 NO_PLAN` |
| 6 | plan 서비스 | `ConditionValidator.validate(ChangePath.CHAT, conditionChanges)` 재검증(D-033). 허용 밖 키 | `422 FIELD_NOT_CHANGEABLE` |
| 7 | plan 서비스 | 같은 검증의 범위·정수·소수 자릿수 | `422 VALIDATION_FAILED`(`min`·`max`·`unit`·`scale`, **`minDisplay`·`maxDisplay` 없음**, C3-5) |
| 8 | plan 서비스 | `plan.revision ≠ expectedRevision` | `409 PLAN_CHANGED` |
| 9 | plan 서비스 | `plan.current_version_id ≠ 기준 버전` | `409 STALE_COMPARISON` |
| 10 | plan 서비스 | `plan_version` INSERT(현재 버전 복사 + 변경 4키 + `source='CHAT'`, **`calc_start_month`는 현재 버전 값**, D-013) → `UPDATE plan ... WHERE member_id=? AND revision=?` → 0행이면 8과 같이 `PLAN_CHANGED` → `PlanChanged(APPLY)` 발행 | `200` |

- 6·7이 걸리는 경우: 비교 뒤 `rules.yml` 범위가 바뀌었을 때(TBD-09 확정 등). 평소에는 `/internal/calc`가 이미 같은 검증을 통과시켰다. 그래도 다시 하는 이유: 저장 경로의 검증을 한 곳(plan)에 고정하고, 비교 시점과 적용 시점 사이의 규칙 변경을 막는다.
- 8을 9보다 먼저 보는 이유[기획 제안, R-10]: `PLAN_CHANGED`는 "다른 곳에서 계획이 바뀌었으니 화면 전체를 다시 불러오라"이고 프론트 동작이 더 크다. 둘 다 해당하면 큰 쪽을 알려 준다.
- 6~10은 plan의 **한 트랜잭션**이다. 2~4는 chat의 읽기라 트랜잭션 밖이어도 된다(3과 10 사이에 새 비교가 끝나도 결과는 "이전 비교를 적용한 것"이라 해롭지 않다).
- 중복 클릭: 두 번째 요청은 revision이 이미 올라가 8에서 `PLAN_CHANGED`. 프론트는 요청 중 버튼을 막는다.

### C12b-7-2. 오류 응답의 프론트 동작

| `code` | 프론트 동작(문구는 문구표) |
|---|---|
| `STALE_COMPARISON` | 그 버튼을 비활성으로 바꾸고 "가장 최근 비교 결과만 적용할 수 있어요" 토스트. 계획 화면은 다시 부르지 않음 |
| `PLAN_CHANGED` | "계획이 다른 곳에서 바뀌었어요" 안내 후 결과 화면 전체 다시 불러오기(새 revision 받음). 대화창 버튼은 모두 비활성 |
| `VALIDATION_FAILED` / `FIELD_NOT_CHANGEABLE` | "지금 기준으로는 적용할 수 없는 값이에요" 안내, 버튼 비활성 |
| `NO_PLAN` | 입력 화면으로 |
| `NOT_FOUND` | 버튼 비활성(대화가 지워진 경우 등) |

### C12b-7-3. 성공 뒤 프론트 순서 (FR-AI-07, FR-PLAN-03·04, D-041)

1. 계획 상태의 `revision`을 응답 값으로 바꾼다.
2. 대화창의 **모든** 적용 버튼을 비활성으로 바꾼다(기준 버전이 바뀌어 어느 비교도 지금 계획 기준이 아님).
3. 되돌리기 토스트를 **10초** 띄운다(D-041). 토스트가 들고 있는 값은 `revision`.
4. 결과 화면 전체를 다시 불러온다(#12-a). 받은 `status`가 `CALCULATED`면 F-3을 부른다. `ALREADY_EXCEEDED`면 부르지 않는다(D-062). 대화 적용으로는 초과가 생기지 않지만(D-040) 같은 함수를 쓰므로 규칙을 하나로 둔다.

### C12b-7-4. 되돌리기 뒤 버튼 비활성 (D-041) — 프론트 규칙

- **되돌리기 성공 시점에 프론트가 가진 가장 큰 메시지 id를 기억하고(`undoBarrierId`), `id ≤ undoBarrierId`인 비교의 적용 버튼은 모두 비활성**으로 둔다. 그 뒤 새로 온 비교만 `applicable`을 따른다.
- 왜 프론트인가: 되돌리기가 포인터만 바꾸면(ERD Q4-c) 되돌린 뒤 `current_version_id`가 예전 기준 버전과 다시 같아져, 서버 검사(C12b-7-1의 3·9)로는 "되돌리기 전 비교"를 구분할 수 없다. 서버가 보장하려면 되돌리기가 새 `plan_version`을 INSERT해야 한다. 이는 #12-a의 되돌리기 방식 결정이다(R-2).
- 프론트 규칙만으로 생기는 틈: 새로 고침하면 `undoBarrierId`가 사라져, 되돌리기 전의 가장 최근 비교가 다시 `applicable=true`로 보일 수 있다. 데모 흐름(토스트 10초 안의 되돌리기)에서는 드물다고 보고 수용하는 것이 초안이다.

## C12b-8. 대화 기록 삭제 (D-051)

| 항목 | 값 |
|---|---|
| 언제 | (1) 로그인 성공 직후, 쿠키를 내리기 **전**. (2) 로그아웃 처리 중, 쿠키를 만료시키기 **전** |
| 무엇을 | 그 회원의 `chat_message` 전부. `chat_message_citation`은 FK `ON DELETE CASCADE`로 함께 지워진다(이미 있음) |
| 무엇은 남나 | `calc_run(CHAT)` 행(D-057: 정리하지 않음), 계획 |
| 어떻게 | chat 공개 API `chat.ChatHistoryCleaner.deleteAllFor(long memberId)` 한 문장 `DELETE FROM chat_message WHERE member_id = ?` |
| 누가 부르나 | auth의 로그인·로그아웃 서비스(#12-a)가 **직접 동기 호출**[기획 제안, R-5] |

- 동기 호출인 이유: 이벤트(`@ApplicationModuleListener`, 커밋 뒤 비동기)로 하면 로그인 응답 직후 프론트의 F-2 복원이 삭제보다 먼저 돌아 이전 대화가 잠깐 보인다(NFR-INT-03 수용 기준 위반).
- 의존 방향: auth → chat이 새로 생긴다. chat은 auth에 의존하지 않으므로 순환이 아니다(C12b-10).
- `retry_of_message_id`(자기 참조 FK, CASCADE 아님): 한 문장으로 회원의 행을 모두 지우므로 문장 끝 검사에서 위반이 없다(PostgreSQL의 `NO ACTION`은 문장 끝에 검사).
- **진행 중인 PENDING**: 삭제 뒤 ai 응답이 도착하면 리스너의 갱신은 0행이다. 리스너는 이를 오류로 보지 않고 버린다(재시도 금지). 이벤트 재처리(`event_publication`)에서도 행이 없으면 아무것도 하지 않는다(C12b-11-2).
- 만료로 끝난 대화는 다음 로그인 때 지워진다(NFR-INT-03 예외 수용 기준).
- 로그아웃 엔드포인트 자체(경로·응답)는 #12-a다.

## C12b-9. 오류 공통 규칙과 코드 표

형식은 internal-calc **C3-1 그대로**다. `type`, `title`, `status`, `detail`, `instance`(선택) + `code`(필수) + `errors`(필수, 없으면 `[]`).

| HTTP | `code` | 엔드포인트 | 언제 | `errors` |
|---|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | F-1, F-2, F-3, F-5 | JSON 파싱 실패, 타입 불일치, `afterId`·`messageId` 정수 아님 | `[]` |
| 401 | `UNAUTHENTICATED` | 전부 | 쿠키 없음·서명 불일치·만료 | `[]` |
| 404 | `NOT_FOUND` | F-3, F-4, F-5 | 없음·남의 것·조건에 안 맞는 대상(각 절) | `[]` |
| 409 | `ANSWER_PENDING` | F-1 | 질문 답변 대기 중 | `[]` |
| 409 | `NO_PLAN` | F-5 | 저장된 계획 없음 | `[]` |
| 409 | `PLAN_CHANGED` | F-5 | `expectedRevision` 불일치 | `[]` |
| 409 | `STALE_COMPARISON` | F-5 | 가장 최근 비교가 아님, 또는 기준 버전 ≠ 현재 계획 | `[]` |
| 422 | `VALIDATION_FAILED` | F-1, F-5 | 필드 검증 실패 | 1개 이상 |
| 422 | `FIELD_NOT_CHANGEABLE` | F-5 | 저장된 변경에 대화로 못 바꾸는 키 | 1개 이상 |
| 500 | `INTERNAL_ERROR` | 전부 | 예상하지 못한 서버 오류, F-4 재계산 실패. `detail`에 내부 메시지 없음 | `[]` |

- `MALFORMED_REQUEST`, `VALIDATION_FAILED`, `FIELD_NOT_CHANGEABLE`, `NO_PLAN`, 형식은 internal-calc C3-2와 같은 이름·뜻이다. 이 계약이 더하는 코드: `UNAUTHENTICATED`, `NOT_FOUND`, `ANSWER_PENDING`, `PLAN_CHANGED`, `STALE_COMPARISON`, `INTERNAL_ERROR`(C3-5 "코드는 각 계약에서 더한다"). `NOTHING_TO_UNDO`는 #12-a(되돌리기)가 더한다.
- `errors[]`: `field`, `reason`, `min`·`max`·`unit`(OUT_OF_RANGE), `scale`(TOO_MANY_DECIMALS). **`minDisplay`·`maxDisplay`는 프론트 API에 없다**(C3-1, C3-5). 프론트는 `min`·`max`·`unit`과 자기 화면 단위(만원 등)로 표시한다.
- `unit`에 `CHAR`(글자 수)를 더한다[기획 제안, R-7]. C3-1의 `KRW`/`MONTH`/`PCT` 외 값이다. 받는 쪽은 모르는 값을 무시하는 원칙(0-6)이라 ai-server에는 영향이 없다(이 경로는 ai-server가 받지 않음).
- `404`는 `@RestControllerAdvice`(#17, G-15b)가, `401`은 리소스 서버 `AuthenticationEntryPoint`(#12-a)가 쓴다. `401`은 필터에서 나오므로 `instance`가 없을 수 있다(internal-calc C2-1과 같음).
- 403은 쓰지 않는다. 소유권 위반은 404다(존재 여부를 숨김).

예시:

```json
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json

{ "type": "about:blank", "title": "로그인이 필요해요", "status": 401, "code": "UNAUTHENTICATED", "errors": [] }
```

```json
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json

{
  "type": "about:blank",
  "title": "입력 범위를 벗어났어요",
  "status": 422,
  "detail": "monthlySavingAmount: OUT_OF_RANGE",
  "instance": "/api/chat/messages/1031/apply",
  "code": "VALIDATION_FAILED",
  "errors": [
    { "field": "monthlySavingAmount", "reason": "OUT_OF_RANGE", "min": 10000, "max": 5000000, "unit": "KRW" }
  ]
}
```
(예시는 비교 뒤 `rules.yml` 상한이 500만원으로 바뀐 경우. `minDisplay`·`maxDisplay` 키가 없다.)

```json
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{ "type": "about:blank", "title": "가장 최근 비교 결과만 적용할 수 있어요", "status": 409,
  "instance": "/api/chat/messages/1029/apply", "code": "STALE_COMPARISON", "errors": [] }
```

```json
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{ "type": "about:blank", "title": "계획이 바뀌었어요", "status": 409,
  "instance": "/api/chat/messages/1031/apply", "code": "PLAN_CHANGED", "errors": [] }
```

```json
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{ "type": "about:blank", "title": "앞 질문의 답을 기다리고 있어요", "status": 409,
  "instance": "/api/chat/messages", "code": "ANSWER_PENDING", "errors": [] }
```

```json
HTTP/1.1 404 Not Found
Content-Type: application/problem+json

{ "type": "about:blank", "title": "찾을 수 없어요", "status": 404,
  "instance": "/api/chat/explanations", "code": "NOT_FOUND", "errors": [] }
```

(`title` 문구는 임시이며 #18 이후 문구표로 옮긴다. 프론트는 `title`을 화면에 쓰지 않는다.)

## C12b-10. 모듈 의존 방향과 호출 순서 (핵심)

### C12b-10-1. 결정 대상: chatMessageId 적용 API를 어디에 두나

| 안 | 위치 | 의존 | 판단 |
|---|---|---|---|
| **A (제안)** | **chat 컨트롤러** `POST /api/chat/messages/{id}/apply` → chat 서비스가 메시지를 확인하고 **plan 공개 서비스(조건값 적용)** 를 부름 | chat → plan **추가**. plan은 그대로 `{}` | 순환 없음. plan은 "조건값을 받는 적용"만 알고 대화를 모른다. 대화 적용 규칙(가장 최근 비교, D-041)은 대화를 아는 chat에 있다 |
| B | plan 컨트롤러 `POST /api/plan/apply {source:"CHAT", chatMessageId}`(b-team-contracts A-1 초안) | plan → chat 필요 | **순환**: chat → calc → plan → chat. `ModularityTests` 실패. 채택 불가 |
| C | plan 컨트롤러가 조건 값을 브라우저에서 받음 `{source:"CHAT", conditionChanges}` | 의존 추가 없음 | 순환은 없지만 비교 결과와 다른 값을 브라우저가 보낼 수 있다. D-033("검증 통과한 비교만 적용")·원칙 0-4를 어김. "가장 최근 비교" 검사도 할 수 없다 |
| D | chat이 이벤트(`ChatApplyRequested`)를 내고 plan이 받음 | plan → chat(이벤트 타입이 chat 루트에 있으므로) | 이벤트 수신도 의존이라 순환. 게다가 비동기라 HTTP 응답에 새 revision을 줄 수 없다 |

**제안: A.** 한 줄 이유: 의존을 "대화를 아는 쪽 → 계획을 아는 쪽" 한 방향으로만 두면 순환 없이 D-033·D-041을 서버에서 지킬 수 있다.

### C12b-10-2. 바뀌는 의존 (`package-info.java`)

| 모듈 | 지금 | 이 계약 뒤 | 이유 |
|---|---|---|---|
| `plan` | `{}` | `{}` (변경 없음) | 대화를 모른다 |
| `calc` | `{plan, refdata}` | 변경 없음 | |
| `chat` | `{calc, rag}` | **`{calc, rag, plan}`** | F-5에서 plan 적용 서비스, F-4 `applicable`에서 현재 계획 조회 |
| `auth` | `{}` | **`{chat}`** | 로그인·로그아웃 때 대화 삭제(C12b-8, R-5) |

의존 그래프(화살표 = 부를 수 있음):
```
auth ──▶ chat ──▶ calc ──▶ plan
           │        └────▶ refdata
           ├──────▶ plan
           └──────▶ rag
```
- 어느 경로에도 되돌아오는 화살표가 없다. **plan → (chat, calc)**, **calc → chat**, **chat → auth** 가 생기지 않으면 `ModularityTests`가 통과한다.
- 지켜야 할 것: plan 공개 API의 인자·반환에 chat·calc 타입을 쓰지 않는다(plan이 그 타입을 import하면 plan → chat/calc 의존이 생김). 그래서 기준 버전은 `long`, 조건 변경은 `Map<String, JsonNode>`로 받는다(C12b-13 요구 1).
- `backend/CLAUDE.md` 모듈 표의 "의존 가능" 칸도 같이 고친다(H-6, H-9).

### C12b-10-3. 호출 순서

**F-1 / F-3 (비동기 답변)**
```
브라우저 ─POST /api/chat/messages─▶ chat.web
  chat.application: 오래된 PENDING 정리 → ANSWER_PENDING 검사 → USER + ASSISTANT(PENDING) 저장 → ChatAnswerRequested 발행  (한 트랜잭션)
  ◀─202 {userMessageId, assistantMessageId}
[커밋 뒤, 비동기] chat 리스너(#41, 트랜잭션 없이 — C1a-10 G-9a)
  calc.PlanContextProvider.findForCurrentPlan / findForCalcRun  (chat → calc)
  ai-server POST /chat (타임아웃 C12b-11)   ── ai-server ─POST /internal/calc─▶ calc (필요할 때)
  짧은 트랜잭션: COMPLETED/FAILED 갱신 + citation 저장 (행이 없으면 버림)
브라우저 ─GET /api/chat/messages?afterId─▶ (1초 간격, @SkipRenewal) ... hasPending=false면 멈춤
```

**F-4 (비교 조회)**
```
브라우저 ─GET /api/chat/messages/{id}/comparison─▶ chat.web
  chat: findByIdAndMemberId, RECALC_RESULT·COMPLETED 확인
  calc 공개 API: (calcRunId, conditionChanges) → CalcComparison + display, 기준 버전 id   (chat → calc)
  plan 공개 API: 현재 계획 current_version_id                                          (chat → plan)
  chat: applicable 계산
  ◀─200
```

**F-5 (적용)**
```
브라우저 ─POST /api/chat/messages/{id}/apply {expectedRevision}─▶ chat.web
  chat: 메시지 확인(404) → 가장 최근 비교인지(409 STALE_COMPARISON)
  calc 공개 API: calc_run.plan_version_id = 기준 버전                                   (chat → calc)
  plan.PlanApplyService.apply(memberId, CHAT, conditionChanges, expectedRevision, 기준 버전)   (chat → plan)
     └ plan 한 트랜잭션: NO_PLAN → 재검증 → PLAN_CHANGED → STALE_COMPARISON → INSERT·UPDATE → PlanChanged(APPLY) 발행
  ◀─200 {planVersionId, previousVersionId, revision, undoAvailable}
[커밋 뒤, 비동기] calc 리스너: 새 버전 calc_run(PLAN) 기록 (이미 있음)
브라우저: 결과 화면 다시 불러오기(#12-a) → status=CALCULATED면 F-3
```

**로그인·로그아웃 (C12b-8)**
```
브라우저 ─(#12-a 로그인/로그아웃)─▶ auth
  auth: 인증 성공(또는 로그아웃 요청) → chat.ChatHistoryCleaner.deleteAllFor(memberId)  (auth → chat, 동기)
  auth: 쿠키 발급(또는 만료) → 응답
```

## C12b-11. 시간 값과 PENDING 처리

### C12b-11-1. 임시값 (TBD-33 실측 전) [기획 제안, R-3]

| 값 | 제안 | 근거 |
|---|---|---|
| 폴링 간격 | **1초**, `hasPending=false`면 멈춤 | FR-AI-01 "뒤이어 도착"의 체감. `PENDING`이 있을 때만 돌아 요청 수가 작다(ERD §4: 폴링은 PK·키셋 조회) |
| Spring → ai-server 연결 타임아웃 | **2초** | 같은 Compose 네트워크라 연결이 늦으면 서버가 죽은 것 |
| Spring → ai-server 응답 타임아웃 | **30초** | b-team-contracts F-2·alignment 2-8의 임시값. 도구 호출 1~2회 + 생성 |
| 오래된 `PENDING` 기준 | **60초**(`created_at` 기준) | 응답 타임아웃 30초 + 재기동·재처리 여유. 이보다 오래된 `PENDING`은 실패로 본다 |
| 프론트 폴링 안전 상한 | 없음 | 서버가 60초 안에 반드시 `FAILED`로 바꾸므로 프론트가 따로 끊지 않는다 |

- 값은 Spring `application.yml`(설정 키)과 프론트 상수 한 곳에 둔다. TBD-33이 정해지면 그 두 곳만 바꾼다.
- ai-server → Spring `/internal/calc` 타임아웃(ai-server 설정)은 응답 타임아웃 30초보다 작아야 한다(예: 10초). 이 계약 범위 밖이며 H-2에 메모로 넘긴다.

### C12b-11-2. 리스너 규칙 (#41에 요구)

- 시작할 때 행이 `PENDING`이 아니면(이미 `FAILED`로 정리됐거나 삭제됨) **ai-server를 부르지 않고 끝낸다.** 왜: `event_publication` 재처리로 같은 이벤트를 두 번 받아도 결과가 같아야 한다(`modulith.md`).
- 응답 타임아웃·연결 실패·ai 4xx/5xx·planContext 생성 실패 → `FAILED`·`FAILURE`, `content` = 문구표 `chat.failed`(FR-AI-04).
- 갱신이 0행(삭제됨)이면 버린다(C12b-8).

### C12b-11-3. 오래된 PENDING 정리 [기획 제안, R-9]

- F-1·F-2·F-3이 처리 전에 그 회원의 `status='PENDING' AND created_at < now() − 60초` 행을 `FAILED`·`FAILURE`·`chat.failed`로 바꾼다(`ix_chat_message_pending` 사용).
- 왜 스케줄러가 아니라 읽을 때 정리하나: 새 실행 단위(`@Scheduled`)·동시 실행 고려 없이, 사용자가 볼 때 항상 정리된 상태다. 리스너가 죽거나 재기동 중이어도 `ANSWER_PENDING`이 영원히 걸리지 않는다.
- 그 뒤 늦게 도착한 ai 응답은 C12b-11-2 규칙("`PENDING`이 아니면 갱신하지 않음")으로 버린다. 갱신 쿼리에 `AND status='PENDING'`을 붙인다.

## C12b-3a. (보충) F-3 설명 요청 `POST /api/chat/explanations`

> 번호는 C12b-4~7 사이 흐름을 깨지 않으려고 여기에 둔다. 항목 ID는 **C12b-3a**.

요청:
```json
{ "calcRunId": 540 }
```

응답 `202`:
```json
{ "assistantMessageId": 1029, "status": "PENDING" }
```

- **호출 조건**: 결과 화면이 #12-a의 계산 결과를 그린 직후(최초 결과 보기, 입력 수정, 적용 뒤, 되돌리기 뒤 — TBD-26) 그 응답의 `calcRunId`(PLAN 기록)로 부른다(FR-AI-01).
- **이미 목표를 넘은 계획(FR-RES-01 초과 안내, `status=ALREADY_EXCEEDED`)에서는 F-3을 부르지 않는다**(D-062). 결과 화면은 초과 안내만 보이고 대화창에 설명·실패 안내가 오지 않는다(FR-RES-01 수용 기준). 그래도 불리면 서버는 정상 처리하고 ai-server가 LLM 없이 `chat.alreadyExceeded` 문장으로 답한다(C1a-8 검사 4, 방어용).
- **404 규칙**(C1a-10, G-15a): **없는 `calcRunId`, 남의 기록, PLAN이 아닌(CHAT) 기록은 모두 같은 `404 NOT_FOUND`** 다. 왜: id를 추측해 남의 계산 존재 여부를 알 수 없게 한다. 판단은 `calc.PlanContextProvider.findPlanRun(memberId, calcRunId)` 하나가 empty인지로 한다(한 경로라 일관됨).
- 서버 동작: 오래된 PENDING 정리 → `findPlanRun` → ASSISTANT(`EXPLANATION`, `PENDING`, `calc_run_id`, `baseline_scenario` = `PlanRunRef.baselineScenario`) 저장 → `ChatAnswerRequested` → 리스너가 mode=`EXPLAIN`으로 부름(#43, G-9b).
- **같은 `calcRunId`로 이미 `PENDING`인 설명이 있으면 새 행을 만들지 않고 그 `assistantMessageId`로 `202`** [기획 제안, R-4]. 왜: React 개발 모드의 effect 두 번 실행, 결과 화면 재진입으로 같은 설명이 두 번 생기지 않게 한다.
- F-3은 `ANSWER_PENDING`으로 막지 않는다(R-4). 설명은 사용자가 누르는 것이 아니라 화면이 부르는 것이라, 막으면 설명이 빠진다.
- `retryOfMessageId`(FR-AI-05, Should)는 이번 범위 밖. 되살리면 같은 엔드포인트에 선택 필드로 더한다(b-team-contracts F-3).

오류: `400 MALFORMED_REQUEST`(`calcRunId` 정수 아님), `404 NOT_FOUND`, `401 UNAUTHENTICATED`. `422`·`409`는 없다.

## C12b-12. 목(mock) JSON 목록 (`frontend/src/mocks/chat/`)

**파일 형식**[기획 제안]: 응답 하나 = 파일 하나. 상태 코드와 헤더를 함께 담아 `fetch` 래퍼가 그대로 `Response`로 만든다. 새 라이브러리(MSW 등) 없이 래퍼 안에서 "요청 키 → 파일" 표로 분기한다.
```json
{
  "status": 409,
  "headers": { "Content-Type": "application/problem+json" },
  "body": { "type": "about:blank", "title": "가장 최근 비교 결과만 적용할 수 있어요", "status": 409, "code": "STALE_COMPARISON", "errors": [] }
}
```
- 시나리오 선택(정상/오류)은 래퍼 구현(#12 또는 프론트 초기 설정 Issue) 몫이다. 계약은 파일 이름과 내용만 정한다.
- `body`는 **줄임표 없이** 이 문서의 예시 값으로 채운다. F-4 정상은 internal-calc 부록 A-1 응답에서 `calcRunId`를 지우고 `messageId: 1031`, `applicable: true`를 더한다.

| 파일 | 엔드포인트 | HTTP | 내용 |
|---|---|---|---|
| `post-messages.202.json` | F-1 | 202 | C12b-4 응답 |
| `post-messages.422-required.json` | F-1 | 422 | `text` REQUIRED |
| `post-messages.422-too-long.json` | F-1 | 422 | `text` OUT_OF_RANGE `min 1, max 2000, unit CHAR` |
| `post-messages.409-answer-pending.json` | F-1 | 409 | `ANSWER_PENDING` |
| `get-messages.200-restore-empty.json` | F-2 | 200 | `{messages: [], hasPending: false}`(로그인 직후) |
| `get-messages.200-pending.json` | F-2 | 200 | C12b-5 예시(USER + ASSISTANT PENDING, `hasPending: true`) |
| `get-messages.200-recalc.json` | F-2 | 200 | USER + `RECALC_RESULT` COMPLETED(`conditionChanges` 있음), `hasPending: false` |
| `get-messages.200-explanation-citations.json` | F-2 | 200 | `EXPLANATION` COMPLETED, `citations` 2개(서로 다른 운용사, FR-AI-03) |
| `get-messages.200-failed.json` | F-2 | 200 | `FAILURE`/`FAILED`, `content` = 실패 안내 |
| `get-messages.200-clarify.json` | F-2 | 200 | `CLARIFY`(범위 밖 값 되묻기, D-033) |
| `get-messages.401.json` | F-2 | 401 | `UNAUTHENTICATED`(폴링 중 만료) |
| `post-explanations.202.json` | F-3 | 202 | C12b-3a 응답 |
| `post-explanations.404.json` | F-3 | 404 | `NOT_FOUND` |
| `get-comparison.200.json` | F-4 | 200 | internal-calc A-1 기반 전체 본문, `applicable: true` |
| `get-comparison.200-not-applicable.json` | F-4 | 200 | 같은 본문, `applicable: false` |
| `get-comparison.404.json` | F-4 | 404 | `NOT_FOUND` |
| `post-apply.200.json` | F-5 | 200 | C12b-7 응답 |
| `post-apply.409-plan-changed.json` | F-5 | 409 | `PLAN_CHANGED` |
| `post-apply.409-stale.json` | F-5 | 409 | `STALE_COMPARISON` |
| `post-apply.422-validation.json` | F-5 | 422 | C12b-9 예시(`min`·`max`·`unit`, display 키 없음) |
| `post-apply.404.json` | F-5 | 404 | `NOT_FOUND` |
| `common.401-unauthenticated.json` | 전부 | 401 | C12b-9 401 예시. 래퍼의 공통 401 분기 테스트용 |

- Issue 수용 기준 "정상, 422, 401, 409를 모두 받을 수 있다": F-1(202·422·409), F-2(200·401), F-5(200·409·422), 공통 401이 모두 있다. 404도 있다.

## C12b-13. #12-a(및 A팀)에 요구하는 것

#12-b가 동작하려면 A팀 쪽에 아래가 있어야 한다. #12-a 협상의 입력으로 넘긴다.

| # | 요구 | 담당(추정) | 왜 |
|---|---|---|---|
| 1 | **plan 공개 적용 서비스**(아래 시그니처). 검사 순서는 C12b-7-1의 5~10 | A, plan(#19 또는 적용 Issue, 번호 확인 필요) | F-5가 부른다. 대안·비교 적용(Should)도 같은 서비스를 `expectedBaseVersionId=null`로 쓴다 |
| 2 | 401 `AuthenticationEntryPoint`가 C3-1 형식(`code=UNAUTHENTICATED`, `errors=[]`, `application/problem+json`) | A, auth/config(#12-a) | Issue 수용 기준(예외) |
| 3 | `@SkipRenewal`(또는 같은 장치)을 F-2에 붙일 수 있음 | A, auth/config | D-052 |
| 4 | 현재 계획·결과 조회 응답에 **`revision`, `calcRunId`(PLAN), `result.status`** | A, #12-a(#29·#30) | F-5 `expectedRevision`, F-3 `calcRunId`, D-062 판단 |
| 5 | 되돌리기 응답에 새 **`revision`**. 되돌리기 방식(포인터 교체 vs 새 버전 INSERT) 결정 | A, #12-a | C12b-7-4, R-2 |
| 6 | calc 공개 API: (a) `calcRunId` → `plan_version_id`, (b) `(calcRunId, conditionChanges)` → `CalcComparison` + `display`(F-4 재계산) | A, calc(#32/#44 중 번호 확인 필요) | F-4·F-5. `/internal/calc`와 같은 계산·같은 `ResultDisplayBuilder` |
| 7 | plan 공개 현재 계획 조회에 `currentVersionId` | A, plan(#19, G-12와 같은 API) | F-4 `applicable` |
| 8 | 로그인 성공·로그아웃 처리에서 `chat.ChatHistoryCleaner.deleteAllFor(memberId)`를 **쿠키 응답 전에 동기 호출**, auth `package-info`에 `chat` 추가 | A, auth(#12-a) | D-051, C12b-8, R-5 |
| 9 | 전역 `@RestControllerAdvice`가 C12b-9의 코드를 같은 형식으로 냄(`NOT_FOUND` 포함) | A, #17 | G-15b와 같은 곳 |
| 10 | 되돌리기 뒤 결과 화면이 F-3을 다시 부름(TBD-26)과 D-062 규칙을 결과 화면 공통 함수 하나로 | A·B, #49·#54 | C12b-7-3 |

요구 1 시그니처(초안, 세부는 제공자 재량. 인자·검사 순서·예외 종류는 계약):
```java
// plan 루트 패키지(공개 API). chat·calc 타입을 쓰지 않는다(의존 방향).
public interface PlanApplyService {
    /**
     * 바꾼 조건을 현재 계획에 적용한다. 한 트랜잭션. 시작월은 현재 버전 값(D-013).
     * @param expectedBaseVersionId 비교의 기준 버전. null이면 검사하지 않음(대안·비교 적용)
     */
    PlanApplyResult apply(long memberId, ChangePath path, Map<String, JsonNode> conditionChanges,
                          long expectedRevision, Long expectedBaseVersionId);
}
public record PlanApplyResult(long planVersionId, Long previousVersionId, long revision) {}
// 예외(plan 루트): NoPlanException(NO_PLAN), ConditionViolationException(VALIDATION_FAILED/FIELD_NOT_CHANGEABLE, 이미 있음),
//                 PlanChangedException(PLAN_CHANGED), StaleBaseVersionException(STALE_COMPARISON)
```
- `ChangePath.CHAT` → `plan_version.source='CHAT'`. 이미 있음: `ChangePath`, `ConditionValidator`(`db/moved-to-code.md`). 새로 필요: 서비스·결과·예외 3개.
- `Map<String, JsonNode>`인 이유: `/internal/calc`와 같은 검증 입력(internal-calc C2-2 "받는 방식")이라 `FIELD_NOT_CHANGEABLE`·`NOT_INTEGER`를 같은 코드로 낸다.
- ERD Q4-b의 SQL에 기준 버전 검사를 더한다: 같은 트랜잭션에서 `plan`을 읽어 `current_version_id = :base`인지 본 뒤 `UPDATE ... WHERE revision = :expected`[코드 차이 X-6].

## C12b-14. ai-server에 미치는 영향

- 없음(새 필드·새 엔드포인트 없음). F-1·F-3은 지금의 `ChatRequest`·`ChatResponse`를 그대로 쓴다.
- 단, `ChatResponse.conditionChanges`의 키 표기(지금 snake_case, `ConditionChanges.changed()`)와 프론트 API의 camelCase가 다르다. 변환 위치는 #44(F-16)에서 정한다. 이 계약은 **프론트에 나가는 키는 camelCase**만 정한다. (권장: chat이 저장할 때 camelCase로 맞춤. `/internal/calc` 요청 키·F-4 재계산 입력과 같은 표기라 변환이 한 번뿐)

## C12b-15. moeun 현재 코드·문서와 다른 곳

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| X-1 | `backend/.../chat/package-info.java` | `allowedDependencies = {"calc", "rag"}` | `{"calc", "rag", "plan"}` | H-6 |
| X-2 | `backend/.../auth/package-info.java`, `backend/CLAUDE.md` 모듈 표 | auth 의존 없음 | auth → chat | H-9 |
| X-3 | `chat_message` PENDING 행의 `message_type` | 정한 곳 없음(NOT NULL) | 질문 대기는 자리표시 값, 화면에는 `null` | H-3 |
| X-4 | `db/erd.md` §4 Q2-b | `id > last_seen OR id = ANY(pending_ids)` | `id > afterId` 하나, 프론트가 afterId를 가장 작은 PENDING 앞으로 | H-3 (문서 한 줄) |
| X-5 | `db/erd.md` §5-G, ADR-002 §2-5 | "로그아웃은 클라이언트가 토큰을 지움" | 서버 로그아웃 + 대화 삭제(D-051, D-052) | #12-a, 문서 |
| X-6 | `db/erd.md` §4 Q4-b | revision만 검사 | + 기준 버전 검사(STALE_COMPARISON) | H-7 |
| X-7 | `ai-server/app/schemas.py` `ConditionChanges.changed()` | snake_case 키 저장 | 프론트 API는 camelCase | #44(F-16) |
| X-8 | `b-team-contracts.md` §3·§4 A-1 | `POST /api/plan/apply {source:"CHAT", chatMessageId}`, F-4 `planRevision` | F-5 `POST /api/chat/messages/{id}/apply`, `planRevision` 없음 | H-12 |
| X-9 | `backend/.claude/rules/modulith.md` 이벤트 표 | — | 변경 없음(삭제는 이벤트가 아니라 직접 호출) | — |

## C12b-16. 열린 질문(Q-051~055)의 영향 — 정하지 않고 영향만

| 질문 | 이 계약에 미치는 영향 |
|---|---|
| Q-051 초과 계획의 대화창 | A·B: API 변경 없음(B는 프론트가 문구표 한 줄을 그림, `chat_message`에 저장 안 함). C: F-1을 초과 계획에서 막으려면 `409 ALREADY_EXCEEDED`를 F-1에 더해야 함. 목 파일 1개 추가 |
| Q-052 질문 예시 버튼(Should) | A: 변경 없음(버튼 문구가 F-1 `text`로 감). B: Spring이 버튼 문장을 만드는 새 엔드포인트 필요(이 계약 밖, 새 협상) |
| Q-053 `±1만원 미만` 부호 | F-4 `display` 문자열 하나가 바뀔 수 있음. 목 파일의 A-1 값에는 해당 경계가 없어 영향 없음 |
| Q-054 대화 고지 | A: 프론트 고정 한 줄, API 변경 없음. B: ai-server가 `content` 끝에 덧붙임, 모양 변경 없음 |
| Q-055 세금 질문 경계 | 없음(프롬프트·문구표) |

## C12b-17. Issue #12 수용 기준 대응표 (#12-b 범위)

| # | 수용 기준 | 이 문서 | 비고 |
|---|---|---|---|
| 1 | 각 엔드포인트의 요청·응답·오류 코드 예시(`PLAN_CHANGED`, `STALE_COMPARISON`, `NOTHING_TO_UNDO`, `ANSWER_PENDING` 등) | C12b-3a·4~7, C12b-9 예시 | `NOTHING_TO_UNDO`는 되돌리기(#12-a)에서 |
| 2 | chatMessageId 적용에서 plan → chat 의존이 생기지 않는 호출 방향 | C12b-10 | |
| 3 | 목 JSON으로 정상·422·401·409 응답 | C12b-12 | |
| 4 | (예외) 401 예시가 C3-1 형식(`UNAUTHENTICATED`, `errors=[]`, `application/problem+json`) | C12b-2, C12b-9 | 구현은 #12-a(요구 2) |
| 5 | 422 `errors[]`에 `min`·`max`·`unit` 있고 `minDisplay`·`maxDisplay` 없음 | C12b-9 422 예시, C12b-7-1 순서 7 | |
| 6 | (예외) F-3: 없는 calcRunId·남의 기록·CHAT 기록 모두 같은 `404 NOT_FOUND` | C12b-3a | G-15c 문장 1 |
| 7 | F-3: 이미 목표를 넘은 계획은 F-3을 부르지 않음(D-062) | C12b-3a, C12b-7-3 | G-15c 문장 2 |
| 완료 조건 | backend 의존 방향이 ModularityTests를 깨지 않음 | C12b-10-2 | |

## C12b-18. 이 계약 때문에 생기는 후속 작업 (D-058: 기존 Issue 본문에 반영)

> Issue 번호는 최종본 `plan-context.md` 표에서 확인된 것만 적었다. "번호 확인 필요"는 검토자가 moeun Issue를 조회해 채운다.

| # | 작업 | 팀 | Issue |
|---|---|---|---|
| H-1 | 최종본의 B 부분을 `docs/api/frontend-api.md`로 옮기고 C12b-12 목 파일 22개를 `frontend/src/mocks/chat/`에 둠 | 공통 | **#12** |
| H-2 | 리스너: `PENDING` 아니면 미호출, 0행 갱신 버림, 갱신에 `AND status='PENDING'`, 연결 2초·응답 30초 타임아웃(설정 키), 실패 → `chat.failed`. ai-server `/internal/calc` 타임아웃 < 30초 메모 | B | **#41** |
| H-3 | F-1·F-2 컨트롤러·서비스: `ANSWER_PENDING`(질문 대기만), 오래된 PENDING 정리(60초), `afterId` 폴링·복원 50개, `hasPending`, PENDING `messageType=null`, `@SkipRenewal`, 출처 일괄 조회(ERD Q2-c). `db/erd.md` Q2-b 문장 정정 | B | 번호 확인 필요 |
| H-4 | F-3: `findPlanRun` 404 한 경로, 같은 `calcRunId` PENDING 재사용, `ANSWER_PENDING` 제외 | B | **#43**(G-9b·G-15a와 같은 Issue) |
| H-5 | F-4: calc 공개 API로 재계산, `display` 포함, `monthlyPoints` 없음, `applicable` 판정, 404 규칙, camelCase 키(F-16) | B | **#44** |
| H-6 | F-5 chat 컨트롤러·서비스(검사 1~4), chat `package-info`에 `plan`, `backend/CLAUDE.md` 모듈 표 | B | 번호 확인 필요(대화 적용) |
| H-7 | `PlanApplyService`·`PlanApplyResult`·예외 3개, 검사 5~10, 기준 버전 검사, `PlanChanged(APPLY)`. `db/erd.md` Q4-b 정정 | A | 번호 확인 필요(#19 또는 적용 Issue) |
| H-8 | calc 공개 API(요구 6): `calcRunId → planVersionId`, `(calcRunId, conditionChanges) → CalcComparison + display` | A | 번호 확인 필요(#32 또는 #44 선행) |
| H-9 | auth: 로그인·로그아웃에서 `ChatHistoryCleaner` 동기 호출, auth `package-info`에 `chat`. chat: `ChatHistoryCleaner` | A·B | #12-a 로그인·로그아웃 Issue(번호 확인 필요) + chat Issue |
| H-10 | 전역 오류 처리에 `ANSWER_PENDING`, `PLAN_CHANGED`, `STALE_COMPARISON`, `NO_PLAN`, `INTERNAL_ERROR`, `NOT_FOUND`. 401 엔트리 포인트 | A | **#17**, #12-a |
| H-11 | 프론트 대화창: 폴링 규칙, F-4 호출 시점, 적용 성공 뒤 순서(C12b-7-3), 되돌리기 뒤 `undoBarrierId`(C12b-7-4), 오류별 동작(C12b-7-2), D-062 | B(A 협업) | **#54**(+ #49 교차참조) |
| H-12 | `b-team-contracts.md` §3·§4 A-1·§6, `alignment.md` 2-4의 적용 API 위치를 이 계약으로 정정 | 기획 | 문서 |

---

## 검토 요청 (R-x)

| # | 질문 | 기획 초안 | 대안 | 누가 보면 좋나 |
|---|---|---|---|---|
| **R-1** | **적용 API 위치와 의존 방향(핵심)** | 안 A: chat 컨트롤러 F-5 + chat → plan 의존 추가, plan은 조건값 적용 서비스만 공개(C12b-10) | C(브라우저가 값 전송)는 D-033 위반, B·D는 순환 | 제공자(plan 담당 A팀)·소비자(chat 담당 B팀) 모두 |
| R-2 | 되돌리기 뒤 이전 비교 버튼 비활성(D-041)을 누가 보장하나 | 프론트 `undoBarrierId` 규칙. 새로 고침 뒤 틈은 수용 | 되돌리기가 새 `plan_version`(source 복사)을 INSERT하면 서버 검사 9만으로 보장. 단 #12-a 되돌리기 방식·ERD Q4-c·`plan_version` 수 증가 | #12-a와 함께. 쟁점이 되면 Q로 |
| R-3 | 시간 임시값 | 폴링 1초, ai 연결 2초·응답 30초, 오래된 PENDING 60초 | 폴링 2초(요청 수 절반, 체감 지연 +1초) | 양쪽. TBD-33 실측 뒤 조정 |
| R-4 | `ANSWER_PENDING` 범위와 F-3 중복 | 질문 대기만 막음. F-3은 막지 않고 같은 `calcRunId` PENDING이면 같은 id 반환 | 모든 PENDING을 막음(설명 생성 중 10~30초 질문 불가) | 소비자(B), 프론트 |
| R-5 | 대화 삭제 호출 방식 | auth → chat 동기 직접 호출(auth `package-info`에 `chat`) | 이벤트(`MemberLoggedIn`)+비동기: auth 의존은 깨끗하지만 로그인 직후 이전 대화가 잠깐 보이는 경쟁 | 제공자(auth 담당 A팀) |
| R-6 | F-4에 `display`를 넣고 그래프는 빼나 | 넣는다 / 뺀다(Q-039 3번 권장) | 프론트 자체 포맷(TBD-16·D-055 경계를 프론트가 다시 구현) / 대화창 그래프 | 소비자, 프론트 |
| R-7 | `text` 길이 오류의 표현 | `OUT_OF_RANGE` + `min 1, max 2000, unit "CHAR"`(C3-1에 `unit` 값 하나 추가) | 새 `reason` `TOO_LONG` + `max` | 양쪽(C3-1 소유자 A팀) |
| R-8 | `expectedRevision`의 출처 | 프론트 계획 상태 하나(현재 계획·적용·되돌리기·입력 응답) | F-4에 `planRevision`을 실어 보냄(b-team-contracts 초안). 출처가 둘이 되어 어긋남 | 프론트 |
| R-9 | 오래된 PENDING 정리 방식 | F-1·F-2·F-3이 읽기 전에 정리(60초) | `@Scheduled` 정리 작업 | 소비자(B) |
| R-10 | F-5 검사 순서 | `PLAN_CHANGED`(8)를 `STALE_COMPARISON`(9)보다 먼저 | 반대 순서(버튼 단위 오류를 먼저 알림) | 양쪽 |
