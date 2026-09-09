---
description: 실습용 저장소를 만든다 (수업 준비)
argument-hint: [경로] (생략하면 /tmp/checkup-demo)
allowed-tools: Bash
---

!`for _c in "$CLAUDE_PLUGIN_ROOT/bin/mh-demo-repo" "$(readlink -f "$HOME/.claude/skills/mini-harness" 2>/dev/null)/bin/mh-demo-repo" "$(dirname "$(readlink -f "$HOME/.claude/skills/checkup" 2>/dev/null)")/../bin/mh-demo-repo" "$(command -v mh-demo-repo 2>/dev/null)"; do [ -x "$_c" ] && { "$_c" $ARGUMENTS 2>&1; exit 0; }; done; echo "ERROR: mh-demo-repo 를 찾지 못했다 — 설치를 확인해라"`

---

위 출력을 사용자에게 그대로 전하고, 다음에 무엇을 하면 되는지 한 줄로 알려줘라.

`ERROR:` 로 시작하면 설치가 깨진 것이다. 저장소를 직접 만들려고 하지 마라.
