# 소비자 재검토: frontend-api-chat-v2.md (moeun #12-b 대화, 4단계 마지막 1회)

> 관점: 프론트 대화창(B팀 #52~#54, A팀 #51·#55), Spring chat이 ai-server를 부르는 F-1·F-3 흐름(#41~#45).
> 근거: `frontend-api-chat-v2.md`, `review-frontapi-chat-v1-consumer.md`(내 v1 검토), `review-frontapi-chat-v1-provider.md`, `docs/decisions.md` D-041·D-044·D-051, moeun open Issue #12·#13·#16·#18·#19·#21·#23·#32·#33·#34·#41~#46·#49·#51~#55·#78(`gh api`로 본문 조회).

## 판정: 수정하면 수용

v1에서 막혔던 4곳(질문 대기 신호, #46 충돌, D-041 범위, 목 순서)은 모두 풀렸다. 남은 것은 계약 본문보다 **후속 Issue 배치의 빈틈 5개**와 목 사용 방식 1개다. 전부 본문 몇 줄로 닫힌다.

## (1) 내 v1 제안 반영 여부

| 제안 | 결과 | 확인 |
|---|---|---|
| `answerPending` | 반영(C12b-5). 서버 판정은 `status='PENDING' AND message_type='ANSWER'` 한 조건이라 F-1 `ANSWER_PENDING`과 같다. 프론트는 `hasPending`(폴링)·`answerPending`(보내기 버튼) 두 불리언만 본다 | 충분 |
| `changedKeys` | 반영(C12b-6). 저장값의 키를 꺼낸 것이라 계산이 아니다. 프론트는 "무엇을 바꿨나" 강조에만 쓴다 | **라벨 키 빠짐**(아래 필수 4) |
| planContext null → `AVG` | 반영(C12b-4, C12b-14). 계획 없는 질문이 422로 `FAILED`가 되는 일이 없다 | 충분 |
| 오류별 프론트 동작 | 반영. F-1(C12b-4)·F-2(C12b-2)·F-3(C12b-3a)·F-4(C12b-6)·F-5(C12b-7-2) 표가 `code`만 보고 고를 수 있다. 문자열 해석 없음 | **F-2 400 한 칸 빠짐**(필수 5) |
| 목 응답 배열 + 빠진 목 | 반영. 35개가 맞다(6+10+4+6+8+1) | **전 흐름 구현은 아직 안 됨**(필수 3) |
| F-4는 최신 RECALC만, 새 RECALC 도착 시 이전 버튼 즉시 비활성, 버튼 활성 한 줄 | 반영 | 충분 |
| F-3은 새 `calcRunId`로 | 반영 | **호출 지점이 여러 Issue에 걸림**(필수 2) |
| 폴링 연속 3회 실패 중단 | 반영 | 4xx 처리 빠짐(필수 5) |
| 응답에서 뺄 것(`conditionChanges`, `rank`, `status`, `previousVersionId`, `undoAvailable`) | 반영 | `planVersionId`는 남겼다(빼도 되는 것) |

## (2) 제공자 제안으로 소비자 쪽에 생긴 변화

- **이벤트 동기 수신(C12b-8)**: 프론트 영향은 하나다. 삭제가 실패하면 로그인·로그아웃 요청이 5xx로 실패한다. 로그인 화면(#47, A)이 일반 5xx를 "로그인하지 못했어요"로 처리하면 된다. 대화창 쪽 변화 없음. 수용.
- **PENDING `message_type='ANSWER'` 고정**: 화면에는 `null`로 가려 나가므로 프론트 영향 없음. 프론트는 `answerPending`만 본다. 수용.
- **camelCase 저장**: 프론트에 노출되지 않는다(`conditionChanges` 제외). 영향 없음.
- **`SameSite=Lax` 이상**: **프론트 배포·개발 구성에 제약이 생긴다.** Lax는 교차 사이트 `fetch`(GET 포함)에 쿠키를 보내지 않으므로, 프론트와 Spring이 다른 사이트에 있으면 F-2 폴링이 전부 401이 된다. 프론트·Spring을 **같은 사이트**(한 도메인, 또는 프록시)로 두고, 개발 서버는 Vite 프록시 또는 `localhost` 같은 사이트로 띄운다고 #13에 적어야 한다. 안 적으면 통합 기간(#55)에 처음 터진다.
- **복원 안전장치 1회**: 수용. "같은 폴링 주기 동안 다시 하지 않는다"의 **주기가 정의되지 않았다.** "`hasPending=false`로 폴링이 멈추거나 사용자가 F-1·F-3을 보낼 때까지"로 못박는다(#52 수용 기준).
- **id ≠ 커밋 순서**: 복원 안전장치로 막는 것을 수용. 프론트 비용 없음.
- **F-2 쓰기 트랜잭션, 가상 스레드, 0행 citation 미저장, `ErrorResponseException`**: 소비자 영향 없음.

## (3) 쟁점 최종 의견

### 쟁점 X-1: B(되돌리기 = 새 버전 INSERT)에 **동의, 내 v1 반대를 철회**한다

v2의 설명("B는 `previous_version_id = NULL`이라 #33 직전 1개와 충돌 없음")에 동의한다. 이유 셋.
1. 내 v1 반대(R-2 3번, "`previousVersionId` 체인이 길어진다")는 제공자 SQL을 정확히 읽지 못한 것이었다. 되돌린 뒤 `previous_version_id`는 NULL이라 다시 되돌리면 `NOTHING_TO_UNDO`다. 체인이 없고 "직전 1개"가 유지된다. #33 수용 기준("직전 계획으로 돌아가고 시작월은 그대로", "이전 버전이 없으면 409 NOTHING_TO_UNDO")이 그대로 참이다.
2. 소비자에게 B가 가장 싸다. F-4 `applicable`과 F-5 검사 9가 D-041을 새로고침과 무관하게 지키므로 프론트는 `planChangeBarrierId`를 기억하지 않는다. 내가 제안한 C(시각 비교)는 `plan` 컬럼 추가와 `calc_run.created_at` 비교가 필요해 B보다 비싸다. C는 철회한다.
3. 흐름 확인: 비교가 v1 기준 → 적용(v2) → 되돌리기(v3 = v1 복사) 뒤 그 비교의 기준 v1 ≠ 현재 v3이므로 `applicable=false`, 눌러도 `STALE_COMPARISON`이다. 사용자는 다시 질문해야 한다. D-041 "되돌리기 뒤 이전 결과 버튼 비활성"과 일치한다.

소비자 쪽 부수 확인(B 채택 시): 되돌리기 응답의 새 `revision`을 #51 토스트가 쓰고, 결과 재조회로 얻은 새 `calcRunId`(새 버전의 PLAN 기록)로 F-3을 부른다. v3 `source`가 복사 원본이라는 점은 프론트에 보이지 않는다. 영향 없음.

### 쟁점 X-2: A(범위 확대)에 **동의**한다. 단 구현 방식을 바꾸자

서버가 이미 막는 버튼을 살려 두면 사용자가 눌러서 토스트를 본다. 비용이 작으니 A를 권한다. D-041 문장("되돌리기 뒤")보다 넓으므로 결정 기록 한 줄이 필요하다(사람이 정한다).

**구현은 "네 곳에서 함수를 부른다"가 아니라 "계획 상태의 `revision`이 바뀌면 대화창이 스스로 끈다"로 한다.** v2 문구(C12b-7-4)는 대화 적용·되돌리기·입력 저장·`PLAN_CHANGED` 네 지점에서 함수를 부르는데, 되돌리기(#51)와 입력 저장은 A팀 `features/plan`·`features/input`이고 함수는 B팀 `features/chat`에 있다. 팀 경계를 넘는 호출이 생긴다. 네 경우 모두 `revision`이 바뀌므로, #53이 `revision` 변경을 구독해 "가진 모든 적용 버튼 비활성"을 한 곳에서 처리하면 A팀 코드는 건드리지 않는다. 최초 로드(undefined → N)는 제외한다. 이 문장을 C12b-7-4 프론트 문단에 넣는다.

## 항목별 의견

- [C12b-1 목록] 수용.
- [C12b-2 인증·공통] 수정 — `SameSite=Lax` 전제에 "프론트와 Spring은 같은 사이트(프록시 포함)"를 한 줄 더한다(위 (2)). 폴링 실패 규칙은 아래 필수 5로 보강.
- [C12b-3 메시지 모양] 수용 — PENDING `messageType=null`과 `answerPending` 조합으로 프론트가 문자열을 해석할 일이 없다.
- [C12b-4 F-1] 수용 — 오류 6행이 기계적으로 고를 수 있다. `ANSWER_PENDING` 동작(버튼 비활성, 폴링 재개, 글 유지)이 내 v1 제안 그대로다.
- [C12b-5 F-2] 수정 — 복원 안전장치의 "주기" 정의, 4xx 처리(필수 5).
- [C12b-6 F-4] 수용 — `display`·`changedKeys`로 카드 4영역을 채울 수 있고 프론트 계산이 없다. F-4 500의 카드 자리 문구 뒤 "버튼 없음, 재시도 없음(새로고침으로)"을 한 줄 적으면 완결.
- [C12b-7 F-5] 수용 — `{planVersionId, revision}`. 프론트는 `revision`만 쓴다.
- [C12b-7-2 오류 동작] 수용 — 8개 코드 모두 동작이 있다.
- [C12b-7-3 성공 뒤 순서] 수정 — 4번 "새 `calcRunId`로 F-3"의 호출 지점을 하나로(필수 2).
- [C12b-7-4] 수정 — X-1 B·X-2 A 채택 + 구현을 `revision` 구독으로(위).
- [C12b-8 삭제] 수용. 단 이벤트 타입 파일의 소유 Issue가 순환이다(필수 1).
- [C12b-9 오류 코드] 수용.
- [C12b-10 의존] 수용. 단 `chat/package-info.java` 수정 시점이 늦다(필수 1b).
- [C12b-12 목] 수정 — 필수 3.
- [C12b-13·18 후속 작업] 수정 — 아래 (4).
- [C12b-14 ai-server] 수용 — `AVG` 채움, #21 선행, #23 "보고값 = 보낸 값" 테스트. 소비자 요구 충족.

## (4) 후속 Issue 배치 검토 (gh api로 본문 확인)

본문은 아직 v2를 반영하지 않았다(결정 전이라 정상). 반영할 때 아래 빈틈을 함께 고친다.

| 번호 | 문제 | 제안 |
|---|---|---|
| **#46 / #16 / #34 (필수 1)** | v2 H-9는 A가 #16·#34에서 `MemberLoggedIn/Out`을 **발행**하고 B가 #46에서 **수신**한다. 그런데 #46 paths에 `auth/LoggedIn.java`(타입 파일)가 있고, #46의 선행이 #16·#34다. 발행하는 쪽이 먼저 끝나는데 타입은 나중 Issue가 만든다. 또 B 팀 Issue가 `auth/` 파일을 고친다(moeun CLAUDE.md "다른 팀 코드 고치지 않음") | 타입 record는 **#16(MemberLoggedIn)·#34(MemberLoggedOut)** paths에 두고 #46 paths에서 `auth/...` 항목을 뺀다. #46은 `chat/application/**`, `modulith.md`, `auth/package-info.java` 문장만 다룬다(후자는 A 파일이므로 #34 paths로) |
| **#45 (필수 1b)** | v2 H-6은 `chat/package-info.java`(`plan`·`auth` 추가)와 `backend/CLAUDE.md`를 #45에 둔다. 그러나 #42는 `@SkipRenewal`(auth), #44는 `currentVersionId`(plan)를 이미 쓴다. #45는 #44보다 뒤라 그 전 Issue의 `ModularityTests`가 깨진다. 또 #45 paths(`chat/web`, `chat/application`)에는 `chat/package-info.java`가 없다 | 의존 변경은 **#41**(paths가 `chat/**`라 이미 포함)에서 `{calc, rag, plan, auth}`로 한 번에 바꾸고 `backend/CLAUDE.md` 모듈 표 paths를 #41에 추가한다. #45에서는 뺀다 |
| **#32 (확인)** | `ChatComparisonQuery`·`ChatComparisonView` 추가에 더해 "버전 지정 기준 데이터 조회"(refdata)가 필요하다. v2는 "#78과 공유, 먼저 하는 쪽이 만든다"인데 #78의 선행이 #32라 **실제 순서는 #32가 먼저**다. 그러면 #32가 만든다 | #32 paths에 refdata 파일과 calc 루트 새 타입을 넣고, "만드는 쪽은 #32"로 못박는다. #78 본문에는 "#32가 만든 조회를 쓴다" 한 줄. #32가 이미 가장 큰 Issue라 크기를 A팀이 판단하게 알린다 |
| **#44** | 선행이 #32·#42. v2는 #21도 선행. 또 `currentVersionId`는 #19에서 오므로 #19도 명시가 안전 | 선행에 #21, #19 추가. 수용 기준 snake_case 문장 교체, `changedKeys`·`display`·`applicable` 추가 |
| **#42** | `answerPending`, `conditionChanges`·`rank` 미노출, 복원 50개 수용 기준 없음 | 수용 기준 3줄 추가 |
| **#41** | 수용 기준에 `status=PENDING` 202 응답이 남아 있다(v2는 제거). 오류 표·trim 규칙 반영 | 해당 줄 수정 |
| **#55 (필수 6)** | v2 H-11e는 "목 제거 | B | #55"인데 #55는 `team:A`이고 paths가 `api/`·`mocks/`·`features/auth·input·result·plan`뿐이라 **대화 쪽(`features/chat/**`)이 빠진다.** 선행에도 #52~#54·#45가 없다 | #55 paths에 `frontend/src/features/chat/**`를 더하거나, 대화 목 제거를 B 소유 Issue 한 줄로 분리한다. 선행에 #52~#54, #45 추가 |
| **#51 (필수 2)** | v2 H-11d는 #51이 되돌리기 성공 뒤 "결과 재조회·F-3"을 한다. #54도 F-3을 부른다. **두 곳이 같은 `calcRunId`로 부르면** 앞 설명이 이미 `COMPLETED`일 때 PENDING 재사용이 안 되어 설명이 두 개 생긴다 | F-3 호출은 **#54 한 곳**에서 "결과 화면이 그린 `calcRunId`가 바뀌고 `status=CALCULATED`이면 부른다"(effect 하나)로 한다. #51·#53은 결과 재조회까지만. H-11d·H-11b 문구 수정 |
| **#13 (필수 3)** | 래퍼 수용 기준이 "mocks의 JSON을 돌려준다"뿐이다. v2 목은 `{responses:[{status, headers, body}]}` 배열 형식이라 래퍼가 **상태 코드·헤더·호출 순서**를 처리해야 하고, #12 paths는 `mocks/**`만이라 래퍼(`api/**`)는 #13에 속한다 | #13 수용 기준에 "배열 순서대로, 끝 넘으면 마지막 반복, status 반영" 추가. 요청 키 정의 포함(필수 3) |
| **#52** | F-1 오류별 동작, `answerPending`, 복원 안전장치, 3회 실패 중단이 수용 기준에 없다. #52 paths가 `features/chat/**` 전체라 #53·#54와 겹치지만 선행 순서로 직렬화되어 문제 없음 | 수용 기준에 위 4줄. 폴링 훅이 `answerPending`·`hasPending`을 노출 |
| **#53** | "되돌린 뒤 이전 카드 모두 비활성(프론트 상태)"가 X-1 B면 서버 보장으로 바뀐다. `PLAN_CHANGED`·`STALE`·`NO_PLAN`·422·500 동작, ETF 0% 카드 수용 기준 없음 | 수용 기준 교체·추가. `revision` 구독 문장 |
| **#18** | H-15의 문구표 키에 **조건 4개 라벨**(월 저축액·저축 비중·적금 금리·기한)이 없다 | 필수 4 |
| 나머지(#17·#19·#30·#31·#33·#43·#49·#78) | v2 배치대로 수용. #43은 선행에 #78이 이미 있고 404 규칙도 있다 | — |

## 소비자 쪽에서 꼭 필요한 것

1. **이벤트 타입 소유 Issue 정정**(#16·#34로, #46 paths에서 `auth/` 제거)과 **chat `package-info` 수정을 #41로 이동.** 안 하면 #42·#44에서 `ModularityTests`가 깨지거나 B 팀이 auth를 고쳐야 한다.
2. **F-3 호출 지점 하나(#54)**. 안 하면 되돌리기·적용 뒤 설명이 중복된다.
3. **목 선택 방식과 요청 키 정의.** v2는 "시나리오 선택은 래퍼 구현 몫"이라 했지만, F-5처럼 **같은 요청 키(`POST .../1031/apply`)에 오류 목이 7개**(409×3, 422×2, 404, 500)라 계약이 선택 방식을 정하지 않으면 35개 중 절반을 호출할 수 없다. 최소 정의: (a) 요청 키 = 메서드 + 경로(쿼리 제외). (b) 같은 키의 여러 파일은 개발·테스트 전용 `useMock(파일명)` 호출로 고른다. (c) F-4 목은 서로 다른 `messageId`를 쓴다(정상 1031, not-applicable 1027, etf0 1033 등)로 경로 키만으로 구분한다. 추가 목: `get-messages.200-restore-pending.json`(복원인데 `answerPending: true`, 새로고침 중 보내기 버튼 막기와 복원 안전장치 시험), 그리고 F-4 `get-comparison.200-etf0`는 위 messageId 규칙 반영.
4. **문구표 키 H-15 보강**: 조건 4개 라벨(`changedKeys`·`conditions` 행 라벨). 프론트가 라벨을 지어내지 않게 한다.
5. **폴링 실패 규칙 보강**: "네트워크 오류 또는 5xx"를 "**401 외 모든 실패**(네트워크, 4xx, 5xx)"로. F-2의 `400 MALFORMED_REQUEST`(`afterId` 오류)가 현재 규칙에 없어 1초마다 영원히 반복된다.
6. **#55 팀·범위 정정**(위 표).

## 빼도 되는 것

- F-5 응답 `planVersionId`: 프론트가 안 쓴다(로그·목 식별용이라 v2는 유지). 빼면 `PlanApplyResult` 옮기는 코드가 한 줄 줄지만 비용이 작아 양보 가능.
- F-3 202 응답 `assistantMessageId`: 프론트는 폴링으로 메시지를 받으므로 안 쓴다. PENDING 재사용 확인용으로만 의미가 있어 양보 가능.
- 목 `post-messages.400.json`, `get-comparison.400.json`: 개발 오류라 `INTERNAL_ERROR`와 같은 처리다. 35개에서 2개 줄일 수 있다(유지해도 해는 없음).
- C12b-9의 405·415 행은 프론트가 쓰지 않는다. 표에 남겨도 목은 없으므로 그대로 둔다.

## 남은 반대

- 필수 1(이벤트 타입 소유·package-info 시점)과 필수 2(F-3 단일 호출)는 반영하지 않으면 **수용 불가**에 가깝다. 계약 본문이 아니라 Issue 배치이므로 본문 수정으로 닫힌다.
- 필수 3~6은 수정하면 수용.
