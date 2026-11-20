# 대화·비교로 바꿀 수 있는 조건 넓히기 합의안 (moeun #12)

- 협상: `/negotiate-contract` (D-054). 기획 초안 v1 → 제공자·소비자 1차 검토 → v2 → **재검토(마지막 라운드)** → **v3**
- 본문(자기완결): `docs/design/contracts/changeable-fields-v3.md`
- 코드 근거: `../moeun` `feature/126-input-suggestion` **읽기 전용**. Issue 상태는 제공자가 `gh`로 대조한 2026-11-20 값
- 상태: **협상 종료.** 아래 "합의된 것"은 그대로 구현 가능하고, **"사람이 정할 쟁점" 3건**만 결정을 기다린다

---

## 합의된 것 (그대로 구현 가능)

> 재검토에서 양쪽이 코드로 확인하고 수렴한 항목이다. 추가 결정 없이 진행한다. 번호는 v3 CF12-17과 같다.

### 쟁점이었다가 합의로 종결된 것 4건

| 전 쟁점 | 합의 | 어떻게 수렴했나 |
|---|---|---|
| **X-A** 초과 계획의 목표 상향 | **A) 3-1 — 바꾼 조건이 초과를 벗어나면 계산을 진행한다.** `current.status = ALREADY_EXCEEDED` + `scenarios: []`로 응답에 담고 비대칭 2칸 카드. 바꾸지 않거나 바꿔도 여전히 초과면 **409 유지** | **제공자가 v1의 3-2 권고를 철회하고 소비자와 같은 입장으로 옮겼다.** 3-2를 권한 회귀 근거 3건 중 2건이 사실이 아니었고(`agent.py:143`은 409 코드→문구 키 매핑이라 수정 0줄, `:424`·`:441`은 EXPLAIN planContext 분기, 프론트 `settledStatus`는 계획 결과 상태), 3-2는 `schema.sql:190-191 ck_cm_recalc`가 `RECALC_RESULT`에 `calc_run_id`를 요구하고 `ck_cm_type`에 쓸 타입이 없어 막힌다. 결정타는 소비자 지적 — 3-2의 "바꿀까요?"→"네" 2턴 확인은 "네"에 숫자·조건이 없어 `drop_carried_conditions`(`agent.py:228-230`)가 조건을 모두 지우고 `:383`에서 CLARIFY가 되어 **성립하지 않는다.** Spring 추가분 ≈0.7일, 깨지는 기존 테스트는 `InternalCalcApiTest:240` **한 건** |
| **X-C** COMPARE 동시 개방 | **A) CHAT·COMPARE 둘 다 개방**(사용자 원안 유지). FR-CMP-02는 Should 그대로, 프론트 비교 영역은 만들지 않는다 | **소비자가 보류를 철회했다.** `COMPARE`는 `rules.yml:17`·`PlanService.java:51`·`ChangePath.java:7`·`schema.sql:91`에만 있고 **조회 경로가 없어 추가 비용 0**. 적용 경로(`merge`)는 어차피 공용이라 두 번 안 고친다 |
| **X-D** Issue reopen 정책 | **C) 혼합.** 단 **"C2-4 불변식" 단독 신규 Issue는 만들지 않는다**(같은 파일, `status`는 이미 응답에 있다). reopen 대상은 **#21·#18 중심** | 양쪽 수용. 제공자가 "같은 파일을 두 PR이 건드린다"를 근거로 단독 Issue를 반대 |
| **X-E** 모르는 키 저장 동작 | **A) 저장 실패.** 범위는 **해당 ASSISTANT 메시지를 `FAILED`**(턴 전체 500 아님), `RECALC_RESULT`로 저장하지 않음, 기존 `chat.failed` 재사용, **새 문구 키 없음**. **`condition_changes`만 비우는 부분 저장은 반대(제공자 양보 불가 — `ck_cm_recalc`가 DB에서 터진다)** | v2가 "현상"으로 적은 **"chat 리스너의 4키 고정 맵"은 코드에 없다**(`chat/`은 `package-info.java` 하나, `origin/develop`도 같다). 저장·F-4·F-5는 **#44·#45·#128(모두 OPEN, team:B)** 이 앞으로 쓴다 → **비용 ≈0, 소유는 B팀.** 대화는 202+폴링이라 "500을 보는 사용자"가 없고, 읽기 쪽(`toOverride`)이 이미 fail-closed라 쓰기도 맞춘다 |

### 설계 확정 (양쪽 코드 확인)

| # | 항목 |
|---|---|
| 1 | `max-fields` = **6**. `ConditionValidator.validateChanged:83-86`이 `allows(field)`를 따로 보므로 **"허용 5 < max 6"에 가드 구멍이 없다**(v2의 우려는 불성립). 5로 두면 2단계에서 또 고친다. `TOO_MANY_CHANGES` 문구·화면은 만들지 않는다 |
| 2 | `rules.yml` `fields:` 블록 **불변**, `change-paths` 허용 목록만 확장. **yml만 고치면 `/internal/calc`에 효과가 0이다**(`InternalCalcController.CHANGEABLE_KEYS`는 yml을 읽지 않는다 — 제공자 양보 불가) |
| 3 | **C2-4 불변식 개정 + 쪽별 `status`.** 단 **`CalcResultView.java:21`에 `status`가 이미 있고 `InternalCalcResponse`가 그대로 내보낸다 → Spring 코드 변경 0**(javadoc·계약 문구·소비자 타입만). *v2의 "응답에 담는다"는 과대 확정이었다* |
| 4 | 한쪽 초과면 `scenarios: []`·`diff.byScenario: []`. **`comparable` 플래그 없음**(`status` 두 개로 결정된다) |
| 5 | `changed` 초과여도 **적용 버튼 활성**. 예고 문장은 **ai-server가 `changed.status`를 보고** 붙인다(모델 아님) |
| 6 | **초과인 쪽에 `conditions.<side>.heldAssets`를 만든다 — 목표 금액만 여는 1단계에도.** v2의 모순(초과 칸 문장이 `{heldAssets}`를 쓰는데 `putConditions`는 `isSingleResult`일 때만 만든다)을 해소했다. 초과 칸 문구는 결과 화면 문구 재사용이 아니라 **`chat.cardAlreadyExceeded` 신규 키** |
| 7 | display 쪽별 키 이름 = **`conditions.current.…` / `conditions.changed.…`**. **제공자가 자기 안(`current.goalAmount`)을 철회**(`ResultDisplayBuilder.build(…, resultPrefix, conditionPrefix)`가 이미 조건 접두어를 받고 `CompareConditionsUseCase:33-36`에 상수가 있어 `putConditions` 한 줄) |
| 8 | **목표가 바뀐 비교에서는 무접두어 `goalAmount`를 Spring이 아예 만들지 않는다**(소비자 안). 조용한 덮어쓰기와 모델의 잘못 인용을 **구조적으로** 막는다(프롬프트 준수에 기대지 않는다) |
| 9 | **`DISPLAY_KEY`(`schemas.py:84-90`) 개정은 필요 없다** — planContext 전용 필터이고 비교 display는 `calc.py:_select_for_model`이 무필터 통과시킨다(`current.GOOD.afterTaxAsset`가 이미 통과 중). **단일 경로에 `conditions.goalAmount`가 생길 때만** 한 단어 추가(안 더하면 조용히 버려지므로 그때는 범위 필수). **ai-server에 `ComparisonResponse` 스키마는 없다** |
| 10 | **`CalcComparison.ConditionValues` 2필드 확장과 딸린 REST Docs·C2-3 개정은 뺀다** — 쪽별 `goalAmount` raw는 `CalcResultView`에 이미 있다(소비자 F-4 목 확인, 제공자 ≈0.5일 절감) |
| 11 | **`a5-already-exceeded.json`은 이미 있다 → 지우지 않고 "바꿔도 여전히 초과" 사례로 의미를 재배치**하고, "`current` 초과 + `changed` 정상" 200 성공 예시를 **별 파일로 추가**. `InternalCalcApiTest:240`도 그 사례로 교체 |
| 12 | **`drop_carried_conditions` 확장**(`_GOAL`·`_HELD` 정규식, **둘 다 1단계**). 위험은 **조건부**다: "목표를 1억으로"는 숫자 수 > 조건 수 가드로 **유지**되고, "목표 2,500**만원**으로"는 `_MONTHLY`의 `만원`에 걸려 `goal_amount`가 **조용히 삭제**된다 |
| 13 | **`check_amount_units`는 기존 `_NUMBER`·`_KO_MAN`·`_THOUSANDS_COMMA` 재사용**(한글 수사도 꽤 넓게 세므로 건너뛰는 범위가 좁아져 더 안전하고 비용도 준다). **`held_assets`는 숫자 토큰이 없을 때 건너뛰지 않고 CLARIFY**(한글 수사 "삼천만원"→`3000`이면 카드가 "약 0만원") |
| 14 | **`prompts.py:53-54` 규칙 9를 쪽별로 다시 쓴다**(제공자가 재검토에서 새로 제기). 지금은 단일 결과 기준이라 비대칭 2칸에서 모델이 어느 쪽 `status`를 보는지 애매하다. **T-8 범위** |
| 15 | **제공자의 `notes` 경로(`chat.heldAssetsBasis`를 Spring이 내림)는 폐기 확정** — `_select_for_model`이 새 최상위 키를 조용히 버리고, 받으려면 `test_calc_client.py:318-322,379` 단언까지 바꿔야 한다. v2의 폐기가 옳다고 양쪽이 확인했다 |
| 16 | 문구 **1단계 신규 4**(`condition.goalAmount`, `chat.goalAmountChangedNote`, `chat.changedAlreadyExceeded`, `chat.cardAlreadyExceeded`) · **개정 3**. `chat.changedAlreadyExceeded`는 **자리 값 없음**이고 ai-server가 붙인다. `chat.alreadyExceeded`는 **409 경로만** 맡는다("적용하면 초과"는 200 안의 `changed.status`라 경로가 달라 키를 나눌 필요가 없다). 제안 문장: **"이미 가진 자산이 목표 금액을 넘었어요. 대화로 목표 금액을 더 높게 바꿔 볼 수 있어요."** |
| 17 | 배포 순서 **Spring → ai-server → 프론트** + **문구 본문 개정은 ai-server 활성화와 같은 날 나간다**(Spring `CopyBook`만 먼저 나가면 "대화로 바꿔 보세요"가 가리킨 곳이 아직 안 된다) |
| 18 | **단위 자동 보정 금지**, 범위 검증은 **Spring 한 곳(D-033)**, 비정상 값 경고 규칙 없음. **단위 사고의 최종 방어선은 카드 확인뿐**이라는 사실을 기록한다(내부 경로라 Spring이 더 할 수 있는 일이 없다) |
| 19 | **고정 문장 테스트는 삭제하지 않고 대상 교체**(D-056·CP-05 보호 유지), `test_out_of_scope.py:230`은 그대로 |
| 20 | **DB 스키마 변경 0**, `PlanService.merge`는 `firstNonNull` 2줄, 되돌리기 추가 작업 없음, `source` CHECK에 `'CHAT'` 이미 있음 |
| 21 | **`ConditionOverride`는 X-B가 B안이어도 2필드를 한 번에 넣고** yml·`CHANGEABLE_KEYS`에서만 `heldAssets`를 뺀다(테스트 fixture 4파일 20여 곳 수선을 **한 번만** 하려고) |
| 22 | **`agent.py:143`·`:424`·`:441`·프론트 `settledStatus`는 수정 0줄**(v1·v2의 회귀 추정 정정) |

### 작업량 (X-B B안 기준)

- Spring(A팀) **≈3.3일** — v2의 4.1 + 1.5일에서 줄었다(`ConditionValues` 제외 −0.5, C2-4가 코드 0, 3-1 증분 0.7).
- ai-server·chat·프론트(B팀) **≈4.2~4.7인일** — chat 저장 ≈0(아직 안 쓴 코드), 3-1 증분 0.2.
- X-B A안이면 **Spring +1.0일 / B팀 +2~2.5인일**.

---

## 사람이 정할 쟁점

### 쟁점 1 (X-B) — 1단계 범위: `HELD_ASSETS`를 이번에 넣을까

> **사용자 지시를 바꾸는 일이라 반드시 사람이 정한다.** 사용자는 범위를 "`GOAL_AMOUNT`와 `HELD_ASSETS` 둘"로 못 박았는데 **제공자·소비자가 재검토에서도 모두 B안**을 권한다.

**제공자 의견 (A팀 Spring)**
- **B) 목표 금액만** 지지. A안도 구현하지만(+1.0일) **양보 불가 조건**: A안을 고르면 **C2-6 개정이 범위에 들어온다.** C2-6은 *"비교에서는 `calcStartMonth`·`heldAssets`·`assumptions`를 만들지 않는다 — 비교 답변이 세율·기준월을 인용하지 않게 하려는 것"* 이라고 **의도와 이유를 클래스 주석에 적어 둔 규칙**이다. 범위 = 규칙 개정 + **그 규칙이 막던 위험을 프롬프트로 다시 막기**. **"display 한 줄"로 적으면 안 된다.**

**소비자 의견 (B팀 ai-server·chat·프론트)**
- **B) 목표 금액만** 수용. 양보 불가 조건 4개:
  1. `held_assets`를 열기 전에 **`check_amount_units`** 진입 조건 셋(표 테스트 15행 이상 / fake 고정 JSON 2건 / **2주차 말까지 머지**). 안 서면 자동으로 B안.
  2. **T-13('입력 수정' 버튼 제거)은 2단계 완료 뒤.**
  3. **1단계에서는 `chat.unchangeableCondition`에 "보유 자산은 입력 수정에서" 안내를 유지한다.** 1단계에서 보유 자산은 여전히 입력 수정으로만 바꾸므로 빼면 **막다른 길이 새로 생긴다** — *v2가 "입력 수정에서를 뺀다"고 확정한 것은 B안에서 틀렸다.*
  4. **`_GOAL`·`_HELD` 정규식과 `ConditionOverride`의 `heldAssets` 타입 필드는 1단계에 함께**(fixture 수선·정규식 작업을 한 번만 하려고).
- 위험 근거: 단위 구멍에서 **보유 자산이 가장 위험하다.** `min 0`이라 전 구간이 통과하고 "3,000원"이 카드에 "약 0만원"으로 보여 **사용자가 알아채기 어렵다.** 목표 금액은 "약 1만원"처럼 눈에 보인다.

**기획 의견**
- 두 검토가 **독립적으로** 같은 결론(한쪽은 위험, 한쪽은 비용)에 왔다는 점이 가장 무겁다. 다만 사용자 원안을 바꾸는 일이고, 아래 제품 영향이 선택마다 다르다.

**선택지와 영향**

| | **A) 둘 다 이번에**(사용자 원안) | **B) 목표 금액만, 보유 자산은 2단계** |
|---|---|---|
| 일정 | Spring ≈4.3일 / B팀 ≈6.5~7.2인일 | Spring ≈3.3일 / B팀 ≈4.2~4.7인일 |
| 계약 | **C2-6 개정**(비교 display `calcStartMonth`·`assumptions` 해제) + 그 규칙이 막던 위험을 프롬프트로 재방어 | C2-6 **그대로**(초과 칸 `heldAssets`만 예외로 추가 — 합의 6) |
| 문구 | `chat.heldAssetsBasis`·`condition.heldAssets` 신규 2건 이번에. `chat.unchangeableCondition`은 "여기서는 바꿀 수 없어요"로 끝낸다 | 신규 2건 2단계로. **`chat.unchangeableCondition`에 "보유 자산은 입력 수정에서" 유지** |
| 금융 위험 | `check_amount_units`가 없으면 막을 수단이 **프롬프트뿐** → 단위 사고가 **조용히** 틀린 계획을 만든다 | 목표 금액은 눈에 보이는 범위라 프롬프트 + 카드 확인으로 받을 수 있다 |
| 제품 | "저축을 더 했어요"류 발화를 대화로 반영 가능 | 그 발화는 여전히 입력 수정으로만 → **작은 막다른 길이 남는다**(단 안내가 가리키는 곳은 실제로 작동한다) |
| **D-035**(보유 자산 기준월 안내) | **범위 확장**(대화 경로에도 같은 기준 안내 필요) → 새 D-번호로 기록 | **변경 없음**(입력 화면 문구 그대로) |
| **제품 방향: 입력 수정 버튼 제거(CP-07·T-13·#51)** | **이번 변경으로 선행이 모두 충족** → 버튼 제거를 바로 결정할 수 있다 | **버튼을 아직 없앨 수 없다**(없애면 보유 자산을 바꿀 곳이 사라진다). T-13 선행 = **2단계 완료** |
| SRS | CP-07 "6개", FR-INP-05 수용 기준 추가 | CP-07 "5개", FR-INP-05 **변경 없음** |

**기획 추천: B) 목표 금액만** — 단 **2단계를 같은 결정에서 "할 일"로 못 박고**(D-035 확장·`chat.heldAssetsBasis`·`check_amount_units`를 2단계 범위로 명시), **T-13의 선행을 "2단계 완료"로 적는다.**
이유: ① 이번 변경의 목적(FR-RES-01의 막다른 길 제거)은 목표 금액만으로 달성된다 ② 보유 자산은 틀려도 **사용자가 알아챌 수 없는** 유일한 필드라 결정적 대조(`check_amount_units`)가 선 뒤에 여는 편이 금융 조언 제품에 맞다 ③ 1단계 설계는 CF12-7-2를 그대로 둔 채 **구현만 미루므로 계약을 두 번 고치지 않는다.**
**단, B안을 고르면 "입력 수정 버튼 제거"는 이번에 못 한다는 것을 함께 받아들이는 것이다.**

---

### 쟁점 2 (X-F, 신규) — moeun #132 선행을 언제까지 기다릴까

**현황(제공자 `gh` 대조, 2026-11-20)**: #132 `[calc] 대화 조건 변환 코드를 한 곳으로 모으기`는 **OPEN·`status:in-progress`**, **열린 PR 0건**, `origin`에 132 관련 브랜치 없음, `calc/application/ConditionChanges.java` **아직 없음**. 즉 작업물이 나오지 않았다.

**제공자 의견**
- **선행 요구 유지**가 기본. #132 본문 수용 기준이 "`/internal/calc` 응답이 바뀌지 않는다"라 **4키 기준으로 끝내야 리뷰가 쉽다.** 먼저 머지되면 이번 변경의 중복 3곳이 **한 파일 한 곳**으로 줄어든다(≈0.3일 절감).
- **늦어질 조짐이면 "#132를 이번 변경에 흡수"**(#132를 닫고 신규 `[calc] 대화 조건 5(6)필드 배선`에 "변환기 한 곳으로 모으기 + 키 확장"을 함께 넣는다).
- **"각각 고치고 나중에 합치는" 안만 반대**: 고칠 곳이 `InternalCalcController`·`PlanContextProviderImpl`·chat 저장 **세 곳**인데, 세 곳을 넓힌 뒤 합치면 "세 곳의 동작이 서로 다르지 않다"를 증명하는 테스트를 **두 번** 쓴다.
- 제공자 제안 판단 시점: **PR이 올라오지 않은 채 하루가 더 지나면 흡수.**

**소비자 의견**: 직접 의견 없음. 다만 **배포 순서상 Spring이 먼저 끝나야 ai-server를 켤 수 있어** #132 지연은 B팀 착수 시점을 그대로 민다.

**기획 의견**: 흡수 쪽이 "두 번 증명"을 피하지만, #132 담당자가 이미 진행 중이라 **흡수는 그 사람의 작업을 가져오는 일**이다. 일정이 아니라 **사람 배정 문제**라 기획이 정할 수 없다.

**선택지와 영향**

| | **A) 선행 유지(기다린다)** | **B) 지금 흡수한다** | **C) 기한을 정하고 자동 전환** |
|---|---|---|---|
| 일정 | #132 머지까지 이번 변경 착수가 막힌다. 머지 뒤 ≈0.3일 절감 | 바로 착수. #132를 닫고 신규 1건이 변환기 통합 + 키 확장을 함께 한다 | 기한(예: 2026-11-21 EOD)까지 PR 없으면 B로 |
| 리뷰 | #132가 "동작 변경 없음"을 단언할 수 있어 리뷰가 쉽다 | 한 PR이 **리팩터링 + 기능 확장**을 같이 해 리뷰가 무거워진다 | A의 장점을 짧게 시도 |
| 사람 | 현재 담당자(#132) 유지 | **담당 재배정 필요** | 전환 시점에 재배정 |
| 위험 | 3주 일정에서 착수 지연이 그대로 꼬리를 문다(B팀까지 밀린다) | 큰 PR의 회귀 | 기한을 넘기면 A의 손해만 남는다 |

**기획 추천: C) 기한을 정하고 자동 전환** — 제공자 제안대로 **"#132 PR이 올라오지 않은 채 하루가 더 지나면 흡수"** 를 결정으로 적는다. 이유: 선행의 이득(≈0.3일 + 쉬운 리뷰)은 작고, **착수 지연은 두 팀 모두를 민다.** 기한을 명시해 두면 매일 다시 판단하지 않아도 된다. **다만 흡수는 담당 재배정을 동반하므로 사람이 정한다.**

---

### 쟁점 3 — 사람이 확인할 결정 변경 3건

> 이 협상은 기존 결정 3건을 바꾼다. **에이전트가 확정하지 않았다.** 아래를 확인해 주면 D-번호를 받아 `decisions.md`에 기록하고 SRS·계약에 반영한다.

| # | 바뀌는 결정 | 현재 내용 | 바뀐 뒤 | 왜 |
|---|---|---|---|---|
| **1** | **D-040 대체** | "대화로 바꿀 수 있는 조건은 기존 4개를 유지하고 목표 금액은 입력 수정으로 바꾼다" | **5개**(X-B B안) 또는 **6개**(A안). 목표 종류·기존 납입액은 계속 제외 | 입력 수정 버튼을 없애기 전에 안내가 가리키는 출구를 먼저 만든다(CF12-1). 같이 바뀌는 것: **CP-07**, **D-056**(문구 안의 "4개 조건"), **D-059**("네 조건"→"다섯/여섯 조건") |
| **2** | **D-071 변경** | "초과 계획에서 대화로 **4개 조건**을 바꾸면 `ALREADY_EXCEEDED` 고정 문장, 비교·적용 없음" | **"목표(·보유)를 바꾸지 않거나, 바꿔도 여전히 초과일 때만 고정 문장."** 바꿔서 초과를 벗어나면 정상 비교(비대칭 2칸) | **X-A = 3-1 합의의 직접 결과.** 문자 그대로 읽으면 목표 금액 변경은 D-071의 범위 밖(공백)이지만 **구현(`CompareConditionsUseCase:88-92`)은 변경 키와 무관하게 던지므로** 결정이 필요하다. 영향: FR-AI-01·FR-RES-01 수용 기준, plan-context.md 머리말, internal-calc C2-2 검사 8·C3-2 |
| **3** | **internal-calc C2-4 불변식 개정** | "`status`는 이 경로의 성공 응답에서 항상 `CALCULATED`… 대화로 목표·보유를 바꿀 수 없으므로 `changed`도 `CALCULATED`다" | `current`·`changed` 각각 `ALREADY_EXCEEDED`일 수 있고, 그 쪽은 `scenarios: []` | **X-A를 어떻게 정하든 필수**였다(목표를 내려 `changed`가 초과가 되는 경우). **Spring 코드 변경은 0**(`CalcResultView.status`가 이미 있다) — 계약 문구·javadoc·소비자 타입만 바뀐다 |

**D-035는 바꾸지 않는다.** 단 **X-B 선택에 따라 영향이 다르다**: A안이면 "보유 자산 기준월 안내"가 대화 경로까지 **범위 확장**되어 새 D-번호가 필요하고, B안이면 **변경 없음**(2단계로 미룬다).
**D-058(Issue 본문 수정 우선)은 유지**하되, X-D 혼합 합의가 "CLOSED Issue는 reopen해 본문을 고친다"로 해석을 넓힌다.

**질문 등록 권고**(최종 번호는 `open-questions.md` 등록 시 확정): 쟁점 1 → **Q-085**(개발 차단), 쟁점 2 → **Q-086**(개발 차단), 쟁점 3 → **Q-087**(개발 차단).

---

## 후속 작업

> 상태는 제공자가 `gh`로 대조한 2026-11-20 값이다. **처리 방식은 X-D 혼합 합의를 따르지만, reopen 대상 일부는 사람이 정할 여지가 있다** — "X-D 결정에 따라 갈림"으로 표시했다.

| T | 작업 | 담당 | Issue | 상태 | 처리 | 선행 |
|---|---|---|---|---|---|---|
| T-1 | `rules.yml` CHAT·COMPARE 허용 확장 + `max-fields: 6` | A | 신규 `[calc] 대화 조건 5(6)필드 배선`(참조 #17) | #17 **CLOSED** | **신규**(참조 링크) | 쟁점 1·2 결정 |
| T-2 | `ConditionOverride` **2필드** + `ConditionValidator.changedFields` + fixture 4파일 컴파일 수선 | A | 같은 신규 1건 | — | **신규** | T-1 |
| T-3 | `ConditionResolver` override 배선 + "override가 결과를 바꾼다" 단위 테스트 | A | 같은 신규 1건(참조 #25·#32) | #25·#32 **CLOSED** | **신규** | T-2 |
| T-4 | `PlanService.merge` 배선 + 적용 테스트 | A | 같은 신규 1건(참조 #33) | #33 **CLOSED** | **신규** | T-2 |
| T-5 | `PlanContextProviderImpl` `CHANGEABLE_KEYS`·`toOverride` 키 확장 | A | **#132** | **OPEN** | **본문 수정**(합침) | — |
| T-6 | `CompareConditionsUseCase` 초과 분기 역전 + C2-4 문구 개정(코드 0) + `diff` 비움 + display 쪽별 분리 + 초과 칸 `heldAssets` | A | 같은 신규 1건 | — | **신규.** **"C2-4 불변식" 단독 Issue는 만들지 않는다**(합의) | 쟁점 3 확인 |
| T-7 | internal-calc 계약·fixture(A-4 키 교체, `a4-response.json`, **a5 의미 재배치 + 200 성공 예시 추가**, REST Docs display 분) | A | **#10** `[contract] /internal/calc 응답·검증 오류 형식 확정` | **CLOSED** | **reopen 또는 신규 1건에 흡수 — X-D 결정에 따라 갈림** | T-6 |
| T-8 | ai-server 도구·`ConditionChanges` 키 확장 + **`drop_carried_conditions` `_GOAL`·`_HELD`** + **`calc.py` `status` 통과** + **규칙 9 쪽별 재작성** | B | **#21** `[ai] 대화 조건 4개로 축소 — M-2` | **CLOSED** | **reopen 권고**(자기가 한 축소를 되돌리는 일이라 이력이 한 곳에 남는 것이 정직 — 양쪽 일치) | Spring 배포 완료 |
| T-9 | 프롬프트 개정(`:7-8,18,21-27,30-31,53-54,70,75`) + 단위·역할 규칙 + **`check_amount_units`**(2단계 전제) + fake 테스트 + 고정 문장 테스트 대상 교체 | B | **#21**, 단위·되묻기 테스트는 **#23** | 둘 다 **CLOSED** | **#21 reopen + #23은 테스트만 흡수 — X-D 결정에 따라 갈림** | T-8 |
| T-10 | 문구표 1단계 신규 4 · 개정 3 + `CopyBook.java` + 프론트 `copy.ts` 2곳 | 공통 | **#18** `[docs] 문구표 copy.ko.yml` | **CLOSED** | **reopen 권고**(본문 개정이 곧 이력) | 쟁점 1 결정 |
| T-11 | chat 저장 맵을 **처음부터 5(6)키** + **모르는 키 → 메시지 FAILED** 테스트 | **B** | **#44 · #45 · #128** | **모두 OPEN** | **본문에 수용 기준 추가**(신규 없음). 변환기는 #132 공통 코드를 쓴다 | #132(쟁점 2) |
| T-12 | 프론트 비교 카드(비대칭 초과 칸, 쪽별 목표 금액, `conditions` 5(6)행, 주의 문구, `status` 타입) + 목 JSON 3개 | B | **#53** `[front] 대화창 비교 결과 카드와 '내 계획으로 적용' 버튼` | **OPEN**(in-progress) | **본문 수정** | T-6, T-7 |
| T-13 | '입력 수정' 버튼 제거 (**이번 범위 밖**) | B | **#51** `[front] 입력 수정 복귀…` | **CLOSED** | **이번에 건드리지 않는다**(별도 결정) | **쟁점 1이 B안이면 "2단계(HELD) 완료" 뒤** |
| T-14 | 계약 문서 반영(이 repo): internal-calc, frontend-api-chat, plan-context, frontend-api-plan, b-team-contracts, alignment | 기획 | — | — | 결정 뒤 기획이 수행 | 쟁점 1~3 결정 |
| T-15 | SRS·decisions 반영(CP-07, FR-AI-06, FR-CMP-02, FR-RES-01, FR-AI-01, FR-INP-05, FR-PLAN-03·04 + D-번호 3건) | 기획 | — | — | 결정 뒤 requirements-pm | 쟁점 3 확인 |

**X-D 결정에 따라 갈리는 부분**: T-7(#10), T-9(#23). 두 Issue는 "reopen할지 / 신규 1건에 흡수할지"가 아직 열려 있다. **#21·#18 reopen과 #132·#53·#44·#45·#128 본문 수정은 양쪽이 합의했다.**

---

## 협상 기록

| 라운드 | 문서 | 결과 |
|---|---|---|
| **v1** | `changeable-fields-v1.md` | 기획 초안. 구현 지점 6곳, 쟁점 9개(1, 2, 3-1~3-7, 4-1·4-2). 추천: `max-fields` 미정, 3-1, `DISPLAY_KEY` 개정, `GOAL_AMOUNT_COPY` 삭제, `achievementChange` null 숨김 |
| **1차 검토** | `review-changeable-fields-v1-provider.md` / `-consumer.md` | **제공자**: 빠진 구현 지점 4건 제시(`InternalCalcController` Set·`validate`, `PlanContextProviderImpl` Set, display 무접두어 `goalAmount`), **3-2 권고**, 양보 불가 6건. **소비자**: `drop_carried_conditions`가 새 키를 지운다는 **핵심 발견**, 단위 구멍 사례 정정, **3-2 거절**(`ck_cm_recalc`·D-041), `achievementChange` 숨김 반대 |
| **v2** | `changeable-fields-v2.md` | 구현 지점 **13곳**으로 확장, 합의 **21건** 확정, 쟁점을 **X-A~X-E 5건**으로 재정리. 재검토 질문 P-1~7 / C-1~8 |
| **재검토(마지막)** | `review-changeable-fields-v2-provider.md` / `-consumer.md` | **제공자: "수정하면 수용" + X-A에서 3-2 권고 철회(3-1로 이동)**, display 키 이름도 소비자 안 수용, v2 확정 4건을 오류로 지적(`status` 이미 존재 / chat 맵 없음 / `DISPLAY_KEY` 불필요 / a5 fixture 존재), 규칙 9 쪽별 재작성 신규 제기. **소비자: "수정하면 수용" + X-C 보류 철회**, v2 확정 3건 오류 지적(`DISPLAY_KEY`·`ComparisonResponse`·`unchangeableCondition`), 초과 칸 `heldAssets` 모순 지적, `ConditionValues` 확장 불필요, 문구 신규 4·개정 3 재확정 |
| **v3** | `changeable-fields-v3.md` (이 합의안의 본문) | **합의 26건 확정**(X-A·X-C·X-D·X-E 종결), v2의 **잘못된 확정 6건 정정**, 작업량 재산정(Spring 4.1+1.5 → **3.3일**, B팀 7~8 → **4.2~4.7인일**). 남은 쟁점 **3건**(X-B, X-F, 결정 변경 확인) |

**협상에서 양쪽이 입장을 바꾼 것**(기록 가치가 있는 부분)
- 제공자: X-A 3-2 → **3-1**(자기가 든 회귀 근거 2건이 사실이 아님을 코드로 확인), display 키 이름 `current.goalAmount` → **`conditions.current.goalAmount`**, `notes` 경로 **철회**.
- 소비자: X-C 보류 → **수용**(코드로 "깨질 것 없음" 확인), 3-2 거절 근거 중 "CHECK 개정 필수"는 **과장이었다고 스스로 정정**(정확히는 F-4·F-5 계약과 D-041이 막는다).
- 기획: v2의 확정 6건을 **철회·정정**(과대 확정 2건, 없는 코드 2건, 모순 1건, 불필요한 범위 1건).
