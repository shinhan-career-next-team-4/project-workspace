# 프론트 ↔ Spring 대화 API 계약 최종본 (moeun #12-b)

> **최종본** (2026-11-16). v3에 쟁점 결정 D-068(쟁점 X-1 = B: 되돌리기는 직전 버전 복사 INSERT), D-069(쟁점 X-2 = A: 계획이 바뀐 모든 순간 이전 적용 버튼 비활성)를 반영했다. 두 결정은 Claude 판단(진혁 위임)으로 **임시**이며, 바뀌면 `[D-068]`·`[D-069]` 표시 줄만 고친다. 본문의 "쟁점 X-n이 A/B로 정해지면 …" 문장은 기록용이다.
> 협상 기록: `frontend-api-chat-v1.md` → 검토 2건 → `-v2.md` → 재검토 2건 → `-v3.md`, 합의안 `frontend-api-chat-proposal.md`. 이 문서를 moeun #12가 `docs/api/frontend-api.md`(대화 절)와 `frontend/src/mocks/chat/`로 옮긴다.
>
> **최종본 보충 (같은 날 결정, 본문보다 우선)**
> - **D-063** 초과 계획(D-062): 대화창은 열어 두고 첫 자리에 문구표 `chat.alreadyExceeded` 문장 한 줄을 프론트가 표시한다. F-3·LLM 호출 없음, `chat_message`·F-2 응답에 넣지 않는다. 설명 다시 요청 버튼(FR-AI-05)은 보이지 않는다. → #52·#54
> - **D-066** 대화창에 고지 한 줄(문구표 `chat.disclaimer`: D-029 과거 데이터 고지 + "AI 설명은 참고용이며 계산 결과가 기준이에요")을 상시 표시한다. 서버 응답과 무관. → #52, #18
> - **D-064** 질문 예시 버튼(FR-AI-08, Should)은 "조건 고르기" 문구이며 F-1로 그 문장을 그대로 보낸다(응답은 `CLARIFY`). API 변경 없음.
> - **D-070** 목 제거 #55는 `team:common`, `features/chat/**` 포함(H-11e 확인 완료).
> - **D-072** 초과 고정 문장은 계획 `revision`이 바뀔 때마다(D-069 구독 지점) 현재 초과 여부로 다시 판단: 초과면 대화창 맨 위 표시·설명 다시 요청 버튼 숨김, 풀리면 지우고 버튼 표시, F-3은 #54 규칙대로. → #52·#53·#54
> - **D-071** 초과 계획에서 대화 조건 변경은 `ALREADY_EXCEEDED` 고정 문장(RECALC_RESULT 아님) → 비교 카드·적용 버튼 없음. → #53


> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 4단계(재검토 반영) 마무리. **결정이 아니라 사람에게 넘길 합의안의 본문이다.** 쟁점(쟁점 X-1, 쟁점 X-2)은 사람이 정한다. 합의안·쟁점 설명은 `frontend-api-chat-proposal.md`.
> - 입력: `frontend-api-chat-v2.md`, `review-frontapi-chat-v2-provider.md`(A팀 재검토, "수정하면 수용"), `review-frontapi-chat-v2-consumer.md`(B팀 재검토, "수정하면 수용"). v1 검토(`review-frontapi-chat-v1-provider.md`, `review-frontapi-chat-v1-consumer.md`)는 v2에 반영돼 있다.
> - 재검토는 이번이 마지막이다. 두 재검토의 남은 지적은 모두 문서 몇 줄 수준이라 **합의로 반영**했다(부록 C).
> - 재사용(최종본): `internal-calc.md` C3-1(오류 형식), C3-5, C2-2(허용 4키), C2-3~C2-6(비교 모양·display), `plan-context.md` C1a-10(`findPlanRun`, F-3 404), C1a-11(계획 없음·초과)
> - 기준: `docs/srs.md`(FR-AI-01·04·05·06·07, FR-PLAN-03·04, FR-RES-01, FR-AUTH-02·03, NFR-INT-03, NFR-SEC-02), `docs/decisions.md`(D-013, D-016, D-022, D-030, D-033, D-040, D-041, D-051, D-052, D-057, D-058, D-062)
> - moeun 기준(origin/develop, 읽기만). Issue 번호·본문은 두 재검토가 `gh api`로 조회한 값을 합쳤다(이 단계에서 다시 조회하지 않음).
>
> **표기**
> - **[합의]**: 양쪽이 수용했거나, 한쪽 수정 제안에 다른 쪽 이견이 없어 반영한 것.
> - **[쟁점 X-n]**: 사람이 정한다. 본문에는 **기획 추천안(양쪽 재검토도 같은 안)을 임시로** 적고 `⟵ 쟁점 X-n` 표시를 달았다. 결정이 다르면 그 줄만 바꾼다. open-questions에는 **Q-056(쟁점 X-1)**, **Q-057(쟁점 X-2)** 로 올라간다.
> - **[v3]**: v2에서 이번에 바뀐 줄.
> - **이름 겹침 주의**: C12b-15의 코드 차이 번호(X-1~X-15)와 쟁점 번호가 겹친다. 이 문서는 항상 **"코드 차이 X-n"** 과 **"쟁점 X-n"** 으로 구분해 부른다.
> - 항목 ID(C12b-x, R-x, H-x)는 v1·v2와 같다. v1 → v2 변경은 `frontend-api-chat-v2.md` 부록 B, v2 → v3 변경은 맨 아래 부록 C.

## 0. 이 계약의 원칙

`internal-calc.md` §0을 그대로 따른다.

1. **프론트는 Spring만 부른다.** ai-server는 브라우저에 노출하지 않는다(NFR-INT-03). 사용자 토큰은 ai-server로 가지 않는다(D-030).
2. **회원은 JWT subject로만 정한다.** 본문·쿼리에 `memberId`가 없다. 남의 리소스는 `404 NOT_FOUND`(존재 여부 숨김).
3. **숫자는 Spring만 만든다.** 대화창 비교 카드 문자열도 Spring `display`를 그대로 쓴다(C12b-6).
4. **적용은 값이 아니라 `messageId`로 한다**(D-033).
5. **JSON은 camelCase**, 금액 원 정수, 기간 개월 정수, 퍼센트 숫자, 시각 ISO-8601(오프셋 포함).
6. **null은 키를 빼지 않는다. 받는 쪽은 모르는 키를 무시한다.**
7. **오류 본문은 하나의 형식**: `ProblemDetail` + `code` + `errors[]`(C3-1). 기계 판단은 `code`로만. **모든 오류 응답에 `code`가 있다**(Spring 기본 예외 포함, C12b-9).
8. **새 라이브러리 없음.** 프론트 목은 JSON 파일 + 기존 `fetch` 래퍼 분기(C12b-12).
9. **`chat_message.condition_changes`는 camelCase로 저장한다**(C12b-14). 저장 뒤 모든 읽기는 변환하지 않는다.

---

## C12b-1. 범위와 엔드포인트 목록 [합의]

| ID | 메서드·경로 | 하는 일 | 성공 | 담당 모듈(팀) | 토큰 연장 |
|---|---|---|---|---|---|
| F-1 | `POST /api/chat/messages` | 질문 보내기 | `202` | chat(B) | 예 |
| F-2 | `GET /api/chat/messages?afterId={id}` | 메시지 폴링·대화 복원 | `200` | chat(B) | **아니오**(D-052, `@SkipRenewal`) |
| F-3 | `POST /api/chat/explanations` | 계산 결과 설명 요청 | `202` | chat(B) | 예 |
| F-4 | `GET /api/chat/messages/{messageId}/comparison` | 대화 비교 결과 조회 | `200` | chat(B), 계산은 calc 공개 API(A) | 예 |
| F-5 | `POST /api/chat/messages/{messageId}/apply` | 대화 비교 결과를 내 계획에 적용 | `200` | chat(B) 컨트롤러 → plan(A) 공개 서비스 | 예 |
| — | (엔드포인트 없음) 대화 기록 삭제 | 로그인·로그아웃 때 이전 대화 삭제(D-051) | — | auth(A)가 이벤트 발행, chat(B)이 동기 수신(C12b-8) | — |

- F-5는 `b-team-contracts` A-1의 대화 쪽을 대신한다. 대안·비교 적용(Should)은 plan 컨트롤러의 조건값 적용 API로 남는다(#33, #12-a).
- 대화 기록 삭제용 프론트 엔드포인트는 두지 않는다. 왜: D-051은 로그인·로그아웃 시점만 정했다.
- 모든 경로는 JWT 쿠키 인증. `/internal/**`과 필터 체인이 다르다(internal-calc C2-1).

## C12b-2. 인증·공통 헤더·공통 응답

| 항목 | 값 |
|---|---|
| 인증 | HttpOnly·Secure 쿠키의 JWT(D-052, ADR-002). **`SameSite=Lax` 이상 필수**. 왜: `SecurityConfig`가 CSRF를 끄므로 교차 사이트 POST(F-1 비용, F-5 계획 변경)를 막는 장치가 `SameSite`뿐이다. 쿠키 이름은 #12-a(#16) |
| **[v3] 배포 전제** | **프론트와 Spring은 같은 사이트**(한 도메인 또는 리버스 프록시)에서 서빙한다. 개발 서버는 Vite 프록시로 `/api`를 Spring에 넘긴다. 왜: `Lax` 쿠키는 교차 사이트 `fetch`(GET 포함)에 실리지 않아, 다른 사이트면 F-2 폴링이 전부 401이 된다. #13에 적는다 |
| 요청 헤더 | 본문이 있으면 `Content-Type: application/json`. 프론트는 `fetch(..., { credentials: "include" })` |
| 성공 / 오류 `Content-Type` | `application/json` / `application/problem+json` |
| 토큰 연장 | 사용자 조작 요청은 `TokenRenewalFilter`가 새 쿠키를 내린다. **F-2만 `@SkipRenewal`**(D-052) |
| 만료·없는 토큰 | 모든 엔드포인트 `401 UNAUTHENTICATED`. 프론트는 폴링을 멈추고 로그인 화면으로 |

- chat 컨트롤러는 `memberId`를 **Spring Security 타입**(`@AuthenticationPrincipal Jwt` 또는 `Authentication.getName()`)으로만 얻는다. auth가 만든 리졸버를 쓰지 않는다(C12b-10-2 규칙 b).
- `@SkipRenewal`·`TokenRenewalFilter`·`ChangePath`·`ConditionValidator`는 **이름만 정해진 상태**(`moved-to-code.md`)다. 코드는 해당 Issue가 만든다.
- **[v3] `@SkipRenewal` 구현 메모(#34, 계약 변경 아님)**: 핸들러 어노테이션이라 서블릿 필터는 핸들러가 정해지기 전에 돌아 바로 볼 수 없다. `HandlerInterceptor.preHandle`(본문을 쓰기 전에 `Set-Cookie`)로 하거나, 필터에서 `HandlerMappingIntrospector`로 핸들러를 찾는다(#34 재량). 어느 쪽이든 어노테이션은 auth 루트 타입이다.
- 폴링이 401을 받으면 사용자 조작 없이 만료된 것이므로 다른 요청을 다시 보내지 않고 로그인 화면으로 간다(FR-AUTH-02 예외).
- **[v3] 폴링 실패 규칙**: F-2가 **401 외의 실패**(네트워크 오류, 4xx, 5xx)를 **연속 3회** 받으면 폴링을 멈추고 대화창에 실패 안내를 한 번 보인다(문구표). 사용자가 F-1·F-3을 다시 보내면 재개한다. 한 번이라도 200이면 연속 횟수는 0으로. 왜: 서버가 멈춰 60초 정리(C12b-11-3)를 못 하는 경우와, `400 MALFORMED_REQUEST`(`afterId` 오류)가 1초마다 영원히 반복되는 경우를 모두 끝낸다.

## C12b-3. 메시지 모양 (F-2가 돌려줌)

```json
{
  "id": 1031,
  "role": "ASSISTANT",
  "messageType": "RECALC_RESULT",
  "status": "COMPLETED",
  "content": "월 저축액을 약 50만원으로 바꾸면 평균일 때 약 2,501만원으로 목표를 달성해요. 지금보다 약 789만원 증가해요.",
  "citations": [],
  "createdAt": "2026-11-16T10:15:31+09:00"
}
```

| 필드 | 타입 | 뜻 |
|---|---|---|
| `id` | integer | `chat_message.id`(BIGSERIAL) |
| `role` | `USER` \| `ASSISTANT` | |
| `messageType` | `QUESTION` \| `ANSWER` \| `EXPLANATION` \| `RECALC_RESULT` \| `CLARIFY` \| `OUT_OF_SCOPE` \| `FAILURE` \| `null` | `status=PENDING`이면 `null` |
| `status` | `PENDING` \| `COMPLETED` \| `FAILED` | USER는 항상 `COMPLETED` |
| `content` | string \| null | `PENDING`이면 `null`. `FAILED`면 문구표 실패 안내(FR-AI-04) |
| `citations` | array | 출처. **배열 순서가 순위**다. 없으면 `[]` |
| `citations[].title` | string | 문서 제목(D-028: 링크에는 상품명 허용) |
| `citations[].sourceUrl` | string | |
| `citations[].orgName` | string | 운용사·기관명 |
| `createdAt` | string | ISO-8601 |

- **`conditionChanges`·`citations[].rank`는 응답에 넣지 않는다.** 왜: 카드는 F-4의 `conditions`·`changedKeys`를 쓰고, 순위는 배열 순서로 충분하다. ai-server 키 표기 문제(C12b-14)가 프론트에 새지 않는다.
- **PENDING 행의 DB 값(구현 고정)**: 질문 답변 대기(F-1이 만든 ASSISTANT PENDING)는 `message_type='ANSWER'`, 설명 대기(F-3)는 `message_type='EXPLANATION'`. 왜: `ANSWER_PENDING` 판정(C12b-4)과 `answerPending`(C12b-5)을 같은 조건 `status='PENDING' AND message_type='ANSWER'` 하나로 만든다. 화면에는 PENDING의 `messageType`을 `null`로 가린다. 프론트가 "질문 대기인가"를 알아야 할 때는 F-2의 `answerPending`을 본다.
- `FAILED`는 항상 `messageType=FAILURE`. 실패 이유 코드는 로그에만.
- `calcRunId`·`retryOfMessageId`·`baselineScenario`는 내보내지 않는다.
- **id와 커밋 순서**: id는 할당 순서이지 커밋 순서가 아니다. 같은 회원의 F-1과 F-3이 몇 ms 안에 겹치면 작은 id가 늦게 커밋되어 `id > afterId` 폴링이 놓칠 수 있다. 데모에서 드물어 서버 잠금은 두지 않고 C12b-5의 복원 안전장치로 막는다.

## C12b-4. F-1 질문 보내기 `POST /api/chat/messages`

요청:
```json
{ "text": "월 50만원으로 하면 어때요?" }
```

응답 `202 Accepted`:
```json
{ "userMessageId": 1030, "assistantMessageId": 1031 }
```

- `userMessageId`는 프론트가 사용자 말풍선을 바로 그리고 폴링 upsert와 겹치지 않게 하는 키다. `status`는 넣지 않는다(항상 같은 값).

| 필드 | 규칙 |
|---|---|
| `text` | 필수. **앞뒤 공백을 지운(trim) 문자열**의 길이가 1 이상 2000 이하. 길이는 **UTF-16 코드 단위**(Java `String.length()` = JS `string.length`). **저장·ai-server 전송도 trim한 문자열**로 한다 |

- 왜 UTF-16: 프론트 글자 수 표시(`maxLength=2000`)와 서버 기준이 같다. ai-server `max_length=2000`(코드포인트)은 이보다 느슨하므로 Spring을 통과한 값은 ai-server에서 걸리지 않는다. trim한 값을 보내야 이 관계가 성립한다.
- trim 뒤 길이 검사는 `@Size`가 못 보므로 컨트롤러 또는 요청 record의 compact constructor에서 한다(구현 메모).

서버 동작(한 트랜잭션):
1. 오래된 `PENDING` 정리(C12b-11-3).
2. 그 회원에게 `status='PENDING' AND message_type='ANSWER'` 행이 있으면 `409 ANSWER_PENDING`. 설명 대기는 막지 않는다(R-4).
3. USER(`QUESTION`, `COMPLETED`, trim한 `text`) + ASSISTANT(`ANSWER`, `PENDING`) 저장 → `ChatAnswerRequested{assistantMessageId, memberId}` 발행.
4. 커밋 뒤 리스너가 ai-server `POST /chat`(mode=`QUESTION`) 호출 → `COMPLETED`/`FAILED`(#41, C12b-11-2).

- 계획이 없어도 받는다(NFR-USA-01). 리스너는 `planContext: null`로 부르고 **`baselineScenario`는 `"AVG"`로 채운다**. 왜: `ChatRequest.baseline_scenario`가 필수라 비우면 ai-server 422 → `FAILED`. 계획이 있으면 `plan.baseline_scenario`.
- `history`: 같은 회원의 `COMPLETED` 메시지 최근 20개. `role`은 ai-server 형식(소문자 `user`/`assistant`)으로 Spring이 바꾼다(프론트 영향 없음).
- 초과 계획에서도 평소대로 받는다. 대화창 표시는 **Q-051(미결)**.

오류:

| HTTP | `code` | 언제 | `errors` | 프론트 동작 |
|---|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | JSON 파싱 실패, 본문이 객체가 아님 | `[]` | 일반 실패 토스트(개발 오류) |
| 422 | `VALIDATION_FAILED` | trim 뒤 빈 문자열 | `[{field:"text", reason:"REQUIRED"}]` | 입력창 아래 안내 |
| 422 | `VALIDATION_FAILED` | 2000 초과 | `[{field:"text", reason:"OUT_OF_RANGE", min:1, max:2000, unit:"CHAR"}]` | 입력창 아래 안내 |
| 409 | `ANSWER_PENDING` | 질문 답변 대기 중 | `[]` | **보내기 버튼 비활성 + 폴링 재개**(다른 탭이 만든 대기일 수 있음). **입력창 글은 지우지 않는다** |
| 401 | `UNAUTHENTICATED` | 만료·없는 토큰 | `[]` | 로그인 화면 |
| 500 | `INTERNAL_ERROR` | DB 오류 등 | `[]` | "보내지 못했어요" 토스트, 입력창 글 유지 |

- "`text`가 문자열이 아님 → 400"은 두지 않는다. Jackson 기본 스칼라 변환(`123` → `"123"`)으로 받아질 수 있고 막을 가치가 낮다.
- 프론트는 `answerPending=true`인 동안 보내기 버튼을 막는다. 409는 두 탭·연타의 방어선이다. 2·3 사이 동시 요청 경쟁은 데모 범위에서 허용(막으려면 회원 행 잠금).

## C12b-5. F-2 메시지 폴링·복원 `GET /api/chat/messages?afterId={id}`

응답 `200`:
```json
{
  "messages": [
    { "id": 1030, "role": "USER", "messageType": "QUESTION", "status": "COMPLETED",
      "content": "월 50만원으로 하면 어때요?", "citations": [],
      "createdAt": "2026-11-16T10:15:30+09:00" },
    { "id": 1031, "role": "ASSISTANT", "messageType": null, "status": "PENDING",
      "content": null, "citations": [],
      "createdAt": "2026-11-16T10:15:30+09:00" }
  ],
  "hasPending": true,
  "answerPending": true
}
```

| 쿼리 | 규칙 |
|---|---|
| `afterId` 없음 | **복원**: 최근 50개를 `id` 오름차순으로(키셋 `DESC LIMIT 50` 뒤 뒤집기). 결과 화면 진입 때 1회 |
| `afterId=N` | **폴링**: `id > N` 전부를 `id` 오름차순. 정수가 아니면 `400 MALFORMED_REQUEST` |

| 응답 필드 | 뜻 | 프론트 사용 |
|---|---|---|
| `messages[]` | C12b-3 모양 | `id`로 upsert |
| `hasPending` | 그 회원에게 `PENDING`이 하나라도 있음(목록 밖 포함) | 폴링 유지/중단 |
| `answerPending` | 그 회원에게 **질문 답변 대기**(`PENDING` + DB `message_type='ANSWER'`)가 있음 | **보내기 버튼 막기**. F-1 `ANSWER_PENDING`과 같은 조건(같은 메서드) |

- 왜 `answerPending`(불리언)인가: 새로고침 뒤에도 보내기 버튼을 정할 수 있고, 프론트가 메시지 문자열을 해석하지 않는다. 서버 판정은 `EXISTS(member_id=? AND status='PENDING' AND message_type='ANSWER')` 하나다. `ix_chat_message_pending`은 회원 조건을 포함하지 않지만 PENDING 행이 몇 개뿐이라 인덱스를 바꾸지 않는다.
- **`hasPending=false` 보장**: 서버는 오래된 PENDING을 정리한 **뒤** 조회한다. 그래서 `hasPending=false`면 응답 시점에 서버의 모든 PENDING이 끝났고, 프론트가 가진 PENDING은 이미 덮어써졌어야 한다. 남아 있으면 아래 복원 안전장치를 쓴다.

**프론트 폴링 규칙**
- `afterId` = 가진 메시지 중 **가장 작은 `PENDING` id − 1**. `PENDING`이 없으면 가진 가장 큰 id.
- 받은 메시지는 `id`로 덮어쓴다(upsert). 같은 메시지를 다시 받는 것은 정상.
- 간격 **1초**. `hasPending=false`면 멈추고, F-1·F-3을 보내면 다시 시작한다.
- **복원 안전장치**: `hasPending=true`인데 가진 PENDING이 없거나, `hasPending=false`인데 가진 PENDING이 남아 있으면 `afterId` 없이 **복원을 1회** 부른다. **[v3] "1회"의 범위**: 한 번 부르면 **폴링이 멈출 때(`hasPending=false`)까지, 또는 사용자가 F-1·F-3을 보낼 때까지** 다시 부르지 않는다(무한 반복 방지). 서버 변경 없음.
- 401 외 실패 연속 3회면 중단(C12b-2), 401이면 로그인 화면.
- 다른 회원의 메시지는 나오지 않는다. `afterId`가 남의 id여도 오류 없이 자기 메시지만.
- ERD Q2-b의 `pending_ids` 파라미터는 쓰지 않는다(코드 차이 X-4).
- **구현 메모**: GET이 오래된 PENDING을 UPDATE하므로 F-2 서비스는 **읽기 전용 트랜잭션이 아니다**. 대개 0행 UPDATE라 부담은 작다.

## C12b-6. F-4 대화 비교 결과 조회 `GET /api/chat/messages/{messageId}/comparison`

응답 `200`:
```json
{
  "messageId": 1031,
  "applicable": true,
  "changedKeys": ["monthlySavingAmount"],
  "conditions": { "current": { "...": "C2-3과 같음(4키)" }, "changed": { "...": "" } },
  "current": { "...": "C2-4 CalcResultView (monthlyPoints 키 없음)" },
  "changed": { "...": "C2-4" },
  "diff": { "...": "C2-5" },
  "display": { "...": "C2-6 키·형식 그대로" }
}
```

- 본문 = `/internal/calc` 성공 응답(C2-3~C2-6)에서 `calcRunId`를 빼고 `messageId`·`applicable`·`changedKeys`를 더한 것. 목 파일에는 internal-calc 부록 A-1 값을 줄임 없이 넣는다.
- **`changedKeys`**: 저장된 `condition_changes`의 키 목록(camelCase). 계산이 아니라 저장값의 키를 그대로 꺼낸 것. 프론트는 카드에서 "무엇을 바꿨나"를 강조하는 데만 쓴다. **[v3] 순서는 보장하지 않는다. 프론트는 집합으로 쓴다**(포함 여부만 본다). 화면에 행을 그리는 순서는 프론트가 `conditions`의 고정 4키 순서(internal-calc C2-2 표)로 정한다. 왜: `condition_changes`는 `jsonb`라 PostgreSQL이 키 순서를 보존하지 않는다. 순서를 약속하면 정렬 코드가 생기고, 집합이면 코드가 0줄이다.
- `messageId` 에코는 유지(목 파일 식별용).
- `display` 포함, `monthlyPoints`(그래프) 제외(R-6, Q-039 3번 권장과 같음).

**계산 방식**
- 메시지의 `calc_run(CHAT)`에 기록된 **계획 버전·데이터 버전·`engine_version`** 과 저장된 `condition_changes`로 다시 계산한다(ADR-002 결과 미저장). 그래서 그 뒤 계획이 바뀌어도 이 비교는 **당시 기준**이다(AI 문장과 같다).
- **[v3] 재계산은 범위 검사를 하지 않고 타입 변환만 한다.** 그때 계산한 값을 재현하는 것이 목적이기 때문이다. 타입 변환 실패나 허용 4키 밖의 키는 `500 INTERNAL_ERROR`(아래 표의 "재계산 실패")다. **범위 위반의 최종 거절은 F-5 검사 6·7(plan) 한 곳**에서만 한다. 그래서 **F-4는 422를 내지 않는다.** `ConditionValidator`가 "범위 검사 없이 타입만 바꾸는" 진입점을 하나 더 내거나, 검증 결과 record에 위반이 있어도 값을 담아 주는 방식 중 #17 재량.
  - 허용 밖 키가 저장된 메시지는 F-4가 500이라 카드·버튼이 없다. F-5의 `FIELD_NOT_CHANGEABLE`은 방어선으로 남는다.
- chat은 **calc 루트 공개 API**로만 부른다(제공자 시그니처, 이름·세부는 A팀 재량):
  ```java
  // calc 루트. 소유권은 findPlanRun과 같은 2단계(calc_run 조회 → plan.findVersion(memberId, ...)).
  public interface ChatComparisonQuery {
      /** CHAT 기록의 기준 버전만. 없음·남의 것·PLAN 기록이면 empty. F-5 검사 4용(재계산 없음). */
      Optional<Long> findChatRunPlanVersion(long memberId, long calcRunId);
      /** CHAT 기록의 데이터 버전·engine_version + 그 기록의 plan_version + changes로 다시 계산. 범위 검사 없음. */
      Optional<ChatComparisonView> recompute(long memberId, long calcRunId, Map<String, JsonNode> conditionChanges);
  }
  public record ChatComparisonView(long basePlanVersionId, CalcComparison comparison, Map<String, String> display) {}
  ```
  - `display`는 `ResultDisplayBuilder`를 calc 안에서 불러 **루트 공개 타입 `Map<String,String>`** 으로 내보낸다(planContext `PlanContextView.display`와 같은 방식). chat이 `calc.web`·`calc.application` 타입을 쓰면 `modulith.md`(하위 패키지 비공개) 위반이다.
  - **[v3] 만드는 곳은 #78.** `ChatComparisonQuery`·`ChatComparisonView`와 **버전 지정 기준 데이터 조회**(`ReferenceDataService`에 버전 id로 꺼내는 메서드 3개)를 #78(`PlanContextProvider.findForCalcRun`)에서 만든다. 왜: #78도 "그 기록의 plan_version·데이터 버전으로" 다시 계산해야 해 같은 조회가 반드시 필요하고 소유권 확인도 같은 2단계라, 하나의 "기록 재현" 코드를 두 공개 API가 쓴다. #78의 선행에 #32가 있으므로 #32에 두면 #32가 refdata까지 떠안는다. #78이 너무 커지면 A팀이 같은 선행으로 나눌 수 있다(재량).
  - `JsonNode`는 Boot 4의 Jackson 3(`tools.jackson.databind.JsonNode`), #17 `ConditionValidator`와 같은 패키지.

**`applicable` 판정**(D-041, 서버 힌트)
1. 이 메시지가 그 회원의 `COMPLETED` `RECALC_RESULT` 중 id가 가장 크고,
2. 그 `calc_run.plan_version_id` = 지금 `plan.current_version_id`일 때 `true`.
- 되돌리기 뒤에도 이 값이 정확한 것은 되돌리기가 새 버전을 만들기 때문이다 [D-068](C12b-7-4).
- `currentVersionId`는 plan 공개 현재 계획 조회(#19)에서 얻는다(chat → plan).

오류:

| HTTP | `code` | 언제 | 프론트 동작 |
|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | `messageId`가 정수 아님 | 카드 자리 비움(개발 오류) |
| 404 | `NOT_FOUND` | 없는 id, 남의 메시지, `RECALC_RESULT` 아님, `COMPLETED` 아님 — 모두 같은 404 | 카드 자리 비움, 버튼 없음 |
| 500 | `INTERNAL_ERROR` | 재계산 실패(타입 변환 실패·허용 밖 키 포함) | 카드 자리에 "비교 결과를 불러오지 못했어요"(문구표). **[v3] 버튼 없음, 자동 재시도 없음**(새로고침으로 다시 시도) |
| 401 | `UNAUTHENTICATED` | | 로그인 화면 |

**프론트 호출·버튼 규칙**
- **F-4는 가장 최근 `RECALC_RESULT`에만 자동으로 부른다.** 복원 때 RECALC_RESULT가 여러 개여도 1회. 이전 결과는 본문(`content`)만 보이고 카드는 "이전 결과"로 접는다(버튼 비활성). 이전 카드를 펼칠 때 F-4를 부르는 것은 선택 구현.
- 이미 받은 비교는 다시 부르지 않는다.
- **새 `RECALC_RESULT`가 폴링으로 도착하면 이전 카드의 적용 버튼을 즉시 비활성**으로 바꾼다(F-4 재호출 없음).
- **버튼 활성 한 줄**: 활성 = (이 메시지 id = 가진 메시지 중 최대 `RECALC_RESULT` id) AND (F-4 `applicable=true`) AND (이 메시지가 계획 `revision`이 마지막으로 바뀐 뒤에 도착함, C12b-7-4) ⟵ 셋째 조건의 범위는 **쟁점 X-2**.
- 카드 문구: `diff.byScenario[].achievementChange` 4값과 **[v3] 조건 4개의 행 라벨**(월 저축액·저축 비중·적금 금리·목표 기간)은 프론트가 문구표에서 키로 찾는다. 프론트가 라벨을 지어내지 않는다. 키 목록은 #18·#53 수용 기준에 적는다.
- ETF 0%(`savingsRatioPct=100`)면 시나리오가 AVG 하나다. 카드는 1개·3개를 모두 그린다(목 `get-comparison.200-etf0.json`).

## C12b-7. F-5 대화 비교 결과 적용 `POST /api/chat/messages/{messageId}/apply`

확인창 없이 바로 적용한다(D-016, D-022).

요청:
```json
{ "expectedRevision": 12 }
```

응답 `200`:
```json
{ "revision": 13 }
```

| 필드 | 뜻 |
|---|---|
| `expectedRevision` | 프론트가 들고 있는 내 계획의 `revision`. 출처는 #12-a의 현재 계획 응답, 직전 적용·되돌리기·입력 저장 응답 하나뿐(R-8) |
| `revision` | 새 revision. 프론트는 이 값으로 계획 상태를 바꾸고 되돌리기 토스트가 쓴다 |

- **[v3] 응답은 `revision` 하나다.** v2의 `planVersionId`는 프론트가 쓰지 않아 뺐다(소비자 제안, 제공자 이견 없음). `previousVersionId`·`undoAvailable`도 없다. plan 서비스의 `PlanApplyResult`(C12b-13 요구 1)는 `planVersionId`·`previousVersionId`를 그대로 가져도 되며(로그·테스트용), chat 컨트롤러가 `revision`만 응답 DTO로 옮긴다. #33의 plan 쪽 REST(대안·비교 적용)가 `undoAvailable`을 내는 것은 그 Issue 범위다.
- `calcRunId`는 응답에 없다. 새 버전의 `calc_run(PLAN)`은 `PlanChanged` 리스너(calc)가 비동기로 남기고, 결과 화면 재조회(#30·#31)가 기록이 없으면 계산·기록한다(ERD Q1-c).

### C12b-7-1. 서버 검사 순서 [합의]

| 순서 | 어디서 | 검사 | 결과 |
|---|---|---|---|
| 0 | 필터 | 토큰 | `401 UNAUTHENTICATED` |
| 1 | chat 컨트롤러 | 본문 파싱, `expectedRevision` 정수, 경로 `messageId` 정수 | `400 MALFORMED_REQUEST` |
| 2 | chat 서비스 | `findByIdAndMemberId`. 없음·남의 것·`RECALC_RESULT` 아님·`COMPLETED` 아님 | `404 NOT_FOUND` |
| 3 | chat 서비스 | 그 회원의 `COMPLETED` `RECALC_RESULT` 중 가장 큰 id가 아님 | `409 STALE_COMPARISON` |
| 4 | chat → calc | `ChatComparisonQuery.findChatRunPlanVersion` = **기준 버전** | (실패 없음. FK로 보장) |
| 5 | plan 서비스 | `plan` 행 없음 | `409 NO_PLAN` |
| 6 | plan 서비스 | `ConditionValidator.validate(ChangePath.CHAT, conditionChanges)`. 허용 밖 키 | `422 FIELD_NOT_CHANGEABLE` |
| 7 | plan 서비스 | 같은 검증의 범위·정수·소수 자릿수 | `422 VALIDATION_FAILED`(`min`·`max`·`unit`·`scale`, `minDisplay`·`maxDisplay` 없음) |
| 8 | plan 서비스 | `plan.revision ≠ expectedRevision` | `409 PLAN_CHANGED` |
| 9 | plan 서비스 | `plan.current_version_id ≠ 기준 버전` | `409 STALE_COMPARISON` |
| 10 | plan 서비스 | `plan_version` INSERT(현재 버전 복사 + 변경 키 + `source='CHAT'`, `calc_start_month`는 현재 값, D-013) → `UPDATE plan ... WHERE member_id=? AND revision=?` → **0행이면 `PlanChangedException`(런타임 예외)으로 트랜잭션 롤백** → `PlanChanged(APPLY)` 발행 | `200` |

- **0행 롤백**: 앞에서 INSERT한 `plan_version`이 남지 않게 한다. `plan_version`은 INSERT 전용이라 고아 행을 지울 경로가 없다. 응답은 8과 같은 `409 PLAN_CHANGED`이며 **현재 상태를 본문에 싣지 않는다** — `persistence.md:14`·`moved-to-code.md`, **[v3] #19 수용 기준**의 "0행이면 현재 상태를 돌려준다"와 다르므로 그 문장들을 고친다(코드 차이 X-10, #33·#19).
- **검사 9를 잠금 없이 읽어도 되는 이유**: 10의 `UPDATE ... WHERE revision = :expected`가 성공했다면 그 사이 `current_version_id`도 바뀌지 않았다(포인터를 바꾸는 모든 경로가 revision을 올린다). 그래서 `SELECT ... FOR UPDATE`가 필요 없다.
- **6·7 입력은 camelCase 키**만이다(원칙 9). chat이 snake_case를 넘기면 모든 대화 적용이 `FIELD_NOT_CHANGEABLE`이 된다.
- 6·7이 걸리는 경우: 비교 뒤 `rules.yml` 범위가 바뀐 때. 다시 검증하는 이유: 저장 경로의 검증을 plan 한 곳에 고정한다(F-4는 범위 검사를 하지 않으므로 여기가 유일한 범위 거절이다).
- **422·500 처리 위치**: plan의 `ConditionViolationException`은 전역 advice로 바로 나간다. `/internal/calc`용 `minDisplay` 덧붙이기와 **[v3] 500 `CALC_FAILED`** 는 **`/internal/calc` 컨트롤러 안의 `@ExceptionHandler`** 에 두어 F-5 응답에 섞이지 않게 한다(#32, C12b-9).
- **검사 순서의 의미(R-10)**: chat의 검사 3(`STALE_COMPARISON`, 최신 아님)은 plan의 검사 8보다 **항상 먼저** 돈다(plan은 대화를 모른다). "둘 다 해당하면 큰 쪽(`PLAN_CHANGED`)을 알린다"는 **plan 안의 8·9 사이에서만** 참이다. 검사 3이 먼저 걸려도 프론트 동작(그 버튼 비활성)이 맞다. 3과 9는 같은 코드·같은 프론트 동작이라 코드를 나누지 않는다.
- 6~10은 plan의 한 트랜잭션. 2~4는 chat의 읽기(트랜잭션 밖 가능).
- 중복 클릭: 두 번째 요청은 8에서 `PLAN_CHANGED`. 프론트는 요청 중 버튼을 막는다.

### C12b-7-2. 오류 응답의 프론트 동작 [합의]

| `code` | 프론트 동작(문구는 문구표) |
|---|---|
| `STALE_COMPARISON` | 그 버튼 비활성 + "가장 최근 비교 결과만 적용할 수 있어요" 토스트. 계획 화면은 다시 부르지 않음 |
| `PLAN_CHANGED` | "계획이 다른 곳에서 바뀌었어요" 안내 → 결과 화면 전체 다시 불러오기(새 revision). 새 revision을 받으면 대화창 버튼이 모두 비활성된다(C12b-7-4) |
| `VALIDATION_FAILED` / `FIELD_NOT_CHANGEABLE` | "지금 기준으로는 적용할 수 없는 값이에요", 버튼 비활성 |
| `NO_PLAN` | 입력 화면으로. 대화창 상태(메시지 목록)는 그대로 둔다 |
| `NOT_FOUND` | 버튼 비활성 |
| `UNAUTHENTICATED` | 로그인 화면 |
| `INTERNAL_ERROR` / 네트워크 실패 | "적용하지 못했어요" 토스트. **버튼은 활성 그대로**(재시도 가능) |
| `MALFORMED_REQUEST` | 개발 오류. `INTERNAL_ERROR`와 같이 처리 |

### C12b-7-3. 성공 뒤 프론트 순서 (FR-AI-07, FR-PLAN-03·04, D-041) [합의]

1. 계획 상태의 `revision`을 응답 값으로. → 대화창이 revision 변화를 보고 **모든** 적용 버튼을 끈다(C12b-7-4).
2. 되돌리기 토스트 **10초**(D-041). 토스트가 들고 있는 값은 `revision`.
3. 결과 화면 전체 다시 불러오기(#30·#31).
4. **[v3] F-3은 여기서 부르지 않는다.** 결과 화면의 `calcRunId`가 바뀌면 #54가 한 곳에서 부른다(C12b-3a "호출 지점").

- 결과 재조회와 `PlanChanged` 리스너가 같은 (버전, PLAN) 기록을 동시에 만들어 2행이 되는 경우는 **무해**하다(plan-context C1a-10 합의와 같음. 조회는 `ix_calc_run_latest`로 최신 1행). 유일 제약·멱등 INSERT는 **두지 않는다**. #29의 "같은 이벤트 두 번 → 중복 없음"(이벤트 단위 멱등)과는 다른 이야기라 둘 다 유지해도 모순이 없다. **[정정 2026-11-16, #12-a Y-17]** 이 문장은 `frontend-api-plan.md` C12a-6-6으로 대체: 기준 데이터 활성 버전·`engine_version`이 그대로인 동안 같은 (버전, PLAN) 기록은 #29 advisory 잠금으로 하나만 생긴다(같은 revision = 같은 `calcRunId`).

### C12b-7-4. 계획이 바뀐 뒤 이전 비교 버튼 비활성 (D-041) — [D-068, D-069]

본문은 **기획 추천안(쟁점 X-1 = B, 쟁점 X-2 = A)** 을 임시로 적는다. 두 재검토도 같은 안을 지지했다(소비자는 v1의 반대를 철회). 결정 변경·새 정책이라 사람이 정한다(Q-056, Q-057).

- **서버**([D-068]): 되돌리기는 **직전 버전 행을 복사해 새 `plan_version`을 INSERT**하고 포인터를 그 행으로 옮긴다(`previous_version_id = NULL`, `revision + 1`). 그래서 되돌리기 전에 만든 모든 비교는 기준 버전 ≠ 현재가 되어 F-4 `applicable=false`, F-5 검사 9 `STALE_COMPARISON`으로 **서버가 D-041을 보장**한다. 새로고침해도 틈이 없다.
  - 막는 경우: **비교(기준 V1) → 적용(V2) → 10초 안에 되돌리기.** 포인터 교체라면 현재가 다시 V1이 되어 방금 적용한 그 비교가 새로고침 뒤 다시 활성이다. B에서는 현재가 V3(V1의 복사본)이라 비활성이다.
  - 되돌리기는 여전히 **1단계**다. 되돌린 뒤 `previous_version_id`가 NULL이라 다시 되돌리면 `NOTHING_TO_UNDO`. `plan_version`에는 부모 컬럼이 없어 체인이 생기지 않는다. #33 수용 기준("직전 계획으로 돌아가고 시작월은 그대로", "이전 버전이 없으면 409 NOTHING_TO_UNDO")이 그대로 참이다.
  - **[v3] 구현 메모(#33)**: (a) 조건부 UPDATE 하나로 하면 0행일 때 `NOTHING_TO_UNDO`와 `PLAN_CHANGED`를 구분할 수 없다. 복사할 행 id를 알려면 어차피 `plan`을 먼저 읽으므로 **"`plan` 읽기 → `previous_version_id` 없음 `409 NOTHING_TO_UNDO` → revision 다름 `409 PLAN_CHANGED` → 복사 INSERT → `UPDATE plan ... WHERE member_id=? AND revision=?`(0행이면 런타임 예외로 롤백) → `PlanChanged(UNDO)`"** 로 적용(C12b-7-1)과 같은 틀을 쓴다. (b) `schema.sql`의 `source` 주석 "이 버전을 만든 경로"가 B에서는 "복사한 원본의 경로"가 된다. CHECK에 `UNDO`를 더하지 않고(스키마 변경 없음) 주석과 `db/tables.md` 한 줄만 고친다(코드 차이 X-14). 새 버전의 `calc_run(PLAN)`은 기존 `PlanChanged(UNDO)` → calc 리스너가 기록하므로 추가 코드가 없다.
- **프론트**([D-069]): **내 계획이 바뀐 모든 순간**(대화 적용 성공, 되돌리기 성공, 입력 수정 저장, `PLAN_CHANGED`로 다시 불러옴)에 **그때 가진 모든 적용 버튼을 비활성**으로 바꾼다. 그 뒤 새로 온 비교만 F-4 `applicable`을 따른다.
  - **[v3] 구현 방식**: 네 곳에서 함수를 부르지 않는다. **대화창(#53) 한 곳이 계획 상태의 `revision`을 구독**해, 값이 바뀌면 그때 가진 메시지의 적용 버튼을 모두 끈다. **최초 로드(값 없음 → N)는 제외**한다. 왜: 네 경우 모두 `revision`이 바뀌고, 되돌리기(#51)·입력 저장은 A팀 `features/plan`·`features/input`에 있어 B팀 함수를 부르면 팀 경계를 넘는다. 구독 한 곳이면 A팀 코드를 건드리지 않는다.
  - 끈 상태는 메모리에만 있다. 새로고침 뒤에는 서버(`applicable`, 검사 9)가 같은 결과를 낸다(쟁점 X-1 B 전제).
  - revision이 바뀌기 전에 보낸 F-4의 응답이 뒤늦게 `applicable=true`로 와도, 그 메시지가 revision 변경 전에 이미 있었다면 비활성을 유지한다.
  - 서버가 보장하므로 프론트는 id를 기억할 필요가 없다(`undoBarrierId`·`planChangeBarrierId` 없음). 이 규칙은 "누르면 409"보다 먼저 버튼을 끄는 화면 반응이다.
- 다른 탭에서의 변경은 프론트가 알 수 없다. 누르면 `PLAN_CHANGED`(revision 다름)나 `STALE_COMPARISON`을 받고 위 규칙대로 비활성된다.
- 쟁점 X-1이 A(포인터 교체 유지)로 정해지면: 같은 `revision` 구독 지점에서 그 순간의 최대 메시지 id를 `planChangeBarrierId`로 기억하고 `id ≤ barrier`인 버튼을 계속 비활성으로 둔다. 새로고침 뒤 틈은 수용(데이터는 안전). 쟁점 X-2가 B로 정해지면: 구독은 되돌리기·대화 적용 성공으로 바뀐 경우에만 반응한다.

## C12b-8. 대화 기록 삭제 (D-051) [합의]

| 항목 | 값 |
|---|---|
| 언제 | (1) 로그인 성공 직후, 쿠키를 내리기 **전**. (2) 로그아웃 처리 중, 쿠키를 만료시키기 **전** |
| 무엇을 | 그 회원의 `chat_message` 전부. `chat_message_citation`은 FK `ON DELETE CASCADE` |
| 무엇은 남나 | `calc_run(CHAT)`(D-057), 계획 |
| 어떻게 | auth가 **`auth.MemberLoggedIn{memberId}`·`auth.MemberLoggedOut{memberId}`**(auth 루트 record)를 `ApplicationEventPublisher`로 발행 → chat이 **동기 `@EventListener`** 로 받아 자체 `@Transactional`에서 **한 문장 일괄 DELETE** `DELETE FROM chat_message WHERE member_id = ?`(`@Modifying` JPQL/네이티브) |
| 의존 | **chat → auth**(이벤트 타입 수신). auth `{}` 유지 |
| **[v3] 누가 만드나** | 이벤트 record·발행·`auth/package-info.java` 문장은 **A팀**: `MemberLoggedIn` + 발행 + `package-info` 문장은 **#16**, `MemberLoggedOut` + 발행은 **#34**. chat 동기 리스너·일괄 DELETE·`modulith.md`는 **B팀 #46**. B팀 Issue는 `auth/` 파일을 고치지 않는다 |

- 왜 이벤트 + 동기 수신: `@SkipRenewal`(auth 루트 타입)을 chat의 F-2가 쓰므로 chat → auth가 이미 생긴다. 삭제를 auth → chat 직접 호출로 하면 auth ⇄ chat 순환으로 `ModularityTests`가 깨진다. 이벤트로 방향을 chat → auth 하나로 맞추고, 동기 `@EventListener`로 받아 "로그인 직후 F-2 복원이 삭제보다 먼저 도는" 경쟁을 없앤다.
- 삭제가 실패하면 예외가 로그인·로그아웃으로 올라가 그 요청도 실패한다(D-030 쪽이 안전). 프론트 로그인 화면(#47)은 일반 5xx를 "로그인하지 못했어요"로 처리한다. 동기 리스너는 `event_publication`에 기록되지 않지만 재시도가 필요 없다(사용자가 다시 로그인).
- **`modulith.md:24` 예외 1줄**: "수신은 `@ApplicationModuleListener`" 규칙에 "응답 전에 끝나야 하는 수신(대화 삭제)은 동기 `@EventListener`"를 더한다(코드 차이 X-11, #46). `auth/package-info.java:4`의 "이 모듈을 직접 의존하지 않는다"는 "다른 모듈은 auth 루트의 이벤트와 `@SkipRenewal`만 쓴다"로 고친다(#16).
- **일괄 DELETE인 이유**: 엔티티를 하나씩 지우면 `retry_of_message_id`(자기 참조, NO ACTION)가 문장마다 검사되어 순서에 따라 실패한다. 한 문장이면 문장 끝 검사라 위반이 없다.
- 이벤트 이름은 #46 본문의 `LoggedIn`/`LoggedOut`을 `MemberLoggedIn`/`MemberLoggedOut`으로 맞춘다(같은 의미, 파일 이름만).
- **진행 중인 PENDING**: 삭제 뒤 ai 응답이 오면 리스너의 완료 갱신(`... AND status='PENDING'`)이 0행이다. 리스너는 이를 오류로 보지 않고 버리며, **0행이면 citation INSERT를 하지 않는다**(순서 고정: UPDATE → 1행일 때만 citation). 그렇지 않으면 삭제된 메시지에 citation을 넣다 FK 위반 → `event_publication` 미완료로 재기동마다 다시 돈다.
- 만료된 토큰으로 로그아웃하면 401이고 삭제는 다음 로그인 때 된다(NFR-INT-03 예외 수용 기준과 같음). #34에 한 줄.

## C12b-9. 오류 공통 규칙과 코드 표

형식은 internal-calc **C3-1 그대로**. `type`, `title`, `status`, `detail`, `instance`(선택) + `code`(필수) + `errors`(필수, 없으면 `[]`).

| HTTP | `code` | 엔드포인트 | 언제 | `errors` |
|---|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | F-1~F-5 | JSON 파싱 실패, 타입 불일치, `afterId`·`messageId` 정수 아님 | `[]` |
| 401 | `UNAUTHENTICATED` | 전부 | 쿠키 없음·서명 불일치·만료 | `[]` |
| 404 | `NOT_FOUND` | F-3, F-4, F-5, 없는 경로 | 없음·남의 것·조건에 안 맞는 대상 | `[]` |
| 405 | `METHOD_NOT_ALLOWED` | 전부 | 지원하지 않는 메서드(프론트는 쓰지 않음) | `[]` |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | 본문 있는 것 | `Content-Type` 불일치(프론트는 쓰지 않음) | `[]` |
| 409 | `ANSWER_PENDING` | F-1 | 질문 답변 대기 중 | `[]` |
| 409 | `NO_PLAN` | F-5 | 저장된 계획 없음 | `[]` |
| 409 | `PLAN_CHANGED` | F-5 | `expectedRevision` 불일치, UPDATE 0행 | `[]` |
| 409 | `STALE_COMPARISON` | F-5 | 가장 최근 비교 아님, 또는 기준 버전 ≠ 현재 | `[]` |
| 422 | `VALIDATION_FAILED` | F-1, F-5 | 필드 검증 실패 | 1개 이상 |
| 422 | `FIELD_NOT_CHANGEABLE` | F-5 | 저장된 변경에 대화로 못 바꾸는 키 | 1개 이상 |
| 500 | `INTERNAL_ERROR` | 전부 | 예상하지 못한 오류, F-4 재계산 실패. `detail`에 내부 메시지 없음 | `[]` |

- **[v3] 500 코드는 한 곳에서 하나**: 전역 advice의 처리하지 못한 예외 기본값은 **`INTERNAL_ERROR`** 다. `/internal/calc`만 **그 컨트롤러 안의 `@ExceptionHandler`**(422 `minDisplay`를 붙이는 바로 그곳)가 자기 500을 **`CALC_FAILED`** 로 바꾼다(internal-calc C3-2 유지). 전역 advice에 경로별 분기를 넣지 않는다. 왜: 지금 #17 수용 기준은 "처리되지 않은 예외 → 500 `CALC_FAILED`"라 전역 advice 하나로는 두 계약을 동시에 만족할 수 없다. #17 기준을 `INTERNAL_ERROR`로, `CALC_FAILED`는 #32로 옮긴다(코드 차이 X-15).
- **Spring 기본 예외 매핑**(#17): `MethodArgumentTypeMismatchException` → 400 `MALFORMED_REQUEST`, `HttpMessageNotReadableException` → 400 `MALFORMED_REQUEST`, `NoResourceFoundException` → 404 `NOT_FOUND`, `HttpRequestMethodNotSupportedException` → 405 `METHOD_NOT_ALLOWED`, `HttpMediaTypeNotSupportedException` → 415 `UNSUPPORTED_MEDIA_TYPE`. 왜: 매핑하지 않으면 `code` 없는 Spring 기본 ProblemDetail이 나가 원칙 7이 깨진다.
- **모듈 예외는 `config`의 타입을 상속하지 않는다.** 권장 구현: 모듈 예외가 Spring `ErrorResponseException`을 상속하고 `ProblemDetail`에 `code`·`errors` 속성을 직접 담는다. 전역 advice는 `ErrorResponse`를 일반 처리만 하므로 새 코드가 늘어도 `config`를 고치지 않는다. 왜: 모듈 → config 의존이 생기면 config → 모듈과 합쳐 순환이다. 구현 방식 자체는 #17 재량.
- `MALFORMED_REQUEST`, `VALIDATION_FAILED`, `FIELD_NOT_CHANGEABLE`, `NO_PLAN`은 internal-calc C3-2와 같은 이름·뜻. 이 계약이 더하는 코드: `UNAUTHENTICATED`, `NOT_FOUND`, `METHOD_NOT_ALLOWED`, `UNSUPPORTED_MEDIA_TYPE`, `ANSWER_PENDING`, `PLAN_CHANGED`, `STALE_COMPARISON`, `INTERNAL_ERROR`. `NOTHING_TO_UNDO`는 #12-a(되돌리기).
- `errors[]`: `field`, `reason`, `min`·`max`·`unit`(OUT_OF_RANGE), `scale`(TOO_MANY_DECIMALS). **`minDisplay`·`maxDisplay`는 프론트 API에 없다**(C3-5).
- `unit`에 `CHAR` 추가(R-7). 받는 쪽은 모르는 값을 무시한다. Bean Validation `@Size`의 `min`·`max`를 `OUT_OF_RANGE`로 바꾸는 매핑 하나로 된다.
- `401`은 리소스 서버 `AuthenticationEntryPoint`(#16)가 쓴다. 필터에서 나오므로 `instance`가 없을 수 있다. 403은 쓰지 않는다(소유권 위반은 404).
- 오류별 프론트 동작은 각 절의 표(C12b-2 폴링, C12b-4 F-1, C12b-6 F-4, C12b-7-2 F-5, C12b-3a F-3)에 있다. 목 파일(C12b-12)과 일대일이다.

예시(`title`은 임시이며 프론트는 쓰지 않는다):

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
    { "field": "monthlySavingAmount", "reason": "OUT_OF_RANGE", "min": 10000, "max": 10000000, "unit": "KRW" }
  ]
}
```

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

## C12b-10. 모듈 의존 방향과 호출 순서 [합의]

### C12b-10-1. 적용 API 위치: 안 A (R-1)

| 안 | 위치 | 판단 |
|---|---|---|
| **A (채택)** | chat 컨트롤러 `POST /api/chat/messages/{id}/apply` → chat 서비스가 메시지 확인 → plan 공개 서비스(조건값 적용) | chat → plan 추가, plan `{}` 유지. 순환 없음. 대화 규칙(가장 최근 비교, D-041)은 대화를 아는 chat에 |
| B | plan 컨트롤러 `{source:"CHAT", chatMessageId}` | plan → chat. chat → calc → plan과 합쳐 순환 |
| C | 브라우저가 조건 값 전송 | D-033·원칙 4 위반 |
| D | chat 이벤트 → plan 수신 | plan → chat(이벤트 타입), 순환. HTTP 응답에 revision을 줄 수 없음 |

한 줄 이유: 의존을 "대화를 아는 쪽 → 계획을 아는 쪽" 한 방향으로만 두면 순환 없이 D-033·D-041을 서버에서 지킨다.

### C12b-10-2. 바뀌는 의존 (`package-info.java`)

| 모듈 | 지금 | 이 계약 뒤 | 이유 |
|---|---|---|---|
| `plan` | `{}` | `{}` | 대화를 모른다 |
| `calc` | `{plan, refdata}` | 변경 없음 | |
| `chat` | `{calc, rag}` | **`{calc, rag, plan, auth}`** | F-5 plan 적용, F-4 현재 계획 조회, auth 이벤트 수신·`@SkipRenewal` |
| `auth` | `{}` | **`{}`(변경 없음)** | 이벤트를 발행만 한다 |
| `config`(표 밖) | — | 어느 모듈도 `config`에 의존하지 않음 | 순환 방지 |

- **[v3] 바꾸는 시점은 #41**(paths가 `chat/**`라 `chat/package-info.java`를 이미 포함). `{calc, rag, plan, auth}`로 한 번에 바꾸고 `backend/CLAUDE.md` 모듈 표의 "의존 가능" 칸도 #41에서 고친다. 왜: #42(`@SkipRenewal`, auth)·#44(`currentVersionId`, plan)가 #45보다 먼저 이 의존을 쓰므로, #45에서 바꾸면 그 전 Issue의 `ModularityTests`가 깨진다.

```
chat ──▶ calc ──▶ plan
  │        └────▶ refdata
  ├──────▶ plan
  ├──────▶ rag
  └──────▶ auth   (MemberLoggedIn/MemberLoggedOut 수신, @SkipRenewal)
config ──▶ (auth, plan, calc, chat: 보안 필터 등록·예외 처리. 역방향 없음)
```

지켜야 할 것:
- (a) **calc → chat, plan → (chat·calc), auth → (어느 모듈이든)** 이 생기지 않는다.
- (b) chat은 auth 루트의 이벤트와 `@SkipRenewal`만 쓰고 `memberId`는 Spring Security 타입에서 얻는다.
- (c) 모듈은 `config` 타입을 쓰지 않는다(C12b-9).
- (d) plan 공개 API의 인자·반환·예외에 chat·calc·config 타입을 쓰지 않는다. 기준 버전은 `Long`, 변경은 `Map<String, JsonNode>`(camelCase).

### C12b-10-3. 호출 순서

**F-1 / F-3 (비동기 답변)**
```
브라우저 ─POST /api/chat/messages─▶ chat.web
  chat: 오래된 PENDING 정리 → ANSWER_PENDING 검사 → USER + ASSISTANT(ANSWER, PENDING) 저장 → ChatAnswerRequested  (한 트랜잭션)
  ◀─202 {userMessageId, assistantMessageId}
[커밋 뒤, 비동기] chat 리스너(#41, 트랜잭션 밖 HTTP)
  행이 PENDING이 아니면 끝 → calc.PlanContextProvider (chat → calc)
  ai-server POST /chat (연결 2초·응답 30초)  ── ai-server ─POST /internal/calc─▶ calc (필요할 때)
  짧은 트랜잭션: UPDATE ... AND status='PENDING' (condition_changes는 camelCase로 변환해 저장) → 1행이면 citation 저장
브라우저 ─GET /api/chat/messages?afterId─▶ (1초, @SkipRenewal) ... hasPending=false면 멈춤
```

**F-4 (비교 조회)**
```
브라우저 ─GET /api/chat/messages/{id}/comparison─▶ chat.web
  chat: findByIdAndMemberId, RECALC_RESULT·COMPLETED 확인
  calc.ChatComparisonQuery.recompute(memberId, calcRunId, conditionChanges)   (chat → calc, 범위 검사 없음)
  plan 현재 계획 조회: currentVersionId                                       (chat → plan)
  chat: applicable, changedKeys
  ◀─200
```

**F-5 (적용)**
```
브라우저 ─POST /api/chat/messages/{id}/apply {expectedRevision}─▶ chat.web
  chat: 메시지 확인(404) → 가장 최근 비교인지(409 STALE_COMPARISON)
  calc.ChatComparisonQuery.findChatRunPlanVersion = 기준 버전                  (chat → calc)
  plan.PlanApplyService.apply(memberId, CHAT, conditionChanges, expectedRevision, 기준 버전)   (chat → plan)
     └ plan 한 트랜잭션: NO_PLAN → 재검증 → PLAN_CHANGED → STALE_COMPARISON → INSERT·UPDATE(0행이면 롤백) → PlanChanged(APPLY)
  ◀─200 {revision}
[커밋 뒤, 비동기] calc 리스너: 새 버전 calc_run(PLAN)
브라우저: revision 갱신(대화창 버튼 비활성) → 결과 화면 다시 불러오기(#30·#31) → calcRunId가 바뀌고 status=CALCULATED면 #54가 F-3
```

**로그인·로그아웃 (C12b-8)**
```
브라우저 ─(#12-a 로그인/로그아웃)─▶ auth
  auth: 인증 성공(또는 로그아웃 요청) → publish MemberLoggedIn / MemberLoggedOut
     └ chat @EventListener(동기, 같은 스레드): DELETE FROM chat_message WHERE member_id = ?
  auth: 쿠키 발급(또는 만료) → 응답
```

## C12b-11. 시간 값과 PENDING 처리

### C12b-11-1. 임시값 (TBD-33 실측 전) [합의, R-3]

| 값 | 값 | 근거 |
|---|---|---|
| 폴링 간격 | **1초**, `hasPending=false`면 멈춤 | FR-AI-01 체감. PENDING일 때만 돈다 |
| Spring → ai-server 연결 타임아웃 | **2초** | 같은 Compose 네트워크 |
| Spring → ai-server 응답 타임아웃 | **30초** | 도구 호출 1~2회 + 생성 |
| 오래된 `PENDING` 기준 | **60초**(`created_at`) | 응답 타임아웃 + 재기동·재처리 여유 |
| 프론트 폴링 안전 상한 | 시간 상한 없음, **401 외 실패 연속 3회 중단**(C12b-2) | 서버가 60초 안에 `FAILED`로 바꾼다. 서버가 멈춘 경우·4xx 반복은 실패 중단이 막는다 |

- 값은 chat의 `@ConfigurationProperties` 하나와 프론트 상수 하나(폴링 간격)에 둔다.
- ai-server → `/internal/calc` 타임아웃은 30초보다 작게(예: 10초). ai-server 설정, H-2 메모.
- **구현 메모**: 리스너는 Boot 기본 `applicationTaskExecutor`에서 돌고 ai-server 호출 동안 스레드를 최대 30초 잡는다. 동시 질문이 몰리면 큐에서 기다리다 60초 정리로 `FAILED`가 될 수 있다(결과는 일관됨). Java 21이므로 `spring.threads.virtual.enabled=true` 한 줄로 푼다(#41).

### C12b-11-2. 리스너 규칙 (#41) [합의]

- 시작할 때 행이 `PENDING`이 아니면(정리됨·삭제됨) ai-server를 부르지 않고 끝낸다(재처리 멱등, `modulith.md`).
- 응답 타임아웃·연결 실패·ai 4xx/5xx·planContext 생성 실패 → `FAILED`·`FAILURE`, `content` = 문구표 `chat.failed`.
- 완료 갱신은 `UPDATE ... AND status='PENDING'`. **0행이면 버리고 citation을 저장하지 않는다**(C12b-8).
- `condition_changes`는 **camelCase로 바꿔 저장**한다(C12b-14).

### C12b-11-3. 오래된 PENDING 정리 [합의, R-9]

- F-1·F-2·F-3이 처리 전에 그 회원의 `status='PENDING' AND created_at < now() − 60초` 행을 `FAILED`·`FAILURE`·`chat.failed`로 바꾼다(`ix_chat_message_pending`).
- 왜 읽을 때 정리: 스케줄러 없이, 재기동 직후에도 사용자가 보는 순간 정리된다. F-2가 정리 후 조회하므로 같은 응답에 `FAILED`가 실린다.

## C12b-3a. (보충) F-3 설명 요청 `POST /api/chat/explanations` [합의]

> 번호는 v1과 같다.

요청:
```json
{ "calcRunId": 540 }
```

응답 `202`:
```json
{}
```

- **[v3] 본문은 빈 객체다.** v2의 `assistantMessageId`는 프론트가 쓰지 않아 뺐다(소비자 제안, 제공자 이견 없음). 프론트는 폴링으로 설명 메시지를 받는다. PENDING 재사용은 Spring 테스트(#43)가 DB 행 수로 확인한다. 왜 `{}`이고 빈 본문이 아닌가: 프론트 `fetch` 래퍼가 성공 응답을 항상 JSON으로 읽게 둔다.
- **[v3] 호출 지점은 #54 한 곳**: 결과 화면이 그린 **`calcRunId`가 바뀌고 `status=CALCULATED`이면** 부른다(effect 하나). 최초 결과 보기, 입력 수정, 적용 뒤, 되돌리기 뒤(TBD-26)가 모두 "결과 재조회 → `calcRunId` 바뀜"으로 이 한 지점에 모인다. #51(되돌리기)·#53(적용)은 결과 재조회까지만 하고 F-3을 부르지 않는다. 왜: 두 곳이 같은 `calcRunId`로 부르면 앞 설명이 이미 `COMPLETED`일 때 PENDING 재사용이 안 되어 설명이 두 개 생긴다. 옛 `calcRunId`로 부르는 일도 구조적으로 없어진다.
- **초과 계획(`status=ALREADY_EXCEEDED`)에서는 부르지 않는다**(D-062). 불리면 서버는 정상 처리하고 ai-server가 LLM 없이 `chat.alreadyExceeded`로 답한다(방어용).
- **404 규칙**(C1a-10): 없는 `calcRunId`, 남의 기록, CHAT 기록은 모두 같은 `404 NOT_FOUND`. 판단은 `calc.PlanContextProvider.findPlanRun(memberId, calcRunId)`(#78) 하나.
- 서버 동작: 오래된 PENDING 정리 → `findPlanRun` → ASSISTANT(`EXPLANATION`, `PENDING`, `calc_run_id`, `baseline_scenario` = `PlanRunRef.baselineScenario`) 저장 → `ChatAnswerRequested` → 리스너 mode=`EXPLAIN`(#43).
- **같은 `calcRunId`로 이미 `PENDING`인 설명이 있으면 새 행 없이 `202`**(R-4). 조회는 `ix_chat_message_run`. 동시 두 요청이 둘 다 못 찾아 2행이 생기는 경우는 무해(잠금 없음).
- F-3은 `ANSWER_PENDING`으로 막지 않는다. `retryOfMessageId`(FR-AI-05, Should)는 범위 밖.

오류와 프론트 동작:

| HTTP | `code` | 프론트 동작 |
|---|---|---|
| 400 | `MALFORMED_REQUEST` | 설명 자리에 아무것도 그리지 않음(대화창에 오류를 쓰지 않음) |
| 404 | `NOT_FOUND` | 결과 화면을 다시 불러온다. **`calcRunId`가 바뀌면 위 호출 지점이 한 번만** 다시 부른다. 같거나 또 실패하면 아무것도 그리지 않음 |
| 500 / 네트워크 | `INTERNAL_ERROR` | 아무것도 그리지 않음 |
| 401 | `UNAUTHENTICATED` | 로그인 화면 |

## C12b-12. 목(mock) JSON 목록 (`frontend/src/mocks/chat/`) [합의]

**파일 형식**: 파일 하나 = **응답 배열**(호출 순서대로). 응답이 하나면 길이 1 배열이다. 새 라이브러리(MSW 등) 없음.

```json
{
  "responses": [
    { "status": 200, "headers": { "Content-Type": "application/json" },
      "body": { "messages": [ "...PENDING..." ], "hasPending": true, "answerPending": true } },
    { "status": 200, "headers": { "Content-Type": "application/json" },
      "body": { "messages": [ "...RECALC_RESULT COMPLETED..." ], "hasPending": false, "answerPending": false } }
  ]
}
```

**[v3] 목 선택 방식(래퍼 계약, #13)**
1. **요청 키 = 메서드 + 경로**(쿼리 제외). 예: `GET /api/chat/messages`, `POST /api/chat/messages/1031/apply`.
2. 요청 키마다 기본 파일이 하나 있다(아래 표의 "기본" 표시). **같은 키의 다른 파일은 개발·테스트 전용 `useMock(파일명)` 호출로 고른다.** 화면 코드는 이 함수를 부르지 않는다.
3. 래퍼는 고른 파일의 i번째 호출에 i번째 응답을 돌려주고, 배열 끝을 넘으면 마지막 응답을 반복한다. **`status`·`headers`를 그대로 반영**한다(4xx·5xx는 실제 `fetch`와 같은 오류 경로로).
4. **F-4 목은 서로 다른 `messageId`를 쓴다**: 정상 `1031`, not-applicable `1027`, ETF 0% `1033`. 경로 키만으로 구분되어 한 화면에 여러 카드를 띄울 수 있다. F-4 오류 목(400·404·500)은 `useMock`으로 고른다.

- `body`는 **줄임표 없이** 이 문서의 예시 값으로 채운다(위 블록의 `"..."`는 설명용). F-4 정상은 internal-calc 부록 A-1에서 `calcRunId`를 지우고 `messageId: 1031`, `applicable: true`, `changedKeys: ["monthlySavingAmount"]`를 더한다.
- 예시 id(1029/1030/1031, calcRunId 540)는 #42·#45 Spring 테스트(REST Docs) 스니펫과 같은 값을 쓴다. REST Docs 스니펫은 단일 응답이므로 배열 목의 각 원소가 스니펫 하나와 같도록 맞춘다.

| 파일 | 엔드포인트 | 응답(순서) | 내용 |
|---|---|---|---|
| `post-messages.202.json` (기본) | F-1 | 202 | C12b-4 응답 |
| `post-messages.400.json` | F-1 | 400 | `MALFORMED_REQUEST` |
| `post-messages.422-required.json` | F-1 | 422 | `text` REQUIRED |
| `post-messages.422-too-long.json` | F-1 | 422 | `text` OUT_OF_RANGE `min 1, max 2000, unit CHAR` |
| `post-messages.409-answer-pending.json` | F-1 | 409 | `ANSWER_PENDING` |
| `post-messages.500.json` | F-1 | 500 | `INTERNAL_ERROR` |
| `get-messages.200-restore-empty.json` (기본) | F-2 | 200 | `{messages: [], hasPending: false, answerPending: false}`(로그인 직후) |
| `get-messages.200-restore-history.json` | F-2 | 200 | 복원: 과거 `RECALC_RESULT` 2개 이상(이전 카드 + 최신 카드), EXPLANATION 1개 |
| **`get-messages.200-restore-pending.json`** [v3] | F-2 | 200 | 복원인데 USER + ASSISTANT PENDING, `hasPending: true`, `answerPending: true`(새로고침 중 보내기 버튼 막기, 복원 안전장치 시험) |
| `get-messages.seq-question-recalc.json` | F-2 | 200 → 200 | USER + ASSISTANT PENDING(`answerPending: true`) → `RECALC_RESULT` COMPLETED(`hasPending: false`) |
| `get-messages.seq-explanation.json` | F-2 | 200 → 200 | 설명 PENDING(`hasPending: true`, `answerPending: false`) → `EXPLANATION` COMPLETED, citations 2개(서로 다른 운용사, FR-AI-03) |
| `get-messages.200-failed.json` | F-2 | 200 | 질문 답변 `FAILURE`/`FAILED`, `content` = 실패 안내 |
| `get-messages.200-explanation-failed.json` | F-2 | 200 | 설명 요청의 `FAILURE`/`FAILED`(앞 메시지가 USER가 아닌 맥락) |
| `get-messages.200-clarify.json` | F-2 | 200 | `CLARIFY`(범위 밖 값·상대 표현 되묻기, D-033·D-059) |
| `get-messages.200-out-of-scope.json` | F-2 | 200 | `OUT_OF_SCOPE` |
| `get-messages.seq-500x3.json` | F-2 | 500 → 500 → 500 | 연속 3회 실패 중단 테스트 |
| `get-messages.401.json` | F-2 | 401 | 폴링 중 만료 |
| `post-explanations.202.json` (기본) | F-3 | 202 | `{}` |
| `post-explanations.404.json` | F-3 | 404 | `NOT_FOUND` |
| `post-explanations.500.json` | F-3 | 500 | `INTERNAL_ERROR` |
| `get-comparison.200.json` (기본, `/1031`) | F-4 | 200 | internal-calc A-1 기반 전체 본문, `messageId: 1031`, `applicable: true` |
| `get-comparison.200-not-applicable.json` (`/1027`) | F-4 | 200 | 같은 본문, `messageId: 1027`, `applicable: false` |
| `get-comparison.200-etf0.json` (`/1033`) | F-4 | 200 | ETF 0%, 시나리오 AVG 1개, `messageId: 1033` |
| `get-comparison.400.json` | F-4 | 400 | `MALFORMED_REQUEST` |
| `get-comparison.404.json` | F-4 | 404 | `NOT_FOUND` |
| `get-comparison.500.json` | F-4 | 500 | `INTERNAL_ERROR`(재계산 실패) |
| `post-apply.200.json` (기본) | F-5 | 200 | `{revision: 13}` |
| `post-apply.409-plan-changed.json` | F-5 | 409 | `PLAN_CHANGED` |
| `post-apply.409-stale.json` | F-5 | 409 | `STALE_COMPARISON` |
| `post-apply.409-no-plan.json` | F-5 | 409 | `NO_PLAN` |
| `post-apply.422-validation.json` | F-5 | 422 | C12b-9 예시(`min`·`max`·`unit`, display 키 없음) |
| `post-apply.422-field-not-changeable.json` | F-5 | 422 | `FIELD_NOT_CHANGEABLE`, `errors: [{field: "goalAmount", reason: "FIELD_NOT_CHANGEABLE"}]` |
| `post-apply.404.json` | F-5 | 404 | `NOT_FOUND` |
| `post-apply.500.json` | F-5 | 500 | `INTERNAL_ERROR` |
| `common.401-unauthenticated.json` | 전부 | 401 | C12b-9 401 예시. 래퍼 공통 401 분기 테스트용 |

- 총 **35개**(v2 35개 − `post-explanations.seq-reuse.json` + `get-messages.200-restore-pending.json`). `seq-reuse`는 F-3 응답에 id가 없어져 프론트에서 확인할 것이 없으므로 뺐다.
- Issue #12 수용 기준 "정상, 422, 401, 409를 모두 받을 수 있다": F-1(202·422·409), F-2(200·401), F-5(200·409·422), 공통 401. 404·400·500도 있다.
- `FIELD_NOT_CHANGEABLE`의 `errors[].reason` 값은 internal-calc C3-1의 해당 행을 따른다. 위 예시의 `reason` 문자열이 C3-1과 다르면 C3-1이 기준이다.

## C12b-13. #12-a(및 A팀)에 요구하는 것 [합의]

| # | 요구 | 담당 Issue | 추가 비용(제공자 추정) | 왜 |
|---|---|---|---|---|
| 1 | **plan 공개 적용 서비스**(아래 시그니처). 검사 5~10, 기준 버전 검사, **0행 롤백** | A, **#33** | +0.5일 | F-5가 부른다 |
| 2 | 401 `AuthenticationEntryPoint`가 C3-1 형식 | A, **#16** | 0 | Issue #12 수용 기준(예외) |
| 3 | F-2에 `@SkipRenewal`(auth 루트 타입, 인터셉터 또는 필터 + `HandlerMappingIntrospector`) | A, **#34** | 0 | D-052 |
| 4 | 현재 계획·결과 응답에 **`revision`, `calcRunId`(PLAN), `result.status`**. **[v3] 입력 저장(결과 보기) 응답에 `revision`** | A, **#31**(현재 계획 조회), **#30**(결과 보기 = 입력 저장 REST). #19는 저장 서비스가 새 `revision`을 반환 | 필드 3개, 0.25일 | F-5 `expectedRevision`, F-3 `calcRunId`, D-062 |
| 5 | 되돌리기 응답에 새 **`revision`**. 되돌리기 방식 [D-068] | A, **#33** | B안이면 INSERT 1문장·테스트 1건(0.25일) | C12b-7-4 |
| 6 | **[v3]** calc 공개 API `ChatComparisonQuery`(기준 버전 조회, 범위 검사 없는 재계산 + display)와 버전 지정 기준 데이터 조회(refdata 3메서드) | A, **#78**(기록 재현 코드를 `PlanContextProvider.findForCalcRun`과 공유). `calc_run` 조회는 **#29** 리포지토리 재사용 | 약 1일 | F-4·F-5 |
| 7 | plan 공개 현재 계획 조회에 `currentVersionId` | A, **#19**(G-12와 같은 API) | 필드 1개 | F-4 `applicable` |
| 8 | **[v3]** 이벤트 record + 발행(쿠키 응답 전) + `auth/package-info.java` 문장 | A, **#16**(`MemberLoggedIn`, package-info)·**#34**(`MemberLoggedOut`). 수신은 B **#46** | 0.25일 | D-051, C12b-8 |
| 9 | **[v3]** 전역 advice: C12b-9 코드, 500 기본값 `INTERNAL_ERROR`, Spring 기본 예외 매핑. 모듈 예외 `config` 상속 금지. `/internal/calc`의 500 `CALC_FAILED`·422 `minDisplay`는 그 컨트롤러의 `@ExceptionHandler` | A, **#17**(전역), **#32**(`/internal/calc` 한정) | `ErrorResponseException` 방식이면 0에 가까움 | 원칙 7, 코드 차이 X-15 |
| 10 | **[v3]** 결과 화면이 `revision`·`calcRunId`·`status`를 공유 상태로 둔다. 되돌리기·적용 뒤에는 결과 재조회까지만(F-3은 #54) | 프론트 A **#51**(되돌리기 토스트)·**#49**(결과 화면), B **#54**(F-3 호출) | Spring 영향 없음 | C12b-3a, C12b-7-3 |

요구 1 시그니처(인자·검사 순서·예외 종류는 계약, 세부는 A팀 재량):
```java
// plan 루트 패키지(공개 API). chat·calc·config 타입을 쓰지 않는다.
public interface PlanApplyService {
    /**
     * 바꾼 조건을 현재 계획에 적용한다. 한 트랜잭션. 시작월은 현재 버전 값(D-013).
     * UPDATE 0행이면 PlanChangedException으로 롤백한다.
     * @param path ALTERNATIVE·COMPARE·CHAT만 허용(INPUT_EDIT이면 IllegalArgumentException)
     * @param expectedBaseVersionId 비교의 기준 버전. null이면 검사하지 않음(대안·비교 적용)
     */
    PlanApplyResult apply(long memberId, ChangePath path, Map<String, JsonNode> conditionChanges,
                          long expectedRevision, Long expectedBaseVersionId);
}
public record PlanApplyResult(long planVersionId, Long previousVersionId, long revision) {}
// 예외(plan 루트, config 타입 상속 금지): NoPlanException(NO_PLAN), ConditionViolationException(VALIDATION_FAILED/FIELD_NOT_CHANGEABLE),
//                 PlanChangedException(PLAN_CHANGED), StaleBaseVersionException(STALE_COMPARISON)
```
- `ConditionValidator`는 검증 결과를 **타입 있는 값 record**로 돌려준다(다시 파싱하지 않게). **[v3]** F-4용 "범위 검사 없이 타입만 바꾸는" 사용 방식도 같은 record로 지원한다(#17 재량).
- ERD Q4-b의 SQL에 기준 버전 검사를 더한다(코드 차이 X-6).

## C12b-14. ai-server에 미치는 영향 [합의]

- **새 필드·새 엔드포인트 없음.** F-1·F-3은 지금의 `ChatRequest`·`ChatResponse`를 쓴다.
- **키 표기 및 저장 실패 처리(D-090, CF12-10-1)**: chat 저장 코드는 아직 없으며 **#44·#45·#128(OPEN, B팀)** 이 쓴다. 변환 맵은 처음부터 **5키**(`goal_amount → goalAmount` 포함)로 두고, camelCase 변환 시 **맵에 없는 키가 하나라도 있으면 그 키만 버리지 않고 변환 실패로 간주해 해당 ASSISTANT 메시지를 `FAILED`로 남긴다(`RECALC_RESULT`로 저장 금지, 부분 저장 금지, 기존 `chat.failed` 재사용, 턴 전체 500 아님)**. F-4 재계산·F-5 적용은 저장된 camelCase를 변환 없이 쓴다.
- **`ConditionChanges`**: #21에서 4키로 축소됐으나 **CF12(D-090·D-092)로 5키(`goal_amount` 추가)로 재확장**한다. F-2가 `conditionChanges`를 내보내지 않으므로 프론트에는 새지 않는다.
- F-1에서 계획이 없으면 Spring이 `baselineScenario: "AVG"`를 채운다(C12b-4). `history[].role`은 Spring이 소문자로 바꾼다.
- 위험 메모(제공자): Spring은 ai-server가 보고한 `conditionChanges`가 실제 `/internal/calc`에 보낸 값과 같은지 검증하지 못한다(`calc_run`에 변경값 미저장, ADR-002). 다르면 F-4 카드가 AI 문장과 어긋난다(카드와 적용은 서로 일치하므로 계획 데이터는 안전). **ai-server 테스트(#23)에서 "보고값 = 보낸 값"을 고정**한다.

## C12b-15. moeun 현재 코드·문서와 다른 곳 (코드 차이) [합의]

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| X-1 | `chat/package-info.java`, `backend/CLAUDE.md` 모듈 표 | `{"calc", "rag"}` | `{"calc", "rag", "plan", "auth"}` | H-6(**#41**) [v3] |
| X-2 | `auth/package-info.java:4` | "이 모듈을 직접 의존하지 않는다" | **chat → auth**(이벤트 수신·`@SkipRenewal`), auth `{}` 유지, 문장을 "auth 루트의 이벤트·`@SkipRenewal`만 쓴다"로 | H-9(**#16**) [v3] |
| X-3 | `chat_message` PENDING 행 `message_type` | 정한 곳 없음(NOT NULL) | 질문 대기 `ANSWER`, 설명 대기 `EXPLANATION`. 화면에는 `null` | H-3 |
| X-4 | `db/erd.md` §4 Q2-b | `id > last_seen OR id = ANY(pending_ids)` | `id > afterId` 하나 | H-3b |
| X-5 | `db/erd.md` §5-G, ADR-002 §2-5 | "로그아웃은 클라이언트가 토큰을 지움" | 서버 로그아웃 + 대화 삭제(D-051, D-052) | #12-a, 문서 |
| X-6 | `db/erd.md` §4 Q4-b | revision만 검사 | + 기준 버전 검사 | H-7 |
| X-7 | `ai-server/app/schemas.py` `ConditionChanges` | 7키, snake_case | 4키(#21), 저장은 camelCase(#41) | #21, H-2 |
| X-8 | `b-team-contracts.md` §3·§4 A-1 | `POST /api/plan/apply {source:"CHAT", chatMessageId}`, F-4 `planRevision` | F-5 chat 경로, `planRevision` 없음 | H-12 |
| X-9 | `modulith.md` 이벤트 표 | — | **`auth.MemberLoggedIn`/`MemberLoggedOut` 두 행 추가**(발행 auth, 수신 chat, 동기) | H-9(#46) |
| X-10 | `persistence.md:14`, `moved-to-code.md`(멱등 키 행), **#19 수용 기준** [v3] | "0행이면 현재 상태를 돌려준다" | `409 PLAN_CHANGED` + 롤백, 본문에 상태 없음 | H-7(#33), H-7b(**#19**) |
| X-11 | `modulith.md:24` | 수신은 `@ApplicationModuleListener` | 대화 삭제는 동기 `@EventListener` 예외 1줄 | H-9(#46) |
| X-12 | #46 본문 | 이벤트 이름 `LoggedIn`, 수신 방식 미정, paths에 `auth/LoggedIn.java` | `MemberLoggedIn`/`MemberLoggedOut`, 동기 수신, chat → auth 허용, **paths에서 `auth/` 제거** [v3] | H-9 |
| X-13 | #44 수용 기준 | "snake_case 저장 → camelCase로 바꿔 넘김" | 저장이 camelCase(#41), #44는 변환 없음 | H-2, H-5 |
| X-14 | `db/erd.md` §4 Q4-c, **`schema.sql` `source` 주석, `db/tables.md`** [v3] | 되돌리기 = 포인터 교체, `source` = "이 버전을 만든 경로" | (쟁점 X-1 B일 때만) 직전 버전 복사 INSERT + 포인터 이동, `source` = "복사한 원본의 경로"(CHECK 변경 없음) | H-7(#33) |
| **X-15** [v3] | #17 수용 기준 | "처리되지 않은 예외 → 500 `code=CALC_FAILED`" | 전역 500 `INTERNAL_ERROR`. `CALC_FAILED`는 `/internal/calc` 컨트롤러 한정(#32) | H-10(#17), H-8(#32) |

## C12b-16. 열린 질문(Q-051~055)의 영향 (v1과 같음)

| 질문 | 이 계약에 미치는 영향 |
|---|---|
| Q-051 초과 계획의 대화창 | A·B: API 변경 없음(B는 프론트가 문구표 한 줄. 결과 화면 `status`로 판단하므로 요구 4로 충분). C: F-1에 `409 ALREADY_EXCEEDED` + 목 1개, F-1이 현재 계획을 한 번 더 읽음 |
| Q-052 질문 예시 버튼(Should) | A: 변경 없음. B: 새 엔드포인트(이 계약 밖) |
| Q-053 `±1만원 미만` 부호 | F-4 `display` 문자열 하나. 목 A-1 값에는 해당 경계 없음 |
| Q-054 대화 고지 | A: 프론트 고정 한 줄. B: `content` 끝에 덧붙임, 모양 변경 없음 |
| Q-055 세금 질문 경계 | 없음 |

이 계약에서 새로 올리는 질문: **Q-056(쟁점 X-1)**, **Q-057(쟁점 X-2)**. 둘 다 이 문서 머지를 막지 않는다.

## C12b-17. Issue #12 수용 기준 대응표 (#12-b 범위)

| # | 수용 기준 | 이 문서 | 비고 |
|---|---|---|---|
| 1 | 각 엔드포인트의 요청·응답·오류 코드 예시 | C12b-3a·4~7, C12b-9 | `NOTHING_TO_UNDO`는 #12-a |
| 2 | chatMessageId 적용에서 plan → chat 의존이 생기지 않는 호출 방향 | C12b-10 | |
| 3 | 목 JSON으로 정상·422·401·409 | C12b-12 | 응답 배열 형식, 선택 방식은 #13 |
| 4 | (예외) 401 예시가 C3-1 형식 | C12b-2, C12b-9 | 구현 #16 |
| 5 | 422 `errors[]`에 `min`·`max`·`unit`, `minDisplay`·`maxDisplay` 없음 | C12b-9, C12b-7-1 | |
| 6 | (예외) F-3: 없는·남의·CHAT 기록 모두 같은 404 | C12b-3a | |
| 7 | F-3: 초과 계획은 F-3을 부르지 않음(D-062) | C12b-3a | |
| 완료 조건 | `ModularityTests`를 깨지 않음 | C12b-10-2 | chat 의존 변경은 #41에서 먼저 |

## C12b-18. 이 계약 때문에 생기는 후속 작업 (D-058: 기존 Issue 본문에 반영) [합의]

| # | 작업 | 팀 | Issue | 선행 변경 |
|---|---|---|---|---|
| H-1 | 최종본의 B 부분을 `docs/api/frontend-api.md`로, 목 35개(응답 배열 형식, F-4 messageId 분리)를 `frontend/src/mocks/chat/`에 | 공통 | **#12** | — |
| H-2 | 리스너: PENDING 아니면 미호출, `AND status='PENDING'` 갱신, **0행이면 citation 미저장**, **camelCase 저장**, `baselineScenario` 없으면 `AVG`, `history.role` 소문자, 연결 2초·응답 30초(설정 키), 실패 → `chat.failed`, 가상 스레드. ai-server `/internal/calc` 타임아웃 < 30초 메모 | B | **#41** | — |
| H-3 | F-1: trim 저장·UTF-16 길이, `ANSWER_PENDING`(질문 대기만), PENDING 자리표시 `ANSWER` 고정, 오래된 PENDING 정리. **[v3] 수용 기준 "202 … status=PENDING"을 `{userMessageId, assistantMessageId}`로 정정** | B | **#41** | — |
| H-3b | F-2: `afterId` 폴링·복원 50개, `hasPending`·`answerPending`, PENDING `messageType=null`, `conditionChanges`·`rank` 미노출, 쓰기 트랜잭션, `@SkipRenewal`, 출처 일괄 조회(Q2-c), `db/erd.md` Q2-b 정정 | B | **#42** | 선행 #34 |
| H-4 | F-3: `findPlanRun` 404 한 경로, 같은 `calcRunId` PENDING 재사용(DB 행 수로 테스트), `ANSWER_PENDING` 제외, **[v3] 202 본문 `{}`** | B | **#43** | — |
| H-5 | F-4: `ChatComparisonQuery.recompute`로 재계산(범위 검사 없음, 실패 500), `display`·`changedKeys`(순서 보장 없음)·`applicable`, `monthlyPoints` 없음, 400·404·500. 수용 기준의 snake_case 문장 교체(코드 차이 X-13) | B | **#44** | **[v3] 기존 선행에 #21·#78·#19 추가** |
| H-6 | F-5 chat 컨트롤러·서비스(검사 1~4), **[v3] 응답 `{revision}`**. **[v3] `package-info`·`backend/CLAUDE.md`는 #45에서 뺀다(H-6b)** | B | **#45** | 선행 #33, #44, #21 |
| **H-6b** [v3] | chat `package-info.java`를 `{calc, rag, plan, auth}`로, `backend/CLAUDE.md` 모듈 표 "의존 가능" 칸(코드 차이 X-1) | B | **#41** | paths에 `backend/CLAUDE.md` 추가 |
| H-7 | `PlanApplyService`·`PlanApplyResult`·예외, 검사 5~10, 기준 버전 검사, 0행 롤백, `path` 제한, `persistence.md:14` 정정(X-10), ERD Q4-b 정정, 되돌리기 응답 `revision`. (쟁점 X-1 B면) 되돌리기 복사 INSERT, **[v3] 읽기 → `NOTHING_TO_UNDO` → `PLAN_CHANGED` → INSERT → 조건부 UPDATE 순서, `source` 주석·`db/tables.md` 1줄**, ERD Q4-c(X-14). `undoAvailable=true`(plan REST)는 유지 가능 | A | **#33** | — |
| H-7b | **[v3]** 저장 서비스가 새 `revision`을 반환, 공개 현재 계획 조회에 `currentVersionId`, 수용 기준 "0행이면 현재 상태를 돌려준다" 정정(X-10) | A | **#19** | — |
| H-7c | 현재 계획·결과 응답에 `revision`·`calcRunId`·`result.status`, **[v3] 입력 저장(결과 보기) 응답에 `revision`** | A | **#31**, **#30** | — |
| H-8 | **[v3]** `/internal/calc` 컨트롤러 한정 `@ExceptionHandler`: 422 `minDisplay`, 500 `CALC_FAILED`(X-15) | A | **#32** | — |
| **H-8b** [v3] | calc 루트 `ChatComparisonQuery`·`ChatComparisonView`(display `Map`, 범위 검사 없는 재계산), 버전 지정 기준 데이터 조회(`ReferenceDataService` 3메서드), `findForCalcRun`과 공용 "기록 재현" 코드 | A | **#78** | paths에 `calc/ChatComparisonQuery.java`·`calc/ChatComparisonView.java`·`refdata/ReferenceDataService.java`(+ 테스트). 너무 크면 A팀이 같은 선행으로 분리 가능 |
| H-9 | **[v3] 재배치**. A: `MemberLoggedIn` record·발행(쿠키 응답 전)·`auth/package-info.java` 문장(**#16**), `MemberLoggedOut` record·발행·만료 토큰 로그아웃 401 메모(**#34**). B: 동기 `@EventListener` + 일괄 DELETE, `modulith.md` 예외 1줄·이벤트 표 2행, 수용 기준 "로그인 응답 전에 삭제가 끝남(동기)"·"auth `{}` 유지"(**#46**) | A·B | **#16**, **#34**, **#46** | #46 paths에서 `auth/LoggedIn.java` 제거, #16·#34 paths에 각 record |
| H-10 | 전역 오류 처리: 새 코드, **[v3] 수용 기준 500 `CALC_FAILED` → `INTERNAL_ERROR`(X-15)**, Spring 기본 예외 매핑(400·404·405·415), 모듈 예외 `config` 상속 금지, F-4용 "타입만 변환" 사용 방식. 401 엔트리 포인트 | A | **#17**, 401은 **#16** | — |
| H-10b [v3] | `@SkipRenewal` 구현 메모(인터셉터 또는 필터 + `HandlerMappingIntrospector`) | A | **#34** | — |
| H-11 | 프론트: 폴링(1초, `afterId` 규칙, upsert), **[v3] 401 외 실패 연속 3회 중단, 복원 안전장치 1회의 범위(폴링 멈춤 또는 F-1·F-3까지)**, `answerPending`으로 보내기 버튼, F-1 오류별 동작. 폴링 훅이 `hasPending`·`answerPending` 노출 | B | **#52** | — |
| H-11b | 프론트: F-4는 최신 RECALC만, 새 RECALC 도착 시 이전 버튼 비활성, 버튼 활성 한 줄, F-4 500 카드(버튼·재시도 없음), F-5 오류별 동작, 성공 뒤 순서(F-3 호출 없음), **[v3] `revision` 구독으로 버튼 전부 비활성(최초 로드 제외, D-069)**, ETF 0% 카드, `achievementChange`·조건 4개 라벨 키 | B | **#53** | — |
| H-11c | 프론트: **[v3] F-3 호출 지점 하나**("결과 `calcRunId`가 바뀌고 `status=CALCULATED`면 부른다"), F-3 오류별 동작(404는 재조회 뒤 한 번), D-062 | B | **#54**(+ #49 교차참조) | — |
| H-11d | 되돌리기 토스트가 `revision`을 들고 있음, 되돌리기 성공 뒤 **결과 재조회까지**(F-3 호출 없음) | A | **#51** | — |
| H-11e | **[v3]** 목 제거: paths에 `frontend/src/features/chat/**` 포함. **소유 팀 확인 필요**(#55는 `team:A`라 B팀 파일을 고치게 됨 → `team:common`으로 바꾸거나 대화 목 제거를 B팀 Issue 한 줄로 분리) | A·B(확인) | **#55** | 선행에 #45, #52, #53, #54 추가 |
| H-12 | `b-team-contracts.md` §3·§4 A-1·§6, `alignment.md` 2-4를 이 계약으로 정정(X-8) | 기획 | 문서 | — |
| H-13 | `ConditionChanges` 4키로 축소(D-040) — #44·#45 선행 | B | **#21** | — |
| H-14 | ai-server 테스트: 보고한 `conditionChanges` = `/internal/calc`에 보낸 값 | B | **#23** | — |
| H-15 | 문구표 키: 폴링 실패 안내, F-1·F-5 토스트, F-4 카드 실패, `achievementChange` 4값, **[v3] 조건 4개 라벨**(`monthlySavingAmount`·`savingsRatioPct`·`savingsRateInputPct`·`targetPeriodMonths`, 키 이름 예 `condition.<camelCase 키>`) | 공통 | **#18** | — |
| **H-16** [v3] | 프론트 `fetch` 래퍼: 목 선택 방식(요청 키 = 메서드 + 경로, `useMock(파일명)`, 배열 순서·끝이면 마지막 반복, `status`·`headers` 반영), F-4 messageId 분리. **같은 사이트 전제**(`SameSite=Lax`, Vite 프록시로 `/api`) | 공통(프론트 초기 설정) | **#13** | — |

---

## 합의 목록

검토 네 건(v1·v2 각 제공자·소비자)에서 양쪽 수용, 또는 한쪽 제안에 다른 쪽 이견이 없어 반영한 것. **75건**(v2 56건 + v3 19건. v2 항목 중 5·14·23·24·28은 v3에서 문장을 고쳤다).

| # | 항목 | 내용 | 제안 |
|---|---|---|---|
| 1 | C12b-1 | 엔드포인트 5개, 삭제용 프론트 엔드포인트 없음 | 양쪽 |
| 2 | C12b-1·9 | F-4에 400 `MALFORMED_REQUEST` | 소비자 |
| 3 | C12b-2 | `SameSite=Lax` 이상 필수 | 제공자 |
| 4 | C12b-2 | `memberId`는 Spring Security 타입으로만 | 제공자 |
| 5 | C12b-2 | 폴링 **401 외 모든 실패** 연속 3회 중단 [v3 수정] | 소비자 |
| 6 | C12b-3 | PENDING 자리표시 `message_type='ANSWER'` 고정(설명은 `EXPLANATION`) | 제공자 |
| 7 | C12b-5 | F-2에 `answerPending` 추가(6과 같은 조건) | 소비자 |
| 8 | C12b-3 | F-2 응답에서 `conditionChanges` 제외 | 소비자 |
| 9 | C12b-3 | `citations[].rank` 제외(배열 순서) | 소비자 |
| 10 | C12b-3·5 | id ≠ 커밋 순서 인정, 복원 1회 안전장치 | 제공자 |
| 11 | C12b-4 | trim한 문자열로 검사·저장·전송 | 제공자 |
| 12 | C12b-4 | 길이는 UTF-16 단위 | 소비자 |
| 13 | C12b-4 | "`text`가 문자열 아님 → 400" 삭제 | 제공자 |
| 14 | C12b-4·3a | 202 응답의 `status` 제외. **F-3 202는 `{}`** [v3 수정] | 소비자 |
| 15 | C12b-4 | `ANSWER_PENDING` 프론트 동작(버튼 비활성·폴링 재개·글 유지) | 소비자 |
| 16 | C12b-4 | F-1 500 `INTERNAL_ERROR` 행 | 소비자 |
| 17 | C12b-4·14 | 계획 없을 때 `baselineScenario=AVG`, `history.role` 소문자 변환 | 소비자 |
| 18 | C12b-5 | `afterId` 폴링·복원 50개·upsert | 양쪽 |
| 19 | C12b-5 | `hasPending=false` 보장 문장 | 소비자 |
| 20 | C12b-5 | F-2는 쓰기 트랜잭션(구현 메모) | 제공자 |
| 21 | C12b-6 | 당시 기준 재계산·`applicable` 조건·404 일원화 | 양쪽 |
| 22 | C12b-6 | calc 루트 `ChatComparisonQuery`, display는 `Map<String,String>` | 제공자 |
| 23 | C12b-6 | 버전 지정 기준 데이터 조회를 `ChatComparisonQuery`와 함께 **#78**에서 만들어 공유 [v3 수정] | 제공자 |
| 24 | C12b-6 | `changedKeys`, **순서 보장 없음(집합)** [v3 수정] | 소비자, 제공자 |
| 25 | C12b-6 | F-4는 가장 최근 RECALC만 자동 호출, 이전은 접음 | 소비자 |
| 26 | C12b-6 | 새 RECALC 도착 시 이전 버튼 즉시 비활성, 버튼 활성 한 줄 | 소비자 |
| 27 | C12b-6 | `achievementChange` 문구표 키를 #18·#53에 | 소비자 |
| 28 | C12b-7 | F-5 응답을 **`{revision}`** 으로 축소 [v3 수정] | 양쪽 |
| 29 | C12b-7-1 | 검사 순서 유지 + 검사 9 잠금 없는 이유 | 제공자 |
| 30 | C12b-7-1 | UPDATE 0행이면 런타임 예외로 롤백 | 제공자 |
| 31 | C12b-7-1 | R-10 이유 문장 정정, 3·9 같은 코드 유지 | 제공자, 소비자 |
| 32 | C12b-7-1 | `/internal/calc` `minDisplay` 처리를 그 컨트롤러 한정 | 제공자 |
| 33 | C12b-7-2 | 오류 동작에 401·500·네트워크·`MALFORMED_REQUEST`·`NO_PLAN` 대화창 유지 추가 | 소비자 |
| 34 | C12b-7-3 | 성공 뒤 순서, PLAN 기록 중복은 무해(유일 제약 없음) | 양쪽 |
| 35 | C12b-8 | 대화 삭제 = auth 이벤트 발행 + chat 동기 `@EventListener`(R-5) | 양쪽 |
| 36 | C12b-8 | 한 문장 일괄 DELETE | 제공자 |
| 37 | C12b-8·11 | 완료 갱신 0행이면 citation 미저장 | 제공자 |
| 38 | C12b-8 | 만료 토큰 로그아웃은 401, 다음 로그인 때 삭제 | 제공자 |
| 39 | C12b-9 | Spring 기본 예외 `code` 매핑 | 제공자 |
| 40 | C12b-9 | 모듈 예외는 `config` 타입 상속 금지(`ErrorResponseException` 권장) | 제공자 |
| 41 | C12b-10 | 안 A(R-1) + 의존 표(chat `{calc, rag, plan, auth}`, auth `{}`) | 양쪽 |
| 42 | C12b-11 | 시간 임시값(R-3) | 양쪽 |
| 43 | C12b-11 | 가상 스레드 메모 | 제공자 |
| 44 | C12b-11 | 읽을 때 정리(R-9) | 양쪽 |
| 45 | C12b-3a | F-3 그대로, 같은 `calcRunId` PENDING 재사용(R-4) | 양쪽 |
| 46 | C12b-3a | F-3 오류별 프론트 동작 | 소비자 |
| 47 | C12b-4 | `ANSWER_PENDING`은 질문 대기만(R-4) | 양쪽 |
| 48 | C12b-12 | 목 응답 배열 형식 | 소비자 |
| 49 | C12b-12 | 목과 REST Docs 같은 예시 값 | 제공자 |
| 50 | C12b-6 | `display` 포함·그래프 제외(R-6) | 양쪽 |
| 51 | C12b-9 | `OUT_OF_RANGE` + `unit: CHAR`(R-7) | 양쪽 |
| 52 | C12b-7 | `expectedRevision` 출처 하나, F-4에 `planRevision` 없음(R-8) | 양쪽 |
| 53 | C12b-13 | 담당 Issue, `PlanApplyService` `path` 제한·검증 결과 record | 양쪽, 제공자 |
| 54 | C12b-14 | `condition_changes` camelCase 저장(#41), #44 기준 정정 | 양쪽 |
| 55 | C12b-14 | `ConditionChanges` 4키(#21) 선행, 보고값=보낸 값 테스트(#23) | 소비자, 제공자 |
| 56 | C12b-15 | 코드 차이 X-1~X-14 | 제공자 |
| 57 | C12b-9 | 500 전역 `INTERNAL_ERROR`, `/internal/calc`만 컨트롤러 `@ExceptionHandler`에서 `CALC_FAILED`(코드 차이 X-15, #17·#32) | 제공자 |
| 58 | C12b-6 | F-4 재계산은 범위 검사 없이 타입 변환만, 실패 500. F-4는 422 없음, 범위 최종 거절은 F-5 | 제공자 |
| 59 | C12b-6 | F-4 500 카드: 버튼 없음·자동 재시도 없음 | 소비자 |
| 60 | C12b-3a·12 | F-3 202 `assistantMessageId` 제거, `seq-reuse` 목 삭제 | 소비자(양보 가능 항목) |
| 61 | C12b-12 | 목 `get-messages.200-restore-pending.json` 추가 | 소비자 |
| 62 | C12b-5 | 복원 안전장치 "1회"의 범위 정의 | 소비자 |
| 63 | C12b-2 | 같은 사이트 배포 전제(Vite 프록시), #13 | 소비자 |
| 64 | C12b-12 | 목 선택 방식(메서드+경로 키, `useMock`, 배열·status 반영), F-4 messageId 분리(#13) | 소비자 |
| 65 | C12b-3a | F-3 호출 지점은 #54 한 곳, #51·#53은 재조회까지 | 소비자 |
| 66 | C12b-7-4 | (쟁점 X-2 A일 때) 구현은 #53의 `revision` 구독 한 곳, 최초 로드 제외 | 소비자 |
| 67 | C12b-7-4 | (쟁점 X-1 B일 때) #33 구현 메모: plan 먼저 읽어 `NOTHING_TO_UNDO`/`PLAN_CHANGED` 구분, `source` 주석 | 제공자 |
| 68 | C12b-2 | `@SkipRenewal` 구현 메모(#34) | 제공자 |
| 69 | C12b-6·18 | #18에 조건 4개 라벨 키 | 소비자 |
| 70 | C12b-18 | `ChatComparisonQuery`·버전 지정 refdata는 #78 | 제공자(소비자 확인안과 다르나 같은 문제 제기, A팀 영역) |
| 71 | C12b-18 | #44 선행에 #21·#78·#19 | 양쪽 |
| 72 | C12b-13·18 | 입력 저장 응답 `revision`은 #30, #19는 서비스 반환·`currentVersionId`, X-10 후속에 #19 | 제공자 |
| 73 | C12b-8·18 | 이벤트 record·`auth/package-info`는 #16·#34, #46 paths에서 `auth/` 제거 | 양쪽 |
| 74 | C12b-10·18 | chat `package-info`·`backend/CLAUDE.md`는 #41, #41의 202 `status=PENDING` 기준 정정 | 소비자, 제공자 |
| 75 | C12b-18 | #55 paths·선행 정정, 소유 팀 확인 | 소비자 |

## 쟁점 (사람이 정함)

> 둘 다 **#12-b 계약 문서 머지를 막지 않는다.** 본문은 기획 추천안(쟁점 X-1 B, 쟁점 X-2 A)을 임시로 적었다. 재검토에서 **양쪽과 기획이 같은 안으로 모였지만**, 쟁점 X-1은 `db/erd.md` Q4-c(되돌리기 방식)를 바꾸고 쟁점 X-2는 D-041의 범위를 넓히는 새 정책이라 사람이 정한다. open-questions: **Q-056(쟁점 X-1), Q-057(쟁점 X-2)**. 선택지·영향·추천은 `frontend-api-chat-proposal.md`.

### 쟁점 X-1. 되돌리기 뒤 "되돌리기 전 비교"의 비활성을 누가 보장하나 (R-2, D-041) — Q-056

- A. 프론트만(포인터 교체 유지 + `planChangeBarrierId`) / **B. 되돌리기 = 직전 버전 복사 INSERT(추천)** / C. 계획 마지막 변경 시각 비교.
- 제공자 B(A 수용 가능, C 반대), 소비자 B(v1의 A+C 철회), 기획 B.
- 결정에 따라 바뀌는 줄: C12b-6 `applicable` 아래 문장, C12b-7-4 "서버" 문단과 마지막 문단, C12b-13 요구 5, 코드 차이 X-14, H-7·H-11b.

### 쟁점 X-2. D-041의 "되돌리기 뒤 비활성"을 "내 계획이 바뀐 모든 순간"으로 넓히나 — Q-057

- **A. 넓힘(추천)** / B. D-041 문장대로(되돌리기·대화 적용 직후만).
- 제공자 A(서버 영향 없음), 소비자 A(구현은 `revision` 구독), 기획 A.
- 결정에 따라 바뀌는 줄: C12b-6 "버튼 활성 한 줄"의 셋째 조건, C12b-7-4 "프론트" 문단, H-11b.

---

## 부록 C. v2 → v3에서 바뀐 것

| 항목 | v2 | v3 | 출처 |
|---|---|---|---|
| C12b-2 | `SameSite=Lax`만, 폴링 실패 = 네트워크·5xx | 같은 사이트 배포 전제(#13), 폴링 실패 = 401 외 모든 실패, `@SkipRenewal` 구현 메모 | 소비자, 제공자 |
| C12b-5 | 복원 안전장치 "같은 폴링 주기 동안 1회" | "폴링이 멈추거나 F-1·F-3을 보낼 때까지 1회"로 정의, `answerPending` 인덱스 메모 | 소비자, 제공자 |
| C12b-6 | `changedKeys` = C2-2 표 순서, 재계산 검증 미기재, `ChatComparisonQuery` 위치 "#32, #78과 공유(먼저 하는 쪽)" | 순서 보장 없음(집합), 재계산은 범위 검사 없이 타입 변환만(실패 500, F-4 422 없음), 위치 #78, 500 카드 버튼·재시도 없음, 조건 라벨 키 | 제공자, 소비자 |
| C12b-7 | 응답 `{planVersionId, revision}` | `{revision}` | 소비자(양보 가능 항목, 제공자 이견 없음) |
| C12b-7-1 | X-10 대상 `persistence.md`·`moved-to-code.md` | + #19 수용 기준. `/internal/calc` 컨트롤러 한정 처리에 500 `CALC_FAILED` 추가 | 제공자 |
| C12b-7-3 | 4번 "새 `calcRunId`로 F-3" | F-3은 #54 한 곳(결과 `calcRunId` 변화), revision 갱신이 버튼 비활성을 일으킴 | 소비자 |
| C12b-7-4 | 프론트가 네 지점에서 함수 호출 | #53이 `revision` 구독(최초 로드 제외). X-1 B 구현 메모 (a)·(b), B가 막는 경우 명시 | 소비자, 제공자 |
| C12b-8 | 이벤트 record·`auth/package-info`가 #46 paths | #16(`MemberLoggedIn`, package-info)·#34(`MemberLoggedOut`) | 양쪽 |
| C12b-9 | 500 `INTERNAL_ERROR`만 | 전역 `INTERNAL_ERROR` + `/internal/calc` 한정 `CALC_FAILED`(X-15) | 제공자 |
| C12b-10-2 | 의존 변경 시점 #45 | #41 | 소비자 |
| C12b-3a | 202 `{assistantMessageId}`, 호출 지점 여러 곳 | 202 `{}`, 호출 지점 #54 하나, 404 재시도도 같은 지점 | 소비자 |
| C12b-12 | 시나리오 선택은 래퍼 재량, 35개(`seq-reuse` 포함) | 선택 방식 계약(#13), F-4 messageId 분리, `restore-pending` 추가·`seq-reuse` 삭제, 35개 | 소비자 |
| C12b-13 | 요구 4 입력 저장 #19, 요구 6 #32, 요구 8 수신 #46 | 요구 4 #30, 요구 6 #78, 요구 8 record도 #16·#34, 요구 9 X-15, 요구 10 F-3은 #54만 | 제공자, 소비자 |
| C12b-15 | X-1~X-14 | X-1·X-2·X-10·X-12·X-14 대상 보강, X-15 추가 | 제공자, 소비자 |
| C12b-18 | H-1~H-15 | H-6b·H-8b·H-10b·H-16 추가, H-3·H-4·H-5·H-6·H-7·H-7b·H-7c·H-8·H-9·H-10·H-11~H-11e·H-15 수정 | 양쪽 |
| 쟁점 | X-1(제공자 B vs 소비자 A+C), X-2(소비자 A, 제공자 의견 없음) | 둘 다 양쪽·기획 일치(X-1 B, X-2 A). 결정 변경·새 정책이라 Q-056·Q-057로 사람에게 | 양쪽 |
