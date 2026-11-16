# 프론트 ↔ Spring 대화 API 계약 합의안 (moeun #12-b)

> **결정 대기.** 쟁점 X-1 → Q-056, 쟁점 X-2 → Q-057로 open-questions에 올라간다. 결정되면 이 줄을 "결정 완료 (날짜): X-1→D-xxx, X-2→D-xxx"로 바꾸고 v3을 최종본 `frontend-api-chat.md`로 확정한다.

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 4단계(재검토 반영) 마무리, 5단계(사람에게 넘기기) 준비.
> - 계약 본문: `frontend-api-chat-v3.md` (쟁점은 본문에 추천안을 임시로 적고 `⟵ 쟁점 X-n` 표시)
> - 입력: `frontend-api-chat-v1.md`, `review-frontapi-chat-v1-provider.md`(A팀), `review-frontapi-chat-v1-consumer.md`(B팀), `frontend-api-chat-v2.md`, `review-frontapi-chat-v2-provider.md`(A팀 재검토), `review-frontapi-chat-v2-consumer.md`(B팀 재검토)
> - **에이전트는 결정하지 않았다.** 아래 "사람이 정할 쟁점" 2개만 답해 주면 v3을 최종본으로 확정할 수 있다. 재검토는 이번이 마지막이다(더 반복하지 않음).
> - 이름 겹침 주의: 계약 본문의 "코드 차이 X-n"(C12b-15)과 여기의 "쟁점 X-n"은 다른 번호다.

## 합의된 것 (그대로 구현 가능) — 75항목

전체 표는 `frontend-api-chat-v3.md` "합의 목록". 묶어서 요약한다.

| 묶음 | 내용 | 근거 |
|---|---|---|
| 범위·원칙 | 엔드포인트 5개(F-1 질문, F-2 폴링·복원, F-3 설명, F-4 비교 조회, F-5 적용), 삭제용 엔드포인트 없음. 프론트는 Spring만, `memberId`는 JWT subject·Spring Security 타입으로만, 숫자는 Spring `display`, 적용은 `messageId`로. `condition_changes`는 camelCase 저장 | 양쪽 (1, 4, 41, 54) |
| 인증·배포 | `SameSite=Lax` 이상 필수, **프론트·Spring 같은 사이트**(Vite 프록시). F-2만 `@SkipRenewal`(인터셉터 또는 필터 + `HandlerMappingIntrospector`) | 제공자, 소비자 (3, 63, 68) |
| 메시지·F-1 | PENDING 자리표시 `ANSWER`/`EXPLANATION` 고정, 화면에는 `messageType=null`. `conditionChanges`·`rank` 미노출. trim·UTF-16 1~2000, `ANSWER_PENDING`은 질문 대기만, 계획 없으면 `baselineScenario=AVG`. 202 `{userMessageId, assistantMessageId}` | 양쪽 (6, 8, 9, 11~17, 47) |
| F-2 폴링 | `afterId` 규칙·복원 50개·upsert, `hasPending`·`answerPending`, `hasPending=false` 보장, 복원 안전장치 1회(**폴링이 멈추거나 F-1·F-3까지**), **401 외 실패 연속 3회 중단**, 쓰기 트랜잭션 | 양쪽 (5, 7, 10, 18~20, 62) |
| F-3 설명 | `findPlanRun` 404 일원화, 같은 `calcRunId` PENDING 재사용, 202 본문 `{}`, **호출 지점은 #54 하나**(결과 `calcRunId`가 바뀌고 `CALCULATED`면), 초과 계획은 부르지 않음(D-062) | 양쪽 (14, 45, 46, 60, 65) |
| F-4 비교 | 당시 기준 재계산(**범위 검사 없이 타입 변환만, 실패 500, 422 없음**), `display` 포함·그래프 제외, `changedKeys`(**순서 보장 없음**), `applicable`, 최신 RECALC만 자동 호출, 500 카드는 버튼·재시도 없음. calc 루트 `ChatComparisonQuery`(display `Map`) | 양쪽 (21~27, 50, 58, 59) |
| F-5 적용 | 안 A(chat 컨트롤러 → plan 공개 서비스), 응답 **`{revision}`**, 검사 순서 0~10, 0행 롤백, 검사 9 잠금 없음, 오류별 프론트 동작 8개, 성공 뒤 순서, PLAN 기록 중복 무해 | 양쪽 (28~34, 52, 53) |
| 대화 삭제 | auth `MemberLoggedIn`/`MemberLoggedOut` 발행 + chat 동기 `@EventListener`, 한 문장 일괄 DELETE, 0행이면 citation 미저장, 만료 토큰 로그아웃 401. chat → auth 한 방향, auth `{}` | 양쪽 (35~38) |
| 오류 | C3-1 형식, 모든 오류에 `code`, Spring 기본 예외 매핑, 모듈 예외 `config` 상속 금지, `unit: CHAR`. **500은 전역 `INTERNAL_ERROR`, `/internal/calc`만 컨트롤러 `@ExceptionHandler`에서 `CALC_FAILED`**(코드 차이 X-15) | 제공자 (39, 40, 51, 57) |
| 시간 값 | 폴링 1초, 연결 2초·응답 30초, 오래된 PENDING 60초(읽을 때 정리), 가상 스레드 | 양쪽 (42~44) |
| 목 | 응답 배열 형식 35개, **선택 방식 계약**(키 = 메서드+경로, `useMock(파일명)`, 배열 순서·끝 반복·`status` 반영), F-4 messageId 분리(1031/1027/1033), `restore-pending` 추가, REST Docs와 같은 예시 값 | 양쪽 (48, 49, 61, 64) |
| ai-server | 새 필드 없음, `ConditionChanges` 4키(#21) 선행, 보고값=보낸 값 테스트(#23) | 양쪽 (55) |
| 쟁점 조건부 구현 | (X-1 B면) #33은 plan 먼저 읽어 `NOTHING_TO_UNDO`/`PLAN_CHANGED` 구분, `source` 주석·`db/tables.md` 1줄. (X-2 A면) #53이 `revision` 구독 한 곳(최초 로드 제외) | 제공자, 소비자 (66, 67) |
| Issue 배치 | `ChatComparisonQuery`·버전 지정 refdata는 #78, #44 선행 #21·#78·#19, 입력 저장 `revision`은 #30, X-10에 #19, 이벤트 record는 #16·#34, chat 의존 변경은 #41, #55 정정, #18 조건 라벨 키 | 양쪽 (23, 69~75) |

**재검토에서 합의로 처리한 것** (사람이 보고 이견이 있으면 말해 주면 된다)
- **500 코드 이름(제공자)**: #17 수용 기준은 500 `CALC_FAILED`, 이 계약은 `INTERNAL_ERROR`라 전역 advice 하나로 둘을 만족할 수 없었다. 전역은 `INTERNAL_ERROR`, `/internal/calc`는 이미 422 `minDisplay`를 처리하는 그 컨트롤러 안에서 `CALC_FAILED`. 전역 advice에 경로 분기를 넣지 않는다.
- **F-4 재계산의 검증(제공자)**: F-4가 범위 검사를 하면 계약에 없는 422가 프론트로 나간다. 재계산은 "그때 값 재현"이므로 타입 변환만 하고, 범위 거절은 F-5 한 곳.
- **`changedKeys` 순서(제공자)**: `jsonb`는 키 순서를 보존하지 않아 "표 순서"는 구현이 틀리기 쉽다. 두 안 중 제공자 권장(순서 보장 없음, 코드 0줄)을 택했다. 프론트는 집합으로 쓰고 행 순서는 `conditions`의 고정 4키로 그린다.
- **`ChatComparisonQuery` 위치(배치 충돌)**: 제공자는 #78, 소비자는 #32(+ #78은 "가져다 씀")를 제안했다. 둘 다 "v2의 '먼저 하는 쪽'은 #78 선행에 #32가 있어 성립하지 않는다"는 같은 문제를 짚었다. calc·refdata는 A팀 영역이고 #32 paths에 refdata가 없으며 수용 기준이 이미 20개라 **제공자안(#78)을 채택**했다. #78이 커지면 A팀이 같은 선행으로 나눈다(재량).
- **F-3 호출 지점(소비자)**: #51·#54가 각각 부르면 설명이 중복된다. #54 한 곳의 effect로 모았고, 404 재시도도 같은 지점으로 흡수했다.
- **양보 가능 필드 축소(소비자 제안, 제공자 이견 없음)**: F-5 응답 `planVersionId`, F-3 응답 `assistantMessageId`를 뺐다. 목 `post-explanations.seq-reuse.json`도 함께 뺐다. 목 400 두 개(F-1·F-4)는 "유지해도 해 없음"이라 유지했다.
- **#55 소유 팀**: #55는 `team:A`인데 대화 목 제거(`features/chat/**`, B팀 파일)를 넣어야 한다. 계약은 "paths·선행 추가"까지만 정하고, `team:common`으로 바꿀지 B팀 Issue로 한 줄 분리할지는 **두 팀이 확인**한다(H-11e). 개발 차단은 아니다(3주차 통합 작업).

## 사람이 정할 쟁점

두 쟁점 모두 **양쪽 팀과 기획이 같은 안을 지지한다**(X-1 B, X-2 A). 그래도 사람에게 올리는 이유: 쟁점 X-1은 `db/erd.md` Q4-c에 적힌 되돌리기 방식(포인터 교체)을 바꾸고, 쟁점 X-2는 D-041의 적용 범위를 넓히는 새 화면 정책이라서다. 둘 다 **#12-b 계약 문서 머지를 막지 않는다.** v3 본문에는 추천안이 임시로 적혀 있고, 다르게 정하면 `⟵ 쟁점 X-n` 표시가 붙은 줄만 바꾼다.

### 쟁점 X-1. 되돌리기 뒤 "되돌리기 전 비교"의 비활성을 누가 보장하나 (R-2, D-041) → **Q-056**

- **문제**: 되돌리기가 포인터만 바꾸면(ERD Q4-c) 되돌린 뒤 `current_version_id`가 예전 기준 버전과 다시 같아진다. 대표 흐름은 **비교(기준 V1) → 적용(V2) → 10초 안에 되돌리기**. 이때 방금 적용한 그 비교가 "가장 최근 RECALC_RESULT이면서 기준 버전 = 현재"가 되어, 새로고침하면 F-4 `applicable=true`, F-5 성공이 된다. D-041("되돌리기 뒤 이전 결과 버튼은 비활성")을 서버가 지킬 수 없다.
- **제공자 의견**: B 권장, A도 수용 가능(데이터는 안전), C 반대. B의 SQL은 `previous_version_id = NULL`로 두므로 되돌리기는 여전히 1단계이고 `plan_version`에 부모 컬럼이 없어 체인이 생기지 않는다. #33 수용 기준이 그대로 참. 구현 메모: plan을 먼저 읽어 `NOTHING_TO_UNDO`/`PLAN_CHANGED`를 구분, `source` 주석은 "복사한 원본의 경로"로(CHECK 변경 없음). C는 `plan` 컬럼 추가·모든 UPDATE 경로 수정이 필요하고 시각과 커밋 순서가 달라 보장이 약하다.
- **소비자 의견**: B 동의. v1의 반대("체인이 길어진다")는 SQL을 잘못 읽은 것이라 철회, 자기 안 C도 철회. B면 프론트가 id를 기억하지 않아 가장 싸다.
- **기획 의견**: B. 서버 한 곳(#33)의 INSERT 1문장으로 D-041이 새로고침과 무관하게 지켜지고, 스키마 변경이 없으며, 프론트 상태가 하나 줄어 주니어 팀이 만들 것이 가장 적다.
- **선택지**
  - A) 프론트만: 포인터 교체 유지. 프론트가 `revision` 변경 시점의 최대 메시지 id(`planChangeBarrierId`)를 기억하고 그 이하 버튼을 끈다. (영향: 서버 변경 없음. 새로고침하면 barrier가 사라져 되돌리기 전 비교가 다시 활성으로 보인다. 눌러도 계획 데이터는 틀리지 않음 — D-041 화면 규칙 위반만)
  - B) 되돌리기 = 직전 버전 복사 INSERT + 포인터 이동(`previous_version_id = NULL`, `revision + 1`). (영향: #33 INSERT 1문장·테스트 1건(약 0.25일), 되돌릴 때마다 `plan_version` 1행 + `calc_run(PLAN)` 1행, ERD Q4-c·`schema.sql` 주석·`db/tables.md` 1줄(코드 차이 X-14). 스키마 변경 없음. 되돌린 결과가 "같은 버전 id"가 아니라 "같은 내용의 새 id"가 된다)
  - C) 시각 비교: 포인터 교체 유지 + `plan`에 마지막 변경 시각, F-4·F-5가 `calc_run(CHAT).created_at`과 비교. 프론트 barrier도 유지. (영향: `ALTER TABLE plan` + 엔티티·ERD·`tables.md`, 모든 plan UPDATE 경로 수정, 시각·커밋 순서 경계 문제. 양쪽 모두 반대)
- **추천: B.**
- 결정에 따라 바뀌는 줄: v3 C12b-6 `applicable` 아래 문장, C12b-7-4 "서버" 문단·마지막 문단, C12b-13 요구 5, 코드 차이 X-14, H-7·H-11b.

### 쟁점 X-2. D-041의 "되돌리기 뒤 비활성"을 "내 계획이 바뀐 모든 순간"으로 넓히나 → **Q-057**

- **문제**: D-041은 "되돌리기 뒤 대화창의 이전 결과 버튼은 비활성"만 적었다. 입력 수정 저장이나 다른 탭 변경(`PLAN_CHANGED` 재조회) 뒤의 이전 비교는 서버가 이미 거절한다(F-4 `applicable=false`, F-5 `STALE_COMPARISON`/`PLAN_CHANGED`). 남는 것은 **화면이 버튼을 미리 끄는지, 사용자가 눌러서 409 토스트를 본 뒤 끄는지**다.
- **제공자 의견**: A 수용. 서버 영향 없음(어느 안이든 검사 9·`applicable`이 막는다). D-041 문장을 넓히는 것이라 결정 기록이 필요하다.
- **소비자 의견**: A 동의. 단 구현은 "네 곳에서 함수 호출"이 아니라 **#53이 계획 상태의 `revision`을 구독해 한 곳에서 끄기**(최초 로드 제외). 되돌리기(#51)·입력 저장은 A팀 코드라, 함수 호출 방식이면 팀 경계를 넘는다.
- **기획 의견**: A. D-041의 앞 문장 "대화 비교의 기준은 항상 내 계획"을 화면에 그대로 옮긴 것이고, 소비자 구현안이면 비용은 구독 한 곳이다. v3 본문은 소비자 구현안으로 적었다.
- **선택지**
  - A) 넓힘: 대화 적용·되돌리기·입력 수정 저장·`PLAN_CHANGED` 재조회 때(= `revision`이 바뀔 때) 그때 가진 모든 적용 버튼을 끈다. (영향: #53 `revision` 구독 한 곳. 사용자가 눌러서 오류를 보는 일이 없다. D-041에 보충 한 줄(D-번호))
  - B) D-041 문장대로: 되돌리기와 대화 적용 성공 직후만 끈다. 입력 수정 뒤 이전 비교는 활성으로 보이다가 누르면 `STALE_COMPARISON` 토스트 + 비활성. (영향: 결정 변경 없음. #53 구독이 "되돌리기·적용으로 바뀐 경우"를 구분해야 해 오히려 조건이 하나 는다)
- **추천: A.**
- 결정에 따라 바뀌는 줄: v3 C12b-6 "버튼 활성 한 줄"의 셋째 조건, C12b-7-4 "프론트" 문단, H-11b.
- 쟁점 X-1과의 관계: X-1이 B면 A안은 "revision 바뀌면 버튼 전부 끔" 하나로 끝난다. X-1이 A면 같은 구독 지점에서 barrier id도 기억해야 한다.

## 후속 작업

> D-058: 각 moeun Issue **본문(수용 기준·변경 범위·선행)** 에 반영한다. 댓글로 덧붙이지 않는다. 새 Issue는 없다(모두 기존 Issue에 합침).
> 번호 출처: 양쪽 재검토자가 `gh api`로 조회한 moeun Issue 본문. 이 단계에서 다시 조회하지 않았다.
> 쟁점 의존 표시: **(X-1)**·**(X-2)** 가 붙은 줄은 결정 뒤 반영한다. 나머지는 지금 반영해도 된다.

| H-번호 | 내용 | 팀 | 대상 moeun Issue | 선행 변경 |
|---|---|---|---|---|
| H-1 | 최종본의 B 부분을 `docs/api/frontend-api.md`로, 목 35개(응답 배열, F-4 messageId 1031/1027/1033)를 `frontend/src/mocks/chat/`에 | 공통 | #12 | — |
| H-2 | 리스너: PENDING 아니면 미호출, `AND status='PENDING'` 갱신, 0행이면 citation 미저장, camelCase 저장, `AVG` 채움, `history.role` 소문자, 연결 2초·응답 30초, 실패 → `chat.failed`, 가상 스레드 | B | #41 | — |
| H-3 | F-1: trim·UTF-16, `ANSWER_PENDING`(질문 대기만), PENDING `ANSWER` 고정, 오래된 PENDING 정리. 수용 기준 "202 … `status=PENDING`" → `{userMessageId, assistantMessageId}` | B | #41 | — |
| H-3b | F-2: `afterId` 폴링·복원 50개, `hasPending`·`answerPending`, PENDING `messageType=null`, `conditionChanges`·`rank` 미노출, 쓰기 트랜잭션, `@SkipRenewal`, ERD Q2-b 정정 | B | #42 | 선행 #34 |
| H-4 | F-3: `findPlanRun` 404 한 경로, PENDING 재사용(DB 행 수로 테스트), `ANSWER_PENDING` 제외, 202 `{}` | B | #43 | — |
| H-5 | F-4: `recompute`(범위 검사 없음, 실패 500), `display`·`changedKeys`(순서 보장 없음)·`applicable`, 400·404·500, snake_case 문장 교체(코드 차이 X-13) | B | #44 | 기존 선행에 **#21·#78·#19** 추가 |
| H-6 | F-5 chat 컨트롤러·서비스(검사 1~4), 응답 `{revision}`. `package-info`·`backend/CLAUDE.md` 항목은 **삭제**(H-6b로 이동) | B | #45 | 선행 #33·#44·#21 |
| H-6b | chat `package-info.java` → `{calc, rag, plan, auth}`, `backend/CLAUDE.md` 모듈 표(코드 차이 X-1) | B | #41 | paths에 `backend/CLAUDE.md` 추가 |
| H-7 | `PlanApplyService`·`PlanApplyResult`·예외, 검사 5~10, 기준 버전 검사, 0행 롤백, `path` 제한, `persistence.md:14`·`moved-to-code.md` 정정(X-10), ERD Q4-b, 되돌리기 응답 `revision`. **(X-1)** B면 복사 INSERT, 읽기 → `NOTHING_TO_UNDO` → `PLAN_CHANGED` → INSERT → 조건부 UPDATE, `source` 주석·`db/tables.md`, ERD Q4-c(X-14) | A | #33 | — |
| H-7b | 저장 서비스가 새 `revision` 반환, 공개 현재 계획 조회에 `currentVersionId`, 수용 기준 "0행이면 현재 상태를 돌려준다" 정정(X-10) | A | #19 | — |
| H-7c | 현재 계획·결과 응답에 `revision`·`calcRunId`·`result.status`, 입력 저장(결과 보기) 응답에 `revision` | A | #31, #30 | — |
| H-8 | `/internal/calc` 컨트롤러 한정 `@ExceptionHandler`: 422 `minDisplay`, 500 `CALC_FAILED`(X-15) | A | #32 | — |
| H-8b | calc 루트 `ChatComparisonQuery`·`ChatComparisonView`, 버전 지정 기준 데이터 조회(`ReferenceDataService` 3메서드), `findForCalcRun`과 공용 기록 재현 코드 | A | #78 | paths에 `calc/ChatComparisonQuery.java`·`calc/ChatComparisonView.java`·`refdata/ReferenceDataService.java`(+ 테스트). 분리는 A팀 재량 |
| H-9 | A: `MemberLoggedIn` record·발행·`auth/package-info.java` 문장(#16), `MemberLoggedOut` record·발행·만료 토큰 로그아웃 401(#34). B: 동기 `@EventListener`·일괄 DELETE·`modulith.md` 예외 1줄·이벤트 표 2행, 수용 기준 "로그인 응답 전 삭제 완료"·"auth `{}` 유지"(#46) | A·B | #16, #34, #46 | #46 paths에서 `auth/LoggedIn.java` 제거, #16·#34 paths에 각 record |
| H-10 | 전역 오류 처리: 수용 기준 500 `CALC_FAILED` → `INTERNAL_ERROR`(X-15), Spring 기본 예외 매핑 4~5개, 모듈 예외 `config` 상속 금지, F-4용 "타입만 변환" 사용 방식. 401 엔트리 포인트는 #16 | A | #17 (+ #16) | — |
| H-10b | `@SkipRenewal` 구현 메모(인터셉터 또는 필터 + `HandlerMappingIntrospector`) | A | #34 | — |
| H-11 | 프론트 폴링: 1초, `afterId`, upsert, 401 외 실패 연속 3회 중단, 복원 안전장치 1회의 범위, `answerPending`으로 보내기 버튼, F-1 오류별 동작, 훅이 `hasPending`·`answerPending` 노출 | B | #52 | — |
| H-11b | 프론트 카드: 최신 RECALC만 F-4, 새 RECALC 도착 시 이전 버튼 비활성, 버튼 활성 한 줄, F-4 500 카드(버튼·재시도 없음), F-5 오류별 동작, 성공 뒤 순서(F-3 호출 없음), ETF 0% 카드, `achievementChange`·조건 4개 라벨 키. **(X-2)** A면 `revision` 구독으로 버튼 전부 비활성(최초 로드 제외). **(X-1)** A면 같은 지점에서 `planChangeBarrierId` | B | #53 | — |
| H-11c | F-3 호출 지점 하나("결과 `calcRunId`가 바뀌고 `status=CALCULATED`면"), F-3 오류별 동작(404는 재조회 뒤 한 번), D-062 | B | #54 (+ #49 교차참조) | — |
| H-11d | 되돌리기 토스트가 `revision`을 들고 있음, 되돌리기 성공 뒤 결과 재조회까지(F-3 호출 없음) | A | #51 | — |
| H-11e | 목 제거에 `frontend/src/features/chat/**` 포함. **소유 팀 확인**: `team:common`으로 바꾸거나 대화 목 제거를 B팀 Issue 한 줄로 분리 | A·B(확인) | #55 | 선행에 #45·#52·#53·#54 추가 |
| H-12 | `b-team-contracts.md` §3·§4 A-1·§6, `alignment.md` 2-4를 이 계약으로 정정(X-8) | 기획 | 문서 | — |
| H-13 | `ConditionChanges` 4키로 축소(D-040) | B | #21 | (#44·#45의 선행) |
| H-14 | ai-server 테스트: 보고한 `conditionChanges` = `/internal/calc`에 보낸 값 | B | #23 | — |
| H-15 | 문구표 키: 폴링 실패 안내, F-1·F-5 토스트, F-4 카드 실패, `achievementChange` 4값, 조건 4개 라벨(`condition.<camelCase 키>` 예) | 공통 | #18 | — |
| H-16 | `fetch` 래퍼: 목 선택 방식(메서드+경로 키, `useMock(파일명)`, 배열 순서·끝 반복, `status`·`headers` 반영), F-4 messageId 분리. 같은 사이트 전제(`SameSite=Lax`, Vite 프록시 `/api`) | 공통 | #13 | — |
| — | 결정 반영: Q-056·Q-057 결정 뒤 v3 → 최종본 `frontend-api-chat.md`, D-041 보충(X-2 A일 때) | 기획 | 문서 | 쟁점 결정 |

**task-planner 전달**
- #78이 `PlanContextProvider`에 더해 `ChatComparisonQuery`·refdata 조회까지 맡는다. #43·#44가 둘 다 #78을 기다리므로 #78이 B팀 백엔드의 병목이 될 수 있다. A팀이 나눌지 일찍 정하는 것이 좋다.
- chat 의존 변경이 #41로 당겨졌다. #41이 #42·#44보다 먼저 머지되어야 `ModularityTests`가 깨지지 않는다(이미 선행 순서상 그렇다면 확인만).

## 협상 기록

**v1 → v2** (상세 표는 `frontend-api-chat-v2.md` 부록 B)
- 판정: 제공자 "수정하면 수용", 소비자 "수정하면 수용".
- 제공자 반영: 대화 삭제를 auth 이벤트 + chat 동기 수신으로(순환 제거), `SameSite=Lax` 필수, `memberId`는 Security 타입, PENDING 자리표시 `ANSWER` 고정, id·커밋 순서와 복원 안전장치, trim 저장·전송, `ChatComparisonQuery`(display `Map`), F-5 0행 롤백·검사 9 잠금 없는 이유·422 처리 위치, `condition_changes` camelCase 저장, Spring 기본 예외 매핑, 모듈 예외 `config` 상속 금지, 일괄 DELETE, 0행 citation 미저장.
- 소비자 반영: `answerPending`, `conditionChanges`·`rank` 미노출, 202 `status` 제외, 오류별 프론트 동작 표, 폴링 연속 3회 실패 중단, `changedKeys`, F-4는 최신 RECALC만, F-3은 새 `calcRunId`, `baselineScenario=AVG`, 목 응답 배열 형식·35개.
- 쟁점화: R-2 → 쟁점 X-1(제공자 B vs 소비자 A+C), 소비자의 D-041 범위 확대 → 쟁점 X-2.

**v2 → v3** (상세 표는 `frontend-api-chat-v3.md` 부록 C)
- 판정: 제공자 "수정하면 수용"(계약 문장 3개 + Issue 배치 4곳), 소비자 "수정하면 수용"(Issue 배치 빈틈 5개 + 목 선택 방식 1개. 필수 1·2는 미반영 시 수용 불가에 가깝다고 명시 → 둘 다 반영).
- 제공자 반영: 500 코드(전역 `INTERNAL_ERROR`, `/internal/calc`만 `CALC_FAILED`, 코드 차이 X-15), F-4 재계산은 타입 변환만·F-4 422 없음, `changedKeys` 순서 보장 없음, `ChatComparisonQuery`·refdata를 #78로, #44 선행 #78·#19, 입력 저장 `revision`은 #30, X-10에 #19, 이벤트 record·`auth/package-info`는 #16·#34, #17 수용 기준 정정, `@SkipRenewal` 구현 메모, X-1 B 구현 메모 (a)·(b), #41 202 기준 정정.
- 소비자 반영: 같은 사이트 전제(#13), 복원 안전장치 범위 정의, 폴링 실패 "401 외 모든 실패", chat `package-info`·`backend/CLAUDE.md`를 #41로, F-3 호출 지점 #54 하나, 목 선택 방식·F-4 messageId 분리·`restore-pending` 목, #18 조건 라벨 키, #55 팀·paths, F-4 500 카드 동작, 양보 가능 필드 축소(F-5 `planVersionId`, F-3 `assistantMessageId`), X-2 구현을 `revision` 구독으로.
- Issue 배치 충돌 1건(`ChatComparisonQuery` 위치: 제공자 #78 vs 소비자 #32)은 A팀 영역이라 제공자안 채택, 이유 기록.
- 쟁점: 둘 다 양쪽·기획이 같은 안으로 모임(X-1 B — 소비자가 v1 반대 철회, X-2 A). 결정 변경·새 정책이라 Q-056·Q-057로 사람에게 올린다.

**검토 파일**
- [`frontend-api-chat-v1.md`](frontend-api-chat-v1.md), [`review-frontapi-chat-v1-provider.md`](review-frontapi-chat-v1-provider.md), [`review-frontapi-chat-v1-consumer.md`](review-frontapi-chat-v1-consumer.md)
- [`frontend-api-chat-v2.md`](frontend-api-chat-v2.md), [`review-frontapi-chat-v2-provider.md`](review-frontapi-chat-v2-provider.md), [`review-frontapi-chat-v2-consumer.md`](review-frontapi-chat-v2-consumer.md)
- [`frontend-api-chat-v3.md`](frontend-api-chat-v3.md) (최신 본문)
