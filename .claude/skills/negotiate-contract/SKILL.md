---
name: negotiate-contract
description: moeun의 계약 Issue(예: #10 /internal/calc, #11 planContext, #12 프론트-Spring API)를 기획 에이전트(tech-architect)와 개발 에이전트(contract-provider, contract-consumer)가 협상해 합의안과 "사람이 정할 쟁점"을 만든다. 사람은 쟁점만 결정한다. 사용자가 /negotiate-contract를 부르거나 "계약 합의안 만들어", "기획이랑 개발이 협의해서 가져와"라고 할 때 사용.
---

# /negotiate-contract — 기획·개발 에이전트 협상 → 사람 결정

인자: moeun Issue 번호(필수), moeun 로컬 경로(선택, 기본 `../moeun`).

**에이전트는 결정하지 않는다.** 합의된 것과 쟁점을 정리해 사람에게 넘기는 데까지가 이 절차다(CLAUDE.md 기획 루프 4번).

## 0. 준비
- moeun을 최신 develop으로: `git -C <moeun> fetch origin develop && git -C <moeun> switch --detach origin/develop` (작업 중인 브랜치가 있으면 건드리지 말고 별도 worktree를 쓴다).
- `gh issue view <번호> -R shinhan-career-next-team-4/moeun --comments`로 Issue를 읽는다.
- 출발 초안: `docs/design/b-team-contracts.md`, `docs/design/alignment.md`에서 해당 계약 절(C-1a, C-2, C-3, F-*, A-*)을 찾는다.

## 1. 초안 (기획: `tech-architect`)
- 출발 초안을 SRS·결정(D-번호)과 moeun 현재 코드에 맞춰 다듬어 `docs/design/contracts/<이름>-v1.md`로 쓴다.
- 각 항목에 ID(예: C2-1 요청, C2-2 응답 current/changed …)를 붙여 이후 검토가 항목 단위로 오가게 한다.

## 2. 검토 (개발: `contract-provider`, `contract-consumer` — 동시에)
- 두 에이전트에게 같은 초안 경로와 moeun 경로를 준다. 서로의 의견은 아직 주지 않는다(독립 검토).
- 가능하면 소비자 검토는 다른 모델로 2차 확인한다: `codex` CLI가 있으면 `codex exec`로 같은 질문.

## 3. 수정 (기획: `tech-architect`)
- 두 검토를 받아 항목별로 정리한다:
  - **양쪽 수용** → 합의
  - **한쪽 수정 제안, 다른 쪽 이견 없음** → 반영하고 합의
  - **양쪽 의견이 부딪힘** 또는 **결정(D-번호) 변경이 필요** → 쟁점
- `-v2.md`로 고친다. 쟁점은 고치지 않고 선택지로 남긴다.

## 4. 재검토 (최대 1회 더)
- v2를 두 개발 에이전트에게 다시 보여주되 이번에는 **상대 의견도 함께** 준다. 쟁점이 줄면 v3. 그래도 남으면 멈춘다(무한 반복 금지).

## 5. 사람에게 넘기기
`docs/design/contracts/<이름>-proposal.md`를 쓴다:
```
# <계약 이름> 합의안 (moeun #<번호>)
## 합의된 것 (그대로 구현 가능)
## 사람이 정할 쟁점
### X-1: <쟁점 한 줄>
- 제공자 의견 / 소비자 의견 / 기획 의견
- 선택지: A) … (영향) / B) … (영향)
- 추천: (있으면, 이유)
## 협상 기록
- v1 → v2 → v3에서 바뀐 것 요약
```
- moeun Issue에 댓글로 요약(합의 항목 수, 쟁점 목록, 문서 링크)을 남기고, 쟁점이 있으면 `status:blocked`로 바꾼다.
- project-workspace에는 브랜치 → PR → main 반영(CLAUDE.md git 규칙). 제목 `docs(contract): <이름> 합의안 (moeun #번호)`.
- `docs/open-questions.md`에 쟁점을 Q-번호로 올린다(심각도는 계약을 막으면 개발 차단).

## 6. 사람 결정 후
- 사람이 "X-1은 A" 식으로 답하면 `docs/decisions.md`에 D-번호로 기록하고 proposal을 최종본(`<이름>.md`)으로 확정한다.
- moeun Issue에 최종 계약 링크와 결정 번호를 댓글로 남기고 `status:ready`로 바꾼다. 이후 계약 문서를 moeun에 옮기는 작업(README 계약 표, REST Docs)은 그 Issue의 work-issue 절차로 개발 에이전트가 한다.
