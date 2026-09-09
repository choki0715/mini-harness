#!/usr/bin/env bash
# mini-harness 테스트.
#
# 수업 포인트: 하네스도 코드다. 코드니까 테스트한다.
#
#   스킬(마크다운)은 테스트하기 어렵다 — 출력이 매번 다르니까.
#   하지만 스크립트와 훅은 결정적이다. 결정적인 것은 전부 테스트한다.
#   그래서 하네스에서 '스크립트로 뺀 부분'이 늘어날수록 테스트 가능한 면적이 늘어난다.
#   이게 스크립트로 빼는 두 번째 이유다 (첫 번째는 숫자가 흔들리지 않는 것).
#
# 사용법:  ./test/run-tests.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MH="$ROOT/mini-harness/bin/mh-changes"
GUARD="$ROOT/mini-harness/hooks/guard.py"

PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf "  \033[31m✗\033[0m %s\n     기대: %s\n     실제: %s\n" "$1" "$2" "$3"; }

# ─── 픽스처: 같은 저장소를 매번 똑같이 만든다 ─────────────────────
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

build_fixture() {
  cd "$FIXTURE"
  git init -q .
  git config user.email test@example.com
  git config user.name  test
  mkdir -p src tests
  touch .mini-harness-demo          # 이 저장소가 훅의 대상임을 표시
  echo "x = 1" > src/app.py
  git add -A && git commit -qm "init"

  # 수정된 tracked 파일: 비밀키 + 디버그 출력 + TODO
  cat > src/app.py <<'PY'
API_KEY = "sk-live-abcdefghijklmnop123456"
def run():
    print("여기 디버그")   # TODO: 지우기
    return 1
PY
  git add src/app.py

  # 새 untracked 파일에도 비밀키 — git diff HEAD 가 못 보는 자리
  echo 'DB_PASSWORD = "super-secret-value-9999"' > config_new.py
  # 새 테스트 파일 (untracked)
  echo "def test_run(): pass" > tests/test_app.py
}

# ─── mh-changes ───────────────────────────────────────────────
echo "mh-changes"
build_fixture
OUT="$(cd "$FIXTURE" && "$MH" 2>&1)"

field() { echo "$OUT" | grep -m1 "^$1:" | sed "s/^$1:[[:space:]]*//"; }

check() {  # check <설명> <필드> <기대값>
  got="$(field "$2")"
  [ "$got" = "$3" ] && ok "$1" || bad "$1" "$2=$3" "$2=$got"
}

check "봉투 시작"                 MH_CHANGES_PROTO   1
check "브랜치 인식"               BRANCH             master
check "staged 개수"               STAGED_FILES       1
check "untracked 개수"            UNTRACKED_FILES    2
# tracked 4줄 + untracked 2파일 각 1줄 = 6
check "추가 줄 수 (untracked 포함)" INSERTIONS        6
check "삭제 줄 수"                DELETIONS          1
check "새 TODO"                   NEW_TODO           1
check "새 디버그 출력"            NEW_DEBUG_PRINT    1
# 회귀 방지: untracked 파일의 비밀키를 놓쳤던 버그
check "비밀키 2건 (untracked 포함)" SECRET_SUSPECT    2
# 회귀 방지: untracked 테스트 파일을 못 세던 버그
check "테스트 파일 변경 인식"     TEST_FILES_CHANGED 1

echo "$OUT" | grep -q "MH_CHANGES_OK$" \
  && ok "봉투 끝 (MH_CHANGES_OK)" || bad "봉투 끝" "MH_CHANGES_OK 있음" "없음"

# 비밀 '값'은 절대 새면 안 된다 — 이게 깨지면 나머지가 다 맞아도 실패다
if echo "$OUT" | grep -q "sk-live-abcdefghijklmnop123456\|super-secret-value-9999"; then
  bad "비밀 값 유출 없음" "값이 출력되지 않음" "값이 그대로 출력됨"
else
  ok "비밀 값 유출 없음 (파일·변수명까지만)"
fi

echo "$OUT" | grep -q "config_new.py: DB_PASSWORD" \
  && ok "비밀 위치 보고 (파일: 변수명)" || bad "비밀 위치 보고" "config_new.py: DB_PASSWORD" "없음"

# git 저장소가 아닌 곳
NOTGIT="$(mktemp -d)"
# 함정: `"$MH" ... | grep -q` 로 쓰면 pipefail 때문에 mh-changes 의 exit 1 이
# 파이프라인 전체를 실패로 만든다. 출력을 먼저 받아두고 검사한다.
NG_OUT="$("$MH" "$NOTGIT" 2>&1)"
case "$NG_OUT" in
  ERROR:*) ok "git 저장소 아니면 ERROR" ;;
  *)       bad "git 아닌 경로" "ERROR: 로 시작" "$NG_OUT" ;;
esac
rmdir "$NOTGIT" 2>/dev/null || rm -rf "$NOTGIT"

# ─── guard.py ─────────────────────────────────────────────────
echo
echo "guard.py  (현재 브랜치: master = 보호 브랜치)"
cd "$FIXTURE"

g() {  # g <설명> <DENY|PASS> <명령>
  out="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$3" | python3 "$GUARD")"
  got=$([ -n "$out" ] && echo DENY || echo PASS)
  [ "$got" = "$2" ] && ok "$1" || bad "$1" "$2" "$got"
}

g "보호 브랜치 커밋"        DENY "git commit -m 'x'"
g "&& 뒤의 커밋도 잡는다"   DENY "cd /tmp && git commit -m x"
g "force push"              DENY "git push --force origin main"
g "push -f"                 DENY "git push -f"
g "reset --hard"            DENY "git reset --hard HEAD~1"
g "clean -fd"               DENY "git clean -fd"
g "force-with-lease 는 통과" PASS "git push --force-with-lease"
g "일반 push"               PASS "git push origin feature"
g "status"                  PASS "git status"
g "reset (soft)"            PASS "git reset HEAD~1"
g "따옴표 안 문자열"        PASS "echo 'git commit 예시'"
g "grep 패턴 인자"          PASS "grep -r 'git push --force' docs/"
g "Bash 아닌 도구는 통과"   PASS "__NOT_BASH__"

# Bash 가 아닌 도구는 아예 보지 않는다
out="$(echo '{"tool_name":"Write","tool_input":{"file_path":"x"}}' | python3 "$GUARD")"
[ -z "$out" ] && ok "Write 도구는 검사 안 함" || bad "Write 도구" "PASS" "DENY"

# 입력이 깨져도 작업을 막지 않는다 (훅 버그로 에이전트를 세우지 않는다)
out="$(echo 'not json' | python3 "$GUARD")"
[ -z "$out" ] && ok "깨진 입력은 통과 (fail-open)" || bad "깨진 입력" "PASS" "DENY"

# 보호 브랜치가 아니면 커밋이 통과해야 한다
git switch -qc feature
g "작업 브랜치 커밋은 통과" PASS "git commit -m 'x'"

# 범위 밖 저장소는 아예 검사하지 않는다 (실무 저장소를 막지 않기 위해)
git switch -q master
rm -f .mini-harness-demo
g "마커 없으면 main 커밋도 통과" PASS "git commit -m 'x'"
g "마커 없으면 force push 도 통과" PASS "git push --force"
MINI_HARNESS_GUARD=1 g "환경변수로 켜면 다시 막힌다" DENY "git commit -m 'x'"
touch .mini-harness-demo

# ─── 결과 ─────────────────────────────────────────────────────
echo
if [ "$FAIL" -eq 0 ]; then
  printf "\033[32m%d개 통과, 실패 없음\033[0m\n" "$PASS"; exit 0
else
  printf "\033[31m%d개 통과, %d개 실패\033[0m\n" "$PASS" "$FAIL"; exit 1
fi
