# 프론트-Spring 계획 API 계약 v4 초안 (#12-a 개정) — `savingsRatioPct` 요청 필드

> 2026-11-20. 근거 결정 **D-085**(FR-INP-08을 Must로 되살림, CF-08 ②로 확정), **D-084**(입력 화면 추천 채움 — 이 문서와 무관하지만 같은 날 결정).
> 이 문서는 `/negotiate-contract 12`의 **기획(tech-architect) 초안** 자리다. 제공자(contract-provider)·소비자(contract-consumer) 검토를 거쳐 `frontend-api-plan.md`(최종본)에 반영한다.
> **최종본은 아직 고치지 않았다.** 아래 세 곳만 바뀐다.

## 왜

FR-INP-08(이미 저축 중인 납입액)을 되살리면 사용자가 입력 화면에서 적금 : ETF 비중을 정한다. 지금 계약은 `savingsRatioPct`를 "요청에 없는 것"으로 두고 서버가 현재 버전 값을 복사하므로(R-9), 화면이 정한 비중을 보낼 방법이 없다.

## 바뀌는 곳

### (1) C12a-5-1 요청 표에 한 줄 추가

| 필드 | JSON 타입 | 필수 | 뜻 |
|---|---|---|---|
| `savingsRatioPct` | integer \| null | 키 필수 | FR-INP-08. 적금 비중(%). `null` = 서버가 현재 버전 값을 복사하고, 첫 저장이면 `NULL`(= 5:5, R-9). 범위 0~100, 정수 [D-085] |

- 화면은 '지금 하고 있는 저축' 토글을 **켰을 때만** 값을 보낸다. 토글이 꺼져 있으면 `null`이다.
- 값은 화면이 적금·ETF 월 납입액으로 산출한다: `savingsRatioPct = 반올림(적금 납입액 ÷ (적금 납입액 + ETF 납입액) × 100)`. 두 납입액의 합이 0이면 `null`을 보낸다.
  - **주의**: 이 산출은 비중(비율)이지 금액이 아니므로 NFR-INT-01(프론트 금액 계산 금지)에 걸리지 않는다. 결과 금액은 모두 서버가 계산한다.
- 납입액 자체(`existingMonthlyContribution`)는 **여전히 보내지 않는다.** 비중을 정하는 데만 쓰고 저장하지 않는다(D-043). DB 컬럼은 지금처럼 항상 `NULL`로 둔다.
- 차액(납입액 합계 < 월 저축 가능 금액) 처리는 **서버가 하지 않는다.** 비중대로 배분하는 것이 곧 기존 계산이고, '가정 보기'에 적는 문구는 화면 몫이다(CF-08 ②, D-085).

### (2) "요청에 없는 것" 문장 수정

- 지금: `savingsRatioPct`(현재 버전 값 복사, 첫 저장이면 `NULL` = 5:5, R-9), `existingMonthlyContribution`(항상 `NULL`), …
- 바꿈: ~~`savingsRatioPct`~~를 빼고, `existingMonthlyContribution`(항상 `NULL`, D-043)·시작월·기준 시나리오만 남긴다. `savingsRatioPct`가 `null`일 때의 복사 규칙(R-9)은 (1)의 뜻 칸으로 옮긴다.

### (3) C12a-5-5 입력 규칙(`rules.yml`)에 필드 추가

`SAVINGS_RATIO_PCT: { required: false, min: 0, max: 100, unit: PCT, scale: 0 }`

- 변경 경로(ALTERNATIVE·COMPARE·CHAT)에는 이미 있는 키라 **값 범위는 같다.** 입력 저장(`INPUT_EDIT` 경로가 아닌 `PUT /api/plan`) 쪽 `fields:`에만 없던 것을 더한다.
- 범위 밖이면 다른 금액 필드와 같은 `OUT_OF_RANGE`(`min`·`max`·`unit` 포함)다.

## 바뀌지 않는 것 (확인용)

- 응답(C12a-5-3·5-6), 오류 코드, 검사 순서, `revision` 충돌 처리.
- `targetPeriodMonths`·`monthlySavingAmount`는 **계속 필수**다(D-045 유지). D-084의 추천 채움은 화면 안에서 끝나므로 계약이 바뀌지 않는다.
- DB 스키마. `plan_version.savings_ratio_pct`는 이미 nullable `SMALLINT`에 `0~100` CHECK가 있다.
- 계산 엔진. `requiredMonthlySaving`은 계속 항상 `null`이다(FR-RES-08 범위 밖).

## 검토가 필요한 쟁점

- **[소비자, B팀]** 대화·대안의 `SAVINGS_RATIO_PCT` 변경(#64·#66)과 입력 화면의 비중이 같은 필드를 쓴다. D-085는 "나중 변경이 이긴다"로 정했다. 비교 결과를 띄워 둔 사이 사용자가 입력 화면에서 비중을 바꾸면 기준 버전이 달라져 적용 때 `STALE_COMPARISON`(409)이 난다 — #33에서 이미 구현된 동작이라 추가 작업은 없다고 보는데, B팀 화면에서 이 409를 어떻게 안내할지 확인이 필요하다.
- **[제공자, A팀]** `savingsRatioPct`가 `null`일 때 현재 버전 값을 복사하는 기존 R-9 동작을 그대로 두는 것이 맞는지. 토글을 켰다 끄면 "5:5로 되돌린다"가 아니라 "직전 비중 유지"가 된다. 되돌리려면 화면이 `100`이 아닌 명시적 기본값을 보내야 하는데, 지금 계약에 '기본 비중' 값이 없다 → **Q로 올릴 후보**.
- **[소비자, 프론트]** 입력 수정으로 돌아왔을 때 토글의 초기 상태. `plan.savingsRatioPct`가 `null`이 아니면 켜진 상태로 복원하되, 납입액 두 칸은 저장하지 않으므로 **비워 둔 채 비중만 읽기 전용으로 보여 줄지** 정해야 한다(지금도 '현재 비중' 한 줄은 있다, C12a-5-6).
