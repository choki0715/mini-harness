#!/usr/bin/env bash
# 실습용 저장소를 만든다. 학생 전원이 똑같은 화면을 본다.
#
# 사용법:
#   ./examples/make-dirty-repo.sh            → /tmp/checkup-demo 에 만든다
#   ./examples/make-dirty-repo.sh ~/demo     → 지정한 경로에 만든다
#
# 만들어지는 상태 (전부 의도적이다):
#   - tracked 파일에 하드코딩된 API 키      → SECRET_SUSPECT
#   - untracked 파일에도 비밀번호           → git diff HEAD 가 못 보는 자리
#   - 디버그 print 와 TODO                  → NEW_DEBUG_PRINT / NEW_TODO
#   - 관계없는 디렉터리 3개가 섞임          → "커밋을 나눠라" 판단 재료
#   - 테스트 파일은 있지만 새 기능엔 없음   → TEST_FILES_CHANGED 판단 재료
set -euo pipefail

HARNESS="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-/tmp/checkup-demo}"

if [ -e "$DEST" ]; then
  echo "이미 있다: $DEST"
  echo "지우고 다시 만들려면:  rm -rf '$DEST' && $0 '$DEST'"
  exit 1
fi

mkdir -p "$DEST"/{auth,billing,docs,tests}
cd "$DEST"
git init -q .
git config user.email student@example.com
git config user.name  "학생"

# ─── 1. 깨끗한 첫 커밋 ────────────────────────────────────────
cat > auth/login.py <<'PY'
def login(user, password):
    return {"ok": True, "user": user}
PY
echo "# 데모 프로젝트" > README.md
echo "def test_login(): pass" > tests/test_login.py

# 이 저장소가 '실습 대상'임을 표시한다. guard.py 가 이 파일을 보고 동작 여부를 정한다.
# 마커가 없는 저장소에서는 훅이 조용히 비켜선다 — 실무 저장소를 막지 않기 위해.
touch "$DEST/.mini-harness-demo"

# ─── 훅을 이 저장소에만 건다 ──────────────────────────────────
# 훅은 원래 전역이다. ~/.claude/settings.json 에 등록하면 모든 프로젝트에서 돈다.
# 그러면 수업 자료가 실무 저장소의 커밋까지 막는다.
#
# 프로젝트 단위 설정(.claude/settings.json)에 등록하면 이 저장소 안에서만 돈다.
# 실무에서도 같은 판단을 한다 — 가드레일에는 범위를 준다.
mkdir -p "$DEST/.claude"
cat > "$DEST/.claude/settings.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python3 \"$HARNESS/mini-harness/hooks/guard.py\"", "timeout": 10 }
        ]
      }
    ]
  }
}
JSON
git add -A
git commit -qm "로그인 기본 구현"

# ─── 2. 여기서부터가 '점검할 변경사항' ─────────────────────────

# auth: 비밀키를 하드코딩했다 (staged)
cat > auth/login.py <<'PY'
import requests

AUTH_API_KEY = "sk-live-7f3a9b2c8e1d4f6a0b5c"   # 이렇게 하면 안 된다

def login(user, password):
    print("로그인 시도:", user)        # 지우는 걸 잊은 디버그 출력
    # TODO: 비밀번호 해싱 추가
    return {"ok": True, "user": user}
PY
git add auth/login.py

# billing: 완전히 다른 기능 (unstaged) — 커밋을 나눠야 하는 이유
cat > billing/invoice.py <<'PY'
def make_invoice(amount):
    return {"amount": amount, "currency": "KRW"}
PY

# docs: 새 파일이고 비밀번호가 들어 있다 (untracked)
#       git diff HEAD 로는 안 보이는 자리 — 이게 이 실습의 핵심이다
cat > docs/setup.md <<'MD'
# 개발 환경 설정

DB 접속:

    DB_PASSWORD = "postgres-dev-1234567890"

MD

# 테스트는 건드리지 않았다 → TEST_FILES_CHANGED 판단 재료
git add billing docs 2>/dev/null || true
git reset -q billing docs   # unstaged/untracked 상태로 되돌린다

cat <<EOF

실습 저장소 준비 완료: $DEST

  cd $DEST
  /checkup

기대하는 것:
  · 비밀키 후보 2건 (auth/login.py, docs/setup.md)
    → docs/setup.md 는 untracked 라서, git diff HEAD 만 봤다면 놓쳤을 것이다
  · auth/ 와 billing/ 은 관계없는 변경 → 커밋을 나누자는 제안
  · 디버그 print 와 TODO 각 1건
  · 새 기능(billing)에 테스트 없음

가드레일(hooks/guard.py)은 이 저장소 안에서만 돈다. 범위를 두 겹으로 뒀다.
  1. $DEST/.claude/settings.json 에 훅을 등록 (프로젝트 단위)
  2. $DEST/.mini-harness-demo 마커 — 훅이 스스로 대상인지 확인한다

2번 덕분에 플러그인으로 전역 설치해도 실무 저장소는 막히지 않는다.
Claude Code 가 이 디렉터리를 처음 열 때 설정을 신뢰할지 한 번 물을 수 있다.

시연해 볼 것 (전부 차단되어야 한다):
  git commit -m "테스트"      ← master 는 보호 브랜치
  git push --force
  git reset --hard HEAD~1

다시 만들려면:  rm -rf $DEST && $0 $DEST
EOF
