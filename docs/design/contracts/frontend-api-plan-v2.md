# 프론트 ↔ Spring 계획·인증 API 계약 v2 (moeun #12-a)

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` **3단계(검토 반영)**. 결정이 아니라 재검토를 받을 **수정안 v2**다.
> - 입력: `frontend-api-plan-v1.md`, `review-frontapi-plan-v1-provider.md`(A팀, "수정하면 수용"), `review-frontapi-plan-v1-consumer.md`(프론트·B팀, "수정하면 수용").
> - 참고(최종본, 다시 정하지 않음): `frontend-api-chat.md`(#12-b, 머리말 보충 포함), `internal-calc.md`, `plan-context.md`, `docs/decisions.md`(D-001~D-073), `docs/srs.md`, `docs/notion-decisions.md`(TBD-09·TBD-37), moeun(읽기만) `db/{erd,moved-to-code}.md`, `backend/src/main/resources/db/schema.sql`, `backend/.claude/rules/persistence.md`.
> - moeun Issue 번호·범위는 두 검토가 `gh api`로 대조한 값을 쓴다(R-11 해소). 이 단계에서 다시 조회하지 않았다.
>
> **표기**
> - **[합의]**: 양쪽이 수용했거나, 한쪽 제안에 다른 쪽 이견이 없어 반영한 것.
> - **[v2]**: v1에서 바뀐 줄. 전체 목록은 §V(변경 표).
> - **[쟁점 X-n]**: 결정(TBD·D-번호)과 부딪히거나 새 정책이라 **사람이 정한다**. 본문에는 기획 추천안을 임시로 적고 `⟵ 쟁점 X-n`을 단다.
> - **[재검토 확인]**: 한쪽 제안을 기획이 구체화한 곳. 재검토에서 양쪽이 확인한다.
> - 항목 ID(C12a-x, P-x, R-x, Y-x, J-x)는 v1과 같다. 새 항목은 번호를 이어 붙였다.
> - v1과 본문이 같은 절은 "v1과 같음"으로 줄이고 바뀐 줄만 적었다. 최종본에서 합친다.

---

## V. v1 → v2 변경 표

| # | 항목 | v1 | v2 | 근거 | 분류 |
|---|---|---|---|---|---|
| V-1 | C12a-5-2, C12a-11 | 입력 저장(plan)과 결과 계산(calc)은 **다른 트랜잭션**. 계산 실패해도 저장됨 | **한 트랜잭션**: `calc.application` 유스케이스가 열고 `PlanSaveService`가 `REQUIRED`로 합류 → `calc_run(PLAN)` 기록 → 결과·display. 계산 실패면 **저장까지 롤백**, `500 INTERNAL_ERROR` = "저장 안 됨" | 제공자 반대+수정안(v1 근거 "plan이 calc를 못 불러 못 묶는다"는 틀림. 부르는 쪽이 calc). ERD Q4-a도 한 트랜잭션. 소비자 이견 없음(프론트 500 처리가 단순해짐) | 합의 |
| V-2 | C12a-6-1 (신설 C12a-6-6) | 같은 계획에 `calcRunId`가 바뀔 수 있음("2행 무해") | **같은 `revision`(같은 계획 버전) 동안 P-3·P-4가 주는 `calcRunId`는 항상 같다**를 계약 문장으로 고정. 구현: #29 "확인 → 없으면 기록"을 회원 단위 트랜잭션 잠금으로 직렬화 | 소비자 반대 3. V-1만으로는 P-3 경로만 풀리고 F-5·P-5 경로(리스너 vs P-4 재조회 경쟁)는 남는다(§C12a-6-6 분석). 제공자 이견 없음 | 합의 [재검토 확인] |
| V-3 | C12a-12 | 키마다 단건 기본 파일, 25개 | **기본 파일을 시퀀스로**(`get-plan.seq-full-flow`, `put-plan.seq-full-flow`), `put-plan.422-decimals` 추가, 37점 그래프, 28개 | 소비자 반대 1. 제공자 비용 없음 | 합의 |
| V-4 | C12a-6-5 (신설 C12a-6-7) | 공유 상태 `revision`·`calcRunId`·`status`를 "한 번에" 바꿈 | **두 칸**: `revision`(모든 쓰기 응답·PlanView가 갱신) / `view`{revision, calcRunId, status}(PlanView만 갱신). 둘 다 **작은 값으로 덮어쓰지 않음**. D-069는 `revision` 구독, D-072 판단은 `view`가 그 `revision`에 따라잡은 순간, #54 F-3은 `view` 구독 — 구독 지점은 #12-b와 같은 #53 한 곳 | 소비자 반대 2. D-069·D-072·TBD-37("최신 응답만 반영")과 일관. 제공자 영향 없음 | 합의 |
| V-5 | C12a-2-1, C12a-2-2 | 쿠키 리졸버는 경로를 가리지 않음, P-1 연장 칸 "(발급)" | 리졸버는 **`/api/auth/login`에서 토큰을 보지 않음**, JWT 서명 키는 **설정값 고정**, 401 엔트리 포인트가 만료 쿠키를 함께 내림, **P-1에도 `@SkipRenewal`** | 제공자(Spring Security 함정: `permitAll`에서도 깨진 토큰이면 401). 소비자 이견 없음 | 합의 |
| V-6 | C12a-5-2 순서 4 | "첫 저장 PK 충돌이면 409" | `plan` 쓰기는 네이티브 `INSERT … ON CONFLICT (member_id) DO NOTHING` / `UPDATE … WHERE revision=?`, **0행이면 `PlanChangedException`** 롤백 | 제공자(`member_id` 할당 PK라 JPA `save()`가 merge로 조용히 덮어씀) | 합의 |
| V-7 | C12a-11 (h) | — | `/internal/calc`의 `minDisplay`·`CALC_FAILED` 변환은 **그 컨트롤러 클래스 안 `@ExceptionHandler`만**. P-3·P-4는 다른 컨트롤러 클래스 | 제공자. #12-b C12b-7-1·C12b-13 요구 9와 같은 규칙 | 합의 |
| V-8 | C12a-11 (i), C12a-6-3 | 계획 조회(2) → 결과 조회(3)를 따로 읽음 | P-3·P-4 응답은 #29가 **한 번 읽은 현재 계획 스냅샷**(`revision`, `currentVersionId`, 입력값, `baselineScenario`)과 결과로 조립 | 제공자 | 합의 |
| V-9 | C12a-11-1 | `PlanSaveService.save(memberId, PlanInput, Long)` "한 트랜잭션" | `PlanInput(String goalType, String goalCustomName, Map<String, JsonNode> fields)`, Javadoc "호출자 트랜잭션에 합류(`REQUIRED`)". `GoalType`은 plan **루트** enum | 제공자 | 합의 |
| V-10 | C12a-11-1, C12a-8 | `PlanUndoService`는 plan 루트 공개 API | **plan 내부(`plan.application`)**. 호출자가 `plan.web`뿐 | 제공자. 소비자 영향 없음 | 합의 |
| V-11 | C12a-6-1 | `PlanView`에 `conditions`, `result.annualReturnPct`·`requiredMonthlySaving`·`dataVersions`·`baselineScenario`, `plan.calcStartMonth`·`baselineScenario` | **모두 뺀다**(화면 전용 View에서만. planContext·`CalcResultView` 불변) | 소비자 제안. 제공자는 v1 모양을 "수용"했을 뿐 이 필드가 필요하다는 의견 없음, DTO가 줄어 비용 감소 | 합의 |
| V-12 | C12a-6-2 | 점 개수·첫 달은 엔진 재량, 마지막 점만 고정 | **첫 점 `month` = `result.calcStartMonth`(원금 = 세후 = 보유 자산), 마지막 점 `month` = `result.targetMonth`(= 시나리오 값)**. 점 수 = `targetPeriodMonths + 1` | 소비자 제안. 제공자 이견 없음(`MonthlyPoint` 그대로, 첫 점은 View 조립에서 보장 가능) | 합의 [재검토 확인] |
| V-13 | C12a-7 | `display.conditions.heldAssets`·`display["S.x"]` 섞어 씀, 시나리오 순서·미달 표시 미정 | 표기 `display["…"]` 통일, 프론트는 **`["GOOD","AVG","BAD"]` 고정 순서로 있는 것만** 그림, 미달이면 도달 시점 칸에 문구표 `result.notReachedInPeriod` | 소비자 | 합의 |
| V-14 | C12a-0 원칙 1 | 프론트 일: (a)~(d) | (e) 'n년 n개월' ↔ 개월, (f) 422 `min`·`max` → 입력칸 단위 문구 추가. (d)(e)(f)는 **프론트 util 하나 + 단위 테스트** | 소비자 | 합의 |
| V-15 | R-3, C12a-5-4 | 만원 아닌 값 표시 미정 | **만원 칸에 소수 4자리까지 허용, 십진 문자열 자리 이동으로만 변환(부동소수 연산 금지)**. `rules.yml`에 `step`은 **두지 않는다** | 소비자 (b) 변형. 제공자 이견 없음(서버는 원 정수만 받음, 변경 없음). TBD-09 "단위 만원"과 충돌 없음 | 합의 |
| V-16 | R-5 | 기획 추천 "넣지 않음" | (A) 확정: **세로축 눈금 숫자·툴팁·점별 월 라벨 없음** | 소비자 (A), 제공자도 응답 크기 이유로 찬성 | 합의 |
| V-17 | C12a-2-3, C12a-10 | 401은 `code`로 분기 | + 비JSON·파싱 실패 본문은 `code` 없음 → **네트워크 오류 경로**, `UNAUTHENTICATED`면 공유 상태·폴링 모두 비움. `code` 분기 문장을 C12a-10 머리에도 | 소비자 | 합의 |
| V-18 | C12a-3 | 문자열이 아니면 400 | `loginId`·`password` 문자열 강제 변환 허용. 400은 **JSON 파싱 실패·본문이 객체 아님**만 | 제공자 추천(양보 가능 항목 중 기획 추천과 같음), 소비자 이견 없음 | 합의 |
| V-19 | C12a-5-1 | `goalType` 목록은 #19로 미룸 | 계약에 **임시 목록**과 규칙(enum 선언 순서, 표시명 `goal.<CODE>`)을 적는다 | 소비자 요청. 목록 내용은 새 정책 | **쟁점 X-2** |
| V-20 | C12a-5-5 | `goalCustomName` 1~50자 | 기획 추천 **1~100자**(TBD-09) | TBD-09 "목표명 필수·100자" ↔ `schema.sql` `VARCHAR(50)`. 제공자는 50자 선호(양보 가능) | **쟁점 X-1** |
| V-21 | C12a-5-4 | 500 → "결과를 불러오지 못했어요" + P-4 재호출 | 500 → **"저장하지 못했어요", 입력값 유지, P-4 안 부름** | V-1의 결과 | 합의 |
| V-22 | C12a-5-4 | 409 문구 "계획이 다른 곳에서 바뀌었어요" | `plan.changedElsewhere`에 "다시 저장하면 입력한 값으로 바뀌어요" 취지 포함 | 소비자 | 합의 |
| V-23 | R-9, C12a-7 | 비중 복사, 화면에 비중 없음 | 복사 유지 + 입력 화면에 **현재 비중을 읽기 전용**으로 `display["conditions.savingsRatioPct"]` | 소비자. 제공자 비용 없음 | 합의 |
| V-24 | C12a-5-2 | — | `INPUT_EDIT` 경로에는 CP-07 "한 번에 바꾸는 개수" 제한을 걸지 않는다 | 제공자 | 합의 |
| V-25 | R-10, C12a-6-4 | `409 NO_PLAN`(추천) | 확정. **#31 본문 "200 + null 키"를 409로 정정** | 양쪽 찬성 | 합의 |
| V-26 | C12a-6-1 | 응답에 문구 키 없음 | 확정. **#30 `tax.note`·#31 D-035 "문구 키" 수용 기준 삭제** | 제공자 추천, 소비자는 C12a-7(프론트가 키를 직접 고름)을 수용 | 합의 |
| V-27 | C12a-8 | 응답 `{revision}` | 확정. **#33 `undoAvailable` 문장 삭제** | 양쪽 | 합의 |
| V-28 | C12a-9, R-8 | P-6은 #33에서 Should 표시 | **#68**([plan] 대안·비교 적용 확인창, Should)로 옮긴다. 본문은 경로 예약만 | 소비자 제안, 제공자는 "Should 분리" 찬성 | 합의 |
| V-29 | C12a-5-5, Y-9 | `monthlySavingAmount` max 10,000,000 | 확정(#17·TBD-09·D-043과 같음). `frontend-api-chat.md:413` 예시 5,000,000은 **기획 후속 작업(J-15)**으로 정정 | 양쪽 | 합의 |
| V-30 | R-6 | `Secure` 기본 true, 로컬만 끔 | + `secure=false`는 `local` 프로필만, **데모 서버가 HTTPS가 아니면 로그인 불가** → 배포 Issue에서 확인(J-16) | 제공자 조건 | 합의 |
| V-31 | R-12, C12a-15 | "F-2만 `@SkipRenewal`" 정정안 | "사용자 조작 요청 중 연장 제외는 F-2. 로그인·로그아웃은 핸들러가 쿠키를 직접 내리므로 `@SkipRenewal`" | 양쪽 | 합의 |
| V-32 | C12a-16 | J-12a~d 담당 (추정) | #47 로그인·가드·로그아웃 버튼 / #48 입력 화면·422 / #49 요약·조건 바·초과·가정·면책 / **#50 3구간·고지·그래프** / **#51 진입 분기(FR-PLAN-06)·입력 채우기(FR-INP-11)·D-035·되돌리기 토스트** | 양쪽 `gh api` 대조(R-11) | 합의 |
| V-33 | C12a-14 | Y-1~Y-10 | **Y-11~Y-17 추가**(Issue 본문·문서 충돌) | 제공자 + V-2 | 합의 |

- **합의 31건**(V-1~V-18, V-21~V-33), **쟁점 2건**(X-1, X-2).
- **쟁점이 아닌 것으로 정리한 것**: (1) R-3의 `rules.yml step` 도입 — **도입하지 않는다**. 도입하면 대화 되묻기 범위·#17·B팀에 영향이 가는 새 정책이지만, 양쪽 모두 이번 계약에서 쓰지 않는 쪽을 택해 결정 변경이 없다. 나중에 필요하면 그때 Q로 올린다. (2) V-4의 D-072 판단 시점 — D-072 "`revision`이 바뀔 때마다 현재 초과 여부로 다시 판단"을 **정확한 `status`로 판단하기 위한 구현 해석**이며 결정 문장을 바꾸지 않는다(§C12a-6-7). (3) V-2의 잠금 — #12-b C12b-7-3·plan-context C1a-10의 "2행이 생겨도 무해"를 "2행이 생기지 않는다"로 **강화**할 뿐 D-번호와 부딪히지 않는다(Y-17).

---

## C12a-0. 이 계약의 원칙

`frontend-api-chat.md` §0(원칙 1~8)을 그대로 따른다. 이 계약에서 특히 중요한 것:

1. **프론트는 숫자를 만들지 않는다.** 결과 화면의 모든 금액·기간·시점·비율 **문자열**은 Spring `display`를 그대로 쓴다. 프론트가 하는 일은 다음뿐이다. 왜: CP-04 형식이 Spring `Formatter` 한 곳에만 있어야 "화면 숫자 = AI 숫자 글자까지"(PR-04)가 성립한다.
   - (a) `display` 키 찾기, (b) 문구표(CP-05) 키 찾기, (c) 그래프 점 위치 그리기(raw 숫자, 문자열 없음)
   - (d) 입력칸 금액 만원 ↔ 원 변환(C12a-5-6) **[v2]**
   - (e) **[v2]** 입력칸 'n년 n개월' ↔ 개월 변환(C12a-5-6)
   - (f) **[v2]** 422 `min`·`max`·`unit`을 입력칸 단위의 안내 문구로 바꾸기(C12a-5-6)
   - **[v2] (d)(e)(f)는 프론트 util 파일 하나에만 둔다**(단위 테스트 포함, #48). 화면 컴포넌트는 이 util만 부른다. 왜: 화면마다 따로 만들면 CP-04가 어긋난다.
2. **회원은 JWT subject로만 정한다.** 본문·쿼리에 `memberId`가 없다.
3. **`revision`은 내 계획 상태의 유일한 버전 표시다.** 모든 쓰기는 `expectedRevision`을 받고 새 `revision`을 돌려준다. **[v2]** 프론트 공유 상태 규칙은 C12a-6-7.
4. **오류 본문은 C3-1 형식 하나**, 기계 판단은 `code`로만. 프론트 API에는 `minDisplay`·`maxDisplay`가 없다.
5. **새 라이브러리·새 테이블·새 컬럼 없음.** (쟁점 X-1이 B면 컬럼 **길이** 변경 1줄이 생긴다.)

---

## C12a-1. 범위와 엔드포인트 목록

| ID | 메서드·경로 | 하는 일 | 성공 | 컨트롤러 위치(팀) | 토큰 연장 | 우선순위 |
|---|---|---|---|---|---|---|
| P-1 | `POST /api/auth/login` | 로그인, 쿠키 발급, 이전 대화 삭제 | `200 {}` | `auth.web`(A) | **아니오(`@SkipRenewal`, 핸들러가 발급)** [v2] | Must |
| P-2 | `POST /api/auth/logout` | 로그아웃, 쿠키 만료, 이전 대화 삭제 | `200 {}` | `auth.web`(A) | 아니오(`@SkipRenewal`) | Must |
| P-3 | `PUT /api/plan` | 입력 저장: 검증 → 저장 → 계산 → 결과(**한 트랜잭션** [v2]) | `200 PlanView` | `calc.web`(A) | 예 | Must |
| P-4 | `GET /api/plan` | 현재 계획·결과 조회 | `200 PlanView` | `calc.web`(A) | 예 | Must |
| P-5 | `POST /api/plan/undo` | 되돌리기(직전 1단계) | `200 {revision}` | `plan.web`(A) | 예 | Must |
| P-6 | `POST /api/plan/apply` | 대안·비교 결과 적용 | `200 {revision}` | `plan.web`(A) | 예 | **Should(경로 예약만, #68)** [v2] |

- `/api/auth/me`는 두지 않는다(v1과 같음). 입력 저장 = 새 목표 세우기 = 입력 수정, 같은 엔드포인트(R-1 합의).
- P-3·P-4가 `calc.web`인 이유: 결과 계산이 필요하고 의존 방향은 calc → plan뿐이다. **[v2] P-3·P-4 컨트롤러는 `/internal/calc` 컨트롤러와 다른 클래스**다(C12a-11 (h)).

## C12a-2. 인증·쿠키·공통 헤더

#12-b **C12b-2를 그대로 따른다**. 이 절은 #12-a로 미룬 것만 정한다.

### C12a-2-1. 쿠키

| 속성 | 값 | 왜 |
|---|---|---|
| 이름 | `moeun_at` | 서비스 접두어 + access token |
| 값 | JWT(`sub` = memberId, `exp` = 발급 + 30분) | ADR-002, D-052 |
| `HttpOnly` | 항상 | JS가 토큰을 읽지 못하게 |
| `Secure` | 기본 `true`. **[v2] `auth.cookie.secure=false`는 `local` 프로필에서만** | 로컬 http 탈출구. **데모 서버가 HTTPS가 아니면 `Secure` 쿠키가 저장되지 않아 로그인이 안 된다** → 배포 Issue에서 "HTTPS 또는 그 프로필 false" 확인(J-16) |
| `SameSite` | `Lax` | CSRF를 끈 상태의 교차 사이트 방어 |
| `Path` | `/` | |
| `Max-Age` | `1800`. 로그아웃·401 때 `0` | FR-AUTH-02 |

- 토큰은 쿠키 `moeun_at`에서만 읽는 `BearerTokenResolver`(#16). `Authorization` 헤더는 받지 않는다.
- **[v2] 리졸버는 `POST /api/auth/login`에서 `null`을 돌려준다**(토큰을 보지 않는다). 왜: 리소스 서버 필터는 리졸버가 토큰을 주면 `permitAll` 경로에서도 검증하고 실패하면 401을 낸다. 만료·서명 불일치 쿠키가 남은 브라우저가 로그인을 못 하게 된다.
- **[v2] JWT 서명 키는 설정값(환경 변수)으로 고정한다.** 기동마다 새로 만들지 않는다. 왜: 재시작마다 모든 쿠키가 깨진다.
- **[v2] 401 엔트리 포인트는 C3-1 본문과 함께 `moeun_at` 만료 쿠키(`Max-Age=0`, 같은 속성)를 내린다.** 왜: 깨진 쿠키가 브라우저에 남지 않는다. 코드 1줄.
- `/internal/**`은 다른 필터 체인(API 키), 쿠키를 보지 않는다.

### C12a-2-2. 토큰 연장(D-052)

| 요청 | 새 쿠키 | 왜 |
|---|---|---|
| P-1 로그인 | **[v2] `@SkipRenewal`. 핸들러가 새 쿠키를 직접 발급** | 이미 로그인한 상태에서 다시 로그인하면 연장 쿠키(옛 회원)와 핸들러 쿠키가 한 응답에 둘 실릴 수 있다. 위 리졸버 규칙으로도 막히지만 명시한다 |
| P-2 로그아웃 | `@SkipRenewal`. 핸들러가 `Max-Age=0`만 | 만료 쿠키 보호 |
| F-2 폴링 | `@SkipRenewal`(C12b-2) | D-052 |
| 그 밖의 인증된 `/api/**` | 연장(인터셉터 `preHandle`, #34) | FR-AUTH-02 |

- 인증이 통과한 요청의 4xx·5xx에도 연장한다(`preHandle`이라 자연히 그렇다). 필터에서 나는 401에는 붙지 않는다.
- **[v2] Issue #12 수용 기준 문장(R-12)**: "사용자 조작 요청 중 연장 제외는 F-2뿐이다. 로그인·로그아웃은 핸들러가 쿠키를 직접 내리므로 `@SkipRenewal`을 붙인다."

### C12a-2-3. 401 처리와 래퍼 규칙 [v2]

- 보호된 엔드포인트의 쿠키 없음·서명 불일치·만료 → `401 UNAUTHENTICATED`, `errors: []`, `application/problem+json`(+ 만료 쿠키).
- **프론트 래퍼(#13) 규칙**
  1. 분기는 HTTP 상태가 아니라 `code`로만 한다. `code === "UNAUTHENTICATED"`면 로그인 화면. P-1의 `401 INVALID_CREDENTIALS`는 로그인 화면에 머문다(R-2 합의).
  2. **[v2]** 본문이 `application/problem+json`이 아니거나 JSON 파싱에 실패하면(프록시 502, HTML 등) `code`가 없는 것으로 보고 **네트워크 오류 경로**로 보낸다. 로그인 화면으로 보내지 않는다.
  3. **[v2]** `UNAUTHENTICATED`를 받으면 공유 상태(C12a-6-7)를 비우고 폴링을 멈춘 뒤 로그인 화면으로. P-3 중이었다면 입력값은 잃는다(데모 범위에서 수용).
- 403은 쓰지 않는다.

---

## C12a-3. P-1 로그인 `POST /api/auth/login`

v1과 같다. 바뀐 줄만:

- **[v2] 요청 본문**: `loginId`·`password`는 단순 record로 받는다. Jackson이 숫자 등을 문자열로 바꿔 받는 것을 허용한다. `400 MALFORMED_REQUEST`는 **JSON 파싱 실패·본문이 객체가 아님**일 때만. 왜: 로그인에서 400/422를 엄격히 가를 이익이 없다(F-1 `text`와 같은 방침, C12b-4).
- 서버 동작 순서(검증 → 조회·해시 비교 → `MemberLoggedIn` 발행 → JWT 발급·`Set-Cookie` → `200 {}`), 오류 표(400·422 REQUIRED·401 `INVALID_CREDENTIALS`·500), 50자 초과 → 401은 v1과 같다.
- **[v2] 진입 분기**(성공 뒤 P-4 → 200 결과 화면 / `409 NO_PLAN` 입력 화면, FR-PLAN-06)는 **#51** 담당이다. #47은 로그인 화면·라우팅 가드·헤더 로그아웃 버튼.

## C12a-4. P-2 로그아웃 `POST /api/auth/logout`

v1과 같다(인증 필수 → `MemberLoggedOut` 발행 → 만료 쿠키 + `200 {}`, `@SkipRenewal`). 성공·401 모두 프론트는 공유 상태를 비우고 로그인 화면으로.

---

## C12a-5. P-3 입력 저장 `PUT /api/plan`

FR-INP-01~07·09·10·11, FR-RES-01, CP-02, D-013, D-032, D-035, D-045.

### C12a-5-1. 요청

v1과 같은 모양:
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
| `expectedRevision` | integer \| null | 키 필수 | 지금 가진 `revision`. 계획이 없다고 믿으면 `null` |
| `goalType` | string | 예 | `GoalType` 코드. **[v2] 임시 목록은 아래** ⟵ 쟁점 X-2 |
| `goalCustomName` | string \| null | `CUSTOM`일 때만 | FR-INP-02(Should). trim 뒤 **1~100자**(UTF-16) ⟵ 쟁점 X-1. CUSTOM이 아니면 무시하고 `null` 저장 |
| `goalAmount` | integer(KRW) | 예 | |
| `targetPeriodMonths` | integer(MONTH) | 예(D-045) | |
| `heldAssets` | integer(KRW) | 예 | 0 허용 |
| `monthlySavingAmount` | integer(KRW) | 예(D-045) | |
| `savingsRateInputPct` | number(PCT) \| null | 키 필수 | `null` = 기본금리 |

- **[v2] `goalType` 임시 목록**(enum 선언 순서 = 드롭다운 순서, 표시명 문구표 `goal.<CODE>`) ⟵ 쟁점 X-2:
  `HOUSE`(내 집 마련), `CAR`(자동차), `WEDDING`(결혼), `EDUCATION`(교육), `TRAVEL`(여행), `EMERGENCY_FUND`(비상금), `CUSTOM`(직접 입력). 괄호 안은 문구표 임시 문장. `CUSTOM`은 FR-INP-02(Should)를 구현하지 않으면 프론트가 드롭다운에서 숨긴다(코드는 둔다).
- 요청에 없는 것(비중·기존 납입액·시작월·기준 시나리오)과 복사 규칙은 v1과 같다(R-9 합의: 비중은 현재 버전 값 복사).
- 본문 전체를 `JsonNode`(또는 `Map<String, JsonNode>`)로 받아 `ConditionValidator`에 넘긴다. 키 없음과 `null`을 구분해야 하고(`expectedRevision`), Boot 기본 `ACCEPT_FLOAT_AS_INT`로 `300000.5`가 잘리지 않게 한다.

### C12a-5-2. 서버 동작과 검사 순서 [v2]

**`calc.application`의 입력 저장 유스케이스 하나가 `@Transactional`을 연다.** 아래 2~5가 모두 그 안에서 돈다.

| 순서 | 어디서 | 검사·동작 | 결과 |
|---|---|---|---|
| 0 | 필터 | 토큰 | `401 UNAUTHENTICATED` |
| 1 | calc.web | JSON 파싱, 숫자 필드가 JSON 숫자인지, `goalType`이 알려진 코드인지(**`plan.GoalType`은 plan 루트 enum**), `expectedRevision`이 정수 또는 `null` | `400 MALFORMED_REQUEST` |
| 2 | plan `PlanSaveService`(합류) | `PlanInputValidator` + `ConditionValidator.validate(INPUT_EDIT, …)`: `REQUIRED`·`OUT_OF_RANGE`·`NOT_INTEGER`·`TOO_MANY_DECIMALS`·CUSTOM 이름. 걸린 필드 모두. **`INPUT_EDIT`에는 CP-07 개수 제한을 걸지 않는다** | `422 VALIDATION_FAILED` |
| 3 | plan | 계획 있음 + `expectedRevision=null` / 계획 없음 + `≠null` / `plan.revision ≠ expectedRevision` | `409 PLAN_CHANGED` |
| 4 | plan | `plan_version` INSERT(`source='INPUT'`, 시작월·비중 복사 규칙) → **첫 저장: 네이티브 `INSERT INTO plan … ON CONFLICT (member_id) DO NOTHING`**, **수정: `UPDATE plan SET previous=current, current=:v, revision=revision+1 WHERE member_id=? AND revision=?`** → 어느 쪽이든 **영향 0행이면 `PlanChangedException`**(런타임 예외) → `PlanChanged(INPUT)` 발행(커밋 뒤 전달) | 0행 → 전체 롤백 `409 PLAN_CHANGED` |
| 5 | calc 결과 조회 서비스(#29) | 현재 계획 스냅샷을 읽고(4에서 바꾼 값), 그 버전의 PLAN `calc_run`이 없으면 계산·기록(회원 잠금, C12a-6-6) → 결과·display | 성공 `200 PlanView` / **실패면 1~4까지 모두 롤백, `500 INTERNAL_ERROR`** |

- **[v2] 왜 한 트랜잭션인가**: 부르는 쪽이 calc라 의존 방향(calc → plan)을 그대로 두고 묶을 수 있다. 계산 실패는 대개 입력 때문이라 결정적이다. 저장을 먼저 커밋하면 "계산할 수 없는 계획"이 저장되어 P-4도 500 → 옛 `revision`으로 재저장 → 409 → … 루프에 갇힌다. ERD Q4-a도 원래 한 `BEGIN … COMMIT`이다. 비용은 어노테이션 하나, 잠금은 같은 회원의 요청끼리만 겹친다.
- **[v2] 왜 네이티브 쿼리인가**: `plan.member_id`는 할당 PK라 Spring Data `save()`가 `isNew()=false`로 보고 merge(SELECT 후 UPDATE)를 해 두 탭 경쟁에서 조용히 덮어쓴다. `persist`여도 PK 위반은 flush·커밋 때 터져 PostgreSQL 트랜잭션이 abort 상태가 된다. `ON CONFLICT DO NOTHING`은 오류 없이 0행을 돌려준다.
- **[v2] `PlanChanged(INPUT)` 리스너**: 커밋 뒤 돈다. 그 버전의 `calc_run(PLAN)`이 이미 있으므로 **기록을 건너뛴다**(#29 수용 기준 "최신 PLAN 기록이 있으면 다시 기록하지 않음"). v1의 "2행 무해" 문장은 지운다.
- 보유 자산 ≥ 목표는 검증 오류가 아니다. 저장하고 `200`, `result.status = ALREADY_EXCEEDED`(v1과 같음).
- 입력 수정에도 `expectedRevision`을 검사한다(Y-3, PR-08, TBD-37 "버전 확인").

### C12a-5-3. 응답 `200`

P-4와 같은 `PlanView`(C12a-6, R-7 합의). 프론트는 이 응답으로 결과 화면을 그리고 P-4를 부르지 않는다.

### C12a-5-4. 오류와 프론트 동작 (#48 입력 화면)

| HTTP | `code` | `errors` | 프론트 동작 |
|---|---|---|---|
| 400 | `MALFORMED_REQUEST` | `[]` | 개발 오류. "저장하지 못했어요"(`input.saveFailed`) 토스트, 입력값 유지 |
| 422 | `VALIDATION_FAILED` | 1개 이상 | 각 `field` 입력칸 아래 안내. 범위 문구는 C12a-5-6 (f) |
| 409 | `PLAN_CHANGED` | `[]` | **[v2]** 문구표 `plan.changedElsewhere`(취지: "계획이 다른 곳에서 바뀌었어요. 다시 저장하면 입력한 값으로 바뀌어요"). 입력 화면에 머물고 값을 지우지 않는다. P-4를 불러 공유 상태를 새 값으로(`NO_PLAN`이면 규칙은 C12a-6-7) → 다시 누르면 새 `revision`으로 저장. 다른 탭의 변경을 덮어쓰는 것은 의도된 동작 |
| 401 | `UNAUTHENTICATED` | `[]` | 로그인 화면(C12a-2-3) |
| 500 | `INTERNAL_ERROR` | `[]` | **[v2] "저장하지 못했어요" 토스트, 입력값 유지, P-4를 부르지 않는다.** 500이면 계획은 바뀌지 않았다 |

- 422 `errors[].field`는 요청 키 이름(camelCase). `goalCustomName` 길이 초과는 `OUT_OF_RANGE`, `min:1, max:100, unit:"CHAR"` ⟵ 쟁점 X-1.
- 프론트 사전 검사는 "비어 있음"과 입력 형식(C12a-5-6의 숫자 형식)만. 범위 수치는 하드코딩하지 않고 422의 `min`·`max`로 안내한다.

422 예시는 v1과 같다(`monthlySavingAmount` OUT_OF_RANGE `max: 10000000` + `targetPeriodMonths` REQUIRED). **[v2] 소수 예시 추가**:
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
| `monthlySavingAmount` | 10000 | **10000000** | KRW | 0 | #17·TBD-09·D-043과 같음(확정, V-29) |
| `savingsRateInputPct` | 0 | 20 | PCT | 2 | internal-calc C3-3 |
| `targetPeriodMonths` | 1 | 360 | MONTH | 0 | internal-calc C3-3 |
| `goalAmount` | 10000 | 10000000000 | KRW | 0 | 임시(R-4 합의). `rules.yml` 주석에 "임시" |
| `heldAssets` | 0 | 10000000000 | KRW | 0 | 임시(R-4 합의). `long` 계산 넘침 없음 |
| `goalCustomName` | 1 | **100** | CHAR | — | TBD-09 ⟵ 쟁점 X-1 (A면 50) |

- 같은 키는 경로와 무관하게 같은 범위(CP-02). 경로마다 다른 것은 바꿀 수 있는 키 목록뿐.
- **[v2] `rules.yml`에 금액 `step`(예: 10000)은 두지 않는다.** 서버는 원 정수면 받는다. 만원으로 나누어떨어지지 않는 값(대화 적용 345,000원 등)은 C12a-5-6 (d)로 화면에 그대로 보인다.

### C12a-5-6. 프론트 변환 규칙 (util 하나, #48) [v2, 신설]

| 규칙 | 내용 | 예 |
|---|---|---|
| (d) 만원 → 원(보낼 때) | 입력 문자열이 `^\d+(\.\d{1,4})?$`이면 **소수점을 오른쪽으로 네 칸 옮기는 문자열 연산**으로 원 정수를 만든다. 부동소수 곱셈 금지(`1.1*10000 = 11000.000000000002`). 소수 5자리 이상·형식 오류는 프론트가 막는다(입력칸 아래 문구표 안내) | `"30"` → 300000, `"34.5"` → 345000, `"12.3456"` → 123456, `"0.0001"` → 1 |
| (d) 원 → 만원(채울 때) | 원 정수 문자열을 왼쪽으로 네 칸 옮기고 끝의 0과 소수점을 지운다. 반올림·내림 없음 | 300000 → `"30"`, 345000 → `"34.5"`, 1 → `"0.0001"` |
| (e) 기간 | 보낼 때 `년 × 12 + 월`, 채울 때 `년 = floor(m / 12)`, `월 = m % 12` | 36 → 3년 0개월 |
| (f) 422 범위 문구 | `KRW`: (d)로 만원 문자열 + 천 단위 쉼표 + "만원"("약" 없음, 경계는 정확한 값). `MONTH`: `"{n}년 {m}개월"`(CP-04, `minDisplay`와 같은 모양: 1 → "0년 1개월", 360 → "30년 0개월"). `PCT`: `"연 {값}%"`(JSON 숫자를 그대로 문자열로). `CHAR`: `"{n}자"`. 틀 문장은 문구표 | `10000000` → "1,000만원" |
| 금리 칸 | `savingsRateInputPct`는 JSON 숫자 그대로 칸에 넣고, 보낼 때 칸 문자열을 JSON 숫자로. 소수 3자리 이상은 서버 `TOO_MANY_DECIMALS`가 막는다 | |

- 단위 테스트(#48): `34.5 ↔ 345000`, `0.0001 ↔ 1`, `30 ↔ 300000`, `12.34567` 거절, `1.1 → 11000`(부동소수 오류 없음), 360 ↔ 30년 0개월.
- 왜 소수 허용인가: 만원 칸(TBD-09 "단위 만원")을 유지하면서 대화로 적용한 원 단위 값을 **잃지 않고** 보여 줄 수 있다. 내림(R-3 c)은 저장 때 값이 조용히 바뀌어 AI 숫자와 어긋나고, 원 단위 칸(R-3 a)은 TBD-09와 다르다.

---

## C12a-6. P-4 현재 계획·결과 조회 `GET /api/plan`

FR-PLAN-05·06, FR-RES-01~07, FR-INP-11, NFR-INT-02, D-010, D-062, D-072.

### C12a-6-1. 응답 `200` — `PlanView` [v2]

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
    "scenarios": [ { "...": "C1a-4 ScenarioResult 그대로 + monthlyPoints (annualReturnPct 없음)" } ],
    "assumptions": { "...": "C1a-4 그대로" }
  },
  "display": { "...": "C1a-6 키·형식 그대로" }
}
```

| 필드 | 타입 | 뜻 | 누가 쓰나 |
|---|---|---|---|
| `revision` | integer | `plan.revision` | 공유 상태(C12a-6-7) |
| `calcRunId` | integer | 이 결과의 `calc_run(PLAN)` id. **같은 `revision` 동안 항상 같다**(C12a-6-6) | `view` → #54 F-3 |
| `baselineResultScenario` | `GOOD`\|`AVG`\|`BAD`\|null | 결과 요약에 쓸 시나리오(`findBaselineResult()`, 대체 규칙 포함). 초과면 `null` | #49 |
| `plan` | object | 사용자가 입력한 원래 값(원 단위, nullable 그대로). **[v2] `calcStartMonth`·`baselineScenario` 없음** | #51 입력 채우기 |
| `result` | object | **[v2] `status`, `goalAmount`, `calcStartMonth`, `targetMonth`, `scenarios[]`(+`monthlyPoints`), `assumptions`만** | 판단·그래프 점 |
| `display` | object | C1a-6 키·형식(접두어 `""`, 조건 `"conditions."`) | 화면의 모든 숫자 문자열 |

- **[v2] 내보내지 않는 것**: `conditions`(raw 6키, 화면은 `display`), `result.annualReturnPct`(수익 약속처럼 읽힐 위험, display도 없음), `result.requiredMonthlySaving`(항상 null), `result.dataVersions`, `result.baselineScenario`·`plan.baselineScenario`(`baselineResultScenario`로 충분, FR-RES-09 Should 때 다시), `plan.calcStartMonth`(D-035 안내는 `display["calcStartMonth"]`), `currentVersionId`·`previousVersionId`·`undoAvailable`·`memberId`. 왜: 프론트·대화창이 쓰지 않는 필드는 화면 전용 View에서 뺀다. 공개 `CalcResultView`·planContext는 그대로다.
- **[v2] 응답에 문구 키 목록을 넣지 않는다.** 키는 고정이라 서버가 줄 정보가 없고 프론트가 C12a-7대로 고른다(#30 `tax.note`·#31 D-035 "문구 키" 수용 기준 삭제, Y-13).
- `display`는 planContext와 같은 `ResultDisplayBuilder`(#28)가 같은 접두어로 만든다. `<S>.goalReachMonth`는 `isAchieved=true`일 때만 있다.

### C12a-6-2. `monthlyPoints` [v2]

| 필드 | 이 계약 |
|---|---|
| `scenarios[].monthlyPoints` | 있다(planContext·`/internal/calc`에는 키 자체가 없음) |
| `[].month` | `"YYYY-MM"` |
| `[].principal` | integer(KRW). 그 달까지 넣은 원금(보유 자산 포함) |
| `[].afterTaxAsset` | integer(KRW). 그 달의 세후 예상 자산 |

- **[v2] 첫 점**: `month = result.calcStartMonth`, `principal = afterTaxAsset = plan.heldAssets`(보유 자산은 운용 수익 없음, CP-03).
- **[v2] 마지막 점**: `month = result.targetMonth`, `principal`·`afterTaxAsset` = 그 시나리오의 `principal`·`afterTaxAsset`.
- **[v2] 점 수 = `targetPeriodMonths + 1`**, 달마다 하나, 오름차순. 왜: 가로축 양 끝 라벨(`display["calcStartMonth"]`·`display["targetMonth"]`)과 점이 맞아야 프론트가 축을 다시 만들지 않는다.
- 구현 메모(A팀 재량): 엔진(#27) `MonthlyPoint` 목록이 첫 달(k=0)을 내지 않으면 화면 View 조립(#31)이 앞에 붙인다. 엔진 테스트는 마지막 점 = 시나리오 값(#27), View 테스트는 첫 점·점 수(#31). [재검토 확인]
- 응답 DTO는 `calc.web` 화면 전용 View. 공개 `CalcResultView`(monthlyPoints 없음)는 바꾸지 않는다.

### C12a-6-3. 서버 동작 [v2]

1. 필터 → `401`.
2. calc 결과 조회 서비스(#29, ERD Q1)가 **plan 공개 현재 계획 조회를 한 번** 부른다. 행이 없으면 `409 NO_PLAN`.
3. 그 스냅샷(`revision`, `currentVersionId`, 입력값, `baselineScenario`)의 버전으로 PLAN `calc_run`을 찾고 없으면 계산·기록(C12a-6-6). 결과 + `ResultDisplayBuilder`.
4. 컨트롤러는 #29가 돌려준 **스냅샷 + 결과 하나**로 `PlanView`를 만든다. 계획을 따로 다시 읽지 않는다. 왜: 두 번 읽으면 사이에 다른 탭의 적용이 끼어 `revision`과 결과가 다른 버전을 가리키고, 프론트가 화면과 다른 계획의 `revision`으로 F-5를 보내 검사를 통과해 버린다.

- GET이 `calc_run`을 INSERT할 수 있어 읽기 전용 트랜잭션이 아니다. 재로그인 시 최신 데이터로 다시 계산하지 않는다(D-010).

### C12a-6-4. 오류와 프론트 동작

| HTTP | `code` | 프론트 동작 |
|---|---|---|
| 409 | `NO_PLAN` | 빈 입력 화면(FR-PLAN-06). 공유 상태 규칙은 C12a-6-7 |
| 401 | `UNAUTHENTICATED` | 로그인 화면 |
| 500 | `INTERNAL_ERROR` | 결과 화면 자리에 `result.loadFailed` + 다시 시도 버튼. 대화창은 그대로 |

- **[v2] `409 NO_PLAN` 확정**(R-10, 양쪽 찬성). `200 {plan:null}`은 `PlanView`가 nullable이 되어 모든 소비자 분기가 늘어난다. #31 본문의 "계획 없음 → 200 + null 키"를 고친다(Y-12).

### C12a-6-5. 언제 부르나

- 앱 시작·새로고침, 로그인 성공 직후(#51), F-5·P-5·P-6 성공 뒤, `PLAN_CHANGED`를 받은 뒤, F-3 `404` 뒤(C12b-3a).
- P-3 성공 뒤에는 부르지 않는다. **[v2] P-3 500 뒤에도 부르지 않는다**(저장 안 됨).
- 응답 처리는 C12a-6-7.

### C12a-6-6. 같은 계획 버전 = 같은 `calcRunId` [v2, 신설]

**계약 문장**: 같은 `revision`(같은 `plan.current_version_id`) 동안 P-3·P-4가 돌려주는 `calcRunId`는 **항상 같다.** 왜: #54는 "`calcRunId`가 바뀌고 `CALCULATED`면 F-3"(C12b-3a)이라, 같은 계획에서 id가 바뀌면 설명이 한 번 더 생긴다(소비자 반대 3).

V-1(한 트랜잭션)로 풀리는 범위:

| 경로 | 같은 버전의 PLAN 기록을 만드는 쪽 | V-1만으로 |
|---|---|---|
| P-3 입력 저장 | 유스케이스(트랜잭션 안) → 커밋 뒤 리스너는 기록을 보고 건너뜀 | **풀림** |
| F-5 대화 적용, P-5 되돌리기, (P-6) | 커밋 뒤 비동기 리스너 **와** 프론트의 P-4 재조회가 거의 동시에 "없으면 기록" | **안 풀림**: 둘 다 "없음"을 보고 2행 → 첫 P-4는 자기 id, 다음 P-4는 최신(다른) id |

그래서 #29에 하나를 더한다(구현 권장, A팀 재량이되 위 계약 문장을 테스트로 고정):
- **#29의 "현재 버전의 PLAN 기록 확인 → 없으면 계산·기록"을 회원 단위 트랜잭션 잠금으로 감싼다**: 확인 전에 `SELECT pg_advisory_xact_lock(:memberId)`(PostgreSQL 내장, 새 라이브러리·스키마 변경 없음). `PlanChanged` 리스너도 **같은 메서드**로 기록한다. 그러면 둘 중 늦은 쪽은 앞쪽이 커밋한 행을 보고 건너뛴다. 조회는 지금처럼 `findLatest(planVersionId, PLAN)`이고 행이 하나라 "최신 = 유일"이다.
- 잠금은 같은 회원의 기록 경로끼리만 겹치고 ms 단위다. P-3 트랜잭션은 `plan` 행 잠금 뒤 이 잠금을 잡고, 리스너·P-4는 `plan`을 잠그지 않고 읽기만 하므로 교착이 없다.
- 기각한 대안: "가장 작은 id 선택"(소비자 예시) — 데이터 버전이 바뀌는 Q1-c 분기에서 옛 행을 계속 골라 매번 재기록하는 잠재 버그가 있다(해커톤에선 안 돌지만 남겨 둘 이유가 없다). 유일 제약 — 스키마 변경이고 #12-b C12b-7-3이 두지 않기로 했다.
- 테스트(#29): 같은 버전에 대해 리스너와 결과 조회를 동시에 실행 → `calc_run(PLAN)` 1행, 두 호출의 `calcRunId` 같음.
- 이로써 #12-b C12b-7-3·plan-context C1a-10의 "2행이 생길 수 있으나 무해"는 "생기지 않는다"로 강해진다(Y-17, 기획 문서 정정 J-15).

### C12a-6-7. 프론트 공유 계획 상태 [v2, 신설]

공유 상태(#13이 만드는 store 하나, 팀 공용)는 **두 칸**이다.

| 칸 | 값 | 누가 쓰나(갱신) | 누가 읽나(구독) |
|---|---|---|---|
| `revision` | integer \| null | P-3·P-4 `200`의 `revision`, F-5·P-5·(P-6) `200`의 `revision` | #53 적용 버튼 비활성(D-069), #51 되돌리기 토스트 닫기, 모든 쓰기의 `expectedRevision` |
| `view` | `{revision, calcRunId, status}` \| null (+ 그 `PlanView` 본문) | **P-3·P-4 `200`의 `PlanView`만** | #49·#50 결과 화면, #54 F-3 호출, D-072 초과 판단 |

**갱신 규칙**
1. **작은 값으로 덮어쓰지 않는다.** `revision`은 새 값이 지금 값보다 클 때만, `view`는 새 `PlanView.revision`이 지금 `view.revision` **이상**일 때만 바꾼다(같으면 바꿔도 `calcRunId`가 같다, C12a-6-6). 왜: 서버 `revision`은 모든 변경(되돌리기 포함)에서 1씩만 오르므로, 작은 값은 늦게 도착한 옛 응답이다(TBD-37 "최신 응답만 반영").
2. **`null`로 되돌리는 경우**: 로그아웃 성공·`UNAUTHENTICATED`(래퍼가 두 칸 모두 비움). `409 NO_PLAN`은 **지금 `revision`이 `null`일 때만** 상태를 그대로 두고 입력 화면으로 간다. 값이 있는데 온 `NO_PLAN`은 늦은 응답으로 보고 무시한다. 왜: 계획을 지우는 API가 없어 한 번 생긴 계획은 사라지지 않는다. [재검토 확인]
3. 최초 로드(`null` → N)는 "바뀜"으로 보지 않는다(#12-b C12b-7-4).

**구독 규칙**(구독 지점은 #12-b와 같은 대화창 #53 훅 하나 + #54 effect 하나)
- **D-069**(#53): `revision` 칸이 바뀌면(최초 로드 제외) 그때 가진 모든 적용 버튼을 끈다. #12-b C12b-7-4 그대로.
- **D-072**(#53 같은 훅, 표시는 #52): `revision`이 바뀐 뒤 **`view.revision === revision`이 되는 순간**(= 그 계획의 결과가 도착한 순간) `view.status`로 초과 여부를 다시 판단한다. 그 전까지는 지금 표시를 유지한다. 왜: F-5·P-5 응답은 `{revision}`뿐이라 `revision` 칸만 먼저 바뀌고 `status`는 P-4가 와야 안다. 바뀐 순간에 판단하면 옛 `status`로 틀리게 판단한다. "`revision`이 바뀔 때마다 현재 초과 여부로"(D-072)를 정확한 값으로 지키는 해석이며 결정 문장은 그대로다.
- **#54 F-3**: `view.calcRunId`가 바뀌고 `view.status === "CALCULATED"`이면 한 번 부른다(C12b-3a 그대로, 초과면 안 부름 D-062).
- **#51 되돌리기 토스트**: 토스트가 들고 있는 값(직전 적용 응답의 `revision`)과 `revision` 칸이 달라지면 닫는다. P-4 재조회는 같은 값을 주므로 닫지 않는다.
- **결과 화면**(#49·#50): `view`의 `PlanView` 본문만 그린다.

목 흐름(C12a-12)에서 PUT 뒤의 GET이 작은 `revision`을 줘도 규칙 1로 무시된다.

## C12a-7. 결과 화면이 계산하지 않기 위한 대응표 [v2]

표기는 모두 `display["키"]`(키는 점 포함 평면 문자열). 이 표에 없는 숫자 문자열을 프론트가 만들면 계약 위반이다.

| 영역(SRS, Issue) | 문자열 출처 | 판단에 쓰는 raw |
|---|---|---|
| 조건 바(FR-RES-05, #49) | 목표명: 문구표 `goal.<goalType>` 또는 `plan.goalCustomName`. `display["goalAmount"]`, `display["conditions.monthlySavingAmount"]`, `["conditions.targetPeriodMonths"]`, `["conditions.savingsRatioPct"]`, `["conditions.savingsRateInputPct"]`, `["conditions.heldAssets"]` | `result.assumptions.isDefaultSavingsRate` |
| 결과 요약(FR-RES-02, #49) | `S = baselineResultScenario`일 때 `display["S.afterTaxAsset"]`, `display["S.gapToGoal"]`, `display["targetMonth"]`, 문구표 `scenario.<S>` | 그 시나리오 `isAchieved` |
| 3구간(FR-RES-03, **#50**) | **`["GOOD","AVG","BAD"]` 고정 순서로 돌며 `result.scenarios`에 있는 것만** 그린다(배열 순서에 기대지 않는다). 칸마다 `display["<S>.afterTaxAsset"]`, `["<S>.gapToGoal"]`, 도달 시점은 `isAchieved`면 `display["<S>.goalReachMonth"]`, 아니면 **문구표 `result.notReachedInPeriod`**("기간 안에 도달하지 않아요", planContext C1a-11 ai 문장과 같은 뜻). 아래 고지 한 줄은 문구표(D-029) | 시나리오 수(1이면 ETF 0%), `isAchieved` |
| 그래프(FR-RES-04, **#50**) | 목표선 라벨 `display["goalAmount"]`, 가로축 양 끝 `display["calcStartMonth"]`·`display["targetMonth"]`, 시나리오 최종값 라벨은 `display["S.afterTaxAsset"]`. **세로축 눈금 숫자·툴팁·점별 월 라벨은 없다**(R-5 A 확정) | `monthlyPoints[]`(점 위치), `result.goalAmount`(목표선 높이) |
| 초과 안내(FR-RES-01, #49) | 문구표 `result.alreadyExceeded` 안에 `display["goalAmount"]`, `display["conditions.heldAssets"]`. 초과 금액 없음 | `view.status === "ALREADY_EXCEEDED"` → 요약·3구간·그래프·대안 숨김, F-3 안 부름(D-062) |
| 가정 보기(FR-RES-06, #49) | `display["assumptions.taxRatePct"]` + 문구표 `tax.note`(D-067), `display["conditions.savingsRateInputPct"]`, `display["assumptions.savingsRateBaseMonth"]`·`["assumptions.sp500BaseDate"]`(없으면 줄 생략), 문구표 `excluded.<CODE>`, `scenarioMethod.<CODE>` | `result.assumptions.excludedItems`, `scenarioMethod`, `isDefaultSavingsRate` |
| 면책(FR-RES-07, #49) | 문구표 `disclaimer` | — |
| 입력 수정 채우기(FR-INP-11, **#51**) | 입력칸 값: `plan.*` → C12a-5-6 (d)(e). **현재 비중 읽기 전용 한 줄**: 문구표 라벨 + `display["conditions.savingsRatioPct"]`(R-9, 입력 화면에 비중 칸이 없으므로). 재로그인 보유 자산 안내: 문구표(D-035) + `display["calcStartMonth"]` | `plan.savingsRateInputPct === null`이면 금리 칸 비움 |

- 문구표 키 이름은 #18에서 확정. `excluded.*`·`scenarioMethod.*`·`tax.note`는 planContext와 같은 키.
- 대안 영역(Should)은 이 표 밖.

---

## C12a-8. P-5 되돌리기 `POST /api/plan/undo`

v1과 같다(요청 `{expectedRevision}`, 응답 `{revision}`, 검사 순서 읽기 → `NO_PLAN` → `NOTHING_TO_UNDO` → `PLAN_CHANGED` → 복사 INSERT(D-068) → 조건부 UPDATE 0행 롤백 → `PlanChanged(UNDO)`, 오류별 프론트 동작표). 바뀐 줄만:

- **[v2] `PlanUndoService`는 plan 내부(`plan.application`)**에 둔다. 호출자가 `plan.web`뿐이라 루트 공개 API일 필요가 없다(`modulith.md` "루트에는 다른 모듈이 쓰는 것만"). 시그니처는 v1과 같다.
- **[v2] 응답·서비스 반환 모두 `undoAvailable`이 없다.** #33 본문의 `undoAvailable=true` 문장을 지운다(Y-14).
- **[v2] 토스트 닫기**는 공유 상태 `revision` 칸 기준(C12a-6-7). 성공 뒤 순서: `revision` 갱신 → 토스트 닫기 → P-4 재조회(F-3은 #54).
- 새 버전의 `calc_run(PLAN)`은 리스너 또는 P-4가 기록하며 C12a-6-6 잠금으로 1행이다.

## C12a-9. P-6 대안·비교 적용 `POST /api/plan/apply` — Should, 경로 예약만 [v2]

- 경로 `POST /api/plan/apply`, 성공 `200 {revision}`, `plan.web`, `PlanApplyService.apply(…, expectedBaseVersionId=null)` 재사용만 예약한다. **요청 모양·오류·목은 #68**([plan] 대안·비교 적용 확인창, Should)에서 2주차 말에 확정한다. #33(Must)은 P-6을 들고 있지 않는다. 왜: Should를 Must Issue에 두면 Must 완료를 막는다.
- 대화 적용은 F-5뿐이다(`CHAT` 출처는 P-6에서 받지 않는다).

## C12a-10. 오류 공통 규칙과 코드 표

**[v2] 기계 판단은 HTTP 상태가 아니라 `code`로만 한다**(래퍼 규칙 C12a-2-3). 형식은 internal-calc C3-1, 공통 규칙은 #12-b C12b-9 그대로.

코드 표는 v1과 같다(400 `MALFORMED_REQUEST`, 401 `UNAUTHENTICATED`·`INVALID_CREDENTIALS`, 404, 405/415, 409 `NO_PLAN`·`PLAN_CHANGED`·`NOTHING_TO_UNDO`, 422 `VALIDATION_FAILED`·`FIELD_NOT_CHANGEABLE`(P-6), 500 `INTERNAL_ERROR`). 바뀐 줄만:

- **[v2] P-3의 `500 INTERNAL_ERROR`는 "저장되지 않았다"는 뜻**이다(한 트랜잭션 롤백).
- `CALC_FAILED`는 이 계약에 나오지 않는다. P-3·P-4의 계산 실패는 전역 `INTERNAL_ERROR`(C12a-11 (h)).
- 새 코드 `INVALID_CREDENTIALS`(auth), `NOTHING_TO_UNDO`(plan)는 모듈 예외가 `ErrorResponseException`으로 `code`를 직접 담는다. 전역 advice는 고치지 않는다.
- 예시 JSON은 v1과 같다.

---

## C12a-11. 모듈 의존과 호출 순서

### C12a-11-1. 의존 표와 시그니처 [v2]

의존 표는 v1과 같다(auth `{}`, plan `{}`, calc `{plan, refdata}` 변경 없음, chat `{calc, rag, plan, auth}`). `ModularityTests` 그대로 통과한다.

```
calc.web(P-3, P-4) ──▶ calc.application(입력 저장 유스케이스 @Transactional, 결과 조회 #29, ResultDisplayBuilder #28)
                                └──▶ plan(PlanSaveService: REQUIRED 합류, 현재 계획 조회)   [calc → plan, 기존]
plan.web(P-5, P-6) ──▶ plan.application(PlanUndoService, PlanApplyService)
auth.web(P-1, P-2) ──▶ auth.application ──publish──▶ MemberLoggedIn/Out ──(동기)──▶ chat
```

지켜야 할 것(C12b-10-2 (a)~(d)에 더해):
- (e) plan 공개 저장 서비스의 인자·반환에 calc·chat·config 타입이 없다.
- (f) `calc.web`은 plan 루트 공개 API만 쓴다. **[v2] `GoalType`은 plan 루트 enum**.
- (g) auth는 plan을 모른다.
- **(h) [v2]** `/internal/calc`의 422 `minDisplay`·`maxDisplay` 덧붙이기와 500 `CALC_FAILED`는 **그 컨트롤러 클래스 안의 `@ExceptionHandler`에만** 둔다. `@RestControllerAdvice(basePackages = "…calc.web")`로 만들지 않는다. 왜: P-3도 `calc.web`이라 패키지 단위면 P-3 422에 `minDisplay`가 붙어 C3-5를 깬다. #30·#32 테스트 "P-3 422에 `minDisplay` 없음".
- **(i) [v2]** P-3·P-4 응답은 #29 결과 조회 서비스가 돌려준 **한 스냅샷**으로 조립한다(C12a-6-3).
- **(j) [v2]** 같은 계획 버전의 PLAN 기록 확인·기록은 회원 잠금 아래 한 메서드(#29)로만 한다. 리스너도 이 메서드를 쓴다(C12a-6-6).

```java
// plan 루트 (#19). chat·calc·config 타입 없음.
public interface PlanSaveService {
    /**
     * 입력 저장(INPUT). 호출자 트랜잭션에 합류한다(Propagation.REQUIRED).
     * 검증(INPUT_EDIT) → revision 검사 → plan_version INSERT
     * → plan 네이티브 INSERT ... ON CONFLICT DO NOTHING / UPDATE ... WHERE revision=? (0행이면 PlanChangedException)
     * → PlanChanged(INPUT). 시작월·비중은 현재 버전에서 복사(없으면 요청 월·NULL).
     * @param expectedRevision null = 계획이 없다고 믿음
     */
    PlanSaveResult save(long memberId, PlanInput input, Long expectedRevision);
}
public record PlanInput(String goalType, String goalCustomName, Map<String, JsonNode> fields) {}  // fields: camelCase 숫자 키, ConditionValidator 입력과 같은 모양
public record PlanSaveResult(long planVersionId, long revision) {}
public enum GoalType { HOUSE, CAR, WEDDING, EDUCATION, TRAVEL, EMERGENCY_FUND, CUSTOM }  // ⟵ 쟁점 X-2

// plan.application (#33). 공개 API 아님.
interface PlanUndoService { PlanUndoResult undo(long memberId, long expectedRevision); }
record PlanUndoResult(long planVersionId, long revision) {}
```
- 결과 조회 서비스 반환(#29, 이름 재량)은 "현재 계획 스냅샷(`revision`, `currentVersionId`, 입력값, `baselineScenario`) + `calcRunId` + 결과 + display"를 함께 담는다. planContext QUESTION도 같은 서비스를 쓴다.

### C12a-11-2. 호출 순서 [v2]

**로그인 → 진입 (FR-PLAN-06, #51)**
```
브라우저 ─POST /api/auth/login─▶ auth.web (@SkipRenewal, 리졸버는 이 경로에서 토큰을 보지 않음)
  auth: 검증 → 해시 비교 → publish MemberLoggedIn ─(동기)─▶ chat: DELETE chat_message
  auth: JWT 발급 → Set-Cookie moeun_at → 200 {}
브라우저 ─GET /api/plan─▶ calc.web
  ├ 409 NO_PLAN → 입력 화면
  └ 200 PlanView → revision·view 갱신 → 결과 화면 → (#54) view.calcRunId 바뀜 + CALCULATED → F-3
```

**입력 저장 (FR-INP-10)**
```
브라우저 ─PUT /api/plan {expectedRevision, ...}─▶ calc.web
  calc.application 유스케이스 BEGIN
    plan.PlanSaveService.save (합류: 검증 → revision → INSERT/UPDATE, 0행이면 예외 → PlanChanged(INPUT))
    #29 결과 조회 (회원 잠금 → 이 버전 PLAN 기록 없음 → 계산·기록) → 스냅샷 + 결과 + display
  COMMIT  (계산 실패면 ROLLBACK → 500, 저장 안 됨)
  ◀─200 PlanView
[커밋 뒤, 비동기] calc 리스너: 회원 잠금 → 이 버전 PLAN 기록 있음 → 건너뜀
브라우저: revision·view 갱신 → (#53) 버튼 비활성(D-069), view 따라잡음 → 초과 재판단(D-072) → (#54) F-3
```

**되돌리기 (FR-PLAN-04)**
```
브라우저(토스트) ─POST /api/plan/undo {expectedRevision}─▶ plan.web
  plan: 읽기 → NO_PLAN / NOTHING_TO_UNDO / PLAN_CHANGED → 복사 INSERT → 조건부 UPDATE → PlanChanged(UNDO)
  ◀─200 {revision}
브라우저: revision 갱신(버튼 비활성, 토스트 닫힘) → GET /api/plan → view 갱신 → 초과 재판단 → (#54) F-3
[커밋 뒤, 비동기] calc 리스너와 P-4 중 먼저 잠금을 잡은 쪽만 기록 (calcRunId 하나)
```

**로그아웃**: v1과 같다(+ 래퍼가 두 칸 모두 `null`).

---

## C12a-12. 목(mock) JSON 목록 [v2]

**형식·선택 방식은 #12-b C12b-12 그대로**(파일 = `{responses: [...]}`, 요청 키 = 메서드 + 경로, 키마다 기본 파일 하나, 그 밖은 `useMock`, 배열 끝을 넘으면 마지막 반복, `status`·`headers` 반영).

- 기준 계획(A-1 계획)·`body` 줄임표 금지·REST Docs 스니펫 값 일치는 v1과 같다.
- **[v2] `monthlyPoints` 채우는 규칙(목 전용)**: 시나리오마다 **37점**, `month` = 2026-11 … 2029-11(k = 0…36), `principal = heldAssets + monthlySavingAmount × k`, `afterTaxAsset = principal + round(그 시나리오 afterTaxGain × k / 36)`. 첫 점은 원금 = 세후 = 보유 자산, 마지막 점 = 시나리오 값(C12a-6-2).
- **[v2] 헤더 `Set-Cookie`는 브라우저가 `Response`에 넣지 않는 금지 헤더라 무시된다.** 목에서는 설명용이다.
- **[v2] 기본 파일은 시퀀스**다. 이것 하나로 "앱 시작 → 로그인 → 입력 → 결과 → 대화 적용 → 되돌리기 → 입력 수정"이 목만으로 돈다. #12-b 목과 id가 이어진다.

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
| **`plan/get-plan.seq-full-flow.json` (기본)** [v2] | P-4 | 401 → 409 → 200 → 200 | 위 순서 1·3·6·8 |
| `plan/get-plan.200.json` | P-4 | 200 | A-1 계획, `rev 12`, `540`, 3구간 모두 미달 |
| `plan/get-plan.200-etf0.json` | P-4 | 200 | plan-context A-2(`541`), AVG 1개, `plan.savingsRatioPct: 100` |
| `plan/get-plan.200-exceeded.json` | P-4 | 200 | plan-context A-3(`542`), `ALREADY_EXCEEDED`, `scenarios: []`, `baselineResultScenario: null` |
| `plan/get-plan.200-after-apply.json` | P-4 | 200 | `rev 13`, `553` |
| `plan/get-plan.200-after-undo.json` | P-4 | 200 | `rev 14`, `554` |
| `plan/get-plan.409-no-plan.json` | P-4 | 409 | `NO_PLAN` |
| `plan/get-plan.401.json` | P-4 | 401 | `UNAUTHENTICATED` |
| `plan/get-plan.500.json` | P-4 | 500 | `INTERNAL_ERROR` |
| **`plan/put-plan.seq-full-flow.json` (기본)** [v2] | P-3 | 200 → 200 | 위 순서 4·9 |
| `plan/put-plan.200.json` | P-3 | 200 | `get-plan.200`과 같은 본문 |
| `plan/put-plan.200-exceeded.json` | P-3 | 200 | `get-plan.200-exceeded`와 같은 본문 |
| `plan/put-plan.422-range.json` | P-3 | 422 | `OUT_OF_RANGE`(`max 10000000`) + `REQUIRED` |
| **`plan/put-plan.422-decimals.json`** [v2] | P-3 | 422 | C12a-5-4 소수 예시(`NOT_INTEGER` + `TOO_MANY_DECIMALS` `scale 2`) |
| `plan/put-plan.422-custom-name.json` | P-3 | 422 | `goalCustomName` `OUT_OF_RANGE`(`min 1, max 100, unit CHAR`) ⟵ 쟁점 X-1 |
| `plan/put-plan.409-plan-changed.json` | P-3 | 409 | `PLAN_CHANGED` |
| `plan/put-plan.400.json` | P-3 | 400 | `MALFORMED_REQUEST` |
| `plan/put-plan.500.json` | P-3 | 500 | `INTERNAL_ERROR`(**저장 안 됨**) |
| `plan/post-undo.200.json` (기본) | P-5 | 200 | `{revision: 14}` |
| `plan/post-undo.409-nothing.json` | P-5 | 409 | `NOTHING_TO_UNDO` |
| `plan/post-undo.409-plan-changed.json` | P-5 | 409 | `PLAN_CHANGED` |
| `plan/post-undo.409-no-plan.json` | P-5 | 409 | `NO_PLAN` |
| `plan/post-undo.500.json` | P-5 | 500 | `INTERNAL_ERROR` |

- 총 **28개**(auth 6, plan 22). v1 25개 + 시퀀스 기본 2개 + `422-decimals`. 단건 `get-plan.200`·`put-plan.200`은 기본이 아니게 되어 개별 화면 개발용(`useMock`)으로 남는다. P-6 목은 없다(#68).
- 공통 401은 #12-b `chat/common.401-unauthenticated.json` 재사용.
- 9번 뒤의 GET은 마지막 응답(`rev 14`)을 반복한다. C12a-6-7 규칙 1로 무시되어 화면은 `rev 15`를 유지한다(규칙 시험에도 쓴다).

---

## C12a-13. #12-b C12b-13 대응표 [v2]

v1과 같다. 바뀐 행만:

| # | 요구 | 이 문서 | 상태 |
|---|---|---|---|
| 3 | F-2 `@SkipRenewal` | **P-1·P-2에도** `@SkipRenewal`(C12a-2-2) | 만족 + 추가(#34) |
| 4 | 현재 계획·결과에 `revision`·`calcRunId`·`status`, 입력 저장 응답에 `revision` | `PlanView`(C12a-6-1). **같은 버전 = 같은 `calcRunId`**(C12a-6-6) | 만족(#29·#30·#31) |
| 10 | 결과 화면이 `revision`·`calcRunId`·`status`를 공유 상태로 | **두 칸 규칙**(`revision` / `view`) + 작은 값 무시(C12a-6-7). F-3은 #54가 `view`를 구독 | 만족(#13 store, #49·#51·#53·#54) |

## C12a-14. moeun 현재 코드·문서와 다른 곳 (코드 차이 Y-n) [v2]

Y-1~Y-10은 v1과 같다(Y-9의 후속은 J-15로 옮김). 추가:

| # | 위치 | 지금 | 이 계약 | 후속 |
|---|---|---|---|---|
| Y-11 | `db/erd.md` §4 Q4-a | 저장·`calc_run` 한 트랜잭션, `ON CONFLICT DO UPDATE` | 한 트랜잭션은 **같음**. 다른 점은 Y-3(revision 검사)뿐 | J-5 |
| Y-12 | #31 수용 기준 | 계획 없음 → `200` + null 키 | `409 NO_PLAN` | J-8 |
| Y-13 | #30·#31 수용 기준 | 응답에 문구 키 목록(`tax.note`, D-035 키) | 응답에 문구 키 없음, 프론트가 C12a-7대로 고름 | J-7, J-8 |
| Y-14 | #33 수용 기준 | 적용·대안 REST에 `undoAvailable=true` | 없음. P-6 REST는 #68 | J-9, J-17 |
| Y-15 | #30·#31 `paths`·선행 | `plan/**`만, #31 선행 #30 | `calc/web/**`·`calc/application/**`·`test/.../calc/**` 추가, 선행 #19·#28·#29 | J-7, J-8 |
| Y-16 | `schema.sql` `goal_custom_name VARCHAR(50)` | 50자 | TBD-09 100자 ⟵ 쟁점 X-1 | J-5 |
| Y-17 | `frontend-api-chat.md` C12b-7-3, `plan-context.md` C1a-10 | 같은 버전 PLAN 기록 2행 가능, "무해" | 회원 잠금으로 **2행이 생기지 않는다**(같은 버전 = 같은 `calcRunId`) | J-6, J-15 |

## C12a-15. Issue #12 수용 기준 대응표

v1과 같다. 11번 비고만: 수용 기준 문장을 C12a-2-2 [v2] 문장으로 고친다(J-1).

---

## R. 검토 요청 항목의 결과 [v2]

| # | 결과 |
|---|---|
| R-1 | **합의**: 별도 "새 목표 세우기" 동작 없음. P-3 하나. 질문으로 올리지 않는다(D-013, D-038은 D-045로 범위 밖) |
| R-2 | **합의**: `401 INVALID_CREDENTIALS` + `code` 분기, 래퍼 규칙 2줄 추가(C12a-2-3) |
| R-3 | **합의**: 만원 칸 소수 4자리 + 십진 문자열 변환(C12a-5-6). `step` 없음 |
| R-4 | **합의**: 임시 1만원~100억 / 0~100억 |
| R-5 | **합의**: (A) 숫자 없는 그래프 |
| R-6 | **합의**: `local` 프로필만 false, 배포 HTTPS 확인(J-16) |
| R-7 | **합의**: P-3 응답 = `PlanView` |
| R-8 | **합의**: P-6은 #68에서 확정 |
| R-9 | **합의**: 비중 복사 + 입력 화면 읽기 전용 표시 |
| R-10 | **합의**: `409 NO_PLAN` |
| R-11 | **해소**: 두 검토의 `gh api` 대조로 C12a-16 담당을 고침(V-32) |
| R-12 | **합의**: C12a-2-2 [v2] 문장 |

## X. 쟁점 (사람이 정한다)

### 쟁점 X-1. 직접 입력 목표명 길이: 50자 vs 100자

- **부딪히는 것**: Notion **TBD-09**(결정, "목표명 필수·100자") ↔ moeun `schema.sql` `goal_custom_name VARCHAR(50)`, v1 초안 50자.
- **선택지**

| 안 | 내용 | 영향 |
|---|---|---|
| A | 50자 유지 | 스키마·코드 변경 없음. TBD-09와 다르므로 **D-번호로 TBD-09를 바꾼다는 결정 기록 필요**. `rules.yml` max 50, 목 `max 50` |
| B | 100자로 맞춤 | `schema.sql` `VARCHAR(100)` 1줄 + `db/tables.md`·ERD 표기, `rules.yml` max 100, 목 `max 100`. 운영 데이터가 없어 이전 비용 없음 |

- **의견**: 제공자 A 선호(스키마 변경 없음, FR-INP-02는 Should), 양보 가능. 소비자 의견 없음(422 `max`를 읽기만 하므로 영향 없음).
- **기획 추천: B.** 팀이 이미 정한 값(TBD-09)을 따르면 결정 변경이 없고 비용은 1줄이다. A는 비용이 0이지만 팀 결정을 뒤집는 기록이 필요하다.
- **개발 차단 여부**: 아니오. FR-INP-02가 Should이고 Must 작업은 숫자 하나만 다르다. #19(스키마)·#17(규칙) 착수 전에 정하면 된다.

### 쟁점 X-2. 목표 종류(`GoalType`) 목록

- **부딪히는 것**: 결정 없음(새 정책). FR-INP-01은 "1개 선택"만, `moved-to-code.md`는 "enum `GoalType`, 직접 입력은 `CUSTOM`, 순서는 선언 순서, 표시명 `goal.<CODE>`"만 정했다. 소비자(#48 드롭다운)가 계약에 목록을 요구했다.
- **선택지**

| 안 | 내용 | 영향 |
|---|---|---|
| A | 기획 임시 목록: `HOUSE`(내 집 마련), `CAR`(자동차), `WEDDING`(결혼), `EDUCATION`(교육), `TRAVEL`(여행), `EMERGENCY_FUND`(비상금), `CUSTOM`(직접 입력) | 바로 #19 enum, #18 문구, #48 드롭다운, 목에 쓴다. 나중에 바꾸면 enum·문구표·목 몇 줄 |
| B | 사람이 목록을 새로 정한다 | 정할 때까지 목·드롭다운은 A로 개발하고 정해진 뒤 교체 |

- **의견**: 소비자 "임시라도 적어 달라". 제공자 의견 없음(코드는 enum 하나, `goal_type_code VARCHAR(30)`이라 스키마 영향 없음).
- **기획 추천: A**(데모용 일반 목표 + 직접 입력, 계산 로직은 목표 종류와 무관). 목록의 적절성은 사람이 확인한다.
- **개발 차단 여부**: 아니오. 계산은 `goalType`을 쓰지 않는다.

---

## C12a-16. 후속 작업 (D-058: 기존 Issue 본문에 반영) [v2]

| # | 작업 | 팀 | Issue | 선행 |
|---|---|---|---|---|
| J-1 | `docs/api/frontend-api.md`에 #12-a 절, 목 28개(`mocks/auth/`, `mocks/plan/`, 시퀀스 기본 2개), #12 수용 기준 `@SkipRenewal` 문장 정정(R-12) | 공통 | **#12** | 쟁점 X-1·X-2 결정(목 숫자·코드만) |
| J-2 | P-1: 엔드포인트, 쿠키 `moeun_at`(`auth.cookie.secure`, `local` 프로필만 false), 쿠키 리졸버(**로그인 경로는 토큰 무시**), **서명 키 설정값 고정**, `permitAll`, C3-1 401 엔트리 포인트 **+ 만료 쿠키**, `INVALID_CREDENTIALS`, 422 REQUIRED, 400은 파싱 실패만, `MemberLoggedIn` 발행, 시드, `auth/package-info`. 테스트: 깨진 쿠키를 가진 채 로그인 성공 | A | **#16** | — |
| J-3 | P-2 로그아웃, `@SkipRenewal`과 연장 인터셉터, **P-1·P-2 핸들러에 `@SkipRenewal`**(P-1이 먼저 머지되면 이 Issue에서 붙임), `MemberLoggedOut` | A | **#34** | — |
| J-4 | `rules.yml › input.fields` 범위(C12a-5-5, 월 저축액 max 10,000,000, `goalCustomName` max는 X-1), **`INPUT_EDIT`에 CP-07 개수 제한 없음**, `CHAR` 단위, `step` 없음 | A | **#17** | X-1 |
| J-5 | `PlanSaveService`(`PlanInput` + `Map<String, JsonNode>`, **`REQUIRED` 합류**), **`plan` 네이티브 `ON CONFLICT DO NOTHING` / 조건부 UPDATE + 0행 `PlanChangedException`**, 시작월·비중 복사, `PlanChanged(INPUT)`, **`GoalType` plan 루트 enum**(X-2 목록), ERD Q4-a 정정(Y-3·Y-11), `persistence.md:14` 정정(Y-5), `goal_custom_name` 길이(X-1이 B면 `schema.sql` 1줄, Y-16) | A | **#19** | X-1, X-2 |
| J-6 | 결과 조회 서비스가 **현재 계획 스냅샷 + `calcRunId` + 결과 + display**를 함께 반환, **"확인 → 기록"을 `pg_advisory_xact_lock(memberId)` 아래 한 메서드로**, 리스너도 같은 메서드(있으면 건너뜀). 테스트: 동시 실행 → 1행·같은 `calcRunId` | A | **#29** | — |
| J-6b | 엔진 테스트: `monthlyPoints` 마지막 점 = 시나리오 값 | A | **#27** | — |
| J-7 | `PUT /api/plan`: `calc.web` **별도 컨트롤러 클래스**, `calc.application` **한 트랜잭션 유스케이스**, 계산 실패 → 롤백 + 500, 응답 `PlanView`. **`tax.note` 문구 키 수용 기준 삭제**(Y-13), paths에 `calc/web/**`·`calc/application/**`·`test/.../calc/**`(Y-15), 테스트 "P-3 422에 `minDisplay` 없음"·"계산 실패 시 `plan_version`·`plan` 변화 없음", `backend/CLAUDE.md` 모듈 표 한 줄(Y-6) | A | **#30** | #19, #28, #29 |
| J-8 | `GET /api/plan`: `PlanView` v2 필드(C12a-6-1), **`409 NO_PLAN`(200 null 기준 삭제, Y-12)**, **D-035 문구 키 기준 삭제**(Y-13), 스냅샷 조립, `monthlyPoints` 첫 점·점 수(V-12), 화면 전용 View DTO, paths·선행(Y-15) | A | **#31** | #19, #28, #29 |
| J-9 | `POST /api/plan/undo`: `PlanUndoService`(**plan.application**), 검사 순서, 복사 INSERT(D-068), 응답 `{revision}`, `NOTHING_TO_UNDO`, ERD Q4-c 정정(Y-4). **`undoAvailable` 문장 삭제, P-6 REST 부분은 본문에서 빼고 #68로**(Y-14) | A | **#33** | — |
| J-10 | display 키가 planContext와 같은 빌더·접두어인지 확인(변경 없음) | A | **#28** | — |
| J-11 | 래퍼: `code` 분기, **비JSON 본문 → 네트워크 오류**, **`UNAUTHENTICATED` → 공유 상태·폴링 비움**, 목 키 5개·시퀀스 기본. **공유 계획 상태 store(두 칸, 작은 값 무시, `NO_PLAN` 규칙)**(C12a-6-7) + 단위 테스트 | 공통 | **#13** | #12-b H-16과 합침 |
| J-12a | 로그인 화면(`INVALID_CREDENTIALS`, 비밀번호 칸 비움, 500), 라우팅 가드, 헤더 로그아웃. **진입 분기 문장은 빼서 #51로** | A | **#47** | — |
| J-12b | 입력 화면: P-3 요청, **변환 util(C12a-5-6 (d)(e)(f)) + 단위 테스트**, `goalType` 드롭다운(X-2), 422 필드별 안내(소수 포함), `PLAN_CHANGED`(값 유지), **500 "저장하지 못했어요"(P-4 안 부름)** | A | **#48** | X-2(목록만) |
| J-12c | 결과 화면 1: 요약·조건 바·초과 안내·가정 보기·면책(C12a-7), `view`만 그림, 500 다시 시도 | A | **#49** | J-11 |
| J-12d | 결과 화면 2: **3구간(GOOD/AVG/BAD 고정 순서, 1개 경우, `result.notReachedInPeriod`), D-029 고지, 그래프(숫자 눈금·툴팁 없음, 첫/끝 점)** | A | **#50** | J-11 |
| J-12e | **로그인 후 진입 분기(FR-PLAN-06), 입력 수정 채우기(FR-INP-11, util 사용), 현재 비중 읽기 전용, D-035 안내**, 되돌리기 토스트(`revision` 칸 기준 닫기, 오류별 동작, F-3 없음) | A | **#51** | J-11, #12-b H-11d와 합침 |
| J-12f | D-069: `revision` 칸 구독(그대로), **D-072: `view.revision === revision`이 된 순간 `view.status`로 판단**, #54 F-3은 `view` 구독 | B | **#53**(구독 훅), **#52**(초과 문장 표시), **#54**(F-3) | J-11 |
| J-13 | 문구표 키 추가: `input.saveFailed`, `plan.changedElsewhere`(V-22 취지), `result.notReachedInPeriod`, `input.currentRatioLabel`(이름 재량), `goal.<CODE>`(X-2), 그 밖 v1 J-13 목록 | 공통 | **#18** | X-2 |
| J-14 | `db/erd.md` §5-G·§3, ADR-002 §2-5·§3, `moved-to-code.md` §1·§2 정정(Y-1, Y-5) | A | **#34**(문서 paths 추가) 또는 문서 Issue | — |
| J-15 | 기획 문서 정정: `b-team-contracts.md` §4·`alignment.md` 2-4(Y-8), **`frontend-api-chat.md:413` 예시 `max` 10000000**(Y-9), **C12b-7-3·plan-context C1a-10 "2행 무해" → "생기지 않음"**(Y-17) | 기획 | project-workspace(이 협상 마무리 때) | — |
| J-16 | 데모 배포가 HTTPS인지 확인, 아니면 그 프로필 `auth.cookie.secure=false`(R-6) | A | **배포 Issue**(번호 확인 필요) | — |
| J-17 | P-6 `POST /api/plan/apply` 요청·오류·목 확정(Should, 2주차 말) | A | **#68** | — |

---

## 재검토 요청 (4단계, 최대 1회)

- **제공자(A팀)**: V-2·C12a-6-6(회원 advisory 잠금과 리스너가 같은 메서드를 쓰는 구조가 #29에 맞는지), V-12(첫 점을 View 조립에서 붙이는 것), C12a-6-7 규칙 2(`NO_PLAN` 무시 근거 "계획 삭제 API 없음"이 사실인지), V-11(뺀 필드 중 테스트·REST Docs에 필요한 것이 있는지), 쟁점 X-1·X-2 의견.
- **소비자(프론트·B팀)**: C12a-6-7 두 칸·구독 규칙이 #53·#52·#54 구현과 맞는지(특히 D-072 판단 시점), C12a-5-6 (f)의 `MONTH` 문구를 `"30년 0개월"`(CP-04·`minDisplay`와 같은 모양)로 바꾼 것, `result.notReachedInPeriod`, 목 시퀀스 9단계, 쟁점 X-2 목록.
