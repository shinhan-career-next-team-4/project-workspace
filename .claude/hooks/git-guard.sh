#!/usr/bin/env bash
# Claude Code PreToolUse hook: 에이전트의 git 명령을 위치·환경별로 제한한다.
#
# [workspace 루트] 기획 문서 전용, 1인 사용
#   - 커밋, main 직접 푸시 허용 (로컬·클라우드 모두)
#
# [moeun/ 아래] 개발 코드 (기존 규칙)
#   - 로컬(CLI): 커밋·푸시·브랜치 생성 차단. 커밋은 사람이 직접 한다.
#   - 클라우드(CLAUDE_CODE_REMOTE=true): 작업 브랜치 커밋·푸시 허용, main 직접 푸시 차단
#
# [공통] 강제 푸시, reset --hard, rebase, merge 차단
# exit 2 = 명령 차단 (stderr 내용이 Claude에게 전달됨)

input="$(cat)"

has() { printf '%s' "$input" | grep -Eq "$1"; }

GIT='git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?'

# 공통 차단
if has "${GIT}push[^\"]*(--force|[[:space:]]-f([[:space:]]|\"))" \
  || has "${GIT}reset[[:space:]]+--hard" \
  || has "${GIT}rebase" \
  || has "${GIT}merge"; then
  echo "차단됨: 강제 푸시, reset --hard, rebase, merge는 에이전트가 실행하지 않습니다. 필요하면 사람에게 요청하세요." >&2
  exit 2
fi

# 작업 위치가 moeun/ 이 아니면 workspace 규칙: 그대로 허용
# (cwd가 moeun 아래이거나, 명령에 moeun 경로가 들어 있으면 moeun 규칙 적용)
if ! has '"cwd"[[:space:]]*:[[:space:]]*"[^"]*/moeun(/|")' && ! has 'moeun'; then
  exit 0
fi

# ---- 여기부터 moeun/ 규칙 (기존과 동일) ----
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  if has "${GIT}push[^\"]*[[:space:]:](main|master)([[:space:]]|\"|$)"; then
    echo "차단됨: moeun은 main에 직접 푸시하지 않습니다. 작업 브랜치에 푸시하고 PR로 올리세요." >&2
    exit 2
  fi
  exit 0
fi

if has "${GIT}(commit|push|tag)" \
  || has "${GIT}(checkout[[:space:]]+-[bB]|switch[[:space:]]+-[cC])" \
  || has "${GIT}branch[[:space:]]+[^-\"]"; then
  echo "차단됨: moeun에서는 로컬 에이전트가 커밋·푸시·브랜치 생성을 하지 않습니다. 바뀐 파일 목록을 보고하고, 커밋은 사람이 직접 합니다." >&2
  exit 2
fi

exit 0
