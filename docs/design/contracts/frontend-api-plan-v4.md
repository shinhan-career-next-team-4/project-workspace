# 프론트-Spring 계획 API 계약 v4 (#12-a 개정) — `savingsRatioPct` 요청 필드

> 2026-11-20. `/negotiate-contract 12`의 **3단계(검토 반영)**. 입력: `frontend-api-plan-v4-draft.md`(기획 초안), `review-frontapi-plan-v4-provider.md`(A팀), `review-frontapi-plan-v4-consumer.md`(프론트·B팀). 두 검토 모두 **"수정하면 수용"**.
> 근거 결정 **D-085**(FR-INP-08을 Must로 되살림, CF-08 ②), **D-043**(납입액 미저장).
> v1~v3처럼 자기완결 본문을 다시 쓰지 않는다. **v4는 최종본 `frontend-api-plan.md`에 대한 개정 묶음(델타)**이다. 바뀌는 절만 적는다. 그 밖은 v3 최종본이 그대로 유효하다.
> 표기: **[v4]** 새로 바뀌는 줄, **⟵ 쟁점 Z-n** 사람이 정할 것(4단계 재검토 뒤에도 남으면 Q로 올린다).

---

## Z. 초안 → v4 변경 표

| # | 항목 | 초안 | v4 | 근거 | 분류 |
|---|---|---|---|---|---|
| Z-1 | C12a-5-1 요청 표 | `savingsRatioPct` 추가, `null` = 서버가 현재 버전 값 복사 | **`null` = 사용자가 정한 비중이 없음 → `NULL` 저장, 계산은 기본 비중(5:5)** | 제공자 3절 (D) 권고. 초안 안(= R-9 유지)은 D-085 "끄면 5:5"·`schema.sql:80`·`db/tables.md:51`과 충돌 | 합의(Z-2와 묶음) |
| Z-2 | C12a-5-6 토글 → 요청 값 | 켰을 때만 값, 끄면 `null` | **토글 OFF면 `null`**, **ON이면 `산출값 ?? 가장 최근 응답의 plan.savingsRatioPct ?? null`**(칸을 채우면 산출값, 복원 ON·칸 비움이면 받은 값을 가공 없이 되보냄) | 제공자 (D) + 소비자 3·4절을 합친 기획안. 소비자의 "OFF에 `50`을 보낸다"는 기본 비중 수치를 프론트에 복제해 CP-02에 걸린다(제공자 (B) 반대) → 되보내기로 대체 | **합의**(재검토에서 양쪽 A 수용) |
| Z-3 | (3) `rules.yml` 추가 | `SAVINGS_RATIO_PCT` 필드 추가 | **코드 변경 없음**(`rules.yml:13`에 이미 있고 `fields:`는 경로 무관 전역 한 벌, `INPUT_EDIT: {all-fields: true}`). 계약 C12a-5-5 표에 행을 더해 **문서를 코드와 맞춘다**. #127 paths에서 `rules.yml` 제거 | 제공자 1-(3) | 합의 |
| Z-4 | C12a-5-2 순서 4 | "시작월·비중 복사"(v3 문장) | **"시작월만 복사(D-013·D-032), 비중은 요청 값(`null`이면 `NULL`)"** | 제공자 2-1. 안 고치면 구현자가 요청 값을 무시하는 현재 코드를 그대로 둠 | 합의 |
| Z-5 | C12a-5-2 순서 2 | `PlanInputValidator` + `ConditionValidator.validate(INPUT_EDIT, …)` | **`PlanInputValidator` 한 길**(범위 수치는 `ConditionValidator`와 같은 `rules.yml fields`를 읽는다). 입력 저장 경로에서 `ConditionValidator.validateChanges`를 **쓰지 않는다** | 제공자 2-2. 현재 코드와 v3 문장이 어긋나 있었고, `validateChanges`를 쓰면 모두 `null`인 정상 요청이 422 | 합의 |
| Z-6 | 비중 산출식 | "반올림(적금 ÷ 합 × 100)" | **정수 연산 + HALF_UP 고정식과 단위 테스트 표**(아래 C12a-5-6). 부동소수 `Math.round(a/s*100)` 금지 | 소비자 1절. "반올림"만 두면 12.5·87.5류에서 프론트와 테스트가 갈림 | 합의 |
| Z-7 | NFR-INT-01 | "비율이라 걸리지 않는다"(초안 자체 해석) | **D-085에 D-084와 같은 모양의 예외 한 줄을 기록**(→ D-087). 산출은 공용 폴더 util 한 함수에서만, 금액·차액 계산은 하지 않는다 | 소비자 1절. NFR-INT-01은 "금융 계산"이고 금액으로 한정하지 않음(`srs.md:78`) | 합의(결정 기록 필요) |
| Z-8 | CF-08 ② 차액 문구 | "차액 처리는 화면 몫" | **금액 없는 고정 문장** `assumptions.ratioAppliedToAll`. 표시 조건은 `plan.savingsRatioPct !== null`. 서버 `display`에 넣지 않는다 | 소비자 1절 + 제공자 1-(1). 금액 문구는 화면이 빼기를 해야 하고(NFR-INT-01), 납입액은 저장하지 않아 새로고침 뒤에는 합계를 알 수 없다(D-043) | 합의(D-085 ② 구체화 → D-088) |
| Z-9 | 422 `PCT` 문구 | v3 (f) `unit.pct` "연 {값}%" | **`field: savingsRatioPct`일 때는 `unit.ratioPct` "{값}%"** | 제공자 1-(3). 비중 100이 "연 100%"로 잘못 읽힘. 서버 변경 없음 | 합의 |
| Z-10 | `existingMonthlyContribution` | "요청에 없다" | + **"보내도 서버가 읽지 않고 무시한다"**(400 아님) | 제공자 1-(2) | 합의 |
| Z-11 | `STALE_COMPARISON` 안내 | B팀 화면에서 어떻게 안내할지 확인 필요 | **추가 작업 없음**. 계약·#33·#53 AC에 이미 있고 문구 키 `toast.applyStaleComparison`도 있다(`copy.ko.yml:91`). 다만 **문장을 교체**해 원인 둘(계획 변경 / 최신 비교 아님)을 함께 덮는다. 같은 탭에서는 D-069가 적용 버튼을 먼저 끄므로 이 409는 **다른 탭 저장**에서만 남고, 입력 저장은 비중이 같아도 항상 새 버전이라 **비중 전용 처리는 필요 없다** | 소비자 2절(초안 주장 수용 + 보강) | 합의 |
| Z-12 | 입력 수정 복원(FR-INP-11) | 토글 초기 상태 미정 | **(A)안**: `plan.savingsRatioPct !== null`이면 토글 ON(값이 `50`이어도 ON), 납입액 칸은 복원하지 않고 비운다(D-043), 현재 비중 읽기 전용 줄 유지. **칸이 비어 있는 것은 오류가 아니다**(`input.ratioKept` 도움말) | 소비자 3절. (B)는 #127 AC 9번과 불일치·거짓 표시, (C)는 금액 역산이라 NFR-INT-01·D-043 위반 | 합의 |
| Z-13 | 0·100 극단값 | — | 닫힌 구간 0~100 그대로. **양쪽을 다 입력했는데 반올림으로 0·100이 되는 경우가 있고 막지 않는다**(1~99로 조이면 서버 범위와 다른 프론트 하드코딩) | 소비자 1절 | 합의 |
| Z-14 | 납입액 두 칸 검증 | — | `rules.yml`에 없는 필드 → 서버 422 없음. 프론트는 형식(C12a-5-6 (d))·음수 불가만. **빈 칸은 0으로 보고, 합이 0이면 Z-2의 "칸 비움"으로 처리한다.** `REQUIRED`를 걸지 않는다 | 소비자 1·3절 | 합의 |
| Z-15 | 목 | — | `plan/get-plan.200-ratio83.json` **1개 추가 → 30 → 31개**. 요청 오류 전용 목은 만들지 않는다(화면이 항상 0~100을 보냄). 요청 본문은 목이 아니라 **단위 테스트**로 검증 | 소비자 5절. 제공자가 권한 `put-plan.422-ratio-range.json`은 제공자 "양보 가능"이라 넣지 않음 | 합의 |
| Z-16 | 문구표 | — | C12a-7-1에 **7개 반영**: `input.existingSavingToggle`, `input.existingSavingBank`, `input.existingSavingEtf`, `input.existingSavingHelp`, `input.ratioKept`, `assumptions.ratioAppliedToAll`, `unit.ratioPct`. `toast.applyStaleComparison` 문장 교체. 모두 '추천' 표현 금지(D-083, CP-06) | 소비자 5절 + Z-9 | 합의 |
| Z-17 | 요청 본문 키 | — | `savingsRatioPct`는 **키 필수**이므로 #48 요청 본문, 목 요청 예시, 계약 C12a-5-1 예시(342행)에 `"savingsRatioPct": null`을 더한다. 없으면 `422 REQUIRED` | 양쪽 | 합의 |
| Z-18 | 테스트·문서 | 초안에 없음 | 아래 C12a-16 후속 작업 표 | 제공자 4절 + 소비자 5절 | 합의 |

- **합의 18건**(Z-1~Z-18). 4단계 재검토에서 **쟁점 Z-1은 양쪽이 A(되보내기)를 수용**해 닫혔다(`review-frontapi-plan-v4-provider-2.md`: 판정 수용 / `-consumer-2.md`: 수정하면 수용, 수정 3건은 아래에 반영). **사람이 정할 쟁점은 남지 않았다.**
- 초안의 쟁점 3개 처리: ① `STALE_COMPARISON` → Z-11 **해소**(추가 작업 없음 + 문장 교체). ② 기본 비중 구멍 → Z-1·Z-2 **해소안 제시**(쟁점 Z-1로 재검토). ③ 토글 복원 → Z-12 **해소**((A)안 양쪽 수용).

---

## 바뀌는 절 (최종본에 그대로 반영할 문장)

### C12a-5-1. 요청 표에 한 줄 추가 [v4]

| 필드 | JSON 타입 | 필수 | 뜻 |
|---|---|---|---|
| `savingsRatioPct` | integer \| null | 키 필수 | FR-INP-08. 적금 비중(%). 범위 0~100, 정수. **`null` = 사용자가 정한 비중이 없음** → `plan_version.savings_ratio_pct`에 `NULL`을 저장하고, 계산은 기준 데이터의 기본 비중(`DEFAULT_SAVINGS_RATIO_PCT` = 5:5)을 쓴다 [D-085, Z-1] |

- **현재 버전 값을 복사하지 않는다**(v3의 R-9 INPUT 경로 철회). 왜: D-085가 "토글을 끄면 5:5"로 정했고, `schema.sql:80`·`db/tables.md:51`("NULL = 규칙으로 산출, 사용자가 직접 정한 비중만 저장")도 그 뜻이다. 복사해 두면 토글을 끈 사실을 왕복시킬 수 없다.
- 기본 비중 수치(50)는 **기준 데이터 파라미터 한 곳**에만 있다. 계약·프론트·plan 코드에 복제하지 않는다(CP-02).
- **요청에 없는 것** [v4 수정]: `existingMonthlyContribution`(항상 `NULL`, D-043 — **보내도 서버가 읽지 않고 그냥 무시한다. 400이 아니다**), 시작월(첫 저장이면 요청일이 속한 달 D-032, 아니면 현재 버전 값 복사 D-013), 기준 시나리오(첫 저장이면 `AVG`). `savingsRatioPct`는 이 목록에서 **빠진다**.
- 본문 예시(342행 근처)와 모든 요청 예시에 `"savingsRatioPct": null`을 넣는다(키 필수, Z-17).

### C12a-5-2. 검사 순서 [v4]

- **순서 2 문장 정정**: "`PlanInputValidator`가 검증한다(범위 수치는 `ConditionValidator`와 **같은 `rules.yml › fields`를 읽는다**). `REQUIRED`·`OUT_OF_RANGE`·`NOT_INTEGER`·`TOO_MANY_DECIMALS`·CUSTOM 이름, 걸린 필드 모두. `INPUT_EDIT`에는 CP-07 개수 제한을 걸지 않는다."
  - **입력 저장 경로에서 `ConditionValidator.validateChanges`를 쓰지 않는다.** 그 메서드는 `null`을 "바꾸지 않음"으로 보고 바꿀 값이 하나도 없으면 `conditionChanges REQUIRED`를 내므로, 금리·비중을 모두 `null`로 보낸 **정상 요청이 422가 된다**(Z-5).
- **순서 4 문장 정정**: "`plan_version` INSERT(`source='INPUT'`, **시작월 복사(D-013·D-032), 비중은 요청 값 — `null`이면 `NULL`**) → 첫 저장: …"(나머지 그대로, Z-4).

### C12a-5-5. 범위 수치 표에 한 줄 추가 [v4]

| 필드 | min | max | unit | scale | 출처 |
|---|---|---|---|---|---|
| `savingsRatioPct` | 0 | 100 | PCT | 0 | `rules.yml:13` **이미 있음**(코드 변경 없음). 문서를 코드와 맞춘 것 [Z-3] |

- `rules.yml › fields:`는 **경로와 무관한 전역 한 벌**이고 경로별 목록은 `change-paths:`뿐이다. `INPUT_EDIT: { all-fields: true, max-fields: 0 }`이라 입력 저장 경로는 처음부터 모든 필드를 허용한다. **`INPUT_EDIT`에 `fields:` 목록을 새로 만들지 않는다**(`all-fields: true`가 깨진다).
- 같은 키는 경로와 무관하게 같은 범위(CP-02) — 같은 맵을 읽으므로 구조적으로 보장된다.

### C12a-5-6. 프론트 규칙 [v4]

**(g) 비중 산출** — 공용 폴더 util 한 함수(W-14 폴더, #48이 만들고 #51이 쓴다).

- 두 납입액을 (d)로 원 정수 `a`(적금)·`b`(ETF)로 바꾼 뒤 `s = a + b`.
- `s === 0`이면 **칸 비움**으로 본다(Z-2·Z-14).
- 그 밖에는 **정수 연산 HALF_UP**: `r = floor((200 × a + s) / (2 × s))`. 부동소수 `Math.round(a / s * 100)`은 **쓰지 않는다**. 값이 커지면 `BigInt`를 쓴다.
- 단위 테스트 표(#48): `(100,20)→83`, `(1,1)→50`, `(1,2)→33`, `(2,1)→67`, `(1,7)→13`(12.5 → HALF_UP), `(7,1)→88`(87.5), `(0,5)→0`, `(5,0)→100`, `(0,0)→칸 비움`.
- 양쪽을 다 입력했는데 반올림으로 `0`·`100`이 되는 경우(적금 1원 : ETF 1,000만원)는 **막지 않는다**(Z-13). 결과 화면 조건 바가 실제 저장값을 보여 준다.
- **금액·차액 계산은 이 util에서도 하지 않는다.** 비중(비율) 하나만 만든다(Z-7, D-087).

**(h) 토글 → 요청 값** ⟵ 쟁점 Z-1

| 화면 상태 | 요청 `savingsRatioPct` |
|---|---|
| 토글 OFF (첫 입력이거나 사용자가 끔) | `null` → `NULL` 저장 → 계산은 기본 비중 5:5 |
| 토글 ON + 납입액 칸을 채움 | (g)로 산출한 값 |
| 토글 ON(복원) + 납입액 칸 비움 | **가장 최근 응답의 `plan.savingsRatioPct ?? null`을 그대로 되보낸다**(= 현재 비중 유지). 프론트는 숫자를 만들지 않고 받은 정수를 가공 없이 돌려줄 뿐이다. 되보낼 값이 없으면(첫 입력, OFF → ON으로 켰는데 칸을 비움) `null`. **키는 항상 채운다** — `undefined`로 두면 키가 사라져 `422 REQUIRED`가 난다 |

- 왜 되보내기인가: 비중을 바꾸지 않는 일반 수정(목표 금액만 고침)에서 **대화·대안으로 적용한 비중이 지워지지 않게** 하면서, 동시에 `null`의 뜻을 "사용자가 정한 비중 없음 = 5:5"로 한 가지로 유지한다. 프론트에 기본 비중 `50`을 복제하지 않는다(CP-02).
- 왜 `50`을 보내지 않는가: 소비자안 ③("복원 ON을 직접 끄면 `50`")은 기본 비중 수치를 프론트에 복제해 기준 데이터를 바꾸면 화면만 옛 값을 보낸다(제공자 (B) 반대). 되보내기면 OFF가 언제나 `null`이라 분기가 하나 줄고 "끄면 5:5"가 참이다.
- **토글을 끄면 기본 비중으로 돌아간다**는 사실은 토글 아래 `input.existingSavingHelp`에 **상시 노출**한다(별도 `input.ratioResetNote`는 만들지 않는다 — 소비자 재검토 4에서 철회). 문구에 **"5:5" 수치를 적지 않는다**(기본 비중은 기준 데이터 한 곳에만, CP-02).
- **값의 출처는 "가장 최근 응답"이다**: `revision`을 새로 받는 모든 경로(P-3·P-4·P-5 응답)에서 비중도 같은 응답 값으로 갱신해야 한다. 서버는 이것을 막을 수 없다(제공자 재검토 1). 되보낼 값은 **저장을 누르는 시점의 공유 store(#13)**에서 읽는다.
- **`loadPlan()`이 확정되기 전에는 저장 버튼을 비활성**한다. 확정 전에 저장하면 "복원 ON·칸 비움"과 "OFF"를 구분할 수 없어 `null`이 가고 서버에 있던 비중이 지워진다(소비자 재검토 1 — 유일하게 남은 구멍).
- **토글이 OFF면 납입액 두 칸을 비활성**한다.
- 서버는 되보낸 값을 **특별히 다루지 않는다**(현재 버전 값과 같은지 확인하지 않는다 — 확인을 넣으면 버린 복사 로직이 되살아난다). 다른 탭이 먼저 비중을 바꾼 뒤 옛 값을 되보내는 경우는 `expectedRevision` 검사(`PlanService.checkExpectedRevision`)와 조건부 UPDATE가 **409로 이미 막는다**(제공자 재검토 1).
- 단위 테스트(#48, 요청 본문 기대값) **6경우**: ① OFF → `null` / ② ON·칸 채움 → 산출값 / ③ 복원 ON·칸 비움 → 응답 값 그대로(무가공) / ④ 첫 입력 OFF → `null` / ⑤ OFF → ON으로 켜고 칸 채움 → 산출값(예: 83) / ⑥ 모든 경우에 **키가 본문에 있다**(`undefined` 아님).

**(f) 422 범위 문구 보강** [v4]: `unit: PCT`이면서 `field: savingsRatioPct`일 때는 `unit.pct`("연 {값}%")가 아니라 **`unit.ratioPct`("{값}%")**를 쓴다. 왜: 비중 100이 "연 100%"로 잘못 읽힌다(Z-9).

### C12a-5-6 / C12a-7 입력 수정 복원(FR-INP-11) [v4]

- 토글 초기 상태: **`plan.savingsRatioPct !== null`이면 ON**(값이 `50`이어도 ON. 응답으로 `null`과 구분된다), `null`이면 OFF.
- **납입액 두 칸은 복원하지 않는다**(저장하지 않으므로, D-043). 비어 있는 것은 오류가 아니고 도움말 `input.ratioKept`("납입액을 비워 두면 현재 비중을 그대로 써요")를 둔다. 두 칸에 `REQUIRED`를 걸지 않는다.
- 현재 비중 읽기 전용 줄(`input.currentRatioLabel` + `display["conditions.savingsRatioPct"]`)은 v3 그대로.

### C12a-7 결과 화면 '가정 보기' [v4]

- CF-08 ② 차액 안내는 **금액 없는 고정 문장** `assumptions.ratioAppliedToAll`("월 저축 가능 금액 전체를 현재 비중대로 나눠 계산했어요" + `display["conditions.savingsRatioPct"]`)이다.
- 표시 조건: **`plan.savingsRatioPct !== null`**("납입액을 입력했는지"가 아니다 — 납입액은 저장되지 않아 새로고침·재로그인 뒤에는 알 수 없다).
- **서버 `display`·`assumptions`에 필드를 더하지 않는다.** 서버는 납입액을 받지 않아 차액을 모른다(제공자 1-(1), D-043).

### C12a-7-1 문구표 키 추가 [v4]

| 키 | 쓰는 곳 |
|---|---|
| `input.existingSavingToggle` | 토글 라벨 |
| `input.existingSavingBank` / `input.existingSavingEtf` | 납입액 두 칸 라벨 |
| `input.existingSavingHelp` | 토글 아래 상시 노출. "비중을 정하는 데만 쓰고 저장하지 않아요" + 끄면 기본 비중으로 돌아간다는 안내(수치 없이) |
| `input.ratioKept` | 복원 ON·칸 비었을 때 도움말 |
| `assumptions.ratioAppliedToAll` | 가정 보기 고정 문장 |
| `unit.ratioPct` | 비중 422 문구 틀 "{값}%" |
| (문장 교체) `toast.applyStaleComparison` | "계획이 바뀌었거나 더 최근 비교가 있어요. 최신 비교를 다시 받아 적용해 주세요" — 원인 둘을 함께 덮는다(Z-11) |

- 모두 '추천' 표현을 쓰지 않는다(D-083, CP-06).

### R-9 [v4]

- v3: "합의: 비중 복사 + 입력 화면 읽기 전용".
- v4: **"입력 저장은 요청의 `savingsRatioPct`를 그대로 저장한다(`null` → `NULL` → 계산은 기본 비중). 복사하지 않는다. 입력 화면은 비중을 정할 수 있다(D-085로 '읽기 전용' 전제 철회)."**

### C12a-12 목 [v4]

- `plan/get-plan.200-ratio83.json` 추가(`plan.savingsRatioPct: 83`, `display["conditions.savingsRatioPct"]: "적금 83 : ETF 17"`, 나머지는 기본 목 복사) → **30 → 31개**. README 개수와 `mocks.test.mjs` 목록도 함께. (계약 본문의 "29개"는 `put-plan.422-custom-name`이 빠진 수라 이미 어긋나 있었다. 현재 파일은 auth 6 + plan 24 = 30개이고 `frontend/src/mocks/README.md:11`도 30이라 적고 있다 → **31로 맞춘다**.)
- 왜: 지금 목은 `null`·`50`·`100`만 있어 "ON 복원 + 칸 비움 + 되보내기" 시험이 `50`으로는 `null`과 구분되지 않는다.

---

## 바뀌지 않는 것 (코드로 확인)

제공자 2절 표 기준. 응답(C12a-5-3·5-6)·오류 코드(새 코드 없음. 단 `PlanResultController.NULLABLE_REQUIRED_KEYS`·`NUMBER_FIELDS`에 키를 더해야 기존 `REQUIRED`·`MALFORMED_REQUEST`가 적용된다)·`revision` 충돌·DB 스키마(`schema.sql:80`·`ck_pv_ratio`, 마이그레이션 없음)·계산 엔진(`ConditionResolver.resolveRatio`가 `NULL`이면 기본 파라미터)·`requiredMonthlySaving` 항상 `null`. `PlanView`는 이미 `Integer savingsRatioPct`를 내보내고 목에도 들어 있다. `PlanInput`이 `Map<String, JsonNode>`라 **요청 DTO 변경 없음**.

서버 작업은 **약 3~6줄**: `calc/web/PlanResultController`(`NULLABLE_REQUIRED_KEYS`·`NUMBER_FIELDS`에 키 추가), `plan/application/PlanInputValidator`(`checkOptional` 1줄), `plan/application/PlanService:95-98`(복사 로직 삭제 → 요청 값 그대로, **줄이 줄어든다**).

---

## 쟁점 Z-1 (재검토에서 닫힘 — 사람이 정할 것 없음)

### 쟁점 Z-1: 토글 OFF와 "칸 비움"을 요청 값으로 어떻게 표현할까

- **제공자**: `null`은 `NULL` 저장(= 5:5). 복사(R-9)는 D-085·DB 문서와 충돌하니 버린다. 기본 비중 `50`을 프론트에 복제하는 안은 CP-02 위반이라 반대.
- **소비자**: `null` = 비중 유지(복사)를 남기고, 복원 ON을 직접 끌 때만 `50`을 보낸다. 안 그러면 토글을 안 건드린 일반 수정이 대화로 정한 비중을 지운다.
- **기획안(v4 본문)**: 둘을 합쳐 **OFF는 항상 `null`(= 5:5), 복원 ON·칸 비움은 받은 값을 되보낸다.** `50` 복제도 없고, 일반 수정이 비중을 지우지도 않는다.
- 선택지: **A) 기획안(되보내기)** / B) 소비자안(`null`=복사 + 끌 때 `50`) / C) 제공자안 그대로(OFF·칸 비움 모두 `null` → 토글을 켠 채 칸을 비우고 저장하면 5:5로 돌아간다).
- 추천: **A**. 서버가 가장 싸고(복사 로직 삭제), `null`의 뜻이 하나이며, D-085 "끄면 5:5"가 참이 되고, 대화 비중이 조용히 지워지지 않는다.
- **결과: 양쪽이 A를 수용했다**(제공자 재검토 "수용, 서버 추가 코드 0줄", 소비자 재검토 "A 수용, ③안 철회"). Q로 올리지 않는다. 함께 확인된 사실: `savings_ratio_pct`의 `50`과 `NULL`은 **계산 엔진·planContext·대안/비교/대화 재계산·`display`·`assumptions`에서 모두 같게 취급된다**(전부 `ConditionResolver.resolveRatio`가 해석한 int만 쓴다). 차이는 `PlanView`/`PlanResultResponse`가 원본을 그대로 내보내는 것 하나뿐이고, 그 차이는 Z-12 토글 복원과 Z-8 표시 조건에만 쓰인다.

---

## C12a-16. 후속 작업 (D-058: 기존 Issue 본문에 반영) [v4]

| # | 작업 | 팀 | Issue |
|---|---|---|---|
| K-1 | 요청 필드 수용(컨트롤러 상수 2곳·`checkOptional`·`PlanService` 복사 삭제), 순서 2·4 문장대로 구현, `ConditionValidator.validateChanges` 사용 금지, `rules.yml` **손대지 않음** | A | **#127** |
| K-2 | 서버 테스트: 83 → 저장 83 / `null` → `NULL` 저장 + 결과는 기본 비중 / 101 → `OUT_OF_RANGE(0,100,PCT)` / 83.5 → `NOT_INTEGER` / 키 누락 → `422 REQUIRED` / 문자열 → `400`. **`docs/PlanResultDocsTest` 요청 스니펫**(REST Docs 누락이면 실패) | A | **#127** (paths에 `backend/src/test/java/com/moeun/backend/docs/**` 추가) |
| K-3 | 입력 화면: 토글·납입액 두 칸, (g) 산출 util(공용 폴더), (h) 요청 값 표 + 단위 테스트 6경우, 복원 규칙, `input.*` 문구, 요청 본문에 키 항상 포함, **`loadPlan()` 확정 전 저장 버튼 비활성**, **OFF면 납입액 칸 비활성**, **되보낼 값은 저장 시점의 공유 store에서 읽음** | A | **#127** |
| K-4 | 가정 보기 고정 문장(`assumptions.ratioAppliedToAll`, 금액 없음, 조건 `savingsRatioPct !== null`) | A | **#127** |
| K-5 | 목 `get-plan.200-ratio83.json` 추가(30개), README·`mocks.test.mjs` | A | **#127** |
| K-6 | 문구표 7개 추가 + `toast.applyStaleComparison` 문장 교체 | 공통 | **#127**(문구표 초기 키 Issue **#18은 이미 닫혔다**(CLOSED) → 키가 필요한 Issue가 더한다. `copy/copy.ko.yml`은 #127 paths에 그대로 둔다. 소비자 재검토 5의 "담당을 하나로"는 #127로 정했다) |
| K-7 | moeun `docs/api/frontend-api.md:246`(요청에 없는 것)·요청 표·범위 표 정정 | 공통 | **#127**(이미 paths에 있음) |
| K-8 | 계약 최종본·기획 문서 정정(C12a-5-1·5-2·5-5·5-6·7·7-1·12·R-9) | 기획 | project-workspace(이번 협상에서 처리) |
| K-9 | "토글을 끈 입력 저장은 적용된 비중을 5:5로 되돌린다"를 B팀에 알림 | B | #64·#66 본문 한 줄(이번 범위 밖 — 후속) |

- `#127` 선행: 코드 선행 #19·#30은 이미 머지되어 **추가 선행 없음**. 계약 v4가 확정되면 `status:blocked` → `status:ready`.
- `rules.yml`은 #127 paths에서 **제거**(코드 변경 없음, Z-3).
