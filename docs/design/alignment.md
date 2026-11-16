# SRS·결정과 moeun 설계의 차이 (기획 루프 7번, tech-architect)

> **정정 (2026-11-16)**: 이 문서의 계약 초안은 확정 최종본으로 대체됐다 — `docs/design/contracts/internal-calc.md`(#10), `plan-context.md`(#11), `frontend-api-chat.md`(#12-b), `frontend-api-plan.md`(#12-a). 특히 옛 A-1(`POST /api/plan/apply {source:"CHAT"}`)·A-2 모양은 F-5 `POST /api/chat/messages/{id}/apply`·P-5 `POST /api/plan/undo`(`{revision}`, D-068)로 바뀌었다. 차이가 있으면 최종본을 따른다.


> 작성: tech-architect, 2026-11-16. **새로 설계하지 않고**, 기획 문서와 moeun에 이미 있는 설계를 맞춰 본 결과다.
> - 기획 기준: `docs/srs.md`(D-045 반영본), `docs/decisions.md`(D-001~047), `docs/scope-review.md`, `docs/notion-decisions.md`
> - moeun 기준(읽기만 함): `db/decision.md`(ADR-001·002), `db/tables.md`, `db/erd.md`, `db/moved-to-code.md`, `backend/CLAUDE.md`, `backend/src/main/java/com/moeun/backend/calc/*`, `backend/src/main/resources/db/schema.sql`, `ai-server/CLAUDE.md`, `ai-server/README.md`, `ai-server/app/schemas.py`, `ai-server/app/llm/agent.py`, `ai-server/app/llm/prompts.py`, `ai-server/app/tools/calc.py`, `ai-server/.claude/rules/langchain.md`
> - 경로는 `moeun/`을 기준으로 줄여 적었다.

## 0. 읽는 법

- **제안** 열의 값
  - **SRS 맞춤**: moeun이 ADR로 일부러 정한 것이라 SRS·결정 쪽 문구를 moeun에 맞춘다.
  - **moeun 맞춤**: 확정 결정과 어긋나므로 moeun 코드·문서를 고친다(결정 변경 없음).
  - **팀 결정 필요**: 어느 쪽으로 가든 기존 D-번호를 바꾸거나 새로 정해야 한다. 질문 후보(Q-041~)로 적었다.
  - **합의 필요**: 결정까지는 아니고 A·B팀이 계약으로 정하면 되는 것.
- **영향**: 상(데모 핵심 흐름이나 숫자가 틀어짐) / 중(구현 중 재작업) / 하(문서만 고치면 됨).
- 이 문서는 moeun을 고치지 않았다. "moeun 맞춤" 항목은 moeun의 Issue로 옮겨야 한다(D-047).

## 1. 한눈에 보기: 큰 차이 상위 5개 (영향순)

| 순위 | 항목 | 한 줄 요약 | 제안 |
|---|---|---|---|
| 1 | 대화 보관 기간 | D-030은 "대화 기록은 세션 동안만", moeun은 `chat_message` 영속 저장 + 무상태 JWT라 "세션 끝"이 없음 | 팀 결정 필요 (Q-041 후보) |
| 2 | 대화로 바꿀 수 있는 조건 | D-040은 4개(월 저축액·비중·적금 금리·기한), moeun의 `ConditionChanges`·도구 스키마·프롬프트·범위 밖 문구는 7개(목표 금액·보유 자산·기존 납입액 포함) | moeun 맞춤 |
| 3 | 대화 비교 결과의 계약 | `/internal/calc` 응답이 `{calcRunId, ...결과}`로만 적혀 있고, 검증 오류 형식·"내 계획 vs 바꾼 조건" 차이 값이 없음. 그대로면 LLM이 차이를 직접 계산하게 됨(FR-AI-02 위반 위험) | 합의 필요 (B팀 계약 C-2, C-3) |
| 4 | 재계산 시 시작월 | `CalcInput.calcStartMonth` 주석이 "재계산할 때는 현재 월이 들어온다". D-013(확정)은 어떤 동작도 시작월을 새로 정하지 않음 | moeun 맞춤 |
| 5 | 세션 관리 | NFR-SEC-02·D-031은 "서버 세션", moeun은 무상태 JWT(ADR-002, 사용자 확인). 폴링은 토큰 연장에서 빠져 D-031 문구("서버로 가는 요청만 조작")와도 다름. HttpOnly 쿠키라 클라이언트가 토큰을 지울 수 없어 로그아웃 경로가 비어 있음 | SRS 맞춤 + 팀 결정 필요 (Q-042 후보) |

## 2. 상세 비교표

### 2-1. 인증·세션

| 항목 | SRS·결정(ID) | moeun 현재 설계(파일) | 차이 | 영향 | 제안 |
|---|---|---|---|---|---|
| 세션 저장 방식 | NFR-SEC-02 "세션은 서버에서 관리", D-031 "서버 세션 만료 시간 기준" | 무상태 JWT, 만료 30분, `user_session` 테이블 삭제. NFR-SEC-02를 "서버가 서명·만료를 검증"으로 재해석했고 사용자가 확인함 (`db/decision.md` ADR-002 §2-5, `db/moved-to-code.md` §1) | 저장 위치가 다름. 만료를 서버가 판정한다는 점(D-031의 핵심)은 같음 | 중 | **SRS 맞춤**. NFR-SEC-02 설명을 "서버가 토큰 서명과 만료를 검증하고, 만료된 토큰의 요청은 처리하지 않는다"로 고치고 D-031 보충 결정을 남긴다. 이유: ADR로 이미 정했고, 30분 만료·서버 판정이라는 사용자 관점 동작은 같다 |
| 무엇이 만료를 늘리나 | D-031 "서버로 가는 요청만 조작으로 본다" | `TokenRenewalFilter`가 사용자 조작 요청에만 새 토큰 발급, 폴링은 `@SkipRenewal`로 제외 (`db/moved-to-code.md` §1) | AI 설명 폴링은 서버 요청이지만 만료를 늘리지 않음 | 하 | **팀 결정 필요(Q-042 후보)**. moeun 쪽이 더 낫다(화면만 열어 두고 폴링으로 세션이 영원히 살아 있는 문제를 막음). D-031에 "폴링(대화 상태 조회)은 제외"를 덧붙이는 보충 결정을 권장 |
| 로그아웃 | FR-AUTH-03 헤더의 로그아웃 | "클라이언트가 토큰을 지우는 것으로 처리" + "토큰은 HttpOnly·Secure 쿠키로 전달" (ADR-002 §2-5, §4-1) | HttpOnly 쿠키는 JS로 지울 수 없다. 서버가 `Set-Cookie: Max-Age=0`을 돌려주는 로그아웃 엔드포인트가 필요한데 정의가 없음 | 중 | **moeun 맞춤**. `POST /api/auth/logout`(쿠키 만료만, DB 쓰기 없음)을 A팀 계약에 추가. 이유: 새 인프라 없이 ADR의 쿠키 방식을 완성 |
| 로그아웃 후 토큰 유효 | FR-AUTH-02 만료된 세션은 처리하지 않음 | 로그아웃해도 남은 시간 동안 토큰 유효(ADR-002 §3, 위험 1) | 쿠키를 서버가 지우면 정상 브라우저에서는 문제없음. 탈취 시만 위험 | 하 | 데모 범위에서 수용. SRS 변경 불필요 |
| CSRF | (SRS에 없음) | 쿠키 인증 | 쿠키 인증이면 `SameSite` 설정이 필요 | 하 | A팀 구현 메모(쿠키 `SameSite=Lax` 이상). 결정 불필요 |

### 2-2. 대화 경로와 서버 경계

| 항목 | SRS·결정(ID) | moeun 현재 설계(파일) | 차이 | 영향 | 제안 |
|---|---|---|---|---|---|
| 호출 경로 | NFR-INT-03 "AI 서버는 Spring 계산 엔진을 도구 호출로 이용". 경로는 명시 없음. `scope-review.md` §5-2는 "프론트→FastAPI→Spring→FastAPI→프론트"로 적음 | 프론트 → Spring `chat`(질문 저장, ASSISTANT `PENDING`) → 이벤트 `ChatAnswerRequested` → ai `POST /chat` → ai가 Spring `POST /internal/calc` 호출 → Spring이 `COMPLETED/FAILED` 기록 → 프론트 폴링. ai-server는 Spring만 호출하고 브라우저에 노출하지 않음 (`ai-server/README.md`, `backend/.claude/rules/modulith.md` 이벤트 표) | SRS와 충돌은 없음. scope-review의 경로 설명만 다름 | 하 | **SRS 맞춤**. NFR-INT-03 비고에 "프론트는 Spring만 호출, AI 서버는 Spring 내부 API만 호출"을 적고 scope-review의 경로 설명을 정정. 이유: 인증·소유권 검사가 Spring 한 곳에 모이고 AI 서버에 사용자 토큰이 가지 않음(D-030과도 맞음) |
| 비동기 표시 방식 | FR-AI-01 계산 결과 먼저, 설명은 뒤이어 | `chat_message.status=PENDING` + 폴링 (`db/tables.md` §13) | 방식만 구체화됨 | 하 | 그대로 사용. 폴링 간격·시간 초과는 TBD-33 임시값으로 계약에 적음 |
| 설명(EXPLAIN) 요청을 누가 시작하나 | FR-AI-01 | `ChatMode.EXPLAIN`과 `calc_run_id`는 있으나 누가 언제 EXPLAIN 메시지를 만드는지 없음 (`ai-server/app/schemas.py`) | 트리거 미정 | 중 | **합의 필요**. 초안: 결과 화면이 계산 응답을 받은 뒤 프론트가 `POST /api/chat/explanations {calcRunId}`를 부름. 이유: 이벤트 하나를 더 만드는 것보다 단순하고 FR-AI-05(다시 요청)와 같은 엔드포인트를 씀 (B팀 계약 F-3) |
| Spring `chat` 모듈 담당 | D-046 B팀은 AI 대화·설명·RAG | `chat` 모듈은 backend 안에 있음 (`backend/CLAUDE.md` 모듈 표) | B팀 작업이 ai-server뿐 아니라 Spring `chat` 모듈까지 걸침 | 중 | **합의 필요**. `chat` 모듈은 B팀, `calc`·`plan`·`auth`·`refdata`는 A팀. `/internal/calc`는 `calc` 모듈이라 A팀이 만들되 계약은 함께 정함 |
| 대화 기록 보관 | D-030 "대화 기록은 세션 동안만 보관" | `chat_message` 영속 저장. ADR-001 진행자 해석 2번 "AI 대화 메시지는 DB에 영속 저장" (`db/decision.md` ADR-001 §1, `db/tables.md` §13) | **정면 충돌.** 무상태 JWT라 "세션 끝" 시점을 서버가 알 수도 없음 | 상 | **팀 결정 필요(Q-041 후보)**. 아래 §3-1 선택지 |
| LLM에 넘기는 정보 | D-030 계산 결과와 조건만, 계정 식별 정보 없음 | ai-server는 `member_id`를 받지만 프롬프트에는 `plan_context`·발화·기록만 넣음 (`ai-server/app/llm/agent.py` `build_messages`) | 일치 | 하 | 그대로. 다만 `plan_context`에 넣을 필드 목록을 계약으로 고정(B팀 계약 C-1) |

### 2-3. 대화 조건 변경, 비교, 범위 검증

| 항목 | SRS·결정(ID) | moeun 현재 설계(파일) | 차이 | 영향 | 제안 |
|---|---|---|---|---|---|
| 대화로 바꿀 수 있는 조건 | D-040·CP-07 4개(월 저축액, 비중, 적금 금리, 기한). 목표 금액은 입력 수정 | `ConditionChanges` 7개 필드(목표 금액, 보유 자산, 기존 납입액 포함), 도구 `recalculate` 스키마도 7개, 시스템 프롬프트 범위 안내도 7개, `OUT_OF_SCOPE_COPY`는 "목표 금액, 기간, 월 저축액 같은 조건"을 안내 (`ai-server/app/schemas.py`, `app/llm/agent.py`, `app/llm/prompts.py`) | moeun이 3개를 더 허용 | 상 | **moeun 맞춤**. 도구 스키마·프롬프트·문구를 4개로 줄이고, Spring `ConditionValidator`의 `rules.yml › change-paths.CHAT.fields`도 4개로 둔다(서버가 최종 거부). `ConditionChanges` 모델 자체는 다른 경로와 공유하면 남겨도 됨 |
| 비교 기준(누적 여부) | D-041 기준은 항상 내 계획, 누적하지 않음 | `/internal/calc`는 `memberId`의 현재 계획에 `conditionChanges`만 얹어 계산(누적 상태 없음). 하지만 `history` 20개를 LLM에 넘겨 LLM이 이전 턴의 값을 도구 인자에 다시 넣을 수 있음 (`app/schemas.py` `ChatRequest.history`, `app/llm/agent.py`) | 서버 구조는 맞지만 LLM이 누적할 여지가 있음 | 중 | **moeun 맞춤**. 프롬프트에 "이번 발화에서 말한 조건만 넣는다"를 넣고, fake 모델 테스트로 "월 50만원 → 기간 5년" 시나리오를 고정 |
| 범위 검증 위치 | D-033 Spring 계산 엔진 한 곳, AI는 오류를 받으면 되묻는다 | Spring `ConditionValidator.validate(path, values)`가 모든 경로를 검사 (`db/moved-to-code.md` §1·§3). ai-server `ConditionChanges`에도 `gt=0`, `le=100` 같은 형식 검사가 있음. `CalcClient`는 400/409/422를 `CalcError(resp.text)`로 모델에 그대로 넘김 (`app/tools/calc.py`) | 형식 검사가 두 곳이지만 범위(TBD-09 수치)는 Spring 한 곳. 오류 본문 형식이 정해지지 않아 LLM이 원문 텍스트를 읽고 되묻는 구조 | 중 | **SRS 맞춤 + 합의 필요**. ai-server의 형식 검사(음수·100 초과)는 "범위 검증"이 아니라 타입 검사로 보고 허용(D-033 위반 아님). Spring 오류 형식을 `ProblemDetail` 기반으로 고정(B팀 계약 C-3)해서 `field`, `min`, `max`, `unit`을 LLM이 그대로 인용하게 함 |
| 비교 결과는 검증 통과 뒤에만 | D-033 | `assemble`이 `turn.calc_run_id`가 있을 때만 `RECALC_RESULT`로 만듦. `calc_run_id`는 `/internal/calc` 성공 시에만 채워짐 (`app/llm/agent.py`) | 일치 | 하 | 그대로 |
| 비교 결과의 모양 | D-022 "현재 조건과 바꾼 조건의 비교 결과" | `/internal/calc` 응답은 `{calcRunId, ...결과}`로만 적힘(README). 현재 계획 결과와 차이 값이 없음. 화면이 비교를 그릴 API도 없음 | LLM이 "현재보다 N만원 늘어요"를 말하려면 스스로 빼기를 해야 함 → FR-AI-02·NFR-INT-01 위반 위험 | 상 | **합의 필요**. `/internal/calc` 응답에 `current`, `changed`, `diff`(Spring이 계산)를 담고, 프론트용 비교 조회 API를 둠(B팀 계약 C-2, F-4) |
| 범위 밖 3유형 | D-045 FR-AI-09 '조건 변경 / 설명 / 그 밖' | `message_type`: QUESTION, ANSWER, EXPLANATION, RECALC_RESULT, CLARIFY, OUT_OF_SCOPE, FAILURE (`schema.sql` `ck_cm_type`) | 대응됨: 조건 변경→RECALC_RESULT·CLARIFY, 설명→ANSWER·EXPLANATION, 그 밖→OUT_OF_SCOPE | 하 | 그대로. 다만 `OUT_OF_SCOPE_COPY`가 코드에 하드코딩되어 CP-05(문구표 하나)와 어긋남 → 문구표 키로 옮김(**moeun 맞춤**) |
| 범위 밖이면 계산하지 않음 | FR-AI-09 | `ck_cm_out_of_scope`(OUT_OF_SCOPE면 `calc_run_id` NULL). 단 LLM이 계산한 뒤 OUT_OF_SCOPE로 끝내면 CHAT `calc_run` 행이 남음 | 화면 동작은 맞음 | 하 | 그대로(정리 배치 불필요한 수준) |
| 상품명 표기 | D-028 출처 링크엔 상품명, 본문엔 'S&P500 추종 ETF' | 프롬프트에 "특정 상품을 추천하거나 고르지 않는다"만 있음. 본문 상품명 금지 규칙과 출력 검사 없음 (`app/llm/prompts.py`) | 규칙 누락 | 중 | **moeun 맞춤**. 프롬프트 규칙 + `assemble` 단계의 금지 표현·상품명 검사(PR-05, NFR-USA-02) |
| 숫자 대조 | FR-AI-02, PR-04 "AI 응답 숫자를 계산 결과와 자동 대조, 불일치 시 설명 실패" | 프롬프트로만 막음. 대조 로직 없음 | 누락 | 중 | **moeun 맞춤**(B팀 Issue). `assemble`에서 본문의 금액 표현을 `plan_context`·계산 응답 값과 대조, 불일치면 `AgentError("NUMBER_MISMATCH")` |
| 되묻기 상태 | TBD-27 되묻기, D-041 AI 서버는 대화 상태를 들고 있지 않음 | `clarify_fields` 계약은 규칙에만 있고 구현 전. Spring 보관 위치 미정 (`ai-server/.claude/rules/langchain.md`) | 미정 | 하 | **합의 필요**. 3주 범위에서는 `clarify_fields`를 미루고, 되묻기 다음 요청은 지금 SDK 루프처럼 `history`만으로 처리한다. 데모 시나리오에서 되묻기 실패가 실제로 보이면 그때 `chat_message`에 컬럼을 추가할지 `../db`와 정한다. 이유: 스키마 변경 없이 시작할 수 있음 |

### 2-4. 계획 버전, 적용, 되돌리기

| 항목 | SRS·결정(ID) | moeun 현재 설계(파일) | 차이 | 영향 | 제안 |
|---|---|---|---|---|---|
| 계획 이력 | FR-PLAN-03·04, TBD-21 되돌리기는 직전 1개 | `plan_version` INSERT 전용 + `plan.current_version_id / previous_version_id` + `revision` 낙관적 락 (`schema.sql`, `db/tables.md` §2·§3) | 일치 | 하 | 그대로 |
| 적용 출처 | D-016 대화 적용은 확인창 없음, FR-PLAN-01 대화 밖 적용은 확인창 | `plan_version.source IN ('INPUT','ALTERNATIVE','COMPARE','CHAT')` | 확인창은 프론트 동작이라 DB 차이 없음 | 하 | 그대로 |
| 적용 API 형태 | FR-PLAN-03, D-046 B팀은 적용 요청을 A팀 흐름으로 넘김 | 서비스 설명만 있음("한 트랜잭션에서 `plan_version` INSERT와 `plan` UPDATE"). HTTP 계약 없음 (`db/moved-to-code.md` §3) | 엔드포인트·요청 본문 미정 | 상 | **합의 필요**(B팀 계약 A-1). 대화 적용은 `chatMessageId`만 보내고 서버가 `chat_message.condition_changes`를 읽어 다시 검증·저장. 이유: 화면에서 조건 값을 다시 받지 않아 범위 밖 값이 들어올 길이 없음(D-033) |
| 최신 결과만 적용(D-041) | D-041 적용 버튼은 가장 최근 비교 결과에만, 되돌린 뒤 이전 결과 버튼 모두 비활성 | 규칙 없음. 되돌리기가 포인터만 바꾸는지 새 `plan_version`을 INSERT하는지도 문서마다 표현이 다름(`tables.md` §2 "적용하거나 입력을 수정할 때마다 새 행", `moved-to-code.md` §3 "적용·되돌리기 서비스가 ... INSERT와 UPDATE") | 되돌리기가 포인터만 바꾸면, 되돌린 뒤 최신 비교 결과의 기준 버전이 다시 현재 계획과 같아져 서버 검사만으로는 D-041을 지킬 수 없음 | 중 | **합의 필요**. 초안: (1) 버튼 활성은 프론트 상태로 관리(D-041 이유 "AI 서버가 대화 상태를 들고 있지 않아도 됨"과 같음), (2) 서버는 "가장 최근 RECALC_RESULT이고, 그 `calc_run.plan_version_id`가 현재 계획과 같고, `expectedRevision`이 맞을 때"만 적용. 되돌린 뒤 재적용 차단까지 서버가 보장하려면 되돌리기 시각을 비교해야 하는데 `plan.updated_at`이 없음 → 데모 범위에서는 프론트 차단으로 충분 |
| 되돌리기 토스트 10초 | D-041 | 서버 시간 제한 없음 | 프론트가 10초 후 숨김. 서버는 `revision`만 확인 | 하 | 그대로 |
| 동시 적용 | TBD-37 나중 저장 우선, PR-08 버전 확인(MVP는 나중 것 우선으로 충분) | `revision` 불일치면 0행 갱신, 현재 상태 반환 | moeun이 PR-08 쪽(먼저 저장 우선, 나중 요청 거절)에 가까움 | 하 | **SRS 맞춤**. PR-08을 채택한 것으로 보고 계약에 `409 PLAN_CHANGED` 응답을 둠. 결정 변경 불필요(PR-08이 이미 허용) |
| 시작월 고정 | D-013(확정), D-032 | `plan_version.calc_start_month`에 저장(맞음). 그러나 `CalcInput` 주석 "재계산할 때는 현재 월이 들어온다" (`backend/.../calc/CalcInput.java`) | 주석대로 구현하면 대화·비교·적용 재계산마다 시작월이 바뀜 | 상 | **moeun 맞춤**. `ConditionResolver`는 항상 `plan_version.calc_start_month`를 쓰고, 적용·되돌리기로 새 버전을 만들 때도 이 값을 복사. 단위 테스트 "5월에 대화 재계산해도 시작월 3월" 추가 |
| 적용 후 데이터 버전 | D-045 범위 안은 "버전 값 기록"만 | `calc_run`에 금리·지수·파라미터 버전 3종 + `engine_version` 기록 | 일치 | 하 | 그대로 |

### 2-5. 데이터 버전 (D-017·D-038·D-045)

| 항목 | SRS·결정(ID) | moeun 현재 설계(파일) | 차이 | 영향 | 제안 |
|---|---|---|---|---|---|
| 버전 기록 | NFR-INT-02 범위 안: 버전 값 기록 + 가정 보기 기준월 | `calc_run.*_version_id`, `AppliedDataVersions`, `Assumptions.savingsRateBaseMonth / sp500BaseDate` (`backend/.../calc/`) | 일치. 사용자가 금리를 넣으면 `savingsRateBaseMonth`가 null이라 기준월이 S&P500 기준일 하나만 보임 | 하 | 그대로 |
| 과거 버전 보관·재사용 | D-017·D-038 해커톤 범위 밖 | `data_version`은 행을 지우지 않고 `is_active`로 전환. 그래서 과거 버전 보관은 이미 됨. 다만 "계획에 저장된 버전으로 새 계산"은 `plan_version`에 버전 컬럼이 없어 `calc_run`에서 찾아야 함 | 범위 밖이지만 구조상 나중에 붙이기 쉬움 | 하 | 그대로. 해커톤 동안 데이터 갱신이 없으므로 활성 버전만 쓰면 D-045와 같음 |
| 재로그인 재계산 문구 | D-010 "최신 데이터로 다시 계산하지 않는다"(TBD-23 대체) | `calc_run.created_at` 설명 "재로그인 시 최신 데이터로 재계산할지 판단한다(FR-PLAN-05)" (`db/tables.md` §4) | Notion TBD-23 원문을 따른 설명이 남아 있음 | 하 | **moeun 맞춤**(문서 한 줄). "같은 버전에 대한 최신 기록을 고른다"만 남김 |
| 결과 저장 | (SRS에 없음) | 결과를 저장하지 않고 화면을 열 때 `calc_run`의 버전으로 다시 계산(ADR-002) | 재로그인 시 `calc_run`에 기록된 버전으로 계산하면 D-010과 같은 동작 | 하 | 그대로. "결과 화면 재계산은 마지막 PLAN `calc_run`의 버전을 쓴다"를 A팀 구현 메모로 |

### 2-6. 범위 밖 분기(D-045)를 위해 이미 만든 테이블·컬럼·타입

| 분기 | 이미 있는 것 (파일) | 제안 |
|---|---|---|
| 기한 없음 (D-005·D-008·D-026) | `plan_version.target_period_months` NULL 허용, `CalcInput.targetPeriodMonths` null = 도달 시점 계산, `ScenarioResult.goalReachMonth`, `CalcResult.targetMonth` null | 컬럼·타입은 남긴다(나중에 되살리기 쉬움, 비용 없음). 해커톤에서는 `rules.yml`에서 `required: true`로 막고, `CalcEngine`의 기한 없음 분기는 구현하지 않고 `IllegalArgumentException`으로 막는다. 이유: 미구현 분기가 조용히 이상한 숫자를 내지 않게 |
| 월 저축액 모름 (D-015·D-024·D-025·D-043) | `plan_version.monthly_saving_amount` NULL 허용, `CalcInput.monthlySavingAmount` null, `CalcResult.requiredMonthlySaving` | 위와 같음. `requiredMonthlySaving`은 항상 null로 응답 |
| 오래된 계획 질문 (D-018·D-037) | 없음("한 번만" 답 저장 컬럼 없음) | 추가하지 않음 |
| 과거 데이터 버전 보관 (D-017·D-038) | `data_version` 행 보존 + `is_active` | 이미 있으나 재사용 로직은 만들지 않음 |
| (참고) FR-INP-08 Won't | `plan_version.existing_monthly_contribution`, `RatioResolver`의 DERIVED_EXISTING 분기, ai-server `ConditionChanges.existing_monthly_contribution` | 컬럼은 남기되 입력·대화 경로에서 받지 않음. `RatioResolver`는 USER / DEFAULT(5:5) 두 갈래만 구현 |
| (참고) FR-RES-09 Should | `plan.baseline_scenario` | 기본값 AVG로 저장, 선택 UI는 만들지 않음(scope-review 제안과 같음) |

### 2-7. 계산 엔진 타입 (`CalcInput`, `CalcResult` 등)과 SRS

| 항목 | SRS·결정(ID) | moeun 현재 설계(파일) | 차이 | 영향 | 제안 |
|---|---|---|---|---|---|
| 금액·기간 단위 | CP-02(TBD-09 단위 만원), CP-04 '약 N만원' | 원 단위 정수(`long`), 개월 정수 | 입력 단위(만원)와 내부 단위(원)가 다름 | 하 | 그대로. 변환은 프론트 입력 단계 한 곳. 대화로 받은 "50만원"은 LLM이 원 단위로 넣고 Spring이 검증 |
| 기간 표기 | FR-INP-04 'n년 n개월' | `targetPeriodMonths` | 표시 변환만 필요 | 하 | `Formatter`(CP-04)에서 처리 |
| 시나리오 | CP-01, FR-RES-03, ETF 0%면 하나 | `Scenario {GOOD, AVG, BAD}`, ETF 0%면 AVG 하나, `findBaselineResult()`가 AVG로 대체 | 일치. ADR-001 한계 1번을 코드로 해결 | 하 | 그대로 |
| 3구간 산정 방식 | D-006(상·하위 10%), TBD-01 CAGR 적용 미결 | `ScenarioMethod {CAGR, ROLLING_DISTRIBUTION}` 둘 다 열어 둠 | TBD-01 미결 그대로 반영 | 중 | A팀이 1주차에 하나로 확정(scope-review §4). B팀 영향 없음 |
| 목표 대비 0원 달성 | CP-01, TBD-20 | `ScenarioResult.gapToGoal`, `isAchieved` 0 이상 달성 | 일치 | 하 | 그대로 |
| 판정에 반올림 전/후 | TBD-16 미결 | 원 단위 반올림(HALF_UP) 값으로 판정 | 사실상 "반올림 전(원 단위)"을 쓰는 쪽 | 하 | TBD-16 결정 때 이 구현을 근거로 삼으면 됨 |
| 가정 보기 항목 | FR-RES-06, D-027 환율 미반영, TBD-03 총보수 미반영 | `ExcludedItem {ETF_TOTAL_EXPENSE, EXCHANGE_RATE, ETF_DISTRIBUTION, HELD_ASSET_RETURN, SAVINGS_REDEPOSIT}` | 일치 | 하 | 그대로 |
| 이미 목표 초과 | FR-RES-01, CF-03 | `CalcStatus.ALREADY_EXCEEDED`, `hasExceededGoal()` | 일치 | 하 | 그대로. 대화 재계산에서 목표 금액을 못 바꾸므로(D-040) 대화로 초과 상태가 생길 일은 없음 |
| 시작월 | D-013, D-032 | `calcStartMonth` 주석 "재계산할 때는 현재 월" | 2-4 참고 | 상 | moeun 맞춤 |
| 비교 결과 타입 | FR-AI-07, FR-CMP-02, D-022 | 없음(`CalcResult` 하나뿐) | 비교용 묶음 타입이 없음 | 중 | **합의 필요**. `CalcComparison {current: CalcResult, changed: CalcResult, changes, diff}`를 calc 모듈 공개 타입으로(B팀 계약 C-2) |

### 2-8. AI 서버 구현 상태

| 항목 | SRS·결정(ID) | moeun 현재 설계(파일) | 차이 | 영향 | 제안 |
|---|---|---|---|---|---|
| 프레임워크 | 스택: LangChain + LangGraph | `app/llm/agent.py`는 anthropic SDK 루프. LangGraph 전환은 규칙만 있고 별도 작업 (`ai-server/CLAUDE.md`, `.claude/rules/langchain.md`) | 3주 안에 전환까지 할지 미정 | 중 | **팀 결정 필요(Q-043 후보)**. §3-3 선택지 |
| 출처 2개 이상 | FR-AI-03, TBD-31 | 프롬프트 + `diversify_orgs`(rag 규칙), 인용은 실제 검색된 chunk만 (`assemble`) | 일치 | 하 | 그대로. 적재 자료가 운용사 2곳 이상인지 확인(TBD-08) |
| 실패 처리 | FR-AI-04, TBD-33 | ai 4xx/5xx `{"error": CODE}` → Spring이 `FAILED`·`FAILURE` 기록 | 일치. 시간 초과 값 미정 | 하 | Spring → ai 호출 시간 초과를 임시 30초로 두고 TBD-33 실측 후 조정(합의 필요) |

## 3. 팀 결정이 필요한 항목 (질문 후보)

> 이 단계에서는 `open-questions.md`를 고치지 않았다. requirements-pm 또는 spec-verifier 단계에서 아래를 Q-041~로 옮기면 된다.

### 3-1. (Q-041 후보) 대화 기록을 어디에, 얼마나 보관하나? — 개발 차단(B팀 `chat` 모듈 설계)
- 관련: D-030, NFR-INT-03, FR-AI-01·04·05·07, ADR-001 §1(해석 2), ADR-002
- 왜 문제인가: D-030은 "세션 동안만", moeun은 영속 저장. JWT라 서버는 세션이 끝난 때를 모른다. `chat_message`는 비동기 응답(PENDING), 적용 대상(`condition_changes`), 출처(`chat_message_citation`) 저장에도 쓰여서 아예 저장하지 않을 수는 없다.
- 선택지:
  - A) **로그인할 때 그 계정의 이전 대화를 지운다**(moeun 테이블 유지, 삭제 쿼리 1개). 로그아웃 API에서도 지운다. → D-030 유지. "세션"을 "로그인부터 다음 로그인 전까지"로 해석. 만료로 끝난 대화는 다음 로그인까지 DB에 남음(데모 계정만 있어 위험 낮음)
  - B) **D-030을 바꿔 영속 보관**하고, 데모가 끝나면 일괄 삭제. 화면은 재로그인 후 이전 대화를 복원 → ADR-001 의도 그대로. 대화 복원 UI가 추가됨
  - C) A + 화면은 복원하지 않음(A와 같음, 표시만 명시)
- 권장: **A**. 이유: D-030(개인 금융정보 최소 보관)을 지키면서 moeun 스키마를 바꾸지 않음. 금융권 포트폴리오에서 설명하기 좋은 지점.

### 3-2. (Q-042 후보) NFR-SEC-02·D-031을 JWT 기준으로 고쳐 적나? 폴링은 만료 연장에서 빼나? — 개발 중 혼란
- 관련: NFR-SEC-02, FR-AUTH-02·03, D-031, ADR-002 §2-5
- 선택지: A) moeun대로: "서버가 토큰 서명·만료를 검증, 사용자 조작 요청만 만료를 30분 연장, 대화 상태 폴링은 제외, 로그아웃은 서버가 쿠키를 만료" / B) D-031 문구 그대로: 폴링도 연장(구현은 `@SkipRenewal`만 빼면 됨)
- 권장: **A**. 이유: ADR로 이미 확정했고, 화면을 열어 둔 채 폴링만으로 세션이 끝나지 않는 문제를 막음. D-031의 "기준이 서버 한 곳"은 그대로.

### 3-3. (Q-043 후보) 3주 안에 ai-server를 LangGraph로 전환하나? — 개발 중 혼란(B팀 일정)
- 관련: NFR-INT-03, 스택, `ai-server/.claude/rules/langchain.md`
- 선택지: A) 1주차에 전환(기존 테스트 통과가 완료 기준) 후 기능 추가 / B) SDK 루프로 Must를 먼저 끝내고 2주차 말 여력이 있으면 전환 / C) 전환하지 않고 해커톤 종료
- 권장: **B**. 이유: 동작하는 루프가 이미 있고, 전환은 사용자에게 보이는 기능을 늘리지 않음. 다만 스택에 LangGraph를 적었으므로 포트폴리오 설명이 필요하면 B의 2주차 말 판단 때 A로 당김.

### 3-4. 결정 변경은 아니지만 SRS 문구를 고칠 것 (requirements-pm)
- NFR-INT-03 비고: 호출 경로(프론트→Spring→AI→Spring 내부 API)
- NFR-SEC-02 설명: 3-2 결과 반영
- `scope-review.md` §5-2 경로 설명 정정

## 4. moeun에 올릴 수정 (결정 변경 없음, moeun Issue 후보)

| # | 내용 | 근거 | 담당 |
|---|---|---|---|
| M-1 | `CalcInput.calcStartMonth` 주석과 `ConditionResolver`: 항상 `plan_version.calc_start_month` 사용 | D-013 | A팀 |
| M-2 | ai-server 도구 스키마·프롬프트·범위 밖 문구를 4개 조건으로, `rules.yml › change-paths.CHAT.fields`도 4개 | D-040, CP-07 | B팀(ai) + A팀(rules.yml) |
| M-3 | 프롬프트: 이번 발화의 조건만 도구에 넣기(누적 금지) + 테스트 | D-041 | B팀 |
| M-4 | 본문 상품명 금지·추천 표현 검사, 숫자 대조 | D-028, CP-06, PR-04, FR-AI-02 | B팀 |
| M-5 | `OUT_OF_SCOPE_COPY` 등 고정 문구를 `copy/copy.ko.yml`로 | CP-05 | B팀 |
| M-6 | 로그아웃 엔드포인트(쿠키 만료) | FR-AUTH-03, ADR-002 | A팀 |
| M-7 | `db/tables.md` §4 `calc_run.created_at` 설명에서 "최신 데이터로 재계산" 삭제 | D-010 | 누구든(문서) |
| M-8 | 해커톤 범위 밖 분기(기한 없음·모름)는 `rules.yml`에서 필수로 막고 엔진 분기는 미구현으로 예외 처리 | D-045 | A팀 |
