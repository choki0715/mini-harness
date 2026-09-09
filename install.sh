#!/usr/bin/env bash
# mini-harness 를 ~/.claude/ 에 설치한다.
#
# /plugin 을 못 쓰는 환경(VSCode 확장 등)용.
# 복사가 아니라 심볼릭 링크라서, 원본을 고치면 즉시 반영된다.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/mini-harness" && pwd)"
DST="$HOME/.claude"

mkdir -p "$DST"/commands "$DST"/skills

echo "설치: $SRC  ->  $DST"
for f in "$SRC"/commands/*.md; do
  ln -sfn "$f" "$DST/commands/$(basename "$f")"; echo "  commands  $(basename "$f")"
done
for d in "$SRC"/skills/*/; do
  ln -sfn "${d%/}" "$DST/skills/$(basename "${d%/}")"; echo "  skills    $(basename "${d%/}")"
done

# ─── 검증 ───────────────────────────────────────────────────
# 수업에서 제일 자주 터지는 곳이 설치다. 링크를 걸고 끝내지 말고 확인한다.
echo
FAILED=0
for want in "$DST/commands/checkup.md" "$DST/skills/checkup"; do
  if [ -e "$want" ]; then
    echo "  ✓ $want"
  else
    echo "  ✗ $want  — 링크가 깨졌다"; FAILED=1
  fi
done

if [ ! -x "$SRC/bin/mh-changes" ]; then
  echo "  ✗ $SRC/bin/mh-changes 에 실행 권한이 없다"
  echo "     고치기:  chmod +x '$SRC/bin/mh-changes'"
  FAILED=1
else
  echo "  ✓ bin/mh-changes 실행 가능"
fi

[ "$FAILED" -eq 0 ] || { echo; echo "설치가 완전하지 않다. 위 항목을 고쳐라."; exit 1; }

echo
echo "완료. Claude Code 를 다시 시작하면 /checkup 이 뜬다."
echo
echo "주의: 훅(hooks/guard.py)은 이 방식으로 설치되지 않는다."
echo "      훅은 플러그인으로 설치하거나(/plugin), settings.json 에 직접 등록해야 한다."
echo "      수업에서는 이 차이 자체가 설명거리다 — 커맨드·스킬은 파일을 놓으면 되지만"
echo "      훅은 하네스가 '등록'해 줘야 도는 것이다."
