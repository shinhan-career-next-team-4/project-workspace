> **현재 최신 본문: `internal-calc-v3.md`**

# `/internal/calc` 계약 합의안 (moeun #10)

> 작성: tech-architect, 2026-11-16. `/negotiate-contract` 4단계(재검토 반영) 마무리, 5단계(사람에게 넘기기) 준비.
> - 계약 본문: `internal-calc-v3.md` (쟁점은 본문에 `[쟁점 X-n]`과 임시 기본값으로 표시)
> - 입력: `internal-calc-v1.md`, `internal-calc-review-v1-provider.md`(A팀), `internal-calc-review-v1-consumer.md`(B팀), `internal-calc-v2.md`, `internal-calc-review-v2-provider.md`(A팀 재검토)
> - **에이전트는 결정하지 않았다.** 아래 "사람이 정할 쟁점" 3개만 답해 주면 v3을 최종본으로 확정할 수 있다.

## 합의된 것 (그대로 구현 가능) — 30항목

| # | 항목 | 내용 | 근거 |
|---|---|---|---|
| 1 | 원칙-1 | 숫자·차이·표시 문자열은 Spring만 만든다(표시 문자열은 calc 모듈만). 모델은 `display` 문자열만 인용하고 raw 숫자는 판단용 | 양쪽 수용, 소비자 보강 |
| 2 | 원칙-2 | 범위 검증은 Spring `ConditionValidator` 한 곳(D-033). ai-server는 타입만 맞추고 범위 수치를 두지 않음 | 양쪽 수용 |
| 3 | 원칙-3 | 기준은 현재 계획, 누적하지 않음(D-041) | 양쪽 수용 |
| 4 | 원칙-4·5·7 | camelCase, 원·개월·퍼센트 숫자, 새 라이브러리 없음, 모르는 키 무시 | 양쪽 수용 |
| 5 | 원칙-6 | 전역 `non_null` 설정을 켜지 않음(null 키 유지) | 제공자 제안 |
| 6 | C2-1 | `POST /internal/calc`, `X-Internal-Api-Key`, `/internal/**` 전용 필터 체인, 401 본문은 필터가 직접 씀(`instance` 없을 수 있음) | 제공자 보강 |
| 7 | C2-2 허용 키 | 4개(월 저축액·비중·적금 금리·기한)만. 허용 밖 키가 섞이면 요청 전체 거절. `null` 값은 "바꾸지 않음" | 양쪽 수용 |
| 8 | C2-2 받는 방식 | `Map<String, JsonNode>`로 받고 검사 순서 0~9를 고정(허용 밖 키 → 숫자 아님 → 빈 변경 → 범위 → 계획 없음 → 이미 초과) | 제공자 제안 |
| 9 | C2-2 기준 시나리오 | Spring은 `plan.baseline_scenario`를 읽는다. 요청의 `baselineScenario`는 선택·무시(ai-server 코드 변경 없음), 다음 버전에서 삭제 | 제공자 제안, 소비자 영향 없음 |
| 10 | C2-2 빈 변경 | 바꿀 값이 없으면 `422 VALIDATION_FAILED`, `reason=REQUIRED` | 양쪽 수용 |
| 11 | C2-3 최상위 | `calcRunId`, `conditions`, `current`, `changed`, `diff`, `display`. `basePlanVersionId`·`baselineScenario`·`conditionChanges` 에코는 뺌 | 소비자 제안, 제공자 수용(재검토) |
| 12 | C2-3 구현 위치 | 공개 타입 `calc.CalcComparison`, `monthlyPoints` 제거와 `display`는 웹 DTO에서만 | 제공자 제안 |
| 13 | C2-4 | 직렬화 표기 표, `monthlyPoints` 키 없음(응답 전용 DTO), 시나리오는 항상 GOOD·AVG·BAD 순서, `BigDecimal` 자릿수 비고정 | 양쪽 수용, 제공자 보강 |
| 14 | C2-5 | `diff.baselineScenario`(포인터) + `byScenario[]`(`afterTaxAssetDelta`, `principalDelta`, `afterTaxGainDelta`, `achievementChange`). 공통 시나리오만. `gapToGoalDelta`·달성 시점 차이는 두지 않음 | 소비자 제안, 제공자 수용(재검토) |
| 15 | C2-6 키 규칙 | 평평한 맵, 응답에 있는 시나리오만. `goalAmount`, `targetMonth`, `afterTaxGain`, `goalReachMonth`(null이면 키 없음) 추가. 1억 이상도 `약 12,345만원`. 델타는 따로 반올림하므로 display끼리 빼 보이지 않음. `annualReturnPct`는 말하지 않음 | 소비자 제안, 제공자 수용(재검토, 맵 빌더 약 0.5일) (**문자열 형식은 X-1**) |
| 16 | C2-6 전환기 | #28(Formatter) 머지 전에는 `display: {}` 허용. ai-server는 display가 비면 비교를 내지 않고 `CALC_DISPLAY_MISSING`으로 실패 | 제공자 (a)안 + 소비자 안전 조건. 양쪽이 같은 방향이라 합의로 처리 |
| 17 | C2-7 | 성공 1건당 `calc_run(CHAT)` 1행, current·changed 같은 버전, 실패하면 기록 안 함 | 양쪽 수용 (**고아 행 허용 여부는 X-3**) |
| 18 | C2-8 | 기준은 `plan.current_version_id`, 시작월은 계획 값(D-013), 비중을 바꾸지 않은 요청은 현재 해석된 비중을 고정(방어 규칙) | 양쪽 수용, 제공자 보강 |
| 19 | C3-1 | `ProblemDetail` + `code` + `errors`(걸린 필드 모두). `config`의 `@RestControllerAdvice` 하나, 모듈별 예외, `common` 모듈 없음. `minDisplay`·`maxDisplay` 추가(만드는 위치는 #26). `title`은 코드별 고정 상수, `copyKey`는 선택. Bean Validation으로 CP-02 검증하지 않음 | 양쪽 제안 합침 |
| 20 | C3-2 코드 | 7개 코드와 HTTP 상태(`ALREADY_EXCEEDED`는 409, 500 `detail`에 내부 메시지 없음) | 양쪽 수용 |
| 21 | C3-2 ai-server 분기 | `VALIDATION_FAILED`만 모델에 `{code, errors}`로 넘겨 되묻기. `FIELD_NOT_CHANGEABLE`·`NO_PLAN`·`ALREADY_EXCEEDED`는 코드 분기 + 문구표 고정 문장. 범위 오류 뒤 같은 요청 안에서 재계산 금지(코드 가드) | 소비자 제안, 제공자 이견 없음 (**FIELD_NOT_CHANGEABLE의 messageType은 X-2**) |
| 22 | C3-3 | `backend/src/main/resources/config/rules.yml`(Spring 전용, plan `@ConfigurationProperties`), 임시 수치 4행 | 제공자 제안, 소비자 수용 |
| 23 | C3-4 | 200은 추린 결과만 모델에, 422·409는 `CalcRejected(code, errors)`, 400·401·5xx·타임아웃은 `AgentError` | 양쪽 수용 |
| 24 | C3-5 | 같은 오류 형식을 프론트 API에도. 프론트 401(JWT)은 #12에서 형식을 맞춤 | 양쪽 수용, 제공자 메모 |
| 25 | 부록 A | 줄임표 없는 성공 응답 1개와 오류 예시 7개(fixture·REST Docs 기준) | 소비자 요청 |
| 26 | C3-1 `minDisplay`·`maxDisplay` 위치 | #17(plan `ConditionValidator`)은 `min`·`max`·`unit`·`scale`만. #32의 `calc.web`이 `plan.ConditionViolationException`을 잡아 `Formatter`로 붙이고 `calc.CalcRejectedException`으로 다시 던진다. `/internal/calc`에서만 보장, 프론트 API(#30)에는 없음. #32가 #28에 의존하므로 이 필드의 [전환기]는 없앰. 왜: plan → calc 순환 의존 금지(Modulith) | 제공자 재검토(v3) |
| 27 | C2-5 포인터 규칙 | `diff.baselineScenario`는 항상 `byScenario`에 있는 시나리오(없으면 `AVG`). #32 테스트로 고정 | 제공자 재검토(v3) |
| 28 | C2-2 `memberId` 검사 | `memberId`도 `JsonNode.isIntegralNumber()`로 정수 검사(`7.5`가 `7`로 잘리지 않게), 실패는 `400 MALFORMED_REQUEST` | 제공자 재검토(v3) |
| 29 | C2-2·C3-2 `baselineScenario` 모순 해소 | `String`으로 받고 값은 보지 않는다. C3-2의 "모르는 `baselineScenario` → 400" 삭제 | 제공자 재검토(v3) |
| 30 | C2-6·C3-1 비중 표시 | 비중 표시 형식은 `적금 a : ETF b`(CP-04) 하나. 경계값도 `적금 0 : ETF 100`·`적금 100 : ETF 0` | 제공자 재검토(v3) |

**쟁점 후보였지만 합의로 처리한 것** (사람이 보고 이견이 있으면 말해 주면 된다)
- **CHAT에서 비중을 안 바꿨을 때 비중 고정(FR-INP-08)**: 비중이 바뀌는 경우는 기존 납입액으로 비중을 산출하는 계획뿐인데, 해커톤에서 FR-INP-08은 Won't(5:5 고정, D-045)라 그런 계획이 생기지 않는다. 어느 쪽으로 정해도 해커톤 동작이 같으므로 방어 규칙(현재 비중 고정)만 두고, FR-INP-08을 되살릴 때 의미를 다시 정한다.
- **display 1주차 `{}` 허용**: 백로그에서 Spring 구현(#32)은 원래 2주차이고 Formatter(#28)에 의존한다. 1주차에 B팀은 fixture로 개발하므로 실제 쟁점은 "#28 전에 #32가 먼저 머지되면?"뿐이다. 제공자의 "형식 지금 고정, 구현은 비워도 됨"과 소비자의 "비면 실패 처리"는 서로 막지 않아 둘 다 넣었다.
- **`baselineScenario` 출처**: 소비자는 이 값을 쓰지 않고, 제공자는 요청 필드를 남겨 두는 데 양보했다. 해커톤에서는 항상 AVG라 결과가 같다.
- **`afterTaxGainDelta` 추가 / `goalReachMonthShift`**: 앞의 것은 Spring의 뺄셈 1줄이라 넣었다. 뒤의 것은 한쪽이 `null`인 경우가 많아 뜻이 애매하므로 넣지 않고, 소비자가 함께 제시한 "시점 차이는 말하지 않는다"를 택했다.

## 사람이 정할 쟁점

세 쟁점 모두 **v3에서도 쟁점으로 유지**한다. 본문에는 임시 기본값(X-1 C, X-2 A, X-3 A)만 적혀 있다.

### X-1: 차이·목표 대비 표시 문자열 형식 (부호 vs 방향 단어, 0원·반올림 미만)
- **제공자 의견(v1)**: v1의 `+약 N만원` / `-약 N만원`, 금리 `연 N.NN%` 수용. 단 0원 차이와 반올림 단위 미만(+3,000원 등) 표기를 TBD-16과 함께 정해 줘야 Formatter 테스트를 쓸 수 있다.
- **소비자 의견(v1)**: 부호 대신 방향 단어. 차이는 `약 789만원 증가/감소`, 목표 대비는 `약 288만원 미달 / 약 501만원 초과 달성`. 모델이 문장에 넣기 쉽고 부호를 잘못 읽을 일이 없다. 경계(0원, 1만원 미만, 1억 이상)도 명시해 달라.
- **기획 의견**: CP-04는 "목표 대비는 **부호와** 달성/미달 라벨"이라고 적었다. 그래서 목표 대비에서 부호를 빼면 SRS를 고쳐야 한다(D-번호 필요). 차이(`diff`) 형식은 CP-04에 없어 자유롭게 정할 수 있다. TBD-16(판정에 반올림 전/후 값)은 #9(T-001)에서 정할 일이라 여기서는 "판정·라벨은 raw 값, 표시는 판정과 모순되지 않게"만 정한다.
- **선택지**
  - A) 모두 부호(v1): 목표 대비 `-약 288만원 미달`, 차이 `+약 789만원`. (영향: SRS 변경 없음. 모델이 "+약 789만원 늘어요"처럼 어색한 문장을 만들 수 있고 부호 해석을 모델에 맡김)
  - B) 모두 방향 단어(소비자안): 목표 대비 `약 288만원 미달`, 차이 `약 789만원 증가`. (영향: CP-04 수정과 D-번호 필요. 결과 화면(#49)·planContext(#11)도 같은 형식을 따름)
  - C) 섞음: 목표 대비는 CP-04대로 부호 + 라벨, 차이만 방향 단어 `약 789만원 증가/감소`. (영향: SRS 변경 없음. 차이 문장이 자연스러움. 두 형식이 섞여 Formatter 함수가 1개 늘어남)
  - 경계(A·B·C 공통으로 함께 정함): 차이 정확히 0원 → `변화 없음`, 0원이 아닌데 표시가 0만원이 되는 값 → `1만원 미만 증가/감소`(목표 대비는 `1만원 미만 미달/달성`), 목표 대비 정확히 0원 → `0원 달성`, 1억 이상 → `약 12,345만원`.
- **제공자 재검토 입장(v2)**: **C + 경계 규칙 찬성.** 단 X-1 확정 전에는 #28(Formatter)을 시작하지 않는다.
- **소비자 입장**: v1 검토에서 B(모두 방향 단어)를 제안했다. C는 소비자가 가장 걱정한 차이 문장(부호 해석)을 해결하지만 목표 대비는 부호 + 라벨로 남는다. 소비자는 v2를 재검토하지 않아 C에 대한 명시 입장은 없다. 사람이 C로 정할 때 B팀에 확인할 것: 목표 대비 `-약 288만원 미달`을 모델이 그대로 인용하는 데 문제가 없는지.
- **추천: C + 위 경계 규칙.** SRS를 고치지 않으면서 소비자가 걱정한 차이 문장의 어색함을 없앤다. v3 본문의 임시값이 이것이다.

### X-2: `FIELD_NOT_CHANGEABLE`(목표 금액 등 대화로 못 바꾸는 조건)의 `messageType`
- **제공자 의견(v1)**: 없음(ai-server 쪽 일).
- **소비자 의견(v1)**: `ANSWER`. FR-AI-09의 `OUT_OF_SCOPE`는 "서비스가 다루지 않는 질문"이고 지금 `OUT_OF_SCOPE_COPY`가 "이 질문은 모은에서 다루지 않아요"로 시작해 틀린 안내가 된다. 단 SRS가 "FR-AI-09·TBD-30을 따른다"고 적었으니 기획 확인이 필요하다.
- **기획 의견**: 두 근거가 부딪힌다. FR-AI-06 수용 기준(D-040)은 "안내 문구는 FR-AI-09·TBD-30을 따른다"고 했지만, TBD-30 원문의 6유형은 "대화로 못 바꾸는 조건"을 "금융 범위 밖"과 **다른 유형**으로 나눴다. D-045가 이를 3유형("조건 변경 / 설명 / 그 밖")으로 줄이면서 이 유형이 어디로 가는지는 정하지 않았다. 어느 쪽이든 **문장은 범위 밖 문구와 다른 전용 문구**(입력 수정 안내 + 바꿀 수 있는 4개 조건)여야 한다는 데는 양쪽이 같다. 정할 것은 라벨(`messageType`)뿐이다. DB CHECK(`ck_cm_out_of_scope`)와 프론트(#52)는 둘 다 받을 수 있다.
- **선택지**
  - A) `ANSWER` + 전용 문구 키. (영향: 범위 밖 말풍선 스타일이 붙지 않음. "범위 밖" 집계에 섞이지 않음. #38(T-030)의 3유형 중 "조건 변경"의 하위 경우로 처리)
  - B) `OUT_OF_SCOPE` + 전용 문구 키. (영향: SRS 문장("FR-AI-09를 따른다")과 글자 그대로 맞음. 프론트가 범위 밖 말풍선으로 보여 "다루지 않는 질문"처럼 보일 수 있음)
- **제공자 재검토 입장(v2)**: 이해관계 없음. **이견 없음**(A에 반대하지 않음).
- **소비자 입장**: **A**(v1 검토 Q3). 문구는 "목표 금액은 입력 수정에서 바꿀 수 있어요. 대화로는 월 저축액·비중·적금 금리·기한을 바꿔 볼 수 있어요". 다만 SRS 문장과 부딪히므로 기획 확인을 요청했다.
- **추천: A.** 사용자는 "목표 금액을 바꾸고 싶다"는 정당한 요청을 했고 서비스가 그 방법(입력 수정)을 안내하는 것이므로 "다루지 않는다"는 라벨이 맞지 않다. 정해지면 D-번호로 기록하고 FR-AI-06 수용 기준의 괄호 문장을 "안내 문구는 문구표 전용 키를 따른다"로 고친다. v3 본문의 임시값이 A다. 양 팀 모두 A 쪽이지만 SRS 문장을 바꾸는 일이라 사람이 정한다.

### X-3: 참조되지 않는 CHAT `calc_run` 행을 허용할지 (ADR-002 문장 수정)
- **제공자 의견(v1)**: v1 방식(성공하면 바로 1행, ai-server가 그 뒤 실패하거나 범위 밖으로 끝나도 남김)이 쉽다. 단 ADR-002 §2-2 "CHAT 재계산은 메시지가 참조할 때만 1행"과 어긋나므로 문장을 고치는 결정이 필요하다. 원래 방식을 지키려면 ai-server가 `calcRunId` 대신 버전 묶음을 들고 다녀야 해 `CalcClient`·`/chat` 계약이 같이 바뀐다.
- **소비자 의견(v1)**: v1 수용(ai-server는 `calcRunId`만 받으면 됨).
- **기획 의견**: 양쪽 방향은 같다. 다만 확정된 ADR 문장을 바꾸는 일이라 사람이 확인해야 한다. 남는 행은 계획 버전·데이터 버전 id뿐이고 개인 금융 값은 없다(대화 기록 삭제 D-051 대상인 `chat_message`와 달리 `calc_run`은 계획에 묶인 기록).
- **선택지**
  - A) 허용하고 ADR-002 문장을 "대화 재계산 요청마다 1행. 메시지가 참조하지 않는 행은 남을 수 있으며 정리하지 않는다"로 고친다. (영향: 구현 단순, 문서 1줄 수정 Issue 1개)
  - B) ADR-002 원래대로: Spring이 `/chat` 응답을 저장할 때 CHAT 행을 만든다. (영향: `/internal/calc` 응답에 `calcRunId` 대신 버전 묶음, `CalcClient`·`agent.py`·`/chat` 응답·chat 모듈(#41) 변경. 2주차 일정에 부담)
- **제공자 재검토 입장(v2)**: **A 강하게 지지.**
- **소비자 입장**: **A**(v1 수용). `calcRunId` 하나만 받는 지금 구조를 유지할 수 있다.
- **추천: A.** 저장 비용이 무시할 만하고 계약 두 개(#10, #11)를 다시 열지 않아도 된다. v3 본문의 임시값이 A다. 양 팀 모두 A지만 확정된 ADR 문장을 고치는 일이라 사람이 정한다.

## 협상 기록

**v1 → v2** (상세 표는 v3 부록 B)
- 판정: 제공자 "수정하면 수용", 소비자 "수정하면 수용". 정면으로 부딪힌 것은 X-1(표시 형식) 하나이고, X-2·X-3은 SRS·ADR 문장 해석이 걸려 사람에게 올렸다.
- 제공자 반영: `/internal/**` 필터 체인과 401 본문, `Map<String, JsonNode>`와 검사 순서, `plan.baseline_scenario` 사용, 시나리오 순서 보장, 응답 전용 DTO, 전역 오류 처리 위치(`config`), `title` 고정·`copyKey` 선택, `rules.yml` 위치, 비중 고정 방어 규칙, 전역 `non_null` 금지, `display` 전환기.
- 소비자 반영: "모델은 display만 인용"을 원칙으로, 쓰지 않는 응답 필드 삭제, `diff.baselineScenario` 포인터, `afterTaxGainDelta`, display 키 추가와 표·예시 정리, 델타 반올림 주의, `minDisplay`·`maxDisplay`, `VALIDATION_FAILED`만 모델에 넘기고 나머지는 코드 분기, 재계산 가드, 줄임표 없는 fixture.
- v1의 [기획 제안] 중 그대로 남은 것: 빈 변경 거절, `conditions`, `monthlyPoints` 제외, `current`도 CHAT 행 버전으로 계산, 코드 이름·HTTP 상태, 임시 수치, 타임아웃 코드.

**v2 → v3** (상세 표는 v3 부록 C): 제공자 재검토("수정하면 수용") 반영. `minDisplay`·`maxDisplay`를 #17(plan)이 아니라 #32(`calc.web`)가 붙이도록 옮김(순환 의존 방지), `diff` 포인터 규칙, `memberId` JsonNode 검사, `baselineScenario` 400 모순 삭제, 비중 표시 통일. 모두 합의 처리(합의 26~30), 쟁점 X-1~X-3은 그대로.

## 이 계약 때문에 생긴 후속 작업

이미 백로그(`docs/backlog.json`)에 있는 Issue는 범위·수용 기준에 아래 내용을 더하면 되고, 없는 것은 새 moeun Issue가 필요하다.

| # | 작업 | 팀 | Issue | 메모 |
|---|---|---|---|---|
| F-1 | `CalcClient` 오류 처리: `CalcRejected(code, errors)`, 400·401·5xx·타임아웃 → `AgentError`, 200 응답 추리기, `display` 전환기 검사 | B | **#23**(T-015) | 코드 분기(고정 문장)와 재계산 가드는 `agent.py`(`_TOOL_ERRORS`, `_recalculate`)를 고쳐야 하는데 #23 `paths`에 `agent.py`가 없다. #23 `paths`에 `ai-server/app/llm/agent.py`를 더하고, 같은 파일을 고치는 #21·#22와 **순서대로**(#21 → #22 → #23) 처리 |
| F-2 | 도구 스키마 4개 축소, `ConditionChanges`의 범위 검사 제거(D-033), 목표 금액 의도 → 전용 문구 | B | **#21**(T-013, M-2) | X-2 결과(`messageType`)를 수용 기준에 반영 |
| F-3 | Spring `POST /internal/calc`: `memberId`·`conditionChanges` `JsonNode` 검사, 검사 순서, `CalcComparison`, `CalcResultView` DTO(`@JsonProperty("isAchieved")`), `diff`(`afterTaxGainDelta`, 포인터), display 키(맵 빌더 약 0.5일), 비중 고정, **`minDisplay`·`maxDisplay` 붙이기**(`plan.ConditionViolationException` → `Formatter` → `calc.CalcRejectedException`), 부록 A와 일치하는 REST Docs 테스트 | A | **#32**(T-024) | 수용 기준에 "FIELD_NOT_CHANGEABLE는 허용 키가 섞여도 전체 거절", "두 번째 요청에 첫 변경이 섞이지 않음", "`diff.baselineScenario`는 항상 `byScenario`에 있음", "`memberId: 7.5` → 400", "`OUT_OF_RANGE` 오류에 `minDisplay`·`maxDisplay` 있음" 추가. #28에 의존 |
| F-4 | `/internal/**` 전용 `SecurityFilterChain` + API 키 필터(401 ProblemDetail 직접 작성) | A | **새 Issue 권장** | `config/security/**`는 #16(T-008)의 `paths`라 #32에서 고치면 `paths` 위반. #16 이후·#32 이전, 2주차 초 |
| F-5 | `config` 전역 `@RestControllerAdvice`(ProblemDetail + `code`·`errors`, Spring 기본 예외 → 400 `MALFORMED_REQUEST`) | A | **새 Issue 필수** | #17·#30·#32·#33이 모두 이 형식을 쓰지만 어느 Issue `paths`에도 `config/error/**`가 없다. **1주차에 #17과 같이 진행**(제공자 재검토 "꼭 지킬 것") |
| F-6 | `ConditionValidator`·`rules.yml`: 위치 확정(`backend/src/main/resources/config/rules.yml`), `InputField` ↔ camelCase 매핑, 걸린 필드 모두 반환. 오류에는 `min`·`max`·`unit`·`scale`만 담음(**display 문자열은 만들지 않음**, plan은 calc에 의존하지 않음) | A | **#17**(T-009) | `paths`가 이미 이 위치와 같음. `minDisplay`·`maxDisplay`는 #32로 옮겨 감(F-3) |
| F-7 | Formatter: X-1 결과 형식, 경계 규칙, `YYYY년 M월`, `연 N.NN%`, 경계값 표시(`약` 없음), 비중 `적금 a : ETF b` | A | **#28**(T-020) | **X-1 결정 뒤 시작.** 수용 기준 보강: 방향 단어(`증가`/`감소`), 경계값 4가지(`변화 없음`, `1만원 미만 …`, `0원 달성`, 1억 이상 `약 12,345만원`), `YYYY년 M월`, `연 N.NN%`, `약` 없는 경계값 표시, 비중 형식 하나. TBD-16 판정 기준은 #9(T-001) |
| F-8 | 엔진의 시나리오 순서 GOOD·AVG·BAD 보장 테스트 | A | **#27**(T-019) | 수용 기준 1줄 추가 |
| F-9 | `CalcInput.calcStartMonth` 주석 정정(M-1), 비중 고정 방어 규칙의 단위 테스트 | A | **#25**(T-017) | |
| F-10 | 문구표 키: 대화로 못 바꾸는 조건 안내, `NO_PLAN`·`ALREADY_EXCEEDED` 대화 안내, 증가/감소/변화 없음, 비중 `적금 a : ETF b`, 오류 `title` | 공통 | **#18**(T-010) | X-2 결과 반영 |
| F-11 | 범위 밖 문구 이전 시 "대화로 못 바꾸는 조건"을 범위 밖과 분리 | B | **#38**(T-030) | X-2 결과 반영 |
| F-12 | ADR-002 §2-2 문장 수정, `db/moved-to-code.md`의 `config/rules.yml`(두 서버 공용) 문장을 Spring 전용 위치로 수정 | 공통 | **새 Issue(docs)** | X-3이 A일 때. 문서만 |
| F-13 | 계약 최종본을 moeun `docs/api/internal-calc.md`와 `ai-server/README.md` "Spring과의 계약"에 옮김, fixture JSON 위치 정하기 | 공통 | **#10** 자신 | fixture를 한 파일로 공유하려면 #10 `paths`에 `docs/api/examples/**` 추가 권장(지금은 md 2개뿐). 아니면 #23(`ai-server/tests/fakes/**`)과 #32(`backend/src/test/**`)가 각각 복사하고 "계약 변경 시 두 복사본 동시 수정" 규칙을 README에 적음 |
| F-14 | 프론트 API 401(JWT 만료) 본문을 같은 ProblemDetail 형식으로 | 공통 | **#12**(T-004) | 계약 메모만 |
| F-15 | `planContext.display`도 C2-6 키·형식 규칙을 재사용, snake/camel 통일 | 공통 | **#11**(T-003) | X-1 결과를 같이 따름 |
| F-16 | F-4 비교 조회가 `CalcComparison` 재사용, `chat_message.condition_changes`(snake_case) → camelCase 변환 | B | **#44**(T-036) | 기존 범위 안 |
| F-17 | 프론트 API 오류 본문에는 `minDisplay`·`maxDisplay`가 없음을 수용 기준·화면 표시에 반영(`min`·`max`·`unit`으로 화면 단위 표시) | A | **#30** | 계약 메모만 |

## 재검토(4단계) 판단

**재검토 완료.** 제공자(A팀)가 v2를 재검토해 "수정하면 수용"으로 판정했고, 고칠 곳(`minDisplay` 위치)과 보강(포인터 규칙, `memberId` 검사, `baselineScenario` 모순, 비중 표시)을 모두 v3에 반영했다. 소비자(B팀) 쪽은 v2의 제공자 변경(요청 `baselineScenario` 무시, 401 `instance` 없음, `copyKey` 선택)과 v3 변경(`minDisplay`는 `/internal/calc`에서 계속 보장, 400 조건 축소)이 ai-server 동작을 바꾸지 않으므로 재검토하지 않았다. 남은 것은 사람이 X-1~X-3을 정하는 것뿐이다.
