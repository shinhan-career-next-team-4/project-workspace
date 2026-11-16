# 소비자 검토: frontend-api-chat-v1.md (moeun #12-b 대화)

> 관점: 프론트 대화창(B팀, #52~#54·#47·#51), Spring chat이 ai-server를 부르는 F-1·F-3 흐름(#41~#45).
> 근거: `docs/design/contracts/frontend-api-chat-v1.md`, `/tmp/issue12.md`, moeun `ai-server/app/schemas.py`, moeun open Issue #33·#34·#41~#46(gh api로 조회), `docs/decisions.md` D-016·022·033·040·041·051·052·059·062, `open-questions.md` Q-051~055.

## 판정: 수정하면 수용

뼈대(적용 API는 chat 컨트롤러, 값이 아니라 `chatMessageId`로 적용, display 인용, 오류 코드로 분기)는 수용한다. 막히는 곳은 4곳이다.
(1) 질문 대기와 설명 대기를 프론트가 구분할 수 없다(보내기 버튼을 못 정함).
(2) R-5가 이미 열린 #46(이벤트 방식, auth는 chat을 의존하지 않음)과 충돌한다.
(3) D-041 비활성 규칙이 "되돌리기"만 다루고 입력 수정·다른 탭의 변경은 빠졌다.
(4) 목 파일이 응답 1개 = 파일 1개라 PENDING에서 COMPLETED로 넘어가는 폴링을 흉내 낼 수 없다.

## 항목별 의견 (C12b-1~18)

- [C12b-1 엔드포인트 목록] 수용 — F-1~F-5와 "삭제는 엔드포인트 없음"이 Issue #41~#46 분할과 맞는다. 삭제를 프론트가 부르지 않아도 되므로 화면 부담이 없다. F-4는 400 `MALFORMED_REQUEST`(messageId가 정수 아님) 표(C12b-9)에 빠져 있으니 F-4를 더한다.
- [C12b-2 인증·헤더] 수용 — 폴링 401이면 중단하고 로그인 화면으로(FR-AUTH-02). 수정: 폴링의 네트워크 오류·5xx 규칙이 없다. "연속 3회 실패하면 폴링을 멈추고 실패 안내 한 번, 사용자가 다시 질문하면 재개"를 H-11에 적는다. 안 적으면 프론트마다 다르게 만든다.
- [C12b-3 메시지 모양] 수정 — 아래 4가지.
  1. **`status=PENDING`이면 `messageType=null`이라 질문 대기와 설명 대기를 구분할 수 없다.** 새로고침(복원) 뒤에는 어느 것이 보내기 버튼을 막아야 하는지 알 길이 없다(F-1은 `ANSWER_PENDING`, F-3은 안 막는다, R-4). F-3의 대기 행은 `EXPLANATION`이라고 생성 시점에 이미 안다. 수정안: F-3이 만든 PENDING은 `messageType="EXPLANATION"`을 주고 `null`은 질문 대기만 쓴다. 더 단순한 안은 F-2 응답에 `answerPending: boolean`(질문 대기 존재 여부)을 더하는 것이다. 프론트는 `hasPending`(폴링 유지)과 `answerPending`(보내기 막기) 두 값만 본다. 나는 후자를 권한다(분기 문자열 해석이 없다).
  2. `conditionChanges`가 RECALC_RESULT에 실린다. 카드는 F-4의 `conditions`를 쓰므로 프론트는 안 쓴다. 단 ai-server `ConditionChanges`가 지금 7키(`goal_amount`·`held_assets`·`existing_monthly_contribution` 포함, snake_case)라 D-040의 4키·camelCase와 어긋난다. #21(4개로 축소)과 #44(snake→camelCase 변환)가 끝나기 전에는 이 필드를 신뢰할 수 없다. 프론트가 안 쓰므로 **빼는 것을 권한다(빼도 되는 것 참조)**.
  3. `FAILED` 메시지의 `content`는 서버가 문구표로 채운다. 프론트가 문구를 지어낼 일이 없어 좋다. 수용.
  4. `citations[].rank`는 배열 순서와 같아 프론트가 안 쓴다.
- [C12b-3a F-3] 수용 — 같은 `calcRunId`의 PENDING 재사용(R-4)은 React 개발 모드 effect 이중 실행에 필요하다. 수정: F-3의 `NOT_FOUND`·`400`·`500` 때 프론트가 할 일이 없다. 제안은 "설명 자리에 아무것도 안 그린다(대화창에 오류를 쓰지 않는다). 404면 결과 화면을 다시 불러온 뒤 한 번만 재시도"다. 그리고 F-3은 **적용·되돌리기 뒤에 새로 받은 `calcRunId`로** 불러야 한다는 점을 H-11에 못박는다(옛 id는 설명이 옛 계획 기준이 된다).
- [C12b-4 F-1] 수용 — 수정 3가지.
  1. 409 `ANSWER_PENDING`을 받았을 때 동작이 없다. 제안: 보내기 버튼 비활성 + 폴링 재개(다른 탭이 만든 대기일 수 있음). 입력창의 글은 지우지 않는다.
  2. `text`는 UTF-16 길이(JS `string.length`) 기준으로 2000을 센다고 못박는다(ai-server `max_length`는 코드포인트 기준이라 서버가 더 느슨해 충돌은 없지만, 프론트 글자 수 표시와 서버 기준이 같아야 한다). 프론트는 `maxLength=2000`으로 미리 막으므로 서버 오류는 방어선이다.
  3. 202 응답의 `userMessageId`는 프론트가 사용자 말풍선을 즉시 그리는 키라 필요하다(폴링 upsert와 중복 방지). 수용.
- [C12b-5 F-2 폴링] 수용 — upsert와 `afterId = 가장 작은 PENDING id − 1` 규칙으로 PENDING에서 COMPLETED/FAILED로의 전이가 빠짐없다. 수정: `hasPending`은 응답 목록 밖의 PENDING도 센다고 되어 있으나, 프론트가 `hasPending=false`를 받고도 가지고 있는 메시지에 PENDING이 남아 있으면(오래된 정리로 이미 FAILED가 된 경우는 같은 응답에 들어온다) 계약상 불가능해야 한다. 이를 "`hasPending=false`이면 응답 시점에 서버의 모든 PENDING이 이미 정리·완료됐으므로 프론트는 가진 PENDING을 모두 이 응답의 값으로 덮어쓴 상태"라고 한 줄 보장으로 적자(서버가 정리 후 조회하므로 성립).
- [C12b-6 F-4] 수용 — 숫자와 문자열이 모두 서버 값이라 프론트가 빼기·반올림할 일이 없다(CP-04/05). 수정:
  1. ETF 0%(`savingsRatioPct=100`)면 시나리오가 AVG 하나다. 카드가 1개·3개를 모두 그려야 하므로 목에 ETF 0% 응답을 하나 더 둔다.
  2. `diff.byScenario[].achievementChange` 4값에 대응하는 카드 문구는 프론트가 문구표에서 enum으로 찾는다. 문구표 키 목록을 #18·#53에 명시해야 한다.
  3. **어느 비교 카드에 F-4를 부르나가 비어 있다.** 복원 때 RECALC_RESULT가 여러 개면 모두 부르면 재계산이 그만큼 돈다. 제안: 가장 최근 RECALC_RESULT만 F-4로 카드를 그리고, 이전 것은 본문(`content`)만 보이고 카드는 접거나 "이전 결과" 표시(버튼 비활성)로 둔다. D-041의 "이전 결과의 버튼은 비활성"과 맞고 F-4 호출 수가 1이다. 이전 카드를 펼칠 때만 F-4를 부르는 방식도 가능.
  4. **새 RECALC_RESULT가 폴링으로 도착하면 프론트가 이전 카드의 적용 버튼을 즉시 비활성으로 바꾼다**(F-4를 다시 안 부름). 지금 문서는 "`applicable`을 다시 받지 않고 C12b-7-4 규칙으로 버튼만"이라고만 해서 이 경우가 비어 있다. H-11에 규칙으로 넣는다: 버튼 활성 = (이 메시지 id가 가진 메시지 중 최대 RECALC_RESULT id) AND `applicable` AND (barrier보다 큼, R-2).
- [C12b-7 F-5] 수용 — `chatMessageId`로 적용(D-033)과 `expectedRevision` 한 곳 출처(R-8)가 좋다. 수정: 오류 표(C12b-7-2)에 `UNAUTHENTICATED`(로그인 화면)와 `INTERNAL_ERROR`/네트워크 실패(토스트 "적용하지 못했어요", 버튼은 그대로 활성, 재시도 가능)가 없다. `MALFORMED_REQUEST`는 개발 오류라 일반 실패 처리로 묶는다. 또 `NO_PLAN` 이동은 프론트가 입력 화면으로 갈 때 대화창 상태를 어떻게 하는지만 정하면 된다(그대로 둠).
- [C12b-7-3 성공 뒤 순서] 수용 — D-041(전체 갱신, 10초 토스트)과 D-062(`status=ALREADY_EXCEEDED`면 F-3 안 부름)와 일치. 한 가지: 4번에서 결과 화면을 다시 불러올 때 `calcRunId`가 PLAN 기록 비동기(`PlanChanged` 리스너) 때문에 비어 있을 수 있다. 요구 4가 "조회가 기록이 없으면 계산·기록한다"로 해결하지만, 리스너와 조회가 동시에 같은 (버전, PLAN) 행을 만들면 중복될 수 있어 **(plan_version_id, run_type=PLAN) 유일 제약 또는 멱등 INSERT**를 H-8/#29에 요구한다(제공자 몫이므로 A팀 확인).
- [C12b-7-4 되돌리기 뒤 비활성] 수정 — R-2 참조.
- [C12b-8 대화 삭제] 수정 — R-5 참조(#46과 충돌).
- [C12b-9 오류 표] 수용 — 프론트가 `code`만 보고 고를 수 있다(title 해석 없음). 수정: F-4에 400을 더하고, F-1에 `INTERNAL_ERROR`(ai 호출은 비동기라 F-1 자체는 거의 안 나지만 DB 오류 가능)를 더한다. 코드마다 프론트 동작표를 한 곳(C12b-7-2의 확장판)에 모으면 목 파일과 일대일이 된다.
- [C12b-10 모듈 의존] 수용(R-1) — plan → chat 없음, #33 본문도 "chat 쪽 컨트롤러가 PlanApplyService를 호출"이라 이미 같다. #45 선행(#33, #44)과도 맞다.
- [C12b-11 시간값·PENDING] 수용(R-3, R-9). 프론트 상수는 폴링 간격 1초 하나만 가진다. 안전 상한이 없다는 점은 서버가 60초 안에 FAILED로 만든다는 전제라 서버가 이를 지키지 못할 때(서버 정지) 폴링이 끝나지 않는다. C12b-2의 "연속 실패 3회 중단"이 이 구멍도 막는다.
- [C12b-12 목] 수정 — 아래 "꼭 필요한 것" 5·6.
- [C12b-13 #12-a 요구] 수용 — 요구 4(현재 계획 응답에 `revision`·`calcRunId`·`result.status`)와 5가 프론트에 직접 필요하다. 요구 8은 R-5에서 바꾼다.
- [C12b-14 ai-server 영향] 수정 — "ai-server 영향 없음"은 맞지 않는 곳이 있다. (a) `ConditionChanges`는 7키(D-040 위반), #21 선행. (b) `ChatRequest.baseline_scenario`는 필수인데 F-1이 `planContext: null`(계획 없음)로 부를 때 값의 출처가 없다. Spring이 `AVG`를 채운다고 계약에 한 줄 적는다(그렇지 않으면 NO_PLAN 질문이 422로 실패해 `FAILED`가 된다). (c) `history[].role`은 소문자(`user`/`assistant`)이고 F-2는 대문자라 Spring이 변환한다(프론트 영향 없음, 메모).
- [C12b-15 코드 차이] 수용 — X-7은 (a)와 함께 #21·#44 선행으로 올린다. X-2는 R-5에서 바뀐다.
- [C12b-16 Q-051~055] 수용 — Q-051 B안(초과 계획이면 프론트가 대화창 첫 줄에 `chat.alreadyExceeded`를 그림, 저장 안 함)이면 API 변경 없음. 단 그 문구를 프론트가 그리려면 **F-2 복원 응답과 별개로 결과 화면의 `status`를 알아야** 하므로 요구 4로 충분하다. Q-053은 `display`만 바뀌어 영향 없음. Q-052·054·055는 영향 없음.
- [C12b-17 수용 기준 대응] 수용.
- [C12b-18 후속 작업] 수정 — Issue 번호(조회 결과, 아래 "번호 확인 필요 항목 제안")를 채운다.

## R-1~R-10 의견

- **R-1 적용 위치(chat → plan) — 수용.** B·D는 순환, C는 D-033 위반. #33·#45 본문이 이미 이 방향이다. 주의: plan 공개 API 시그니처에 chat·calc 타입 금지(문서에 적힘). `ModularityTests`로 고정한다.
- **R-2 되돌리기 뒤 비활성 — 수정.** 프론트 `undoBarrierId`는 1차로 수용하되 범위를 넓히고(아래) 서버 보강안을 하나 얹는다.
  1. 프론트: `undoBarrierId`를 "되돌리기" 한정이 아니라 **내 계획이 바뀐 모든 순간**(되돌리기, 입력 수정 저장, PLAN_CHANGED로 다시 불러옴, 로그인 직후는 대화가 비어 해당 없음)에 갱신한다. 이름은 `planChangeBarrierId`. 입력 수정 뒤에는 기준 버전이 달라 서버 검사 9가 막지만, 버튼이 살아 있다가 누를 때 409가 되는 것보다 즉시 비활성이 낫다. D-041 문구("되돌린 뒤")보다 넓은 해석이므로 결정 기록에 한 줄이 필요하다.
  2. 서버 보강(새로고침 틈 제거): F-4 `applicable`과 F-5 검사에 "`chat_message.created_at` ≥ plan의 마지막 변경 시각"을 더한다. plan이 변경 시각(적용·되돌리기·입력 저장마다 갱신)을 공개하면 된다. 되돌리기가 `plan_version`을 새로 INSERT하는 안보다 #33의 "직전 1개" 의미를 안 건드린다. 없으면 프론트 규칙만으로 가고 틈은 Q로 남긴다.
  3. 반대 안(되돌리기=새 버전 INSERT)은 `previousVersionId` 체인이 길어져 "직전 1개로" 규칙·#33과 충돌하므로 비권장.
- **R-3 시간 임시값 — 수용.** 폴링 1초(PENDING일 때만), 연결 2초·응답 30초·정리 60초. 프론트 상수는 하나. 2초안은 체감 지연만 늘어 이점이 작다. 전제: C12b-2의 연속 실패 중단 규칙을 넣을 것.
- **R-4 ANSWER_PENDING 범위·F-3 중복 — 수정.** 정책은 수용(설명은 화면이 부르는 것이라 막으면 설명이 빠진다). 단 프론트가 구분할 신호가 없다(C12b-3 항목 1). `answerPending`을 더하거나 F-3 PENDING에 `messageType=EXPLANATION`을 준다. 같은 `calcRunId` PENDING 재사용은 수용.
- **R-5 대화 삭제 호출 방식 — 수정(반대 일부).** 동기여야 한다는 요구(로그인 직후 F-2가 이전 대화를 보면 안 됨)는 맞지만, 직접 호출(auth → chat)은 열린 #46과 충돌한다. #46: "auth가 이벤트(LoggedIn, LoggedOut)를 발행하고 chat이 받아 삭제", 완료 조건 "auth가 chat을 의존하지 않고 이벤트로 푼다", paths에 `auth/LoggedIn.java`. 수정안: **이벤트는 그대로 두되 동기 리스너를 쓴다.** auth가 로그인 성공·로그아웃 처리에서 `LoggedIn`/`LoggedOut`을 발행하고(타입은 auth 루트), chat은 `@ApplicationModuleListener`(비동기)가 아니라 일반 `@EventListener`(같은 스레드, 응답 전에 끝남)로 삭제한다. 결과: 방향은 chat → auth(`chat`의 allowedDependencies에 `auth` 추가), auth는 `{}` 유지, 순환 없음, 로그인 응답 전에 삭제 완료. 비용은 `chat` 의존 하나. 그러면 C12b-13 요구 8·C12b-15 X-2·H-9의 "auth package-info에 chat 추가"는 "chat package-info에 auth 추가, auth는 이벤트 발행"으로 바뀌고 #46 본문 수정은 "리스너는 동기"와 "chat → auth 허용" 두 줄이다. 이벤트 두 번 도착 시 멱등은 `DELETE`가 원래 멱등이라 만족. 제공자(A팀 auth)가 `LoggedIn` 발행 시점을 "쿠키 응답을 만들기 전"으로 보장해야 한다.
- **R-6 display 포함·그래프 제외 — 수용.** 프론트가 원→만원 반올림을 재구현하지 않아 CP-04·FR-AI-02 위반 위험이 없다. 그래프 제외(Q-039 3번)도 수용. 이 응답으로 카드 4영역(현재 조건·바꾼 조건·시나리오별 세후 자산·목표 대비·차이)을 모두 채울 수 있다. 하나만 확인: 카드에 "무엇이 바뀌었나"를 강조하려면 `conditions.current`와 `conditions.changed`를 비교해야 하는데, 프론트는 **값 동등 비교**(같다/다르다)만 하고 차이를 계산하지 않는다. 더 안전하게는 F-2 메시지의 `conditionChanges` 키 목록을 쓰는데 이를 뺀다고 제안한 터라(빼도 되는 것), 대신 F-4에 `changedKeys: ["monthlySavingAmount"]`(배열, 계산 아님)를 더하는 쪽을 제안한다.
- **R-7 text 길이 오류 — 수용.** `OUT_OF_RANGE` + `min 1, max 2000, unit "CHAR"`. 프론트는 `reason`+`field`로 분기하고 `unit`은 표시용이라 새 값이 와도 문제없다. 모르는 `unit`은 무시 원칙 유지. 길이 기준(UTF-16)만 명시.
- **R-8 expectedRevision 출처 — 수용.** 출처 하나(프론트 계획 상태)가 어긋남이 적다. F-4에 `planRevision`을 두면 F-4 시점과 적용 시점 사이에 입력 수정이 끼었을 때 옛 revision을 보내 409가 아닌 잘못된 성공이 날 수 있다. 전제: #12-a의 현재 계획·입력 저장·적용·되돌리기 응답이 모두 `revision`을 준다(요구 4·5).
- **R-9 오래된 PENDING 정리 — 수용.** 읽을 때 정리가 스케줄러보다 단순하고, F-2가 정리 후 조회하므로 같은 응답에 FAILED가 실려 프론트가 추가 호출 없이 실패 안내를 그린다. GET이 쓰기를 한다는 점(`@SkipRenewal` 폴링이 DB를 갱신)은 데모 범위에서 허용.
- **R-10 PLAN_CHANGED(8)를 STALE_COMPARISON(9)보다 먼저 — 수용.** 프론트 동작이 큰 쪽(전체 다시 불러오기)을 먼저 알려 주는 게 맞다. 보충: 검사 3의 `STALE_COMPARISON`(가장 최근이 아님)과 9의 `STALE_COMPARISON`(기준 버전 ≠ 현재)은 같은 코드·같은 프론트 동작(버튼 비활성 + 토스트)이라 구분이 필요 없다. 그래서 코드가 하나여도 좋다. 9는 revision이 같은데 기준 버전만 다른 경우라, 프론트가 입력 수정 직후 새 revision을 이미 받은 상황에서 나온다(R-2의 1번으로 대부분 사전에 막힌다).

## 번호 확인 필요 항목 제안 (gh api open Issue 조회 결과)

| 초안 | 제안 |
|---|---|
| H-3 F-1·F-2 컨트롤러·서비스 | F-1은 **#41**, F-2는 **#42**(#41과 #42에 나눠서). `@SkipRenewal`은 #42, 선행 #34 |
| H-6 F-5 chat 컨트롤러·서비스 | **#45** (선행 #33, #44) |
| H-7 PlanApplyService·예외 | **#33**(PlanApplyService와 되돌리기, 본문이 이미 chat이 호출한다고 적음). 입력 저장의 `revision` 반환은 **#19** |
| H-8 calc 공개 API(`calcRunId→planVersionId`, 재계산+display) | **#29**(calc_run 기록·결과 조회 서비스)와 **#32**(CalcComparison·display). F-4가 쓰는 부분은 #44가 호출 |
| H-9 로그인·로그아웃 삭제 | **#46**(대화 삭제, 이벤트 방식이 이미 적힘), 로그인 **#16**, 로그아웃 **#34**. R-5 수정안이면 #46 본문 수정 |
| H-10 전역 오류 | **#17**(전역 오류 형식), 401 엔트리 포인트는 **#16**(JWT)·**#34** |
| C12b-13 요구 4 현재 계획 응답(`revision`, `calcRunId`, `result.status`) | **#30**(결과 보기), **#31**(현재 계획 조회) |
| C12b-13 요구 6 `calcRunId → plan_version_id` | #29 |
| H-11 프론트 | **#52**(대화창·폴링), **#53**(비교 카드·적용 버튼), **#54**(설명), **#51**(되돌리기 토스트), **#49**(D-062 분기). 목 제거는 #55 |
| planContext 생성 | **#78** (참고) |

## 소비자 쪽에서 꼭 필요한 것

1. **질문 대기 신호**: F-2에 `answerPending: boolean`(또는 F-3 PENDING에 `messageType=EXPLANATION`). 없으면 새로고침 뒤 보내기 버튼을 정할 수 없다.
2. **오류 처리 표 완성**: F-1 `ANSWER_PENDING`(버튼 비활성+폴링 재개), 폴링 네트워크·5xx(3회 중단), F-3 404·5xx(조용히 무시, 한 번 재시도), F-4 500(카드 자리 문구), F-5 500·네트워크(토스트, 버튼 유지). C12b-7-2를 모든 엔드포인트로 확장한다.
3. **버튼 활성 규칙을 한 줄로**: 활성 = 가진 메시지 중 최대 RECALC_RESULT id이고, F-4 `applicable=true`이며, 마지막 `planChangeBarrierId`보다 큰 id. 새 RECALC_RESULT 도착 시 이전 카드 즉시 비활성.
4. **F-4 호출 대상**: 가장 최근 RECALC_RESULT만(복원 시 N번 재계산 방지).
5. **목 파일 순서 지원**: "요청 키 → 파일 1개"로는 PENDING → COMPLETED를 못 그린다. 키 하나에 **응답 배열**(호출 순서대로)을 허용한다. 추가로 필요한 파일: F-3 PENDING 재사용(같은 id 202), F-2 `explanation-pending`, `out-of-scope`, 복원(과거 RECALC 둘 이상+이전 카드), F-4 `500`·ETF 0% 한 시나리오·`400`, F-5 `409-no-plan`·`422-field-not-changeable`·`500`, F-1 `400`·`500`, 설명 FAILED(`get-messages.200-failed`에 EXPLANATION 맥락 추가).
6. **ai-server 정합**: `ConditionChanges`를 4키(D-040)로 줄이는 #21과 camelCase 변환 위치(#44)를 F-2 `conditionChanges`가 노출되기 전에 끝내거나 이 필드를 응답에서 뺀다. F-1 `planContext: null`일 때 `baseline_scenario` 값(AVG)을 Spring이 채운다고 계약에 적는다.
7. **R-5의 #46 정합**: 동기 `@EventListener`(chat → auth) 방식으로 바꾸거나, #46 본문을 직접 호출 방식으로 고치고 `ModularityTests` 조건(auth → chat 허용)을 바꾸는 결정이 필요하다. 이벤트 방식을 권한다.

## 빼도 되는 것

- F-5 응답의 `previousVersionId`, `planVersionId`, `undoAvailable`: 프론트는 `revision`만 쓴다(`undoAvailable`은 항상 `true`). 되돌리기 API가 `revision`만 받는다면 셋을 뺀다. 목 파일과 서버 코드가 줄어든다. (되돌리기 API 모양은 #12-a. 그쪽이 `previousVersionId`를 요구하면 유지.)
- F-2 `citations[].rank`: 배열 순서로 충분.
- F-2 `conditionChanges`: 카드는 F-4의 `conditions`를 쓰고 값의 표기 일치도 어긋난 상태(snake_case 7키). 강조가 필요하면 F-4 `changedKeys`로 대신.
- F-4 `messageId` 에코: URL에 이미 있다(단 목 파일 식별용으로 두는 것은 무방).
- F-1 `status: "PENDING"`(202 응답): 항상 PENDING.
- `retry_of_message_id`·`calcRunId`(메시지 모양에 안 넣기로 한 것)는 현행대로 제외, 문서의 판단에 동의.
