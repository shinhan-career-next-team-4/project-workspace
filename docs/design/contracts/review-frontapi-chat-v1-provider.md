# 프론트 ↔ Spring 대화 API 계약 v1 (#12-b) — 제공자(Spring: plan·auth·calc 공개 서비스 + chat 모듈 구현 가능성) 검토

> 검토자: contract-provider, 2026-11-16. `/negotiate-contract` 2단계 독립 검토. 대상 `frontend-api-chat-v1.md`(moeun #12 중 #12-b).
> 근거로 읽은 것(moeun origin/develop `9a31166`, 읽기만 함): `backend/CLAUDE.md` 모듈 표, `backend/.claude/rules/modulith.md`·`persistence.md`, 모든 `package-info.java`(auth·plan·calc·chat·rag·refdata), `config/SecurityConfig.java`, `ModularityTests.java`, `refdata/ReferenceDataService.java`, `calc/CalcInput.java`, `resources/db/schema.sql`(plan_version·plan·calc_run·chat_message), `db/erd.md` §4 Q1·Q2·Q4·§5-G, `db/decision.md` ADR-002, `db/moved-to-code.md` §1, `ai-server/app/schemas.py`(`ConditionChanges`, `ChatResponse`), 최종 계약 `internal-calc.md`(C2-2·C2-3·C2-7·C2-8·C3-1~C3-5), `plan-context.md`(C1a-10·후속 작업), `decisions.md`(D-013·D-016·D-022·D-030·D-033·D-040·D-041·D-046·D-051·D-052·D-057·D-058·D-062), moeun 열린 Issue 목록과 #16·#33·#34·#44·#45·#46 본문(`gh api`로 조회).
> 지금 코드 상태: `plan`·`auth`·`chat` 모듈은 `package-info.java`만 있다. `ChangePath`·`ConditionValidator`·`TokenRenewalFilter`·`@SkipRenewal`은 **이름만 정해진 상태**(`moved-to-code.md`)이고 코드는 없다. 초안이 "이미 있음"이라고 쓴 곳 중 이 넷은 "이름이 정해짐"으로 읽어야 한다.

```
판정: 수정하면 수용
```

큰 방향 — 적용 API를 chat 컨트롤러에 두고 chat → plan 의존을 더하는 안 A(C12b-10), 값이 아니라 `chatMessageId`로 적용(D-033), plan 공개 서비스는 chat·calc 타입을 모르는 것, F-4를 `calc_run(CHAT)` 버전으로 다시 계산(ADR-002) — 는 그대로 받는다. 다만 그대로 만들면 **(1) `@SkipRenewal`과 auth → chat이 합쳐져 순환 의존이 생겨 `ModularityTests`가 실패하고**, (2) `condition_changes` 키 표기를 정하지 않으면 F-5가 항상 `FIELD_NOT_CHANGEABLE`이 되며, (3) 대화 삭제 방식이 이미 열린 #46 본문(이벤트)과 반대다. 아래 수정이 들어가면 수용한다.

## 항목별 의견

- **[C12b-1 범위·엔드포인트] 수용** — F-5를 chat 경로(`/api/chat/messages/{id}/apply`)에 두는 것은 #33 본문("chatMessageId로 적용하는 컨트롤러는 … chat 모듈(T-037)이 이 서비스를 호출")·#45 본문과 같다. 대화 삭제용 프론트 엔드포인트를 두지 않는 것도 찬성(D-051은 로그인·로그아웃 시점만 정함).

- **[C12b-2 인증·공통] 수정** — 두 가지.
  1. **`@SkipRenewal` 위치가 순환을 만든다(아래 C12b-10에서 자세히).** F-2 컨트롤러는 chat에 있고, `@SkipRenewal`은 auth 루트 타입으로 정해져 있다(`auth/package-info.java:3`, `moved-to-code.md` §1). chat 컨트롤러에 이 어노테이션을 붙이면 chat → auth 의존이다(Modulith 검사는 ArchUnit 기반이라 어노테이션 참조도 의존으로 잡는다. 착수 시 `ModularityTests`로 확인). 초안 C12b-8의 auth → chat과 합쳐지면 순환이다.
  2. **`SameSite`를 #12-a 재량으로 두지 말고 `Lax` 이상을 이 계약의 전제로 적는다.** 지금 `SecurityConfig`는 CSRF를 끈다(`SecurityConfig.java:16`). 쿠키 JWT + CSRF 끔이면 교차 사이트 POST를 막는 것은 `SameSite`뿐이고, F-5는 계획을 바꾸는 POST, F-1은 LLM 비용이 드는 POST다. 수정안: C12b-2 표 "인증" 칸에 "`SameSite=Lax` 이상(필수, CSRF 토큰을 쓰지 않으므로)"을 넣고 #16 수용 기준과 맞춘다(#16은 이미 "SameSite 쿠키"를 적음).
  - 덧붙임: chat 컨트롤러는 `memberId`를 `@AuthenticationPrincipal Jwt`(또는 `Authentication.getName()`) 같은 **Spring Security 타입으로만** 얻는다. auth가 `@CurrentMember` 같은 리졸버를 만들어 chat이 쓰면 그것도 chat → auth다. C12b-10-2 "지켜야 할 것"에 한 줄.

- **[C12b-3 메시지 모양] 수정(구현 메모 2개)** —
  - PENDING 자리표시 `message_type`을 **`ANSWER`로 계약에 고정**한다. 왜: C12b-4 2번 "질문 답변 대기만 `ANSWER_PENDING`"을 Spring은 `status='PENDING' AND message_type='ANSWER'`로 판정한다(F-3 대기는 `EXPLANATION`이라 자연히 빠짐). 자리표시 값이 구현자마다 다르면 이 판정이 깨진다. `ck_cm_role_type`(ASSISTANT ≠ QUESTION)과 `ck_cm_recalc`(완료 시 리스너가 `calc_run_id`·`condition_changes`·`baseline_scenario`를 함께 채움)에도 문제없다(`schema.sql`의 chat_message).
  - `id`는 "회원별 단조 증가"가 맞지만 **커밋 순서와 같지는 않다**(BIGSERIAL은 할당 순서). 같은 회원의 F-1과 F-3이 몇 ms 안에 겹치면 작은 id가 늦게 커밋되어 `id > afterId` 폴링이 그 행을 영영 못 볼 수 있다. 데모에서 드물고 고치려면 잠금이 필요하므로 수용하되, 싼 안전장치를 프론트 규칙에 하나 더한다: **`hasPending=true`인데 프론트가 가진 PENDING이 없으면 `afterId` 없이 복원 1회.** 서버 변경 없음.

- **[C12b-4 F-1] 수용 + 수정 1** — 서버 동작(정리 → 대기 검사 → 두 행 저장 → `ChatAnswerRequested`)은 `modulith.md` 이벤트 표와 같고 #41 범위다.
  - 수정: "앞뒤 공백을 지운 길이"로 검사하면 **저장·전송도 지운 문자열**로 한다고 적는다. 공백 포함 원문을 ai-server에 보내면 Spring 통과·ai-server `max_length=2000` 422 → `FAILED`가 날 수 있다. (Java `String.length()`는 UTF-16 단위라 Python 글자 수 이상이므로 trim만 맞추면 Spring 쪽이 항상 더 엄격하다.)
  - 양보 가능: "`text`가 문자열이 아님 → 400"은 Jackson 기본 스칼라 강제 변환(`{"text":123}` → `"123"`) 때문에 그냥 받아질 수 있다. `/internal/calc`처럼 `JsonNode`로 받아 막을 수 있지만 F-1에서는 가치가 낮다. 이 줄을 "JSON 파싱 실패, 본문이 객체가 아님"으로 줄이기를 권한다.

- **[C12b-5 F-2] 수용** — `afterId` 하나 + `hasPending`은 `ix_chat_message_member(member_id, id)` 범위 조회 1번 + `ix_chat_message_pending` 1번으로 끝나 Q2-b(`pending_ids`)보다 단순하다. 복원 50개·id 오름차순도 수용(키셋 `DESC LIMIT 50` 뒤 뒤집기). 출처는 Q2-c 일괄 조회 1번.
  - GET이 오래된 PENDING을 UPDATE하므로(C12b-11-3) F-2 서비스는 읽기 전용 트랜잭션이 아니다. 구현 메모로 적는다.

- **[C12b-6 F-4] 수정** — 재계산 방식·`applicable` 조건·404 일원화 모두 수용. 수정은 **calc 쪽 공개 API의 모양**이다.
  - F-4는 chat이 계산할 수 없으므로 calc 루트에 공개 서비스가 하나 필요하다(초안 요구 6). 제안 시그니처(세부는 제공자 재량):
    ```java
    // calc 루트. 소유권은 findPlanRun과 같은 2단계(calc_run 조회 → plan.findVersion(memberId, ...)).
    public interface ChatComparisonQuery {
        /** CHAT 기록의 기준 버전만. 없음·남의 것·PLAN 기록이면 empty. F-5 검사 4용(재계산 없음). */
        Optional<Long> findChatRunPlanVersion(long memberId, long calcRunId);
        /** CHAT 기록의 데이터 버전·engine_version + 그 기록의 plan_version + changes로 다시 계산. */
        Optional<ChatComparisonView> recompute(long memberId, long calcRunId, Map<String, JsonNode> conditionChanges);
    }
    public record ChatComparisonView(long basePlanVersionId, CalcComparison comparison, Map<String, String> display) {}
    ```
    `display`는 `ResultDisplayBuilder`(calc.application, #28)를 calc 안에서 불러 **루트 공개 타입의 `Map<String,String>`로** 내보낸다(planContext `PlanContextView.display`와 같은 방식). internal-calc C2-3 구현 메모의 "display는 `calc.web`에서만"은 `/internal/calc` 응답 DTO 이야기이며, chat이 `calc.web` 타입을 쓰면 `modulith.md:12`(하위 패키지 비공개) 위반이다.
  - **"당시 기준" 재계산에는 버전 지정 기준 데이터 조회가 필요하다.** 지금 `ReferenceDataService`는 활성 버전만 꺼낸다(`findActiveSavingsAvgRate` 등 3개). `findById(versionId)` 류 3개가 필요하며, 이것은 #78(`PlanContextProvider.findForCalcRun`)이 이미 같은 이유로 필요로 하므로 **#78과 공유**하고 F-4가 따로 만들지 않는다. #44 수용 기준(예외) "그 행의 같은 데이터 버전·엔진 버전으로 계산"은 이 전제 위에서만 지킬 수 있다.
  - `applicable` 판정에 chat → plan(현재 `current_version_id`)이 필요한 것 수용. plan 공개 현재 계획 조회(#19, G-12)에 `currentVersionId`를 넣는 비용은 필드 1개.
  - `applicable`이 되돌리기 뒤에도 정확하려면 R-2의 새 버전 방식이 필요하다(아래 R-2).

- **[C12b-7 F-5 응답] 수정(양보 가능)** — `undoAvailable`은 항상 `true`라 정보가 없고 `previousVersionId`·`planVersionId`는 프론트가 쓰는 곳이 없다(되돌리기는 `revision`만으로 한다, ERD Q4-c). 응답을 `{ "revision": 13 }` + `planVersionId` 정도로 줄이기를 권한다. 다만 #33 수용 기준이 "undoAvailable=true"를 적고 있으므로, 남긴다면 #33과 같은 응답 record를 그대로 직렬화하는 조건으로 수용(추가 비용 없음).

- **[C12b-7-1 F-5 검사 순서] 수용 + 수정 3** —
  - 순서 자체(chat: 404 → 최신 여부 → 기준 버전 / plan: NO_PLAN → 재검증 → PLAN_CHANGED → STALE → 쓰기)는 한 트랜잭션 안에서 자연스럽게 구현된다. 검사 9(기준 버전)를 잠금 없이 읽어도 안전한 이유를 계약에 적는다: **검사 10의 `UPDATE … WHERE revision = :expected`가 성공했다면 그 사이 `current_version_id`도 바뀌지 않았다**(포인터가 바뀌는 모든 경로가 revision을 올림). 그래서 `SELECT … FOR UPDATE` 불필요.
  - 수정 1: 10번에서 `UPDATE`가 0행이면 **런타임 예외로 트랜잭션을 롤백**해 앞에서 INSERT한 `plan_version`을 남기지 않는다고 적는다(`plan_version`은 INSERT 전용이라 고아 행이 남으면 지울 경로가 없다, `persistence.md:14`).
  - 수정 2: `persistence.md:14`·`moved-to-code.md`(멱등 키 행)는 "0행이면 현재 상태를 돌려준다"인데 이 계약·#33은 `409 PLAN_CHANGED` + 프론트 재조회다. 계약 쪽이 맞다(본문에 상태를 싣지 않는 쪽이 단순). C12b-15에 X-10으로 올리고 `persistence.md` 한 줄을 #33에서 고친다.
  - 수정 3: 6·7 재검증의 입력 키는 **camelCase만** 받는다(아래 C12b-14). chat이 snake_case를 그대로 넘기면 4개 키 모두 허용 밖이라 **모든 대화 적용이 `422 FIELD_NOT_CHANGEABLE`**이 된다.
  - 검사 6·7의 422는 plan의 `ConditionViolationException`이 전역 advice로 바로 나가야 한다. calc.web이 `/internal/calc`용으로 `minDisplay`를 붙이는 처리(internal-calc C3-1)는 **`/internal/calc` 컨트롤러 안의 `@ExceptionHandler`(또는 그 패키지 한정 advice)** 로 두어 F-5 422에 섞이지 않게 한다. #32 구현 메모 한 줄.

- **[C12b-7-2·7-3 프론트 동작] 수용** — 제공자 영향 없음. 7-3의 4번(결과 재조회 → `calcRunId`로 F-3)은 #30·#31 응답에 `calcRunId`가 있어야 성립(요구 4, 수용). `PlanChanged(APPLY)` 리스너가 늦어도 Q1-c가 기록하므로 `calcRunId`는 항상 나온다(동시에 PLAN 행 2개는 무해, C1a-10).

- **[C12b-7-4 되돌리기 뒤 비활성(프론트 `undoBarrierId`)] 수정 → R-2 참고** — 제공자는 되돌리기를 **새 버전 INSERT**로 하자고 제안한다. 그러면 이 절의 프론트 규칙과 "새로 고침 틈"이 통째로 없어진다.

- **[C12b-8 대화 기록 삭제] 수정(핵심 2)** — 동기 삭제(로그인 응답 전에 끝남)라는 목표는 찬성. **방향과 장치를 바꾼다.**
  - 문제 1(순환): 초안은 auth → chat(직접 호출). 그런데 F-2에 `@SkipRenewal`(auth 타입)을 붙이면 chat → auth가 생겨 **auth ⇄ chat 순환** → `ModularityTests` 실패(`modulith.md:17`). 둘 중 하나는 버려야 한다.
  - 문제 2(이미 열린 Issue와 반대): #46 본문은 "auth가 이벤트(LoggedIn, LoggedOut)를 발행하고 chat이 받아 삭제", 완료 조건 "auth가 chat을 의존하지 않고 이벤트로 푼다", paths `auth/LoggedIn.java`다. 초안을 그대로 쓰면 #46·#16·#34를 모두 다시 써야 한다.
  - **수정안(제공자 권장, R-5 대안의 변형): 방향은 #46대로 chat → auth(이벤트), 수신은 동기.**
    - auth 루트에 `auth.MemberLoggedIn {memberId}`, `auth.MemberLoggedOut {memberId}` record. 로그인·로그아웃 서비스가 **쿠키를 내리기 전에** `ApplicationEventPublisher`로 발행.
    - chat은 `@ApplicationModuleListener`(커밋 뒤·비동기)가 아니라 **동기 `@EventListener`** 로 받아 `DELETE FROM chat_message WHERE member_id = ?`를 자체 `@Transactional`로 실행. 발행한 스레드 안에서 끝나므로 초안이 걱정한 "로그인 직후 F-2 복원이 삭제보다 먼저 도는" 경쟁이 없다. 삭제가 실패하면 예외가 로그인으로 올라가 로그인도 실패한다(D-030 쪽이 안전).
    - 의존: chat `{calc, rag, plan, auth}`, auth `{}` 그대로. 그러면 F-2의 `@SkipRenewal`도 chat → auth라 같은 방향이다. 순환 없음.
    - 대가: `modulith.md:24`("수신은 `@ApplicationModuleListener`")에 예외 한 줄("응답 전에 끝나야 하는 수신은 동기 `@EventListener`"), `auth/package-info.java:4`의 "이 모듈을 직접 의존하지 않는다"를 "auth 루트의 이벤트·`@SkipRenewal`만 쓴다"로 고침. 동기 리스너는 `event_publication`에 기록되지 않지만 재시도가 필요 없다(실패하면 로그인이 실패하고 사용자가 다시 로그인).
  - 초안(auth → chat 직접 호출)을 유지하려면 **`@SkipRenewal`을 쓰지 말고 `TokenRenewalFilter`가 경로로 제외**(`GET /api/chat/messages`를 auth 설정 목록에)해야 한다. 이 경우 #34 수용 기준("@SkipRenewal이 붙은 폴링 요청")·`moved-to-code.md`·D-052 표현과 다르고 #46을 다시 써야 해 고칠 곳이 더 많다. 제공자는 위 수정안을 권한다.
  - 구현 메모(어느 쪽이든): 삭제는 **JPQL/네이티브 한 문장 일괄 DELETE**(`@Modifying`). 엔티티를 하나씩 지우면 `retry_of_message_id`(NO ACTION, 자기 참조)가 문장마다 검사되어 순서에 따라 실패한다. 초안의 "문장 끝 검사" 설명은 한 문장일 때만 맞다. `chat_message_citation`은 DB `ON DELETE CASCADE`라 일괄 DELETE로도 지워진다.
  - 구현 메모: 리스너(#41)는 **완료 갱신이 0행이면 citation INSERT를 하지 않는다.** 순서를 "UPDATE … `AND status='PENDING'` → 1행일 때만 citation 저장"으로 고정하지 않으면, 삭제된 메시지에 citation을 넣다가 FK 위반 → 예외 → `event_publication` 미완료로 재기동 때마다 다시 돈다.
  - 로그아웃은 유효한 토큰이 있어야 회원을 안다. 만료된 토큰으로 로그아웃하면 401이고 삭제는 다음 로그인 때 된다(NFR-INT-03 예외 수용 기준과 같음). #34에 한 줄.

- **[C12b-9 오류 공통] 수용 + 수정 2** — 코드·HTTP 매핑은 C3-1·C3-5와 맞고 ProblemDetail로 그대로 낼 수 있다.
  - 수정 1: Spring 기본 예외 매핑을 표에 명시한다 — `MethodArgumentTypeMismatchException`(경로 `messageId`·쿼리 `afterId`가 정수 아님) → `400 MALFORMED_REQUEST`, `NoResourceFoundException`(없는 경로) → `404 NOT_FOUND`, `HttpRequestMethodNotSupportedException`·`HttpMediaTypeNotSupportedException` → 각각 405·415 + `code`(`METHOD_NOT_ALLOWED`·`UNSUPPORTED_MEDIA_TYPE`, 프론트는 쓰지 않음). 안 적으면 `code` 없는 Spring 기본 ProblemDetail이 나가 "모든 오류에 `code`" 원칙이 깨진다. #17 수용 기준 1줄.
  - 수정 2(구현 경계): 전역 `@RestControllerAdvice`는 `config`에 있다(C3-1). 새 코드 예외(`ANSWER_PENDING`·`STALE_COMPARISON`은 chat, `PLAN_CHANGED`·`NO_PLAN`·`STALE`(plan 쪽 9번)은 plan)를 advice가 타입별로 import하면 config → chat·plan 의존이 늘어난다. 순환은 아니지만(어느 모듈도 config에 의존하지 않는 한) **모듈 예외가 `config`의 공통 부모 클래스를 상속하면 즉시 순환**이다. 제공자 권장: 모듈 예외는 Spring의 `ErrorResponseException`을 상속하고 `ProblemDetail`에 `code`·`errors` 속성을 직접 담는다. advice는 `ErrorResponse`를 일반 처리만 하므로 새 코드가 늘어도 config를 고치지 않는다. "공용 `common` 모듈을 만들지 않는다"(C3-1)와도 맞다. 계약 문장으로는 "모듈 예외는 `config`의 타입을 상속하지 않는다" 한 줄만 있으면 된다.

- **[C12b-10 모듈 의존 방향] 수용(안 A) + 수정** — 안 A 찬성. B·D가 순환인 분석도 맞다(chat → calc → plan이 이미 있으므로 plan → chat이면 순환).
  - 수정: C12b-10-2 표와 그래프를 아래로 바꾼다.

    | 모듈 | 지금 | 이 계약 뒤(제공자안) |
    |---|---|---|
    | `plan` | `{}` | `{}` |
    | `calc` | `{plan, refdata}` | 변경 없음 |
    | `chat` | `{calc, rag}` | **`{calc, rag, plan, auth}`** |
    | `auth` | `{}` | **`{}`(변경 없음)** |
    | `config`(표 밖, 제한 없음) | — | 어느 모듈도 `config`에 의존하지 않는다 |

    ```
    chat ──▶ calc ──▶ plan
      │        └────▶ refdata
      ├──────▶ plan
      ├──────▶ rag
      └──────▶ auth   (MemberLoggedIn/LoggedOut 수신, @SkipRenewal)
    config ──▶ (auth, plan, calc, chat: 보안 필터 등록·예외 처리. 역방향 없음)
    ```
  - "지켜야 할 것"에 더한다: (a) **calc → chat, plan → (chat·calc), auth → (어느 모듈이든)** 이 생기지 않는다. (b) chat은 auth 루트의 이벤트·`@SkipRenewal`만 쓰고 memberId는 Spring Security 타입에서 얻는다. (c) 모듈은 `config` 타입을 쓰지 않는다.
  - `PlanApplyService`가 `Map<String, JsonNode>`를 받는 것 수용(internal-calc C2-2 "받는 방식"과 같은 검증 입력). Boot 4는 Jackson 3(`tools.jackson.databind.JsonNode`)이므로 #17의 `ConditionValidator` 시그니처와 같은 패키지를 쓴다. `ChangePath`(plan 루트 enum)를 chat이 import하는 것은 chat → plan이라 문제없다.

- **[C12b-11 시간 값·PENDING] 수용 + 메모** — 연결 2초·응답 30초·정리 60초 관계(정리 > 응답 타임아웃 + 여유) 수용. 설정 키는 chat의 `@ConfigurationProperties` 하나.
  - 메모: 리스너는 Boot 기본 `applicationTaskExecutor`에서 돌며 ai-server 호출 동안 스레드를 최대 30초 잡는다. 기본 풀(코어 8)에서 동시 질문이 몰리면 큐에서 기다리다 60초 정리로 `FAILED`가 될 수 있다(그 뒤 리스너는 PENDING이 아니라 건너뜀 — 결과는 일관됨). Java 21이므로 `spring.threads.virtual.enabled=true` 한 줄이면 해결된다. #41 메모.
  - 11-2의 "시작할 때 PENDING이 아니면 미호출"과 "갱신에 `AND status='PENDING'`" 수용(멱등, `modulith.md:25`).

- **[C12b-3a F-3] 수용** — `findPlanRun` 한 경로 404(C1a-10)는 #78이 만들고 #43이 쓴다. 같은 `calcRunId` PENDING 재사용 조회는 `ix_chat_message_run`(부분 인덱스)로 싸다. 동시 두 요청이 둘 다 못 찾아 2행이 생기는 경우는 무해하므로 잠금 없이 수용.

- **[C12b-12 목 JSON] 수용** — 제공자 영향 없음. 실제 응답과 목이 어긋나지 않게, #45·#42 Spring 테스트(REST Docs)의 응답 스니펫을 나중에 목과 비교할 수 있도록 같은 예시 값(id 1030/1031 등)을 쓰기를 권한다(양보 가능).

- **[C12b-13 #12-a에 요구하는 것 10개] 수정(담당 Issue 정정) — 비용은 감당 가능**

  | # | 요구 | 실제 담당 | 추가 비용(제공자 추정) | 의견 |
  |---|---|---|---|---|
  | 1 | `PlanApplyService` + 기준 버전 검사 + 예외 | **#33**(이미 `PlanApplyService` 이름으로 범위에 있음) | +0.5일(기준 버전 인자·예외 1개·테스트). 0행 롤백 포함 | 수용 |
  | 2 | 401 `AuthenticationEntryPoint` C3-1 형식 | **#16**(수용 기준에 이미 "401 UNAUTHENTICATED") | 0 | 수용 |
  | 3 | F-2 갱신 제외 | **#34** | 0. 단 `@SkipRenewal`을 chat이 쓰려면 C12b-8 수정안(chat → auth 방향)이 전제 | 수정 |
  | 4 | 현재 계획·결과 응답에 `revision`·`calcRunId`·`result.status` | **#31**(현재 계획 조회), **#30**(결과 보기). #29는 서비스 | 필드 3개, 0.25일 | 수용 |
  | 5 | 되돌리기 응답 `revision` + 방식 결정 | **#33** | 새 버전 방식이면 +INSERT 1문장·테스트 1건(0.25일) | R-2 |
  | 6 | calc 공개 API(기준 버전 조회, 재계산 + display) | **#32**(`CalcComparison` 소유) paths에 calc 루트 새 파일 추가. 버전 지정 기준 데이터 조회는 **#78과 공유** | 약 1일(가장 큼). #78이 버전 지정 조회를 먼저 만들면 0.5일 | 수정(C12b-6 시그니처) |
  | 7 | plan 현재 계획 조회에 `currentVersionId` | **#19**(G-12와 같은 API) | 필드 1개 | 수용 |
  | 8 | 로그인·로그아웃 때 대화 삭제 | auth 쪽 **#16**(로그인)·**#34**(로그아웃)는 이벤트 발행 1줄씩, chat 쪽 **#46** | 0.25일 | **수정**(C12b-8 방향) |
  | 9 | 전역 advice가 새 코드를 냄 | **#17** | 코드당 몇 줄. `ErrorResponseException` 방식이면 0에 가까움 | 수용 |
  | 10 | 결과 화면 공통 함수(F-3·D-062) | 프론트 **#51**(A, 되돌리기 토스트)·**#54**(B) + #49 교차참조 | 제공자(Spring) 영향 없음 | 수용 |

  합계 A팀 Spring 추가분은 약 2일이며 대부분 이미 열린 Issue(#33·#32·#19·#30·#31) 안의 몇 줄이다. 3주·백엔드 1명 기준에서 감당 가능하다. 가장 비싼 6번도 #78의 버전 지정 조회와 겹치므로 따로 만들지 않으면 된다. **#32 선행에 #78을 넣지 말고**(순서가 뒤집힘) 버전 지정 조회를 refdata(#14)·#29 쪽 공용으로 두는 편이 안전하다 — 어느 Issue에 둘지는 A팀 재량.

  요구 1 시그니처는 수용하되 두 줄 고친다: `path`는 `ALTERNATIVE`·`COMPARE`·`CHAT`만 허용(`INPUT_EDIT`면 `IllegalArgumentException`), 검증 결과를 다시 파싱하지 않게 `ConditionValidator`가 **타입 있는 값 record**를 돌려주게(#17 재량). 예외는 plan 루트에 두고 `config` 타입을 상속하지 않는다.

- **[C12b-14 ai-server 영향 / 키 표기] 수정(제공자 양보 불가)** — "변환 위치는 #44에서 정한다"로 열어 두면 안 된다. `ai-server` `ConditionChanges.changed()`는 snake_case 키를 낸다(`schemas.py:43-45`)고 `ChatResponse.condition_changes`가 그대로 온다. F-4(#44)·F-5(#45)는 둘 다 이 값을 calc·plan 검증(camelCase만, internal-calc C2-2)에 넘긴다.
  - 수정안: **chat 리스너(#41)가 `chat_message.condition_changes`에 저장할 때 camelCase로 바꿔 저장**하고, 그 뒤 모든 읽기(F-2 응답, F-4 재계산, F-5 적용)는 변환 없이 쓴다. 변환은 4키 고정 맵 하나. 허용 4키 밖의 키는 그대로 저장해 F-5에서 `FIELD_NOT_CHANGEABLE`로 걸리게 둔다(조용히 버리지 않음).
  - 이에 따라 #44 수용 기준 "snake_case로 저장된 RECALC_RESULT → camelCase로 바꿔 넘긴다"는 "저장은 camelCase(#41)"로 바꾼다. 아직 운영 데이터가 없으므로 이전 형식 호환은 필요 없다.
  - 참고(소비자 쪽 위험, 제공자는 막을 수 없음): Spring은 ai-server가 보고한 `conditionChanges`가 실제 `/internal/calc`에 보낸 값과 같은지 검증하지 못한다(`calc_run`에 변경값을 저장하지 않음, ADR-002). 다르면 F-4 카드는 저장된 값 기준이라 AI 문장과 어긋난다. 카드와 적용은 서로 일치하므로 데이터는 안전하다. ai-server 테스트(#23)에서 같음을 고정하기를 권한다.

- **[C12b-15 코드 차이] 수정(행 추가)** —
  - X-2 행을 "auth → chat"에서 "**chat → auth**(이벤트 수신·`@SkipRenewal`), auth `{}` 유지, `auth/package-info.java:4` 문장 수정"으로.
  - 추가 X-10: `persistence.md:14`·`moved-to-code.md`(멱등 키 행) "0행이면 현재 상태를 돌려준다" ↔ `409 PLAN_CHANGED` → #33.
  - 추가 X-11: `modulith.md:24` 수신 규칙 ↔ 대화 삭제 동기 `@EventListener` 예외 → #46.
  - 추가 X-12: #46 본문(비동기 이벤트로 읽힘) ↔ 동기 수신 → #46 본문 수정(D-058).
  - 추가 X-13: #44 수용 기준 "snake_case 저장" ↔ camelCase 저장 → #41·#44.
  - 추가 X-14: (R-2 새 버전 채택 시) `db/erd.md` Q4-c 포인터 교체 ↔ 복사 INSERT → #33.
  - X-9는 "변경 없음"이 아니라 **`auth.MemberLoggedIn`/`MemberLoggedOut` 두 행 추가**(수신: chat, 동기).

- **[C12b-16 열린 질문 영향] 수용** — 제공자 영향 없음. Q-051 C안(`409 ALREADY_EXCEEDED`를 F-1에)은 F-1에서 현재 계획 조회가 하나 늘 뿐이다.

- **[C12b-17 수용 기준 대응표] 수용** — 완료 조건 "ModularityTests를 깨지 않음"은 위 C12b-10 수정이 들어가야 참이다.

- **[C12b-18 후속 작업] 수정(Issue 번호 채움)** — `gh api …/issues?state=open`로 확인.

  | # | 초안 | 제공자 제안 |
  |---|---|---|
  | H-1 | #12 | **#12** (목 래퍼 분기는 #13 프론트 초기 설정과 맞춤) |
  | H-2 | #41 | **#41** + camelCase 저장, 0행이면 citation 미저장, 가상 스레드 메모 |
  | H-3 | 번호 확인 필요 | F-1 부분 → **#41**(제목 "chat 모듈 기반 + F-1 질문 전송"), F-2 부분 → **#42**(제목 "F-2 메시지 폴링 + 출처 조회"). `ANSWER` 자리표시 고정은 #41 |
  | H-4 | #43 | **#43** |
  | H-5 | #44 | **#44**(수용 기준의 snake_case 문장 교체) |
  | H-6 | 번호 확인 필요 | **#45**("대화 '내 계획으로 적용' 엔드포인트"). chat `package-info`에 `plan`·`auth` 추가 + `backend/CLAUDE.md` 모듈 표 — #45 paths 밖이므로 paths에 두 파일 추가 |
  | H-7 | 번호 확인 필요 | **#33**("적용·되돌리기 서비스와 REST"). 기준 버전 검사, 0행 롤백, `persistence.md` X-10, (R-2) 되돌리기 새 버전 |
  | H-8 | 번호 확인 필요 | **#32**(`CalcComparison` 소유) paths에 calc 루트 `ChatComparisonQuery`·`ChatComparisonView` 추가. 버전 지정 기준 데이터 조회는 **#78**과 공유(둘 중 먼저 하는 쪽이 만듦) |
  | H-9 | 번호 확인 필요 | auth: **#16**(로그인 이벤트 발행)·**#34**(로그아웃 이벤트 발행). chat: **#46**(동기 수신·일괄 DELETE). `auth/package-info.java`·`modulith.md` 문장은 #46 paths에 추가 |
  | H-10 | #17, #12-a | **#17**(코드·Spring 기본 예외 매핑), 401은 **#16** |
  | H-11 | #54(+#49) | **#52**(폴링·F-1·`hasPending` 복원 안전장치), **#53**(F-4 카드·F-5·오류별 동작·(R-2 미채택 시) `undoBarrierId`), **#54**(F-3·D-062), A팀 **#51**(되돌리기 토스트 `revision`) |
  | H-12 | 문서 | 문서(그대로) |

## 검토 요청(R-x)에 대한 제공자 의견

- **R-1 적용 API 위치: 안 A 찬성.** 단 C12b-10 수정(의존 표에 chat → auth 포함, auth `{}` 유지)과 함께.

- **R-2 되돌리기 뒤 비활성: 새 버전 INSERT를 권한다(제공자안).**
  - 방법: 되돌리기 = `INSERT INTO plan_version SELECT …(previous 행 복사, source도 복사)` → `UPDATE plan SET previous_version_id = NULL, current_version_id = :new, revision = revision + 1 WHERE member_id = ? AND revision = :expected AND previous_version_id IS NOT NULL`. 한 트랜잭션. `source`는 원래 값을 복사하므로 `ck_pv_source`(INPUT·ALTERNATIVE·COMPARE·CHAT) 스키마 변경이 없다. `ck_plan_prev_diff`도 만족. ADR-002 §2-4 "plan_version INSERT 전용 + 포인터 + revision"과 그대로 맞는다.
  - 얻는 것: 되돌리기 전 비교는 모두 기준 버전 ≠ 현재가 되어 **F-4 `applicable`과 F-5 검사 9만으로 D-041이 서버에서 보장**된다. 프론트 `undoBarrierId` 상태와 "새로 고침 틈"이 사라진다. 비용은 plan 쪽 INSERT 1문장·테스트 1건(0.25일)과 되돌릴 때마다 `plan_version` 1행, 새 버전의 `calc_run(PLAN)` 1행(PlanChanged 리스너, 이미 있음).
  - 포인터 교체를 유지해도 **데이터는 틀리지 않는다**는 점은 적어 둔다: 되돌린 뒤 예전 비교를 다시 적용하면, 그 비교의 기준 버전이 정말로 지금 계획이므로 결과는 처음 적용과 같다. 즉 틈은 화면 규칙(D-041) 위반일 뿐 계획 오염은 아니다. 그래서 A팀이 포인터 교체를 고르면 초안의 프론트 규칙으로 수용 가능하다(양보 가능). 쟁점이면 Q로 올린다.

- **R-3 시간 값: 초안 수용.** 폴링 1초는 PK·키셋 조회 + 대개 0행 UPDATE라 부담이 작다. 2초로 바꿔도 서버는 무관. ai-server → `/internal/calc` 타임아웃 < 30초 메모 수용.

- **R-4 ANSWER_PENDING 범위: 초안 수용**(소비자 판단 영역). 제공자 조건은 자리표시 `ANSWER` 고정(C12b-3).

- **R-5 대화 삭제 호출 방식: 초안(auth → chat 직접 호출)에 반대, 대안 변형을 권한다.** 이벤트로 하되 **동기 `@EventListener`** 로 받으면 초안이 걱정한 경쟁이 없고, `@SkipRenewal`과 순환이 생기지 않으며, 이미 열린 #46 설계를 유지한다(C12b-8). 초안을 고집하면 `@SkipRenewal`을 경로 기반으로 바꾸고 #34·#46·`moved-to-code.md`를 고쳐야 한다.

- **R-6 F-4 display 포함·그래프 제외: 찬성.** display는 `ResultDisplayBuilder`를 calc 안에서 한 번 더 부르는 것뿐이고 루트 공개 타입으로 `Map<String,String>`을 내보내면 된다(C12b-6). 그래프 제외로 `monthlyPoints` 직렬화가 빠져 응답이 작다.

- **R-7 `text` 길이 오류: 초안(`OUT_OF_RANGE` + `unit: "CHAR"`) 수용.** Bean Validation `@Size`의 `min`·`max` 속성을 그대로 꺼내 `OUT_OF_RANGE`로 바꾸는 매핑 하나면 되고, 새 `reason`을 만들지 않아 advice 분기가 늘지 않는다. 단 trim 뒤 길이는 `@Size`가 못 보므로 컨트롤러(또는 compact constructor)에서 trim 후 검사하는 작은 코드가 필요하다.

- **R-8 `expectedRevision` 출처: 초안 수용.** 서버는 revision 하나만 비교하므로 출처가 하나인 편이 제공자에게도 단순하다. F-4에 `planRevision`을 싣지 않는 것 찬성(F-4가 plan을 한 번 더 읽지 않아도 됨).

- **R-9 오래된 PENDING 정리: 초안(읽을 때 정리) 수용.** `ix_chat_message_pending` 부분 인덱스로 거의 항상 0행 UPDATE다. `@Scheduled`도 한 메서드라 비용은 비슷하지만, 재기동 직후에도 사용자가 보는 순간 정리된다는 점에서 초안이 낫다. 조건: F-2가 쓰기 트랜잭션이 되는 것을 구현 메모로 적고, 리스너 갱신에 `AND status='PENDING'`을 반드시 붙인다(늦은 응답이 `FAILED`를 덮지 않게).

- **R-10 F-5 검사 순서: 초안(PLAN_CHANGED 먼저) 수용.** 다만 이유 문장을 고친다: chat 쪽 검사 3(최신이 아님 → `STALE_COMPARISON`)은 plan의 검사 8보다 **항상 먼저** 돈다(plan은 대화를 모름). 그래서 "둘 다 해당하면 큰 쪽을 알린다"는 plan 안의 8·9 사이에서만 참이다. 계약에 그렇게 적으면 된다. 검사 3이 먼저 걸려도 프론트 동작(그 버튼 비활성)이 맞으므로 문제는 없다.

## 제공자 쪽에서 꼭 지켜야 할 것 (양보 불가)

1. **순환 금지 — auth ⇄ chat.** `@SkipRenewal`(auth)을 chat이 쓰는 한 auth → chat은 둘 수 없다. 대화 삭제는 chat → auth 방향(이벤트, 동기 수신)으로 한다. 반대 방향을 원하면 `@SkipRenewal`을 경로 기반으로 바꾸는 것이 함께 와야 한다. 근거: `modulith.md:17`, `ModularityTests.verifyModules()`, #45·#46 완료 조건.
2. **plan은 의존 `{}` 유지.** `PlanApplyService`의 인자·반환·예외에 chat·calc·config 타입 금지. 기준 버전은 `Long`, 변경은 `Map<String, JsonNode>`(camelCase 키).
3. **`condition_changes`는 camelCase로 저장**(#41). 그렇지 않으면 F-5 전체가 `FIELD_NOT_CHANGEABLE`이 된다.
4. **F-5 쓰기는 plan 한 트랜잭션, 0행이면 롤백**(고아 `plan_version` 금지). revision 조건부 UPDATE가 기준 버전 검사의 안전성까지 보장하므로 잠금은 쓰지 않는다.
5. **모든 오류 본문에 `code`.** Spring 기본 예외(타입 불일치·없는 경로·메서드·미디어 타입)도 매핑한다. 모듈 예외는 `config` 타입을 상속하지 않는다(순환 방지).
6. **F-4는 calc 루트 공개 API로만.** chat이 `calc.web`·`calc.application` 타입이나 calc 리포지토리를 직접 쓰지 않는다. 재계산은 그 `calc_run`의 데이터 버전·`engine_version`(ADR-002, #44 예외 수용 기준).
7. **`SameSite=Lax` 이상.** CSRF를 끈 상태에서 F-1·F-5 같은 상태 변경 POST를 막는 유일한 장치다.
8. **대화 삭제는 한 문장 일괄 DELETE, 로그인 응답 전에 완료.** 리스너 완료 갱신은 `AND status='PENDING'` 조건, 0행이면 citation을 넣지 않는다.

## 양보 가능한 것

- R-2 되돌리기 방식: 제공자는 새 버전 INSERT를 권하지만, 포인터 교체 + 프론트 `undoBarrierId`도 데이터 정합성 문제는 없으므로 수용 가능.
- F-5 응답의 `previousVersionId`·`undoAvailable` 유지 여부(#33 응답과 같은 record면 비용 없음).
- `PlanApplyService` 세부 시그니처(경로별 메서드로 나눌지, 검증 결과 record 모양).
- calc 공개 API 이름(`ChatComparisonQuery` 등)과 버전 지정 기준 데이터 조회를 어느 A팀 Issue(#32·#78·#29)에 둘지.
- F-1 "`text`가 문자열이 아님 → 400" 줄 삭제(Jackson 강제 변환 허용).
- 오래된 PENDING 정리를 읽을 때 할지 `@Scheduled`로 할지(초안 수용, 바꿔도 무방).
- 폴링 1초 ↔ 2초, R-7 `CHAR` ↔ `TOO_LONG`.
- 오류 처리 구현 방식(`ErrorResponseException` 상속 ↔ advice 타입별 매핑). 계약에는 "config 타입 상속 금지"만 있으면 된다.
