# changeable-fields-v1 소비자 검토 (B팀: ai-server·chat·프론트)

- 검토 대상: `changeable-fields-v1.md` (CF12). 근거 코드는 `../moeun` `feature/126-input-suggestion` 읽기 전용.
- 쟁점 번호: 초안의 쟁점 1·2·3(-1~-7)·4(-1·-2)를 X-1~X-4로 줄여 쓴다.

판정: **수정하면 수용**

방향(CHAT에서 목표 금액을 바꿔 막다른 길을 없앤다)은 수용한다. 다만 초안은 소비자 쪽 구멍 세 곳을 놓쳤다.
(1) ai-server에 `drop_carried_conditions`가 있어 목표 금액·보유 자산 값이 **조용히 지워진다**(CF12-4 표에 없음).
(2) 단위 구멍 예시가 틀렸고, 실제 구멍은 더 크다(아래 2절).
(3) X-3-2 "확인 → 바로 적용"은 DB 제약·D-041과 부딪혀 소비자에게 싸지 않다.

---

## 1. FR-AI-06 / ai-server 범위 (쟁점 X-4)

### 1-1. 실제로 고칠 곳

초안 CF12-9 표는 `_CONDITION_FIELDS`·`ConditionChanges`·프롬프트 3줄·문구 매핑만 적었다. 코드에서 더 나온 곳은 **굵게**.

| 파일:행 | 지금 | 바꿀 것 |
|---|---|---|
| `app/schemas.py:31-42` `ConditionChanges` | 4필드, `extra="forbid"`, docstring "4개(M-2, D-040)" | `goal_amount`, `held_assets`: `StrictInt \| None` 추가. docstring의 D-번호 갱신 |
| `app/llm/agent.py:74-79`, `:86` | 도구 4키, 설명 "네 가지" | 6키, "여섯 가지". `required`는 `list(_CONDITION_FIELDS)`라 자동 |
| **`app/llm/agent.py:165-230` `_stated_conditions`·`drop_carried_conditions`** | 발화의 표현으로 "말한 조건"을 4개만 가려내고, **그 밖의 키는 history에서 이어받은 값으로 보고 지운다**(`:230` `if k in stated`) | **새 두 키를 모르므로, history가 있는 대화에서 사용자가 말한 `goal_amount`·`held_assets`가 계산 전에 지워진다.** 그러면 `:383`에서 "바꿀 조건이 없습니다"로 CLARIFY가 되거나(최선), 같이 말한 다른 조건만 계산된다. 가장 위험한 것은 `_MONTHLY`(`:186` `만원`·`\d\s*만`·`\d\s*원`)가 목표 금액 발화에도 걸려 **월 저축액으로 오인**하는 것. 새 정규식 `_GOAL`(목표·모으려), `_HELD`(보유·가진·모아둔·이미·지금 있는)를 `_stated_conditions`에 추가하고, 목표·보유 단어가 있으면 일반 금액 표현을 월 저축액으로 세지 않게 한다. `tests/test_no_accumulate.py` 표 테스트(`:337`~`:372`)에 새 행 필요 |
| `app/llm/agent.py:45-57` `out_of_scope_content`, `_CONDITION_COPY_KEYS` | 범위 밖 안내에 "대화로는 4개 조건 이름"을 잇는다 | 문구표에 `condition.goalAmount`·`condition.heldAssets` 키를 더하고 6개로(`app/core/copy.py:93` `_CONDITION_CODES`). `tests/test_out_of_scope.py:119-125`가 "목표 금액이 **없다**"를 단언하므로 **뒤집힌다** |
| `app/llm/agent.py:139-144` `_FIXED_COPY_KEYS` | `FIELD_NOT_CHANGEABLE → chat.unchangeableCondition` | 유지. 단 이 문구는 이제 **목표 종류·기존 납입액·오타 키**용이고, 가리킬 곳(입력 수정)이 없어질 예정이므로 "여기서는 바꿀 수 없어요"로 끝내야 한다(막다른 길 재발 방지). 본문 개정은 #18 |
| **`app/tools/calc.py:86-102` `_select_for_model`, `:117-125` `_select_side`** | 모델에 `scenarios[].{scenario,isAchieved}`만 준다. **`status`를 안 준다** | X-3-1·3-4로 한쪽이 `ALREADY_EXCEEDED, scenarios: []`가 되면 모델은 "빈 목록"만 보고 사유를 모른다. `status`를 통과시키지 않으면 프롬프트 규칙 9가 동작할 수 없다. `_check_display`(`:105-114`)는 빈 `scenarios`면 루프를 안 돌아 그대로 통과한다 |
| `app/llm/prompts.py:7-8` | `GOAL_AMOUNT_COPY` | 상수 삭제 대신 **목표 종류·기존 납입액 전용 문구**로 재사용(아래) |
| `prompts.py:18` | "네 가지뿐" | "여섯 가지" |
| `prompts.py:21-22` | 목표 금액 발화 → 전용 문구 | 삭제 |
| **`prompts.py:23-24`** | "이미 모은 돈이나 기존 납입액 … 입력 수정에서 바꿀 수 있다고" | 초안이 빠뜨림. "이미 모은 돈"은 이제 `held_assets`다. **"기존 납입액"만 남기고**(여전히 못 바꿈) 목표 종류와 함께 전용 문구로 |
| **`prompts.py:25-27`** | "네 조건을 더/덜…" | "여섯 조건"(D-059). 목표·보유도 상대 표현은 되묻는다 |
| **`prompts.py:30-31`** | "goalAmount는 같은 값이라 어느 쪽을 인용해도 됩니다" | **X-3-6 때문에 이 전제가 깨진다**(양쪽 목표가 다를 수 있음). `current.goalAmount`·`changed.goalAmount`로 갈라 인용하게 고친다. 이 줄을 안 고치면 모델이 엉뚱한 쪽을 인용한다 |
| `prompts.py:53-54` | 초과면 "입력 수정에서 바꿀 수 있어요" | "대화로 목표 금액을 바꿔 볼 수 있어요"(plan-context 규칙 9와 동일). 모델이 짓지 않게 문구표 문장을 그대로 인용하라고 한다 |
| `prompts.py:70`, `:75` | 조건 변경 정의 4개, 목표 금액 발화는 "그 밖의 질문이 아니다" | `:70` 6개로, `:75` 삭제 |
| 신규 | 없음 | 단위·역할 규칙 한두 줄(2절), 보유 자산 시작월 문구 덧붙이기(4절). 덧붙이기는 `with_tax_note`(`agent.py:582`, `check_numbers` 뒤)와 같은 위치·방식 |

초안의 "프롬프트 `:21`·`:54`·`:75` 삭제"는 **필요하지만 충분하지 않다.** 프롬프트 변경 범위는 `:7-8, 18, 21-27, 30-31, 53-54, 70, 75` + 신규 규칙이다. 한 군데라도 남으면 모델이 옛 고정 문장으로 답하는 회귀가 난다(예: `:23`이 남으면 "3,000만원 모았어요"에 "입력 수정에서…"로 답한다).

### 1-2. 되돌리기 어려운 회귀 위험 (고정 문장 테스트)

고정 문장은 D-056·CP-05의 약속(모델이 짓지 않음)이라 **삭제가 아니라 대상을 바꿔** 지켜야 한다. 그냥 지우면 "대화로 못 바꾸는 요청도 `ANSWER`, `OUT_OF_SCOPE` 아님"이라는 보호가 같이 사라진다.

| 테스트 | 처리 |
|---|---|
| `tests/test_agent_tools.py:22` `REMOVED_KEYS`, `:98` "4키뿐" | `goal_amount`·`held_assets`를 빼고 `existing_monthly_contribution`만 남긴 6키 단언으로 교체 |
| `:119-126`, `:130-141` 목표 금액 발화 → 전용 문구, `goal_amount` 도구 호출은 is_error | **목표 종류 발화**로 대상 교체. 새로 "목표 금액 발화는 `recalculate`를 부른다" 테스트 추가 |
| `:143-150` 프롬프트에 `GOAL_AMOUNT_COPY` 글자 그대로 | 새 전용 문구 기준으로 |
| `tests/test_out_of_scope.py:119-125`, `:188-260` AC-4 | 위와 같이 대상 교체. ANSWER에 OUT_OF_SCOPE 치환이 번지지 않는 테스트(`:230`)는 **그대로 둔다** |
| `tests/test_copy.py:37, 100-102, 135, 208-221` | 문구 본문 하드코딩(`"목표 금액은 입력 수정에서 바꿀 수 있어요…"`)이 #18 개정과 **같은 PR**에서 바뀌어야 한다 |
| `tests/test_calc_client.py:269` + `docs/api/examples/.../field-not-changeable-response.json` | fixture의 `field: goalAmount`를 `goalType` 등으로(초안 A-4와 같음) |
| `tests/test_no_accumulate.py` | 위 `drop_carried_conditions` 새 행(목표·보유 발화가 지워지지 않음, 월 저축액으로 오인되지 않음) |

회귀 위험이 가장 큰 곳은 `test_copy.py`의 문구 본문 단언과 `drop_carried_conditions` 표 테스트다. 앞의 것은 문구와 함께 바뀌지 않으면 CI가 깨지고, 뒤의 것은 **테스트가 통과한 채로** 새 키가 지워질 수 있다(표에 새 행이 없으면 아무도 모른다).

### 1-3. 항목별

| 항목 | 의견 |
|---|---|
| CF12-9 표(스키마·pydantic) | 수용 |
| CF12-9 표(프롬프트) | **수정**: 위 표의 행 전부로 넓힌다 |
| CF12-9 표(문구·매핑) | 수용. 단 문구 키 본문에서 "입력 수정"을 빼면 **목표 종류를 어디서 바꾸는지 안내가 없다.** "목표 종류는 여기서 바꿀 수 없어요"로 끝낸다 |
| CF12-4 k·l·m·n | 수용. **`drop_carried_conditions`(agent.py:204-230)와 `calc.py:_select_side`를 표에 추가**(초안에 없음) |

---

## 2. 단위 구멍 (초안 핵심 발견 5)

### 2-1. 초안 예시 정정

초안은 "'2,500만원'을 `2500`으로 추출하면 `goalAmount min 10000`을 통과한다"고 적었다. **`2500 < 10000`이라 `OUT_OF_RANGE`로 걸린다.** 서버가 막는다는 뜻이므로 오류 경로(`CLARIFY` + `minDisplay`)를 탄다. 실제로 통과하는 값은 다음이다.

| 발화 | 모델이 잘못 낸 값 | 서버 결과 |
|---|---|---|
| 목표 1억 | `10000`(만 단위 그대로) | **통과**, 목표 1만원 |
| 목표 1억 5천만원 | `15000` | **통과**, 목표 1.5만원(실제 1억 5천만) |
| 목표 2,500만원 | `250000000`(×10 과환산) | **통과**, 2.5억 |
| 목표 2,500만원 | `2500` | 걸림(`OUT_OF_RANGE`) |
| 보유 자산 3,000만원 | `3000` | **통과**(min 0) |
| 보유 자산 3,000만원 | `300000000` | **통과**(max 1e10) |

즉 구멍은 (a) 목표가 **1억 이상**일 때 만 단위를 그대로 쓴 경우, (b) **×10·×100 과환산**, (c) **보유 자산 전 구간**이다. 사회초년생의 흔한 목표가 1억이므로 (a)는 흔하다. 목표가 1만원~1억 범위라 비교 카드에 "목표 약 1만원"이 나오면 사용자는 알아챌 수 있지만, 보유 자산 3,000원은 "약 0만원"으로 보여 알아채기 어렵다.

### 2-2. 소비자 안: 세 겹

| 겹 | 내용 | 비용 |
|---|---|---|
| (a) 프롬프트 | `## 숫자`에 두 줄: "만·억 단위는 원으로 바꿔 인자에 넣는다. 단위가 없거나 모호한 금액은 계산하지 말고 단위를 되묻는다(CLARIFY)." "금액의 역할은 말로 정한다: 목표·모으려는 → 목표 금액, 이미·지금·모아둔·가진 → 보유 자산, 매달·월 → 월 저축액. 역할 단어가 없으면 되묻는다." | 매우 작음. 단 모델 준수는 보장이 아니다 |
| (b) **추출 후 결정적 검사(권고)** | 새 함수 `check_amount_units(text, changes)`를 `drop_carried_conditions` 옆에 둔다. 발화에서 **숫자 + 단위 토큰**(`N억`, `N천만원`, `N만원`, `N원`, 쉼표 금액, `1억 5천만원` 조합)을 정규식으로 파싱해 값 후보 집합을 만든다. 추출된 `goal_amount`·`held_assets`·`monthly_saving_amount`가 **후보에 없으면 Spring을 부르지 않고 `turn.validation_failed`처럼 `CLARIFY`로 끝낸다.** 발화에 숫자 토큰이 없으면(한글 수사 "이천오백만원") 검사를 건너뛰고 (c)에 맡긴다 | 중간(정규식 + 표 테스트 약 15행). **이것은 계산이 아니라 "모델이 낸 값이 발화와 일치하는지" 대조**라 FR-AI-02에 어긋나지 않는다. 이미 `number_check.py`가 같은 성격의 대조를 한다 |
| (c) 확인 문장 + 카드 | 비교 결과의 목표·보유 금액 `display`를 **카드와 답변에 그대로** 보여 준다. 적용은 D-022대로 버튼을 눌러야 하므로 **카드가 두 번째 확인**이다. 카드에 변경된 두 금액이 `changedKeys`로 강조되어야 한다 | 프론트 카드 변경이 어차피 필요(3절) |

(b)를 넣을 수 없다면 `HELD_ASSETS`는 이번에 열지 않기를 권한다(2-2 축소안). 목표 금액은 (a)+(c)만으로도 위험이 눈에 보이는 범위라 받을 수 있다.

**하지 않는 것**: 값 자동 보정(초안 4-2 마지막 문단과 같음). 서버 쪽 "목표가 너무 작다" 경고 규칙도 두지 않는다. 범위 검증은 Spring 한 곳(D-033)이고, 비정상 값 판정은 규칙을 새로 만드는 일이라 3주 범위 밖이다.

### 2-3. 비율·기간과의 혼동

- 비율(0~100)과 기간(1~360)은 범위가 좁아 단위를 틀리면 **서버가 거의 항상 잡는다.** 새로 생기는 위험이 아니다.
- 새로 생기는 위험은 **금액 세 개(목표·보유·월 저축액) 사이의 역할 혼동**이다. "3,000만원이요"는 세 필드 모두 문법적으로 맞다. 월 저축액에 들어가면 max 1천만원에서 걸리지만, "300만원 모으려면"이 월 저축액 300만원(범위 안)이 되면 **조용히 틀린다.** 해결은 2-2의 (a) 역할 규칙 + 역할 단어가 없으면 CLARIFY.
- `_PERIOD`(`agent.py:187` `년|개월|기간|\d\s*달`)가 "목표 10년 뒤 1억"에서 기한으로도 잡히는 것은 현재 동작이며 문제없다(숫자 수가 조건 수보다 많으면 통과).

| 항목 | 의견 |
|---|---|
| X-4-1 | **수정**: "범위 검증이 잡는다"는 전제가 틀렸다. 위 2-1 표로 정정 |
| X-4-2 | **수정**: 프롬프트 한 줄 + fake 테스트에 더해 (b) 추출 후 검사를 권고. fake로 "1억 → 10000"을 모델이 낸 경우를 고정 JSON으로 만들어 CLARIFY가 되는지 본다 |
| "단위 자동 보정 안 함" | 수용 |

---

## 3. X-3 초과 판정과 비교 카드

현황: 프론트에는 대화 비교 카드(#54)가 **아직 없다**(`frontend/src/features/chat/ChatWindow.tsx`에 diff·changed 렌더링 없음, 초과는 `:112` `settledStatus === "ALREADY_EXCEEDED"` 고정 문장뿐). 카드를 새로 만드는 중이라 한쪽 초과 카드를 **처음부터** 설계할 수 있어 지금이 가장 싸다.

### X-3-1 (초과 계획에서 목표 상향) — **3-1 수용, 3-2 거절**

- **3-2 거절 이유**: ai-server가 `RECALC_RESULT`를 내려면 `calc_run_id`가 있어야 한다(`agent.py:546-561` `assemble`, DB CHECK `ck_cm_recalc`). 계산 없는 "확인 → 적용"은 `ANSWER`로는 `condition_changes`를 저장할 수 없고(F-5는 `RECALC_RESULT` 메시지에만 적용, 검사 3·6·7), 새 메시지 타입·CHECK 개정이 필요하다. D-041("적용 버튼은 가장 최근 비교 결과에만")과도 맞지 않는다. 초안이 "싸다"고 한 것은 Spring 쪽뿐이고 B팀에는 더 비싸다.
- **3-1 수용 조건**
  1. 응답의 `current`/`changed` 각각에 `status`가 있고, `ALREADY_EXCEEDED`면 `scenarios: []`. 소비자는 **`status`만 보고** 칸을 고른다(문자열 해석 없음).
  2. 양쪽이 모두 `CALCULATED`일 때만 `diff`를 본다. 한쪽이 `ALREADY_EXCEEDED`면 `diff.byScenario: []`(초안과 같음). 별도 `comparable` 플래그는 두지 않는다(status 두 개로 결정됨).
  3. 초과 칸은 `result.alreadyExceeded`(`goalAmount`·`heldAssets` 자리, 이미 문구표에 있음, `frontend/src/shared/copy/copy.ts:30`)를 쓴다. 이를 위해 Spring이 **초과인 쪽에도** `*.goalAmount`·`*.heldAssets` display를 내려야 한다. 초안은 "초과 금액은 말하지 않는다"만 적고 어떤 display를 주는지가 없다.
  4. 초과 계획에서 목표를 올렸는데 **여전히 초과**면 409 고정 문장이 나간다(D-071). 사용자는 "바꿨는데 왜 또 초과?"가 되므로 문구표 `chat.alreadyExceeded`가 "그 값으로도 이미 넘었어요"처럼 읽혀야 한다. 문구 개정(#18) 시 확인할 것.
  5. ai-server: `_select_for_model`이 `status`를 통과(1절). 프롬프트 규칙 9 확장: 한쪽이 초과면 그쪽은 `result.alreadyExceeded` 문장만 인용하고 비교 문장을 만들지 않는다.
- 소비자 비용: 프론트 카드 분기 1개, ai-server 통과 코드 몇 줄 + 프롬프트 + 테스트 2개. 기존 `calc` 응답 `current`가 항상 `CALCULATED`라는 불변식에 기대는 코드는 ai-server·프론트에 없는 것으로 확인했다(`_check_display`는 빈 목록을 통과).

### X-3-4 (`changed`가 초과) — **수용**

- 적용 버튼 활성에 동의한다. 이후는 이미 구현되어 있다: `ChatWindow.tsx:112`가 `settledStatus`로 초과 문장을 켜고, `ResultPage.tsx`도 초과를 처리하며 mock(`put-plan.200-exceeded.json`, `get-plan.seq-exceeded-toggle.json`)이 있다. D-072의 `revision` 구독 한 곳으로 풀린다.
- 단 카드는 "바뀐 조건" 칸에 **"이 조건으로 적용하면 이미 목표를 넘은 상태가 돼요"** 류 한 줄이 필요하다(결과 화면이 초과 안내로 바뀌는 것을 예고). `chat.alreadyExceeded`만 쓰면 "이미 넘었어요"가 사용자가 방금 말한 의도의 확인으로 읽힌다. 새 키가 필요하면 `chat.changedAlreadyExceeded`(이름은 #18에서).

### X-3-6/7 (목표 금액이 바뀐 비교) — **3-6 수정 수용**

- 그릴 수 있다: 카드에 양쪽 `goalAmount` display 두 줄 + 각 시나리오의 `isAchieved`/`gapToGoal`(각자 자기 목표 기준, 이미 `<side>.<S>.gapToGoal`로 존재).
- **display 키 이름을 C2-6 규칙에 맞춘다.** 초안은 `display["current.goalAmount"]`라 쓰지만 C2-6의 조건 키는 `conditions.<side>.…`, 최상위 `goalAmount`는 접두어 없는 단일 키다. 제안: `conditions.current.goalAmount`, `conditions.changed.goalAmount`, `conditions.current.heldAssets`, `conditions.changed.heldAssets`를 **`conditionChanges`에 해당 키가 있을 때만** 만든다. 최상위 `goalAmount` 단일 키는 그대로 두되 목표가 바뀐 비교에서는 **프롬프트가 인용하지 않게** 한다(위 1절 `:30-31`).
- `achievementChange`는 `null`로 숨기지 말고(3-7 반대) **그대로 쓰되 카드가 주의 문구를 붙인다.** 이유: 이 필드가 주 사용 사례("목표를 낮추면 달성돼요")의 핵심 정보이고, 사용자가 목표를 직접 말했으므로 사실이다. 오해 위험은 "조건이 좋아졌다"로 읽히는 것뿐이다.
- 주의 문구 `chat.goalAmountChangedNote`는 **모델이 아니라 코드가 붙인다**(D-073 `tax.note`와 같은 방식): `conditionChanges`에 `goal_amount`가 있으면 ai-server가 문구를 덧붙이고, 프론트 카드는 F-4 `changedKeys`에 `goalAmount`가 있으면 같은 문구 키를 정적으로 보여 준다. 자리: `{currentGoal}`, `{changedGoal}`(display 문자열). 본문 예: "목표 금액이 {currentGoal}에서 {changedGoal}으로 바뀌어, 달성 여부는 각각 자기 목표 기준이에요."
- `diff`에 `gapToGoalDelta`는 여전히 두지 않는다(C2-5가 이유를 적음). 목표가 바뀌면 `afterTaxAssetDelta`와 달라지는데 모델이 직접 뺄 수 있으므로 **오히려 이 규칙 문장("이전 값을 빼서 새 숫자를 만들지 않는다")을 프롬프트에 목표 변경 비교용으로 한 번 더 못 박는다.**
- 새로 필요한 문구표 키(소비자 기준): `condition.goalAmount`, `condition.heldAssets`(조건 이름, F-4 행 레이블·범위 밖 안내), `chat.goalAmountChangedNote`, `chat.heldAssetsBasis`, `chat.changedAlreadyExceeded`, 개정 3건(`chat.unchangeableCondition`, `chat.alreadyExceeded`, `result.alreadyExceeded`). 프론트 `features/chat/copy.ts:5`에도 `alreadyExceeded` 본문이 복제되어 있다. 문구표와 함께 갱신해야 한다.

### FR-AI-01·D-071·D-072·#52와의 관계

- D-071은 초안 말대로 **부분 대체**한다("목표·보유를 바꾸지 않는 변경 또는 바꿔도 여전히 초과면 고정 문장"으로 한정). FR-AI-01 수용 기준 문장을 같이 고친다.
- D-072(초과 안내 문장은 `revision`마다 재판단)는 **변경 없이 그대로 동작**한다. 대화 적용으로 초과가 풀리면 문장이 사라지고 F-3 호출이 살아난다.
- 막다른 길 복원은 3-1 하나로 풀린다. 단 **ChatWindow 고정 문장(D-063)이 "대화로 목표 금액을 바꿔 보세요"를 안내**하는 것이 선행 조건이다(그래야 사용자가 대화로 들어온다). 이 문장은 `chat.alreadyExceeded`이며 개정 대상이다.

---

## 4. X-2 `HELD_ASSETS` vs D-035

- 초안 2-1(코드가 문장을 덧붙임) **방식은 수용**. 다만 Spring이 `display`에 **문구 키**를 내려보낼 필요는 없다. 문구는 ai-server가 이미 `load_copy()`로 읽는다(`agent.py:570`). 필요한 것은 자리 값 `{calcStartMonth}` 하나이므로 **recalculate 응답 `display`에 `calcStartMonth`(문자열)만 추가**하면 된다. 키가 없으면 문장을 붙이지 않고 로그만 남긴다(fail-open이 아니라 "문장 생략"이 안전: 틀린 월을 말하는 것보다 낫다).
- **조건부로 붙인다.** `conditionChanges`에 `held_assets`가 있을 때만(매번 붙이면 4개 조건 변경 답변까지 길어지고 경고가 소음이 된다). 위치는 **답변 맨 끝**(숫자 인용·`tax.note` 뒤).
- 사용자가 헷갈릴 지점
  1. "시작월"이 낯선 용어다. D-035 문구("{시작월} 당시 쓸 수 있던 돈")를 그대로 재사용해 용어를 맞춘다.
  2. 문장이 숫자가 **이미 반영된 뒤에** 나온다. 사용자는 "그럼 이 비교는 틀린 거야?"가 된다. 문장이 "이 값은 시작월 당시 기준이라 그 뒤 납입분은 월 저축액으로 이미 계산돼요" 같이 **방향을 알려** 줘야 한다(단순 경고가 아니라 사용자가 값을 다시 말하도록).
  3. 카드에서도 같은 문구가 있어야 한다. 사용자는 답변 문장을 읽지 않고 카드의 적용 버튼만 누를 수 있다. F-4 `changedKeys`에 `heldAssets`가 있으면 카드 안에 같은 문구 키를 정적으로 표시한다.
  4. `chat.heldAssetsBasis`의 `{calcStartMonth}`(`2026년 11월`)는 `check_numbers` 토큰이라 **검사 뒤에 붙여야** 한다(`with_tax_note`와 같은 위치). 앞에 붙이면 `NUMBER_MISMATCH`.
- **권고**: 단위 구멍(2절) 때문에 보유 자산은 위험이 가장 크다. (b) 추출 후 검사가 3주 안에 서지 않으면 **X-2는 2-2(목표 금액만)로 줄인다.** 막다른 길(FR-RES-01)은 목표 금액만으로 풀린다. 다만 '입력 수정' 버튼 제거는 보유 자산을 바꿀 곳이 사라지는 일이므로(D-035가 "입력 수정으로만") **버튼 제거의 선행 조건으로 HELD_ASSETS를 명시**한다.

---

## 5. X-1 `max-fields`

- 확인한 것: `TOO_MANY_CHANGES`는 `backend/.../plan/FieldError.java:23`의 코드 정의와 ALTERNATIVE 테스트(`docs/superpowers/plans/…:278`)에만 있다. **프론트에는 없고**(전체 검색 결과 0건), **ai-server에도 없다.** 422 `VALIDATION_FAILED`의 `errors[].reason`으로 오면 ai-server는 `validation_failed → CLARIFY`로 처리하고(`agent.py:352-363`) 모델은 `min`·`max`가 없는 오류를 받아 "허용 범위를 벗어났어요"라고만 말한다. 문구·화면이 없으므로 "범위가 아닌 이유"를 사용자에게 전할 수 없다.
- 의견: **1-1(6) 수용.** 4(1-2)는 처음으로 이 분기를 활성화해 문구·분기·테스트를 새로 만들어야 하므로 **반대**한다. 0(1-3)도 가드 상실이라 반대에 동의한다.
- 조건: 6은 사실상 상한이 없다. 대화는 한 발화에서 조건 대부분을 바꾸는 일이 드물고, 프롬프트 규칙(이번 발화에서 말한 것만 인자로)이 개수를 작게 유지한다. 나중에 값을 줄이게 되면 그때 `TOO_MANY_CHANGES` → CLARIFY 문구를 소비자 쪽에서 함께 만든다(지금은 만들지 않는다).

---

## 6. F-4 재계산·F-5 적용 (`chat_message.condition_changes`)

| 점검 | 결과 |
|---|---|
| camelCase 저장(원칙 9, C12b-14) | 맵이 **4키 고정**이라(#41) `goal_amount → goalAmount`, `held_assets → heldAssets` 두 줄 추가가 필요하다. **맵에 없는 키가 오면 어떻게 되는지 계약에 없다.** 고정 맵이 모르는 키를 버리면 저장값에서 목표가 사라져 F-4·F-5가 AI 문장과 다른 계산을 한다(`foreign key` 아니라 **조용한 불일치**). "모르는 키는 저장 실패(500/FAILED)"로 명시하고 테스트 1개를 둔다 |
| 옛 메시지 호환 | 옛 메시지는 4키의 부분집합이라 영향 없다. `changedKeys`도 저장 키 그대로라 문제없다. 새 필드는 없는 것이 정상 |
| **배포 순서** | F-4는 "허용 4키 밖의 키는 `500 INTERNAL_ERROR`"(`frontend-api-chat.md:219` 근처). ai-server를 6키로 먼저 배포하면 `/internal/calc`가 `FIELD_NOT_CHANGEABLE`(안전, 고정 문장)이지만, Spring이 계산은 되고 저장·F-4가 4키면 카드가 500이다. **순서: Spring(T-1~T-5·T-11) → ai-server(T-8·T-9) → 프론트(T-12).** ai-server를 마지막에 켜면 중간 상태가 모두 fail-closed다 |
| F-4 `conditions` 행 | "고정 4키 순서"(`C12b-6`)로 행을 그린다. 6행(목표·보유 추가)이 되면 **프론트 행 레이블·순서 고정 목록과 목 JSON이 같이 바뀐다.** `changedKeys` 집합으로 강조하는 방식은 그대로 쓴다 |
| F-4 각 칸 `status` | `current`/`changed`가 `ALREADY_EXCEEDED`일 수 있으므로 F-4 응답 모양(C2-4 `CalcResultView`)에도 `status`가 있어야 한다. 프론트 타입(`features/chat/types.ts`)에 필드를 더한다 |
| `STALE_COMPARISON` | 변화 없음. 기준 버전 ≠ 현재면 거절이라 "다른 버전의 목표 위에 병합"되는 일이 없다. **목표·보유를 바꾸는 적용은 `PlanService.merge`(`:205-206`) 배선(T-4)이 빠지면 "카드는 바뀌는데 적용하면 안 바뀐다"**(초안과 같은 위험, 동의) |
| `PLAN_CHANGED` | 변화 없음. 적용 성공 후 `revision` 증가 → 모든 적용 버튼 비활성(D-069) → 초과가 되면 D-072가 켜진다 |
| 되돌리기(D-068) | 직전 버전 행 복사라 목표·보유도 그대로 복원된다. 별도 처리 없음 |
| 저장된 값의 범위 | F-4는 범위 검사를 하지 않는다(타입 변환만). 지금은 ai-server가 Spring의 422를 받은 값만 `condition_changes`에 담는다(`agent.py:386-387`)이므로 범위 밖 값은 저장되지 않는다. 새 두 키도 같다 |

| 항목 | 의견 |
|---|---|
| CF12-10-2 C12b-14(6키 고정 맵) | 수용. 위 "모르는 키" 동작을 문서에 추가 |
| CF12-10-2 C12b-6 | 수용. F-4 행 6개·`status` 추가를 같이 적는다 |
| T-11 | 수용, 순서는 위 표(ai-server 마지막) |
| CF12-10-2 `:698` "ConditionChanges 7키 → #21 4키로 축소" | 초안대로 "이미 4키로 축소됨" 정정 수용 |

---

## 7. FR-AI-02: 새로 생기는 "AI가 계산하게 되는" 구멍

| # | 구멍 | 막는 방법 |
|---|---|---|
| 1 | **목표 변경 비교에서 모델이 두 목표를 뺀다**("목표가 N만원 줄었다") 또는 두 `gapToGoal`을 뺀다 | 계약: `diff`에 목표 차이 키를 두지 않는다(C2-5 유지)는 대신 **프롬프트로 금지**하고, 말하고 싶으면 양쪽 display만 인용. "상대 표현 → 절대값 되묻기"(D-059)를 목표·보유에도 적용. 문장에서 "N만원 줄이면"은 `CLARIFY` |
| 2 | **단위 환산**(만원·억 → 원) | 모델이 하는 환산은 이미 월 저축액에서 허용돼 있다(`agent.py:87`). 새 위험은 아니지만 오류 영향이 커졌으므로 2-2 (b)로 **대조**한다. 값을 코드가 고쳐 주지는 않는다 |
| 3 | **보유 자산을 "모은 총액"에서 시작월 기준으로 모델이 바꿔 말한다**("지금까지 모은 3,000만원에서 납입분을 빼면…") | `chat.heldAssetsBasis`는 코드가 붙인다. 프롬프트에 "보유 자산 값을 가공하지 않는다" 한 줄 |
| 4 | 목표 상향으로 초과를 벗어난 카드에서 **필요 월 저축액·초과 금액**을 모델이 계산 | 기존 규칙(초과 금액은 말하지 않음, `requiredMonthlySaving` 미노출)이 유지되는지 테스트로 고정 |
| 5 | `drop_carried_conditions`가 값을 **지우는** 것(1절) | 계산이 아니라 누락이지만, 사용자가 말한 값이 아닌 다른 값(월 저축액으로 오인)이 계산되면 결과적으로 같은 사고다. 1절의 정규식 확장으로 막는다 |

계산 값을 Spring이 아닌 곳에서 만드는 요구는 **없다.** 소비자가 새로 필요로 하는 계산 값도 없다(양쪽 `goalAmount`/`heldAssets` 표시 문자열과 `status`로 충분).

---

## 8. 작업량(소비자 쪽, 3주 해커톤)과 범위 권고

단위는 인일(1인 하루), 테스트 포함 추정.

| 작업 | 추정 |
|---|---|
| ai-server: 스키마·도구·`ConditionChanges` 6키 + 프롬프트 개정(1절 표) + 기존 테스트 대상 교체 | 1.5 |
| ai-server: `drop_carried_conditions` 확장 + 표 테스트 | 1 |
| ai-server: `_select_side`에 `status` 통과, 한쪽 초과 프롬프트·테스트 | 0.5 |
| ai-server: 단위 대조 `check_amount_units`(2-2 b) + 표 테스트 | 1 |
| ai-server: `chat.goalAmountChangedNote`·`chat.heldAssetsBasis` 덧붙이기 + 테스트 | 0.5 |
| chat 리스너 6키 맵(T-11) + "모르는 키" 테스트 | 0.5 |
| 프론트: 카드 한쪽 초과 분기, 목표·보유 행, 주의 문구, 목 JSON | 1.5~2 |
| 문구표(#18) 개정·신규 6~8키, 프론트 `copy.ts` 동기 | 0.5 |
| **소계(B팀)** | **약 7~8인일** (Spring A팀 몫: 3-1 재설계 2~3 + 배선 2, 별도) |

권고(작은 쪽부터):

1. **1단계: CHAT 경로만, `GOAL_AMOUNT`만.** 소비자 약 4.5인일(HELD 관련 단위 대조 일부·`heldAssetsBasis`·행 하나 제외). 막다른 길을 풀고 위험이 가장 작다(2절 (a)+(c)로 충분). 3-1·3-4·3-6은 이 단계에 포함.
2. **2단계: `HELD_ASSETS`.** (b) 단위 대조와 `chat.heldAssetsBasis`가 갖춰질 때. D-035와 D-040 대체 결정을 같이 기록.
3. **COMPARE 경로는 미룬다.** 초안 C-6 질문에 대한 답: FR-CMP-02가 Should이고 프론트 비교 영역이 아직 없으므로 CHAT만 열어도 제품 방향("대화로만 바꾼다")에 지장이 없다. COMPARE는 Should를 되살릴 때 6필드로 함께 연다. 단 `ConditionOverride`는 COMPARE도 같은 타입이라 Spring 쪽 비용은 거의 같다(A팀이 판단).
4. '입력 수정' 버튼 제거(C-5)는 **HELD까지 끝난 뒤**에만. 이 변경이 먼저라는 전제는 맞다.

---

## 초안 항목별 판정 (요약)

| 항목 | 판정 | 요지 |
|---|---|---|
| CF12-1·2·3 (배경·범위·D-040 대체) | 수용 | D-071·D-035도 같이 개정 대상. 범위 2필드 + CHAT 우선을 권고 |
| CF12-4 표 | **수정** | `drop_carried_conditions`, `calc.py _select_side`(status), 프롬프트 `:23-27`·`:30-31`을 추가 |
| CF12-5 yml diff | 수용(CHAT만 먼저면 COMPARE 줄 보류) | `fields:` 불변 확인 |
| X-1 | 수용(1-1, 6) | 소비자 쪽 화면·문구 없음 확인 |
| X-2 | 수정 수용 | 방식은 코드가 붙이는 것. Spring은 `calcStartMonth` display만 추가. 조건부 + 카드 병기. 위험이 커서 2단계로 |
| X-3-1 | 3-1 수용, 3-2 거절 | 3-2는 RECALC_RESULT·DB CHECK·D-041과 충돌 |
| X-3-4 | 수용 | 카드에 "적용하면 초과 상태" 한 줄 |
| X-3-6 | 수정 수용 | display 키 이름을 C2-6 규칙으로, 주의 문구는 코드가 덧붙임, 3-7 반대 |
| X-4-1 | 수정 | 예시가 틀렸고 실제 구멍은 2-1 표 |
| X-4-2 | 수정 | 프롬프트 + **추출 후 대조** 권고 |
| CF12-10 계약 문서 표 | 수용 | `internal-calc` C2-6 display 키(위 이름), C2-4 status, F-4 `conditions` 6행, A-4·A-5 fixture, ai-server `test_calc_client` fixture |
| CF12-12 후속 표 | 수정 | T-8·T-9에 `drop_carried_conditions`·`calc.py` 추가, T-11 "모르는 키" 동작, 배포 순서 명시 |

## 소비자 쪽에서 꼭 필요한 것

- `current`·`changed` 각각의 **`status`** (F-4·`/internal/calc` 모두), 초과 칸 `scenarios: []`. 소비자는 status로 칸을 고른다.
- 목표·보유가 `conditionChanges`에 있을 때 **양쪽 표시 문자열**: `conditions.current.goalAmount`, `conditions.changed.goalAmount`, `conditions.current.heldAssets`, `conditions.changed.heldAssets` (초과 칸에도).
- recalculate 응답 `display`에 **`calcStartMonth`** (보유 자산 변경 시).
- 문구표: `condition.goalAmount`, `condition.heldAssets`, `chat.goalAmountChangedNote`, `chat.heldAssetsBasis`, `chat.changedAlreadyExceeded` 신규, `chat.unchangeableCondition`·`chat.alreadyExceeded`·`result.alreadyExceeded` 본문 개정.
- ai-server: `drop_carried_conditions` 확장(없으면 값이 조용히 지워짐), `status` 통과, 단위 대조(HELD 열기 전 필수).
- 기존 고정 문장 테스트는 삭제하지 말고 목표 종류·기존 납입액으로 대상을 바꿔 유지.
- 배포 순서 Spring → ai-server → 프론트.

## 빼도 되는 것

- 별도 `comparable` 플래그(status 두 개로 충분).
- `diff.byScenario[].achievementChange`를 `null`로 숨기는 안(3-7).
- `chat.heldAssetsBasis`를 **Spring display의 문구 키**로 내리는 것(ai-server가 이미 문구표를 읽는다. 자리 값 `calcStartMonth`만 받으면 된다).
- 3-2 "확인 → 바로 적용" 흐름 전체.
- `max-fields` 4·0 안과 `TOO_MANY_CHANGES` 문구·화면(6이면 발생하지 않음).
- 1단계에서 COMPARE 경로 6필드, 목표 종류, 자동 단위 보정, 서버 쪽 비정상 값 경고 규칙.

---

## 수용 조건 (요약)

이 개정을 수용하는 조건. 하나라도 빠지면 "통과하는데 틀린 값" 또는 "막다른 길"이 남는다.

1. **범위**: 1단계는 CHAT + `GOAL_AMOUNT`. `HELD_ASSETS`는 단위 대조(2-2 b)와 `chat.heldAssetsBasis`가 서면 2단계. COMPARE는 보류.
2. **ai-server**: `ConditionChanges`·도구 스키마·프롬프트(`:7-8, 18, 21-27, 30-31, 53-54, 70, 75`)를 함께 개정하고, **`drop_carried_conditions`가 새 키를 지우지 않으며 월 저축액으로 오인하지 않는다**는 표 테스트를 추가한다.
3. **고정 문장 테스트**는 삭제하지 않고 목표 종류·기존 납입액으로 대상을 교체한다(`ANSWER` ≠ `OUT_OF_SCOPE` 보호 유지). 문구표 본문과 테스트를 같은 PR에서 바꾼다.
4. **단위**: 초안 4-1의 "범위 검증이 잡는다"를 정정(2-1 표)하고, 목표 ≥1억 만 단위 사고·×10 과환산·보유 자산을 fake 모델 고정 JSON 테스트로 고정한다. 값 자동 보정은 하지 않는다.
5. **초과**: X-3-1은 3-1로, `status` 필드로 칸을 고르고 `diff`는 한쪽이 초과면 비운다. 3-2는 채택하지 않는다. X-3-4 적용 버튼은 활성, 카드에 "적용하면 초과 상태" 한 줄.
6. **목표 변경 비교**: 양쪽 목표 display, `achievementChange`는 유지, 주의 문구는 코드가 붙이고 프롬프트의 "goalAmount는 같은 값" 문장을 고친다. 모델은 두 목표·두 `gapToGoal`을 빼지 않는다.
7. **보유 자산(2단계)**: 시작월 문구는 `held_assets`가 있을 때만, 답변 끝과 카드 양쪽에, `check_numbers` 뒤에 붙인다. Spring은 `calcStartMonth` display만 추가한다.
8. **max-fields**는 6. `TOO_MANY_CHANGES` 소비자 처리는 이번에 만들지 않는다.
9. **저장·적용**: chat 리스너 6키 맵 + 모르는 키는 저장 실패, F-4 `conditions` 6행·`status`, 배포 순서 Spring → ai-server → 프론트. `PlanService.merge`·`toOverride` 배선 없이는 ai-server를 켜지 않는다.
10. 문구표 신규·개정 키가 #18에서 확정되고 프론트 `copy.ts`와 동기화된다. D-040·D-071 대체, D-035 확장은 새 D-번호로 기록한다.
