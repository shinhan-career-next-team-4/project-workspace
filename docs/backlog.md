# 개발 백로그 (기획 루프 8번)
> **moeun Issue로 등록됨** (2026-11-16): T-001~T-063 → [moeun #9~#71](https://github.com/shinhan-career-next-team-4/moeun/issues?q=is%3Aissue). 진행 상태는 Issue 라벨(`status:*`)이 기준이고, 이 문서는 등록 시점의 계획입니다.


> 기계가 읽는 원본은 `docs/backlog.json`이며 moeun repo의 GitHub Issues로 등록된다(D-047·D-048). 이 문서는 사람이 읽는 요약이다. 작업 상세(수용 기준, 완료 조건, 건드릴 폴더)는 JSON에 있다.
> 기준: `srs.md`(D-045 반영본), `decisions.md`(D-001~049), `scope-review.md`, `design/alignment.md`, `design/b-team-contracts.md`.
> 범위: Must 전부 + Should 일부(2주차 말 판단). Won't와 [해커톤 범위 밖] 분기는 만들지 않았다.
> 총 63개: Must 55 / Should 8. 팀별 Must는 A 22, B 20, 공통 13.

## 미결 질문과 blocked 작업
| 질문 | 심각도 | 걸린 작업 | 처리 |
|---|---|---|---|
| Q-041 대화 기록 보관 | 개발 차단 | [T-038](https://github.com/shinhan-career-next-team-4/moeun/issues/46) (#46) | blocked. 권장안 A(로그인·로그아웃 때 삭제)로 진행 가능. T-033은 history 최근 20개로 먼저 진행 |
| Q-042 세션 방식 | 개발 중 혼란 | [T-026](https://github.com/shinhan-career-next-team-4/moeun/issues/34) (#34) | blocked. 권장안 A(JWT, 폴링 제외, 로그아웃 엔드포인트)로 진행 가능 |
| Q-043 LangGraph 전환 | 개발 중 혼란 | [T-063](https://github.com/shinhan-career-next-team-4/moeun/issues/71) (#71) | blocked. 권장안 A(Must 후 2주차 말 판단)로 진행 가능 |

> 주의: Q-041이 "개발 차단 / 미결"인데도, 요청에 따라 백로그를 만들고 해당 작업만 blocked로 두었다. Q-041이 결정되기 전에는 T-038을 시작하지 않는다.

## 1주차 (계약·기반)
핵심: 계산 전제와 API 계약을 먼저 정해 A·B가 서로 기다리지 않게 한다. 계약 3개([T-002](https://github.com/shinhan-career-next-team-4/moeun/issues/10) (#10) -> [T-003](https://github.com/shinhan-career-next-team-4/moeun/issues/11) (#11), [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12))를 초반 2~3일에 끝낸다.

| ID | 제목 | 담당 | 우선순위 | 선행 |
|---|---|---|---|---|
| [T-001](https://github.com/shinhan-career-next-team-4/moeun/issues/9) (#9) | [calc] 계산 명세 확정 + 손계산 골든 케이스 | A | must | - |
| [T-002](https://github.com/shinhan-career-next-team-4/moeun/issues/10) (#10) | [contract] /internal/calc 응답·검증 오류 형식 확정 | 공통 | must | - |
| [T-003](https://github.com/shinhan-career-next-team-4/moeun/issues/11) (#11) | [contract] planContext 필드 목록과 display 규칙 | 공통 | must | [T-002](https://github.com/shinhan-career-next-team-4/moeun/issues/10) (#10) |
| [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12) | [contract] 프론트-Spring API 계약 + 목 JSON | 공통 | must | [T-002](https://github.com/shinhan-career-next-team-4/moeun/issues/10) (#10) |
| [T-005](https://github.com/shinhan-career-next-team-4/moeun/issues/13) (#13) | [front] 프론트 프로젝트 초기 설정 | 공통 | must | - |
| [T-006](https://github.com/shinhan-career-next-team-4/moeun/issues/14) (#14) | [refdata] refdata 모듈 코드 | A | must | - |
| [T-007](https://github.com/shinhan-career-next-team-4/moeun/issues/15) (#15) | [refdata] 시드 데이터(S&P500, 적금 금리, 파라미터) | A | must | [T-006](https://github.com/shinhan-career-next-team-4/moeun/issues/14) (#14), [T-001](https://github.com/shinhan-career-next-team-4/moeun/issues/9) (#9) |
| [T-008](https://github.com/shinhan-career-next-team-4/moeun/issues/16) (#16) | [auth] 로그인·JWT·데모 계정 | A | must | - |
| [T-009](https://github.com/shinhan-career-next-team-4/moeun/issues/17) (#17) | [plan] ConditionValidator와 rules.yml | A | must | [T-002](https://github.com/shinhan-career-next-team-4/moeun/issues/10) (#10) |
| [T-010](https://github.com/shinhan-career-next-team-4/moeun/issues/18) (#18) | [docs] 문구표 copy.ko.yml과 로더 | 공통 | must | - |
| [T-011](https://github.com/shinhan-career-next-team-4/moeun/issues/19) (#19) | [plan] 계획 저장 서비스 | A | must | [T-009](https://github.com/shinhan-career-next-team-4/moeun/issues/17) (#17) |
| [T-012](https://github.com/shinhan-career-next-team-4/moeun/issues/20) (#20) | [docs] M-7 tables.md 정정 | 공통 | must | - |
| [T-013](https://github.com/shinhan-career-next-team-4/moeun/issues/21) (#21) | [ai] 대화 조건 4개로 축소 (M-2) | B | must | - |
| [T-014](https://github.com/shinhan-career-next-team-4/moeun/issues/22) (#22) | [ai] 누적 금지 프롬프트와 테스트 (M-3) | B | must | [T-013](https://github.com/shinhan-career-next-team-4/moeun/issues/21) (#21) |
| [T-015](https://github.com/shinhan-career-next-team-4/moeun/issues/23) (#23) | [ai] 계산 응답·검증 오류 소비와 되묻기 | B | must | [T-002](https://github.com/shinhan-career-next-team-4/moeun/issues/10) (#10) |
| [T-016](https://github.com/shinhan-career-next-team-4/moeun/issues/24) (#24) | [rag] 근거 자료 2건 선정과 이용 허락 확인 | B | must | - |

## 2주차 (기능)
### A팀
| ID | 제목 | 우선순위 | 선행 |
|---|---|---|---|
| [T-017](https://github.com/shinhan-career-next-team-4/moeun/issues/25) (#25) | [calc] 시작월 고정 ConditionResolver (M-1) | must | [T-006](https://github.com/shinhan-career-next-team-4/moeun/issues/14) (#14), [T-011](https://github.com/shinhan-career-next-team-4/moeun/issues/19) (#19) |
| [T-018](https://github.com/shinhan-career-next-team-4/moeun/issues/26) (#26) | [calc] CalcEngine 1: 적금·세금·시계열 | must | [T-001](https://github.com/shinhan-career-next-team-4/moeun/issues/9) (#9), [T-007](https://github.com/shinhan-career-next-team-4/moeun/issues/15) (#15), [T-017](https://github.com/shinhan-career-next-team-4/moeun/issues/25) (#25) |
| [T-019](https://github.com/shinhan-career-next-team-4/moeun/issues/27) (#27) | [calc] CalcEngine 2: 3구간·판정·초과·미지원 분기 차단 (M-8) | must | [T-018](https://github.com/shinhan-career-next-team-4/moeun/issues/26) (#26) |
| [T-020](https://github.com/shinhan-career-next-team-4/moeun/issues/28) (#28) | [calc] Formatter | must | [T-001](https://github.com/shinhan-career-next-team-4/moeun/issues/9) (#9) |
| [T-021](https://github.com/shinhan-career-next-team-4/moeun/issues/29) (#29) | [calc] calc_run 기록·버전 기록·결과 조회 | must | [T-011](https://github.com/shinhan-career-next-team-4/moeun/issues/19) (#19), [T-019](https://github.com/shinhan-career-next-team-4/moeun/issues/27) (#27) |
| [T-022](https://github.com/shinhan-career-next-team-4/moeun/issues/30) (#30) | [plan] 결과 보기 API | must | [T-009](https://github.com/shinhan-career-next-team-4/moeun/issues/17) (#17), [T-011](https://github.com/shinhan-career-next-team-4/moeun/issues/19) (#19), [T-019](https://github.com/shinhan-career-next-team-4/moeun/issues/27) (#27), [T-020](https://github.com/shinhan-career-next-team-4/moeun/issues/28) (#28), [T-021](https://github.com/shinhan-career-next-team-4/moeun/issues/29) (#29) |
| [T-023](https://github.com/shinhan-career-next-team-4/moeun/issues/31) (#31) | [plan] 현재 계획 조회 API(진입 분기) | must | [T-022](https://github.com/shinhan-career-next-team-4/moeun/issues/30) (#30) |
| [T-024](https://github.com/shinhan-career-next-team-4/moeun/issues/32) (#32) | [calc] POST /internal/calc | must | [T-002](https://github.com/shinhan-career-next-team-4/moeun/issues/10) (#10), [T-003](https://github.com/shinhan-career-next-team-4/moeun/issues/11) (#11), [T-009](https://github.com/shinhan-career-next-team-4/moeun/issues/17) (#17), [T-019](https://github.com/shinhan-career-next-team-4/moeun/issues/27) (#27), [T-020](https://github.com/shinhan-career-next-team-4/moeun/issues/28) (#28), [T-021](https://github.com/shinhan-career-next-team-4/moeun/issues/29) (#29) |
| [T-025](https://github.com/shinhan-career-next-team-4/moeun/issues/33) (#33) | [plan] 적용·되돌리기 서비스 | must | [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12), [T-011](https://github.com/shinhan-career-next-team-4/moeun/issues/19) (#19), [T-021](https://github.com/shinhan-career-next-team-4/moeun/issues/29) (#29) |
| [T-026](https://github.com/shinhan-career-next-team-4/moeun/issues/34) (#34) | [auth] 로그아웃·TokenRenewalFilter (M-6) | must, blocked(Q-042) | [T-008](https://github.com/shinhan-career-next-team-4/moeun/issues/16) (#16) |
| [T-039](https://github.com/shinhan-career-next-team-4/moeun/issues/47) (#47) | [front] 로그인 화면·가드·로그아웃 | must | [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12), [T-005](https://github.com/shinhan-career-next-team-4/moeun/issues/13) (#13) |
| [T-040](https://github.com/shinhan-career-next-team-4/moeun/issues/48) (#48) | [front] 입력 화면 | must | [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12), [T-005](https://github.com/shinhan-career-next-team-4/moeun/issues/13) (#13) |
| [T-041](https://github.com/shinhan-career-next-team-4/moeun/issues/49) (#49) | [front] 결과 화면 1(요약·조건 바·가정 보기·면책) | must | [T-040](https://github.com/shinhan-career-next-team-4/moeun/issues/48) (#48), [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12) |
| [T-042](https://github.com/shinhan-career-next-team-4/moeun/issues/50) (#50) | [front] 결과 화면 2(3구간·고지·그래프) | must | [T-041](https://github.com/shinhan-career-next-team-4/moeun/issues/49) (#49) |
| [T-043](https://github.com/shinhan-career-next-team-4/moeun/issues/51) (#51) | [front] 입력 수정·진입 분기·되돌리기 토스트 | must | [T-041](https://github.com/shinhan-career-next-team-4/moeun/issues/49) (#49), [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12) |

### B팀
| ID | 제목 | 우선순위 | 선행 |
|---|---|---|---|
| [T-027](https://github.com/shinhan-career-next-team-4/moeun/issues/35) (#35) | [ai] planContext 설명 모드 | must | [T-003](https://github.com/shinhan-career-next-team-4/moeun/issues/11) (#11), [T-013](https://github.com/shinhan-career-next-team-4/moeun/issues/21) (#21) |
| [T-028](https://github.com/shinhan-career-next-team-4/moeun/issues/36) (#36) | [ai] 상품명·추천 표현 검사 (M-4) | must | [T-013](https://github.com/shinhan-career-next-team-4/moeun/issues/21) (#21) |
| [T-029](https://github.com/shinhan-career-next-team-4/moeun/issues/37) (#37) | [ai] 숫자 자동 대조 | must | [T-015](https://github.com/shinhan-career-next-team-4/moeun/issues/23) (#23), [T-027](https://github.com/shinhan-career-next-team-4/moeun/issues/35) (#35) |
| [T-030](https://github.com/shinhan-career-next-team-4/moeun/issues/38) (#38) | [ai] 범위 밖 3유형·문구표 이전 (M-5) | must | [T-010](https://github.com/shinhan-career-next-team-4/moeun/issues/18) (#18), [T-013](https://github.com/shinhan-career-next-team-4/moeun/issues/21) (#21) |
| [T-031](https://github.com/shinhan-career-next-team-4/moeun/issues/39) (#39) | [rag] 자료 적재·검색 품질 점검 | must | [T-016](https://github.com/shinhan-career-next-team-4/moeun/issues/24) (#24) |
| [T-032](https://github.com/shinhan-career-next-team-4/moeun/issues/40) (#40) | [ai] 운용사 2곳 이상 출처 인용 | must | [T-027](https://github.com/shinhan-career-next-team-4/moeun/issues/35) (#35), [T-031](https://github.com/shinhan-career-next-team-4/moeun/issues/39) (#39) |
| [T-033](https://github.com/shinhan-career-next-team-4/moeun/issues/41) (#41) | [chat] chat 모듈 기반 + F-1 + ai 호출 | must | [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12), [T-008](https://github.com/shinhan-career-next-team-4/moeun/issues/16) (#16), [T-010](https://github.com/shinhan-career-next-team-4/moeun/issues/18) (#18) |
| [T-034](https://github.com/shinhan-career-next-team-4/moeun/issues/42) (#42) | [chat] F-2 폴링 + citations | must | [T-033](https://github.com/shinhan-career-next-team-4/moeun/issues/41) (#41), [T-026](https://github.com/shinhan-career-next-team-4/moeun/issues/34) (#34) |
| [T-035](https://github.com/shinhan-career-next-team-4/moeun/issues/43) (#43) | [chat] F-3 설명 요청 | must | [T-033](https://github.com/shinhan-career-next-team-4/moeun/issues/41) (#41), [T-021](https://github.com/shinhan-career-next-team-4/moeun/issues/29) (#29) |
| [T-036](https://github.com/shinhan-career-next-team-4/moeun/issues/44) (#44) | [chat] F-4 비교 조회 + applicable | must | [T-024](https://github.com/shinhan-career-next-team-4/moeun/issues/32) (#32), [T-034](https://github.com/shinhan-career-next-team-4/moeun/issues/42) (#42) |
| [T-037](https://github.com/shinhan-career-next-team-4/moeun/issues/45) (#45) | [chat] 대화 적용 엔드포인트 | must | [T-025](https://github.com/shinhan-career-next-team-4/moeun/issues/33) (#33), [T-036](https://github.com/shinhan-career-next-team-4/moeun/issues/44) (#44) |
| [T-038](https://github.com/shinhan-career-next-team-4/moeun/issues/46) (#46) | [chat] 대화 기록 삭제 | must, blocked(Q-041) | [T-033](https://github.com/shinhan-career-next-team-4/moeun/issues/41) (#41), [T-008](https://github.com/shinhan-career-next-team-4/moeun/issues/16) (#16), [T-026](https://github.com/shinhan-career-next-team-4/moeun/issues/34) (#34) |
| [T-044](https://github.com/shinhan-career-next-team-4/moeun/issues/52) (#52) | [front] 대화창 기본 | must | [T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12), [T-005](https://github.com/shinhan-career-next-team-4/moeun/issues/13) (#13) |
| [T-045](https://github.com/shinhan-career-next-team-4/moeun/issues/53) (#53) | [front] 비교 카드·적용 버튼 | must | [T-044](https://github.com/shinhan-career-next-team-4/moeun/issues/52) (#52), [T-043](https://github.com/shinhan-career-next-team-4/moeun/issues/51) (#51) |
| [T-046](https://github.com/shinhan-career-next-team-4/moeun/issues/54) (#54) | [front] AI 설명·출처·실패 안내 | must | [T-044](https://github.com/shinhan-career-next-team-4/moeun/issues/52) (#52), [T-041](https://github.com/shinhan-career-next-team-4/moeun/issues/49) (#49) |

## 3주차 (통합·데모)
마지막 3~4일은 새 기능 없이 통합과 버그 수정만 한다. Must 통합 작업([T-047](https://github.com/shinhan-career-next-team-4/moeun/issues/55) (#55)~[T-055](https://github.com/shinhan-career-next-team-4/moeun/issues/63) (#63))이 먼저이고, Should는 3주차 1~2일 안에 끝나지 않으면 포기한다.

| ID | 제목 | 담당 | 우선순위 | 선행 |
|---|---|---|---|---|
| [T-047](https://github.com/shinhan-career-next-team-4/moeun/issues/55) (#55) | [front] 목 제거, 실제 API 연결 | A | must | [T-022](https://github.com/shinhan-career-next-team-4/moeun/issues/30) (#30), [T-023](https://github.com/shinhan-career-next-team-4/moeun/issues/31) (#31), [T-025](https://github.com/shinhan-career-next-team-4/moeun/issues/33) (#33), [T-039](https://github.com/shinhan-career-next-team-4/moeun/issues/47) (#47), [T-042](https://github.com/shinhan-career-next-team-4/moeun/issues/50) (#50), [T-043](https://github.com/shinhan-career-next-team-4/moeun/issues/51) (#51) |
| [T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56) | [demo] 3서버 통합 E2E | 공통 | must | [T-029](https://github.com/shinhan-career-next-team-4/moeun/issues/37) (#37), [T-032](https://github.com/shinhan-career-next-team-4/moeun/issues/40) (#40), [T-036](https://github.com/shinhan-career-next-team-4/moeun/issues/44) (#44), [T-037](https://github.com/shinhan-career-next-team-4/moeun/issues/45) (#45), [T-045](https://github.com/shinhan-career-next-team-4/moeun/issues/53) (#53), [T-046](https://github.com/shinhan-career-next-team-4/moeun/issues/54) (#54), [T-047](https://github.com/shinhan-career-next-team-4/moeun/issues/55) (#55) |
| [T-049](https://github.com/shinhan-career-next-team-4/moeun/issues/57) (#57) | [demo] 대화 시나리오 고정·LLM 회귀 점검 | B | must | [T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56) |
| [T-050](https://github.com/shinhan-career-next-team-4/moeun/issues/58) (#58) | [demo] 데모 계정·시드·시연 입력 | 공통 | must | [T-007](https://github.com/shinhan-career-next-team-4/moeun/issues/15) (#15), [T-008](https://github.com/shinhan-career-next-team-4/moeun/issues/16) (#16) |
| [T-051](https://github.com/shinhan-career-next-team-4/moeun/issues/59) (#59) | [docs] 문구·추천 금지·면책 점검 | 공통 | must | [T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56) |
| [T-052](https://github.com/shinhan-career-next-team-4/moeun/issues/60) (#60) | [demo] 통합 버그 수정 1 | 공통 | must | [T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56), [T-049](https://github.com/shinhan-career-next-team-4/moeun/issues/57) (#57) |
| [T-053](https://github.com/shinhan-career-next-team-4/moeun/issues/61) (#61) | [demo] 통합 버그 수정 2·안정화 | 공통 | must | [T-052](https://github.com/shinhan-career-next-team-4/moeun/issues/60) (#60) |
| [T-054](https://github.com/shinhan-career-next-team-4/moeun/issues/62) (#62) | [demo] 리허설 1 | 공통 | must | [T-049](https://github.com/shinhan-career-next-team-4/moeun/issues/57) (#57), [T-050](https://github.com/shinhan-career-next-team-4/moeun/issues/58) (#58), [T-051](https://github.com/shinhan-career-next-team-4/moeun/issues/59) (#59), [T-052](https://github.com/shinhan-career-next-team-4/moeun/issues/60) (#60) |
| [T-055](https://github.com/shinhan-career-next-team-4/moeun/issues/63) (#63) | [demo] 리허설 2·최종 문서 | 공통 | must | [T-053](https://github.com/shinhan-career-next-team-4/moeun/issues/61) (#61), [T-054](https://github.com/shinhan-career-next-team-4/moeun/issues/62) (#62) |

### Should (2주차 말 판단)
| ID | 제목 | 담당 | 순서 | 선행 |
|---|---|---|---|---|
| [T-056](https://github.com/shinhan-career-next-team-4/moeun/issues/64) (#64) | [chat] 조건 변경 비교 API (FR-CMP-02) | B | 1 | [T-024](https://github.com/shinhan-career-next-team-4/moeun/issues/32) (#32), [T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56) |
| [T-057](https://github.com/shinhan-career-next-team-4/moeun/issues/65) (#65) | [front] 비교 영역·원래대로 (FR-CMP-02·03) | B | 1 | [T-056](https://github.com/shinhan-career-next-team-4/moeun/issues/64) (#64), [T-045](https://github.com/shinhan-career-next-team-4/moeun/issues/53) (#53) |
| [T-058](https://github.com/shinhan-career-next-team-4/moeun/issues/66) (#66) | [calc] 대안 3종 값 산출 API (FR-ALT-01·03) | B | 2 | [T-024](https://github.com/shinhan-career-next-team-4/moeun/issues/32) (#32), [T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56) |
| [T-059](https://github.com/shinhan-career-next-team-4/moeun/issues/67) (#67) | [front] 대안 3종 카드 (FR-ALT-02·04) | B | 2 | [T-058](https://github.com/shinhan-career-next-team-4/moeun/issues/66) (#66), [T-042](https://github.com/shinhan-career-next-team-4/moeun/issues/50) (#50) |
| [T-060](https://github.com/shinhan-career-next-team-4/moeun/issues/68) (#68) | [plan] 대안·비교 적용 확인창 (FR-PLAN-01·02) | A | 3 | [T-025](https://github.com/shinhan-career-next-team-4/moeun/issues/33) (#33), [T-057](https://github.com/shinhan-career-next-team-4/moeun/issues/65) (#65), [T-059](https://github.com/shinhan-career-next-team-4/moeun/issues/67) (#67) |
| [T-061](https://github.com/shinhan-career-next-team-4/moeun/issues/69) (#69) | [ai] 질문 예시 버튼 (FR-AI-08) | B | 4 | [T-044](https://github.com/shinhan-career-next-team-4/moeun/issues/52) (#52), [T-030](https://github.com/shinhan-career-next-team-4/moeun/issues/38) (#38) |
| [T-062](https://github.com/shinhan-career-next-team-4/moeun/issues/70) (#70) | [ai] 설명 다시 요청 (FR-AI-05) | B | 5 | [T-035](https://github.com/shinhan-career-next-team-4/moeun/issues/43) (#43), [T-046](https://github.com/shinhan-career-next-team-4/moeun/issues/54) (#54) |
| [T-063](https://github.com/shinhan-career-next-team-4/moeun/issues/71) (#71) | [ai] LangGraph 전환 | B | 6 | [T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56) |

## 2주차 말 되살릴 Should 순서
scope-review의 빼는 순서를 거꾸로 따랐다. 진행률을 보고 위에서부터 하나씩만 연다.
1. 조건 변경 비교 FR-CMP-02·03 ([T-056](https://github.com/shinhan-career-next-team-4/moeun/issues/64) (#64), [T-057](https://github.com/shinhan-career-next-team-4/moeun/issues/65) (#65)): 대화창 비교 카드 재사용
2. 대안 3종 FR-ALT-01~04 ([T-058](https://github.com/shinhan-career-next-team-4/moeun/issues/66) (#66), [T-059](https://github.com/shinhan-career-next-team-4/moeun/issues/67) (#67))
3. 적용 확인창 FR-PLAN-01·02 ([T-060](https://github.com/shinhan-career-next-team-4/moeun/issues/68) (#68)): 2번이나 1번이 살아 있을 때만 의미가 있음
4. 질문 예시 버튼 FR-AI-08 ([T-061](https://github.com/shinhan-career-next-team-4/moeun/issues/69) (#69))
5. 설명 다시 요청 FR-AI-05 ([T-062](https://github.com/shinhan-career-next-team-4/moeun/issues/70) (#70))
6. LangGraph 전환 ([T-063](https://github.com/shinhan-career-next-team-4/moeun/issues/71) (#71)): Q-043 결정 필요. 포트폴리오 설명이 필요할 때 당김
(FR-RES-09 기준 시나리오 선택 UI, FR-INP-02, NFR 항목은 만들지 않았다. 기본값은 평균 고정이다.)

## 일정상 위험 3가지
1. **계산 엔진 병목과 전제 미확정([T-001](https://github.com/shinhan-career-next-team-4/moeun/issues/9) (#9) -> [T-018](https://github.com/shinhan-career-next-team-4/moeun/issues/26) (#26) -> [T-019](https://github.com/shinhan-career-next-team-4/moeun/issues/27) (#27) -> [T-024](https://github.com/shinhan-career-next-team-4/moeun/issues/32) (#32)).** TBD-01·04·05가 1주차 초반에 확정되지 않으면 계산 엔진, 결과 API, /internal/calc, 대화 비교([T-036](https://github.com/shinhan-career-next-team-4/moeun/issues/44) (#44))와 B팀 통합이 줄줄이 밀린다. A팀 백엔드 작업이 2주차에 직렬(T-017부터 [T-025](https://github.com/shinhan-career-next-team-4/moeun/issues/33) (#33))로 몰려 있어 지연 여유가 거의 없다.
2. **모듈 의존 순환과 적용 계약([T-004](https://github.com/shinhan-career-next-team-4/moeun/issues/12) (#12), [T-025](https://github.com/shinhan-career-next-team-4/moeun/issues/33) (#33), [T-037](https://github.com/shinhan-career-next-team-4/moeun/issues/45) (#45)).** 대화 적용은 chatMessageId를 받아 chat_message를 읽어야 하는데, plan이 chat을 의존하면 calc -> plan, chat -> calc 구조와 순환이 된다. 그래서 적용 컨트롤러를 chat 모듈로 두는 설계로 T-004에서 합의해야 하며, 늦으면 T-025와 T-037을 다시 만들게 된다.
3. **3서버 통합과 LLM 비결정성([T-048](https://github.com/shinhan-career-next-team-4/moeun/issues/56) (#56), [T-049](https://github.com/shinhan-career-next-team-4/moeun/issues/57) (#57)).** 통합이 3주차 초반에야 시작되어 계약 불일치(키 표기, 시간 초과, 오류 형식)가 늦게 드러난다. LLM이 누적하거나 상품명·숫자를 어기면 데모 시나리오가 깨질 수 있다. 목 기반 계약 테스트를 2주차에 앞당기고 [T-049](https://github.com/shinhan-career-next-team-4/moeun/issues/57) (#57) 시나리오를 먼저 고정해야 한다.
