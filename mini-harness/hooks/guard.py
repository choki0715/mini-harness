#!/usr/bin/env python3
"""PreToolUse 훅 — 되돌릴 수 없는 git 명령을 실행 전에 막는다.

수업 포인트: 훅은 '설득되지 않는' 안전장치다.

  스킬(마크다운)에 "main 에 직접 커밋하지 마라"라고 써두면 대체로 지킨다.
  대체로. LLM 은 맥락에 따라 스스로를 설득할 수 있고, 사용자가 재촉하면
  더 그렇다. 훅은 프롬프트가 아니라 코드다. 협상 대상이 아니다.

  규칙: 되돌릴 수 있는 일은 스킬에 맡기고,
        되돌릴 수 없는 일만 훅으로 막는다.
        훅이 많아지면 에이전트가 아무 일도 못 한다.

표준 라이브러리만 쓴다. 어느 환경에서나 즉시 돌아야 한다.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys

PROTECTED_BRANCHES = {"main", "master"}

# 명령의 '시작 위치'만 본다. 이게 없으면 `echo "git commit 예시"` 같은
# 따옴표 안 문자열까지 명령으로 오인한다.
#
# 한계를 분명히 알고 쓴다: 훅은 셸 파서가 아니라 정규식이다.
# 변수 확장(`$CMD --force`), base64, 별칭으로 우회할 수 있다.
# 이건 샌드박스가 아니라 과속방지턱이다 — 실수를 막지, 공격을 막지 않는다.
CMD_START = r"(?:\A|[;&|]|\n)\s*(?:sudo\s+)?"

# (패턴, 사람이 읽을 이유) — 되돌리기 어려운 것만 넣는다
DANGEROUS = [
    (re.compile(CMD_START + r"git\s+push\b[^;&|\n]*(--force(?!-with-lease)\b|(?<![-\w])-f\b)"),
     "강제 푸시는 남의 커밋을 지운다. 필요하면 --force-with-lease 를 쓰고, "
     "그것도 사용자가 직접 실행한다."),
    (re.compile(CMD_START + r"git\s+reset\s+--hard\b"),
     "reset --hard 는 커밋 안 된 작업을 복구 불가능하게 지운다."),
    (re.compile(CMD_START + r"git\s+clean\b[^;&|\n]*-[a-zA-Z]*f"),
     "git clean -f 는 untracked 파일을 지운다. 아직 커밋 안 한 새 파일이 사라진다."),
]

COMMIT_RE = re.compile(CMD_START + r"git\s+commit\b")


def deny(reason: str) -> None:
    """실행을 막고, LLM 에게 '왜' 막혔는지 알려준다.

    이유를 붙이는 게 중요하다. 이유 없이 막으면 LLM 은 같은 명령을
    조금 바꿔서 다시 시도한다. 이유를 주면 다른 방법을 찾는다.
    """
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))
    raise SystemExit(0)


def current_branch() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5,
        )
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""   # git 이 없거나 저장소가 아니면 판단하지 않는다


def main() -> int:
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return 0    # 입력이 깨졌으면 통과시킨다. 훅 버그로 작업을 막지 않는다

    if data.get("tool_name") != "Bash":
        return 0

    command = (data.get("tool_input") or {}).get("command", "")

    for pattern, reason in DANGEROUS:
        if pattern.search(command):
            deny(f"{reason}\n실행하려던 명령: {command}")

    if COMMIT_RE.search(command):
        branch = current_branch()
        if branch in PROTECTED_BRANCHES:
            deny(
                f"`{branch}` 는 보호 브랜치다. 직접 커밋하지 마라.\n"
                f"작업 브랜치를 먼저 만들어라: git switch -c <이름>\n"
                f"의도한 것이라면 사용자에게 확인받고, 사용자가 직접 실행한다."
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
