# 프론트 ↔ Spring 계획·인증 API 계약 v1 (moeun #12-a)

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 1단계 **초안 v1**. 결정이 아니라 검토(제공자 A팀, 소비자 프론트·B팀)를 받을 초안이다.
> - 범위: moeun Issue #12 중 **#12-a(A팀 부분)** — 로그인·로그아웃, 입력 저장(새 목표 세우기·입력 수정), 현재 계획·결과 조회, 되돌리기, 대안 적용(Should, 범위 표시만), 이 API들의 오류 규칙과 목 JSON.
> - 대화 쪽(F-1~F-5)은 확정된 **#12-b 최종본** `frontend-api-chat.md`(머리말 보충 포함)를 따른다. 겹치는 규칙(오류 형식, 쿠키, `@SkipRenewal`, 목 선택 방식, `revision` 뜻)은 **재사용·참조만** 하고 다시 정하지 않는다.
> - 입력: `/tmp/issue12.md`(Issue #12 본문), `b-team-contracts.md` §4(A-1, A-2), `alignment.md` 2-1·2-4·2-5, 최종본 `frontend-api-chat.md`·`internal-calc.md`·`plan-context.md`, `docs/decisions.md`(D-001~D-073), `docs/srs.md`, `docs/open-questions.md`, moeun(origin/develop, 읽기만) `backend/CLAUDE.md`·`.claude/rules/{modulith,persistence}.md`·`SecurityConfig`·`auth`/`plan` `package-info.java`·`calc/{CalcResult,ScenarioResult,MonthlyPoint}.java`·`db/{erd,decision,moved-to-code}.md`·`schema.sql`.
> - **확인하지 못한 것**: 이 단계에는 셸이 없어 moeun Issue 본문(#16, #17, #19, #29~#31, #33, #34, #47~#51 등)을 `gh api`로 다시 조회하지 못했다. Issue 번호와 담당은 #12-b 최종본(C12b-13·C12b-18)에 적힌 것을 썼고, 프론트 화면 Issue 번호 중 #12-b에 없는 것(#48, #50)은 **추정**이라 `(추정)`을 붙였다. 검토자가 본문과 대조해 주기를 요청한다(R-11).
>
> **표기**
> - 엔드포인트 ID는 **P-n**(계획·인증)이다. #12-b의 F-n, b-team-contracts의 A-n과 겹치지 않게 했다.
> - **R-n**: 이 초안에서 정할 수 없거나 검토자가 판단해야 할 것. 본문에는 기획 추천안을 임시로 적고 `⟵ R-n`을 단다.
> - 각 결정 줄에 "왜"를 한 줄 남긴다.

## C12a-0. 이 계약의 원칙

`frontend-api-chat.md` §0(원칙 1~8)을 그대로 따른다. 이 계약에서 특히 중요한 것:

1. **프론트는 숫자를 만들지 않는다.** 결과 화면의 모든 금액·기간·시점·비율 **문자열**은 Spring `display`를 그대로 쓴다. 프론트가 하는 일은 (a) `display` 키 찾기, (b) 문구표(CP-05) 키 찾기, (c) 그래프의 점 위치 그리기(raw 숫자), (d) 입력 폼의 단위 환산(만원 ↔ 원, C12a-5-4)뿐이다. 왜: CP-04 형식(반올림·부호·경계)이 Spring `Formatter` 한 곳에만 있어야 "화면 숫자 = AI 숫자 글자까지"(PR-04)가 성립한다.
2. **회원은 JWT subject로만 정한다.** 본문·쿼리에 `memberId`가 없다(`persistence.md`).
3. **`revision`은 내 계획 상태의 유일한 버전 표시다.** 모든 쓰기(입력 저장·되돌리기·대화 적용·대안 적용)는 `expectedRevision`을 받고 새 `revision`을 돌려준다. 프론트는 이 값 하나를 공유 상태로 두고, 대화창(#53)은 그 변화를 구독한다(D-069, C12b-7-4).
4. **오류 본문은 C3-1 형식 하나**(`ProblemDetail` + `code` + `errors[]`), 기계 판단은 `code`로만. 프론트 API에는 `errors[].minDisplay`·`maxDisplay`가 없다(C3-5).
5. **새 라이브러리·새 테이블·새 컬럼 없음.**

---

## C12a-1. 범위와 엔드포인트 목록

| ID | 메서드·경로 | 하는 일 | 성공 | 컨트롤러 위치(팀) | 토큰 연장 | 우선순위 |
|---|---|---|---|---|---|---|
| P-1 | `POST /api/auth/login` | 로그인, 쿠키 발급, 이전 대화 삭제 | `200 {}` | `auth.web`(A) | (발급) | Must |
| P-2 | `POST /api/auth/logout` | 로그아웃, 쿠키 만료, 이전 대화 삭제 | `200 {}` | `auth.web`(A) | **아니오**(`@SkipRenewal`) | Must |
| P-3 | `PUT /api/plan` | 입력 저장(새 목표 세우기·입력 수정): 검증 → 저장 → 계산 → 결과 | `200 PlanView` | **`calc.web`**(A) | 예 | Must |
| P-4 | `GET /api/plan` | 현재 계획·결과 조회(로그인 직후 진입, 결과 화면, 재조회) | `200 PlanView` | **`calc.web`**(A) | 예 | Must |
| P-5 | `POST /api/plan/undo` | 되돌리기(직전 1단계) | `200 {revision}` | `plan.web`(A) | 예 | Must |
| P-6 | `POST /api/plan/apply` | 대안·비교 결과 적용 | `200 {revision}` | `plan.web`(A) | 예 | **Should(예약만)** |

- 대화 비교 적용은 F-5(`POST /api/chat/messages/{id}/apply`, #12-b)다. P-6은 대화와 무관하다.
- 별도 "내 정보" 엔드포인트(`/api/auth/me`)는 두지 않는다. 왜: 앱 시작·새로고침 때 P-4 하나로 "로그인 여부(401) / 계획 없음(409) / 결과(200)"가 모두 갈린다. 헤더에 아이디를 보여 줄 요구도 없다(FR-AUTH-03은 로그아웃 버튼만).
- 입력 저장은 "새 목표 세우기"와 "입력 수정"이 **같은 엔드포인트**다(ERD Q4-a "입력 수정 저장도 같은 경로"). 차이는 계획이 이미 있는지뿐이고 서버가 판단한다. ⟵ R-1
- P-3·P-4가 `calc.web`인 이유: 결과를 계산해야 하는데 `plan`은 의존이 `{}`라 calc를 부를 수 없다. 의존 방향 calc → plan 그대로 둔다(C12a-11).

## C12a-2. 인증·쿠키·공통 헤더

#12-b **C12b-2를 그대로 따른다**(JWT HttpOnly 쿠키, `SameSite=Lax` 이상 필수, 같은 사이트 배포·Vite 프록시 `/api`, `credentials: "include"`, 성공 `application/json`, 오류 `application/problem+json`, `memberId`는 Spring Security 타입으로만). 이 절은 C12b-2가 #12-a로 미룬 것만 정한다.

### C12a-2-1. 쿠키 (C12b-2 "쿠키 이름은 #12-a")

| 속성 | 값 | 왜 |
|---|---|---|
| 이름 | **`moeun_at`** | 서비스 접두어 + access token. 쿠키가 하나뿐이라 짧게 |
| 값 | JWT(서명, `sub` = memberId, `exp` = 발급 + 30분) | ADR-002, D-052 |
| `HttpOnly` | 항상 | JS가 토큰을 읽지 못하게(ADR-002 위험 1) |
| `Secure` | 기본 `true`. 설정 `auth.cookie.secure`로 끌 수 있음(로컬 http 전용) | Chrome·Firefox는 `localhost`를 보안 컨텍스트로 봐 `Secure` 쿠키를 받지만, 브라우저·도구 차이로 막힐 때를 대비한 탈출구. 운영(데모 서버)은 `true` ⟵ R-6 |
| `SameSite` | **`Lax`** | C12b-2. CSRF를 끈 상태의 유일한 교차 사이트 방어 |
| `Path` | `/` | 프론트 정적 파일과 `/api`가 같은 사이트. 경로를 나누면 로그아웃 만료 쿠키와 경로가 어긋날 위험만 생김 |
| `Max-Age` | `1800`(30분). 로그아웃 때 `0` | FR-AUTH-02. 브라우저 쿠키 수명과 JWT `exp`를 같게 둔다 |

- **토큰을 읽는 곳**: 리소스 서버 기본값은 `Authorization` 헤더라, #16이 쿠키 `moeun_at`에서 읽는 `BearerTokenResolver`를 등록한다. `Authorization` 헤더는 받지 않는다. 왜: 토큰 경로를 하나로 두면 프론트가 헤더를 만들 일이 없다.
- `/internal/**`은 다른 필터 체인(API 키)이다(internal-calc C2-1). 쿠키를 보지 않는다.

### C12a-2-2. 토큰 연장(D-052)

| 요청 | 새 쿠키 | 왜 |
|---|---|---|
| P-1 로그인 | 핸들러가 발급 | 인증 전이라 연장 필터 대상이 아님 |
| P-2 로그아웃 | **`@SkipRenewal`** — 핸들러가 `Max-Age=0`만 내림 | 연장 필터가 같은 이름의 새 쿠키를 함께 내리면 만료가 무시될 수 있다(같은 응답에 `Set-Cookie` 두 개) |
| F-2 폴링 | `@SkipRenewal`(C12b-2) | D-052 |
| 그 밖의 인증된 `/api/**`(P-3~P-6, F-1, F-3~F-5) | `TokenRenewalFilter`(또는 인터셉터, C12b-2 구현 메모)가 내림 | FR-AUTH-02 "서버로 가는 요청이 30분 없으면 만료" |

- 오류 응답(4xx·5xx)에도 인증이 통과했다면 연장한다. 왜: 사용자가 버튼을 누른 것(조작)은 같다. 구현이 "인증됨 + `@SkipRenewal` 아님" 한 조건이라 단순하다.
- 프론트에는 만료 타이머를 두지 않는다(FR-AUTH-02 비고).

### C12a-2-3. 401 처리 (C12b-2·C12b-9와 같음)

- 보호된 엔드포인트에 쿠키 없음·서명 불일치·만료 → `401 UNAUTHENTICATED`, `errors: []`, `application/problem+json`. 본문은 리소스 서버 `AuthenticationEntryPoint`(#16)가 C3-1 형식으로 쓴다(`instance`는 없을 수 있음).
- **프론트 래퍼의 401 분기는 HTTP 상태가 아니라 `code`로 한다**: `code === "UNAUTHENTICATED"`면 로그인 화면으로 보낸다. 왜: P-1의 로그인 실패도 HTTP 401(`INVALID_CREDENTIALS`, C12a-3)이라, 상태로 분기하면 로그인 화면에서 "아이디·비밀번호 오류" 안내 대신 로그인 화면으로 다시 이동하는 동작이 된다. C12b §0 원칙 7("기계 판단은 `code`로만")과 같다. ⟵ R-2
- 403은 쓰지 않는다(C12b-9).

---

## C12a-3. P-1 로그인 `POST /api/auth/login`

FR-AUTH-01, NFR-SEC-01, D-051, D-052.

요청:
```json
{ "loginId": "demo01", "password": "demo-pass-01" }
```

응답 `200`:
```http
HTTP/1.1 200 OK
Content-Type: application/json
Set-Cookie: moeun_at=<JWT>; Max-Age=1800; Path=/; Secure; HttpOnly; SameSite=Lax

{}
```

- 본문은 빈 객체다. 왜: auth는 의존이 `{}`라 "계획이 있는지"를 알 수 없다(auth → plan 의존을 만들지 않는다). 프론트는 성공 뒤 **P-4를 불러** `200`이면 결과 화면, `409 NO_PLAN`이면 빈 입력 화면으로 간다(FR-PLAN-06). 결과 화면은 어차피 P-4가 필요하므로 왕복이 늘지 않는다. `{}`인 이유는 C12b-3a와 같다(래퍼가 성공 본문을 항상 JSON으로 읽음).
- 회원가입 없음(FR-AUTH-01). 데모 계정은 미리 넣는다(#16 시드).

서버 동작:
1. `loginId`·`password`가 비었는지 검사(trim 하지 않음. 비밀번호의 공백도 값이다).
2. `member` 조회 + 해시 비교(NFR-SEC-01). 실패하면 `401 INVALID_CREDENTIALS`(아이디 없음과 비밀번호 틀림을 구분하지 않음).
3. **`auth.MemberLoggedIn{memberId}` 발행** → chat 동기 리스너가 이전 대화 일괄 삭제(C12b-8). 쿠키를 내리기 **전**.
4. JWT 발급, `Set-Cookie`, `200 {}`.
5. 로그 `auth.login {memberId, at}`(moved-to-code §2).

- 이미 로그인한 상태에서 다시 로그인해도 같은 동작(대화 삭제 + 새 쿠키). 왜: 분기를 두지 않는다.
- 3에서 삭제가 실패하면 로그인도 `500 INTERNAL_ERROR`(C12b-8: D-030 쪽이 안전).
- 로그인 시도 횟수 제한은 두지 않는다(데모 계정, 범위 밖).

오류:

| HTTP | `code` | 언제 | `errors` | 프론트 동작 |
|---|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | JSON 파싱 실패, 필드가 문자열이 아님 | `[]` | "로그인하지 못했어요" |
| 422 | `VALIDATION_FAILED` | `loginId`·`password`가 없거나 빈 문자열 | `[{field, reason:"REQUIRED"}]` 걸린 것 모두 | 입력칸 아래 안내(프론트도 같은 검사를 먼저 해서 보통은 오지 않음) |
| 401 | `INVALID_CREDENTIALS` | 아이디 없음, 비밀번호 틀림 | `[]` | "아이디 또는 비밀번호가 맞지 않아요"(문구표). **로그인 화면 그대로, 비밀번호 칸만 비움** |
| 500 | `INTERNAL_ERROR` | DB 오류, 대화 삭제 실패 | `[]` | "로그인하지 못했어요"(#47, C12b-8) |

- 길이 상한(`login_id` 50자) 초과는 422가 아니라 `401 INVALID_CREDENTIALS`다. 왜: 그런 계정은 없고, 규칙을 드러낼 이유가 없다.

## C12a-4. P-2 로그아웃 `POST /api/auth/logout`

FR-AUTH-03, D-051, D-052, NFR-INT-03.

요청: 본문 없음(또는 `{}`). 응답 `200`:
```http
HTTP/1.1 200 OK
Content-Type: application/json
Set-Cookie: moeun_at=; Max-Age=0; Path=/; Secure; HttpOnly; SameSite=Lax

{}
```

서버 동작:
1. 인증 필수(필터). 만료·없는 토큰이면 `401 UNAUTHENTICATED`이고 대화 삭제는 다음 로그인 때 된다(C12b-8, NFR-INT-03 예외 수용 기준).
2. **`auth.MemberLoggedOut{memberId}` 발행** → chat 동기 삭제(C12b-8). 쿠키를 만료시키기 **전**.
3. 만료 쿠키(`Max-Age=0`, 같은 이름·`Path`·속성) + `200 {}`. 핸들러에 `@SkipRenewal`(C12a-2-2).

- 왜 POST: 상태를 바꾸는 요청이고, `SameSite=Lax`는 교차 사이트 POST에 쿠키를 싣지 않아 외부 링크로 로그아웃시키는 장난을 막는다.
- 로그아웃 뒤에도 기존 토큰은 남은 시간 동안 서버에서 유효하다(ADR-002 §3, 위험 1). 쿠키를 지웠으므로 정상 브라우저에는 영향이 없다. 데모 범위에서 수용(alignment 2-1).

오류와 프론트 동작:

| HTTP | `code` | 프론트 동작 |
|---|---|---|
| 401 | `UNAUTHENTICATED` | **로그인 화면으로**(이미 로그아웃된 것과 같다) |
| 500 | `INTERNAL_ERROR` | "로그아웃하지 못했어요" 토스트, 화면 유지(쿠키가 남아 있으므로 다시 누를 수 있음) |
| 400·405·415 | 해당 코드 | 개발 오류. 500과 같이 처리 |

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
  "savingsRateInputPct": null
}
```

| 필드 | JSON 타입 | 필수 | 뜻 |
|---|---|---|---|
| `expectedRevision` | integer \| null | 키 필수 | 지금 가진 계획의 `revision`. **계획이 없다고 믿으면 `null`**(새 목표 세우기 첫 저장) |
| `goalType` | string | 예 | `GoalType` 코드(FR-INP-01). 목록·순서는 #19 enum, 표시명은 문구표 `goal.<CODE>`. 예: `HOUSE`, `CUSTOM` ⟵ 목록 확정은 #19 |
| `goalCustomName` | string \| null | `goalType=CUSTOM`일 때만 | FR-INP-02(Should). 1~50자(trim 뒤, UTF-16). CUSTOM이 아니면 무시하고 `null`로 저장 |
| `goalAmount` | integer(KRW) | 예 | FR-INP-03 |
| `targetPeriodMonths` | integer(MONTH) | **예**(D-045) | FR-INP-04. 프론트가 'n년 n개월'을 개월로 바꿔 보낸다 |
| `heldAssets` | integer(KRW) | 예 | FR-INP-05. 0 허용 |
| `monthlySavingAmount` | integer(KRW) | **예**(D-045) | FR-INP-06 |
| `savingsRateInputPct` | number(PCT) \| null | 키 필수, 값 `null` 허용 | FR-INP-07. `null` = 기본금리(D-012·D-034) |

- **요청에 없는 것**: `savingsRatioPct`, `existingMonthlyContribution`, `calcStartMonth`, `baselineScenario`.
  - 비중: 입력 화면에 비중 칸이 없다(FR-INP-08 Won't, D-045 "5:5 고정, 비중은 대화로"). 서버는 **현재 버전의 `savings_ratio_pct`를 그대로 복사**한다(첫 저장이면 `NULL` = 기본 5:5). 왜: 대화로 적용한 비중이 입력 수정 한 번에 조용히 사라지지 않게. ⟵ R-9
  - `existingMonthlyContribution`: 항상 `NULL`(Won't).
  - 시작월: 요청에 없다. 첫 저장이면 요청일이 속한 달(D-032), 계획이 있으면 현재 버전 값을 복사(D-013).
  - 기준 시나리오: `plan.baseline_scenario`. 첫 저장이면 `AVG`(FR-RES-09 Should, alignment 2-6).
- 숫자 필드는 internal-calc C2-2처럼 **`JsonNode`로 받아** `ConditionValidator`에 넘긴다. 왜: Boot 기본값(`ACCEPT_FLOAT_AS_INT`)이면 `300000.5`가 잘려 `NOT_INTEGER`를 낼 수 없다. 같은 검증기를 입력·대화·대안이 공유한다(CP-02).

### C12a-5-2. 서버 동작과 검사 순서

| 순서 | 어디서 | 검사 | 결과 |
|---|---|---|---|
| 0 | 필터 | 토큰 | `401 UNAUTHENTICATED` |
| 1 | calc.web | JSON 파싱, 숫자 필드가 JSON 숫자인지(문자열·불리언 등이면 실패), `goalType`이 알려진 코드인지, `expectedRevision`이 정수 또는 `null`인지 | `400 MALFORMED_REQUEST` |
| 2 | plan(`PlanInputValidator` + `ConditionValidator.validate(INPUT_EDIT, …)`) | 필수 누락(`REQUIRED`), 범위(`OUT_OF_RANGE`), 정수 아님(`NOT_INTEGER`), 소수 자릿수(`TOO_MANY_DECIMALS`), CUSTOM 이름. **걸린 필드를 모두** 담는다 | `422 VALIDATION_FAILED` |
| 3 | plan(저장 서비스, 한 트랜잭션) | 계획 있음 + `expectedRevision=null`, 계획 없음 + `expectedRevision≠null`, `plan.revision ≠ expectedRevision` | `409 PLAN_CHANGED` |
| 4 | plan | `plan_version` INSERT(`source='INPUT'`, 시작월·비중은 위 규칙) → 첫 저장이면 `plan` INSERT(`revision=1`, `baseline_scenario='AVG'`), 아니면 `UPDATE plan SET previous=current, current=:v, revision=revision+1 WHERE member_id=? AND revision=?` (0행이면 런타임 예외로 롤백 → `409 PLAN_CHANGED`). 첫 저장 경쟁(같은 회원 두 탭)으로 `plan` PK 충돌이 나면 `409 PLAN_CHANGED` → `PlanChanged(INPUT)` 발행 → 커밋 | — |
| 5 | calc(결과 조회 서비스, #29 Q1) | 새 현재 버전의 최신 PLAN `calc_run`이 없으면 계산·기록하고 결과·display를 만든다 | `200 PlanView`(C12a-6) / 실패 `500 INTERNAL_ERROR` |

- **보유 자산 ≥ 목표 금액은 검증 오류가 아니다.** 저장하고 `200`으로 `result.status = ALREADY_EXCEEDED`를 돌려준다(FR-RES-01 "계산 대신 초과 안내", CF-03). 왜: 사용자가 입력한 계획 자체는 유효하고, 결과 화면이 초과 안내를 그려야 한다.
- 4와 5는 **다른 트랜잭션**이다. 5가 실패해도 계획은 저장돼 있다(응답 `500`). 프론트는 "결과를 불러오지 못했어요"를 보이고 P-4를 다시 부르면 된다(P-4가 같은 Q1로 계산·기록). 왜: plan은 calc를 부를 수 없어 한 트랜잭션에 묶을 수 없고, 저장을 계산 성공에 묶을 이유도 없다(결과는 언제든 다시 만든다, ADR-002).
- 5와 `PlanChanged(INPUT)` 리스너가 같은 (버전, PLAN) 기록을 동시에 만들어 2행이 될 수 있다. **무해**(C12b-7-3, plan-context C1a-10과 같은 방침).
- ERD Q4-a의 `ON CONFLICT ... DO UPDATE`(revision 검사 없음)와 다르다. 이 계약은 입력 수정에도 `expectedRevision`을 검사한다(C12a-14 Y-3). 왜: 다른 탭에서 대화 적용한 계획을 입력 화면의 오래된 값으로 덮어쓰는 일을 막는다(PR-08, TBD-37의 "버전 확인" 쪽).

### C12a-5-3. 응답 `200`

**P-4와 같은 `PlanView`**(C12a-6). 새 `revision`과 새 `calcRunId`가 들어 있다. 프론트는 이 응답으로 결과 화면을 바로 그린다(P-4를 다시 부르지 않는다). 왜: FR-INP-10 "검증 → 저장 → 계산 → 결과 화면"이 한 번의 왕복이고, 응답 모양이 P-4와 같아 결과 화면 코드가 하나다. C12b-13 요구 4(입력 저장 응답에 `revision`)를 만족한다. ⟵ R-7

### C12a-5-4. 오류와 프론트 동작

| HTTP | `code` | `errors` | 프론트 동작(#48 입력 화면 (추정)) |
|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | `[]` | 개발 오류. "저장하지 못했어요" 토스트, 입력값 유지 |
| 422 | `VALIDATION_FAILED` | 1개 이상 | 각 `field` 입력칸 아래에 안내. 범위 문구는 `min`·`max`·`unit`을 **입력칸 단위로** 바꿔 보인다(C3-5. 예: `KRW` 10000000 → "1,000만원") |
| 409 | `PLAN_CHANGED` | `[]` | "계획이 다른 곳에서 바뀌었어요"(문구표). **입력 화면에 머물고 입력값을 지우지 않는다.** P-4를 불러 공유 상태의 `revision`을 새 값으로 바꾼 뒤(409 NO_PLAN이면 `null`), 사용자가 다시 누르면 새 값으로 저장 |
| 401 | `UNAUTHENTICATED` | `[]` | 로그인 화면 |
| 500 | `INTERNAL_ERROR` | `[]` | "결과를 불러오지 못했어요". **계획은 저장됐을 수 있으므로** P-4를 한 번 불러 `200`이면 결과 화면으로, 실패면 입력 화면에 머문다 |

- 422 `errors[].field`는 요청 키 이름 그대로(camelCase). `goalCustomName` 길이 초과는 `OUT_OF_RANGE`, `min:1, max:50, unit:"CHAR"`(C12b-9 R-7과 같은 `CHAR`).
- 프론트는 같은 검사(필수·범위)를 먼저 해서 버튼을 막을 수 있지만, **범위 수치는 하드코딩하지 않는다**: 422 응답의 `min`·`max`를 기준으로 안내한다. 왜: 수치가 `rules.yml` 한 곳에 있어야 한다(C3-3). 프론트 사전 검사는 "비어 있음"만 권장.
- **입력 화면 단위**: CP-02(TBD-09)는 금액 입력 단위가 만원이다. 프론트는 입력칸 값(만원) × 10000으로 원 단위를 보낸다. 입력 수정 화면을 채울 때(FR-INP-11)는 `plan.*`(원) ÷ 10000이다. 대화로 적용한 월 저축액이 만원으로 나누어떨어지지 않으면(예: 345,000원) 칸에 무엇을 보일지는 정하지 못했다. ⟵ R-3

422 예시(월 저축액 상한 초과 + 기간 누락):
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
(`minDisplay`·`maxDisplay` 키가 **없다**. 범위 수치는 internal-calc C3-3의 임시값. `goalAmount`·`heldAssets` 범위는 R-4.)

### C12a-5-5. 범위 수치 (`rules.yml › input.fields`, 임시)

| 필드 | min | max | unit | scale | 출처 |
|---|---|---|---|---|---|
| `monthlySavingAmount` | 10000 | 10000000 | KRW | 0 | internal-calc C3-3과 같은 값(같은 설정 키) |
| `savingsRateInputPct` | 0 | 20 | PCT | 2 | internal-calc C3-3 |
| `targetPeriodMonths` | 1 | 360 | MONTH | 0 | internal-calc C3-3 |
| `goalAmount` | 10000 | 10000000000 | KRW | 0 | **임시 제안**(1만원 ~ 100억). TBD-09 미결 ⟵ R-4 |
| `heldAssets` | 0 | 10000000000 | KRW | 0 | **임시 제안**. 0 허용(DB 기본값 0) ⟵ R-4 |
| `goalCustomName` | 1 | 50 | CHAR | — | `schema.sql` `VARCHAR(50)` |

- 같은 키는 경로(INPUT_EDIT·CHAT·ALTERNATIVE)와 무관하게 **같은 범위**다(CP-02 "대안·비교·대화로 바꾼 값에도 같은 범위"). 경로마다 다른 것은 "바꿀 수 있는 키 목록"뿐이다(`change-paths.<PATH>.fields`).

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
    "savingsRatioPct": null,
    "calcStartMonth": "2026-11",
    "baselineScenario": "AVG"
  },
  "conditions": { "...": "planContext C1a-3과 같음(6키, 계산에 실제 쓴 값)" },
  "result": { "...": "planContext C1a-4와 같음 + scenarios[].monthlyPoints" },
  "display": { "...": "planContext C1a-6과 같은 키·형식" }
}
```

| 필드 | 타입 | 뜻 | 누가 쓰나 |
|---|---|---|---|
| `revision` | integer | `plan.revision`. 모든 쓰기의 `expectedRevision` 출처(C12b-7 R-8) | 공유 상태, F-5, P-3, P-5, 대화창 구독(D-069·D-072) |
| `calcRunId` | integer | 이 결과를 계산한 `calc_run(PLAN)` id | F-3 호출 지점 하나(#54, C12b-3a) |
| `baselineResultScenario` | `GOOD`\|`AVG`\|`BAD`\|null | **결과 요약(FR-RES-02)에 쓸 시나리오**. `CalcResult.findBaselineResult()`의 결과(기준이 없으면 AVG로 대체). `ALREADY_EXCEEDED`면 `null` | 결과 요약 |
| `plan` | object | **사용자가 입력한 원래 값**(원 단위·nullable 그대로). 입력 수정 화면 채우기(FR-INP-11)와 재로그인 안내 문구(D-035)용 | #48 (추정) |
| `conditions` | object | 계산에 실제 쓴 값(기본금리·기본비중 채운 뒤). C1a-3 그대로 | 판단용. 화면 문자열은 `display` |
| `result` | object | C1a-4 그대로 + `scenarios[].monthlyPoints` | 판단용(`status`, `isAchieved`, 시나리오 수), 그래프 점 위치 |
| `display` | object | C1a-6 키·형식 그대로(접두어 `""`, 조건 접두어 `"conditions."`) | **화면의 모든 숫자 문자열** |

- `baselineResultScenario`를 따로 두는 이유: ETF 0%면 기준이 GOOD/BAD여도 결과가 AVG 하나뿐이라 대체 규칙(ADR-001 한계 1)이 필요하다. 이 규칙을 프론트가 다시 구현하지 않게 Spring이 이름만 준다.
- `plan.savingsRatioPct`는 사용자가(대화·대안으로) 정한 비중이며 `null`이면 기본 비중이다. 입력 화면에는 칸이 없지만 내려 준다(입력 수정 저장 때 서버가 복사하므로 프론트는 보내지 않는다, C12a-5-1).
- **내보내지 않는 것**: `currentVersionId`·`previousVersionId`·`planVersionId`(프론트가 쓰지 않음. `currentVersionId`는 chat이 plan 공개 API로 얻는다, C12b-13 요구 7), `undoAvailable`(되돌리기 토스트는 적용 직후에만 띄우므로 필요 없음), `memberId`.
- `display` 키는 planContext와 **같은 `ResultDisplayBuilder`**(#28)가 같은 접두어로 만든다. 그래서 결과 화면과 AI 설명의 문자열이 글자까지 같다(PR-04, C1a-6). `<S>.goalReachMonth`는 `isAchieved=true`일 때만 있다(C1a-6 v3 규칙).

### C12a-6-2. `result` — C1a-4와 다른 점

| 필드 | 이 계약 |
|---|---|
| `scenarios[].monthlyPoints` | **있다**(planContext·`/internal/calc`에는 키 자체가 없음). FR-RES-04 그래프용 |
| `scenarios[].monthlyPoints[].month` | `"YYYY-MM"` |
| `scenarios[].monthlyPoints[].principal` | integer(KRW). 그 달까지 넣은 원금(보유 자산 포함) |
| `scenarios[].monthlyPoints[].afterTaxAsset` | integer(KRW). 그 달의 세후 예상 자산 |
| 그 밖 | C1a-4와 같다(`status`, `goalAmount`, `calcStartMonth`, `targetMonth`, `baselineScenario`, `scenarios[]`, `requiredMonthlySaving`(항상 `null`), `assumptions`, `dataVersions`) |

- 구현 메모(A팀): `MonthlyPoint(month, principal, afterTaxAsset)`(moeun `calc/MonthlyPoint.java`) 그대로. 응답 DTO는 `calc.web`의 화면 전용 View(`PlanResultView` 등 이름은 재량)로 두고, calc 루트 공개 `CalcResultView`(monthlyPoints 없음)는 바꾸지 않는다. 왜: planContext·`/internal/calc`의 "키 자체가 없음" 계약을 깨지 않는다(C2-4 "전역 믹스인 금지"와 같은 이유).
- 점의 개수·첫 달 규칙(시작월을 포함하는지, 목표월에서 끝나는지)은 엔진(#27) 정의를 따르고 이 계약은 고정하지 않는다. 프론트는 배열을 순서대로 그리기만 한다. 단 **마지막 점의 `afterTaxAsset`·`principal`은 그 시나리오의 `afterTaxAsset`·`principal`과 같다**(#27 테스트로 고정 요청, J-6).
- `annualReturnPct`는 내보내지만 **화면에 표시하지 않는다**. 왜: display가 없는 값이고(C2-6), 과거 연환산 수익률을 보이면 수익 약속처럼 읽힐 위험이 있다(CP-06 취지).

### C12a-6-3. 서버 동작

1. 필터 → `401`.
2. plan 공개 현재 계획 조회(#19). 행이 없으면 **`409 NO_PLAN`**. ⟵ R-10
3. calc 결과 조회 서비스(#29, ERD Q1): 현재 버전의 최신 PLAN `calc_run`의 버전으로 계산. 없으면(또는 Q1-c 조건) 계산하고 기록. 결과 + `ResultDisplayBuilder`.
4. `200 PlanView`.

- **GET이 `calc_run`을 INSERT할 수 있다**(Q1-c). 그래서 이 서비스는 읽기 전용 트랜잭션이 아니다(C12b-5 F-2 메모와 같은 성격).
- 재로그인 시 최신 데이터로 다시 계산하지 않는다(D-010). 해커톤 중에는 데이터 재적재가 없어 Q1-c 분기가 실제로 돌지 않는다(D-045, plan-context C1a-10 R-4).
- 같은 (버전, 데이터 버전, `engine_version`) 결과는 앱 메모리 캐시 가능(ERD Q1, ADR-002 위험 4). 계약 밖 구현 재량.

### C12a-6-4. 오류와 프론트 동작

| HTTP | `code` | 프론트 동작 |
|---|---|---|
| 409 | `NO_PLAN` | 빈 입력 화면으로(FR-PLAN-06). 공유 상태 `revision = null` |
| 401 | `UNAUTHENTICATED` | 로그인 화면 |
| 500 | `INTERNAL_ERROR` | 결과 화면 자리에 "결과를 불러오지 못했어요" + 다시 시도 버튼(문구표). 대화창은 그대로(FR-AI-04와 무관) |

### C12a-6-5. 언제 부르나 (프론트, #49 결과 화면)

- 로그인 성공 직후, 앱 시작·새로고침, F-5 대화 적용 성공 뒤(C12b-7-3 3번), P-5 되돌리기 성공 뒤, P-6 적용 성공 뒤, `PLAN_CHANGED`를 받은 뒤.
- P-3 성공 뒤에는 부르지 않는다(응답이 이미 `PlanView`).
- 응답을 받으면 공유 상태(`revision`, `calcRunId`, `result.status`)를 한 번에 바꾼다(C12b-13 요구 10). F-3은 #54가 "`calcRunId`가 바뀌고 `status=CALCULATED`"일 때 한 곳에서 부른다(C12b-3a). 결과 화면(#49)·되돌리기(#51)는 F-3을 부르지 않는다.

## C12a-7. 결과 화면이 계산하지 않기 위한 대응표 (display 완비)

결과 화면의 각 영역이 **어디서 문자열을 가져오는지**. 이 표에 없는 숫자 문자열을 프론트가 만들면 계약 위반이다.

| 영역(SRS) | 문자열 출처 | 판단에 쓰는 raw |
|---|---|---|
| 조건 바(FR-RES-05) | 목표명: 문구표 `goal.<goalType>` 또는 `plan.goalCustomName`. 금액·기간·비중·금리: `display.goalAmount`, `display.conditions.{monthlySavingAmount, targetPeriodMonths, savingsRatioPct, savingsRateInputPct, heldAssets}` | `result.assumptions.isDefaultSavingsRate`(“기본 금리” 표시 여부, 문구표) |
| 결과 요약(FR-RES-02) | `S = baselineResultScenario`일 때 `display["S.afterTaxAsset"]`, `display["S.gapToGoal"]`, `display.targetMonth`. 시나리오 이름은 문구표 `scenario.<S>` | 그 시나리오의 `isAchieved` |
| 3구간(FR-RES-03) | 있는 시나리오마다 `display["<S>.afterTaxAsset"]`, `["<S>.gapToGoal"]`, (있으면) `["<S>.goalReachMonth"]`. 아래 고지 한 줄은 문구표(D-029) | `result.scenarios.length`(1이면 ETF 0%, 3구간 대신 한 칸), 각 `isAchieved` |
| 그래프(FR-RES-04) | 목표선 라벨 `display.goalAmount`, 가로축 양 끝 `display.calcStartMonth`·`display.targetMonth`. **점마다의 금액 문자열(툴팁·세로축 눈금 숫자)은 없다** ⟵ R-5 | `result.scenarios[].monthlyPoints[]`(점 위치), `result.goalAmount`(목표선 높이) |
| 초과 안내(FR-RES-01) | 문구표 `result.alreadyExceeded`(+ 목표 수정 안내) 안에 `display.goalAmount`, `display.conditions.heldAssets`를 끼운다. **초과 금액은 보이지 않는다**(display 없음, C1a-6) | `result.status === "ALREADY_EXCEEDED"` → 요약·3구간·그래프·대안 숨김, F-3 안 부름(D-062) |
| 가정 보기(FR-RES-06) | 세율 `display["assumptions.taxRatePct"]` + 문구표 `tax.note`(D-067), 적금 금리 `display["conditions.savingsRateInputPct"]`, 데이터 기준월 `display["assumptions.savingsRateBaseMonth"]`·`["assumptions.sp500BaseDate"]`(키가 없으면 그 줄 생략), 반영하지 않은 항목 문구표 `excluded.<CODE>`(D-027 포함), 3구간 산정 방식 문구표 `scenarioMethod.<CODE>` | `result.assumptions.excludedItems`, `scenarioMethod`(null이면 줄 생략), `isDefaultSavingsRate` |
| 면책(FR-RES-07) | 문구표 `disclaimer`. 서버 응답과 무관 | — |
| 입력 수정 채우기(FR-INP-11) | 입력칸 값: `plan.*`(원 → 만원 환산, R-3). 재로그인 보유 자산 안내: 문구표 + `display.calcStartMonth`(D-035) | `plan.savingsRateInputPct === null`이면 금리 칸 비움 |

- 문구표 키 이름(`goal.<CODE>`, `scenario.<S>`, `result.alreadyExceeded`, `disclaimer`, `excluded.<CODE>`, `scenarioMethod.<CODE>`, `tax.note`)은 #18에서 확정한다. `excluded.*`·`scenarioMethod.*`·`tax.note`는 planContext C1a-11·D-067과 **같은 키**를 쓴다(ai-server와 공유, CP-05).
- 대안 영역(FR-ALT, Should)은 이 표 밖이다(C12a-9).

---

## C12a-8. P-5 되돌리기 `POST /api/plan/undo`

FR-PLAN-04, D-013, D-041, D-044, D-068, C12b-7-4.

요청:
```json
{ "expectedRevision": 13 }
```

응답 `200`:
```json
{ "revision": 14 }
```

- 응답은 **`revision` 하나**다(F-5 C12b-7과 같은 모양). 왜: 프론트가 다음에 하는 일은 공유 상태 갱신과 P-4 재조회뿐이고, 결과는 P-4가 그린다. b-team-contracts A-2 초안의 `planVersionId`·`previousVersionId`·`calcRunId`·`undoAvailable`은 뺐다(C12a-14 Y-8).
- 서비스 반환 record는 `planVersionId`·`revision`을 가져도 된다(로그·테스트용). 컨트롤러가 `revision`만 옮긴다.

### C12a-8-1. 서버 동작 [D-068] (C12b-7-4 구현 메모 그대로)

| 순서 | 검사·동작 | 결과 |
|---|---|---|
| 0 | 토큰 | `401 UNAUTHENTICATED` |
| 1 | 본문 파싱, `expectedRevision` 정수 | `400 MALFORMED_REQUEST` |
| 2 | `plan` 읽기. 행 없음 | `409 NO_PLAN` |
| 3 | `previous_version_id IS NULL` | `409 NOTHING_TO_UNDO` |
| 4 | `plan.revision ≠ expectedRevision` | `409 PLAN_CHANGED` |
| 5 | 직전 버전 행을 **`source`·`calc_start_month`까지 복사**해 새 `plan_version` INSERT → `UPDATE plan SET current=:new, previous=NULL, revision=revision+1 WHERE member_id=? AND revision=?` → 0행이면 런타임 예외로 롤백(`409 PLAN_CHANGED`) → `PlanChanged(UNDO)` | `200 {revision}` |

- 되돌리기는 **1단계**다. 되돌린 뒤 `previous=NULL`이라 다시 누르면 `NOTHING_TO_UNDO`(FR-PLAN-04 "바로 직전 계획 1개").
- 복사 INSERT 덕분에 되돌리기 전에 만든 대화 비교는 모두 기준 버전 ≠ 현재가 되어 F-4 `applicable=false`, F-5 `STALE_COMPARISON`이다(D-068). 그래서 프론트가 id를 기억할 필요가 없다.
- 시작월은 복사한 값 그대로(D-013, FR-PLAN-04 예외 수용 기준).
- 서버에는 10초 제한이 없다. 10초는 프론트 토스트 표시 시간이다(D-041, alignment 2-4). 10초가 지나 토스트가 사라지면 사용자는 누를 수 없다.
- 검사 3과 4의 순서는 C12b-7-4 메모를 따른다. 프론트 동작이 두 코드 모두 "토스트 닫고 재조회"라 순서가 결과를 바꾸지 않는다.

### C12a-8-2. 오류와 프론트 동작 (#51 되돌리기 토스트)

| `code` | 프론트 동작 |
|---|---|
| (성공) | 공유 상태 `revision`을 응답 값으로 → 토스트 닫기 → P-4 재조회(C12b-13 요구 10: **F-3은 부르지 않는다**) |
| `NOTHING_TO_UNDO` | 토스트 닫기 + "이미 되돌렸어요"(문구표) + P-4 재조회(다른 탭에서 되돌렸을 수 있음) |
| `PLAN_CHANGED` | 토스트 닫기 + "계획이 다른 곳에서 바뀌었어요" + P-4 재조회 |
| `NO_PLAN` | 토스트 닫기 + 입력 화면으로 |
| `UNAUTHENTICATED` | 로그인 화면 |
| `INTERNAL_ERROR` / 네트워크 | "되돌리지 못했어요" 토스트. **되돌리기 토스트는 남은 시간 동안 그대로**(다시 누를 수 있음) |
| `MALFORMED_REQUEST` | 개발 오류. `INTERNAL_ERROR`와 같이 |

- **토스트가 들고 있는 값**: 직전 적용 응답의 `revision`(F-5 또는 P-6). 그 값이 `expectedRevision`이다. 토스트가 떠 있는 동안 다른 쓰기(입력 저장 등)로 공유 `revision`이 바뀌면 토스트를 닫는다. 왜: 토스트가 가리키는 "방금 적용"이 더 이상 직전이 아니다.
- 되돌리기 토스트는 **적용(F-5, P-6) 직후에만** 띄운다. 입력 저장(P-3) 뒤에는 띄우지 않는다(FR-PLAN-04는 "적용 직후"). 서버는 입력 수정 뒤에도 `previous`가 있어 되돌리기를 받지만, 프론트 진입점이 없다.
- 토스트 시간 10초는 대화 적용에 대해 D-041로 정해졌다. 대안 적용(P-6, Should) 토스트 시간은 Q-039 2번(미결, 권장 "같음")이다.

## C12a-9. P-6 대안·비교 적용 `POST /api/plan/apply` — Should, 범위 표시만

FR-ALT-04, FR-CMP-02, FR-PLAN-01~03(대화 밖 적용). **D-045로 FR-ALT·FR-CMP는 Should**다. 이 계약은 **경로와 모양만 예약**하고, 2주차 말 Should를 되살릴 때 해당 Issue(#33의 plan REST 부분 또는 대안 Issue)에서 이 절을 확정한다. #12 머지 조건이 아니며 목 파일도 만들지 않는다.

예약 모양(변경 가능):
```json
요청 { "source": "ALTERNATIVE", "conditionChanges": { "targetPeriodMonths": 48 }, "expectedRevision": 12 }
응답 200 { "revision": 13 }
```
- `source`: `ALTERNATIVE` \| `COMPARE`(`CHAT`은 400 — 대화 적용은 F-5만). 서버는 `PlanApplyService.apply(memberId, path, changes, expectedRevision, null)`(C12b-13 요구 1, 기준 버전 검사 없음)을 부른다.
- 오류: `409 NO_PLAN`, `422 FIELD_NOT_CHANGEABLE`(경로 밖 키), `422 VALIDATION_FAILED`, `409 PLAN_CHANGED`. 성공 뒤 프론트 순서는 F-5와 같다(공유 `revision` 갱신 → 되돌리기 토스트 → P-4 재조회).
- 확인창(FR-PLAN-01·02)은 프론트 동작이라 API에 없다. 확인창을 연 시점의 `revision`을 `expectedRevision`으로 보낸다(ERD Q4-b).
- 대안 값을 **계산**하는 API(FR-ALT-02·03 카드, FR-CMP-02 비교표)는 B팀 Should 범위이며 이 계약 밖이다(`CalcComparison` 재사용, internal-calc C2-3 구현 메모).

---

## C12a-10. 오류 공통 규칙과 코드 표

형식은 internal-calc **C3-1**, 공통 규칙은 #12-b **C12b-9를 그대로** 따른다(Spring 기본 예외 매핑, 500 전역 기본값 `INTERNAL_ERROR`, 모듈 예외는 `ErrorResponseException` 상속·`config` 타입 상속 금지, `title`은 임시이며 프론트는 쓰지 않음).

| HTTP | `code` | 엔드포인트 | 언제 | `errors` | 새로? |
|---|---|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | P-1~P-6 | 파싱 실패, 타입 불일치, 알 수 없는 `goalType` | `[]` | C12b-9 |
| 401 | `UNAUTHENTICATED` | P-2~P-6 | 쿠키 없음·서명 불일치·만료 | `[]` | C12b-9 |
| 401 | **`INVALID_CREDENTIALS`** | P-1 | 아이디 없음·비밀번호 틀림 | `[]` | **#12-a** |
| 404 | `NOT_FOUND` | (없는 경로) | | `[]` | C12b-9 |
| 405 / 415 | `METHOD_NOT_ALLOWED` / `UNSUPPORTED_MEDIA_TYPE` | 전부 | 프론트는 쓰지 않음 | `[]` | C12b-9 |
| 409 | `NO_PLAN` | P-4, P-5, (P-6) | 저장된 계획 없음 | `[]` | C3-2 |
| 409 | `PLAN_CHANGED` | P-3, P-5, (P-6) | `expectedRevision` 불일치, UPDATE 0행, 첫 저장 경쟁 | `[]` | C12b-9 |
| 409 | **`NOTHING_TO_UNDO`** | P-5 | `previous_version_id` 없음 | `[]` | **#12-a** |
| 422 | `VALIDATION_FAILED` | P-1, P-3, (P-6) | 필드 검증 실패 | 1개 이상 | C3-2 |
| 422 | `FIELD_NOT_CHANGEABLE` | (P-6) | 경로 밖 키 | 1개 이상 | C3-2 |
| 500 | `INTERNAL_ERROR` | 전부 | 예상하지 못한 오류, 결과 계산 실패, 대화 삭제 실패 | `[]` | C12b-9 |

- `CALC_FAILED`는 이 계약의 엔드포인트에 나오지 않는다(`/internal/calc` 컨트롤러 한정, C12b-9·코드 차이 X-15). P-3·P-4의 계산 실패도 전역 `INTERNAL_ERROR`다.
- `errors[]`: `field`, `reason`(`REQUIRED`·`OUT_OF_RANGE`·`NOT_INTEGER`·`TOO_MANY_DECIMALS`·`NOT_CHANGEABLE`), `min`·`max`·`unit`(`KRW`·`MONTH`·`PCT`·`CHAR`), `scale`. `minDisplay`·`maxDisplay` 없음(C3-5).
- 새 코드 두 개는 각 모듈 예외(`auth`의 `InvalidCredentialsException`, `plan`의 `NothingToUndoException` — 이름 재량)가 `ErrorResponseException`으로 `code`를 직접 담는다. 전역 advice(#17)는 고치지 않는다(C12b-9 권장 구현).

예시:
```json
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json

{ "type": "about:blank", "title": "아이디 또는 비밀번호가 맞지 않아요", "status": 401,
  "instance": "/api/auth/login", "code": "INVALID_CREDENTIALS", "errors": [] }
```
```json
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{ "type": "about:blank", "title": "되돌릴 계획이 없어요", "status": 409,
  "instance": "/api/plan/undo", "code": "NOTHING_TO_UNDO", "errors": [] }
```
```json
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{ "type": "about:blank", "title": "계획이 바뀌었어요", "status": 409,
  "instance": "/api/plan", "code": "PLAN_CHANGED", "errors": [] }
```
```json
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{ "type": "about:blank", "title": "계획이 없어요", "status": 409,
  "instance": "/api/plan", "code": "NO_PLAN", "errors": [] }
```
```json
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json

{ "type": "about:blank", "title": "로그인이 필요해요", "status": 401, "code": "UNAUTHENTICATED", "errors": [] }
```

---

## C12a-11. 모듈 의존과 호출 순서

### C12a-11-1. 의존 표 (C12b-10-2에 더하는 것)

| 모듈 | #12-b 뒤 | #12-a 뒤 | 이유 |
|---|---|---|---|
| `auth` | `{}` | **`{}`** | 로그인·로그아웃은 `member`만 읽고 이벤트만 발행. 계획 유무를 묻지 않는다(C12a-3) |
| `plan` | `{}` | **`{}`** | P-5·P-6 컨트롤러는 `plan.web`. `memberId`는 Spring Security 타입에서 |
| `calc` | `{plan, refdata}` | **변경 없음** | P-3·P-4 컨트롤러(`calc.web`)가 plan 공개 저장·조회 서비스와 자기 결과 조회 서비스를 부른다 |
| `chat` | `{calc, rag, plan, auth}` | 변경 없음 | |
| `config` | — | auth 필터·쿠키 리졸버·엔트리 포인트 등록(기존 방향) | 역방향 없음 |

```
calc.web(P-3, P-4) ──▶ plan(PlanSaveService, 현재 계획 조회)   [calc → plan, 기존]
          └──────────▶ calc.application(결과 조회 #29, ResultDisplayBuilder #28)
plan.web(P-5, P-6) ──▶ plan.application(되돌리기, PlanApplyService)
auth.web(P-1, P-2) ──▶ auth.application ──publish──▶ MemberLoggedIn/Out ──(동기)──▶ chat
```

지켜야 할 것(C12b-10-2 (a)~(d)에 더해):
- (e) **plan 공개 저장 서비스의 인자·반환에 calc·chat·config 타입이 없다.** 입력은 plan 자체 record(필드는 `JsonNode` 또는 원시 타입), 반환은 `revision`·`planVersionId`.
- (f) `calc.web`이 plan의 하위 패키지(`plan.web`·`plan.application`) 타입을 쓰지 않는다. 루트 공개 API만.
- (g) auth는 plan을 모른다. 그래서 로그인 응답에 계획 정보가 없다.

공개 API 시그니처 제안(인자·책임은 계약, 이름·세부는 A팀 재량):
```java
// plan 루트 (#19). chat·calc·config 타입 없음.
public interface PlanSaveService {
    /**
     * 입력 저장(INPUT). 검증(INPUT_EDIT) → revision 검사 → plan_version INSERT → plan INSERT/UPDATE → PlanChanged(INPUT).
     * 시작월·비중은 현재 버전에서 복사(없으면 요청 월·NULL). 한 트랜잭션. 0행·PK 충돌이면 PlanChangedException.
     * @param expectedRevision null = 계획이 없다고 믿음
     */
    PlanSaveResult save(long memberId, PlanInput input, Long expectedRevision);
}
public record PlanSaveResult(long planVersionId, long revision) {}

// plan 루트 (#33). 되돌리기.
public interface PlanUndoService {
    PlanUndoResult undo(long memberId, long expectedRevision);   // NoPlan / NothingToUndo / PlanChanged 예외
}
public record PlanUndoResult(long planVersionId, long revision) {}
```
- 결과 조회는 #29의 "현재 계획 결과 조회 서비스"(planContext C1a-10 QUESTION이 쓰는 것과 같은 것)를 `calc.application`에서 부른다. 새 공개 API는 필요 없다(같은 모듈 안).

### C12a-11-2. 호출 순서

**로그인 → 진입 (FR-PLAN-06)**
```
브라우저 ─POST /api/auth/login─▶ auth.web
  auth: 검증 → member 조회·해시 비교 → publish MemberLoggedIn ─(동기)─▶ chat: DELETE chat_message
  auth: JWT 발급 → Set-Cookie moeun_at → 200 {}
브라우저 ─GET /api/plan─▶ calc.web
  ├ 409 NO_PLAN → 입력 화면
  └ 200 PlanView → 결과 화면 → (#54) calcRunId 바뀜 + CALCULATED → F-3   (초과면 F-3 없음, D-062)
     + (#52) F-2 복원(afterId 없음)
```

**입력 저장 (FR-INP-10)**
```
브라우저 ─PUT /api/plan {expectedRevision, ...}─▶ calc.web
  plan.PlanSaveService.save  (plan 한 트랜잭션: 검증 → revision → INSERT/UPDATE → PlanChanged(INPUT))
  calc 결과 조회 #29 (없으면 calc_run(PLAN) 기록) → PlanView
  ◀─200 PlanView
[커밋 뒤, 비동기] calc 리스너: 새 버전 calc_run(PLAN) (이미 있으면 한 행 더, 무해)
브라우저: 공유 상태 갱신(revision·calcRunId·status) → 대화창 버튼 모두 비활성(D-069), 초과 여부 재판단(D-072) → (#54) F-3
```

**되돌리기 (FR-PLAN-04)**
```
브라우저(토스트) ─POST /api/plan/undo {expectedRevision}─▶ plan.web
  plan: 읽기 → NO_PLAN / NOTHING_TO_UNDO / PLAN_CHANGED → 복사 INSERT → 조건부 UPDATE → PlanChanged(UNDO)
  ◀─200 {revision}
브라우저: revision 갱신(대화창 버튼 비활성) → 토스트 닫기 → GET /api/plan → (#54) F-3
```

**로그아웃**
```
브라우저 ─POST /api/auth/logout─▶ auth.web (@SkipRenewal)
  publish MemberLoggedOut ─(동기)─▶ chat: DELETE chat_message
  Set-Cookie moeun_at=; Max-Age=0 → 200 {}
브라우저: 공유 상태 비우기(폴링 중지) → 로그인 화면
```

---

## C12a-12. 목(mock) JSON 목록 (`frontend/src/mocks/auth/`, `frontend/src/mocks/plan/`)

**형식·선택 방식은 #12-b C12b-12를 그대로 쓴다**: 파일 하나 = `{responses: [{status, headers, body}]}`, 요청 키 = 메서드 + 경로(쿼리 제외), 키마다 기본 파일 하나, 다른 파일은 개발·테스트 전용 `useMock(파일명)`, 배열 끝을 넘으면 마지막 반복, `status`·`headers` 그대로 반영. 새 라이브러리 없음.

- `body`는 **줄임표 없이** 채운다. 값은 아래 출처와 같게 맞춘다(REST Docs 스니펫 #30·#31·#33·#16과 같은 값).
- 기준 계획(이하 "A-1 계획"): 목표 2,000만원(`HOUSE`), 보유 500만원, 월 30만원, 36개월, 금리 미입력(기본 3.12%), 비중 미입력(5:5), 시작월 2026-11. `conditions`·`result`(monthlyPoints 제외)·`display`는 **plan-context 부록 A-1과 글자까지 같다**(`calcRunId` 540).
- id 흐름이 #12-b 목과 이어지게 맞춘다: 현재 `revision 12`·`calcRunId 540` → F-5 `post-apply.200`(`revision 13`) → `get-plan.200-after-apply`(`revision 13`, `calcRunId 553`) → P-5 `post-undo.200`(`revision 14`) → `get-plan.200-after-undo`(`revision 14`, `calcRunId 554`).
- **`monthlyPoints` 채우는 규칙(목 전용)**: 시나리오마다 36점, `month` = 2026-12 … 2029-11, `principal` = 5,000,000 + 300,000 × k(k = 1…36), `afterTaxAsset` = principal + round(그 시나리오 `afterTaxGain` × k / 36). 마지막 점이 시나리오 값과 같다. 엔진의 실제 점 규칙(#27)과 달라도 목은 이 규칙으로 고정한다(프론트는 점 개수에 기대지 않는다, C12a-6-2).

| 파일 | 엔드포인트 | 응답 | 내용 |
|---|---|---|---|
| `auth/post-login.200.json` (기본) | P-1 | 200 | `{}`, 헤더에 `Set-Cookie`(목에서는 설명용, 브라우저가 반영하지 않음) |
| `auth/post-login.401-invalid.json` | P-1 | 401 | `INVALID_CREDENTIALS` |
| `auth/post-login.422.json` | P-1 | 422 | `errors: [{field:"password", reason:"REQUIRED"}]` |
| `auth/post-login.500.json` | P-1 | 500 | `INTERNAL_ERROR` |
| `auth/post-logout.200.json` (기본) | P-2 | 200 | `{}` |
| `auth/post-logout.401.json` | P-2 | 401 | `UNAUTHENTICATED` |
| `plan/get-plan.200.json` (기본) | P-4 | 200 | A-1 계획, `revision 12`, `calcRunId 540`, 3구간 모두 미달 |
| `plan/get-plan.200-etf0.json` | P-4 | 200 | plan-context A-2(`calcRunId 541`), 시나리오 AVG 1개, `plan.savingsRatioPct: 100` |
| `plan/get-plan.200-exceeded.json` | P-4 | 200 | plan-context A-3(`calcRunId 542`), `ALREADY_EXCEEDED`, `scenarios: []`, `baselineResultScenario: null` |
| `plan/get-plan.200-after-apply.json` | P-4 | 200 | 월 50만원 적용 뒤, `revision 13`, `calcRunId 553`. `result`·`display`는 internal-calc A-1 `changed`·`changed.*` 값(접두어만 뺌), 3구간 모두 달성·`goalReachMonth` 있음 |
| `plan/get-plan.200-after-undo.json` | P-4 | 200 | `get-plan.200`과 같은 숫자, `revision 14`, `calcRunId 554` |
| `plan/get-plan.409-no-plan.json` | P-4 | 409 | `NO_PLAN`(로그인 직후 빈 입력 화면) |
| `plan/get-plan.401.json` | P-4 | 401 | `UNAUTHENTICATED`(새로고침 시 만료) |
| `plan/get-plan.500.json` | P-4 | 500 | `INTERNAL_ERROR` |
| `plan/put-plan.200.json` (기본) | P-3 | 200 | `get-plan.200`과 같은 본문 |
| `plan/put-plan.200-exceeded.json` | P-3 | 200 | `get-plan.200-exceeded`와 같은 본문 |
| `plan/put-plan.422-range.json` | P-3 | 422 | C12a-5-4 예시(`OUT_OF_RANGE` + `REQUIRED`, display 키 없음) |
| `plan/put-plan.422-custom-name.json` | P-3 | 422 | `goalCustomName` `OUT_OF_RANGE`(`min 1, max 50, unit CHAR`) |
| `plan/put-plan.409-plan-changed.json` | P-3 | 409 | `PLAN_CHANGED` |
| `plan/put-plan.400.json` | P-3 | 400 | `MALFORMED_REQUEST` |
| `plan/put-plan.500.json` | P-3 | 500 | `INTERNAL_ERROR` |
| `plan/post-undo.200.json` (기본) | P-5 | 200 | `{revision: 14}` |
| `plan/post-undo.409-nothing.json` | P-5 | 409 | `NOTHING_TO_UNDO` |
| `plan/post-undo.409-plan-changed.json` | P-5 | 409 | `PLAN_CHANGED` |
| `plan/post-undo.409-no-plan.json` | P-5 | 409 | `NO_PLAN` |
| `plan/post-undo.500.json` | P-5 | 500 | `INTERNAL_ERROR` |

- 총 **25개**(auth 6, plan 19). P-6(Should) 목은 만들지 않는다.
- 공통 401은 #12-b의 `chat/common.401-unauthenticated.json`을 재사용한다(새 파일 없음).
- Issue #12 수용 기준 "정상, 422, 401, 409를 모두 받을 수 있다": P-1(200·422·401), P-3(200·422·409), P-4(200·409·401), P-5(200·409). 400·500도 있다.

---

## C12a-13. #12-b C12b-13("#12-a에 요구하는 것") 대응표

| # | 요구 | 이 문서 | 상태 |
|---|---|---|---|
| 1 | plan 공개 적용 서비스 `PlanApplyService`(검사 5~10, 기준 버전, 0행 롤백) | 변경 없이 그대로. P-6(Should)이 같은 서비스를 `expectedBaseVersionId=null`로 부른다(C12a-9). 되돌리기는 별도 `PlanUndoService`(C12a-11-1) | 만족(#33) |
| 2 | 401 `AuthenticationEntryPoint`가 C3-1 형식 | C12a-2-3, C12a-10 예시. 쿠키 리졸버도 #16(C12a-2-1) | 만족(#16) |
| 3 | F-2 `@SkipRenewal` | C12a-2-2. **P-2 로그아웃에도 `@SkipRenewal`을 더한다**(만료 쿠키 보호) | 만족 + 추가(#34) |
| 4 | 현재 계획·결과 응답에 `revision`·`calcRunId`(PLAN)·`result.status`, 입력 저장 응답에 `revision` | C12a-6-1 `PlanView`. P-3 응답 = `PlanView`(C12a-5-3) | 만족(#31·#30) |
| 5 | 되돌리기 응답에 새 `revision`, 방식 D-068 | C12a-8 `{revision}`, 복사 INSERT | 만족(#33) |
| 6 | calc `ChatComparisonQuery` + 버전 지정 refdata | 이 계약과 무관. #78 그대로 | 해당 없음(변경 없음) |
| 7 | plan 공개 현재 계획 조회에 `currentVersionId` | 프론트 응답에는 넣지 않는다(C12a-6-1). plan **공개 API**(#19)에는 그대로 둔다 | 만족(#19) |
| 8 | 이벤트 record + 발행(쿠키 응답 전) + `auth/package-info` 문장 | C12a-3 서버 동작 3, C12a-4 서버 동작 2, C12a-11-2 | 만족(#16·#34) |
| 9 | 전역 advice(C12b-9 코드, 500 `INTERNAL_ERROR`, 기본 예외 매핑, `config` 상속 금지, `/internal/calc` 한정 처리) | C12a-10. 새 코드 `INVALID_CREDENTIALS`·`NOTHING_TO_UNDO`는 모듈 예외가 `code`를 직접 담아 advice를 고치지 않는다 | 만족(#17) |
| 10 | 결과 화면이 `revision`·`calcRunId`·`status`를 공유 상태로, 되돌리기·적용 뒤에는 재조회까지만(F-3은 #54) | C12a-6-5, C12a-8-2 | 만족(#49·#51) |

못 만족하는 요구는 없다.

## C12a-14. moeun 현재 코드·문서와 다른 곳 (코드 차이 Y-n)

#12-b의 X-1~X-15와 섞이지 않게 **Y-n**으로 부른다.

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| Y-1 | `db/erd.md` §5-G·§3 FR-AUTH-03, `db/decision.md` ADR-002 §2-5, `db/moved-to-code.md` §1 `user_session` 행 | "로그아웃은 클라이언트가 토큰을 삭제" | 서버 `POST /api/auth/logout`이 `Max-Age=0` 쿠키 + 대화 삭제(D-051·D-052). #12-b X-5와 같은 대상 | J-3, J-14 |
| Y-2 | `config/SecurityConfig.java` | `/api/auth/login` 보호됨, 토큰은 헤더 기본, 엔트리 포인트 기본 | `/api/auth/login` `permitAll`, 쿠키 `moeun_at` `BearerTokenResolver`, C3-1 401 엔트리 포인트 | J-2 |
| Y-3 | `db/erd.md` §4 Q4-a | `INSERT plan ... ON CONFLICT DO UPDATE`(revision 검사 없음) | 입력 수정도 `expectedRevision` 검사, 0행·PK 충돌이면 `409 PLAN_CHANGED`(C12a-5-2) | J-5 |
| Y-4 | `db/erd.md` §4 Q4-c | 포인터 교체 UPDATE 하나 | 직전 버전 복사 INSERT + 조건부 UPDATE(D-068). #12-b X-14와 같은 대상 | J-9 |
| Y-5 | `.claude/rules/persistence.md:14`, `moved-to-code.md` §2 `request_key` 행, `decision.md` ADR-002 §3 멱등 행 | "0행이면 현재 상태를 돌려준다" | `409 PLAN_CHANGED` + 롤백, 본문에 상태 없음. #12-b X-10과 같은 대상(P-3·P-5에도 적용) | J-5, J-9 |
| Y-6 | `backend/CLAUDE.md` 모듈 표 | `plan` 책임 "적용·되돌리기", 컨트롤러 위치 언급 없음 | 계획 조회·입력 저장 REST는 `calc.web`, 되돌리기·대안 적용 REST는 `plan.web`. 의존 표는 바뀌지 않음 | J-7(문서 한 줄) |
| Y-7 | `CalcInput.calcStartMonth` 주석 | "재계산할 때는 현재 월" | 입력 수정도 현재 버전의 시작월 복사(D-013). alignment M-1·#25와 같은 대상 | (기존 #25) |
| Y-8 | `b-team-contracts.md` §4 A-1·A-2, `alignment.md` 2-4 | `POST /api/plan/apply {source:"CHAT", chatMessageId}`, A-2 응답 `{planVersionId, previousVersionId, revision, calcRunId, undoAvailable}`, "되돌리기 뒤 비활성은 프론트 상태" | 대화 적용은 F-5, P-6은 ALTERNATIVE·COMPARE만(Should), P-5 응답 `{revision}`, D-068로 서버 보장 | J-15(기획 문서) |
| Y-9 | `frontend-api-chat.md` C12b-9 422 예시 | `monthlySavingAmount` `max: 5000000` | internal-calc C3-3·이 계약 `max: 10000000`. 예시 숫자만 다름(형식 예시). #12가 옮길 때 10000000으로 맞춘다 | J-1 |
| Y-10 | `auth/package-info.java` | "주요 클래스: JwtTokenService, TokenRenewalFilter, @SkipRenewal" | + 로그인·로그아웃 컨트롤러, 쿠키 이름. 의존 `{}` 유지. #12-b X-2 문장 변경과 같은 파일 | J-2 |

## C12a-15. Issue #12 수용 기준 대응표 (#12-a 범위)

| # | 수용 기준(`/tmp/issue12.md`) | 이 문서 | 비고 |
|---|---|---|---|
| 1 | 각 엔드포인트의 요청·응답·오류 코드 예시(`PLAN_CHANGED`, `NOTHING_TO_UNDO` 등) | C12a-3~C12a-9, C12a-10 | `STALE_COMPARISON`·`ANSWER_PENDING`은 #12-b |
| 2 | chatMessageId 적용에서 plan → chat 의존 없음 | #12-b C12b-10. 이 계약도 plan `{}` 유지(C12a-11-1) | |
| 3 | 목 JSON으로 정상·422·401·409 | C12a-12 | 형식·선택 방식은 C12b-12 |
| 4 | (예외) 401 본문이 C3-1 형식(`UNAUTHENTICATED`, `errors=[]`, problem+json) | C12a-2-3, C12a-10 예시 | 구현 #16 |
| 5 | 422 `errors[]`에 `min`·`max`·`unit`, `minDisplay`·`maxDisplay` 없음 | C12a-5-4 예시, C12a-10 | |
| 11 | 인증·배포 전제(`SameSite=Lax` 이상, 같은 사이트, F-2만 `@SkipRenewal`) | C12a-2. **로그아웃(P-2)도 `@SkipRenewal`** | 수용 기준 문장 "F-2만"이 P-2와 어긋남 → R-12 |
| 13 | #12-a 항목은 별도 협상 | 이 문서 전체 | |
| 완료 조건 | `ModularityTests`를 깨지 않는 설계 | C12a-11-1(auth·plan `{}`, calc `{plan, refdata}` 그대로) | |
| (나머지 6~10, 12) | F-3·대화 절·대화 목 35개 | #12-b 범위 | |

---

## R. 정할 수 없거나 검토자가 판단할 것

| # | 내용 | 기획 추천(본문에 임시로 쓴 것) | 검토 요청 대상 |
|---|---|---|---|
| R-1 | 계획이 이미 있을 때 "새 목표 세우기"가 따로 있나(시작월을 새로 정하나, D-038 데이터 버전 갱신을 하나). D-013은 "시작월을 새로 정하는 동작은 없다", D-038(범위 밖)은 "버전은 새 목표 세우기 때만 갱신" | **해커톤에는 별도 동작 없음.** P-3 하나, 계획이 있으면 항상 시작월 유지. D-038이 범위 밖(D-045)이라 버전 갱신도 없음. 필요하면 질문(Q)으로 올린다 | 제공자·소비자 |
| R-2 | 로그인 실패를 `401 INVALID_CREDENTIALS`로 두고 래퍼가 `code`로 분기할지, `400`/`422`로 둘지 | 401 + `code` 분기(C12a-2-3). 래퍼 규칙 한 줄로 끝남 | 소비자(#13 래퍼) |
| R-3 | 입력 화면 금액 단위(만원)와, 대화·대안 적용으로 만원 단위가 아닌 값이 저장된 경우 입력 수정 칸 표시 | 미정. 후보: (a) 금액 칸을 원 단위로 받기, (b) 만원 칸에 소수 한 자리까지 허용, (c) 칸에는 만원 내림값 + "저장하면 이 값으로 바뀌어요" 안내. 화면 결정이라 질문으로 올릴지 소비자 의견을 먼저 받는다 | 소비자(#48 (추정)) |
| R-4 | `goalAmount`·`heldAssets` 허용 범위(TBD-09 미결) | 임시 1만원~100억(목표), 0~100억(보유). `rules.yml`만 바꾸면 됨 | 제공자(#17) |
| R-5 | 그래프에 점마다 금액 툴팁·세로축 숫자 눈금이 필요한가 | 넣지 않음(목표선 라벨·양 끝 월만 display). 필요하면 `monthlyPoints[].afterTaxAssetDisplay`를 더하는 것으로(빌더 1줄, 응답 커짐) | 소비자(#49·#50 (추정)) |
| R-6 | 로컬 http에서 `Secure` 쿠키 | 기본 `true`, `auth.cookie.secure=false`로 로컬만 끔 | 제공자(#16) |
| R-7 | P-3 응답을 `PlanView` 전체로 할지 `{revision}`만 둘지 | `PlanView` 전체(왕복 1회, P-4와 같은 DTO). `{revision}`이면 F-5·P-5와 모양이 같아지지만 입력 저장마다 P-4를 한 번 더 부른다 | 제공자·소비자 |
| R-8 | P-6 대안·비교 적용의 최종 모양 | 예약만(C12a-9). Should를 되살릴 때 확정 | 2주차 말 |
| R-9 | 입력 수정 때 대화·대안으로 정한 비중을 서버가 복사해 유지할지, 기본 5:5로 되돌릴지 | 복사 유지(조용히 사라지지 않게). 입력 화면에는 비중 칸이 없으므로 사용자가 되돌리려면 대화로 바꾼다 | 제공자·소비자 |
| R-10 | 계획이 없을 때 P-4를 `409 NO_PLAN`으로 할지 `404`/`200 {plan:null}`로 할지 | `409 NO_PLAN`. 코드↔상태 대응이 F-5·`/internal/calc`와 같아진다 | 소비자 |
| R-11 | moeun Issue 본문 대조(이 단계에서 `gh api` 조회 불가). 특히 #30·#31의 경계(입력 저장 REST vs 현재 계획 조회), #48·#50의 실제 범위 | 검토자가 본문과 대조해 C12a-16 담당 칸을 고친다 | 제공자·소비자 |
| R-12 | Issue #12 수용 기준 "F-2만 `@SkipRenewal`"과 로그아웃 `@SkipRenewal`(C12a-2-2) | 로그아웃은 "토큰 연장" 대상이 아니라 만료 쿠키를 지키는 예외이므로 수용 기준을 "사용자 조작 요청 중 F-2만 연장 제외, 로그아웃은 만료 쿠키만 내림"으로 고친다(J-1) | 제공자 |

### 열린 질문의 영향

| 질문 | 이 계약에 미치는 영향 |
|---|---|
| Q-039 (미결, 개발 중 혼란) 2번 "대안 카드 적용 토스트도 10초인가" | P-6(Should) 토스트 시간. P-6이 예약만이라 지금은 영향 없음. 권장(같음)대로면 #51 토스트 컴포넌트를 그대로 재사용 |
| Q-039 3번 "대화창 비교에 그래프" | 이 계약 밖(F-4 `monthlyPoints` 없음, #12-b R-6). P-4의 `monthlyPoints`와 무관 |
| Q-039 1·4·5·6번 | 해커톤 범위 밖 분기(D-045)라 영향 없음 |

새로 올릴 질문 후보: R-1(새 목표 세우기), R-3(입력 단위). 검토 결과 결정이 필요하면 Q-061 이후로 올린다.

---

## C12a-16. 이 계약 때문에 생기는 후속 작업 (D-058: 기존 Issue 본문에 반영)

| # | 작업 | 팀 | Issue | 선행 변경 |
|---|---|---|---|---|
| J-1 | 최종본의 #12-a 부분을 `docs/api/frontend-api.md`에 대화 절과 이어 쓰기, 목 25개(`mocks/auth/`, `mocks/plan/`), C12b-9 예시 `max` 10000000으로(Y-9), 수용 기준 "F-2만 `@SkipRenewal`" 문장 정정(R-12) | 공통 | **#12** | — |
| J-2 | P-1: `POST /api/auth/login`, 쿠키 `moeun_at` 속성(C12a-2-1, `auth.cookie.secure`), 쿠키 `BearerTokenResolver`, `permitAll`, C3-1 401 엔트리 포인트, `INVALID_CREDENTIALS`(모듈 예외), 422 REQUIRED, `MemberLoggedIn` 발행(쿠키 전), 데모 계정 시드, `auth/package-info` 문장(Y-10) | A | **#16** | — |
| J-3 | P-2: `POST /api/auth/logout`, `@SkipRenewal`, `Max-Age=0` 쿠키, `MemberLoggedOut` 발행(쿠키 전), 만료 토큰 401. `TokenRenewalFilter` 규칙(인증됨 + `@SkipRenewal` 아님이면 오류 응답에도 연장) | A | **#34** | — |
| J-4 | 전역 오류: 프론트 API 422에 display 없음 확인, `rules.yml › input.fields`에 `goalAmount`·`heldAssets`·`goalCustomName` 범위(R-4), `ConditionValidator(INPUT_EDIT)` + `PlanInputValidator`(CUSTOM 이름), `CHAR` 단위 | A | **#17** | — |
| J-5 | `PlanSaveService`(C12a-11-1): `expectedRevision` null 의미, 0행·PK 충돌 → `PlanChangedException` 롤백, 시작월·비중 복사, `source='INPUT'`, `PlanChanged(INPUT)`, ERD Q4-a 정정(Y-3), `persistence.md:14` 정정(Y-5, #12-b H-7b와 합침) | A | **#19** | — |
| J-6 | 결과 조회 서비스가 `calcRunId`·결과·display를 함께 내놓음(P-3·P-4·planContext 공용). 엔진 테스트: `monthlyPoints` 마지막 점 = 시나리오 값 | A | **#29**, 엔진 테스트는 **#27** | — |
| J-7 | `PUT /api/plan`(calc.web): 검사 순서(C12a-5-2), 저장 후 결과 조회, 응답 `PlanView`, 500 처리. `backend/CLAUDE.md` 모듈 표에 컨트롤러 위치 한 줄(Y-6) | A | **#30** | 선행 #19, #29, #28 |
| J-8 | `GET /api/plan`(calc.web): `PlanView`(`revision`, `calcRunId`, `baselineResultScenario`, `plan`, `conditions`, `result` + `monthlyPoints`, `display`), `409 NO_PLAN`, 화면 전용 View DTO(공개 `CalcResultView` 불변) | A | **#31** | 선행 #19, #29, #28 |
| J-9 | `POST /api/plan/undo`(plan.web): `PlanUndoService`, 검사 순서(C12a-8-1), 복사 INSERT(D-068), 응답 `{revision}`, `NOTHING_TO_UNDO` 모듈 예외, ERD Q4-c 정정(Y-4). P-6은 **Should로 분리**(같은 Issue에 두면 Must 완료를 막음) — #33 본문에서 P-6을 "Should, 2주차 말"로 표시하거나 대안 Issue로 옮긴다 | A | **#33** | — |
| J-10 | display 키가 planContext C1a-6과 같은 빌더·같은 접두어인지 확인(변경 없음) | A | **#28** | — |
| J-11 | `fetch` 래퍼: 401 분기는 `code === "UNAUTHENTICATED"`일 때만(C12a-2-3), 목 키 `GET /api/plan`·`PUT /api/plan`·`POST /api/plan/undo`·`POST /api/auth/login`·`POST /api/auth/logout` | 공통 | **#13** | #12-b H-16과 합침 |
| J-12a | 로그인 화면: `INVALID_CREDENTIALS` 안내·비밀번호 칸 비움, 성공 뒤 P-4로 진입 분기(FR-PLAN-06), 500 안내 | A | **#47** | — |
| J-12b | 입력 화면: P-3 요청 모양, 만원 ↔ 원 환산(R-3 결정 뒤), 422 필드별 안내(`min`·`max`·`unit` 기준, 범위 하드코딩 금지), `PLAN_CHANGED` 처리(값 유지), FR-INP-11 채우기(`plan.*`), D-035 안내 | A | **#48** (추정) | — |
| J-12c | 결과 화면: C12a-7 대응표만 사용(숫자 문자열 생성 금지), `baselineResultScenario`, 초과 안내(D-062: F-3 없음), 가정 보기, 면책, 공유 상태(`revision`·`calcRunId`·`status`), 500 다시 시도 | A | **#49**, 그래프는 **#50** (추정) | — |
| J-12d | 되돌리기 토스트: 들고 있는 값은 직전 적용 응답의 `revision`, 오류별 동작(C12a-8-2), 공유 `revision`이 바뀌면 토스트 닫기, 성공 뒤 P-4 재조회까지(F-3 없음) | A | **#51** | #12-b H-11d와 합침 |
| J-13 | 문구표 키: `auth.invalidCredentials`, `auth.loginFailed`, `auth.logoutFailed`, `plan.changedElsewhere`, `undo.nothingToUndo`, `undo.failed`, `result.loadFailed`, `result.alreadyExceeded`, `goal.<CODE>`, `scenario.<S>`, `disclaimer`(이름은 #18 재량, `excluded.*`·`scenarioMethod.*`·`tax.note`는 planContext와 같은 키) | 공통 | **#18** | — |
| J-14 | `db/erd.md` §5-G·§3 FR-AUTH-03, ADR-002 §2-5·§3, `moved-to-code.md` §1·§2 정정(Y-1, Y-5) | A | **#34**(문서 paths 추가) 또는 문서 Issue | — |
| J-15 | `b-team-contracts.md` §4 A-1·A-2, `alignment.md` 2-4를 이 계약·#12-b로 정정(Y-8) | 기획 | 문서(#12-b H-12와 합침) | — |

---

## 검토 요청 (2단계 contract-provider · contract-consumer)

- **제공자(A팀)**: C12a-5-2(입력 저장 검사 순서·두 트랜잭션), C12a-6(`PlanView`·화면 전용 View DTO 위치), C12a-8-1(되돌리기), C12a-11(컨트롤러를 `calc.web`/`plan.web`에 두는 것, 공개 서비스 시그니처), C12a-2(쿠키 리졸버·`@SkipRenewal` 로그아웃), R-1·R-4·R-6·R-7·R-9·R-11·R-12.
- **소비자(프론트·B팀)**: C12a-7(display 대응표로 결과 화면을 숫자 생성 없이 그릴 수 있는지), C12a-2-3(래퍼 `code` 분기), C12a-5-4(입력 화면 오류 동작), C12a-8-2(토스트), C12a-12(목 25개·id 흐름이 #12-b 목과 이어지는지), R-2·R-3·R-5·R-7·R-10.
