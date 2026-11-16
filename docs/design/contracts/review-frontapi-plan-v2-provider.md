# 재검토: 프론트 ↔ Spring 계획·인증 API 계약 v2 (#12-a) — 제공자(A팀 Spring) 관점

> 검토자: contract-provider, 2026-11-16. `/negotiate-contract` 4단계(마지막 1회). 대상 `frontend-api-plan-v2.md`.
> 근거: moeun origin/develop(9a31166) `backend/src/**`(`calc/MonthlyPoint.java`, `calc/ScenarioResult.java`, `calc/CalcResult.java`, `calc|plan/package-info.java`), `schema.sql`, `db/erd.md` §4 Q1·Q4, `backend/.claude/rules/persistence.md`, `docs/decisions.md`, `docs/notion-decisions.md`(TBD-04·05·09), moeun Issue 본문 `gh api` 조회(#9 #16 #19 #20 #26 #27 #29 #30 #31 #33 #34 #56 #58 #63 #68 #78, 전체 78개 제목 목록).

```
판정: 수정하면 수용
```

v1 제공자 "꼭 지켜야 할 것" 6개는 모두 반영됐다(아래 1절). 남은 반대는 **1건**(V-12 첫 점을 View에서 붙이는 것)이고, 나머지는 구현 함정을 막는 문장 추가와 Issue 배치 정정이다.

## 1. v1 제안 반영 여부

| v1 제안 | v2 | 판정 |
|---|---|---|
| P-3 한 트랜잭션(calc.application, `REQUIRED` 합류, 실패 시 롤백 500) | V-1, C12a-5-2, V-21 | 반영 |
| `plan` 네이티브 `ON CONFLICT DO NOTHING`/조건부 UPDATE + 0행 예외 | V-6 | 반영(구현 함정 1개 추가, 3절 J-5) |
| 로그인 경로 리졸버 null, 서명 키 고정, 401 만료 쿠키, P-1 `@SkipRenewal` | V-5 | 반영 |
| `minDisplay` 변환은 `/internal/calc` 컨트롤러 안에서만 | V-7, (h) | 반영 |
| 한 스냅샷으로 PlanView 조립 | V-8, (i) | 반영 |
| `PlanInput` 모양, `REQUIRED` Javadoc, `GoalType` 루트, `PlanUndoService` 내부 | V-9, V-10 | 반영 |
| 리스너는 기록이 있으면 건너뜀("2행 무해" 삭제) | C12a-5-2, V-2 | 반영(더 강하게: 잠금) |
| `INPUT_EDIT`에 CP-07 없음 | V-24 | 반영 |
| Y-11~Y-16, #30·#31·#33 본문 정정 | V-25~V-27, V-33 | 반영 |
| R-6 배포 HTTPS 조건 | V-30, J-16 | 반영(Issue 번호 없음, 4절) |
| R-11 #50 3구간, #51 진입 분기·D-035 | V-32 | 반영 |

## 2. 재검토 요청 항목

### 2-1. V-2·C12a-6-6 회원 advisory 잠금 + 리스너가 같은 메서드 — **수용(조건 4개)**

구조는 맞고, 더 단순한 대안이 없다.
- 대안 검토: (a) "가장 작은 id 선택"은 v2 기각 이유 외에도 **경쟁하는 당사자에게는 안정적이지 않다**. 두 트랜잭션이 동시에 기록하면 늦은 쪽은 앞쪽의 미커밋 행을 못 보고 자기 id(554)를 응답하고, 다음 조회부터 553을 준다. (b) `plan` 행 `SELECT … FOR UPDATE`를 잠금으로 쓰는 안은 calc가 plan 공개 API에 "잠금 조회"를 요구해 트랜잭션 의미가 모듈 경계를 넘고, F-5 적용이 계산 시간만큼 기다린다. (c) 리스너 기록을 없애도 두 탭의 P-4 경쟁이 남는다. → advisory 잠금이 calc 안에서 끝나는 가장 작은 변경이다. 새 라이브러리·스키마 변경 없음, Testcontainers PostgreSQL로 동시성 테스트 가능.
- 교착 분석도 맞다. 잠금 순서가 "plan 행 → advisory"(P-3) 하나뿐이고 P-4·리스너·QUESTION은 plan 행을 잠그지 않는다. F-5·P-5는 advisory를 잡지 않는다.

**지켜야 할 조건(J-6 #29, 일부 #78에 문장으로)**
1. **기록 메서드는 호출자 트랜잭션 안에서만 돈다**(`Propagation.MANDATORY` 권장). `pg_advisory_xact_lock`은 트랜잭션 끝에 풀리므로 트랜잭션 밖(autocommit)에서 부르면 그 문장이 끝나자마자 풀려 아무것도 막지 못한다. `REQUIRES_NEW`도 안 된다: P-3에서는 아직 커밋 안 된 `plan_version`을 새 트랜잭션이 못 봐 FK 위반이 난다.
2. **격리 수준은 PostgreSQL 기본 READ COMMITTED**, 잠금 획득 **뒤에** `findLatest`를 실행한다. REPEATABLE READ면 스냅샷이 잠금 대기 전에 잡혀 앞쪽이 커밋한 행을 못 보고 2행이 생긴다. 잠금 문장보다 앞서 같은 조회를 해 둔 JPA 결과를 재사용하지 않는다.
3. **호출 트랜잭션이 `readOnly=true`면 안 된다.** #78 수용 기준 "메서드별 자체 `@Transactional`(읽기 중심)"을 구현자가 `readOnly = true`로 옮기면 `findForCurrentPlan` → #29 기록 INSERT가 PostgreSQL에서 "read-only transaction" 오류로 실패한다(P-4 GET도 같음, C12a-6-3 마지막 줄은 이미 맞게 적혀 있다). J-6에 한 줄, #78 본문에 한 줄("`findForCurrentPlan`은 readOnly 아님").
4. **리스너는 `@ApplicationModuleListener`(커밋 뒤, 새 트랜잭션)** 로 받아 같은 메서드를 부른다. 같은 트랜잭션의 `@EventListener`로 받으면 P-3 안에서 이미 잡은 잠금을 재진입해 의미가 없고, 커밋 전 실행이 된다.
- (양보 가능) 잠금 키는 다른 advisory 사용과 겹치지 않게 두 인자형 `pg_advisory_xact_lock(<상수>, memberId)`(int, int)나 고정 접두 해시를 권한다. 해커톤에선 다른 사용처가 없어 `bigint` 하나도 된다.
- (양보 가능) 매 조회마다 잠금을 잡기 싫으면 "잠금 없이 조회 → 있으면 반환, 없으면 잠금 → 다시 조회 → 기록"(이중 확인)으로 해도 같은 보장이다. QUESTION 매 턴 비용이 ms라 필수는 아니다.

**계약 문장 정정(작음)**: C12a-6-6 "같은 `revision` 동안 `calcRunId`는 항상 같다"는 `db/erd.md:472` Q1-(c)·#29 G-18("**활성 버전과 같은** 최신 PLAN 기록이 있으면 다시 기록하지 않음") 때문에 **활성 기준 데이터 버전이나 `engine_version`이 바뀌면 깨진다**(같은 버전에 새 행). 해커톤에선 재배포 때만 생긴다. 수정안: "기준 데이터 활성 버전과 `engine_version`이 그대로인 동안"을 붙인다. 결과는 F-3 한 번 더(설명 1회 중복)뿐이라 소비자 영향은 작다.

### 2-2. V-12 그래프 첫 점을 #31(View 조립)에서 붙이기 — **반대, 엔진(#26)으로**

- `ScenarioResult.monthlyPoints` Javadoc이 이미 "계산 시작월부터의 월별 예상 자산"(`calc/ScenarioResult.java` `@param monthlyPoints`)이다. 시계열 정의는 엔진 것이다.
- 납입 시점(월초/월말)이 **아직 미정**이다(TBD-04·05 "미답변", #9가 확정). 월초 납입으로 정해져 엔진 첫 점이 `calcStartMonth`(납입 포함)가 되면, View가 앞에 `calcStartMonth` 점을 하나 더 붙여 **같은 달이 두 번** 나온다. View는 엔진 관례를 모르고 붙일 수 없다.
- P-3 응답도 `PlanView`라 View 조립은 #31이 아니라 **#30이 먼저** 만든다(C12a-5-3). "#31에서 붙임"은 담당도 어긋난다.
- 수정안: C12a-6-2 규칙(첫 점 = `calcStartMonth`·원금 = 세후 = 보유 자산(납입 전 출발점), 마지막 점 = `targetMonth`·시나리오 값, 점 수 = `targetPeriodMonths + 1`)은 **그대로 두고** 지키는 곳을 엔진으로 옮긴다. J-6b를 "#26: 시계열 첫 점·점 수, #27: 마지막 점 = 시나리오 값"으로, #9 명세에 "k번째 점 = k번째 납입 뒤, 월 = 시작월 + k"를 한 줄. View 테스트(#30·#31)는 복사만 확인한다. 엔진이 늦으면 View에서 붙이는 임시 처리는 A팀 재량이지만 계약 문장의 담당은 엔진.

### 2-3. C12a-6-7 규칙 2 "계획 삭제 API 없음" — **사실이다. 단 근거 문장은 틀림, 운영 절차 1줄 필요**

- API로는 맞다: 이 계약·#12-b·plan-context와 열린 Issue 78개 어디에도 계획 삭제 엔드포인트가 없다. `plan`·`plan_version`의 `ON DELETE CASCADE`는 `member` 삭제 때뿐인데 회원 삭제 기능도 없다(`schema.sql:70,95`).
- 그러나 "한 번 생긴 계획은 사라지지 않는다"는 틀리다. **#58 수용 기준 "초기화 절차를 실행하면 계획·대화가 지워지고"**로 DB 밖 경로에서 지워진다. 서명 키를 고정(V-5)했으므로 초기화 뒤에도 열린 탭의 쿠키는 유효하고, 그 탭은 `revision`이 있어 `409 NO_PLAN`을 무시해 옛 결과 화면에 머문다(쓰기는 `NO_PLAN`·`PLAN_CHANGED`만 받음).
- 규칙 자체는 유지에 찬성(프론트 판단이 단순). 수정안: 근거를 "계획을 지우는 API가 없다(데모 초기화는 예외: 초기화 뒤 열린 브라우저는 새로고침 또는 다시 로그인)"로 고치고, #58 `docs/demo-setup.md` 초기화 절차에 그 한 줄을 넣는다(4절 J-16과 함께). 새로고침하면 상태가 `null`에서 시작해 `NO_PLAN`을 받아들인다.

### 2-4. V-11 뺀 필드가 테스트·REST Docs에 필요한가 — **수용, 필요한 것 없음**

- REST Docs는 응답에 있는 필드만 문서화하므로 빼도 문제 없다. 데이터 버전 기록(NFR-INT-02)은 #29가 `calc_run` 행으로 검증하고 응답을 보지 않는다. 가정 보기의 기준월·기준일은 `display["assumptions.*"]`로 나간다.
- `plan.savingsRatioPct`(raw)는 남는다(입력 채우기와 무관하지만 해롭지 않음). 화면 전용 View라 `CalcResultView`·planContext 테스트(#32·#78)에 영향 없다.

### 2-5. 그 밖에 v2에서 새로 본 것

- **(J-5, 구현 함정) 네이티브 UPDATE 뒤 JPA 1차 캐시**: 순서 3에서 `plan`을 JPA로 읽고(revision 비교) 순서 4에서 네이티브 `UPDATE`를 하면, 같은 영속성 컨텍스트에 남은 `Plan` 엔티티는 옛 값이다. 순서 5에서 #29가 plan 공개 조회로 다시 읽으면 Hibernate가 캐시 인스턴스를 돌려줘 **옛 `revision`·`currentVersionId`로 PlanView를 만든다**(계산도 옛 버전). 수정안: 네이티브 쓰기에 `@Modifying(flushAutomatically = true, clearAutomatically = true)`, 또는 순서 3의 읽기를 엔티티가 아닌 프로젝션으로. #19 수용 기준에 "저장 직후 같은 트랜잭션의 현재 계획 조회가 새 `revision`·`currentVersionId`를 돌려준다" 테스트 한 줄.
- (확인) X-1이 B면 `ddl-auto=validate`는 VARCHAR 길이를 검사하지 않아 엔티티 `@Column(length)`만 맞추면 된다. 앱 검사 "UTF-16 100자"는 PostgreSQL 문자 수(코드 포인트) 100보다 항상 엄격하므로 DB 오류가 나지 않는다.

## 3. 쟁점 최종 의견

- **X-1(목표명 50 vs 100자): B(100자) 수용.** v1에서 50자를 선호한 이유는 변경 비용 0이었는데, B의 비용은 `schema.sql` 1줄 + 엔티티 `length` + `db/tables.md` 1줄로 운영 데이터가 없어 이전 비용도 없다. 팀 결정(TBD-09)을 뒤집는 기록을 남기는 쪽이 더 비싸다. 조건: `schema.sql`·`db/tables.md`를 **#19 paths에 추가**(지금 `plan/**`뿐). 사람이 늦게 정해도 #19(week 1, Must)를 막지 않도록 "결정 전에는 100으로 진행, A로 정해지면 숫자만 바꿈"을 J-5 선행 칸에 적는다.
- **X-2(GoalType 임시 목록): A 수용.** 계산은 `goalType`을 쓰지 않고 `goal_type_code VARCHAR(30)`이라 스키마 영향 없다. 주의 1줄: 코드 이름은 `plan_version.goal_type_code`에 저장되므로 **데이터가 생긴 뒤 코드를 지우거나 이름을 바꾸면 옛 행을 enum으로 읽을 때 실패**한다. 목록 변경은 #19 머지 전이 싸고, 그 뒤면 #58 초기화와 함께 한다. 이것도 #19를 막지 않게 "임시 목록으로 진행".

## 4. 후속 작업 J-1~J-17 배치 (Issue 본문 `gh api` 대조)

| J | 대상 | 의견 |
|---|---|---|
| J-1 | #12 | 맞음 |
| J-2 | #16 | 맞음(paths `auth/**`·`config/security/**`에 리졸버·엔트리 포인트 포함) |
| J-3 | #34 | **조건문 삭제**: "P-1이 먼저 머지되면 이 Issue에서 붙임" → "P-1 핸들러의 `@SkipRenewal`은 #34가 붙인다". `@SkipRenewal` 타입을 #34가 만들고 #34 선행이 #16이라 #16은 붙일 수 없다 |
| J-4 | #17 | 맞음 |
| J-5 | #19 | paths에 `backend/src/main/resources/db/schema.sql`(X-1), `db/tables.md` 추가. **`persistence.md:14` 정정은 빼라**: #33 본문이 이미 같은 줄을 고친다(paths 중복). ERD Q4-a 정정은 J-14와 함께 #20으로(아래). 2-5의 1차 캐시 테스트 추가. 선행 X-1·X-2는 "막지 않음, 임시값으로 진행" |
| J-6 | #29 | 2-1 조건 4개 + 계약 문장 정정. 스냅샷 반환은 #78(`findForCurrentPlan`이 #29 호출)에도 영향이 있으니 #78 본문에 "readOnly 아님" 한 줄(J-6 비고로) |
| J-6b | #27 → **#26 + #27** | 2-2. 첫 점·점 수는 #26(시계열 골격, paths `CalcEngine.java`), 마지막 점은 #27. #9에 "k번째 점 = 시작월 + k" 한 줄 |
| J-7 | #30 | 선행 칸을 **덮어쓰지 말고 더한다**: 지금 #17·#19·#27·#28·#29가 이미 있다(v2 표 "#19, #28, #29"로 바꾸면 #17·#27이 빠짐). paths: `plan/web/**`는 P-3에 불필요(컨트롤러가 calc.web), `test/.../plan/**` → `test/.../calc/**`. 제목 `[plan]` → `[calc]` 권장. View 조립 첫 구현이 여기라 2-2의 "복사만 확인" 테스트도 여기 |
| J-8 | #31 | 선행 **#30을 유지**하고 #19·#28·#29를 더한다(PlanView DTO·조립을 #30이 먼저 만든다). paths `plan/web/**` → `calc/web/**`, `test/.../calc/**`. 제목 `[calc]` 권장. "첫 점·점 수" 항목은 2-2대로 엔진으로 |
| J-9 | #33 | 맞음 |
| J-10 | #28 | 맞음 |
| J-11·J-12a~f·J-13 | #13, #47~#54, #18 | 제공자 의견 없음(소비자 대조값과 일치) |
| J-14 | #34 → **#20** | #20([docs] `db/tables.md`·`db/decision.md`·`db/moved-to-code.md`, team:common, week 1, 선행 없음)이 같은 파일을 이미 고치는 열린 Issue다. #34(auth 코드)에 문서 paths를 붙이는 것보다 맞다(D-058 "같은 범위 기존 Issue에 합침"). `db/erd.md`를 #20 paths에 추가하고 J-5의 ERD Q4-a(Y-3·Y-11)도 여기로. 단 #33도 `db/erd.md` Q4-b·c를 고치므로 동시 진행 금지(#20을 먼저) |
| J-15 | 기획 | 맞음. Y-17 문장도 2-1 단서("활성 버전·engine_version이 그대로인 동안")로 |
| J-16 | **배포 Issue 없음** | 78개 Issue 전체를 봤다. 배포·HTTPS·도메인을 다루는 Issue가 없다. 가까운 것: **#58**([demo] 데모 계정·시드·시연 입력 세트, `docs/demo-setup.md`, team:common, week 3, 환경 초기화 절차 포함), #56(3서버 통합, `docker-compose.yml`), #63(README·환경 변수 최종 정리). **#58에 넣기를 권한다**: (1) 데모 접속 주소가 HTTPS인지, 아니면 그 프로필 `auth.cookie.secure=false`(http://localhost는 대부분 브라우저가 Secure 쿠키를 받지만 브라우저마다 다름, 시연 브라우저로 확인), (2) JWT 서명 키 환경 변수, (3) 초기화 뒤 열린 브라우저 새로고침(2-3). 프로필 설정 파일을 바꾸면 #58 paths에 `backend/src/main/resources/application-*.yml` 추가. 데모를 원격 서버에 올릴 계획이면 그 자체가 빠진 작업이니 사람에게 확인 |
| J-17 | #68 | 맞음(paths `plan/web/**` 이미 있음) |

## 제공자 쪽에서 꼭 지켜야 할 것
1. **calc_run 기록 메서드는 호출자 트랜잭션 안(`MANDATORY`), READ COMMITTED, 잠금 뒤 조회, readOnly 트랜잭션에서 부르지 않음, 리스너는 `@ApplicationModuleListener`.** 이유: 하나라도 어기면 advisory 잠금이 무력해지거나(2행) INSERT가 실패한다(2-1).
2. **그래프 시계열의 첫 점·점 수는 엔진(#26)이 정한다.** 이유: 납입 시점(TBD-04·05)이 미정이라 View가 붙이면 같은 달이 두 번 나올 수 있다(2-2).
3. **네이티브 `plan` 쓰기 뒤 영속성 컨텍스트 비우기.** 이유: 같은 트랜잭션의 스냅샷 조회가 옛 `revision`을 돌려줘 V-8을 깬다(2-5).
4. v1 1~6(한 트랜잭션, 조건부 네이티브 쓰기, 로그인 경로 리졸버, `minDisplay` 컨트롤러 한정, 한 스냅샷, plan `{}`)은 v2대로 유지.

## 양보 가능한 것
- advisory 잠금 키 형태(두 인자형 vs `bigint` 하나), 이중 확인 여부.
- 엔진이 늦을 때 View에서 첫 점을 붙이는 임시 처리(계약상 담당은 엔진).
- #30·#31 제목 접두어 변경.
- `calcRunId` 고정 문장 단서의 표현.
- X-1·X-2: 사람이 A/B 어느 쪽으로 정해도 구현 비용 차이는 몇 줄이다.
