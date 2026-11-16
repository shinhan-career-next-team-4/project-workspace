# project-workspace

목표 기반 개인 자산관리 AI Agent 프로젝트의 **전체 구성 관리 repo**입니다.

- 지금: 기획 자료(요구사항정의서, 결정 기록, 미결 질문)와 기획용 Claude Code 에이전트를 관리합니다.
- 나중: 프론트엔드·백엔드·AI 서버 repo를 **Git Submodule**로 연결해, 이 repo 하나로 전체 프로젝트를 받을 수 있게 합니다. (아래 [Submodule 적용 계획](#submodule-적용-계획) 참고)

## 폴더 구조

```
project-workspace/
├─ README.md
├─ CLAUDE.md                     # Claude Code가 따르는 기획 루프와 규칙
├─ .claude/
│  ├─ settings.json              # 팀 공용 설정 (git-guard 훅 등록)
│  ├─ hooks/git-guard.sh         # 에이전트 git 명령 제한
│  └─ agents/                    # 기획 에이전트 6개
└─ docs/
   ├─ srs.md                     # 요구사항정의서 (GOAL-AGENT-SRS)
   ├─ decisions.md               # 결정 기록 (D-번호)
   ├─ open-questions.md          # 팀이 결정할 질문 (Q-번호)
   ├─ design/                    # API·DB 설계 (아키텍처 검토 후 생성)
   └─ backlog.md                 # 개발 작업 목록 (마지막 단계에 생성)
```

## 기획 에이전트

| 에이전트 | 모델 | 역할 | 파일 수정 |
|---|---|---|---|
| requirements-pm | Sonnet | 정의서 작성·수정, 팀 결정 반영 | srs.md, open-questions.md |
| spec-verifier | Opus | 빈틈·모호함·충돌 찾기 | open-questions.md만 |
| finance-domain-reviewer | Sonnet | 투자 권유 문구, 고지, 개인 금융정보 점검 | open-questions.md만 |
| scope-prioritizer | Sonnet | 3주 범위 Must/Should/Won't 제안 | 수정 안 함 |
| tech-architect | Opus | 실현 가능성 검토, API·DB 초안 | docs/design/ |
| task-planner | Sonnet | 3주 백로그 작성 | backlog.md |

작업 순서는 `CLAUDE.md`의 **기획 루프**를 따릅니다. 핵심 규칙: **에이전트는 미결 사항을 스스로 결정하지 않고, 질문으로 만들어 사람에게 넘깁니다.**

## 사용 방법

### 로컬 CLI

```bash
git clone https://github.com/shinhan-career-next-team-4/project-workspace.git
cd project-workspace
claude
> CLAUDE.md의 기획 루프대로 docs/srs.md를 검토해줘
```

- 에이전트는 기획 루프의 각 단계가 끝날 때마다 **커밋하고 main에 바로 push**합니다.

### 클라우드 세션 (claude.ai/code)

1. claude.ai/code에서 이 repo를 선택하고 세션을 시작합니다. 터미널에서는 `claude --cloud "CLAUDE.md의 기획 루프대로 docs/srs.md를 검토해줘"`로도 시작할 수 있습니다.
2. 로컬과 똑같이 단계마다 **main에 바로 push**합니다.

> 이 repo의 기획 문서는 1인 사용 전제라 PR 없이 main에 바로 반영합니다. 변경 이력은 `git log`와 커밋 메시지(`docs(<단계>): <요약>`)로 확인합니다.

### git 규칙 요약

| | workspace 루트 (기획 문서) | moeun/ 로컬 CLI | moeun/ 클라우드 |
|---|---|---|---|
| 파일 수정 | ✅ | ✅ | ✅ |
| 커밋 | ✅ 자동 | ❌ 사람이 직접 | ✅ |
| 작업 브랜치 푸시 | ✅ | ❌ | ✅ |
| main 직접 푸시 | ✅ 자동 | ❌ | ❌ PR로 |
| 강제 푸시, reset --hard, rebase, merge | ❌ | ❌ | ❌ |

`moeun/`(개발 코드)은 기존 규칙을 유지합니다. 훅은 작업 위치(cwd)나 명령에 `moeun` 경로가 있으면 moeun 규칙을 적용합니다.

개인적으로 설정을 더 추가하고 싶으면 `.claude/settings.local.json`을 만드세요. (`.gitignore`에 포함되어 공유되지 않습니다)

## 팀 결정 기록 방법

1. 에이전트가 `docs/open-questions.md`에 질문(Q-번호)을 추가합니다.
2. 팀이 회의에서 답을 정합니다.
3. 에이전트에게 "Q-003은 A로 결정했어. 이유는 ~"라고 알려주면, `docs/decisions.md`에 D-번호로 기록하고 질문 상태를 바꿉니다.
4. 결정을 바꿀 때는 기존 항목을 지우지 않고 "변경됨 → D-번호"로 표시합니다.

---

## Submodule 적용 계획

> **상태: 미적용.** 개발 repo들이 만들어지면 아래 순서로 적용합니다.

### 목표 구조

```
project-workspace/
├─ docs/  .claude/  CLAUDE.md    # 지금 있는 기획 자료 (그대로 유지)
├─ frontend/                     # submodule → React repo
├─ backend/                      # submodule → Spring Boot repo
└─ ai-server/                    # submodule → FastAPI + LangChain/LangGraph repo
```

repo 이름과 폴더 이름은 개발 repo를 만들 때 확정합니다.

### 적용 방법 (한 명이 1회 실행)

```bash
cd project-workspace

# 1. submodule 추가 (반드시 HTTPS 주소 사용)
git submodule add https://github.com/shinhan-career-next-team-4/<frontend-repo>.git frontend
git submodule add https://github.com/shinhan-career-next-team-4/<backend-repo>.git backend
git submodule add https://github.com/shinhan-career-next-team-4/<ai-server-repo>.git ai-server

# 2. 생성된 .gitmodules와 submodule 폴더를 커밋
git add .gitmodules frontend backend ai-server
git commit -m "chore: 개발 repo submodule 연결"
git push
```

### 팀원이 받을 때

```bash
# 처음 받을 때
git clone --recurse-submodules https://github.com/shinhan-career-next-team-4/project-workspace.git

# 이미 받아 둔 상태라면
git submodule update --init --recursive

# 각 submodule을 원격 최신으로 갱신
git submodule update --remote --merge
```

### 알아둘 점

- **workspace는 submodule의 "특정 커밋"을 가리킵니다.** submodule 안에서 작업·커밋·푸시한 뒤, workspace에서도 `git add <폴더>` → 커밋해야 그 버전이 기록됩니다.
- **submodule 안에서는 각 repo의 브랜치에서 작업하세요.** `git submodule update` 직후에는 브랜치가 없는 상태(detached HEAD)라서, `cd backend && git switch main`처럼 브랜치를 먼저 잡아야 합니다.
- **HTTPS 주소를 쓰세요.** SSH 주소(`git@github.com:...`)는 클라우드 세션에서 받을 수 없습니다.
- **클라우드 세션에서 쓰려면** Claude GitHub 앱이 submodule repo들에도 접근할 수 있어야 하고, 세션 환경 설정의 시작 스크립트에 `git submodule update --init --recursive`를 넣어야 합니다.
- **에이전트 규칙 분리**: 기획 에이전트는 workspace 루트의 `.claude/`에 두고, 개발 단계 규칙(코딩 컨벤션, 테스트 방법)은 각 개발 repo의 `CLAUDE.md`에 둡니다.
- submodule 적용 후 `CLAUDE.md`의 "문서 위치"에 각 폴더 설명을 추가합니다.
