# 프론트 ↔ Spring 계획·인증 API 계약 합의안 (moeun #12-a)

> **결정 완료** (2026-11-16): X-1 → D-074(B, 100자), X-2 → D-075(A), X-3 → D-076(A 로컬, 임시 — 원격 배포 가능성). 최종본: `frontend-api-plan.md`. 후속 작업 J-1~J-17을 moeun Issue 26개 본문에 반영(#9·12·13·16·17·18·19·20·26·27·29·30·31·33·34·47·48·49·50·51·52·53·54·58·68·78), J-15 기획 문서 정정 완료, 2026-11-16.

> **결정 대기.** 쟁점 X-1 → Q-061, 쟁점 X-2 → Q-062, 쟁점 X-3 → Q-063으로 open-questions에 올라간다. 결정되면 이 줄을 "결정 완료 (날짜): X-1→D-xxx, X-2→D-xxx, X-3→D-xxx"로 바꾸고 v3을 최종본 `frontend-api-plan.md`로 확정한다.

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 4단계(재검토 반영) 마무리, 5단계(사람에게 넘기기) 준비.
> - 계약 본문: `frontend-api-plan-v3.md` (쟁점은 본문에 추천안을 임시로 적고 `⟵ 쟁점 X-n` 표시). v1·v2를 합친 자기완결 본문이다.
> - 입력: `frontend-api-plan-v1.md`, `review-frontapi-plan-v1-provider.md`(A팀), `review-frontapi-plan-v1-consumer.md`(프론트·B팀), `frontend-api-plan-v2.md`, `review-frontapi-plan-v2-provider.md`(A팀 재검토), `review-frontapi-plan-v2-consumer.md`(프론트·B팀 재검토)
> - **에이전트는 결정하지 않았다.** 아래 "사람이 정할 쟁점" 3개만 답해 주면 v3을 최종본으로 확정할 수 있다. 재검토는 이번이 마지막이다(더 반복하지 않음).
> - 이름 겹침 주의: 계약 본문의 "코드 차이 Y-n"(C12a-14)과 여기의 "쟁점 X-n"은 다르다. #12-b 합의안의 쟁점 X-1·X-2(Q-056·Q-057)와도 다른 번호다.

## 합의된 것 (그대로 구현 가능) — 47항목

v1 → v2 합의 31건(`frontend-api-plan-v2.md` §V, V-1~V-18·V-21~V-33) + v2 → v3 합의 16건(`frontend-api-plan-v3.md` §W, W-1~W-16). 묶어서 요약한다.

| 묶음 | 내용 | 근거 |
|---|---|---|
| 범위·원칙 | 엔드포인트 6개(P-1 로그인, P-2 로그아웃, P-3 입력 저장, P-4 현재 계획·결과, P-5 되돌리기, P-6 대안 적용은 **경로 예약만**·#68). `/api/auth/me` 없음. 프론트는 숫자를 만들지 않고 `display`·문구표만, 변환 (d)(e)(f)는 **공용 폴더 util 하나** | 양쪽 (V-14, V-28, W-14) |
| 인증·쿠키 | `moeun_at`, `HttpOnly`·`SameSite=Lax`·`Secure` 기본 true(`local`만 false), 리졸버는 로그인 경로에서 토큰 무시, 서명 키 환경 변수 고정, 401에 만료 쿠키, P-1·P-2 `@SkipRenewal`(#34가 붙임), 로그인 400은 파싱 실패만 | 제공자 (V-5, V-18, V-30, V-31) |
| 래퍼 | `code`로만 분기, 비JSON → 네트워크 오류, `UNAUTHENTICATED` → 상태·폴링 비움, 로그인 화면에서는 다시 이동 안 함 | 소비자 (V-17, W-15) |
| P-3 입력 저장 | **한 트랜잭션**(calc 유스케이스 + plan `REQUIRED` 합류), 계산 실패 = 롤백 + 500 = "저장 안 됨", 네이티브 `ON CONFLICT DO NOTHING`/조건부 UPDATE + 0행 409, **네이티브 쓰기 뒤 영속성 컨텍스트 비움**, `INPUT_EDIT`에 CP-07 없음, 응답 `PlanView`, 요청 중 저장 버튼 비활성 | 제공자, 소비자 (V-1, V-6, V-21, V-24, W-6, W-13) |
| 입력 단위 | 만원 칸 소수 4자리·십진 문자열 변환(부동소수 금지), `step` 없음, 422 범위 문구 (f)(KRW 0은 "0원"), 범위 수치 임시값 | 양쪽 (V-15, V-29, W-7) |
| P-4 `PlanView` | 화면 전용 View(뺀 필드 목록), 한 스냅샷으로 조립, `409 NO_PLAN`, 응답에 문구 키 없음, readOnly 트랜잭션 아님 | 양쪽 (V-8, V-11, V-25, V-26) |
| 그래프 점 | 점 = `month`·`afterTaxAsset`만(**`principal` 제거**), 첫 점 = 시작월·보유 자산, 마지막 점 = 목표월·시나리오 값, 점 수 = 기간 + 1. **엔진(#26·#27·#9)이 지키고 View는 복사만**. 숫자 없는 그래프 | 양쪽 (V-12, V-16, W-8, W-9) |
| 같은 버전 = 같은 `calcRunId` | 회원 advisory 잠금 아래 "확인 → 기록" 한 메서드, 리스너도 같은 메서드. **조건 4개**(`MANDATORY`, READ COMMITTED·잠금 뒤 조회, readOnly 금지, `@ApplicationModuleListener`). 단서 "기준 데이터 활성 버전·`engine_version`이 그대로인 동안" | 양쪽 (V-2, W-10, W-11) |
| 프론트 공유 상태 | store(#13) **두 칸**(`revision`/`view`) + **파생 `settledStatus`**, 작은 값 무시, `NO_PLAN`은 "요청 시점 `null`이고 지금 값이 있을 때만" 무시, **`loadPlan()` single-flight 하나만 GET**. #52는 `settledStatus`, #53은 `revision`, #54는 `view`를 읽음 | 소비자 (V-4, W-1, W-2, W-3) |
| 결과 화면 대응표 | `display["…"]` 표기 통일, 3구간 `GOOD/AVG/BAD` 고정 순서, `result.notReachedInPeriod`, 입력 화면 현재 비중 읽기 전용, **문구표 키 전체 목록**(`result.alreadyExceeded` ≠ `chat.alreadyExceeded`, `disclaimer` 하나) | 소비자 (V-13, V-23, W-4) |
| P-5 되돌리기 | `PlanUndoService`는 plan 내부, 응답 `{revision}`, `undoAvailable` 없음, 복사 INSERT(D-068) | 양쪽 (V-10, V-27) |
| 모듈 | 의존 변경 없음, `/internal/calc`의 `minDisplay`·`CALC_FAILED`는 그 컨트롤러 클래스 안에서만, `PlanInput` 모양·`GoalType` 루트 enum | 제공자 (V-7, V-9) |
| 목 | 시퀀스 기본 파일 2개(앱 시작 → 로그인 → 입력 → 적용 → 되돌리기 → 수정), `422-decimals`, **`seq-exceeded-toggle`(useMock 전용)**, 총 **29개**, README "시퀀스는 요청 순서로 소비" | 소비자 (V-3, W-5) |
| Issue 배치 | J-3 #34만, J-5 `persistence.md` 제외·paths 추가, J-7 선행 유지·test paths calc, J-8 선행 #30 유지, **J-14 → #20**, **J-16 → #58**, #12·#13·#47·#48·#49·#50·#52~#54 보강 | 양쪽 `gh api` 대조 (V-32, V-33, W-16) |

**재검토에서 합의로 처리한 것** (사람이 보고 이견이 있으면 말해 주면 된다)
- **D-072 판단 위치(소비자 O-1)**: v2는 #53 훅이 판단하고 #52가 표시한다고 적었지만 #53의 선행이 #52라 거꾸로였다. 공유 store의 파생값 `settledStatus`(결과가 그 `revision`에 따라잡았으면 그 상태, 아니면 직전 값)로 옮겼다. D-072 문장은 그대로다.
- **`NO_PLAN` 무시 규칙(소비자 O-2, 제공자 2-3)**: v2의 "값이 있으면 무시"는 F-5·P-5 `NO_PLAN` → 입력 화면 동작과 부딪히고, 데모 초기화 뒤 화면이 멈췄다. "요청 보낼 때 `null`이었고 지금 값이 있을 때만 무시"로 좁혔다. 근거 문장도 "계획 삭제 API 없음(데모 초기화는 예외)"으로 고치고 #58 절차에 새로고침 한 줄을 넣는다.
- **`loadPlan()` single-flight(소비자 O-3) + 기획 보완**: 소비자안대로 GET 호출 지점을 store 함수 하나로 모았다. 기획이 한 줄을 더했다: 진행 중 요청이 시작된 뒤 `revision`이 바뀌었으면(F-5·P-5 성공 직후) 합류하지 않고 새로 보낸다. 합류하면 쓰기 전에 출발한 옛 계획을 받기 때문이다. 재검토를 거치지 않은 구체화이므로 **#13 담당자가 확인**한다.
- **그래프 첫 점 담당(제공자 반대 2-2)**: v2는 View(#31)가 첫 점을 붙여도 된다고 했다. 납입 시점(TBD-04·05)이 #9에서 정해지므로 View가 붙이면 같은 달이 두 번 나올 수 있다. 규칙은 그대로 두고 지키는 곳을 엔진(#26 첫 점·점 수, #27 마지막 점)으로 옮겼다. 제공자는 "엔진이 늦으면 View 임시 처리"를 양보 가능으로 남겼지만 계약은 **View에서 붙이지 않는다**로 적었다(한 곳에서만 정해야 테스트가 하나).
- **`principal` 제거(소비자 "빼도 되는 것")**: 화면이 원금선을 그리지 않아 뺐다. 제공자 이견 없음. 원금선이 필요해지면 키 하나를 다시 더한다.
- **문구표 키(소비자 O-4)**: v2가 "v1 J-13 목록"을 참조해 끊겼다. 키 전체를 C12a-7-1 표로 적었다. `disclaimer`는 결과 화면과 대화창이 같은 키 하나를 쓴다. `result.alreadyExceeded`와 `chat.alreadyExceeded`는 놓이는 화면과 자리 표시가 달라 합치지 않는다.
- **#20으로 문서 정정 이동(제공자)**: `db/erd.md` 등 문서 정정을 auth 코드 Issue(#34)에 붙이지 않고 같은 파일을 이미 고치는 #20(team:common)에 합쳤다(D-058). #33도 `db/erd.md`를 고치므로 **#20을 먼저**, 동시 진행 금지.

## 사람이 정할 쟁점

세 쟁점 모두 **v3 계약 문서 머지와 1주차 개발을 막지 않는다.** X-1·X-2는 양쪽 팀과 기획이 같은 안을 지지하고 임시값으로 진행한다. 그래도 사람에게 올리는 이유: X-1은 머지된 DB 설계(`schema.sql`)와 팀 결정(TBD-09) 중 어느 쪽을 기준으로 할지의 기록이고, X-2는 새 정책(목표 종류 목록), X-3은 새 인프라·새 Issue 여부라서다. 다르게 정하면 `⟵ 쟁점 X-n` 표시가 붙은 줄만 바꾼다.

### 쟁점 X-1. 직접 입력 목표명 길이: 50자 vs 100자 → **Q-061**

- **문제**: Notion TBD-09는 "목표명 필수·100자"로 정했는데, 머지된 `schema.sql`은 `goal_custom_name VARCHAR(50)`이다. 둘 중 하나는 고쳐야 한다.
- **제공자 의견**: B 수용(v1의 A 선호를 거둠). B의 비용은 `schema.sql` 1줄 + 엔티티 `length` + `db/tables.md` 1줄이고 운영 데이터가 없어 이전 비용도 없다. 팀 결정을 뒤집는 기록을 남기는 쪽이 더 비싸다. 조건: `schema.sql`·`db/tables.md`를 #19 paths에 추가.
- **소비자 의견**: B 동의. 프론트는 422 `max`만 읽어 어느 쪽이든 영향이 없다. #49 조건 바는 100자에도 깨지지 않게.
- **기획 의견**: B. 이미 정한 TBD-09를 따르면 결정 변경이 없다.
- **선택지**
  - A) 50자 유지. (영향: 코드 변경 없음. TBD-09를 바꾸는 D-번호 필요. `rules.yml`·목 `max 50`)
  - B) 100자로 맞춤. (영향: `schema.sql`·엔티티·`db/tables.md` 각 1줄, `rules.yml`·목 `max 100`)
- **추천: B.**
- **진행**: 결정 전에도 #19는 100으로 진행한다. A로 정해지면 숫자만 바꾼다.
- **심각도 제안: 사소함.**
- 결정에 따라 바뀌는 줄: v3 C12a-5-1 `goalCustomName` 행, C12a-5-4 길이 초과 문장, C12a-5-5 표, 목 `put-plan.422-custom-name`, Y-16, J-1·J-4·J-5.

### 쟁점 X-2. 목표 종류(`GoalType`) 목록 → **Q-062**

- **문제**: FR-INP-01은 "목표 1개 선택"만 정했고 목록이 없다. #48 드롭다운·#18 문구·#19 enum·목이 같은 목록을 써야 한다.
- **제공자 의견**: A 수용. 계산은 `goalType`을 쓰지 않고 컬럼이 `VARCHAR(30)`이라 스키마 영향이 없다. 주의: 데이터가 생긴 뒤 코드를 지우거나 이름을 바꾸면 옛 행을 읽을 때 실패하므로 변경은 #19 머지 전이 싸다(늦으면 #58 초기화와 함께).
- **소비자 의견**: A 동의. 요청 두 가지(문구표에 없는 코드는 코드 문자열로 대체 표시, `CUSTOM` 숨김 조건은 #48) — v3 본문에 반영했다.
- **기획 의견**: A. 데모용 일반 목표 + 직접 입력이면 충분하고 계산과 무관하다. 은행 서비스 맥락에서 빠진 목표가 없는지만 사람이 확인한다.
- **선택지**
  - A) 임시 목록 `HOUSE`(내 집 마련), `CAR`(자동차), `WEDDING`(결혼), `EDUCATION`(교육), `TRAVEL`(여행), `EMERGENCY_FUND`(비상금), `CUSTOM`(직접 입력). (영향: 바로 #19·#18·#48·목에 씀)
  - B) 사람이 새 목록을 정한다. (영향: 그때까지 A로 개발, 정해지면 enum·문구표·목 몇 줄 교체)
- **추천: A.**
- **진행**: 결정 전에도 임시 목록으로 진행.
- **심각도 제안: 개발 중 혼란.** #19 머지 뒤에 바꾸면 비용이 커지므로 1주차 안에 정하는 것이 좋다.
- 결정에 따라 바뀌는 줄: v3 C12a-5-1 `goalType` 목록, C12a-11-1 `GoalType` enum, C12a-7-1 `goal.<CODE>`, J-5·J-12b·J-13.

### 쟁점 X-3. 데모를 로컬에서 할지, 원격 서버에 배포할지 → **Q-063**

- **문제**: moeun Issue 78개에 **배포·HTTPS·도메인 작업이 없다**(제공자 전수 확인). 쿠키가 `Secure`라 http 원격 주소에서는 로그인이 되지 않는다. 데모 방식에 따라 `Secure` 설정과 배포 Issue 신설 여부가 갈린다. 해커톤 제출 조건(심사위원이 URL로 접속해야 하는지)은 기획 문서에 없어 기획이 알 수 없다.
- **제공자 의견**: #58에 HTTPS 여부·서명 키 환경 변수·초기화 뒤 새로고침을 넣자. 원격 서버에 올릴 계획이면 그 자체가 빠진 작업이니 사람에게 확인하라.
- **소비자 의견**: 없음(프론트는 같은 사이트·Vite 프록시 전제만 지켜지면 됨).
- **기획 의견**: A. 백로그에 배포 작업이 없고 3주 일정에 1~2일을 더할 여유가 적다. 새 인프라를 추가하지 않는 것이 기본값이다. `localhost`에서는 `Secure` 쿠키와 같은 사이트 전제가 그대로 성립해 계약을 바꿀 것이 없다. 단, **제출 조건이 원격 URL을 요구하면 B**다.
- **선택지**
  - A) 로컬 데모: 시연 노트북에서 `docker compose up`, `http://localhost`. (영향: 새 Issue 없음. #58에 시연 절차와 시연 브라우저의 `Secure` 쿠키 확인, 안 되면 `demo` 프로필 `secure=false`. 원격 접속 불가)
  - B) 원격 + HTTPS: VM 1대에 compose + 리버스 프록시(TLS 인증서) + 도메인. (영향: **배포 Issue 신설**(team:common, week 3, 1~2일 추정), 새 인프라·비밀 관리, `Secure=true` 그대로, #63 환경 변수 항목 추가)
  - C) 원격 + http, `secure=false`. (영향: 배포 Issue는 필요. 쿠키가 평문으로 오가 NFR-SEC 취지와 어긋나고 금융 서비스 데모로 설명하기 어렵다. 비추천)
- **추천: A**(제출 조건이 원격 URL을 요구하면 B).
- **심각도 제안: 개발 중 혼란.** 1~2주차 개발은 어느 쪽이든 로컬에서 같다. B면 새 Issue가 일정에 들어가야 하므로 **2주차 말 Should 판단 때까지** 정한다.
- 결정에 따라 바뀌는 줄: v3 C12a-2-1 `Secure` 행, J-16(#58), B면 새 배포 Issue와 #63.

## 후속 작업

> D-058: 각 moeun Issue **본문(수용 기준·변경 범위·선행)**에 반영한다. 댓글로 덧붙이지 않는다. 새 Issue는 없다(쟁점 X-3이 B일 때만 배포 Issue 1개 신설).
> 번호 출처: 양쪽 재검토자가 `gh api`로 조회한 moeun Issue 본문. 이 단계에서 다시 조회하지 않았다.
> 쟁점 의존 표시: **(X-n)**이 붙은 줄은 결정 뒤 숫자·목록만 바꾼다. X-1·X-2는 임시값으로 지금 반영해도 된다.

| J-번호 | 내용 | 팀 | 대상 moeun Issue | 선행·paths 변경 |
|---|---|---|---|---|
| J-1 | `docs/api/frontend-api.md`에 #12-a 절, 목 29개(`mocks/auth/`·`mocks/plan/`, 시퀀스 기본 2개, `seq-exceeded-toggle`), `mocks/README` 시퀀스 소비 규칙, `@SkipRenewal` 수용 기준 문장(R-12). **(X-1)(X-2)** 목 숫자·코드 | 공통 | #12 | — |
| J-2 | P-1 전체(쿠키·리졸버 로그인 경로 null·서명 키 환경 변수·401 엔트리 포인트 + 만료 쿠키·`INVALID_CREDENTIALS`·400 범위·`MemberLoggedIn`·시드·`auth/package-info`) + 테스트 "깨진 쿠키로 로그인 성공" | A | #16 | — |
| J-3 | P-2, `@SkipRenewal`·연장 인터셉터, **P-1·P-2 핸들러 `@SkipRenewal`은 #34가 붙인다**(조건문 삭제), `MemberLoggedOut` | A | #34 | — |
| J-4 | `rules.yml › input.fields`, `INPUT_EDIT` CP-07 없음, `CHAR`, `step` 없음. **(X-1)** max | A | #17 | — |
| J-5 | `PlanSaveService`·네이티브 쓰기·**`@Modifying(flush/clearAutomatically)` + 1차 캐시 테스트**·복사 규칙·`GoalType` enum·컬럼 길이. `persistence.md:14` 정정은 **제외**(#33), ERD Q4-a는 J-14로. **(X-1)(X-2)** | A | #19 | paths에 `schema.sql`·`db/tables.md`. X-1·X-2는 "막지 않음, 임시값으로 진행" |
| J-6 | 결과 조회 서비스 스냅샷 반환, advisory 잠금 한 메서드 + **조건 4개**, 계약 문장 단서, 동시성 테스트 | A | #29 (+ #78 본문 "`findForCurrentPlan`은 readOnly 아님") | — |
| J-6b | `monthlyPoints` 첫 점·점 수(#26), 마지막 점 테스트(#27), 명세 "k번째 점 = 시작월 + k"(#9) | A | #26, #27, #9 | — |
| J-7 | `PUT /api/plan`(별도 컨트롤러, 한 트랜잭션, 롤백 500, `PlanView`, View는 점 복사만), `tax.note` 기준 삭제, 테스트 2개, `backend/CLAUDE.md` 한 줄, 제목 `[calc]` 권장 | A | #30 | 선행 **덮어쓰지 않음**(기존 #17·#19·#27·#28·#29 유지). paths `calc/web/**`·`calc/application/**` 추가, `test/.../plan/**` → `test/.../calc/**` |
| J-8 | `GET /api/plan`(`PlanView`, `409 NO_PLAN`, D-035 키 기준 삭제, 스냅샷 조립, readOnly 아님). "첫 점·점 수" 항목은 J-6b로 | A | #31 | 선행 **#30 유지** + #19·#28·#29. paths `plan/web/**` → `calc/web/**`, test calc |
| J-9 | `POST /api/plan/undo`(plan.application, D-068, `{revision}`, `NOTHING_TO_UNDO`, ERD Q4-c), `undoAvailable` 삭제, P-6은 #68로 | A | #33 | #20 다음에(둘 다 `db/erd.md`) |
| J-10 | display 키 같은 빌더·접두어 확인 | A | #28 | — |
| J-11 | 래퍼(`code` 분기·비JSON·`UNAUTHENTICATED`·로그인 화면 재이동 없음) + **공유 계획 store**(두 칸, 작은 값 무시, `settledStatus`, `acceptNoPlan`, `loadPlan()` single-flight) + 단위 테스트 | 공통 | #13 | paths에 store 폴더(예: `frontend/src/api/planStore/**`). #12-b H-16과 합침 |
| J-12a | 로그인 화면·가드(`loadPlan()`)·로그아웃. "로그인 직후 결과 화면" 문장 삭제(#51 소유), 401 기준 `code` | A | #47 | — |
| J-12b | 입력 화면: 공용 util + 단위 테스트, 드롭다운·대체 표시·**`CUSTOM` 숨김 조건**, 422(소수 포함), `PLAN_CHANGED`, 500 P-4 안 부름, **요청 중 버튼 비활성**. **(X-2)** | A | #48 | paths에 util 공용 폴더 |
| J-12c | 결과 화면 1(요약·조건 바·`result.alreadyExceeded`·가정·면책), "공유 상태로 둔다" → "store를 읽는다", 긴 목표명 대응, 컨테이너 폴더 | A | #49 | 선행에 #13 명시, paths에 컨테이너 폴더 |
| J-12d | 결과 화면 2(3구간 고정 순서·1개·`notReachedInPeriod`·D-029 고지, 그래프 첫/끝 점·숫자 없음)를 **수용 기준으로** | A | #50 | 선행에 #13 명시 |
| J-12e | 진입 분기(`loadPlan()`), 입력 채우기(공용 util), 현재 비중 줄, D-035, 토스트(`revision` 칸, `acceptNoPlan`) | A | #51 | #12-b H-11d와 합침 |
| J-12f | #52 `settledStatus` 읽기·문장 정정·`disclaimer`, #53 `revision` 칸·F-5 `NO_PLAN` → `acceptNoPlan`·`loadPlan()`, #54 `view` 기준 문장·404 뒤 `loadPlan()` | B | #52, #53, #54 | — |
| J-13 | 문구표 키 **C12a-7-1 전체**(`result.alreadyExceeded` 추가, `disclaimer` 하나, `validation.*`·`unit.*`). **(X-2)** `goal.<CODE>` | 공통 | #18 | — |
| J-14 | `db/erd.md` §5-G·§3·§4 Q4-a, ADR-002 §2-5·§3, `moved-to-code.md` §1 정정 | 공통 | **#20** | paths에 `db/erd.md`. **#33보다 먼저** |
| J-15 | 기획 문서: `b-team-contracts.md`·`alignment.md`(Y-8), `frontend-api-chat.md:413` `max`(Y-9), "2행 무해" → "단서 안에서 생기지 않음"(Y-17) | 기획 | project-workspace | — |
| J-16 | 데모 환경: HTTPS 여부 또는 `secure=false`(시연 브라우저 확인), JWT 서명 키 환경 변수, 초기화 뒤 열린 브라우저 새로고침. **(X-3)** B면 (1)은 새 배포 Issue로 | 공통 | **#58** | 프로필 파일을 바꾸면 paths에 `application-*.yml` |
| J-17 | P-6 확정(Should, 2주차 말) | A | #68 | — |
| — | 결정 반영: Q-061~Q-063 결정 뒤 v3 → 최종본 `frontend-api-plan.md`, X-1이 A면 TBD-09 변경 D-번호, X-3이 B면 배포 Issue 신설 | 기획 | 문서 | 쟁점 결정 |

**task-planner 전달**
- #13(team:common, week 1)이 래퍼 + 공유 계획 store를 모두 맡는다. #47~#54가 전부 이것을 읽으므로 **프론트의 첫 병목**이다. store 인터페이스(두 칸, `settledStatus`, `acceptNoPlan`, `loadPlan`)를 먼저 머지하고 내부를 채우는 순서를 권한다.
- `db/erd.md`를 #20·#33이 같이 고친다. #20을 먼저 머지한다.
- 그래프 시계열이 #26(엔진 골격)에 걸렸다. #50의 실제 데이터 확인은 #26·#27 뒤이고, 그 전에는 목(37점 규칙)으로 개발한다.
- 쟁점 X-3이 B로 정해지면 3주차에 배포 Issue(1~2일)가 생긴다.

## 협상 기록

**v1 → v2** (상세 표는 `frontend-api-plan-v2.md` §V)
- 판정: 제공자 "수정하면 수용", 소비자 "수정하면 수용".
- 제공자 반영: P-3 한 트랜잭션(v1의 "plan이 calc를 못 불러 못 묶는다"는 틀림), 네이티브 `ON CONFLICT DO NOTHING`/조건부 UPDATE, 로그인 경로 리졸버 null·서명 키 고정·401 만료 쿠키·P-1 `@SkipRenewal`, `minDisplay` 처리를 `/internal/calc` 컨트롤러 안으로, 한 스냅샷 조립, `PlanInput` 모양·`GoalType` 루트, `PlanUndoService` plan 내부, `INPUT_EDIT` CP-07 없음, Y-11~Y-16.
- 소비자 반영: 목 시퀀스 기본 파일, 공유 상태 두 칸(`revision`/`view`), 같은 버전 = 같은 `calcRunId`(회원 잠금), 화면 전용 View 필드 축소, 그래프 첫·끝 점, `display` 표기 통일·고정 순서·미달 문구, 변환 util (d)(e)(f), 래퍼 비JSON 규칙, 비중 읽기 전용, `goalType` 임시 목록 요청.
- 쟁점화: `goalCustomName` 50 vs 100(TBD-09) → X-1, `goalType` 목록(새 정책) → X-2.

**v2 → v3** (상세 표는 `frontend-api-plan-v3.md` §W)
- 판정: 제공자 "수정하면 수용"(반대 1건: 첫 점을 View에서 붙이는 것, 나머지는 구현 함정 문장과 Issue 배치), 소비자 "수정하면 수용"(작은 반대 4건 O-1~O-4 + Issue 본문 정정, 구조 재설계 반대 없음).
- 제공자 반영: 그래프 첫 점·점 수는 엔진(#26·#27·#9), advisory 잠금 조건 4개(#78 readOnly 한 줄 포함), `calcRunId` 문장 단서, "계획 삭제 API 없음" 근거 정정 + #58 새로고침, #19 1차 캐시 함정, J-3·J-5·J-7·J-8 정정, J-14 → #20, J-16 → #58.
- 소비자 반영: `settledStatus`(O-1), `NO_PLAN` 요청 시점 규칙(O-2), `loadPlan()` single-flight(O-3), 문구표 키 전체(O-4), util 공용 폴더(O-5), 저장 버튼 비활성(O-6), `seq-exceeded-toggle` 목, KRW 0 "0원", `principal` 제거, #12·#13·#47·#48·#49·#50·#52~#54 본문 보강.
- 기획 보완 1건: `loadPlan()`은 `revision`이 바뀐 뒤에는 진행 중 요청에 합류하지 않는다(#13 확인).
- 쟁점: X-1(양쪽 B로 모임), X-2(양쪽 A로 모임)는 결정 기록이 필요해 그대로 올린다. 제공자의 J-16 확인에서 **X-3(배포 방식)**이 새로 생겼다.

**검토 파일**
- [`frontend-api-plan-v1.md`](frontend-api-plan-v1.md), [`review-frontapi-plan-v1-provider.md`](review-frontapi-plan-v1-provider.md), [`review-frontapi-plan-v1-consumer.md`](review-frontapi-plan-v1-consumer.md)
- [`frontend-api-plan-v2.md`](frontend-api-plan-v2.md), [`review-frontapi-plan-v2-provider.md`](review-frontapi-plan-v2-provider.md), [`review-frontapi-plan-v2-consumer.md`](review-frontapi-plan-v2-consumer.md)
- [`frontend-api-plan-v3.md`](frontend-api-plan-v3.md) (최신 본문)
