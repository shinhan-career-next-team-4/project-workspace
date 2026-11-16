# 목표 기반 개인 자산관리 AI Agent

## 현재 단계: 기획 (요구사항정의서 확정)

코드를 작성하지 않는다. 지금 목표는 주니어 개발자가 바로 개발을 시작할 수 있을 만큼 명확한 요구사항정의서를 만드는 것이다.

## ID 체계
- 요구사항: `CP-xx`(공통), `FR-<영역>-xx`(기능), `NFR-<영역>-xx`(비기능). 새 요구사항도 같은 체계로 번호를 이어서 붙인다.
- `TBD-xx`, `CF-xx`: Notion에서 관리하던 미결·결정 항목. 원문이 repo에 없으므로 내용을 추측하지 않는다. 원문이 필요하면 질문으로 올린다.
- `Q-xxx`: 이 repo에서 새로 생긴 질문 (docs/open-questions.md)
- `D-xxx`: 이 repo에서 기록한 결정 (docs/decisions.md)

## 문서 위치
- docs/srs.md: 요구사항정의서 (GOAL-AGENT-SRS) 최신본
- docs/decisions.md: 팀이 결정한 것. 날짜, 이유와 함께 기록
- docs/open-questions.md: 팀이 결정해야 할 질문
- docs/design/: API, DB 설계 (아키텍처 검토 이후)
- docs/backlog.md: 개발 작업 목록 (마지막 단계)

## 기획 루프

요청을 받으면 아래 순서를 따른다. 각 단계는 `.claude/agents/`의 서브에이전트에 맡긴다.

1. **requirements-pm**: 정의서를 수정하거나 팀 결정을 반영한다.
2. **spec-verifier**: 수정된 정의서를 검증하고 open-questions.md에 질문을 추가한다.
3. **finance-domain-reviewer**: AI 조언, 상품, 개인 금융정보와 관련된 요구사항이 바뀌었을 때만 실행한다.
4. **여기서 멈춘다.** 새로 생긴 질문 중 "개발 차단" 항목을 사람에게 보고하고 결정을 기다린다. 미결 사항을 에이전트가 대신 결정하지 않는다.
5. 팀이 답하면 decisions.md에 기록하고(D-번호, 날짜, 결정, 이유), 해당 질문 상태를 "결정됨 → D-번호"로 바꾼 뒤 1번으로 돌아간다.

"개발 차단" 질문이 모두 해결되면:

6. **scope-prioritizer**: 3주 범위를 점검한다.
7. **tech-architect**: 실현 가능성을 검토하고, 요청받으면 API, DB 초안을 작성한다.
8. **task-planner**: 백로그를 만든다.

## 규칙
- 모든 출력은 한국어로 한다.
- decisions.md와 충돌하는 내용은 쓰지 않는다. 결정을 바꿔야 할 것 같으면 질문으로 올린다.
- 작업이 끝나면 바꾼 파일 목록과 단계(pm/verify/domain 등)별 변경 요약을 보고한다.

## git 규칙 (위치별)
`.claude/hooks/git-guard.sh`가 아래 규칙을 강제한다. 차단 메시지가 나오면 우회하지 말고 사람에게 보고한다.

### workspace 루트 (기획 문서) — PR 기록 + main 자동 반영
PR은 **나중에 사람이 읽고 이해하기 위한 변경 기록**이다. 리뷰를 기다리지 않고 바로 main에 반영한다. 로컬과 클라우드 모두 같다.

1. 최신 main에서 작업 브랜치를 만든다: `docs/<단계>-<짧은설명>` (예: `docs/verify-first-pass`)
2. 기획 루프의 한 단계가 끝나면 커밋한다. 커밋 메시지는 `docs(<단계>): <요약>` 형식. 예: `docs(verify): FR-INP-04 예외 상황 질문 추가`
3. 브랜치를 push하고 PR을 만든다. 본문은 `.github/pull_request_template.md` 형식을 따르고, **처음 보는 사람도 이해할 수 있게** 왜 바꿨는지와 요구사항·질문·결정 ID를 적는다.
   - 로컬: `gh pr create --base main --title "..." --body-file <파일>`
   - 클라우드: GraphQL이 막혀 있으므로 `gh api repos/{owner}/{repo}/pulls -f base=main -f head=<브랜치> -f title="..." -F body=@<파일>`
4. 같은 브랜치를 main에 바로 반영한다: `git push origin HEAD:main`. main이 브랜치의 조상이면 PR은 자동으로 "merged"가 된다.
5. main 반영이 거부되면(main이 먼저 바뀐 경우) `git pull --rebase origin main` 후 브랜치와 main에 다시 push한다. 충돌이 나면 멈추고 사람에게 보고한다.
6. 기획 루프 4번(사람의 결정 대기)에서 멈출 때도, 그때까지의 작업은 위 과정을 거쳐 main에 반영한 뒤 멈춘다.

### moeun/ (개발 코드) — 기존 규칙
- **로컬 CLI**: 커밋, 푸시, 브랜치 생성을 하지 않는다. 파일만 수정하고 사람이 직접 커밋한다.
- **클라우드 세션**: 작업 브랜치에 커밋하고 푸시한다. main에는 직접 푸시하지 않는다.

### 공통
- 강제 푸시, `reset --hard`, `git rebase`, `git merge`는 실행하지 않는다.
