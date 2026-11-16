# 프론트 ↔ Spring 대화 API 계약 v2 (#12-b) — 제공자 재검토 (마지막 1회)

> 검토자: contract-provider(A팀 Spring 관점), 2026-11-16. `/negotiate-contract` 4단계. 대상 `frontend-api-chat-v2.md`. 상대 의견 `review-frontapi-chat-v1-consumer.md`, 내 1차 의견 `review-frontapi-chat-v1-provider.md`를 함께 봄.
> 근거로 다시 읽은 것(moeun origin/develop `9a31166`, 읽기만): `schema.sql`(plan·plan_version·chat_message 인덱스), `db/erd.md` §4 Q4, `backend/.claude/rules/modulith.md`·`persistence.md`, 모든 `package-info.java`, `refdata/ReferenceDataService.java`, `backend/build.gradle`(REST Docs 이미 있음), `internal-calc.md` C2·C3-2, `decisions.md` D-041·D-044. moeun Issue #16·#17·#19·#21·#29~#34·#41~#46·#49·#51~#54·#78 본문은 `gh api`로 이번에 다시 조회.

```
판정: 수정하면 수용
```

1차 제안은 거의 모두 반영됐다. 소비자 제안(answerPending, 응답 배열 목, 오류별 동작, changedKeys 등)이 A팀에 주는 부담은 작고 모듈 경계도 깨지 않는다. 남은 수정은 **계약 문장 3개(500 코드 이름, F-4의 검증 실패, changedKeys 순서)** 와 **Issue 배치 4곳**이다. 모두 이 문서 안의 몇 줄로 끝나며 쟁점으로 올릴 필요는 없다.

## 항목별 의견

### (1) 1차 제안 반영 여부

- [순환 금지: chat → auth 이벤트 + 동기 `@EventListener`] 수용: 반영됨(C12b-8, C12b-10-2).
- [`SameSite=Lax` 이상, `memberId`는 Security 타입으로만] 수용: 반영됨(C12b-2).
- [PENDING 자리표시 `ANSWER` 고정, id와 커밋 순서, 복원 안전장치] 수용: 반영됨(C12b-3, C12b-5).
- [trim 저장·전송, "문자열 아님 → 400" 삭제, F-2 쓰기 트랜잭션] 수용: 반영됨.
- [`ChatComparisonQuery` + display는 `Map`, 버전 지정 기준 데이터 조회 공유] 수용: 반영됨. 다만 Issue 배치는 아래 (4) H-8에서 고친다.
- [F-5 응답 축소, 검사 9를 잠금 없이 읽는 이유, 0행 롤백, 코드 차이 X-10, 422를 `/internal/calc` 컨트롤러 한정으로] 수용: 반영됨(C12b-7, 7-1).
- [`condition_changes` camelCase 저장(#41)] 수용: 원칙 9로 반영됨.
- [Spring 기본 예외 매핑, 모듈 예외는 `config` 타입 상속 금지] 수용: 반영됨(C12b-9).
- [일괄 DELETE, 0행이면 citation 미저장, 만료 토큰 로그아웃] 수용: 반영됨.
- [가상 스레드 메모, REST Docs와 같은 예시 id, R-10 문장 정정, `path` 제한, 검증 결과 record, #23 테스트] 수용: 반영됨. REST Docs는 `build.gradle:78-80`에 이미 있어 새 의존이 없다.

### (2) 소비자 제안 반영으로 생긴 제공자 부담·경계 문제

- [`answerPending`] 수용: `EXISTS(member_id=? AND status='PENDING' AND message_type='ANSWER')` 한 번이면 된다. `ix_chat_message_pending`은 `(created_at) WHERE status='PENDING'`이라 회원 조건은 인덱스 밖이지만, PENDING 행은 전체에서 몇 개뿐이라 그대로 둔다(인덱스 변경 없음). F-1의 409 판정과 같은 조건이라 메서드 하나를 같이 쓴다.
- [`changedKeys`] 수정: "C2-2 허용 키 표의 순서"를 그대로 두면 **구현이 틀리기 쉽다.** `condition_changes`가 `jsonb`라 PostgreSQL이 키 순서를 보존하지 않기 때문이다(`jsonb`는 키를 다시 정렬해 저장). "저장값의 키를 그대로 꺼낸 것"과 "표의 순서"는 같이 성립하지 않는다. 수정안(둘 중 하나): (a) **"순서는 plan `InputField` enum 순서"** 로 적고, chat은 plan 공개 API에서 얻은 CHAT 허용 키 목록(`List`) 순서로 정렬한다(chat → plan, 허용된 방향). (b) "순서 보장 없음, 프론트는 집합으로 쓴다". 제공자는 (b)를 권한다(코드 0줄). 허용 4키 밖의 키가 저장돼 있으면 그대로 싣는다(조용히 버리지 않는다는 원칙 9와 같음).
- [F-4 재계산 중 검증 실패] 수정(빈칸): C12b-7-1은 "비교 뒤 `rules.yml` 범위가 바뀌면 F-5에서 422"를 전제한다. 그런데 F-4도 같은 저장값으로 다시 계산하므로, `recompute`가 `ConditionValidator`를 거치면 F-4에서 `ConditionViolationException`이 나고, F-4 오류 표에 없는 **422**가 프론트로 나간다. 수정안: "`ChatComparisonQuery.recompute`는 **범위 검사를 하지 않고 타입 변환만** 한다(그때 계산한 값을 재현). 타입 변환 실패나 허용 밖 키는 `500 INTERNAL_ERROR`(F-4 표의 '재계산 실패')이고, 범위 위반의 최종 거절은 F-5 검사 6·7만 한다." 그래서 #17 `ConditionValidator`가 "범위 검사 없이 타입만 바꾸는" 진입점을 하나 더 내거나, 검증 결과 record에 위반이 있어도 값을 담아 준다(#17 재량). F-4 404/500 표는 그대로 둔다.
- [500 코드 이름] 수정(빈칸, 코드 차이 행 추가): 이 계약은 처리하지 못한 예외를 `500 INTERNAL_ERROR`로 쓰는데, **#17 수용 기준은 "처리되지 않은 예외 → 500 `code=CALC_FAILED`"** 이고 internal-calc C3-2도 `/internal/calc`의 500을 `CALC_FAILED`로 정했다. 전역 advice 하나로는 둘을 동시에 만족할 수 없다. 수정안: **전역 기본값은 `INTERNAL_ERROR`, `/internal/calc` 컨트롤러 안 `@ExceptionHandler`(422 `minDisplay`를 붙이는 바로 그곳)가 자기 500을 `CALC_FAILED`로 바꾼다.** 경로별 분기를 전역 advice에 넣지 않는다. 코드 차이 X-15로 "#17 수용 기준 `CALC_FAILED` → `INTERNAL_ERROR`, `CALC_FAILED`는 #32"를 더한다.
- [오류별 프론트 동작, 폴링 연속 3회 실패 중단, F-3 404 재시도] 수용: 서버 영향 없음. F-3 404 재시도가 한 번으로 묶여 있어 부하 걱정 없음.
- [목 응답 배열·35개] 수용: 서버 영향 없음. REST Docs 스니펫은 단일 응답이므로, 배열 목의 각 원소가 스니펫 하나와 같도록 맞추면 된다.
- [`baselineScenario=AVG`, `history.role` 소문자] 수용: 리스너 두 줄(#41).
- [PLAN 기록 중복은 무해, 유일 제약 없음] 수용: #29 수용 기준 "같은 이벤트 두 번 → 중복 없음"은 이벤트 단위 멱등이고, 리스너와 결과 조회가 동시에 만드는 2행과는 다른 이야기다. 둘 다 유지해도 모순이 없다.
- [모듈 경계] 수용: 새로 생긴 의존은 chat → plan(`currentVersionId`, CHAT 허용 키 목록), chat → calc(`ChatComparisonQuery`), chat → auth(이벤트, `@SkipRenewal`)뿐이다. 모두 C12b-10-2 표 안에 있다. plan `{}`, auth `{}` 유지.
- [구현 메모, 계약 변경은 아님] `@SkipRenewal`은 핸들러 어노테이션이라, 서블릿 필터인 `TokenRenewalFilter`는 핸들러가 정해지기 전에 돌아 그 어노테이션을 바로 볼 수 없다. #34에서 `HandlerInterceptor.preHandle`(본문을 쓰기 전에 `Set-Cookie`를 넣음)로 만들거나, 필터에서 `HandlerMappingIntrospector`로 핸들러를 찾는다. 어느 쪽이든 어노테이션이 auth 루트 타입이라는 점은 같다. #34에 한 줄 적는다.

### (3) 쟁점 X-1·X-2

- [쟁점 X-1] **B 유지(제공자 권장), A도 수용 가능, C 반대.**
  - 소비자 우려 "B는 #33의 '직전 1개' 의미와 충돌한다"에 대한 v2 설명은 **맞다.** 근거: (i) `db/erd.md` Q4-c의 지금 되돌리기도 `previous_version_id = NULL`로 두므로 지금도 1단계다. B의 SQL도 똑같이 NULL로 둔다. (ii) `plan_version`에는 부모를 가리키는 컬럼이 없다(`schema.sql` plan_version: `member_id`…`source`·`created_at`뿐). 그래서 행이 늘어도 "체인"이 생길 자리가 없고, `previous_version_id`는 `plan` 행에 하나뿐이다. (iii) D-044·FR-PLAN-04·#33 수용 기준 "직전 계획으로 돌아가고 시작월은 그대로"도 B에서 그대로 참이다(복사본이므로 값·시작월이 같다).
  - B가 실제로 막는 경우를 v2보다 분명히 적어 두면 좋다: **비교(기준 V1) → 적용(V2) → 10초 안에 되돌리기.** 포인터 교체(A)에서는 현재가 다시 V1이 되므로 **방금 적용한 그 비교가 가장 최근 RECALC_RESULT이면서 기준 버전도 같아져** 새로고침하면 다시 활성이다. B에서는 현재가 V3(복사본)이라 서버가 비활성으로 판정한다. D-041 문장 "되돌리기 뒤 이전 결과 버튼은 비활성"이 정확히 이 경우다.
  - B 구현 메모 2개(#33): (a) v2의 SQL은 `WHERE … AND previous_version_id IS NOT NULL`이 0행이면 `NOTHING_TO_UNDO`인지 `PLAN_CHANGED`인지 구분이 안 된다. 복사할 행 id를 알려면 어차피 `plan`을 먼저 읽으므로 "읽기 → previous 없음 `NOTHING_TO_UNDO` → revision 다름 `PLAN_CHANGED` → INSERT 복사 → 조건부 UPDATE(0행이면 롤백)"로 적용과 같은 틀을 쓴다. (b) `schema.sql`의 `source` 주석 "이 버전을 만든 경로"가 B에서는 "복사한 원본의 경로"가 된다. CHECK에 `UNDO`를 더하지 말고(스키마 변경) 주석과 `db/tables.md` 한 줄만 고친다. 코드 차이 X-14에 이 한 줄을 더한다. 새 버전의 `calc_run(PLAN)`은 이미 있는 `PlanChanged(UNDO)` → calc 리스너가 기록하므로 추가 코드가 없다(`modulith.md` 이벤트 표에 `action(INPUT/APPLY/UNDO)`).
  - C 반대 이유: `plan`에 시각 컬럼이 없어 `ALTER TABLE` + 엔티티 + `ddl-auto=validate` 갱신 + 모든 plan UPDATE 경로 수정이 필요하고, 그래도 프론트 barrier를 없애지 못한다. 시각 비교는 트랜잭션 시작 시각(`now()`)과 커밋 순서가 다르다는 경계 문제도 생긴다. B보다 비싸고 보장은 약하다.
- [쟁점 X-2] **A(넓힘) 수용. 서버 영향 없음.** 어느 안이든 검사 9·`applicable`이 막으므로 제공자 쪽 동작은 같다. 다만 D-041의 문장을 넓히는 것이므로 D-번호 결정 기록이 있어야 한다(v2 서술과 같음). X-1이 B면 프론트는 "계획이 바뀌면 버튼 전부 끔" 함수 하나라 가장 싸다.

### (4) 후속 작업 Issue 배치 (A팀 위주, `gh api`로 본문 확인)

- [H-8 → #32] 수정: v2의 "먼저 하는 쪽이 만듦, #32 선행에 #78을 넣지 않음"은 **이미 순서가 정해져 있어 성립하지 않는다.** #78 본문의 선행에 #32가 있다(#78 "선행 #19, #28, #29, #32"). 그러면 #32가 항상 먼저이고, v2대로라면 #32가 버전 지정 기준 데이터 조회까지 만들어야 하는데 #32 paths에는 `refdata`가 없고 수용 기준이 이미 20개다. **수정안: `ChatComparisonQuery`·`ChatComparisonView`와 버전 지정 기준 데이터 조회(`ReferenceDataService`에 버전 id 조회 3개)를 #78로 옮긴다.** 근거: #78 `findForCalcRun`이 "그 기록의 plan_version·데이터 버전으로" 다시 계산해야 해 같은 조회가 반드시 필요하고, 소유권 확인도 같은 2단계(`calc_run` → `plan.findVersion`)다. 공용 "기록 재현" 코드 하나를 두 공개 API가 쓴다. #78 paths에 `calc/ChatComparisonQuery.java`, `calc/ChatComparisonView.java`, `refdata/ReferenceDataService.java`(+ 테스트)를 더한다. #32에는 "`/internal/calc` 422 `minDisplay`·500 `CALC_FAILED` 처리를 그 컨트롤러 한정 `@ExceptionHandler`로"만 남긴다(지금 #32 수용 기준 "`calc.web`이 잡아 `CalcRejectedException`으로 다시 던짐"과 맞음). #78이 너무 커지면 A팀이 같은 선행으로 Issue를 나눌 수 있다(재량).
- [#44 선행] 수정: H-5 "선행 #21, #32"에 **#78**(`ChatComparisonQuery`)과 **#19**(`currentVersionId`)를 더한다. #44 본문의 snake_case 수용 기준 교체(코드 차이 X-13)는 v2대로.
- [H-7b → #19] 수정: #19는 서비스 Issue(paths `plan/**`, REST 없음)이고, 입력을 저장하는 REST는 #30(결과 보기: 검증 → 저장 → 계산 → 응답)이다. 그래서 **"입력 저장 응답에 `revision`"은 #30**이고, #19는 "저장 서비스가 새 `revision`을 돌려줌"과 "공개 현재 계획 조회에 `currentVersionId`"다. C12b-13 요구 4의 "#19(입력 저장 `revision`)"도 #30으로 고친다.
- [코드 차이 X-10] 수정: #19 수용 기준 "revision이 맞지 않는 요청 → 0행 갱신이고 **현재 상태를 돌려준다**(PLAN_CHANGED)"도 `persistence.md:14`와 같은 문장이다. X-10 후속에 #33과 함께 **#19**를 넣는다.
- [H-9 paths] 수정: #46(B팀) paths에 `auth/LoggedIn.java`가 있고 v2는 `auth/package-info.java` 문장 수정도 #46 paths에 넣었다. auth는 A팀 모듈이라 B팀 Issue가 고치면 팀 경계를 넘는다(moeun `CLAUDE.md` "다른 팀 코드를 고쳐야 하면 멈춘다"). **이벤트 record와 `auth/package-info.java` 문장은 A팀이 만든다**: `MemberLoggedIn` + 발행 + `package-info` 문장은 #16(1주차라 먼저 끝남), `MemberLoggedOut` + 발행은 #34. #46은 chat 동기 리스너·일괄 DELETE·`modulith.md` 예외 1줄과 이벤트 표 2행만 하고, paths에서 `auth/LoggedIn.java`를 뺀다. #46 수용 기준에 "로그인 응답 전에 삭제가 끝남(동기)"과 "auth `{}` 유지"를 넣는다.
- [H-10 → #17] 수정: 위 (2)의 500 코드 이름에 맞춰 #17 수용 기준 "500 `code=CALC_FAILED`"를 "500 `code=INTERNAL_ERROR`"로 고치고, Spring 기본 예외 4개 매핑을 더한다.
- [H-7 → #33] 수용: 기준 버전 검사, 0행 롤백, `path` 제한, X-10, (B면) 복사 INSERT와 위 구현 메모 (a)·(b). #33 수용 기준의 `undoAvailable=true`는 plan REST 범위라 유지해도 된다.
- [H-7c → #30·#31, H-11d → #51] 수용.
- [H-3 → #41, B팀] 참고: #41 수용 기준 "202와 userMessageId, assistantMessageId, **status=PENDING**"은 v2에서 `status`를 뺐으므로 그 문장도 고친다.

## 제공자 쪽에서 꼭 지켜야 할 것 (양보 불가)

1. **chat → auth 한 방향, auth·plan은 `{}`.** 이벤트 record와 `auth/package-info.java`는 A팀 Issue(#16·#34)가 만든다. B팀 Issue가 auth 파일을 고치지 않는다.
2. **500 코드는 한 곳에서 하나.** 전역 기본값은 `INTERNAL_ERROR`, `/internal/calc`만 그 컨트롤러 안에서 `CALC_FAILED`. 전역 advice에 경로별 분기를 두지 않는다(#17·#32 수용 기준 맞춤).
3. **F-4는 422를 내지 않는다.** 재계산은 범위 검사 없이 저장값을 재현하고, 범위 거절은 F-5(plan) 한 곳에서만 한다.
4. **`ChatComparisonQuery`와 버전 지정 기준 데이터 조회는 하나의 "기록 재현" 코드를 #78과 같이 쓴다.** #32와 #78에 따로 만들지 않는다.
5. (1차와 같음) plan 한 트랜잭션, 0행이면 롤백. `condition_changes`는 camelCase로 저장. 모든 오류에 `code`. 일괄 DELETE는 로그인 응답 전에 끝남.

## 양보 가능한 것

- 쟁점 X-1: B를 권하지만 A(포인터 교체 + 프론트 barrier)도 데이터는 안전하므로 수용. C만 반대.
- 쟁점 X-2: A·B 어느 쪽이든 서버 영향 없음.
- `changedKeys` 순서: (a) `InputField` 순서 또는 (b) 순서 보장 없음. 제공자는 (b) 권장.
- `ChatComparisonQuery` 위치: #78 권장. A팀이 #78을 나누거나 #32 paths에 `refdata`를 더하는 쪽을 골라도 위 4번만 지키면 된다.
- F-4가 범위 검사 없이 타입만 바꾸는 방법(`ConditionValidator`에 진입점 추가 ↔ 위반이 있어도 값을 담는 결과 record), #17 재량.
- `@SkipRenewal` 구현 방식(인터셉터 ↔ 필터 + `HandlerMappingIntrospector`), #34 재량.
