# 재검토: 프론트 ↔ Spring 계획 API 계약 v4 (#12-a 개정) — 제공자(A팀 Spring) 관점

> 검토자: contract-provider, 2026-11-20. `/negotiate-contract 12` 4단계(마지막 1회). 대상 `frontend-api-plan-v4.md`.
> 함께 본 것: `review-frontapi-plan-v4-provider.md`(1차), `review-frontapi-plan-v4-consumer.md`(소비자 1차).
> 근거: moeun 작업 트리(읽기만) `plan/application/PlanService.java`, `plan/PlanView.java`, `calc/web/PlanResultResponse.java`, `calc/web/PlanResultController.java:40·42`, `calc/application/ConditionResolver.java:50-85`, `calc/application/PlanContextProviderImpl.java`, `calc/PlanContextView.java`, `calc/ConditionsView.java`, `calc/application/ResultDisplayBuilder.java:78-101`, `calc/application/CalcEngine.java:103·174`, `config/rules.yml:13·15-18`, `seed/calc-param.csv:6`, `db/schema.sql:80·90`, `db/tables.md:51`, `frontend/src/mocks/plan/**`, `frontend/src/mocks/README.md:11`.

```
판정: 수용
쟁점 Z-1: A (기획안 = 되보내기)
```

1차에서 꼭 지켜야 한다고 적은 5건(① `rules.yml` 문서 정정, ② `validateChanges` 금지, ③ null = `NULL` 저장, ④ 순서 4 "시작월만 복사", ⑤ 차액 문구 서버 `display` 제외)이 Z-3·Z-5·Z-1·Z-4·Z-8로 모두 들어왔다. 서버 변경은 3~6줄 그대로다.

## 1. 쟁점 Z-1: 되보내기(A안)를 수용한다

- **서버 추가 코드 0줄.** 서버는 요청의 `savingsRatioPct`를 그대로 저장하면 되고, 값이 "새로 산출한 것"인지 "응답에서 받아 돌려준 것"인지 구분할 필요도, 구분할 방법도 없다. 검증은 `PlanInputValidator.checkOptional` → `PlanRules.check`(범위 0~100, scale 0) 한 길로 끝난다.
- **"보낸 값이 현재 버전 값과 같은지" 확인은 필요 없다(요청 확인 답: 없다).** 그런 검사를 넣으면 ① 대화로 83이 된 계획에 사용자가 직접 83을 만들어 보낸 경우와 되보내기를 구분할 수 없어 뜻이 없고, ② 저장 경로가 "같으면 복사, 다르면 요청 값" 두 갈래로 늘어 Z-1이 지우려는 복사 로직이 되살아난다. `plan_version`은 값이 같아도 항상 새 행(P-3)이므로 같은 값 저장이 무해하다.
- **동시 수정은 `expectedRevision`이 이미 막는다.** `PlanService.save`는 `checkExpectedRevision`(178-189행: 계획이 있는데 `expectedRevision`이 `null`이거나 다르면 `PlanChangedException` → 409 `PLAN_CHANGED`) 뒤 `planRepository.replaceCurrent(memberId, newId, expectedRevision)` 조건부 UPDATE를 하고 0행이면 또 예외다. 다른 탭이 비중을 70으로 바꿔 적용했으면 `revision`이 올라가므로 옛 비중을 안은 저장은 **반드시 409로 거부된다.** 즉 "옛 값 되보내기가 최신 비중을 덮는" 창은 없다.
- **단 하나의 소비자 쪽 전제**(서버가 보장할 수 없어 적어 둔다): 프론트가 `revision`을 새로 받는 모든 경로(대화·대안 적용 응답, D-069 이후 재조회)에서 **비중도 같은 응답의 `plan.savingsRatioPct`로 갱신**해야 한다. `revision`만 갱신하고 비중은 화면에 남은 옛 값을 되보내면 409로도 걸리지 않고 조용히 되돌린다. 계약 (h) 표에 "되보낼 값은 **가장 최근 응답**의 `plan.savingsRatioPct`"라고 한 줄 못 박기를 권한다(서버 변경 없음).

## 2. 소비자 질문: 저장값 `50`과 `NULL`이 모든 소비처에서 같은가 — **계산·표시는 같다. 되보내기 값만 다르다**

| 소비처 | 읽는 값 | `50` vs `NULL` |
|---|---|---|
| 계산 엔진 | `ConditionResolver.resolveRatio`(80-84행): `null`이면 `CalcParamKey.DEFAULT_SAVINGS_RATIO_PCT`. 지금 seed 값은 `50`(`seed/calc-param.csv:6`) | **같다** |
| planContext(C1a-2) | `PlanContextView.of(…, resolved.input(), …)` → `ConditionsView.from(CalcInput)`. 즉 **해석된 int**만 들어간다. 원본 nullable 값은 planContext에 없다 | **같다** |
| 대안·비교·대화 재계산 | `resolveChanged`(61-62행)가 변경 없을 때 `resolveRatio`를 부른다 | **같다** |
| `display` | `ResultDisplayBuilder.putConditions`(89행) `formatter.formatRatio(input.savingsRatioPct())` — 역시 해석된 int. `"적금 50 : ETF 50"` 동일 | **같다** |
| `assumptions` | `Assumptions.savingsRatioPct`도 해석된 int | **같다** |
| `PlanView` / `PlanResultResponse.PlanValues` | **원본을 그대로 내보낸다**(`PlanView.java:19`, `PlanResultResponse.java:43-48`, "nullable 그대로") | **다르다**: `50` vs `null` |

- 결론: **결과·AI 컨텍스트·문구는 완전히 동일**하고, 차이는 "응답에 `50`이 보일지 `null`이 보일지" 한 곳뿐이다. 그 차이가 쓰이는 데는 Z-12 토글 복원 조건과 Z-8 가정 보기 표시 조건(둘 다 `!== null`)이다. 대화로 50이 적용되어 컬럼에 `50`이 들어간 계획은 **토글 ON으로 복원되고 가정 보기 문장이 뜬다** — 사용자가 실제로 비중을 정한 적이 있으니 맞는 동작이다.
- 그래서 소비자 1차안(끌 때 `50` 전송)은 **결과가 틀려지는 안은 아니다.** 반대 이유는 ① 기본 비중 수치가 프론트에 복제되어 `DEFAULT_SAVINGS_RATIO_PCT`를 60으로 바꾸면 화면만 옛 값을 보냄(CP-02), ② `savings_ratio_pct`에 "사용자가 정하지 않은 50"이 쌓여 `db/tables.md:51`("사용자가 직접 정한 비중만 저장")과 어긋나고 토글 OFF를 왕복할 수 없음 — 두 가지 그대로다. A안은 둘 다 없다.

## 3. v4 본문 점검 — 틀린 줄만

Z-3·Z-4·Z-5·Z-10, "바뀌지 않는 것" 절(132-134행), C12a-16 표(K-1·K-2 paths 포함)는 1차 검토와 코드에 **모두 맞다.** 특히 134행의 세 파일·줄 번호(`PlanResultController` 상수 2곳 40·42, `PlanInputValidator` 1줄, `PlanService:95-98` 복사 삭제)와 "줄이 줄어든다"는 그대로 성립한다(95-98행 확인). 고칠 줄은 아래 둘뿐이다.

1. **125행·126행 목 개수 "29 → 30개"** — 소비자 1차의 숫자를 그대로 옮겼는데, `frontend/src/mocks/README.md:11`은 "로그인·계획 목의 합계는 **30개**. 계약 최종본 본문은 29개라고 적었지만 같은 문서의 표는 30행이고 표를 기준으로 했다"고 적혀 있다. 즉 코드 기준 현재가 30이므로 추가 뒤는 **31개**다. 수정안: "계약 본문의 개수 표기와 README를 함께 맞춘다(표 기준 30 → 31)". 안 고치면 `mocks.test.mjs`의 개수 단정이 깨지거나 문서가 또 어긋난다.
2. **132행 "`PlanInput`이 `Map<String, JsonNode>`라 요청 DTO 변경 없음"은 맞지만, 같은 줄에 묶인 "오류 코드 변화 없음"에 한 가지 전제가 빠졌다** — 키 누락 `422 REQUIRED`는 `PlanResultController.NULLABLE_REQUIRED_KEYS`(40행, 현재 `expectedRevision`·`savingsRateInputPct` 2개)**에 키를 넣었을 때만** 성립한다. K-1에 "상수 2곳"으로 적혀 있어 구현에는 문제가 없으나, "바뀌지 않는 것" 절만 읽으면 "아무것도 안 해도 REQUIRED가 난다"로 읽힌다. 괄호 한 줄 보강을 권한다.

그 밖에 Z-13(0·100 허용)은 `ck_pv_ratio CHECK (… BETWEEN 0 AND 100)`(`schema.sql:90`)·`rules.yml:13`과 일치하고, Z-6 산출식·Z-12·Z-16·Z-17은 서버 영향이 없다.

## 4. 소비자 요구 중 서버에 영향 있는 것 — 이견 없음

- **가정 보기 고정 문장(`assumptions.ratioAppliedToAll`, 금액 없음)**: 찬성. `ResultDisplayBuilder.putAssumptions`(93-101행)는 금리 기준월·S&P 기준일·세율 셋만 내보내고 서버는 납입액을 받지 않아 차액을 만들 수 없다(D-043). 표시 조건 `plan.savingsRatioPct !== null`은 응답에 그 값이 원본으로 실려 있어(2절) 프론트가 바로 판단할 수 있다.
- **`unit.ratioPct`**: 찬성. 서버 변경 0. `InternalCalcExceptionHandler:125`가 `savingsRatioPct`일 때 `formatRatio`를 쓰는 것과 결이 같다(422 본문의 `min`·`max`·`unit`은 그대로 `PCT`).
- **납입액 두 칸 `REQUIRED` 금지**: 찬성. 두 칸은 서버가 아예 모르는 필드(`rules.yml fields`에 없음)라 서버 422가 날 일이 없고, 합 0을 "칸 비움"으로 보는 Z-14도 서버에 영향이 없다.
- **목 1개 추가(요청 오류 목 없음)**: 찬성. 1차에서 권했던 `put-plan.422-ratio-range.json`은 "양보 가능"으로 적었고 철회한다. 요청 본문 검증은 목으로 할 수 없으므로 단위 테스트(Z-15)가 맞다. 서버 쪽 422는 K-2의 서버 테스트가 덮는다.

## 제공자 쪽에서 꼭 지켜야 할 것

1. **Z-1은 A안으로 닫고, 서버에 "되보낸 값인지" 확인 로직을 넣지 않는다.** 요청 값을 그대로 저장하는 한 줄이 전부다. 되보내기를 검증하려는 시도는 복사 로직을 되살려 Z-1의 이득(-3줄)을 없앤다.
2. **동시 수정 보호는 `expectedRevision` 하나로 끝낸다**(`checkExpectedRevision` + `replaceCurrent` 조건부 UPDATE). 비중 전용 충돌 코드·새 오류 코드를 만들지 않는다.
3. **기본 비중 수치 `50`을 계약·프론트·plan 코드에 쓰지 않는다.** 출처는 `DEFAULT_SAVINGS_RATIO_PCT` 한 곳이다(`seed/calc-param.csv:6`). A안이면 프론트에 상수가 필요 없다.
4. **1차의 5건(Z-3·Z-4·Z-5·Z-8·Z-1)은 문장 그대로 최종본에 반영한다.** 특히 `rules.yml`을 "손대지 않음"으로, `ConditionValidator.validateChanges`를 "쓰지 않음"으로 남겨야 한다.
5. **목 개수는 README(30) 기준으로 31로 적는다**(3절 1번).

## 양보 가능한 것

- 목 파일 이름·개수 표기 방식(README 기준으로 맞추기만 하면 된다).
- `unit.ratioPct` 등 문구 키 이름과 문장 — 프론트 재량.
- (h) 표의 "가장 최근 응답" 문구 위치(계약 본문이든 #127 수용 기준이든).
- B안·C안으로 결정되더라도 구현은 가능하다. 다만 B안은 `tables.md:51` 수정과 CP-02 예외 기록이, C안은 "토글 ON + 칸 비움 저장이 5:5로 되돌아간다"는 사용자 설명이 추가로 필요하다.
