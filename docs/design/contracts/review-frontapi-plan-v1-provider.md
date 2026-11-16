# 검토: 프론트 ↔ Spring 계획·인증 API 계약 v1 (#12-a) — 제공자(A팀 Spring) 관점

> 검토자: contract-provider, 2026-11-16. 대상 `frontend-api-plan-v1.md`.
> 근거: moeun origin/develop(9a31166) `backend/src/**`, `backend/.claude/rules/{modulith,persistence}.md`, `backend/CLAUDE.md`, `db/{erd,decision}.md`, `schema.sql`, 확정 계약 `frontend-api-chat.md`·`internal-calc.md`·`plan-context.md`, `docs/decisions.md`, `docs/notion-decisions.md`, moeun Issue 본문(`gh api`로 #16 #17 #19 #29 #30 #31 #33 #34 #47~#51 조회).

```
판정: 수정하면 수용
```

전체적으로 모듈 방향(auth `{}`, plan `{}`, calc `{plan, refdata}`)을 깨지 않고, 새 테이블·컬럼 없이 만들 수 있다. 다만 (1) 입력 저장을 두 트랜잭션으로 나누는 근거가 틀렸고 그 결과 프론트 복구 경로가 꼬이며, (2) 로그인 경로에 남은 쿠키 때문에 로그인이 막히는 Spring Security 함정이 있고, (3) 담당 Issue 본문(#30 #31 #33 #29)과 어긋나는 곳이 여러 개 있어 고쳐야 한다.

## 항목별 의견

### C12a-0 원칙 — 수용
- 1~5 모두 기존 계약과 같다. "새 테이블·새 컬럼 없음"은 지켜진다(아래 C12a-5 `goalCustomName` 길이만 확인 필요).

### C12a-1 엔드포인트 목록 — 수정
- P-3·P-4를 `calc.web`에 두는 것: **수용.** calc → plan은 이미 허용(`calc/package-info.java:8` `{"plan","refdata"}`)이고, plan → calc 역방향이 생기지 않아 순환 없음. `ModularityTests`는 그대로 통과한다.
- 다만 담당 Issue와 어긋난다(R-11 참고): #30·#31은 제목이 `[plan]`이고 **#31 paths는 `plan/web/**`·`test/.../plan/**`뿐**이다. calc.web에 두려면 #31 paths에 `calc/web/**`, `test/.../calc/**`를 더하고 선행에 #28·#29를 더해야 한다(#31 선행은 지금 #30 하나). #30도 test paths가 `plan/**`뿐이라 `test/.../calc/**` 추가.
- **`/internal/calc`의 `minDisplay` 변환이 P-3에 새지 않게** 해야 한다. internal-calc C3-5(`internal-calc.md:235`)는 calc.web이 `plan.ConditionViolationException`을 잡아 `minDisplay`를 붙인다. 이것을 `@RestControllerAdvice(basePackages = "...calc.web")`로 만들면 같은 패키지의 P-3 422에도 `minDisplay`가 붙어 C3-5·#30 수용 기준("minDisplay 없음")을 깬다. 수정안: 변환은 `/internal/calc` 컨트롤러 클래스 **안의** `@ExceptionHandler`(또는 `assignableTypes`로 한정)로만 하고, P-3·P-4는 별도 컨트롤러 클래스로 둔다는 문장을 C12a-11 "지켜야 할 것"에 (h)로 추가. #32·#30 수용 기준에 "P-3 422에 `minDisplay` 없음" 테스트가 이미 있으니 문장만 더하면 된다.

### C12a-2 인증·쿠키 — 수정
- 쿠키 이름 `moeun_at`, `HttpOnly`, `SameSite=Lax`, `Path=/`, `Max-Age=1800`: 수용.
- **로그인 경로의 남은 쿠키(반대 성격의 버그 위험, 꼭 고칠 것)**: 리소스 서버의 `BearerTokenAuthenticationFilter`는 리졸버가 토큰을 돌려주면 **`permitAll` 경로에서도** 검증하고, 실패하면 엔트리 포인트로 401을 낸다. 쿠키 리졸버가 경로를 가리지 않으면, 만료됐거나 서명이 안 맞는 `moeun_at`이 남은 브라우저는 `POST /api/auth/login`에서 `401 UNAUTHENTICATED`를 받아 **로그인을 못 한다**. 특히 서버 재시작으로 서명 키가 바뀌면 쿠키 `Max-Age` 동안 아무도 로그인 못 한다. 수정안(C12a-2-1에 추가, #16):
  1. 쿠키 `BearerTokenResolver`는 `/api/auth/login`에서 `null`을 돌려준다(토큰을 보지 않음).
  2. JWT 서명 키는 설정값(환경 변수)으로 고정한다. 기동마다 새로 만들지 않는다.
  3. (양보 가능) 401 엔트리 포인트가 `moeun_at` 만료 쿠키(`Max-Age=0`)를 함께 내린다. 비용 1줄, 깨진 쿠키가 남지 않는다.
- **로그인에도 `@SkipRenewal`**: 이미 로그인한 상태(유효 쿠키 A)에서 다시 로그인하면, 위 1을 하지 않을 경우 연장 인터셉터가 A의 새 쿠키를, 핸들러가 B의 쿠키를 같은 응답에 내린다(Set-Cookie 두 개, 로그아웃과 같은 문제). 위 1을 하면 인증 객체가 없어 연장 대상이 아니므로 자연히 해결되지만, 명시적으로 P-1 핸들러에도 `@SkipRenewal`을 붙이는 것을 권한다(C12a-2-2 표의 P-1 칸 "(발급)" → "`@SkipRenewal`, 핸들러가 발급").
- 로그아웃 `@SkipRenewal`: **수용.** #34 구현 메모(인터셉터 `preHandle`에서 `Set-Cookie`)대로면 연장 쿠키가 먼저 붙고 핸들러의 `Max-Age=0`이 뒤에 붙는다. 브라우저가 대체로 뒤의 것을 쓰지만 보장되지 않으므로 제외가 맞다.
- "오류 응답에도 연장": 수용. `preHandle` 방식이면 핸들러 실행 전에 쿠키가 붙어 4xx·5xx에도 자연히 연장된다. 필터에서 나는 401에는 붙지 않는다(인증 실패라 맞다).
- C12a-2-3 401을 `code`로 분기: 수용(소비자 결정 R-2, 제공자 비용 없음).

### C12a-3 P-1 로그인 — 수정(작음)
- 동작·오류 표 수용. `INVALID_CREDENTIALS`를 auth 루트(또는 하위) 예외가 `ErrorResponseException`을 상속해 담는 방식은 #17 수용 기준(`config` 상속 금지)과 맞다.
- 요청 본문 400/422 구분: `loginId`가 숫자 등 문자열이 아니면 400, 비었으면 422. 단순 record 바인딩이면 Jackson이 숫자를 문자열로 강제 변환해 400이 나지 않는다. **수정안**: 로그인은 보안상 구분 이익이 없으니 "문자열이 아닌 값"은 400 대신 그대로 422 REQUIRED 또는 401로 흡수해도 된다고 적거나(구현 단순), 아니면 `JsonNode`로 받는다고 명시. 기획 추천은 앞쪽(문자열 강제 변환을 허용, 400은 JSON 파싱 실패만).
- 50자 초과 → 401: 수용.

### C12a-4 P-2 로그아웃 — 수용
- 이벤트 발행 → 만료 쿠키 순서는 #34 수용 기준과 같다.

### C12a-5 P-3 입력 저장 — 수정(핵심)

**(a) 두 트랜잭션 → 한 트랜잭션으로 (반대 + 수정안)**
- 초안 근거 "plan은 calc를 부를 수 없어 한 트랜잭션에 묶을 수 없다"(C12a-5-2 마지막 문단)는 사실이 아니다. **부르는 쪽이 calc**이므로 calc.application의 유스케이스 서비스가 `@Transactional`을 열고 그 안에서 `plan.PlanSaveService.save`(전파 `REQUIRED`로 합류) → 결과 조회 서비스(#29, `calc_run` INSERT)를 차례로 부르면 한 트랜잭션이다. 모듈 방향은 그대로(calc → plan).
- ERD도 원래 한 트랜잭션이다: `db/erd.md` Q4-a는 `plan_version` INSERT·`plan` upsert·`calc_run` INSERT를 한 `BEGIN … COMMIT`에 둔다.
- 두 트랜잭션의 실제 문제: 저장 커밋 후 계산이 실패하면(계산 실패는 대개 입력 때문이라 결정적이다) 프론트는 옛 `revision`을 들고 P-4를 부르고 → P-4도 같은 계산이라 500 → 입력 화면에 남은 채 옛 `revision`으로 다시 저장 → 409 `PLAN_CHANGED` → P-4 → 500 … 루프. 사용자는 "계산할 수 없는 계획"이 저장된 계정에 갇히고, 직전 정상 계획의 결과도 볼 수 없다.
- 수정안: "P-3은 calc.application 유스케이스 하나의 트랜잭션(검증 → 저장 → `calc_run(PLAN)` 기록 → 결과·display). 계산이 실패하면 저장까지 롤백하고 `500 INTERNAL_ERROR`. 500이면 계획은 바뀌지 않았다." 프론트 표의 500 행은 "저장하지 못했어요, 입력값 유지, P-4 재호출 불필요"로 단순해진다.
- 부수 효과(좋음): 커밋 뒤 `PlanChanged(INPUT)` 리스너가 돌 때 이미 그 버전의 `calc_run(PLAN)`이 있으므로, #29 수용 기준("같은 이벤트 두 번 → 중복 없음", "최신 PLAN 기록이 있으면 다시 기록하지 않음")대로 리스너가 기록을 건너뛴다. 초안 C12a-5-2 "2행이 될 수 있다. 무해"와 C12a-11-2 "이미 있으면 한 행 더, 무해"는 #29 수용 기준과도 어긋나므로 "리스너는 기록이 있으면 건너뛴다"로 고친다.
- 비용: 어노테이션 하나. 트랜잭션이 계산 시간(최대 360개월 × 3시나리오, ms 단위) 동안 `plan` 행 잠금을 쥐지만 같은 회원의 요청끼리만 겹친다.

**(b) revision 검사(Y-3) — 수용 + 구현 방식 명시 요청**
- 입력 수정도 `expectedRevision` 검사: 수용. ERD Q4-a의 `ON CONFLICT DO UPDATE`는 다른 탭의 대화 적용을 조용히 덮는다(PR-08). #19 수용 기준(0행 → `PlanChangedException` 롤백)과도 맞다.
- **첫 저장 PK 충돌 처리 방식을 고정해 달라.** `plan.member_id`는 생성값이 아닌 PK라 Spring Data `save()`가 `isNew()=false`로 보고 `merge`(SELECT 후 UPDATE)를 한다 → 두 탭 경쟁에서 PK 충돌 대신 **조용히 덮어쓰기**가 난다. 또 `persist`여도 PK 위반은 커밋 시점에 터져 서비스 안에서 `PlanChangedException`으로 바꿀 수 없고, PostgreSQL은 오류 뒤 트랜잭션을 abort 상태로 만든다. 수정안(C12a-5-2 순서 4, J-5): `plan` 쓰기는 네이티브 쿼리 두 개로 한다.
  - 첫 저장: `INSERT INTO plan (...) VALUES (...) ON CONFLICT (member_id) DO NOTHING` → 영향 행 0이면 `PlanChangedException`.
  - 수정: `UPDATE plan SET ... WHERE member_id=? AND revision=?` → 0행이면 `PlanChangedException`.
  - 둘 다 예외로 트랜잭션 롤백(앞서 INSERT한 `plan_version`도 사라짐, #19·#33과 같은 방식).
- "계획 없음 + `expectedRevision≠null` → `PLAN_CHANGED`": 수용(프론트 복구가 P-4 → `NO_PLAN` → `revision=null`로 같다).

**(c) 검사 순서·요청 파싱 — 수정(작음)**
- 순서 1에서 calc.web이 `goalType`을 알려진 코드인지 보려면 `plan.GoalType`이 plan **루트** 공개 enum이어야 한다(`plan/package-info.java`는 이름만 적고 위치는 미정). 수정안: C12a-11 (f) 옆에 "`GoalType`은 plan 루트" 한 줄. 제공자 추천은 초안대로 400 유지(422로 바꾸면 `errors[].reason`에 새 값이 필요하다). 양보 가능.
- `expectedRevision`: 키 없음과 `null` 구분이 필요하므로 본문 전체를 `JsonNode`(또는 `Map<String, JsonNode>`)로 받는다는 초안 방향 수용. F-5(`frontend-api-chat.md:287`)와 같은 "정수 검사"를 쓴다.
- `rules.yml`의 `INPUT_EDIT` 경로에는 CP-07 "한 번에 바꿀 수 있는 개수" 제한이 걸리면 안 된다(입력 저장은 모든 키를 보낸다). #17 수용 기준의 CP-07 문장이 CHAT 경로 한정임을 J-4에 한 줄 더한다.

**(d) 시작월·비중 복사(R-9) — 수용**
- D-013과 맞고, `savings_ratio_pct`는 `NULL` = 규칙 산출이라 복사가 자연스럽다(`schema.sql` plan_version 주석).

**(e) 범위 수치 C12a-5-5 — 수정(작음)**
- `monthlySavingAmount` max **10,000,000이 맞다.** `rules.yml`은 아직 없고(develop에 파일 없음), #17 수용 기준이 "월 저축액 10000~10000000 KRW"로 고정했으며 TBD-09("월저축액 상한 1000만원")·D-043("상한 1000만원")과 같다. 5,000,000은 `frontend-api-chat.md:413` 예시 한 곳뿐이다(Y-9 그대로 수용).
- **`goalCustomName` 길이 충돌**: TBD-09는 "목표명 필수·100자"인데 초안·`schema.sql`(`goal_custom_name VARCHAR(50)`)은 50자다. 제공자 입장은 **50자 유지**(스키마 변경 없음, FR-INP-02는 Should). 다만 TBD-09와 다르므로 R 표에 한 줄 올려 사람이 확인하게 한다.
- `goalAmount`·`heldAssets`(R-4): 아래 R 의견.

### C12a-6 P-4 조회 — 수정
- `PlanView` 모양, 화면 전용 View를 `calc.web`에 두고 공개 `CalcResultView`를 바꾸지 않는 것: 수용. `MonthlyPoint(YearMonth, long, long)`(`calc/MonthlyPoint.java:13`)·`CalcResult.findBaselineResult()`(`calc/CalcResult.java:47`)가 이미 있어 `baselineResultScenario`·`monthlyPoints`는 새 계산 없이 옮기기만 하면 된다.
- **한 번 읽은 스냅샷으로 조립**: 초안 순서는 "plan 현재 계획 조회(2) → calc 결과 조회 서비스(3)"인데, 결과 조회 서비스가 다시 현재 계획을 읽으면 그 사이 다른 탭의 적용으로 `revision`(2에서 읽음)과 `calcRunId`·`result`(3에서 읽음)가 다른 버전을 가리킬 수 있다. 그러면 프론트가 화면과 다른 계획의 `revision`으로 F-5를 보내 검사를 통과해 버린다. 수정안: #29 결과 조회 서비스가 **자기가 읽은 현재 계획 스냅샷(`revision`, `currentVersionId`, 입력값, `baselineScenario`)을 결과와 함께 돌려주고**, 컨트롤러는 그 하나로 `PlanView`를 만든다(J-6·J-8에 한 줄). P-3도 같은 유스케이스 반환값을 쓴다.
- `409 NO_PLAN`(R-10): 제공자는 찬성(예외 하나로 끝나고 `/internal/calc` C3-2와 같다). 단 **#31 수용 기준과 정면 충돌**한다: #31은 "계획이 없으면 `revision`·`calcRunId`·`result.status` 키는 있고 값이 null"(200)이다. 초안을 확정하면 #31 본문의 그 줄을 `409 NO_PLAN`으로 바꿔야 한다(J-8에 명시).
- **#30·#31의 "문구 키" 요구와 충돌**: #30 수용 기준 "응답의 문구 키 목록에 `tax.note`가 있다", #31 "재로그인 후 보유 자산 안내 문구 키(D-035)를 함께 준다". 초안 `PlanView`에는 문구 키 목록이 없고 C12a-7은 프론트가 키를 직접 고른다. 제공자 추천은 **초안 쪽**(응답에 문구 키를 넣지 않음. 키는 고정이라 서버가 내려 줄 정보가 없다). J-7·J-8에 "#30·#31의 문구 키 수용 기준 삭제"를 명시해야 한다. 그대로 두면 구현 에이전트가 본문 수용 기준대로 키 목록을 만든다(D-058).
- `annualReturnPct` 내보내되 표시하지 않음: 수용.
- GET이 `calc_run`을 INSERT: 수용(#29 G-18 "기록이 있으면 다시 기록하지 않음"으로 실제 INSERT는 첫 조회 한 번뿐).

### C12a-7 display 대응표 — 수용
- 제공자 비용 없음. 문구 키 이름은 #18.

### C12a-8 P-5 되돌리기 — 수용(작은 수정 1)
- D-068·#33 본문의 순서(읽기 → `NOTHING_TO_UNDO` → `PLAN_CHANGED` → 복사 INSERT → 조건부 UPDATE, 0행 롤백)와 같다. `ck_plan_prev_diff`(`previous ≠ current`)는 새 id라 걸리지 않는다. 스키마 변경 없음.
- 응답 `{revision}`: 수용.
- **`#33` 본문과 어긋남**: #33 첫 수용 기준 "적용 … `undoAvailable=true`"와 "대안·비교 적용 REST의 `undoAvailable=true`는 유지"가 있다. 초안은 `undoAvailable`을 내보내지 않는다(C12a-6-1, C12a-8, P-6 응답 `{revision}`). J-9에 "#33의 `undoAvailable` 문장 삭제(서비스 반환에도 불필요)"를 넣는다.
- `PlanUndoService`(C12a-11-1)는 **plan 루트 공개 API일 필요가 없다.** 호출자가 `plan.web` 하나뿐이다. `plan.application`에 두면 공개 API 표면이 줄고 `modulith.md`("루트에는 다른 모듈이 쓰는 것만")와 맞다. 수정안: 시그니처는 그대로, 위치만 "plan 내부(application)". `PlanSaveService`는 calc가 쓰므로 루트가 맞다.

### C12a-9 P-6 — 수용
- Should 예약만, `PlanApplyService` 재사용, `CHAT`은 400: 수용. #33이 Must 라벨로 "적용·되돌리기 서비스와 REST(대안/비교 출처)"를 함께 들고 있으므로 J-9대로 REST 부분을 Should로 분리하는 데 찬성.

### C12a-10 오류 코드 — 수용
- 새 코드 2개(`INVALID_CREDENTIALS`, `NOTHING_TO_UNDO`)를 모듈 예외가 직접 담는 방식은 #17 수용 기준과 같아 전역 advice 수정이 없다.
- 위 C12a-5 (a)를 받아들이면 "결과 계산 실패" 500의 뜻이 "저장도 안 됨"으로 바뀐다는 한 줄만 더한다.

### C12a-11 모듈 의존·시그니처 — 수정
- 의존 표(auth `{}`, plan `{}`, calc `{plan, refdata}` 변경 없음): 수용. `ModularityTests` 통과 설계다.
- `PlanSaveService.save(long memberId, PlanInput input, Long expectedRevision)` → `PlanSaveResult(planVersionId, revision)`: 수용하되 두 가지.
  1. `PlanInput`의 숫자 필드는 `ConditionValidator`가 받는 형태와 같게 한다. `PlanApplyService`가 `Map<String, JsonNode>`(C12b-10-2 (d))이므로 `PlanInput(String goalType, String goalCustomName, Map<String, JsonNode> fields)` 같은 모양을 권한다(검증기 진입점 하나). 이름은 재량.
  2. Javadoc의 "한 트랜잭션"은 "호출자 트랜잭션에 합류(`REQUIRED`)"로 적는다(C12a-5 (a)).
- `PlanUndoService`: 위치만 plan 내부로(C12a-8).
- (h) 추가: `/internal/calc`의 `minDisplay` 변환은 그 컨트롤러 클래스 안에서만(C12a-1).
- (i) 추가: P-4·P-3 응답은 결과 조회 서비스가 돌려준 한 스냅샷으로 조립(C12a-6).

### C12a-12 목 — 수용
- 제공자 비용 없음. 목 id 흐름은 REST Docs 스니펫 값과 맞추면 된다. 단 C12a-5 (a)를 받으면 `put-plan.500.json`의 뜻이 "저장 안 됨"이 된다.

### C12a-13 요구 대응표 — 수용
- 요구 1~10 모두 만족으로 본다.

### C12a-14 코드 차이 Y-n — 수정(추가)
- Y-1~Y-10 수용. 더할 것:
  - **Y-11**: `db/erd.md` Q4-a의 `calc_run` INSERT는 한 트랜잭션 안이다 → 초안의 두 트랜잭션과 다르다(C12a-5 (a)를 받으면 차이 없음, 안 받으면 ERD 정정 필요).
  - **Y-12**: #31 수용 기준 "계획 없음 → 200 + null 키" ↔ 초안 `409 NO_PLAN`.
  - **Y-13**: #30·#31 "문구 키 목록(`tax.note`, D-035 키)" ↔ 초안 응답에 문구 키 없음.
  - **Y-14**: #33 `undoAvailable=true` ↔ 초안 없음.
  - **Y-15**: #31 paths `plan/web/**`만 ↔ P-4 컨트롤러 `calc.web`.
  - **Y-16**: TBD-09 "목표명 100자" ↔ `schema.sql` `VARCHAR(50)`·초안 50자.

### C12a-15 수용 기준 대응표 — 수용

### C12a-16 후속 작업 — 수정
- J-2(#16): 쿠키 리졸버가 `/api/auth/login`에서 토큰을 보지 않음, 서명 키 고정, P-1 `@SkipRenewal`(C12a-2) 추가.
- J-5(#19): `plan` 쓰기 네이티브 `INSERT … ON CONFLICT DO NOTHING`/조건부 `UPDATE` + 0행 예외, 저장 서비스는 호출자 트랜잭션에 합류.
- J-6(#29): 결과 조회 서비스가 현재 계획 스냅샷(`revision`, `currentVersionId`, 입력값)을 함께 반환. 리스너는 기록이 있으면 건너뜀(이미 #29 수용 기준).
- J-7(#30): 한 트랜잭션 유스케이스(calc.application), 계산 실패 시 롤백 + 500, `tax.note` 문구 키 수용 기준 삭제, test paths에 `calc/**`, `/internal/calc` `minDisplay` 변환이 P-3에 붙지 않는 테스트.
- J-8(#31): paths에 `calc/web/**`·`test/.../calc/**`, 선행 #28·#29, "계획 없음 → 200 null" 기준을 `409 NO_PLAN`으로, D-035 문구 키 기준 삭제.
- J-9(#33): `undoAvailable` 문장 삭제, `PlanUndoService` 위치는 plan 내부, REST(P-6) Should 분리.
- J-4(#17): `INPUT_EDIT`에는 CP-07 개수 제한을 걸지 않음.
- J-12a~d 담당(R-11 결과): 아래 R-11.

## R 의견 (제공자)

| # | 의견 |
|---|---|
| R-1 | **수용.** 해커톤에는 "새 목표 세우기" 별도 동작 없음. D-013("시작월을 새로 정하는 동작은 없다")이 확정이고, D-038(버전 갱신)은 D-045로 범위 밖이다. P-3 하나로 계획 유무만 서버가 판단하면 된다. 질문으로 올릴 필요 없다고 본다. |
| R-4 | **수용.** `goalAmount` 10,000~10,000,000,000, `heldAssets` 0~10,000,000,000 KRW. `schema.sql` CHECK(`goal_amount > 0`, `held_assets >= 0`)와 맞고 BIGINT·`long` 계산에서 넘침이 없다(100억 + 1000만 × 360 ≈ 136억). `rules.yml` 임시값 주석으로 둔다(#17 완료 조건과 같음). |
| R-6 | **수용(조건 1개).** 기본 `true`, `auth.cookie.secure=false`는 `local` 프로필에서만. Vite 프록시를 쓰면 브라우저 주소가 `localhost`라 대부분 `true`로도 된다. 조건: **데모 서버가 HTTPS가 아니면 `Secure` 쿠키가 저장되지 않아 로그인이 안 된다.** 데모 배포가 http면 그 프로필도 false가 필요하므로 배포 Issue에 "HTTPS 또는 secure=false" 확인을 남긴다. |
| R-7 | **수용.** P-3 응답 = `PlanView`. 같은 DTO·같은 조립 코드라 추가 비용이 없고 왕복이 1회다. C12a-5 (a)의 한 트랜잭션과도 잘 맞는다(롤백되면 응답도 없음). |
| R-9 | **수용.** 비중 복사. `existing_monthly_contribution`은 항상 NULL. |
| R-11 | `gh api`로 대조함. **#48** = 입력 화면(맞음, `(추정)` 삭제). **#50** = 결과 화면 2: 3구간·과거 수익률 고지·월별 그래프(맞음, `(추정)` 삭제). 고칠 것: (1) J-12c의 **3구간은 #49가 아니라 #50**이다(#49는 요약·조건 바·초과 안내·가정 보기·면책·입력 수정 진입점). (2) **로그인 후 진입 분기(FR-PLAN-06)는 #47과 #51 둘 다에 적혀 있다.** #51 요구사항에 FR-PLAN-06이 있으므로 #51로 모으고 #47에서는 문장을 빼기를 권한다(J-12a 대신 J-12d 쪽). (3) **D-035 보유 자산 안내 문구는 #51**에 있다(초안 J-12b는 #48). (4) #30 = 입력 저장 REST(제목 "결과 보기 API: 검증 → 저장 → 계산 → 결과 응답"), #31 = 현재 계획 조회 REST — 초안 경계와 같다. 다만 둘 다 `[plan]` 제목·plan paths라 C12a-16 J-7·J-8에 paths 수정을 넣어야 한다(Y-15). |
| R-12 | **수용.** "사용자 조작 요청 중 F-2만 연장 제외. 로그인·로그아웃은 쿠키를 핸들러가 직접 내리므로 연장하지 않는다(`@SkipRenewal`)"로 고친다. 로그인도 포함(C12a-2). |
| (참고) R-2·R-3·R-5·R-10 | 소비자 쪽. R-10은 제공자 찬성(409)이지만 #31 본문 정정이 필요(Y-12). R-5의 `afterTaxAssetDisplay`는 빌더 1줄이지만 360점 × 3 문자열이라 응답이 수십 KB 커진다. 넣지 않는 초안 쪽에 찬성. |

## 제공자 쪽에서 꼭 지켜야 할 것
1. **P-3은 한 트랜잭션**(calc.application 유스케이스가 저장 + `calc_run` 기록을 묶음). 이유: ERD Q4-a와 같고, 저장 커밋 뒤 결정적 계산 실패 시 프론트가 409/500 루프에 갇히는 것을 막는다. 모듈 방향(calc → plan)은 그대로라 비용이 없다.
2. **`plan` 쓰기는 조건부 네이티브 쿼리 + 0행 예외 롤백**(`INSERT … ON CONFLICT DO NOTHING`, `UPDATE … WHERE revision=?`). 이유: `member_id`가 할당 PK라 JPA `save()`가 merge로 조용히 덮어쓴다.
3. **쿠키 리졸버는 `/api/auth/login`에서 토큰을 보지 않고, 서명 키는 고정 설정값.** 이유: 리소스 서버 필터는 `permitAll`에서도 잘못된 토큰을 401로 거절해 로그인이 막힌다.
4. **`/internal/calc`의 `minDisplay` 변환은 그 컨트롤러 안에서만.** 이유: P-3도 `calc.web`에 있어 패키지 단위 advice면 C3-5를 깬다.
5. **P-3·P-4 응답은 결과 조회 서비스가 한 번 읽은 스냅샷으로 조립.** 이유: `revision`과 결과가 다른 버전을 가리키면 낙관적 락이 무의미해진다.
6. plan 공개 API(`PlanSaveService`)에 calc·chat·config 타입 없음, plan `{}` 유지.

## 양보 가능한 것
- 알 수 없는 `goalType`을 400(calc.web, `GoalType` 루트)으로 할지 422(plan 검증기)로 할지.
- 로그인 본문의 "문자열이 아닌 값"을 400으로 엄격히 가를지(`JsonNode`) 강제 변환을 허용할지.
- 401 엔트리 포인트의 만료 쿠키 동봉(권장하지만 없어도 위 3으로 로그인은 된다).
- `PlanUndoService`·`PlanInput`·View DTO 이름과 정확한 모양.
- `goalCustomName` 50자 vs TBD-09 100자(제공자는 50자 선호, 100자로 가면 `schema.sql` 길이 변경 1줄 + `db/` 문서).
- P-4 `409 NO_PLAN` vs `200 + null`(어느 쪽도 쉽다. 정한 쪽으로 #31 본문만 맞추면 됨).
