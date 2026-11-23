# 프론트 ↔ Spring 계획 API 계약 최종본 (moeun #12-a)

> **최종본** (2026-11-16). v3에 쟁점 결정 D-074(목표명 100자), D-075(GoalType 7개), D-076(로컬 데모, 임시 — 원격 배포로 바뀔 수 있어 쿠키 `Secure`·서명 키·허용 출처는 설정값)을 반영했다. 본문의 "쟁점 X-n이 다르면 …" 문장은 기록용이다.
> 협상 기록: `frontend-api-plan-v1.md` → 검토 2건 → `-v2.md` → 재검토 2건 → `-v3.md`, 합의안 `frontend-api-plan-proposal.md`. 이 문서와 `frontend-api-chat.md`(#12-b)를 moeun #12가 `docs/api/frontend-api.md`와 `frontend/src/mocks/`로 옮긴다.
>
> **v4 개정 (2026-11-20, #12-a 개정 — 본문에 직접 반영했다. [v4] 표시)**
> - FR-INP-08을 되살린 **D-085**에 따라 `savingsRatioPct`를 `PUT /api/plan` **요청 필드**로 올렸다. 바뀐 절: C12a-5-1(요청 표·예시·"요청에 없는 것"), C12a-5-2(순서 2·4), C12a-5-5(범위 표), C12a-5-6((f)(g)(h)), C12a-7(가정 보기·입력 수정 채우기), C12a-7-1(문구 키 7개), C12a-12(목 31개), R-9.
> - 새 결정: **D-086**(요청 필드와 `null`의 뜻 = 사용자가 정한 비중 없음 → `NULL` 저장 + 기본 비중 계산, R-9 복사 철회), **D-087**(비중 산출은 NFR-INT-01 예외·정수 HALF_UP 고정식), **D-088**(차액 안내는 금액 없는 고정 문장), **D-089**(입력 수정 복원 토글 상태). 모두 상태 **임시**.
> - 협상 기록: `frontend-api-plan-v4-draft.md` → 검토 2건 → `frontend-api-plan-v4.md`(§Z 변경 표 Z-1~Z-18) → 재검토 2건 → 합의안 `frontend-api-plan-v4-proposal.md`. **쟁점 0건**(초안 쟁점 3개 모두 닫힘). 후속 작업은 moeun **#127** 본문.
>
> **최종본 보충 (2026-11-16, D-077~082 임시, 본문보다 우선)**
> - **D-077** P-3 응답 유실(네트워크·502·비JSON): 입력값 유지 + `common.networkError` + `loadPlan()`으로 `revision`만 맞춤(C12a-6-5 "부르는 때" 표에 추가). → #48, #13
> - **D-078** 로그인·로그아웃 성공 시 `BroadcastChannel("moeun-auth")`로 알림 → 받은 탭은 store 비우고 `loadPlan()`부터. → #13, #47, #58(시연 절차)
> - **D-079** 허용 출처 = CORS 허용 목록(로컬 기본 비움). JWT 서명 키 없으면 기동 실패, `local` 프로필만 고정 개발 키. → #16, #58
> - **D-080** 정수 금액 필드가 `long` 범위 밖(큰 정수) → `OUT_OF_RANGE`. 비정수 숫자는 본문대로 422 `NOT_INTEGER`, 문자열은 400 `MALFORMED_REQUEST`(Q-070 정정). 프론트는 `Number` 변환 없이 십진 문자열 결과를 JSON 숫자로. → #17, #48
> - **D-081** 목표명: 빈 값·공백뿐 `REQUIRED`, 100자 초과 `OUT_OF_RANGE`, trim 저장, UTF-16, `CUSTOM` 아니면 `null` 저장. → #17, #19
> - **D-082** 보유 자산 칸은 `0`으로 시작, 지우고 저장하면 `REQUIRED`. → #48


> 작성: tech-architect, 2026-11-16. `/negotiate-contract` **4단계(재검토 반영) 마무리본**. 재검토는 끝났다(더 반복하지 않음). 쟁점 X-1~X-3을 사람이 정하면 이 문서를 최종본 `frontend-api-plan.md`로 확정한다.
> - 입력: `frontend-api-plan-v1.md`, `review-frontapi-plan-v1-{provider,consumer}.md`, `frontend-api-plan-v2.md`, `review-frontapi-plan-v2-provider.md`(A팀, "수정하면 수용"), `review-frontapi-plan-v2-consumer.md`(프론트·B팀, "수정하면 수용").
> - 참고(최종본, 다시 정하지 않음): `frontend-api-chat.md`(#12-b), `internal-calc.md`, `plan-context.md`, `docs/decisions.md`(D-001~D-073), `docs/srs.md`, `docs/notion-decisions.md`(TBD-04·05·09·37), moeun(읽기만) `db/{erd,moved-to-code}.md`, `schema.sql`, `backend/.claude/rules/persistence.md`, `calc/{MonthlyPoint,ScenarioResult}.java`.
> - moeun Issue 번호·본문은 두 재검토가 `gh api`로 대조한 값을 쓴다. 이 단계에서 다시 조회하지 않았다.
> - **v1·v2를 합친 자기완결 본문**이다. "v1과 같음" 참조를 모두 풀어 썼다.
>
> **표기**
> - **[v3]**: v2에서 바뀐 줄. 전체 목록은 §W(변경 표). v1 → v2 변경 표(V-1~V-33)는 `frontend-api-plan-v2.md` §V.
> - **⟵ 쟁점 X-n**: 사람이 정한다. 본문에는 기획 추천안을 임시로 적었다. 다르게 정하면 이 표시가 붙은 줄만 바꾼다.
> - 항목 ID(C12a-x, P-x, R-x, Y-x, J-x)는 v1·v2와 같다. 새 항목은 번호를 이어 붙였다.
> - 각 결정 줄에 "왜"를 한 줄 남긴다.

---

## W. v2 → v3 변경 표

| # | 항목 | v2 | v3 | 근거 | 분류 |
|---|---|---|---|---|---|
| W-1 | C12a-6-7 D-072 | #53 훅이 `view.revision === revision`인 순간 판단, 표시는 #52 | **공유 store(#13)의 파생값 `settledStatus`**: `view.revision === revision`이면 `view.status`, 아니면 직전 값. #52(초과 문장)·#53(`revision`)·#54(`view`)는 store를 구독만 | 소비자 O-1(#53 선행이 #52라 #52가 #53 훅을 못 씀). 제공자 영향 없음 | 합의 |
| W-2 | C12a-6-7 규칙 2 | `revision`이 `null`일 때만 `NO_PLAN` 수용, 값이 있으면 무시 | **"요청 시점 `revision`이 `null`이었고 지금 값이 있을 때만" 무시**. 그 밖에는 두 칸을 비우고 입력 화면. F-5·P-5 `NO_PLAN` → 입력 화면 동작 유지 | 소비자 O-2(C12b-7-2·P-5 동작표와 충돌, 데모 초기화 뒤 멈춤). 제공자 2-3(초기화 경로)과 같은 문제 | 합의 |
| W-3 | C12a-6-5 | 언제 부르는지만 | **store의 `loadPlan()`(single-flight) 하나만 `GET /api/plan`을 부른다.** 모든 화면은 이것을 쓴다 | 소비자 O-3(중복 호출, 목 시퀀스 순서 밀림, StrictMode 이중 effect). 기획 보완: 진행 중 요청이 시작된 뒤 `revision`이 바뀌었으면 합류하지 않고 새로 보낸다(아래 C12a-6-5) | 합의 |
| W-4 | C12a-7, J-13 | 키 일부 + "그 밖 v1 J-13 목록" | **문구표 키 전체 목록**(C12a-7-1). `result.alreadyExceeded`(결과 화면, #49)와 `chat.alreadyExceeded`(대화창, #52) 구분, 422 `reason`별 안내 틀·단위 틀, `disclaimer` 키 하나 | 소비자 O-4. 참조가 최종본이 아닌 v1을 가리켜 끊겼다 | 합의 |
| W-5 | C12a-12 | 목 28개 | + `plan/get-plan.seq-exceeded-toggle.json`(`useMock` 전용) → **29개**. README에 "시퀀스 파일은 요청 순서로 소비" | 소비자 목 보강(D-072 "미달 → 초과 → 풀림" 시험) | 합의 |
| W-6 | C12a-5-4 | — | **요청 중 저장 버튼 비활성**(#48) | 소비자 O-6(더블클릭 → 두 번째가 `PLAN_CHANGED`) | 합의 |
| W-7 | C12a-5-6 (f) | `KRW`는 만원 문자열 | **`KRW` 0은 "0원"**(D-061). 그 밖은 만원 | 소비자(heldAssets min 0이 실제 안내에 나옴) | 합의 |
| W-8 | C12a-6-2 | `monthlyPoints[].principal` 있음 | **제거**. 점은 `month`·`afterTaxAsset`만 | 소비자 "빼도 되는 것"(FR-RES-04·#50은 자산선·목표선만). 제공자 이견 없음 | 합의 |
| W-9 | C12a-6-2 | 첫 점은 View 조립(#31)이 붙여도 됨 | **첫 점·점 수는 엔진(#26), 마지막 점은 #27, #9 명세 "k번째 점 = 시작월 + k"**. View(#30·#31)는 복사만, **붙이지 않는다** | 제공자 반대 2-2(납입 시점 TBD-04·05 미정 → View가 붙이면 같은 달 중복, `ScenarioResult` Javadoc). 소비자 이견 없음(계약 규칙은 그대로) | 합의 |
| W-10 | C12a-6-6 | advisory 잠금 + 리스너 같은 메서드 | **조건 4개**: `MANDATORY`, READ COMMITTED·잠금 뒤 조회, 호출 트랜잭션 `readOnly` 금지(#78 본문 한 줄), 리스너 `@ApplicationModuleListener` | 제공자 2-1 | 합의 |
| W-11 | C12a-6-6 계약 문장 | 같은 `revision` 동안 `calcRunId`는 항상 같다 | + **"기준 데이터 활성 버전과 `engine_version`이 그대로인 동안"** | 제공자 2-1 + 소비자 "재적재 없는 한"(같은 뜻, 합침) | 합의 |
| W-12 | C12a-6-7 규칙 2 근거 | "계획 삭제 API가 없어 한 번 생긴 계획은 사라지지 않는다" | **"계획을 지우는 API는 없다. 데모 초기화(#58)는 예외"** + #58 절차에 "초기화 뒤 열린 브라우저는 새로고침" | 제공자 2-3(근거 문장이 틀림) | 합의 |
| W-13 | C12a-5-2 순서 4 | 네이티브 쓰기만 | + **`@Modifying(flushAutomatically = true, clearAutomatically = true)`** + #19 테스트 "저장 직후 같은 트랜잭션의 현재 계획 조회가 새 `revision`·`currentVersionId`" | 제공자 2-5(1차 캐시가 옛 `Plan`을 돌려줘 V-8을 깸) | 합의 |
| W-14 | C12a-5-6 | util은 #48 | util 위치는 **`frontend/src/features/input/**` 밖 공용 폴더**(#48 소유, #51 사용) | 소비자 O-5(#48·#51 paths가 다름) | 합의 |
| W-15 | C12a-2-3 | — | 래퍼: 로그인 화면에서 받은 `UNAUTHENTICATED`는 화면을 다시 이동하지 않는다 | 소비자(2)절 | 합의 |
| W-16 | C12a-16 | J-3·J-5·J-7·J-8·J-14·J-16 배치, 프론트 Issue 보강 미흡 | J-3 #34만, J-5 `persistence.md` 정정 제외·paths 추가, J-7 선행 유지·test paths calc, J-8 선행 #30 유지, **J-14 → #20**, **J-16 → #58**, #12·#13·#47·#48·#49·#50·#52~#54 보강 | 양쪽 `gh api` 대조 | 합의 |
| — | 쟁점 X-1 | 제공자 A 선호, 소비자 의견 없음 | **양쪽 B(100자) 수용**. #19는 100으로 먼저 진행 | 양쪽 재검토 | 쟁점 X-1 (Q-061) |
| — | 쟁점 X-2 | 소비자 요청, 제공자 의견 없음 | **양쪽 A 수용** + 미지 코드 대체 표시, `CUSTOM` 숨김 조건 #48, 데이터 생긴 뒤 코드 변경 주의 | 양쪽 재검토 | 쟁점 X-2 (Q-062) |
| W-17 | 신설 | — | **원격 배포(HTTPS) 작업이 백로그에 없다** → 데모를 로컬로 할지 원격으로 할지 | 제공자 J-16(78개 Issue 전수 확인) | 쟁점 X-3 (Q-063) |

- **v3 합의 16건**(W-1~W-16). v2 합의 31건(V-1~V-18, V-21~V-33)과 합쳐 **47건**. **쟁점 3건**(X-1, X-2, X-3).
- v2 [재검토 확인] 표시 3곳의 결과: V-2(C12a-6-6) → 양쪽 수용, 조건 W-10·W-11. V-12(첫 점) → 담당만 엔진으로(W-9). C12a-6-7 규칙 2 → W-2·W-12로 고침.

---

## C12a-0. 이 계약의 원칙

`frontend-api-chat.md` §0(원칙 1~8)을 그대로 따른다. 이 계약에서 특히 중요한 것:

1. **프론트는 숫자를 만들지 않는다.** 결과 화면의 모든 금액·기간·시점·비율 **문자열**은 Spring `display`를 그대로 쓴다. 왜: CP-04 형식이 Spring `Formatter` 한 곳에만 있어야 "화면 숫자 = AI 숫자 글자까지"(PR-04)가 성립한다. 프론트가 하는 일은 다음뿐이다.
   - (a) `display` 키 찾기, (b) 문구표(CP-05) 키 찾기, (c) 그래프 점 위치 그리기(raw 숫자, 문자열 없음)
   - (d) 입력칸 금액 만원 ↔ 원 변환, (e) 입력칸 'n년 n개월' ↔ 개월 변환, (f) 422 `min`·`max`·`unit`을 입력칸 단위의 안내 문구로 바꾸기(C12a-5-6)
   - (d)(e)(f)는 **프론트 util 파일 하나**에만 둔다(단위 테스트 포함, #48 소유, 공용 폴더 [v3]). 왜: 화면마다 따로 만들면 CP-04가 어긋난다.
2. **회원은 JWT subject로만 정한다.** 본문·쿼리에 `memberId`가 없다.
3. **`revision`은 내 계획 상태의 유일한 버전 표시다.** 모든 쓰기는 `expectedRevision`을 받고 새 `revision`을 돌려준다. 프론트 공유 상태 규칙은 C12a-6-7.
4. **오류 본문은 C3-1 형식 하나**(`ProblemDetail` + `code` + `errors[]`), 기계 판단은 `code`로만. 프론트 API에는 `minDisplay`·`maxDisplay`가 없다(C3-5).
5. **새 라이브러리·새 테이블·새 컬럼 없음.** (쟁점 X-1이 B면 컬럼 **길이** 변경 1줄. 쟁점 X-3이 B면 배포 인프라가 생긴다.)

---

## C12a-1. 범위와 엔드포인트 목록

| ID | 메서드·경로 | 하는 일 | 성공 | 컨트롤러 위치(팀) | 토큰 연장 | 우선순위 |
|---|---|---|---|---|---|---|
| P-1 | `POST /api/auth/login` | 로그인, 쿠키 발급, 이전 대화 삭제 | `200 {}` | `auth.web`(A) | 아니오(`@SkipRenewal`, 핸들러가 발급) | Must |
| P-2 | `POST /api/auth/logout` | 로그아웃, 쿠키 만료, 이전 대화 삭제 | `200 {}` | `auth.web`(A) | 아니오(`@SkipRenewal`) | Must |
| P-3 | `PUT /api/plan` | 입력 저장(새 목표 세우기·입력 수정): 검증 → 저장 → 계산 → 결과, **한 트랜잭션** | `200 PlanView` | `calc.web`(A) | 예 | Must |
| P-4 | `GET /api/plan` | 현재 계획·결과 조회 | `200 PlanView` | `calc.web`(A) | 예 | Must |
| P-5 | `POST /api/plan/undo` | 되돌리기(직전 1단계) | `200 {revision}` | `plan.web`(A) | 예 | Must |
| P-6 | `POST /api/plan/apply` | 대안·비교 결과 적용 | `200 {revision}` | `plan.web`(A) | 예 | Should(#68, D-096). 최종 모양은 moeun `docs/api/frontend-api.md` C12a-9(#246) |

- 대화 비교 적용은 F-5(#12-b)다. P-6은 대화와 무관하다.
- `/api/auth/me`는 두지 않는다. 왜: 앱 시작·새로고침 때 P-4 하나로 "로그인 여부(401) / 계획 없음(409) / 결과(200)"가 갈린다.
- 입력 저장 = 새 목표 세우기 = 입력 수정, 같은 엔드포인트(R-1). 계획이 있으면 시작월을 유지한다(D-013).
- P-3·P-4가 `calc.web`인 이유: 결과 계산이 필요하고 의존 방향은 calc → plan뿐이다. P-3·P-4 컨트롤러는 `/internal/calc` 컨트롤러와 **다른 클래스**다(C12a-11 (h)).

## C12a-2. 인증·쿠키·공통 헤더

#12-b **C12b-2를 그대로 따른다**(JWT HttpOnly 쿠키, `SameSite=Lax` 이상, 같은 사이트·Vite 프록시 `/api`, `credentials: "include"`, 성공 `application/json`, 오류 `application/problem+json`). 이 절은 C12b-2가 #12-a로 미룬 것만 정한다.

### C12a-2-1. 쿠키

| 속성 | 값 | 왜 |
|---|---|---|
| 이름 | `moeun_at` | 서비스 접두어 + access token |
| 값 | JWT(`sub` = memberId, `exp` = 발급 + 30분) | ADR-002, D-052 |
| `HttpOnly` | 항상 | JS가 토큰을 읽지 못하게 |
| `Secure` | 기본 `true`. `auth.cookie.secure=false`는 `local` 프로필에서만 | 로컬 http 탈출구. **데모 접속 주소가 HTTPS가 아니면 `Secure` 쿠키가 저장되지 않아 로그인이 안 될 수 있다** → 데모 방식은 쟁점 X-3, 확인은 #58(J-16) [D-076] |
| `SameSite` | `Lax` | CSRF를 끈 상태의 교차 사이트 방어 |
| `Path` | `/` | 로그아웃 만료 쿠키와 경로가 어긋나지 않게 |
| `Max-Age` | `1800`. 로그아웃·401 때 `0` | FR-AUTH-02 |

- 토큰은 쿠키 `moeun_at`에서만 읽는 `BearerTokenResolver`(#16). `Authorization` 헤더는 받지 않는다.
- 리졸버는 **`POST /api/auth/login`에서 `null`을 돌려준다**. 왜: 리소스 서버 필터는 `permitAll` 경로에서도 토큰을 검증해 실패하면 401을 낸다. 깨진 쿠키가 남은 브라우저가 로그인을 못 하게 된다.
- **JWT 서명 키는 설정값(환경 변수)으로 고정한다.** 왜: 기동마다 새로 만들면 재시작마다 모든 쿠키가 깨진다.
- 401 엔트리 포인트는 C3-1 본문과 함께 `moeun_at` 만료 쿠키(`Max-Age=0`, 같은 속성)를 내린다. 왜: 깨진 쿠키가 남지 않는다.
- `/internal/**`은 다른 필터 체인(API 키), 쿠키를 보지 않는다.

### C12a-2-2. 토큰 연장(D-052)

| 요청 | 새 쿠키 | 왜 |
|---|---|---|
| P-1 로그인 | `@SkipRenewal`. 핸들러가 새 쿠키를 직접 발급 | 다시 로그인할 때 연장 쿠키(옛 회원)와 핸들러 쿠키가 한 응답에 둘 실리지 않게 |
| P-2 로그아웃 | `@SkipRenewal`. 핸들러가 `Max-Age=0`만 | 만료 쿠키 보호 |
| F-2 폴링 | `@SkipRenewal`(C12b-2) | D-052 |
| 그 밖의 인증된 `/api/**` | 연장(인터셉터 `preHandle`, #34) | FR-AUTH-02 |

- 인증이 통과한 요청의 4xx·5xx에도 연장한다. 필터에서 나는 401에는 붙지 않는다.
- Issue #12 수용 기준 문장(R-12): "사용자 조작 요청 중 연장 제외는 F-2뿐이다. 로그인·로그아웃은 핸들러가 쿠키를 직접 내리므로 `@SkipRenewal`을 붙인다."
- 프론트에는 만료 타이머를 두지 않는다(FR-AUTH-02 비고).

### C12a-2-3. 401 처리와 래퍼 규칙

- 보호된 엔드포인트의 쿠키 없음·서명 불일치·만료 → `401 UNAUTHENTICATED`, `errors: []`, `application/problem+json`(+ 만료 쿠키).
- **프론트 래퍼(#13) 규칙**
  1. 분기는 HTTP 상태가 아니라 `code`로만 한다. `code === "UNAUTHENTICATED"`면 로그인 화면. P-1의 `401 INVALID_CREDENTIALS`는 로그인 화면에 머문다. 왜: 상태로 분기하면 로그인 실패 안내 대신 화면 이동이 된다.
  2. 본문이 `application/problem+json`이 아니거나 JSON 파싱에 실패하면(프록시 502, HTML 등) `code`가 없는 것으로 보고 **네트워크 오류 경로**(문구표 `common.networkError`)로 보낸다.
  3. `UNAUTHENTICATED`를 받으면 공유 상태(C12a-6-7)를 비우고 폴링을 멈춘 뒤 로그인 화면으로. P-3 중이었다면 입력값은 잃는다(데모 범위에서 수용).
  4. **[v3]** 이미 로그인 화면에 있으면 화면을 다시 이동하지 않는다(상태 비우기만).
- 403은 쓰지 않는다.

---

## C12a-3. P-1 로그인 `POST /api/auth/login`

FR-AUTH-01, NFR-SEC-01, D-051, D-052.

요청 `{ "loginId": "demo01", "password": "demo-pass-01" }` → 응답:
```http
HTTP/1.1 200 OK
Content-Type: application/json
Set-Cookie: moeun_at=<JWT>; Max-Age=1800; Path=/; Secure; HttpOnly; SameSite=Lax

{}
```

- 본문이 `{}`인 이유: auth는 의존이 `{}`라 계획 유무를 모른다. 프론트는 성공 뒤 `loadPlan()`(P-4)으로 진입을 가른다(#51, C12a-11-2).
- 요청 본문은 단순 record. Jackson의 문자열 강제 변환을 허용한다. `400 MALFORMED_REQUEST`는 **JSON 파싱 실패·본문이 객체가 아님**일 때만. 왜: 로그인에서 400/422를 엄격히 가를 이익이 없다.
- 회원가입 없음. 데모 계정은 시드(#16).

서버 동작: (1) 빈 값 검사(trim 하지 않음) → (2) `member` 조회 + 해시 비교, 실패면 `401 INVALID_CREDENTIALS`(아이디 없음·비밀번호 틀림 구분 없음) → (3) `auth.MemberLoggedIn{memberId}` 발행 → chat 동기 리스너가 이전 대화 삭제(쿠키 전) → (4) JWT 발급, `Set-Cookie`, `200 {}` → (5) 로그 `auth.login`.
- 이미 로그인한 상태의 재로그인도 같은 동작. 삭제 실패면 로그인도 `500`. 시도 횟수 제한 없음.

| HTTP | `code` | 언제 | `errors` | 프론트 동작(#47) |
|---|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | JSON 파싱 실패, 본문이 객체 아님 | `[]` | `auth.loginFailed` |
| 422 | `VALIDATION_FAILED` | `loginId`·`password` 없음·빈 문자열 | `[{field, reason:"REQUIRED"}]` | 입력칸 아래 `validation.REQUIRED` |
| 401 | `INVALID_CREDENTIALS` | 아이디 없음, 비밀번호 틀림, `login_id` 50자 초과 | `[]` | `auth.invalidCredentials`, 로그인 화면 그대로, 비밀번호 칸만 비움 |
| 500 | `INTERNAL_ERROR` | DB 오류, 대화 삭제 실패 | `[]` | `auth.loginFailed` |

## C12a-4. P-2 로그아웃 `POST /api/auth/logout`

FR-AUTH-03, D-051, D-052, NFR-INT-03. 요청 본문 없음(또는 `{}`).

서버 동작: (1) 인증 필수. 만료·없는 토큰이면 `401 UNAUTHENTICATED`(대화 삭제는 다음 로그인 때) → (2) `auth.MemberLoggedOut{memberId}` 발행 → chat 동기 삭제 → (3) 만료 쿠키 + `200 {}`, `@SkipRenewal`.
- 왜 POST: 상태 변경이고 `SameSite=Lax`가 교차 사이트 POST에 쿠키를 싣지 않는다.
- 로그아웃 뒤에도 기존 토큰은 남은 시간 동안 서버에서 유효하다(ADR-002 §3, 데모 범위 수용).

| HTTP | `code` | 프론트 동작 |
|---|---|---|
| 200 | — | 공유 상태 비우기·폴링 중지 → 로그인 화면 |
| 401 | `UNAUTHENTICATED` | 같음(이미 로그아웃된 것과 같다) |
| 500·400·405·415 | 해당 코드 | `auth.logoutFailed` 토스트, 화면 유지 |

---

## C12a-5. P-3 입력 저장 `PUT /api/plan`

FR-INP-01~07·09·10·11, FR-RES-01, CP-02, D-013, D-032, D-035, D-045.

### C12a-5-1. 요청

```json
{
  "expectedRevision": 11,
  "goalType": "HOUSE",
  "goalCustomName": null,
  "goalAmount": 20000000,
  "targetPeriodMonths": 36,
  "heldAssets": 5000000,
  "monthlySavingAmount": 300000,
  "savingsRateInputPct": null,
  "savingsRatioPct": null
}
```

| 필드 | JSON 타입 | 필수 | 뜻 |
|---|---|---|---|
| `expectedRevision` | integer \| null | 키 필수 | 지금 가진 `revision`. 계획이 없다고 믿으면 `null` |
| `goalType` | string | 예 | `GoalType` 코드. 임시 목록은 아래 [D-075] |
| `goalCustomName` | string \| null | `CUSTOM`일 때만 | FR-INP-02(Should). trim 뒤 **1~100자**(UTF-16) [D-074]. CUSTOM이 아니면 무시하고 `null` 저장 |
| `goalAmount` | integer(KRW) | 예 | FR-INP-03 |
| `targetPeriodMonths` | integer(MONTH) | 예(D-045) | FR-INP-04 |
| `heldAssets` | integer(KRW) | 예 | FR-INP-05. 0 허용 |
| `monthlySavingAmount` | integer(KRW) | 예(D-045) | FR-INP-06 |
| `savingsRateInputPct` | number(PCT) \| null | 키 필수 | FR-INP-07. `null` = 기본금리(D-012·D-034) |
| `savingsRatioPct` | integer(PCT) \| null | 키 필수 | **[v4]** FR-INP-08. 적금 비중(%), 0~100 정수. **`null` = 사용자가 정한 비중이 없음** → `plan_version.savings_ratio_pct`에 `NULL`을 저장하고 계산은 기준 데이터의 기본 비중(5:5)을 쓴다. **현재 버전 값을 복사하지 않는다**(R-9의 INPUT 경로 철회) [D-085, D-086] |

- **`goalType` 임시 목록**(enum 선언 순서 = 드롭다운 순서, 표시명 문구표 `goal.<CODE>`) [D-075]:
  `HOUSE`(내 집 마련), `CAR`(자동차), `WEDDING`(결혼), `EDUCATION`(교육), `TRAVEL`(여행), `EMERGENCY_FUND`(비상금), `CUSTOM`(직접 입력). 괄호 안은 문구표 임시 문장.
  - **[v3]** `CUSTOM`은 FR-INP-02(Should)를 구현하지 않은 동안 #48이 드롭다운에서 숨긴다(코드는 둔다). 숨김 조건은 #48 수용 기준에 적는다.
  - **[v3]** 프론트는 문구표에 없는 `goal.<CODE>`를 만나면 **코드 문자열을 그대로 표시**한다(화면이 깨지지 않게). 왜: 서버가 코드를 먼저 더하고 문구가 늦을 수 있다. #18의 "없는 키는 로드 때 실패" 규칙과는 별개로, 표시 helper 한 곳(#48 util 옆)에서만 대체한다.
  - **[v3] 주의(제공자)**: 코드는 `plan_version.goal_type_code`에 저장된다. 데이터가 생긴 뒤 코드를 지우거나 이름을 바꾸면 옛 행을 enum으로 읽을 때 실패한다. 목록 변경은 #19 머지 전이 가장 싸고, 그 뒤면 #58 초기화와 함께 한다.
- **[v4] 요청에 없는 것**: `existingMonthlyContribution`(항상 `NULL`, D-043 — **보내도 서버가 읽지 않고 그냥 무시한다. 400이 아니다**), 시작월(첫 저장이면 요청일이 속한 달 D-032, 아니면 현재 버전 값 복사 D-013), 기준 시나리오(첫 저장이면 `AVG`).
- **[v4] 기본 비중 수치(50)는 기준 데이터 파라미터(`DEFAULT_SAVINGS_RATIO_PCT`) 한 곳에만 있다.** 계약·프론트·plan 코드에 복제하지 않는다(CP-02). `savings_ratio_pct`에 `50`이 들어 있는 것과 `NULL`인 것은 계산 엔진·planContext·대안/비교/대화 재계산·`display`·`assumptions`에서 **같게 취급된다**. 차이는 `PlanView`가 원본을 그대로 내보내는 것 하나뿐이고, 그 차이는 토글 복원(C12a-7)과 가정 보기 표시 조건에만 쓰인다.
- 본문 전체를 `JsonNode`(또는 `Map<String, JsonNode>`)로 받아 `ConditionValidator`에 넘긴다. 왜: 키 없음과 `null`을 구분해야 하고, Boot 기본 `ACCEPT_FLOAT_AS_INT`로 `300000.5`가 잘리지 않게.

### C12a-5-2. 서버 동작과 검사 순서

**`calc.application`의 입력 저장 유스케이스 하나가 `@Transactional`을 연다.** 2~5가 모두 그 안에서 돈다.

| 순서 | 어디서 | 검사·동작 | 결과 |
|---|---|---|---|
| 0 | 필터 | 토큰 | `401 UNAUTHENTICATED` |
| 1 | calc.web | JSON 파싱, 숫자 필드가 JSON 숫자인지, `goalType`이 알려진 코드인지(`plan.GoalType`은 plan 루트 enum), `expectedRevision`이 정수 또는 `null` | `400 MALFORMED_REQUEST` |
| 2 | plan `PlanSaveService`(`REQUIRED` 합류) | **[v4] `PlanInputValidator` 한 길**(범위 수치는 `ConditionValidator`와 **같은 `rules.yml › fields`를 읽는다**): `REQUIRED`·`OUT_OF_RANGE`·`NOT_INTEGER`·`TOO_MANY_DECIMALS`·CUSTOM 이름. 걸린 필드 모두. `INPUT_EDIT`에는 CP-07 개수 제한을 걸지 않는다 | `422 VALIDATION_FAILED` |
| 3 | plan | 계획 있음 + `expectedRevision=null` / 계획 없음 + `≠null` / `plan.revision ≠ expectedRevision` | `409 PLAN_CHANGED` |
| 4 | plan | **[v4]** `plan_version` INSERT(`source='INPUT'`, **시작월만 복사(D-013·D-032), 비중은 요청 값 — `null`이면 `NULL`**) → 첫 저장: 네이티브 `INSERT INTO plan … ON CONFLICT (member_id) DO NOTHING` / 수정: `UPDATE plan SET previous=current, current=:v, revision=revision+1 WHERE member_id=? AND revision=?` → 영향 0행이면 `PlanChangedException` → `PlanChanged(INPUT)` 발행(커밋 뒤 전달) | 0행 → 전체 롤백 `409 PLAN_CHANGED` |
| 5 | calc 결과 조회 서비스(#29) | 현재 계획 스냅샷을 읽고(4에서 바꾼 값), 그 버전의 PLAN `calc_run`이 없으면 계산·기록(회원 잠금, C12a-6-6) → 결과·display | 성공 `200 PlanView` / 실패면 1~4까지 롤백, `500 INTERNAL_ERROR` |

- 왜 한 트랜잭션인가: 부르는 쪽이 calc라 의존 방향(calc → plan)을 그대로 두고 묶을 수 있다. 저장을 먼저 커밋하면 "계산할 수 없는 계획"이 저장되어 P-4 500 → 재저장 409 루프에 갇힌다. ERD Q4-a도 원래 한 트랜잭션이다.
- 왜 네이티브 쿼리인가: `plan.member_id`는 할당 PK라 Spring Data `save()`가 merge를 해 두 탭 경쟁에서 조용히 덮어쓴다. `ON CONFLICT DO NOTHING`은 오류 없이 0행을 돌려준다.
- **[v3] 네이티브 쓰기 뒤 영속성 컨텍스트를 비운다**: `@Modifying(flushAutomatically = true, clearAutomatically = true)`(또는 순서 3의 읽기를 엔티티가 아닌 프로젝션으로, A팀 재량). 왜: 순서 3에서 JPA로 읽은 `Plan` 엔티티가 1차 캐시에 남으면 순서 5의 현재 계획 조회가 **옛 `revision`·`currentVersionId`**를 돌려줘 옛 버전으로 계산하고 PlanView를 만든다(C12a-6-3 4번을 깸). #19 테스트: "저장 직후 같은 트랜잭션의 현재 계획 조회가 새 `revision`·`currentVersionId`를 돌려준다".
- `PlanChanged(INPUT)` 리스너는 커밋 뒤 돌고, 그 버전의 `calc_run(PLAN)`이 이미 있으므로 기록을 건너뛴다(C12a-6-6).
- **[v4] 입력 저장 경로에서 `ConditionValidator.validateChanges`를 쓰지 않는다.** 그 메서드는 `null`을 "바꾸지 않음"으로 보고 바꿀 값이 하나도 없으면 `conditionChanges REQUIRED`를 내므로, 금리·비중을 모두 `null`로 보낸 **정상 요청이 422가 된다**. 검증은 `PlanInputValidator` 한 길이다.
- **[v4] 서버는 요청의 비중을 특별히 다루지 않는다**: "되보낸 값인지", "현재 버전 값과 같은지" 확인하지 않는다(확인을 넣으면 철회한 복사 로직이 되살아난다). 다른 탭이 먼저 비중을 바꾼 뒤 화면이 옛 값을 되보내는 경우는 순서 3의 `expectedRevision` 검사와 순서 4의 조건부 UPDATE가 **409로 이미 막는다**.
- 보유 자산 ≥ 목표는 검증 오류가 아니다. 저장하고 `200`, `result.status = ALREADY_EXCEEDED`(FR-RES-01, CF-03).
- 입력 수정에도 `expectedRevision`을 검사한다(Y-3, PR-08, TBD-37 "버전 확인"). 왜: 다른 탭에서 적용한 계획을 입력 화면의 오래된 값으로 덮어쓰지 않게.

### C12a-5-3. 응답 `200`

P-4와 같은 `PlanView`(C12a-6). 프론트는 이 응답으로 결과 화면을 그리고 P-4를 부르지 않는다. 왜: 한 번의 왕복, 결과 화면 코드 하나.

### C12a-5-4. 오류와 프론트 동작 (#48 입력 화면)

| HTTP | `code` | `errors` | 프론트 동작 |
|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | `[]` | 개발 오류. `input.saveFailed` 토스트, 입력값 유지 |
| 422 | `VALIDATION_FAILED` | 1개 이상 | 각 `field` 입력칸 아래 안내. 문구는 `validation.<reason>` + C12a-5-6 (f) |
| 409 | `PLAN_CHANGED` | `[]` | `plan.changedElsewhere`(취지: "계획이 다른 곳에서 바뀌었어요. 다시 저장하면 입력한 값으로 바뀌어요"). 입력 화면에 머물고 값을 지우지 않는다. `loadPlan()`으로 공유 상태를 새 값으로(`NO_PLAN`이면 C12a-6-7 규칙 2) → 다시 누르면 새 `revision`으로 저장. 다른 탭의 변경을 덮어쓰는 것은 의도된 동작 |
| 401 | `UNAUTHENTICATED` | `[]` | 로그인 화면(C12a-2-3) |
| 500 | `INTERNAL_ERROR` | `[]` | `input.saveFailed` 토스트, 입력값 유지, **P-4를 부르지 않는다**(500이면 계획은 바뀌지 않았다) |

- **[v3] 요청 중에는 저장 버튼을 끈다**(응답이 오면 다시 켬). 왜: 같은 PUT이 두 번 나가면 두 번째가 `409 PLAN_CHANGED`("다른 곳에서 바뀌었어요")가 되어 사용자를 헷갈리게 한다.
- 422 `errors[].field`는 요청 키 이름(camelCase). `goalCustomName` 길이 초과는 `OUT_OF_RANGE`, `min:1, max:100, unit:"CHAR"` [D-074].
- 프론트 사전 검사는 "비어 있음"과 입력 형식(C12a-5-6 숫자 형식)만. 범위 수치는 하드코딩하지 않고 422의 `min`·`max`로 안내한다. 왜: 수치는 `rules.yml` 한 곳.

422 예시 1(범위 + 누락):
```json
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json

{
  "type": "about:blank",
  "title": "입력 범위를 벗어났어요",
  "status": 422,
  "detail": "monthlySavingAmount: OUT_OF_RANGE, targetPeriodMonths: REQUIRED",
  "instance": "/api/plan",
  "code": "VALIDATION_FAILED",
  "errors": [
    { "field": "monthlySavingAmount", "reason": "OUT_OF_RANGE", "min": 10000, "max": 10000000, "unit": "KRW" },
    { "field": "targetPeriodMonths", "reason": "REQUIRED" }
  ]
}
```

422 예시 2(소수):
```json
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json

{
  "type": "about:blank",
  "title": "입력 범위를 벗어났어요",
  "status": 422,
  "detail": "monthlySavingAmount: NOT_INTEGER, savingsRateInputPct: TOO_MANY_DECIMALS",
  "instance": "/api/plan",
  "code": "VALIDATION_FAILED",
  "errors": [
    { "field": "monthlySavingAmount", "reason": "NOT_INTEGER" },
    { "field": "savingsRateInputPct", "reason": "TOO_MANY_DECIMALS", "scale": 2 }
  ]
}
```

### C12a-5-5. 범위 수치 (`rules.yml › input.fields`, 임시)

| 필드 | min | max | unit | scale | 출처 |
|---|---|---|---|---|---|
| `monthlySavingAmount` | 10000 | 10000000 | KRW | 0 | #17·TBD-09·D-043(확정) |
| `savingsRateInputPct` | 0 | 20 | PCT | 2 | internal-calc C3-3 |
| `targetPeriodMonths` | 1 | 360 | MONTH | 0 | internal-calc C3-3 |
| `goalAmount` | 10000 | 10000000000 | KRW | 0 | 임시(R-4). `rules.yml` 주석 "임시" |
| `heldAssets` | 0 | 10000000000 | KRW | 0 | 임시(R-4) |
| `goalCustomName` | 1 | 100 | CHAR | — | TBD-09 [D-074] (A면 50) |
| `savingsRatioPct` | 0 | 100 | PCT | 0 | **[v4]** `rules.yml:13`에 **이미 있다**(코드 변경 없음, 문서를 코드와 맞춘 것) |

- 같은 키는 경로와 무관하게 같은 범위(CP-02). 경로마다 다른 것은 바꿀 수 있는 키 목록뿐.
- `rules.yml`에 금액 `step`은 두지 않는다. 서버는 원 정수면 받는다.
- **[v4] `rules.yml › fields:`는 경로와 무관한 전역 한 벌**이고 경로별 목록은 `change-paths:`뿐이다. `INPUT_EDIT: { all-fields: true, max-fields: 0 }`이라 입력 저장 경로는 처음부터 모든 필드를 허용한다. **`INPUT_EDIT`에 `fields:` 목록을 새로 만들지 않는다**(`all-fields: true`가 깨진다). 같은 키가 경로와 무관하게 같은 범위라는 것(CP-02)은 같은 맵을 읽으므로 구조적으로 보장된다.

### C12a-5-6. 프론트 변환 규칙 (util 하나, #48)

| 규칙 | 내용 | 예 |
|---|---|---|
| (d) 만원 → 원(보낼 때) | 입력 문자열이 `^\d+(\.\d{1,4})?$`이면 **소수점을 오른쪽으로 네 칸 옮기는 문자열 연산**으로 원 정수를 만든다. 부동소수 곱셈 금지. 소수 5자리 이상·형식 오류는 프론트가 막는다(`input.invalidAmountFormat`) | `"30"` → 300000, `"34.5"` → 345000, `"0.0001"` → 1 |
| (d) 원 → 만원(채울 때) | 원 정수 문자열을 왼쪽으로 네 칸 옮기고 끝의 0과 소수점을 지운다. 반올림·내림 없음 | 300000 → `"30"`, 345000 → `"34.5"`, 1 → `"0.0001"` |
| (e) 기간 | 보낼 때 `년 × 12 + 월`, 채울 때 `년 = floor(m / 12)`, `월 = m % 12` | 36 → 3년 0개월 |
| (f) 422 범위 문구 | `KRW`: **[v3] 0이면 `unit.won` 틀로 "0원"(D-061)**, 그 밖은 (d)로 만원 문자열 + 천 단위 쉼표를 `unit.manwon` 틀로("약" 없음, 정확한 값). `MONTH`: `unit.month` "{y}년 {m}개월"(1 → "0년 1개월", 360 → "30년 0개월"). `PCT`: `unit.pct` "연 {값}%"(JSON 숫자 그대로) — **[v4] 단 `field: savingsRatioPct`일 때는 `unit.ratioPct` "{값}%"**(비중 100이 "연 100%"로 잘못 읽힌다). `CHAR`: `unit.char` "{n}자" | `10000000` → "1,000만원", `0` → "0원", `10000000000` → "1,000,000만원" |
| 금리 칸 | `savingsRateInputPct`는 JSON 숫자 그대로 칸에 넣고, 보낼 때 칸 문자열을 JSON 숫자로. 소수 3자리 이상은 서버 `TOO_MANY_DECIMALS` | |

- 단위 테스트(#48): `34.5 ↔ 345000`, `0.0001 ↔ 1`, `30 ↔ 300000`, `12.34567` 거절, `1.1 → 11000`(부동소수 오류 없음), 360 ↔ 30년 0개월, **[v3] KRW 0 → "0원"**.
- **[v3] util 위치**: `frontend/src/features/input/**` **밖** 공용 폴더(예: `frontend/src/shared/units/**`, 이름 재량). #48이 만들고 #51(입력 채우기)이 가져다 쓴다. 왜: 두 Issue의 paths가 달라 한쪽 폴더에 두면 다른 쪽이 paths 밖을 고친다. `goal.<CODE>` 표시 helper(미지 코드 대체)도 같은 폴더.
- 왜 소수 허용인가: 만원 칸(TBD-09)을 유지하면서 대화로 적용한 원 단위 값(345,000원 등)을 잃지 않고 보여 준다. 내림은 값이 조용히 바뀌고, 원 단위 칸은 TBD-09와 다르다.

**[v4] (g) 비중 산출** (FR-INP-08, D-085·D-087) — 같은 공용 폴더 util의 함수 하나. #48이 만들고 #51이 쓴다.

- 적금·ETF 월 납입액 두 칸을 (d)로 원 정수 `a`·`b`로 바꾸고 `s = a + b`.
- `s === 0`이면 **"칸 비움"**으로 본다((h) 참고). 두 칸은 `rules.yml`에 없는 필드라 서버 422가 없고, 프론트는 형식(d)과 음수 불가만 본다. **두 칸에 `REQUIRED`를 걸지 않는다**(빈 칸은 오류가 아니다).
- 그 밖에는 **정수 연산, 0.5는 올림(HALF_UP)**: `r = floor((200 × a + s) / (2 × s))`. 부동소수 `Math.round(a / s * 100)`은 **쓰지 않는다**(12.5·87.5류에서 값이 갈린다). 값이 커지면 `BigInt`.
- 단위 테스트: `(100,20)→83`, `(1,1)→50`, `(1,2)→33`, `(2,1)→67`, `(1,7)→13`, `(7,1)→88`, `(0,5)→0`, `(5,0)→100`, `(0,0)→칸 비움`.
- 양쪽을 다 입력했는데 반올림으로 `0`·`100`이 되는 경우(적금 1원 : ETF 1,000만원)는 **막지 않는다**. 1~99로 조이면 서버 범위와 다른 프론트 하드코딩이 된다. 결과 화면 조건 바가 실제 저장값을 보여 준다.
- **이 util은 금액을 계산하지 않는다.** 비중(비율) 하나만 만든다. 이것이 NFR-INT-01의 예외인 근거는 D-087이다(D-084와 같은 모양).

**[v4] (h) 토글 → 요청 `savingsRatioPct`** (D-086)

| 화면 상태 | 요청 값 |
|---|---|
| 토글 OFF (첫 입력이거나 사용자가 끔) | `null` → `NULL` 저장 → 계산은 기본 비중 |
| 토글 ON + 납입액 칸을 채움 | (g)로 산출한 값 |
| 토글 ON + 납입액 칸 비움(주로 복원) | **가장 최근 응답의 `plan.savingsRatioPct ?? null`을 가공 없이 되보낸다**(= 현재 비중 유지). 되보낼 값이 없으면 `null` |

- **키는 항상 채운다.** `undefined`로 두면 키가 사라져 `422 REQUIRED`가 난다.
- **값의 출처는 "가장 최근 응답"**이다. `revision`을 새로 받는 모든 경로(P-3·P-4·P-5 응답)에서 비중도 같은 응답 값으로 갱신하고, 되보낼 값은 **저장을 누르는 시점의 공유 store(#13)**에서 읽는다. 서버는 이것을 막을 수 없다.
- **`loadPlan()`이 확정되기 전에는 저장 버튼을 비활성**한다. 확정 전에 저장하면 "ON·칸 비움"과 "OFF"를 구분할 수 없어 `null`이 가고 서버에 있던 비중이 지워진다.
- **토글이 OFF면 납입액 두 칸을 비활성**한다. 토글을 끄면 기본 비중으로 돌아간다는 사실은 `input.existingSavingHelp`로 토글 아래 **상시 노출**한다(문구에 "5:5" 수치를 적지 않는다 — 기본 비중은 기준 데이터 한 곳에만).
- 왜 되보내기인가: 비중을 바꾸지 않는 일반 수정(목표 금액만 고침)에서 **대화·대안으로 적용한 비중이 지워지지 않게** 하면서, `null`의 뜻을 "사용자가 정한 비중 없음 = 기본 비중"으로 하나로 유지한다. 화면이 기본 비중 `50`을 만들어 보내는 안은 수치를 두 곳에 두게 되어 쓰지 않는다(CP-02).
- 단위 테스트(#48, 요청 본문 기대값) **6경우**: ① OFF → `null` / ② ON·칸 채움 → 산출값 / ③ 복원 ON·칸 비움 → 응답 값 그대로 / ④ 첫 입력 OFF → `null` / ⑤ OFF → ON으로 켜고 칸 채움 → 산출값 / ⑥ 모든 경우에 키가 본문에 있다.
- **사용자가 토글을 직접 끄고 저장하면 대화·대안으로 적용했던 비중이 기본 비중으로 돌아간다.** D-085의 "나중 변경이 이긴다"에 부합한다(D-086).

---

## C12a-6. P-4 현재 계획·결과 조회 `GET /api/plan`

FR-PLAN-05·06, FR-RES-01~07, FR-INP-11, NFR-INT-02, D-010, D-062, D-072.

### C12a-6-1. 응답 `200` — `PlanView`

```json
{
  "revision": 12,
  "calcRunId": 540,
  "baselineResultScenario": "AVG",
  "plan": {
    "goalType": "HOUSE",
    "goalCustomName": null,
    "goalAmount": 20000000,
    "targetPeriodMonths": 36,
    "heldAssets": 5000000,
    "monthlySavingAmount": 300000,
    "savingsRateInputPct": null,
    "savingsRatioPct": null
  },
  "result": {
    "status": "CALCULATED",
    "goalAmount": 20000000,
    "calcStartMonth": "2026-11",
    "targetMonth": "2029-11",
    "scenarios": [ { "...": "C1a-4 ScenarioResult 그대로(annualReturnPct 없음) + monthlyPoints" } ],
    "assumptions": { "...": "C1a-4 그대로" }
  },
  "display": { "...": "C1a-6 키·형식 그대로" }
}
```

| 필드 | 타입 | 뜻 | 누가 쓰나 |
|---|---|---|---|
| `revision` | integer | `plan.revision` | 공유 상태 `revision`·`view`(C12a-6-7) |
| `calcRunId` | integer | 이 결과의 `calc_run(PLAN)` id. 같은 `revision` 동안 같다(단서 C12a-6-6) | `view` → #54 F-3 |
| `baselineResultScenario` | `GOOD`\|`AVG`\|`BAD`\|null | 결과 요약에 쓸 시나리오(`findBaselineResult()`, 대체 규칙 포함). 초과면 `null` | #49 |
| `plan` | object | 사용자가 입력한 원래 값(원 단위, nullable 그대로). `calcStartMonth`·`baselineScenario` 없음 | #51 입력 채우기 |
| `result` | object | `status`, `goalAmount`, `calcStartMonth`, `targetMonth`, `scenarios[]`(+`monthlyPoints`), `assumptions`만 | 판단·그래프 점 |
| `display` | object | C1a-6 키·형식(접두어 `""`, 조건 `"conditions."`) | 화면의 모든 숫자 문자열 |

- 내보내지 않는 것: `conditions`(raw), `result.annualReturnPct`(수익 약속처럼 읽힐 위험), `result.requiredMonthlySaving`(항상 null), `result.dataVersions`, `result.baselineScenario`·`plan.baselineScenario`, `plan.calcStartMonth`(D-035 안내는 `display["calcStartMonth"]`), `currentVersionId`·`previousVersionId`·`undoAvailable`·`memberId`. 왜: 화면이 쓰지 않는 필드는 화면 전용 View에서 뺀다. 공개 `CalcResultView`·planContext는 그대로다.
- 응답에 문구 키 목록을 넣지 않는다. 프론트가 C12a-7대로 고른다(#30 `tax.note`·#31 D-035 "문구 키" 수용 기준 삭제, Y-13).
- `display`는 planContext와 같은 `ResultDisplayBuilder`(#28)가 같은 접두어로 만든다. `<S>.goalReachMonth`는 `isAchieved=true`일 때만 있다.

### C12a-6-2. `monthlyPoints` [v3]

| 필드 | 이 계약 |
|---|---|
| `scenarios[].monthlyPoints` | 있다(planContext·`/internal/calc`에는 키 자체가 없음) |
| `[].month` | `"YYYY-MM"` |
| `[].afterTaxAsset` | integer(KRW). 그 달의 세후 예상 자산 |

- **[v3] `principal`은 내보내지 않는다.** 왜: FR-RES-04·#50은 자산선과 목표선만 그린다. 점당 숫자가 반이 된다(최대 361점 × 3). 엔진 `MonthlyPoint`의 `principal`은 그대로 두고 View가 옮기지 않을 뿐이다. 원금선이 필요해지면 키 하나를 다시 더한다.
- **규칙**(k = 0 … `targetPeriodMonths`):
  - k번째 점 `month` = `result.calcStartMonth` + k개월. 점 수 = `targetPeriodMonths + 1`, 오름차순.
  - **첫 점(k=0)**: `month = result.calcStartMonth`, `afterTaxAsset = plan.heldAssets`(납입 전 출발점, 보유 자산은 운용 수익 없음 CP-03).
  - **마지막 점(k=N)**: `month = result.targetMonth`, `afterTaxAsset` = 그 시나리오의 `afterTaxAsset`.
  - 왜: 가로축 양 끝 라벨(`display["calcStartMonth"]`·`display["targetMonth"]`)과 점이 맞아야 프론트가 축을 다시 만들지 않는다.
- **[v3] 이 규칙을 지키는 곳은 엔진이다.** #26(시계열 골격): 첫 점·점 수·월 증가. #27: 마지막 점 = 시나리오 값(테스트). #9 계산 명세에 한 줄: "k번째 점 = k번째 납입 뒤의 값, 월 = 시작월 + k(k=0은 납입 전)". **화면 View(#30·#31)는 엔진 목록을 복사만 하고 점을 붙이거나 빼지 않는다**(View 테스트는 복사 확인). 왜: 시계열 정의는 엔진 것이다(`ScenarioResult.monthlyPoints` Javadoc "계산 시작월부터의 월별 예상 자산"). 납입 시점(TBD-04·05)이 #9에서 정해지므로 View가 엔진 관례를 모르고 붙이면 같은 달이 두 번 나올 수 있다.
- 응답 DTO는 `calc.web` 화면 전용 View. 공개 `CalcResultView`(monthlyPoints 없음)는 바꾸지 않는다.

### C12a-6-3. 서버 동작

1. 필터 → `401`.
2. calc 결과 조회 서비스(#29, ERD Q1)가 **plan 공개 현재 계획 조회를 한 번** 부른다. 행이 없으면 `409 NO_PLAN`.
3. 그 스냅샷(`revision`, `currentVersionId`, 입력값, `baselineScenario`)의 버전으로 PLAN `calc_run`을 찾고 없으면 계산·기록(C12a-6-6). 결과 + `ResultDisplayBuilder`.
4. 컨트롤러는 #29가 돌려준 **스냅샷 + 결과 하나**로 `PlanView`를 만든다. 계획을 따로 다시 읽지 않는다. 왜: 두 번 읽으면 사이에 다른 탭의 적용이 끼어 `revision`과 결과가 다른 버전을 가리킨다.

- GET이 `calc_run`을 INSERT할 수 있어 **읽기 전용 트랜잭션이 아니다**(`readOnly=true` 금지, C12a-6-6 조건 3). 재로그인 시 최신 데이터로 다시 계산하지 않는다(D-010).

### C12a-6-4. 오류와 프론트 동작

| HTTP | `code` | 프론트 동작 |
|---|---|---|
| 409 | `NO_PLAN` | C12a-6-7 규칙 2로 처리 → 수용하면 빈 입력 화면(FR-PLAN-06) |
| 401 | `UNAUTHENTICATED` | 로그인 화면 |
| 500 | `INTERNAL_ERROR` | 결과 화면 자리에 `result.loadFailed` + 다시 시도 버튼(`loadPlan()`). 대화창은 그대로 |

- `409 NO_PLAN`(R-10). 왜: `200 {plan:null}`이면 `PlanView`가 nullable이 되어 모든 소비자 분기가 늘어난다.

### C12a-6-5. 언제, 누가 부르나 [v3]

- **[v3] `GET /api/plan`은 공유 store(#13)의 `loadPlan()` 하나만 부른다.** 화면·훅은 `fetch`를 직접 하지 않는다.
- **single-flight**: `loadPlan()`이 불렸을 때 진행 중인 요청이 있고 **그 요청이 지금과 같은 `revision` 값에서 시작됐으면** 같은 약속을 돌려준다. 그 사이 `revision`이 바뀌었으면(F-5·P-5 성공 직후 등) 합류하지 않고 새로 보낸다. 왜: 쓰기 전에 출발한 GET에 합류하면 옛 계획을 받는다. 응답 순서가 뒤바뀌어도 규칙 1(작은 값 무시)이 정리한다. 개발 모드 이중 effect·여러 화면의 동시 마운트가 요청 하나로 합쳐져 목 시퀀스 순서도 밀리지 않는다.
- 부르는 때와 부르는 쪽:

| 때 | 부르는 Issue |
|---|---|
| 앱 시작·새로고침(라우팅 가드) | #47 |
| 로그인 성공 직후 진입 분기 | #51 |
| 결과 화면 500 다시 시도 | #49 |
| P-3 `PLAN_CHANGED` 뒤 | #48 |
| P-5 성공·`NOTHING_TO_UNDO`·`PLAN_CHANGED` 뒤 | #51 |
| F-5 성공·해당 오류 뒤 | #53 |
| F-3 `404` 뒤(C12b-3a) | #54 |
| (P-6 성공 뒤) | #68 |

- P-3 성공 뒤·P-3 500 뒤에는 부르지 않는다.

### C12a-6-6. 같은 계획 버전 = 같은 `calcRunId`

**계약 문장 [v3]**: **기준 데이터 활성 버전과 `engine_version`이 그대로인 동안**, 같은 `revision`(같은 `plan.current_version_id`)에 대해 P-3·P-4가 돌려주는 `calcRunId`는 항상 같다.
- 왜: #54는 "`calcRunId`가 바뀌고 `CALCULATED`면 F-3"(C12b-3a)이라, 같은 계획에서 id가 바뀌면 설명이 한 번 더 생긴다.
- 단서의 뜻: 기준 데이터를 다시 적재하거나 엔진 버전이 바뀌면 ERD Q1-(c)·#29 G-18("활성 버전과 같은 최신 PLAN 기록이 있으면 다시 기록하지 않음")에 따라 같은 계획 버전에 새 행이 생긴다. 숫자가 달라졌다는 뜻이라 #54가 F-3을 다시 부르는 것이 맞다. 해커톤에서는 재배포 때만 생긴다(D-010, D-045).

| 경로 | 같은 버전의 PLAN 기록을 만드는 쪽 | 한 트랜잭션(V-1)만으로 |
|---|---|---|
| P-3 입력 저장 | 유스케이스(트랜잭션 안) → 커밋 뒤 리스너는 기록을 보고 건너뜀 | 풀림 |
| F-5 대화 적용, P-5 되돌리기, (P-6) | 커밋 뒤 리스너 **와** 프론트의 P-4 재조회가 거의 동시에 "없으면 기록" | 안 풀림 → 아래 잠금 |

**구현(#29)**: "현재 버전의 PLAN 기록 확인 → 없으면 계산·기록"을 한 메서드로 두고 확인 전에 `SELECT pg_advisory_xact_lock(...)`로 회원 단위 잠금을 잡는다(PostgreSQL 내장, 새 라이브러리·스키마 변경 없음). `PlanChanged` 리스너도 **같은 메서드**로 기록한다. 늦은 쪽은 앞쪽이 커밋한 행을 보고 건너뛴다.

**[v3] 지켜야 할 조건 4개** (하나라도 어기면 잠금이 무력해져 2행이 생기거나 INSERT가 실패한다)
1. **기록 메서드는 호출자 트랜잭션 안에서만 돈다**: `@Transactional(propagation = MANDATORY)`. 왜: `pg_advisory_xact_lock`은 트랜잭션 끝에 풀린다. 트랜잭션 밖(autocommit)이면 그 문장이 끝나자마자 풀린다. `REQUIRES_NEW`도 안 된다(P-3에서 아직 커밋 안 된 `plan_version`을 못 봐 FK 위반).
2. **격리 수준은 PostgreSQL 기본 READ COMMITTED, 잠금 획득 뒤에 `findLatest`를 실행한다.** 잠금 전에 같은 조회를 해 둔 JPA 결과를 재사용하지 않는다. 왜: REPEATABLE READ면 스냅샷이 잠금 대기 전에 잡혀 앞쪽이 커밋한 행을 못 본다.
3. **호출 트랜잭션은 `readOnly=true`가 아니다.** P-4, planContext `findForCurrentPlan`(#78) 모두. 왜: PostgreSQL이 "read-only transaction"으로 INSERT를 거절한다. #78 본문에 "`findForCurrentPlan`은 readOnly 아님" 한 줄.
4. **리스너는 `@ApplicationModuleListener`**(커밋 뒤, 새 트랜잭션)로 받아 같은 메서드를 부른다. 왜: 같은 트랜잭션의 `@EventListener`면 커밋 전에 돌고 이미 잡은 잠금을 재진입해 의미가 없다.
- (A팀 재량) 잠금 키는 두 인자형 `pg_advisory_xact_lock(<상수 네임스페이스>, memberId)` 권장, `bigint` 하나도 허용. "잠금 없이 조회 → 없으면 잠금 → 다시 조회 → 기록"(이중 확인)도 같은 보장이다.
- 교착 없음: 잠금 순서는 "plan 행 → advisory"(P-3) 하나뿐이고 P-4·리스너·QUESTION은 plan 행을 잠그지 않는다. F-5·P-5는 advisory를 잡지 않는다.
- 기각한 대안: "가장 작은 id 선택" — 경쟁 당사자에게 안정적이지 않고(늦은 쪽은 앞쪽의 미커밋 행을 못 봄), Q1-c 분기에서 옛 행을 계속 고른다. 유일 제약 — 스키마 변경이고 #12-b C12b-7-3이 두지 않기로 했다. `plan` 행 `FOR UPDATE` — 잠금 의미가 모듈 경계를 넘고 F-5가 계산 시간만큼 기다린다.
- 테스트(#29, Testcontainers): 같은 버전에 대해 리스너와 결과 조회를 동시에 실행 → `calc_run(PLAN)` 1행, 두 호출의 `calcRunId` 같음.
- 이로써 #12-b C12b-7-3·plan-context C1a-10의 "2행이 생길 수 있으나 무해"는 "(단서 안에서) 생기지 않는다"로 강해진다(Y-17, J-15).

### C12a-6-7. 프론트 공유 계획 상태 [v3]

공유 store(**#13**이 만드는 것 하나, 팀 공용)는 **두 칸 + 파생값 하나**다.

| 칸 | 값 | 누가 갱신 | 누가 읽나 |
|---|---|---|---|
| `revision` | integer \| null | P-3·P-4 `200`의 `revision`, F-5·P-5·(P-6) `200`의 `revision` | #53 적용 버튼 비활성(D-069), #51 되돌리기 토스트 닫기, 모든 쓰기의 `expectedRevision` |
| `view` | `{revision, calcRunId, status}` + 그 `PlanView` 본문 \| null | P-3·P-4 `200`의 `PlanView`만 | #49·#50 결과 화면, #54 F-3 |
| **`settledStatus`** [v3] (파생) | `CALCULATED`\|`ALREADY_EXCEEDED`\|null | store가 계산: `view.revision === revision`이면 `view.status`, 아니면 **직전 값 유지**. 둘 다 `null`이면 `null` | #52 D-072 초과 문장·버튼 숨김 |

**갱신 규칙**
1. **작은 값으로 덮어쓰지 않는다.** `revision`은 새 값이 지금 값보다 클 때만, `view`는 새 `PlanView.revision`이 지금 `view.revision` 이상일 때만 바꾼다(같으면 `calcRunId`도 같다, C12a-6-6). 왜: 서버 `revision`은 모든 변경에서 1씩만 오르므로 작은 값은 늦게 도착한 옛 응답이다(TBD-37 "최신 응답만 반영").
2. **[v3] `null`로 되돌리는 경우**: 로그아웃 성공, `UNAUTHENTICATED`(래퍼), **`409 NO_PLAN`을 수용할 때**. `NO_PLAN` 수용 규칙은 store 함수 하나(`acceptNoPlan(sentRevision)`, 이름 재량):
   - `sentRevision` = 그 요청을 보낸 시점의 `revision` 칸 값. P-4는 `loadPlan()`이 기록하고, P-5·F-5는 보낸 `expectedRevision`이다(항상 값이 있음).
   - **`sentRevision === null`이었고 지금 `revision`이 값이 있으면 무시한다**(그 사이 P-3이 성공했으니 늦게 온 옛 응답이다).
   - 그 밖에는 **두 칸을 비우고 입력 화면으로 간다**. F-5(C12b-7-2)·P-5(C12a-8-2)의 `NO_PLAN` → 입력 화면 동작은 그대로다.
   - 왜 이 조건뿐인가: 계획을 지우는 API는 없으므로 계획이 있는 동안 보낸 요청이 `NO_PLAN`을 받는 정상 경로는 없다. **예외는 데모 초기화(#58)**다. 이때는 `NO_PLAN`을 받아들여 입력 화면으로 가야 화면이 멈추지 않는다. 초기화 절차에는 "열린 브라우저는 새로고침 또는 다시 로그인"을 적는다(#58, J-16).
3. 최초 로드(`null` → N)는 "바뀜"으로 보지 않는다(#12-b C12b-7-4).

**구독 규칙** (구독 지점은 store 한 곳, 읽는 쪽 셋)
- **D-069(#53)**: `revision` 칸이 바뀌면(최초 로드 제외) 그때 가진 모든 적용 버튼을 끈다. #12-b C12b-7-4 그대로. `revision`이 바뀌기 전에 보낸 F-4 응답이 늦게 `applicable=true`로 와도 비활성 유지.
- **[v3] D-072(#52)**: `settledStatus`를 읽어 초과 문장 표시·지움, 적용 버튼 숨김을 그린다. #52는 #53의 훅을 쓰지 않는다. 왜: #53의 선행이 #52라 반대 방향 의존이 생긴다. F-5·P-5 응답은 `{revision}`뿐이라 `revision`만 먼저 바뀌고 `status`는 P-4가 와야 안다. 바뀐 순간에 판단하면 옛 `status`로 틀린다. "`revision`이 바뀔 때마다 현재 초과 여부로"(D-072)를 정확한 값으로 지키는 해석이며 결정 문장은 그대로다.
- **#54 F-3**: `view.calcRunId`가 바뀌고 `view.status === "CALCULATED"`이면 한 번 부른다(C12b-3a, 초과면 안 부름 D-062).
- **#51 되돌리기 토스트**: 토스트가 들고 있는 값(직전 적용 응답의 `revision`)과 `revision` 칸이 달라지면 닫는다.
- **결과 화면(#49·#50)**: `view`의 `PlanView` 본문만 그린다. 초과 안내는 `view.status`(그 본문 자신의 상태).
- A팀 코드에서 B팀 함수를 부르지 않는다(D-069 취지). 모두 store를 읽기만 한다.

목 흐름(C12a-12)에서 PUT 뒤의 GET이 작은 `revision`을 줘도 규칙 1로 무시된다.

## C12a-7. 결과 화면이 계산하지 않기 위한 대응표

표기는 모두 `display["키"]`(키는 점 포함 평면 문자열). 이 표에 없는 숫자 문자열을 프론트가 만들면 계약 위반이다.

| 영역(SRS, Issue) | 문자열 출처 | 판단에 쓰는 raw |
|---|---|---|
| 조건 바(FR-RES-05, #49) | 목표명: 문구표 `goal.<goalType>`(없으면 코드 문자열) 또는 `plan.goalCustomName`(길어도 줄바꿈·말줄임으로 깨지지 않게). `display["goalAmount"]`, `["conditions.monthlySavingAmount"]`, `["conditions.targetPeriodMonths"]`, `["conditions.savingsRatioPct"]`, `["conditions.savingsRateInputPct"]`, `["conditions.heldAssets"]`, 기본 금리 표시 `result.defaultSavingsRate` | `result.assumptions.isDefaultSavingsRate` |
| 결과 요약(FR-RES-02, #49) | `S = baselineResultScenario`일 때 `display["S.afterTaxAsset"]`, `["S.gapToGoal"]`, `["targetMonth"]`, 문구표 `scenario.<S>` | 그 시나리오 `isAchieved` |
| 3구간(FR-RES-03, #50) | `["GOOD","AVG","BAD"]` 고정 순서로 돌며 `result.scenarios`에 있는 것만 그린다. 칸마다 `display["<S>.afterTaxAsset"]`, `["<S>.gapToGoal"]`, 도달 시점은 `isAchieved`면 `display["<S>.goalReachMonth"]`, 아니면 문구표 `result.notReachedInPeriod`. 아래 고지 한 줄은 `result.scenarioNotice`(D-029) | 시나리오 수(1이면 ETF 0%), `isAchieved` |
| 그래프(FR-RES-04, #50) | 목표선 라벨 `display["goalAmount"]`, 가로축 양 끝 `display["calcStartMonth"]`·`display["targetMonth"]`, 시나리오 최종값 라벨 `display["S.afterTaxAsset"]`. 세로축 눈금 숫자·툴팁·점별 월 라벨은 없다(R-5) | `monthlyPoints[].afterTaxAsset`(점 위치), `result.goalAmount`(목표선 높이) |
| 초과 안내(FR-RES-01, #49) | **문구표 `result.alreadyExceeded`**(결과 화면용) 안에 `display["goalAmount"]`, `display["conditions.heldAssets"]`. 초과 금액 없음 | `view.status === "ALREADY_EXCEEDED"` → 요약·3구간·그래프·대안 숨김, F-3 안 부름(D-062) |
| 가정 보기(FR-RES-06, #49) | `display["assumptions.taxRatePct"]` + 문구표 `tax.note`(D-067), `display["conditions.savingsRateInputPct"]`, `display["assumptions.savingsRateBaseMonth"]`·`["assumptions.sp500BaseDate"]`(없으면 줄 생략), 문구표 `excluded.<CODE>`, `scenarioMethod.<CODE>`. **[v4] CF-08 ② 차액 안내: 문구표 `assumptions.ratioAppliedToAll`(금액 없는 고정 문장) + `display["conditions.savingsRatioPct"]`** | `result.assumptions.excludedItems`, `scenarioMethod`, `isDefaultSavingsRate`. **[v4] 차액 안내 조건은 `plan.savingsRatioPct !== null`** |
| 면책(FR-RES-07, #49) | 문구표 `disclaimer` | — |
| 입력 수정 채우기(FR-INP-11, #51) | 입력칸 값: `plan.*` → C12a-5-6 (d)(e). 현재 비중 읽기 전용 한 줄: `input.currentRatioLabel` + `display["conditions.savingsRatioPct"]`. 재로그인 보유 자산 안내: `input.heldAssetsRecheck`(D-035) + `display["calcStartMonth"]`. **[v4] 토글 복원(D-089): `plan.savingsRatioPct !== null`이면 토글 ON**(값이 `50`이어도 ON), `null`이면 OFF. **납입액 두 칸은 복원하지 않고 비운다**(저장하지 않으므로, D-043) — 빈 칸은 오류가 아니고 도움말 `input.ratioKept`를 둔다 | `plan.savingsRateInputPct === null`이면 금리 칸 비움 |

- **[v4] 차액 안내(CF-08 ②, D-088)에 금액을 쓰지 않는다.** 금액을 쓰면 화면이 "월 저축 가능 금액 − 납입액 합계"를 계산해야 하고(NFR-INT-01), 납입액은 저장하지 않으므로(D-043) 새로고침·재로그인 뒤에는 합계를 알 수 없다. **서버 `display`·`assumptions`에 필드를 더하지 않는다** — 서버는 납입액을 받지 않아 차액을 모른다.
- 대안 영역(Should)은 이 표 밖.

### C12a-7-1. 문구표 키 전체 목록 (#18) [v3, 신설]

이 계약에서 프론트가 쓰는 키 전부. 이름은 #18이 바꿀 수 있지만 **바꾸면 이 표와 #47~#54 본문을 함께 고친다**. 문장은 #18이 정하고 아래 "취지"만 계약이다. 왜: 키가 빠지면 프론트가 문구를 하드코딩해 CP-05를 어긴다.

| 묶음 | 키 | 쓰는 곳 | 취지 |
|---|---|---|---|
| 공통 | `common.networkError` | #13 래퍼 | 비JSON·네트워크 오류. #12-b에 같은 뜻의 키가 있으면 그것을 쓴다 |
| 로그인 | `auth.invalidCredentials` | #47 | 아이디 또는 비밀번호가 맞지 않음 |
| | `auth.loginFailed` | #47 | 로그인하지 못함(400·500) |
| | `auth.logoutFailed` | #47 | 로그아웃하지 못함 |
| 입력 | `input.saveFailed` | #48 | 저장하지 못함(400·500) |
| | `input.invalidAmountFormat` | #48 | 만원 칸 형식 오류·소수 5자리 이상 |
| | `input.currentRatioLabel` | #51 | 현재 비중 읽기 전용 줄의 라벨 |
| | `input.heldAssetsRecheck` | #51 | D-035 재로그인 보유 자산 확인 안내(`{calcStartMonth}` 자리) |
| | **[v4]** `input.existingSavingToggle` | #127 | '지금 하고 있는 저축' 토글 라벨 |
| | **[v4]** `input.existingSavingBank` / `input.existingSavingEtf` | #127 | 적금·ETF 월 납입액 칸 라벨 |
| | **[v4]** `input.existingSavingHelp` | #127 | 토글 아래 상시 노출. 납입액은 비중을 정하는 데만 쓰고 저장하지 않음(D-043) + 끄면 기본 비중으로 돌아감(수치 없이) |
| | **[v4]** `input.ratioKept` | #127 | 토글 ON인데 납입액 칸이 비었을 때 "현재 비중을 그대로 쓴다"는 도움말 |
| 422 안내 틀 | `validation.REQUIRED` | #47·#48 | 값을 입력해 주세요 |
| | `validation.OUT_OF_RANGE` | #48 | `{min}`~`{max}` 사이(자리에 아래 단위 틀 결과) |
| | `validation.NOT_INTEGER` | #48 | 정수로 입력 |
| | `validation.TOO_MANY_DECIMALS` | #48 | 소수 `{scale}`자리까지 |
| 단위 틀 | `unit.manwon` | #48 | `{v}만원` |
| | `unit.won` | #48 | `{v}원`(KRW 0 → "0원", D-061) |
| | `unit.month` | #48 | `{y}년 {m}개월` |
| | `unit.pct` | #48 | `연 {v}%` |
| | **[v4]** `unit.ratioPct` | #127 | `{v}%` (비중 422 문구. `unit.pct`를 쓰면 "연 100%"가 된다) |
| | `unit.char` | #48 | `{n}자` |
| 계획 | `plan.changedElsewhere` | #48·#51 | 계획이 다른 곳에서 바뀌었음. 다시 저장하면 입력한 값으로 바뀜 |
| 되돌리기 | `undo.nothingToUndo` | #51 | 이미 되돌렸음 |
| | `undo.failed` | #51 | 되돌리지 못함 |
| 결과 | `result.loadFailed` | #49 | 결과를 불러오지 못함 + 다시 시도 |
| | **`result.alreadyExceeded`** | #49 | **결과 화면** 초과 안내(FR-RES-01, `{goalAmount}`·`{heldAssets}` 자리) + 목표 수정 안내 |
| | `result.notReachedInPeriod` | #50 | 기간 안에 도달하지 않음(planContext C1a-11 ai 문장과 같은 뜻) |
| | `result.scenarioNotice` | #50 | 3구간 고지 한 줄(D-029) |
| | `result.defaultSavingsRate` | #49 | 기본 금리 표시 |
| | **[v4]** `assumptions.ratioAppliedToAll` | #127 | 가정 보기 차액 안내. **금액 없는 고정 문장**(월 저축 가능 금액 전체를 현재 비중대로 나눠 계산했다) + `display["conditions.savingsRatioPct"]` (CF-08 ②, D-088) |
| 이름 | `goal.<CODE>` | #48·#49 | 7개(쟁점 X-2 목록) |
| | `scenario.GOOD`·`scenario.AVG`·`scenario.BAD` | #49·#50 | 시나리오 이름 |
| planContext 공유 | `tax.note`, `excluded.<CODE>`, `scenarioMethod.<CODE>` | #49 | ai-server와 같은 키(CP-05, D-067) |
| 면책 | **`disclaimer`** | #49, #52 | **키 하나로 확정.** 결과 화면과 대화창이 같은 키를 쓴다. #18 본문에 `chat.disclaimer`가 있으면 `disclaimer`로 바꾼다 |

- **`result.alreadyExceeded`와 `chat.alreadyExceeded`는 다른 키다.** `result.*`는 결과 화면(#49, FR-RES-01), `chat.*`는 대화창(#52, D-072 문장)이다. #18에는 지금 `chat.alreadyExceeded`만 있으므로 `result.alreadyExceeded`를 더한다(Y-18). 둘을 하나로 합치지 않는 이유: 놓이는 화면과 자리 표시(결과 화면은 금액 두 개)가 다르다.
- #12-b H-15의 키(폴링 실패, F-1·F-5 토스트, F-4 카드 실패, `achievementChange`, 조건 라벨)는 그대로 둔다.
- **[v4] `toast.applyStaleComparison`(#12-b·#53)의 문장을 교체한다.** 지금 문장("가장 최근 비교 결과만 적용할 수 있어요")은 원인이 "최신 비교 아님"일 때만 맞다. 입력 화면에서 계획이 바뀐 경우도 같은 `STALE_COMPARISON` 코드라 프론트가 원인을 가를 수 없으므로, 둘을 함께 덮는 문장으로 바꾼다("계획이 바뀌었거나 더 최근 비교가 있어요. 최신 비교를 다시 받아 적용해 주세요"). **새 키·새 오류 코드는 만들지 않는다.**
- **[v4]** 비중이 입력 화면과 대화·대안 양쪽에서 바뀌어도 **비중 전용 처리는 필요 없다**: 같은 탭에서는 D-069가 `revision`이 바뀔 때 적용 버튼을 먼저 끄고, 새로고침 뒤에는 F-4 `applicable=false`가 서버에서 버튼을 끈다. `STALE_COMPARISON` 409는 **다른 탭에서 입력을 저장한 경우**에만 남으며, 입력 저장은 값이 같아도 항상 새 버전이므로 비중 변경이 특별한 경우가 아니다. 모두 v3·#33(CLOSED)·#53 수용 기준에 이미 있는 동작이다.
- 모든 문장에 '추천' 표현을 쓰지 않는다(D-083, CP-06).

---

## C12a-8. P-5 되돌리기 `POST /api/plan/undo`

FR-PLAN-04, D-013, D-041, D-044, D-068, C12b-7-4.

요청 `{ "expectedRevision": 13 }` → 응답 `200 { "revision": 14 }`. 왜 `revision` 하나: 프론트가 다음에 하는 일은 공유 상태 갱신과 `loadPlan()`뿐이다.

- `PlanUndoService`는 **plan 내부(`plan.application`)**. 호출자가 `plan.web`뿐이다(`modulith.md` "루트에는 다른 모듈이 쓰는 것만"). 응답·서비스 반환 모두 `undoAvailable`이 없다(Y-14).

| 순서 | 검사·동작 | 결과 |
|---|---|---|
| 0 | 토큰 | `401 UNAUTHENTICATED` |
| 1 | 본문 파싱, `expectedRevision` 정수 | `400 MALFORMED_REQUEST` |
| 2 | `plan` 읽기. 행 없음 | `409 NO_PLAN` |
| 3 | `previous_version_id IS NULL` | `409 NOTHING_TO_UNDO` |
| 4 | `plan.revision ≠ expectedRevision` | `409 PLAN_CHANGED` |
| 5 | 직전 버전 행을 `source`·`calc_start_month`까지 복사해 새 `plan_version` INSERT(D-068) → `UPDATE plan SET current=:new, previous=NULL, revision=revision+1 WHERE member_id=? AND revision=?` → 0행이면 롤백(`409 PLAN_CHANGED`) → `PlanChanged(UNDO)` | `200 {revision}` |

- 되돌리기는 1단계. 복사 INSERT 덕분에 되돌리기 전 대화 비교는 모두 `applicable=false`·`STALE_COMPARISON`이다(D-068). 시작월은 복사한 값 그대로(D-013). 서버에는 10초 제한이 없다(토스트 시간, D-041).
- 새 버전의 `calc_run(PLAN)`은 리스너 또는 P-4가 기록하며 C12a-6-6 잠금으로 1행이다.

| `code` | 프론트 동작(#51 토스트) |
|---|---|
| (성공) | `revision` 갱신 → 토스트 닫기 → `loadPlan()`(F-3은 #54) |
| `NOTHING_TO_UNDO` | 토스트 닫기 + `undo.nothingToUndo` + `loadPlan()` |
| `PLAN_CHANGED` | 토스트 닫기 + `plan.changedElsewhere` + `loadPlan()` |
| `NO_PLAN` | 토스트 닫기 + `acceptNoPlan(expectedRevision)` → 입력 화면 |
| `UNAUTHENTICATED` | 로그인 화면 |
| `INTERNAL_ERROR` / 네트워크 / `MALFORMED_REQUEST` | `undo.failed` 토스트. 되돌리기 토스트는 남은 시간 동안 그대로 |

- 토스트가 들고 있는 값은 직전 적용 응답(F-5, P-6)의 `revision`. 되돌리기 토스트는 적용 직후에만 띄운다(P-3 뒤에는 없음).

## C12a-9. P-6 대안·비교 적용 `POST /api/plan/apply` — Should, 경로 예약만

> **[D-096, 2026-11-23] 되살렸다**(D-093 변경). 요청 모양·검사 순서·오류·목은 moeun #246에서 확정했고 원본은 moeun `docs/api/frontend-api.md` C12a-9다. 백엔드 #250, 프론트 #259.

- 경로 `POST /api/plan/apply`, 성공 `200 {revision}`, `plan.web`, `PlanApplyService.apply(…, expectedBaseVersionId=null)` 재사용만 예약한다. 요청 모양·오류·목은 **#68**(Should)에서 2주차 말에 확정한다. #33(Must)은 P-6을 들고 있지 않다. 왜: Should를 Must Issue에 두면 Must 완료를 막는다.
- 대화 적용은 F-5뿐이다.

## C12a-10. 오류 공통 규칙과 코드 표

**기계 판단은 HTTP 상태가 아니라 `code`로만 한다.** 형식은 internal-calc C3-1, 공통 규칙은 #12-b C12b-9(Spring 기본 예외 매핑, 500 전역 `INTERNAL_ERROR`, 모듈 예외는 `ErrorResponseException` 상속·`config` 상속 금지, `title`은 임시이며 프론트는 쓰지 않음).

| HTTP | `code` | 엔드포인트 | 언제 | `errors` |
|---|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | P-1~P-6 | 파싱 실패, 타입 불일치(P-1은 파싱 실패·비객체만), 알 수 없는 `goalType` | `[]` |
| 401 | `UNAUTHENTICATED` | P-2~P-6 | 쿠키 없음·서명 불일치·만료 | `[]` |
| 401 | `INVALID_CREDENTIALS` | P-1 | 아이디 없음·비밀번호 틀림 | `[]` |
| 404 | `NOT_FOUND` | 없는 경로 | | `[]` |
| 405 / 415 | `METHOD_NOT_ALLOWED` / `UNSUPPORTED_MEDIA_TYPE` | 전부 | 프론트는 쓰지 않음 | `[]` |
| 409 | `NO_PLAN` | P-4, P-5, (P-6) | 저장된 계획 없음 | `[]` |
| 409 | `PLAN_CHANGED` | P-3, P-5, (P-6) | `expectedRevision` 불일치, 쓰기 0행 | `[]` |
| 409 | `NOTHING_TO_UNDO` | P-5 | `previous_version_id` 없음 | `[]` |
| 422 | `VALIDATION_FAILED` | P-1, P-3, (P-6) | 필드 검증 실패 | 1개 이상 |
| 422 | `FIELD_NOT_CHANGEABLE` | (P-6) | 경로 밖 키 | 1개 이상 |
| 500 | `INTERNAL_ERROR` | 전부 | 예상하지 못한 오류, 결과 계산 실패, 대화 삭제 실패. **P-3의 500은 "저장되지 않았다"** | `[]` |

- `CALC_FAILED`는 이 계약에 나오지 않는다(`/internal/calc` 컨트롤러 한정).
- `errors[]`: `field`, `reason`(`REQUIRED`·`OUT_OF_RANGE`·`NOT_INTEGER`·`TOO_MANY_DECIMALS`·`NOT_CHANGEABLE`), `min`·`max`·`unit`(`KRW`·`MONTH`·`PCT`·`CHAR`), `scale`. `minDisplay`·`maxDisplay` 없음.
- 새 코드 `INVALID_CREDENTIALS`(auth), `NOTHING_TO_UNDO`(plan)는 모듈 예외가 `ErrorResponseException`으로 `code`를 직접 담는다. 전역 advice는 고치지 않는다.

예시(나머지 코드도 같은 모양):
```json
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{ "type": "about:blank", "title": "계획이 없어요", "status": 409,
  "instance": "/api/plan", "code": "NO_PLAN", "errors": [] }
```
```json
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json

{ "type": "about:blank", "title": "아이디 또는 비밀번호가 맞지 않아요", "status": 401,
  "instance": "/api/auth/login", "code": "INVALID_CREDENTIALS", "errors": [] }
```

---

## C12a-11. 모듈 의존과 호출 순서

### C12a-11-1. 의존 표와 시그니처

| 모듈 | 의존(변경 없음) | 이유 |
|---|---|---|
| `auth` | `{}` | 로그인·로그아웃은 `member`만 읽고 이벤트만 발행 |
| `plan` | `{}` | P-5·P-6 컨트롤러는 `plan.web` |
| `calc` | `{plan, refdata}` | P-3·P-4 컨트롤러(`calc.web`)가 plan 공개 저장·조회와 자기 결과 조회를 부른다 |
| `chat` | `{calc, rag, plan, auth}` | #12-b |

```
calc.web(P-3, P-4) ──▶ calc.application(입력 저장 유스케이스 @Transactional, 결과 조회 #29, ResultDisplayBuilder #28)
                                └──▶ plan(PlanSaveService: REQUIRED 합류, 현재 계획 조회)   [calc → plan, 기존]
plan.web(P-5, P-6) ──▶ plan.application(PlanUndoService, PlanApplyService)
auth.web(P-1, P-2) ──▶ auth.application ──publish──▶ MemberLoggedIn/Out ──(동기)──▶ chat
```

지켜야 할 것(C12b-10-2 (a)~(d)에 더해):
- (e) plan 공개 저장 서비스의 인자·반환에 calc·chat·config 타입이 없다.
- (f) `calc.web`은 plan 루트 공개 API만 쓴다. `GoalType`은 plan 루트 enum.
- (g) auth는 plan을 모른다.
- (h) `/internal/calc`의 422 `minDisplay`·`maxDisplay`와 500 `CALC_FAILED`는 **그 컨트롤러 클래스 안의 `@ExceptionHandler`에만** 둔다. 왜: P-3도 `calc.web`이라 패키지 단위 advice면 P-3 422에 `minDisplay`가 붙는다. 테스트 "P-3 422에 `minDisplay` 없음".
- (i) P-3·P-4 응답은 #29가 돌려준 **한 스냅샷**으로 조립한다.
- (j) 같은 계획 버전의 PLAN 기록 확인·기록은 회원 잠금 아래 한 메서드(#29)로만, 조건 4개(C12a-6-6).
- **(k) [v3]** `monthlyPoints`의 점 규칙은 엔진(#26·#27)이 지킨다. 화면 View는 복사만 한다.

```java
// plan 루트 (#19). chat·calc·config 타입 없음.
public interface PlanSaveService {
    /**
     * 입력 저장(INPUT). 호출자 트랜잭션에 합류한다(Propagation.REQUIRED).
     * 검증(INPUT_EDIT) → revision 검사 → plan_version INSERT
     * → plan 네이티브 INSERT ... ON CONFLICT DO NOTHING / UPDATE ... WHERE revision=? (0행이면 PlanChangedException)
     *   네이티브 쓰기는 @Modifying(flushAutomatically = true, clearAutomatically = true)
     * → PlanChanged(INPUT). 시작월·비중은 현재 버전에서 복사(없으면 요청 월·NULL).
     * @param expectedRevision null = 계획이 없다고 믿음
     */
    PlanSaveResult save(long memberId, PlanInput input, Long expectedRevision);
}
public record PlanInput(String goalType, String goalCustomName, Map<String, JsonNode> fields) {}
public record PlanSaveResult(long planVersionId, long revision) {}
public enum GoalType { HOUSE, CAR, WEDDING, EDUCATION, TRAVEL, EMERGENCY_FUND, CUSTOM }  // [D-075]

// plan.application (#33). 공개 API 아님.
interface PlanUndoService { PlanUndoResult undo(long memberId, long expectedRevision); }
record PlanUndoResult(long planVersionId, long revision) {}
```
- 결과 조회 서비스 반환(#29, 이름 재량)은 "현재 계획 스냅샷(`revision`, `currentVersionId`, 입력값, `baselineScenario`) + `calcRunId` + 결과 + display". planContext QUESTION(#78 `findForCurrentPlan`)도 같은 서비스를 쓴다.

### C12a-11-2. 호출 순서

**앱 시작·로그인 → 진입 (FR-PLAN-06)**
```
브라우저(#47 가드) ─loadPlan() → GET /api/plan─▶ 401 → 로그인 화면
브라우저 ─POST /api/auth/login─▶ auth.web (@SkipRenewal, 리졸버는 이 경로에서 토큰을 보지 않음)
  auth: 검증 → 해시 비교 → publish MemberLoggedIn ─(동기)─▶ chat: DELETE chat_message
  auth: JWT 발급 → Set-Cookie moeun_at → 200 {}
브라우저(#51) ─loadPlan() → GET /api/plan─▶ calc.web
  ├ 409 NO_PLAN → acceptNoPlan(null) → 입력 화면
  └ 200 PlanView → revision·view 갱신(settledStatus 확정) → 결과 화면 → (#54) view.calcRunId 바뀜 + CALCULATED → F-3
```

**입력 저장 (FR-INP-10)**
```
브라우저(#48, 버튼 비활성) ─PUT /api/plan {expectedRevision, ...}─▶ calc.web
  calc.application 유스케이스 BEGIN
    plan.PlanSaveService.save (합류: 검증 → revision → INSERT/UPDATE(컨텍스트 비움), 0행이면 예외 → PlanChanged(INPUT))
    #29 결과 조회 (회원 잠금 → 이 버전 PLAN 기록 없음 → 계산·기록) → 스냅샷 + 결과 + display
  COMMIT  (계산 실패면 ROLLBACK → 500, 저장 안 됨)
  ◀─200 PlanView
[커밋 뒤, @ApplicationModuleListener] calc 리스너: 회원 잠금 → 이 버전 PLAN 기록 있음 → 건너뜀
브라우저: revision·view 갱신 → (#53) 버튼 비활성(D-069), (#52) settledStatus로 초과 재판단(D-072), (#54) F-3
```

**되돌리기 (FR-PLAN-04)**
```
브라우저(토스트) ─POST /api/plan/undo {expectedRevision}─▶ plan.web
  plan: 읽기 → NO_PLAN / NOTHING_TO_UNDO / PLAN_CHANGED → 복사 INSERT → 조건부 UPDATE → PlanChanged(UNDO)
  ◀─200 {revision}
브라우저: revision 갱신(버튼 비활성, 토스트 닫힘, settledStatus는 직전 값 유지) → loadPlan()(새 요청)
  → view 갱신 → settledStatus 확정 → 초과 재판단 → (#54) F-3
[커밋 뒤] calc 리스너와 P-4 중 먼저 잠금을 잡은 쪽만 기록 (calcRunId 하나)
```

**로그아웃**
```
브라우저 ─POST /api/auth/logout─▶ auth.web (@SkipRenewal)
  publish MemberLoggedOut ─(동기)─▶ chat: DELETE chat_message → Set-Cookie moeun_at=; Max-Age=0 → 200 {}
브라우저: 두 칸 null(폴링 중지) → 로그인 화면
```

---

## C12a-12. 목(mock) JSON 목록 (`frontend/src/mocks/auth/`, `frontend/src/mocks/plan/`)

**형식·선택 방식은 #12-b C12b-12 그대로**(파일 = `{responses: [...]}`, 요청 키 = 메서드 + 경로, 키마다 기본 파일 하나, 그 밖은 `useMock(파일명)`, 배열 끝을 넘으면 마지막 반복, `status`·`headers` 반영). 새 라이브러리 없음.

- `body`는 줄임표 없이 채운다. REST Docs 스니펫(#16·#30·#31·#33)과 같은 값.
- 기준 계획(A-1 계획): 목표 2,000만원(`HOUSE`), 보유 500만원, 월 30만원, 36개월, 금리 미입력(기본 3.12%), 비중 미입력(5:5), 시작월 2026-11. `result`·`display`는 plan-context 부록 A-1과 글자까지 같다(`calcRunId` 540).
- **[v3] `monthlyPoints` 채우는 규칙(목 전용)**: 시나리오마다 `targetPeriodMonths + 1`점(A-1은 37점), `month` = 2026-11 … 2029-11(k = 0 … 36), `afterTaxAsset = heldAssets + monthlySavingAmount × k + round(그 시나리오 afterTaxGain × k / 36)`. 첫 점 = 보유 자산, 마지막 점 = 시나리오 값(C12a-6-2). `principal` 키 없음.
- 헤더 `Set-Cookie`는 브라우저가 `Response`에 넣지 않는 금지 헤더라 무시된다. 목에서는 설명용이다.
- **기본 파일은 시퀀스**다. 이것 하나로 "앱 시작 → 로그인 → 입력 → 결과 → 대화 적용 → 되돌리기 → 입력 수정"이 목만으로 돈다. #12-b 목과 id가 이어진다.
- **[v3] 시퀀스 파일은 요청 순서로 소비된다.** `GET /api/plan`은 `loadPlan()` single-flight를 거치므로 개발 모드 이중 effect에도 한 번만 소비된다. 이 점을 `frontend/src/mocks/README`에 적는다(#12).

| 순서 | 사용자 동작 | 요청 | 목 응답(기본 파일) |
|---|---|---|---|
| 1 | 앱 시작 | GET /api/plan | `get-plan.seq-full-flow` 1번: `401 UNAUTHENTICATED` → 로그인 화면 |
| 2 | 로그인 | POST /api/auth/login | `post-login.200` |
| 3 | 진입 분기 | GET /api/plan | 2번: `409 NO_PLAN` → 입력 화면 |
| 4 | 결과 보기 | PUT /api/plan | `put-plan.seq-full-flow` 1번: `rev 12 / calcRunId 540` |
| 5 | 대화 적용 | POST /api/chat/messages/1031/apply | `post-apply.200` `{revision: 13}`(#12-b) |
| 6 | 재조회 | GET /api/plan | 3번: `rev 13 / 553`(월 50만원 적용, 3구간 모두 달성) |
| 7 | 되돌리기 | POST /api/plan/undo | `post-undo.200` `{revision: 14}` |
| 8 | 재조회 | GET /api/plan | 4번(마지막, 반복): `rev 14 / 554`(A-1 숫자) |
| 9 | 입력 수정 저장 | PUT /api/plan | 2번(마지막, 반복): `rev 15 / 555`(A-1 계획에서 목표 기간 48개월, 49점) |

| 파일 | 엔드포인트 | 응답 | 내용 |
|---|---|---|---|
| `auth/post-login.200.json` (기본) | P-1 | 200 | `{}` |
| `auth/post-login.401-invalid.json` | P-1 | 401 | `INVALID_CREDENTIALS` |
| `auth/post-login.422.json` | P-1 | 422 | `password` REQUIRED |
| `auth/post-login.500.json` | P-1 | 500 | `INTERNAL_ERROR` |
| `auth/post-logout.200.json` (기본) | P-2 | 200 | `{}` |
| `auth/post-logout.401.json` | P-2 | 401 | `UNAUTHENTICATED` |
| `plan/get-plan.seq-full-flow.json` (기본) | P-4 | 401 → 409 → 200 → 200 | 위 순서 1·3·6·8 |
| **`plan/get-plan.seq-exceeded-toggle.json`** [v3] | P-4 | 200 → 200 → 200 | `useMock` 전용. `rev 12 CALCULATED / 540`(A-1) → `rev 13 ALREADY_EXCEEDED / 542`(`get-plan.200-exceeded` 본문에서 `revision`·`calcRunId`만 바꿈) → `rev 14 CALCULATED / 554`. D-072 "미달 → 초과 → 풀림"과 #54 "초과면 F-3 안 부름" 시험용(F-5 `{13}`·P-5 `{14}` 목과 함께) |
| `plan/get-plan.200.json` | P-4 | 200 | A-1 계획, `rev 12`, `540`, 3구간 모두 미달 |
| `plan/get-plan.200-etf0.json` | P-4 | 200 | plan-context A-2(`541`), AVG 1개, `plan.savingsRatioPct: 100` |
| `plan/get-plan.200-exceeded.json` | P-4 | 200 | plan-context A-3(`542`), `ALREADY_EXCEEDED`, `scenarios: []`, `baselineResultScenario: null` |
| `plan/get-plan.200-after-apply.json` | P-4 | 200 | `rev 13`, `553` |
| `plan/get-plan.200-after-undo.json` | P-4 | 200 | `rev 14`, `554` |
| `plan/get-plan.409-no-plan.json` | P-4 | 409 | `NO_PLAN` |
| `plan/get-plan.401.json` | P-4 | 401 | `UNAUTHENTICATED` |
| `plan/get-plan.500.json` | P-4 | 500 | `INTERNAL_ERROR` |
| `plan/put-plan.seq-full-flow.json` (기본) | P-3 | 200 → 200 | 위 순서 4·9 |
| `plan/put-plan.200.json` | P-3 | 200 | `get-plan.200`과 같은 본문 |
| `plan/put-plan.200-exceeded.json` | P-3 | 200 | `get-plan.200-exceeded`와 같은 본문 |
| `plan/put-plan.422-range.json` | P-3 | 422 | `OUT_OF_RANGE`(`max 10000000`) + `REQUIRED` |
| `plan/put-plan.422-decimals.json` | P-3 | 422 | `NOT_INTEGER` + `TOO_MANY_DECIMALS` `scale 2` |
| `plan/put-plan.422-custom-name.json` | P-3 | 422 | `goalCustomName` `OUT_OF_RANGE`(`min 1, max 100, unit CHAR`) [D-074] |
| `plan/put-plan.409-plan-changed.json` | P-3 | 409 | `PLAN_CHANGED` |
| `plan/put-plan.400.json` | P-3 | 400 | `MALFORMED_REQUEST` |
| `plan/put-plan.500.json` | P-3 | 500 | `INTERNAL_ERROR`(저장 안 됨) |
| `plan/post-undo.200.json` (기본) | P-5 | 200 | `{revision: 14}` |
| `plan/post-undo.409-nothing.json` | P-5 | 409 | `NOTHING_TO_UNDO` |
| `plan/post-undo.409-plan-changed.json` | P-5 | 409 | `PLAN_CHANGED` |
| `plan/post-undo.409-no-plan.json` | P-5 | 409 | `NO_PLAN` |
| `plan/post-undo.500.json` | P-5 | 500 | `INTERNAL_ERROR` |
| **[v4]** `plan/get-plan.200-ratio83.json` | P-4 | 200 | `plan.savingsRatioPct: 83`, `display["conditions.savingsRatioPct"]` "적금 83 : ETF 17". 나머지는 기본 목(A-1) 복사. `useMock` 전용 — 토글 ON 복원·되보내기 시험용 |

- **[v4] 총 31개**(auth 6, plan 25). 요청 오류 전용 목은 만들지 않는다(화면이 항상 0~100을 보내고, 목은 응답 고정 JSON이라 요청을 검증하지 못한다 — 요청 본문은 (h) 단위 테스트로 확인한다). *v3 본문의 "29개"는 `put-plan.422-custom-name`이 빠진 수였다. 현재 파일은 30개이고 `frontend/src/mocks/README.md:11`도 30이라 적고 있어, 이 목을 더해 **31**로 맞춘다.* P-6 목은 없다(#68). 공통 401은 #12-b `chat/common.401-unauthenticated.json` 재사용.
- 9번 뒤의 GET은 마지막 응답(`rev 14`)을 반복한다. C12a-6-7 규칙 1로 무시되어 화면은 `rev 15`를 유지한다.
- Issue #12 수용 기준 "정상, 422, 401, 409": P-1(200·422·401), P-3(200·422·409), P-4(200·409·401), P-5(200·409). 400·500도 있다.

---

## C12a-13. #12-b C12b-13("#12-a에 요구하는 것") 대응표

| # | 요구 | 이 문서 | 상태 |
|---|---|---|---|
| 1 | plan 공개 적용 서비스 `PlanApplyService` | 그대로. P-6이 `expectedBaseVersionId=null`로 재사용(C12a-9). 되돌리기는 plan 내부 `PlanUndoService` | 만족(#33) |
| 2 | 401 엔트리 포인트 C3-1 형식 | C12a-2-1·2-3(+ 만료 쿠키) | 만족(#16) |
| 3 | F-2 `@SkipRenewal` | P-1·P-2에도 `@SkipRenewal`(C12a-2-2) | 만족 + 추가(#34) |
| 4 | 현재 계획·결과에 `revision`·`calcRunId`·`status`, 입력 저장 응답에 `revision` | `PlanView`(C12a-6-1). 같은 버전 = 같은 `calcRunId`(단서 포함, C12a-6-6) | 만족(#29·#30·#31) |
| 5 | 되돌리기 응답 `revision`, D-068 | C12a-8 | 만족(#33) |
| 6 | `ChatComparisonQuery` | 무관(#78) | 해당 없음 |
| 7 | plan 공개 현재 계획 조회에 `currentVersionId` | 공개 API(#19)에 둠, 프론트 응답에는 없음 | 만족(#19) |
| 8 | 이벤트 record·발행·`auth/package-info` | C12a-3·C12a-4 | 만족(#16·#34) |
| 9 | 전역 advice | C12a-10, 새 코드는 모듈 예외 | 만족(#17) |
| 10 | 결과 화면이 `revision`·`calcRunId`·`status`를 공유 상태로 | **store(#13) 두 칸 + `settledStatus`**, `loadPlan()` 하나(C12a-6-5·6-7) | 만족(#13, #49·#51·#52·#53·#54) |

## C12a-14. moeun 현재 코드·문서와 다른 곳 (코드 차이 Y-n)

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| Y-1 | `db/erd.md` §5-G·§3, `db/decision.md` ADR-002 §2-5, `moved-to-code.md` §1 | "로그아웃은 클라이언트가 토큰 삭제" | 서버 로그아웃 + 대화 삭제 | J-14(#20) |
| Y-2 | `config/SecurityConfig.java` | 로그인 보호됨, 헤더 토큰, 기본 엔트리 포인트 | `permitAll`, 쿠키 리졸버(로그인 경로 null), C3-1 401 + 만료 쿠키, 서명 키 설정값 | J-2 |
| Y-3 | `db/erd.md` §4 Q4-a | `ON CONFLICT DO UPDATE`(revision 검사 없음) | `expectedRevision` 검사, 네이티브 `DO NOTHING`/조건부 UPDATE, 0행 409 | J-14(#20) |
| Y-4 | `db/erd.md` §4 Q4-c | 포인터 교체 | 복사 INSERT + 조건부 UPDATE(D-068) | J-9 |
| Y-5 | `persistence.md:14`, `moved-to-code.md` §2, ADR-002 §3 멱등 행 | "0행이면 현재 상태를 돌려준다" | `409 PLAN_CHANGED` + 롤백 | J-9(#33이 이미 고침), ADR-002 §3은 J-14(#20) |
| Y-6 | `backend/CLAUDE.md` 모듈 표 | 컨트롤러 위치 언급 없음 | 조회·입력 저장 REST는 `calc.web`, 되돌리기·대안 적용은 `plan.web` | J-7 |
| Y-7 | `CalcInput.calcStartMonth` 주석 | "재계산할 때는 현재 월" | 입력 수정도 현재 버전 시작월 복사(D-013) | (기존 #25) |
| Y-8 | `b-team-contracts.md` §4, `alignment.md` 2-4 | 옛 A-1·A-2 모양 | F-5·P-5 `{revision}`·D-068 | J-15 |
| Y-9 | `frontend-api-chat.md:413` 422 예시 | `max: 5000000` | `max: 10000000` | J-15 |
| Y-10 | `auth/package-info.java` | 주요 클래스 목록 | + 로그인·로그아웃 컨트롤러, 쿠키 이름 | J-2 |
| Y-11 | `db/erd.md` §4 Q4-a | 한 트랜잭션(같음) | 다른 점은 Y-3뿐 | J-14(#20) |
| Y-12 | #31 수용 기준 | 계획 없음 → `200` + null 키 | `409 NO_PLAN` | J-8 |
| Y-13 | #30·#31 수용 기준 | 응답에 문구 키(`tax.note`, D-035 키) | 응답에 문구 키 없음 | J-7, J-8 |
| Y-14 | #33 수용 기준 | `undoAvailable=true`, P-6 REST | 없음, P-6은 #68 | J-9, J-17 |
| Y-15 | #30·#31 paths·선행 | `plan/**`, `test/.../plan/**` | `calc/web/**`·`calc/application/**`·`test/.../calc/**`, 선행은 C12a-16 | J-7, J-8 |
| Y-16 | `schema.sql` `goal_custom_name VARCHAR(50)` | 50자 | 100자 [D-074] | J-5 |
| Y-17 | `frontend-api-chat.md` C12b-7-3, `plan-context.md` C1a-10 | 같은 버전 PLAN 기록 2행 가능, "무해" | 회원 잠금으로 생기지 않음(단서 안에서) | J-6, J-15 |
| **Y-18** [v3] | #18 문구표 | `chat.alreadyExceeded`만, `disclaimer`·`chat.disclaimer` 혼용 | `result.alreadyExceeded` 추가, `disclaimer` 하나, C12a-7-1 전체 | J-13 |
| **Y-19** [v3] | #49 본문, #52 본문 | #49 "`revision`·`calcRunId`·`status`를 공유 상태로 둔다", #52 "D-069의 구독 지점 하나로 처리" | store는 #13 소유, #49는 읽기, #52는 `settledStatus` 읽기 | J-12c, J-12f |
| **Y-20** [v3] | #27·#31 범위 | 첫 점·점 수를 View(#31)에서 | 엔진 #26(첫 점·점 수)·#27(마지막 점), #9 명세 한 줄 | J-6b, J-8 |
| **Y-21** [v3] | #78 수용 기준 | "메서드별 자체 `@Transactional`(읽기 중심)" | `findForCurrentPlan`은 readOnly 아님(#29 기록 INSERT) | J-6 |
| **Y-22** [v3] | #58 초기화 절차 | 계획·대화 삭제만 | + 열린 브라우저 새로고침, HTTPS/`secure`, 서명 키 환경 변수 | J-16 |

## C12a-15. Issue #12 수용 기준 대응표

| # | 수용 기준 | 이 문서 | 비고 |
|---|---|---|---|
| 1 | 엔드포인트별 요청·응답·오류 예시 | C12a-3~C12a-10 | |
| 2 | plan → chat 의존 없음 | C12a-11-1(plan `{}`) | |
| 3 | 목 JSON으로 정상·422·401·409 | C12a-12(**[v4] 31개**) | |
| 4 | 401 본문 C3-1 | C12a-2-3, C12a-10 | #16 |
| 5 | 422 `min`·`max`·`unit`, display 없음 | C12a-5-4 | |
| 11 | 인증·배포 전제 | C12a-2. 수용 기준 문장을 C12a-2-2의 R-12 문장으로 고친다 | J-1 |
| 13 | #12-a 별도 협상 | 이 문서 | |
| 완료 조건 | `ModularityTests` | C12a-11-1(의존 변경 없음) | |

---

## R. 검토 요청 항목의 결과

| # | 결과 |
|---|---|
| R-1 | 합의: 별도 "새 목표 세우기" 없음. P-3 하나 |
| R-2 | 합의: `401 INVALID_CREDENTIALS` + `code` 분기 |
| R-3 | 합의: 만원 칸 소수 4자리 + 십진 문자열 변환. `step` 없음 |
| R-4 | 합의: 임시 1만원~100억 / 0~100억 |
| R-5 | 합의: 숫자 없는 그래프 |
| R-6 | 합의: `local` 프로필만 false. 데모 방식은 **쟁점 X-3** |
| R-7 | 합의: P-3 응답 = `PlanView` |
| R-8 | 합의: P-6은 #68 |
| R-9 | **[v4] 개정(D-086)**: 입력 저장은 요청의 `savingsRatioPct`를 **그대로 저장**한다(`null` → `NULL` → 계산은 기본 비중). **복사하지 않는다.** 입력 화면은 비중을 정할 수 있다(D-085가 "읽기 전용" 전제를 철회). v3 문장은 "비중 복사 + 입력 화면 읽기 전용"이었다 |
| R-10 | 합의: `409 NO_PLAN` |
| R-11 | 해소: 두 차례 `gh api` 대조 |
| R-12 | 합의: C12a-2-2 문장 |

## X. 쟁점 (사람이 정한다)

### 쟁점 X-1. 직접 입력 목표명 길이: 50자 vs 100자 → Q-061

- **부딪히는 것**: Notion **TBD-09**(결정, "목표명 필수·100자") ↔ moeun `schema.sql` `goal_custom_name VARCHAR(50)`(머지된 DB 설계).
- **선택지**

| 안 | 내용 | 영향 |
|---|---|---|
| A | 50자 유지 | 스키마·코드 변경 없음. TBD-09를 바꾸는 D-번호 기록 필요. `rules.yml` max 50, 목 `max 50` |
| B | 100자로 맞춤 | `schema.sql` `VARCHAR(100)` 1줄 + 엔티티 `@Column(length)` + `db/tables.md` 1줄, `rules.yml` max 100, 목 `max 100`. 운영 데이터가 없어 이전 비용 없음 |

- **의견**: 제공자 **B 수용**(v1의 A 선호를 거둠. 팀 결정을 뒤집는 기록이 더 비싸다. 조건: `schema.sql`·`db/tables.md`를 #19 paths에 추가). 소비자 **B 동의**(프론트는 422 `max`만 읽음, AI 영향 없음. #49 조건 바가 100자에도 깨지지 않게).
- 확인(제공자): `ddl-auto=validate`는 VARCHAR 길이를 검사하지 않는다. 앱 검사 "UTF-16 100자"는 PostgreSQL 문자 수 100보다 항상 엄격해 DB 오류가 나지 않는다.
- **기획 추천: B.** 이미 정한 TBD-09를 따르면 결정 변경이 없고 비용은 몇 줄이다.
- **진행**: 결정 전에도 **#19는 100으로 진행**한다. A로 정해지면 숫자만 바꾼다.
- **심각도 제안: 사소함.** 개발을 막지 않는다(FR-INP-02가 Should, Must 작업은 숫자 하나 차이).

### 쟁점 X-2. 목표 종류(`GoalType`) 목록 → Q-062

- **부딪히는 것**: 결정 없음(새 정책). FR-INP-01은 "1개 선택"만, `moved-to-code.md`는 "enum `GoalType`, 직접 입력은 `CUSTOM`, 선언 순서, 표시명 `goal.<CODE>`"만 정했다.
- **선택지**

| 안 | 내용 | 영향 |
|---|---|---|
| A | 기획 임시 목록: `HOUSE`(내 집 마련), `CAR`(자동차), `WEDDING`(결혼), `EDUCATION`(교육), `TRAVEL`(여행), `EMERGENCY_FUND`(비상금), `CUSTOM`(직접 입력) | 바로 #19 enum, #18 문구, #48 드롭다운, 목에 쓴다 |
| B | 사람이 목록을 새로 정한다 | 정할 때까지 A로 개발하고 정해진 뒤 교체 |

- **의견**: 제공자 **A 수용**(계산은 `goalType`을 쓰지 않고 `goal_type_code VARCHAR(30)`이라 스키마 영향 없음. 주의: 데이터가 생긴 뒤 코드를 지우거나 이름을 바꾸면 옛 행을 enum으로 읽을 때 실패 → 변경은 #19 머지 전, 늦으면 #58 초기화와 함께). 소비자 **A 동의**(요청: 미지 코드 대체 표시, `CUSTOM` 숨김 조건 #48 — 둘 다 본문 C12a-5-1에 반영).
- **기획 추천: A.** 데모용 일반 목표 + 직접 입력이면 충분하고 계산 로직과 무관하다. 목록의 적절성(은행 서비스 맥락에서 빠진 목표가 없는지)만 사람이 확인한다.
- **진행**: 결정 전에도 임시 목록으로 #19·#18·#48 진행.
- **심각도 제안: 개발 중 혼란.** 막지는 않지만 #19 머지 뒤에 바꾸면 비용이 커지므로 **1주차 안**에 정하는 것이 좋다.

### 쟁점 X-3. 데모를 로컬에서 할지, 원격 서버에 배포할지 → Q-063 [v3, 신설]

- **문제**: 제공자가 moeun Issue 78개를 모두 확인했는데 **배포·HTTPS·도메인을 다루는 Issue가 없다**. 가까운 것은 #56(3서버 통합, `docker-compose.yml`), #58(데모 계정·시드·초기화), #63(README·환경 변수). 이 계약의 쿠키는 `Secure`(기본 true)라 **http 원격 주소에서는 로그인이 되지 않는다.** 데모 방식에 따라 `Secure` 설정과 "배포 Issue를 새로 만들지"가 갈린다. 해커톤 제출 조건(심사위원이 자기 기기에서 URL로 접속해야 하는지)은 이 repo 문서에 없어 기획이 알 수 없다.
- **선택지**

| 안 | 내용 | 영향 |
|---|---|---|
| A | **로컬 데모**: 시연 노트북에서 `docker compose up`, 브라우저로 `http://localhost` 접속 | 새 Issue 없음. #58에 시연 절차·`demo` 프로필만. `localhost`는 Chrome·Firefox가 보안 컨텍스트로 봐 `Secure` 쿠키를 받는다. 시연 브라우저로 미리 확인하고, 안 되면 `local`/`demo` 프로필 `secure=false`. 원격 접속은 불가 |
| B | **원격 + HTTPS**: 클라우드 VM 1대에 compose + 리버스 프록시(TLS 인증서) + 도메인 | **배포 Issue 신설**(VM·도메인·인증서·환경 변수·비밀 관리, 3주차 1~2일 추정). 새 인프라. `Secure=true` 그대로. 심사위원이 URL로 접속 가능 |
| C | **원격 + http**: VM에 올리되 TLS 없이 `secure=false` | 배포 Issue는 필요(B보다 작음). 쿠키가 평문으로 오가 NFR-SEC 취지와 어긋나고 금융 서비스 데모로 설명하기 어렵다. **비추천** |

- **기획 추천: A(로컬 데모).** 근거: (1) 백로그 78개에 배포 작업이 없고 3주 일정에 1~2일을 더할 여유가 적다. (2) "새 인프라는 추가하지 않는다"가 기본값이다. (3) 같은 사이트·Vite 프록시 전제(C12b-2)와 `Secure` 쿠키가 `localhost`에서 그대로 성립해 계약을 바꿀 것이 없다. (4) 원격이 꼭 필요해지면 B로 옮기는 비용은 지금 정하든 나중에 정하든 같다. 단, **해커톤 제출 조건이 원격 URL을 요구하면 B**다(C는 고르지 않는다).
- **결정에 따라 바뀌는 것**: C12a-2-1 `Secure` 줄, J-16(#58 내용), B면 새 배포 Issue(team:common, week:3)와 #63 환경 변수 항목.
- **심각도 제안: 개발 중 혼란.** 1~2주차 개발은 로컬에서 같으므로 막지 않는다. 다만 B면 새 Issue가 생겨 일정에 들어가야 하므로 **2주차 말 Should 판단 때까지** 정한다.

---

## C12a-16. 후속 작업 (D-058: 기존 Issue 본문에 반영) [v3]

> 쟁점 의존 표시: **(X-n)**이 붙은 줄은 결정 뒤 숫자·목록만 바꾼다. 나머지는 지금 반영해도 된다. X-1·X-2는 임시값으로 진행하므로 선행으로 막지 않는다.

| # | 작업 | 팀 | Issue | 선행·paths |
|---|---|---|---|---|
| J-1 | `docs/api/frontend-api.md`에 #12-a 절, 목 **29개**(`mocks/auth/`, `mocks/plan/`, 시퀀스 기본 2개, `seq-exceeded-toggle`), `mocks/README`에 "시퀀스는 요청 순서로 소비, `GET /api/plan`은 `loadPlan()` 경유", 수용 기준 `@SkipRenewal` 문장 정정(R-12). **현재 본문에 `mocks/auth/`·`mocks/plan/`이 없으므로 수용 기준에 추가** | 공통 | **#12** | (X-1) 목 `max` 숫자, (X-2) 코드 |
| J-2 | P-1: 엔드포인트, 쿠키 `moeun_at`(`auth.cookie.secure`, `local` 프로필만 false), 쿠키 리졸버(로그인 경로 null), 서명 키 설정값(환경 변수), `permitAll`, 401 엔트리 포인트 + 만료 쿠키, `INVALID_CREDENTIALS`, 422 REQUIRED, 400은 파싱 실패·비객체만, `MemberLoggedIn` 발행, 시드, `auth/package-info`(Y-10). 테스트: 깨진 쿠키를 가진 채 로그인 성공 | A | **#16** | — |
| J-3 | P-2 로그아웃, `@SkipRenewal` 타입과 연장 인터셉터, **P-1·P-2 핸들러의 `@SkipRenewal`은 #34가 붙인다**(조건문 삭제: `@SkipRenewal`을 #34가 만들고 #34 선행이 #16이라 #16은 붙일 수 없다), `MemberLoggedOut` | A | **#34** | — |
| J-4 | `rules.yml › input.fields`(C12a-5-5), `INPUT_EDIT`에 CP-07 없음, `CHAR` 단위, `step` 없음 | A | **#17** | (X-1) `goalCustomName` max |
| J-5 | `PlanSaveService`(`PlanInput` + `Map<String, JsonNode>`, `REQUIRED` 합류), 네이티브 `ON CONFLICT DO NOTHING`/조건부 UPDATE + 0행 `PlanChangedException`, **`@Modifying(flushAutomatically, clearAutomatically)` + 테스트 "저장 직후 같은 트랜잭션의 현재 계획 조회가 새 `revision`·`currentVersionId`"**, 시작월·비중 복사, `PlanChanged(INPUT)`, `GoalType` plan 루트 enum, `goal_custom_name` 길이(Y-16). **`persistence.md:14` 정정은 제외**(#33이 이미 고침), ERD Q4-a 정정은 J-14(#20)로 | A | **#19** | paths 추가: `backend/src/main/resources/db/schema.sql`, `db/tables.md`. 선행 X-1·X-2는 "막지 않음, 임시값(100자·7개)으로 진행" |
| J-6 | 결과 조회 서비스가 스냅샷 + `calcRunId` + 결과 + display 반환, "확인 → 기록"을 advisory 잠금 아래 한 메서드로, 리스너도 같은 메서드, **조건 4개**(`MANDATORY`, READ COMMITTED·잠금 뒤 조회, readOnly 금지, `@ApplicationModuleListener`), 계약 문장 단서(활성 버전·`engine_version`). 테스트: 동시 실행 → 1행·같은 `calcRunId`. **#78 본문에 "`findForCurrentPlan`은 readOnly 아님" 한 줄**(Y-21) | A | **#29** (+ #78 한 줄) | — |
| J-6b | `monthlyPoints`: **#26** 첫 점(k=0, 보유 자산)·점 수(`targetPeriodMonths + 1`)·월 증가, **#27** 마지막 점 = 시나리오 값(테스트), **#9** 명세 "k번째 점 = k번째 납입 뒤, 월 = 시작월 + k" 한 줄 | A | **#26, #27, #9** | — |
| J-7 | `PUT /api/plan`: `calc.web` 별도 컨트롤러 클래스, `calc.application` 한 트랜잭션 유스케이스, 계산 실패 → 롤백 + 500, 응답 `PlanView`(View 조립 첫 구현: `monthlyPoints`는 **복사만** 확인, `principal` 없음), `tax.note` 문구 키 기준 삭제(Y-13), 테스트 "P-3 422에 `minDisplay` 없음"·"계산 실패 시 `plan_version`·`plan` 변화 없음", `backend/CLAUDE.md` 모듈 표 한 줄(Y-6). 제목 `[plan]` → `[calc]` 권장 | A | **#30** | **선행은 덮어쓰지 않는다**(기존 #17·#19·#27·#28·#29 유지). paths: `calc/web/**`·`calc/application/**` 추가, `plan/web/**`는 불필요, `test/.../plan/**` → `test/.../calc/**` |
| J-8 | `GET /api/plan`: `PlanView` 필드(C12a-6-1), `409 NO_PLAN`(Y-12), D-035 문구 키 기준 삭제(Y-13), 스냅샷 조립, readOnly 아님, 화면 전용 View DTO. **"첫 점·점 수" 항목은 빼고 J-6b(엔진)로**, View는 복사만. 제목 `[calc]` 권장 | A | **#31** | **선행 #30 유지** + #19·#28·#29. paths `plan/web/**` → `calc/web/**`, `test/.../calc/**` |
| J-9 | `POST /api/plan/undo`: `PlanUndoService`(plan.application), 검사 순서, 복사 INSERT(D-068), 응답 `{revision}`, `NOTHING_TO_UNDO`, ERD Q4-c(Y-4), `persistence.md:14`·`moved-to-code.md` §2(Y-5, 이미 본문에 있음). `undoAvailable` 삭제, P-6 REST는 #68로(Y-14) | A | **#33** | #20과 `db/erd.md` 동시 진행 금지(#20 먼저) |
| J-10 | display 키가 planContext와 같은 빌더·접두어인지 확인(변경 없음) | A | **#28** | — |
| J-11 | **(1) 래퍼**: `code` 분기(401 기준을 `code === "UNAUTHENTICATED"`로), 비JSON → 네트워크 오류(`common.networkError`), `UNAUTHENTICATED` → 두 칸·폴링 비움, 로그인 화면에서는 다시 이동 안 함, 목 키 5개·시퀀스 기본. **(2) 공유 계획 store**: 두 칸, 작은 값 무시, 파생 `settledStatus`, `acceptNoPlan(sentRevision)`, `loadPlan()` single-flight(같은 `revision`에서 시작한 요청에만 합류). 단위 테스트: 역전 응답 무시, `NO_PLAN` 무시·수용 두 경우, `settledStatus` 직전 값 유지, `loadPlan()` 동시 2회 → 요청 1회, `revision` 바뀐 뒤 → 새 요청 | 공통 | **#13** | paths에 store 폴더 명시(예: `frontend/src/api/planStore/**`). #12-b H-16과 합침 |
| J-12a | 로그인 화면(`INVALID_CREDENTIALS`, 비밀번호 칸 비움, 500), 라우팅 가드(앱 시작 `loadPlan()`), 헤더 로그아웃. **"무엇을 왜"의 "로그인 직후 계획이 있으면 결과 화면…" 문장 삭제(#51 소유)**, 401 수용 기준은 `code === UNAUTHENTICATED` 기준으로 | A | **#47** | — |
| J-12b | 입력 화면: P-3 요청, **변환 util(공용 폴더) + 단위 테스트**(소수 예 `34.5 ↔ 345000`·`0.0001 ↔ 1`·`1.1 → 11000`·`12.34567` 거절·360 ↔ 30년 0개월·KRW 0 → "0원"), `goalType` 드롭다운 + `goal.<CODE>` 대체 표시 helper, **`CUSTOM` 숨김 조건**(FR-INP-02 미구현 동안), 422 필드별 안내(소수 포함, `validation.*`·`unit.*`), `PLAN_CHANGED` 값 유지 + `loadPlan()`, 500 "P-4 안 부름", **요청 중 저장 버튼 비활성** | A | **#48** | paths에 util 공용 폴더(예: `frontend/src/shared/units/**`). (X-2) 목록 |
| J-12c | 결과 화면 1: 요약·조건 바·초과 안내(`result.alreadyExceeded`)·가정 보기·면책(C12a-7), 500 다시 시도(`loadPlan()`). **본문 "공유 상태로 둔다" → "store를 읽는다"(Y-19)**, 조건 바는 긴 목표명(100자)에도 줄바꿈·말줄임으로 깨지지 않음, 결과 화면 컨테이너(`view` 읽기) 폴더를 paths에 | A | **#49** | 선행에 **#13 명시**(지금 `#48, #12`) |
| J-12d | 결과 화면 2: 3구간(`["GOOD","AVG","BAD"]` 고정 순서, 1개 경우, `result.notReachedInPeriod`), `result.scenarioNotice`(D-029), 그래프(숫자 눈금·툴팁 없음, 첫 점 = `calcStartMonth`·보유 자산, 마지막 점 = `targetMonth`·시나리오 값, `afterTaxAsset`만). 이 항목들을 **수용 기준으로 옮긴다**(지금 본문이 짧음) | A | **#50** | 선행에 **#13 명시**(지금 #49만) |
| J-12e | 진입 분기(FR-PLAN-06, `loadPlan()` 사용), 입력 수정 채우기(FR-INP-11, 공용 util 사용), 현재 비중 읽기 전용 줄, D-035 안내(`input.heldAssetsRecheck`), 되돌리기 토스트(`revision` 칸 기준 닫기, 오류별 동작, `NO_PLAN` → `acceptNoPlan`, F-3 없음) | A | **#51** | J-11. #12-b H-11d와 합침 |
| J-12f | **#52**: D-072 초과 문장·버튼 숨김은 store `settledStatus`를 읽는다. 본문 "D-069의 `revision` 구독 지점 하나로 처리" 문장 정정(Y-19), 면책은 `disclaimer`. **#53**: D-069는 `revision` 칸만 본다, F-5 `NO_PLAN` → `acceptNoPlan`, F-5 뒤 `loadPlan()`. paths(`chat/comparison/**`)는 store를 읽기만 하므로 그대로. **#54**: effect 기준을 "`view.calcRunId` 바뀜 + `view.status === CALCULATED`"로 문장 정리(지금 "결과 화면이 그린 `calcRunId`"), F-3 404 뒤 `loadPlan()` | B | **#52, #53, #54** | J-11 |
| J-13 | 문구표 키 **C12a-7-1 전체**. `result.alreadyExceeded` 추가(`chat.alreadyExceeded`와 별개), `disclaimer` 하나로(`chat.disclaimer` 있으면 바꿈), 422 `reason` 틀·단위 틀 | 공통 | **#18** | (X-2) `goal.<CODE>` 문장 |
| J-14 | 문서 정정: `db/erd.md` §5-G·§3 FR-AUTH-03(Y-1), §4 Q4-a(Y-3·Y-11), `db/decision.md` ADR-002 §2-5(Y-1)·§3 멱등 행(Y-5), `moved-to-code.md` §1(Y-1) | 공통 | **#20**(기존 `db/tables.md`·`decision.md`·`moved-to-code.md` 문서 Issue, team:common, week 1) | paths에 `db/erd.md` 추가. **#33보다 먼저**(둘 다 `db/erd.md`, 동시 진행 금지) |
| J-15 | 기획 문서 정정: `b-team-contracts.md` §4·`alignment.md` 2-4(Y-8), `frontend-api-chat.md:413` 예시 `max` 10000000(Y-9), C12b-7-3·plan-context C1a-10 "2행 무해" → "활성 버전·`engine_version`이 그대로인 동안 생기지 않음"(Y-17) | 기획 | project-workspace(협상 마무리 때) | — |
| J-16 | 데모 환경: (1) 접속 주소가 HTTPS인지, 아니면 그 프로필 `auth.cookie.secure=false`(시연 브라우저로 `localhost` `Secure` 쿠키 확인), (2) JWT 서명 키 환경 변수, (3) 초기화 절차에 "열린 브라우저는 새로고침 또는 다시 로그인"(Y-22) | 공통 | **#58** | 프로필 파일을 바꾸면 paths에 `backend/src/main/resources/application-*.yml`. (X-3) B면 새 배포 Issue가 (1)을 가져간다 |
| J-17 | P-6 요청·오류·목 확정(Should, 2주차 말) | A | **#68** | — |

### C12a-16-v4. v4 개정 후속 작업 (D-058: 기존 Issue 본문에 반영) [v4]

> 2026-11-20. 모두 **moeun #127**(`[plan] 지금 하고 있는 저축 토글과 적금:ETF 비중`) 하나에 들어간다. 새 Issue를 만들지 않는다. 자세한 근거는 `frontend-api-plan-v4-proposal.md`.

| # | 작업 | Issue |
|---|---|---|
| K-1 | 요청 필드 수용: `PlanResultController`의 `NULLABLE_REQUIRED_KEYS`·`NUMBER_FIELDS`에 키 추가, `PlanInputValidator.checkOptional` 1줄, `PlanService`의 비중 복사 삭제(요청 값 그대로). 검사 순서 2·4대로, `ConditionValidator.validateChanges` 사용 금지, **`rules.yml`은 손대지 않는다** | #127 |
| K-2 | 서버 테스트 6경우(83 저장 / `null` → `NULL` + 기본 비중 결과 / 101 `OUT_OF_RANGE` / 83.5 `NOT_INTEGER` / 키 누락 `422 REQUIRED` / 문자열 `400`) + `docs/PlanResultDocsTest` 요청 스니펫 | #127 |
| K-3 | 입력 화면: 토글·납입액 두 칸, (g) 산출 util(공용 폴더), (h) 요청 값 표 + 단위 테스트 6경우, 복원 규칙(D-089), `loadPlan()` 확정 전 저장 비활성, OFF면 칸 비활성 | #127 |
| K-4 | 가정 보기 고정 문장(D-088, 금액 없음, 조건 `savingsRatioPct !== null`) | #127 |
| K-5 | 목 `get-plan.200-ratio83.json` 추가(30 → 31), README 개수·`mocks.test.mjs` | #127 |
| K-6 | 문구 키 7개 추가 + `toast.applyStaleComparison` 문장 교체(#18은 CLOSED이므로 키가 필요한 Issue가 더한다) | #127 |
| K-7 | moeun `docs/api/frontend-api.md` 요청 표·범위 표·"요청에 없는 것"(246행) 정정 | #127 |
| K-9 | "토글을 끈 입력 저장은 적용된 비중을 기본 비중으로 되돌린다"를 B팀에 알림 | #64·#66 본문 한 줄 (**후속**) |

> **K-9 보류 (2026-11-20).** 사용자가 보류하기로 했다. 입력 화면을 한 번 거친 뒤에는 조건을 AI 대화로만 바꾸고 결과 화면의 '입력 수정' 버튼을 나중에 없애는 방향이라, 버튼이 사라지면 "토글을 끈 입력 저장" 경로 자체가 없어져 B팀에 알릴 내용이 사라진다. 버튼 제거 범위가 정해지면(`changeable-fields-proposal.md` T-13) 다시 본다.

- `#127` 선행: 계약 v4 합의가 끝나 `status:blocked` → `status:ready`. 코드 선행 #19·#30은 이미 머지돼 추가 선행 없음.
