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

다시 만들려면:  rm -rf $DEST && $0 $DEST
EOF
