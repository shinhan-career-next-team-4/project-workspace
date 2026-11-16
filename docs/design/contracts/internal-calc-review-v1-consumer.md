# internal-calc v1 검토 — 소비자(B팀: ai-server·chat·프론트)

> /negotiate-contract 2단계, 독립 검토. 근거 코드: ai-server/app/tools/calc.py, app/schemas.py, app/llm/agent.py, app/llm/prompts.py, tests/test_agent.py

판정: **수정하면 수용**

## 항목별 의견
- [원칙 0-1 숫자는 Spring만] 수용, 단 구멍 있음. `_recalculate`(agent.py:227-234)가 응답 JSON 전체를 모델에 넘겨 모델이 raw 정수로 스스로 "만원" 포맷을 만들 수 있다. 수정안: 계약에 "모델에게 보이는 숫자는 display 값만 인용 가능, raw 숫자는 판단용"을 적고, B팀은 `display`·`diff`(enum)·`conditions`·`changed.scenarios[].isAchieved`·`assumptions`만 추려 넘긴다.
- [원칙 0-2 범위 검증 Spring 한 곳, D-033] 수용 + ai-server 정리 필요(`ConditionChanges` schemas.py:34-45의 범위 검사 제거, 도구 스키마 4개 축소 — M-2, B팀 작업).
- [원칙 0-3 누적 금지, D-041] 수용. 짝 규칙(도구 인자에 이번 발화 값만)은 fake 모델 테스트로(M-3).
- [원칙 0-4·0-5] 수용. snake_case(`chat_message.condition_changes`) 문제는 #11로.
- [C2-1] 수용.
- [C2-2] 수용. 빈 conditionChanges `422 REQUIRED`도 수용.
- [C2-2 baselineScenario 요청값] 수용.
- [C2-3 응답 최상위] 수정. `conditions`는 필요. `basePlanVersionId`, `conditionChanges`·`baselineScenario` 에코는 ai-server가 쓰지 않음(Spring 내부가 쓰면 남겨도 됨). ai-server는 `calcRunId`만 씀.
- [C2-4 current/changed, monthlyPoints 제외] 수용. `dataVersions`, `requiredMonthlySaving`, `status`는 "소비자가 무시"로 충분. null 키를 빼지 않는 규칙 좋음.
- [C2-5 diff] 수정. (a) **`afterTaxGainDelta` 없음** → 모델이 자산 차이−원금 차이를 빼게 됨. 추가 + display. (b) **달성 시점 차이 없음** → `goalReachMonthShift`(개월, null 가능) 추가하거나 "시점 차이는 말하지 않는다"를 계약·프롬프트에 명시. (c) `achievementChange` enum 수용. `baseline`은 `byScenario`와 값이 중복 → 시나리오 포인터만 두자.
- [C2-6 display] 수정. 1) 빠진 display: `goalReachMonth`, `annualReturnPct`, `afterTaxGain`, `targetMonth`, `goalAmount` → display 추가하거나 "소비자는 말하지 않음"으로 못 박기. 2) 키 규칙 표와 예시 불일치(`principal`, `diff.baseline.principalDelta`) 정리. 3) **차이 형식**: "+약 789만원" 대신 "약 789만원 증가/감소", gapToGoal은 "약 288만원 미달 / 약 501만원 초과 달성"처럼 부호 대신 방향 단어. 4) 엣지(0원, 1만원 미만, 1억 이상) 형식 명시. 5) 델타는 따로 반올림해 display끼리 빼면 1만원 어긋날 수 있음을 명시하고, 프롬프트는 두 값을 나란히 빼 보이지 않게. 6) display 키는 응답에 있는 시나리오만(ETF 0%면 AVG만).
- [C2-7] 수용.
- [C2-8] 수용.
- [C3-1 오류 본문] 수용. 수정: `errors` 여러 개면 전부 나열. **`minDisplay`·`maxDisplay` 추가**(없으면 모델이 원→만원 나눗셈). `copyKey`는 프론트용이면 유지.
- [C3-2 코드 표] 수정. `FIELD_NOT_CHANGEABLE`·`NO_PLAN`·`ALREADY_EXCEEDED`는 **모델에 넘기지 않고 ai-server가 코드로 분기해 문구표 고정 문장으로 답함**(문장 흔들림·환각 방지, 테스트 가능). `VALIDATION_FAILED`만 모델에 `{code, errors}`로 넘겨 되묻기. `MALFORMED_REQUEST`(400)는 FAILED(지금은 모델에 넘김 → 고쳐야 함).
- [C3-2 ALREADY_EXCEEDED 409] 수용(200+status보다 소비자가 단순).
- [C3-3] 수용(minDisplay/maxDisplay 조건).
- [C3-4] 수용. 자동 보정 금지는 프롬프트만으로 약하므로 B팀이 `VALIDATION_FAILED` 뒤 같은 턴의 추가 `recalculate`를 막는 가드를 둔다.
- [C3-5] 수용.

## 질문 답변
- **Q3 FIELD_NOT_CHANGEABLE의 messageType → `ANSWER`**. OUT_OF_SCOPE(FR-AI-09)는 "서비스가 다루지 않는 질문"이고, 지금 `OUT_OF_SCOPE_COPY`는 "이 질문은 모은에서 다루지 않아요"로 시작해 틀린 안내가 됨. 문구: "목표 금액은 입력 수정에서 바꿀 수 있어요. 대화로는 월 저축액·비중·적금 금리·기한을 바꿔 볼 수 있어요"(문구표). 단 D-040·SRS가 "FR-AI-09를 따른다"고 적었으므로 기획 확인 필요.
- **Q4 display 시점 → v1 계약에 형태·키를 고정하고, A팀 `Formatter`는 1주차 최소 구현(만원 반올림 + 문구 3개)**. display를 빼면 NFR-INT-01 위반. 정 어려우면 display가 비면 비교를 내지 않고 FAILED.
- **Q5 CalcClient 변경 → 수용, 단 #10 PR이 아니라 별도 ai-server Issue(M-2와 묶음)**. #10 paths가 문서뿐이라 코드를 넣으면 paths 위반. 422·409는 `CalcRejected(code, errors)` 구조화 예외, 400·401·5xx·타임아웃은 `AgentError`.

## fake 테스트 용이성
현재 `FakeCalc`(tests/test_agent.py:32-38) 구조에 잘 맞음. 요청: (1) **줄임표 없는 전체 성공 응답 예시 JSON**(fixture용), (2) `CalcRejected` 예외 타입, (3) Spring REST Docs 스니펫과 ai-server fixture를 맞추는 계약 테스트.

## 소비자 쪽에서 꼭 필요한 것
1. `afterTaxGainDelta`(+display) 또는 "수익 증가분은 말하지 않음" 명시
2. 설명에 쓸 raw 값의 display 또는 "말하지 않음" 명시, 키 표·예시 불일치 정리
3. `errors[].minDisplay`·`maxDisplay`
4. 차이 display는 방향 단어 형식, 엣지 형식 명시
5. `FIELD_NOT_CHANGEABLE`=`ANSWER`, 세 코드는 ai-server 코드 분기 + 고정 문구
6. 줄임표 없는 전체 예시 JSON, errors 여러 개 처리 규칙

## 빼도 되는 것
- 응답 최상위 `basePlanVersionId`, `baselineScenario`·`conditionChanges` 에코(Spring 내부가 안 쓰면)
- `diff.baseline` 값 중복(포인터만), 대응 display 키
- `status`, `requiredMonthlySaving`, `dataVersions`는 "소비자 무시"
- `errors[].copyKey`(프론트가 안 쓰면), ProblemDetail의 `title`·`type`·`detail`·`instance`는 소비자 미사용
