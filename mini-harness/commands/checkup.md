---
description: 커밋 전에 변경사항을 점검하고 커밋 메시지 초안을 만든다
argument-hint: [경로] (생략하면 현재 디렉터리)
allowed-tools: Bash, Read, Grep, Glob
---

변경사항:
!`MH="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(readlink -f "$HOME/.claude/skills/checkup")")/..}/bin/mh-changes"; [ -x "$MH" ] && "$MH" $ARGUMENTS 2>&1 || echo "ERROR: mh-changes 를 찾지 못했다 — 설치를 확인해라 ($MH)"`

기존 커밋 스타일:
!`ARG="$ARGUMENTS"; git -C "${ARG:-.}" log --oneline -10 2>/dev/null || echo "커밋 없음"`

---

`checkup` 스킬을 따라라.

위 STATUS 라인이 **사실이다.** 숫자를 다시 세지 마라.
커밋은 실행하지 마라 — 이 커맨드의 산출물은 초안이고, 실행은 사용자가 한다.
