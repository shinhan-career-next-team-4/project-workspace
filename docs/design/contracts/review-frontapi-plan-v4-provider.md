# 검토: 프론트 ↔ Spring 계획 API 계약 v4 초안 (#12-a 개정) — 제공자(A팀 Spring) 관점

> 검토자: contract-provider, 2026-11-20. 대상 `frontend-api-plan-v4-draft.md`. 다른 검토자 의견 없음(1차).
> 근거: moeun 작업 트리(브랜치 `feature/126-input-suggestion`, 읽기만) `backend/src/main/resources/config/rules.yml`, `plan/application/PlanService.java`, `plan/application/PlanInputValidator.java`, `plan/ConditionValidator.java`, `plan/application/PlanRules.java`, `plan/PlanInput.java`, `plan/PlanView.java`, `calc/web/PlanResultController.java`, `calc/application/ConditionResolver.java`, `backend/src/main/resources/db/schema.sql`, `db/tables.md`, `frontend/src/mocks/plan/**`, `docs/api/frontend-api.md`; project-workspace `docs/decisions.md`(D-043·D-045·D-083·D-085), `docs/design/contracts/frontend-api-plan.md`; moeun Issue #127 본문.

```
판정: 수정하면 수용
```

세 곳의 변경 자체는 모두 구현 가능하고 서버 비용은 **합쳐서 약 6줄 + 테스트**다. 단 (3)은 **이미 코드에 있어 할 일이 없고**(초안 설명이 사실과 다르다), 쟁점 2는 "R-9 유지"가 아니라 **R-9의 INPUT 경로를 "요청 값 그대로(null이면 NULL 저장)"로 바꾸는 쪽이 서버에 더 싸고 DB 문서·D-085와 모두 맞는다**. 이 한 곳만 고치면 수용한다.

## 1. 바뀌는 세 곳의 구현 가능성과 비용

### (1) 요청 표에 `savingsRatioPct` 추가 — **수용**

- `PlanInput`은 이미 `Map<String, JsonNode> fields`라서 **DTO 변경이 없다**(`plan/PlanInput.java:11-17`).
- 실제 작업 3곳, 각 1~3줄:

| 파일 | 줄 | 할 일 |
|---|---|---|
| `calc/web/PlanResultController.java` | 40(`NULLABLE_REQUIRED_KEYS`)·42-44(`NUMBER_FIELDS`) | `"savingsRatioPct"` 상수 추가. 키 없음 → 기존 `MissingPlanKeysException`으로 `422 REQUIRED`, 숫자 아님 → `400 MALFORMED_REQUEST`가 **그대로 적용된다**(초안의 "키 필수"가 추가 코드 없이 성립) |
| `plan/application/PlanInputValidator.java` | 40 근처 | `checkOptional(InputField.SAVINGS_RATIO_PCT, fields, errors)` 1줄 |
| `plan/application/PlanService.java` | 95-98 | 지금 `savingsRatioPct`는 "현재 버전 복사 또는 null" 고정이다. 요청 값을 먼저 보게 바꾼다(쟁점 2 결론을 따르면 **줄이 줄어든다**) |

- `InputField.SAVINGS_RATIO_PCT`는 이미 있다(`plan/InputField.java`). 모듈 경계 변화 없음: 컨트롤러는 calc.web, 검증·저장은 plan, 방향은 calc → plan 그대로다.
- 비중 산출을 화면이 하는 것(초안 20~21행)에 동의한다. 서버는 납입액을 받지 않으므로 **차액(CF-08 ②) 문구도 서버가 만들 수 없다**: `ResultDisplayBuilder.putAssumptions`(93-101행)가 내보내는 `assumptions.*`는 금리 기준월·S&P 기준일·세율 셋뿐이다. 즉 Issue #127 수용 기준 5번의 '가정 보기' 문구는 **프론트가 `copy/copy.ko.yml`에 키를 더해 붙이는 줄**이다. 초안 23행이 "화면 몫"이라 적은 것은 맞고, #127 본문에 "서버 `display`에 추가하지 않는다"를 한 줄 명시하자.

### (2) "요청에 없는 것"에서 제거 — **수용(문장 보강 필요)**

- 최종본 `frontend-api-plan.md:197` 및 moeun `docs/api/frontend-api.md:246`의 같은 문장을 함께 고쳐야 한다(moeun 문서 정정은 #127 paths에 이미 있음).
- 보강: `existingMonthlyContribution`은 지금도 서버가 **키를 읽지 않는다**(`PlanResultController.NUMBER_FIELDS`에 없음). 프론트가 실수로 보내도 조용히 무시되고 400이 아니다. 계약에 "보내면 무시한다"를 적어 두는 쪽이 낫다(지금은 "요청에 없다"만 있어 소비자가 오류를 기대할 수 있다).

### (3) `rules.yml`에 `SAVINGS_RATIO_PCT` 추가 — **수정(이미 구현돼 있다. 비용 0)**

- `rules.yml:13`에 `SAVINGS_RATIO_PCT: { required: false, min: 0, max: 100, unit: PCT, scale: 0 }`가 **이미 초안과 글자까지 같은 형태로 있다.**
- 초안 34행 "입력 저장 쪽 `fields:`에만 없던 것을 더한다"는 **구조를 잘못 본 것이다.** `rules.yml`의 `fields:`는 경로와 무관한 **전역 한 벌**이고(`PlanRules.fields`), 경로별 목록은 `change-paths:`뿐이다. 그리고 `INPUT_EDIT: { all-fields: true, max-fields: 0 }`(15행)라 입력 저장 경로는 애초에 모든 필드를 허용한다.
- 따라서 "ALTERNATIVE/COMPARE/CHAT과 값 범위·unit·scale이 정말 같은가"는 **같은 맵을 읽으므로 구조적으로 같다**(CP-02). `PlanRules.check`가 scale 0 → 소수면 `NOT_INTEGER`, 범위 밖이면 `OUT_OF_RANGE(min 0, max 100, unit PCT)`를 낸다. #127 수용 기준 7번은 그대로 성립하고, `PCT`인데 `scale 0`인 유일한 필드라는 점이 오류 문구에 영향을 줄 수 있으니 확인 한 줄: C12a-5-6 (f) `PCT` 문구 틀은 `unit.pct` "연 {값}%"다. **비중 0~100은 "연 100%"로 읽혀 틀린 안내가 된다.** → 소비자 몫 수정 요청: 422 `unit: PCT` + `field: savingsRatioPct`일 때는 `unit.pct`가 아닌 비중용 문구(예: `unit.ratioPct` "{값}%")를 쓰도록 C12a-5-6에 한 줄. 서버 변경은 없다.
- 초안 수정안: (3)을 "`rules.yml` 변경 없음(이미 있음). 계약 C12a-5-5 표에 `savingsRatioPct | 0 | 100 | PCT | 0` 행을 더해 문서를 코드와 맞춘다"로 바꾼다. #127 paths에서 `rules.yml`은 빼도 된다.

## 2. "바뀌지 않는다"는 주장 검증

| 초안 주장 | 코드 확인 | 판정 |
|---|---|---|
| 응답 C12a-5-3·5-6 | `PlanView`가 이미 `Integer savingsRatioPct`를 그대로 내보낸다(`plan/PlanView.java:21`, `PlanService.toView`). 목 파일도 이미 `plan.savingsRatioPct` 포함(`frontend/src/mocks/plan/put-plan.200.json:20`) | 안 바뀜 **수용** |
| 오류 코드 | 새 코드 없음. `REQUIRED`·`NOT_INTEGER`·`OUT_OF_RANGE` 재사용(1절) | 수용 |
| 검사 순서 C12a-5-2 | **표의 칸은 그대로지만 순서 4의 서술이 틀리게 된다**(아래) | **수정** |
| `revision` 충돌 | `PlanService.checkExpectedRevision`·`replaceCurrent` 경로에 비중이 끼어들 곳이 없다 | 수용 |
| DB 스키마 | `schema.sql:80` nullable `SMALLINT`, `:90` `ck_pv_ratio CHECK (… BETWEEN 0 AND 100)`. 마이그레이션 없음 | 수용 |
| 계산 엔진 | `ConditionResolver.resolveRatio`(81-86행)가 `plan.savingsRatioPct()`가 null이면 `CalcParamKey.DEFAULT_SAVINGS_RATIO_PCT`를 쓴다. 입력 경로가 값을 채워도 엔진은 손대지 않는다 | 수용 |
| `requiredMonthlySaving` null | FR-RES-08 범위 밖, 비중과 무관 | 수용 |

### 2-1. C12a-5-2 순서 4 "시작월·비중 복사" — **수정 필요**

- 코드는 두 값을 나란히 복사한다(`PlanService.save` 91-98행: `calcStartMonth`는 현재 버전 또는 이번 달, `savingsRatioPct`는 현재 버전 또는 null).
- v4 뒤에는 **시작월만 무조건 복사**이고 비중은 요청이 정한다. 수정안(표 순서 4 문장):
  `plan_version` INSERT(`source='INPUT'`, **시작월 복사(D-013·D-032), 비중은 요청 값 — `null`이면 C12a-5-1 규칙**) → …
- 같은 줄의 근거 주석(`PlanService.java:98` "요청에 없는 값은 현재 버전에서 복사(C12a-5-1)")도 함께 고쳐야 한다(#127 paths 안이라 문제 없음).

### 2-2. `ConditionValidator`가 INPUT_EDIT에서 PCT·scale 0을 어떻게 다루나 — **계약 문장이 코드와 다르다(정정 권고)**

- C12a-5-2 순서 2는 "`PlanInputValidator` + `ConditionValidator.validate(INPUT_EDIT, …)`"라고 적혀 있지만, **`PlanService.save`는 `inputValidator.validate(in)`만 부른다**(86행). `ConditionValidator`는 적용 경로(`apply`)에서만 쓰인다(`PlanService.apply` 119행, `validateChanges`).
- 즉 입력 저장의 비중 검증은 `PlanInputValidator.checkOptional` → `PlanRules.check` 한 길로만 간다. 범위·단위·scale은 같은 `fields:` 맵이라 동일하고, `INPUT_EDIT`의 `max-fields: 0`(제한 없음)도 애초에 적용되지 않는다(CP-07 미적용이라는 기존 결론과 결과는 같다).
- 수정안: 순서 2를 "`PlanInputValidator`(범위 수치는 `ConditionValidator`와 같은 `rules.yml fields`를 읽는다)"로 고친다. 이건 v4가 만든 문제가 아니라 v3부터 있던 어긋남이고, 비중이 들어오면 구현자가 `ConditionValidator`를 끌어와 `validate(INPUT_EDIT, …)`로 재구현할 유인이 생겨 지금 고치는 편이 싸다.
- 주의(함정): `ConditionValidator.validateChanges`는 `value.isNull()`이면 "바꾸지 않음"으로 보고 넘어가며, 바꿀 값이 하나도 없으면 `FieldError.required("conditionChanges")`를 낸다(40-48, 78-80행). 입력 저장에 이 메서드를 쓰면 **금리·비중을 모두 null로 보낸 정상 요청이 422가 된다.** 입력 저장 경로에서는 쓰지 않는다를 지켜야 한다.

## 3. 쟁점 2(제공자 몫): `savingsRatioPct`가 null일 때

먼저 사실 확인 — **Issue #127의 모순은 실재한다.** 본문 "무엇을 왜"의 "끄면 5:5 기본 비중이다"(= D-085 원문)와 수용 기준 2번 "null이면 현재 버전 값 복사"는, 직전 버전의 비중이 non-null인 재저장에서 서로 다른 결과를 낸다(토글을 켜서 83을 저장 → 끄고 재저장 → 수용 기준 2번대로면 83 유지, 본문대로면 50). 첫 저장에서만 두 문장이 일치한다.

| 안 | 서버 비용 | 결정과의 충돌 | 부작용 |
|---|---|---|---|
| (A) R-9 유지(끄면 직전 비중 유지) | 0줄. 단 `PlanService.save` 95-98행을 "요청 값 우선"으로만 고치면 됨 | **D-085 본문 "끄면 5:5 기본 비중"과 정면 충돌**. `schema.sql:80`("NULL = 규칙으로 산출(토글/기본값). 사용자가 직접 정한 비중만 저장")·`db/tables.md:51`과도 어긋남 | FR-INP-11 복원이 깨진다: 토글을 끈 뒤 입력 수정으로 돌아오면 `plan.savingsRatioPct`가 여전히 non-null이라 화면이 토글을 **켠 상태로 되살린다**(#127 수용 기준 9번). 사용자가 끈 사실을 왕복시킬 방법이 없다 |
| (B) 계약에 기본 비중 50을 넣고 화면이 50을 보낸다 | 0줄 | 기본 비중은 지금 **기준 데이터 파라미터** `DEFAULT_SAVINGS_RATIO_PCT`다(`ConditionResolver.java:85`). 50을 계약·프론트에 박으면 수치가 두 곳이 되어 CP-02("수치는 한 곳")와 NFR-INT-01 취지에 어긋난다 | 파라미터를 60:40으로 바꾸면 화면만 옛 값을 보낸다. 또 "사용자가 직접 정한 비중만 저장"(tables.md:51)이 깨져 `savings_ratio_pct`에 50이 쌓인다 |
| (C) 별도 "토글 꺼짐" 신호(예: `savingsEnabled`) | 요청 키 1개 + 컨트롤러·서비스 분기 ≈ 10줄 + 테스트 | 충돌 없음 | 두 필드가 같은 뜻을 중복 표현해 `savingsEnabled=false, savingsRatioPct=83` 같은 모순 조합의 검증·문서가 늘어난다. 3주·백엔드 1명에 불필요 |
| **(D, 권고) R-9의 INPUT 경로를 "요청 값 그대로, null이면 `NULL` 저장"으로 바꾼다** | **-3줄**(복사 로직 삭제). `savingsRatioPct = intField(in.fields(), SAVINGS_RATIO_PCT)` 한 줄 | D-085("끄면 5:5"), D-043(납입액 미저장), `schema.sql:80`, `tables.md:51`과 **모두 일치**. R-9의 "입력 화면 읽기 전용" 전제는 D-085가 이미 철회했다 | `NULL` → `ConditionResolver.resolveRatio`가 기본 파라미터(5:5)로 해석 → 계약·엔진·DB 변경 없이 "끄면 5:5"가 성립. FR-INP-11 복원도 `null ↔ 토글 꺼짐`으로 정확히 왕복한다. 유일한 의미 변화: 대화·대안으로 적용한 비중이 그 뒤 **토글을 끈 입력 저장으로 지워진다** — D-085 "나중 변경이 이긴다"에 부합하므로 결함이 아니다 |

- **결론: (D)를 권고하고 (A)에는 반대한다.** (D)는 서버 코드가 늘지 않고 줄며(가장 싸다), 기존 결정·DB 문서와 부딪히지 않는 유일한 안이다. 초안 쟁점 2는 "R-9를 그대로 둘까"가 아니라 "R-9의 INPUT 경로 문장을 (D)로 바꾼다"로 다시 쓰고, 그래도 사람 판단이 필요하면 Q로 올릴 때 선택지를 (A)/(D)로 좁히자((B)·(C)는 비용·일관성에서 밀린다).
- (D)를 택하면 함께 고칠 문장: 최종본 R-9 결과 칸(836행 근처), C12a-5-1 뜻 칸(초안 17행에서 "서버가 현재 버전 값을 복사하고" → "`NULL`로 저장하고 계산은 기본 비중(5:5)을 쓴다"), C12a-5-2 순서 4(2-1), `docs/api/frontend-api.md:246`, `db/tables.md:51`(현재 서술이 이미 (D)와 맞다 — 손댈 필요 없음), **#127 본문 수용 기준 2번**("null이면 `plan_version.savings_ratio_pct`가 `NULL`이고 결과는 기본 비중 5:5로 계산된다")과 1번(비중 83 저장) 유지.

## 4. 빠진 것

- **테스트(서버)**: `plan/PlanServiceTest`에 (a) 요청 83 → 저장 83, (b) 요청 null → `NULL` 저장((D) 채택 시) 또는 복사((A) 채택 시), (c) 101 → `OUT_OF_RANGE`, (d) 83.5 → `NOT_INTEGER`. `calc/PlanResultApiTest`에 (e) 키 누락 → `422 REQUIRED(savingsRatioPct)`, (f) 문자열 → `400`. **`docs/PlanResultDocsTest`의 요청 필드 스니펫**도 필드가 늘면 깨지므로 같이 고친다(REST Docs는 문서화 누락 시 실패). #127 paths에 `backend/src/test/java/com/moeun/backend/docs/**` 추가 권고.
- **목 파일**: 지금 `frontend/src/mocks/plan/put-plan.*.json`은 **응답만** 담고 있어(`put-plan.200.json`) 요청 필드 추가로 깨지지 않는다. 다만 소비자 검증용으로 `put-plan.422-ratio-range.json`(비중 101 → `OUT_OF_RANGE min 0 max 100 unit PCT`)과 비중이 들어간 200 예시 하나를 추가하길 권한다. `frontend/src/mocks/mocks.test.mjs`의 `plan` 키 목록(338행 근처)도 함께 확인.
- **문서 정정**: moeun `docs/api/frontend-api.md` 246행(요청에 없는 것)·요청 표·C12a-5-5 표, `docs/api/examples/` 안의 PUT 요청 예시(있으면), 계약 최종본 C12a-5-1·5-2·5-5·5-6·R-9.
- **선행 Issue**: #127은 `status:blocked`, 선행이 "계약 v4 합의"뿐이다. 코드 선행은 **#19(plan 저장)·#30(PUT /api/plan + PlanView)**이고 둘 다 이미 머지된 작업 트리에 있으므로 추가 선행은 필요 없다. 반면 B팀 #64·#66(대화·대안의 `SAVINGS_RATIO_PCT` 변경)은 같은 컬럼을 쓰지만 **코드가 겹치지 않는다**(`PlanService.apply` 경로). (D)를 택하면 "입력 저장이 적용된 비중을 지울 수 있다"는 사실만 #64·#66 본문 또는 #127에 한 줄 적어 두면 된다.
- **`status:blocked` 해제**: v4 합의 뒤 #127 라벨을 바꾸는 일이 후속 작업 목록에 없다.

## 제공자 쪽에서 꼭 지켜야 할 것

1. **(3)은 코드 변경이 아니라 문서 정정이다.** `rules.yml:13`·`:15`에 이미 있다. 계약이 "추가"라고 적혀 있으면 구현자가 중복 키를 넣거나 `INPUT_EDIT`에 `fields:` 목록을 새로 만들어 `all-fields: true`를 깨뜨린다.
2. **입력 저장 경로에서 `ConditionValidator.validateChanges`를 쓰지 않는다.** 모두 null인 정상 요청이 `conditionChanges REQUIRED`로 422가 된다(`ConditionValidator.java:40-42, 78-80`). 검증은 `PlanInputValidator` 한 길.
3. **null 처리는 (D)**: 요청 값을 그대로 저장하고 `null`이면 `NULL`. 기본 비중 수치(50)를 계약·프론트·plan 코드에 복제하지 않는다. 기본값의 출처는 `CalcParamKey.DEFAULT_SAVINGS_RATIO_PCT` 한 곳이다.
4. **C12a-5-2 순서 4의 "시작월·비중 복사"를 "시작월만 복사"로 고친다.** 안 고치면 구현자가 요청 값을 무시하는 지금 코드를 그대로 둔다.
5. **차액 문구(CF-08 ②)는 서버 `display`에 넣지 않는다.** 서버는 납입액을 받지 않아 차액을 모른다(D-043).

## 양보 가능한 것

- `savingsRatioPct`를 "키 필수"로 둘지 "키 생략 허용"으로 둘지: 둘 다 공짜다(키 필수가 기존 `NULLABLE_REQUIRED_KEYS` 재사용이라 조금 더 싸고 `savingsRateInputPct`와 결이 같아 권한다).
- 비중 422 문구 키 이름(`unit.ratioPct` 등) — 프론트 재량.
- 목 파일 추가 2개의 이름·개수.
- (A)로 결정되더라도 구현은 가능하다(비용 차이 3줄). 대신 #127 본문 "끄면 5:5"와 D-085 원문을 고치는 D-번호 기록이 필요하다는 점만 분명히 하자.
