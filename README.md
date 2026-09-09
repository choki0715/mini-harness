# mini-harness

**에이전트 하네스가 무엇인지 보여주는 최소 예제.** 수업용.

파일 4개로 하네스의 해부학 전부를 보여준다.
Garry Tan 의 [gstack](https://github.com/garrytan/gstack) 은 파일 1,552개로 같은 일을 한다.
구조는 같고, 규모만 다르다.

---

## 하네스란 무엇인가

"프롬프트를 잘 쓰는 것"과 "에이전트를 운영하는 것"은 다른 일이다.

프롬프트는 **한 번의 대화**를 좋게 만든다.
하네스는 **매번 같은 품질이 나오게** 만든다. 그러려면 네 가지가 필요하다.

| 필요한 것 | 이 예제의 파일 | 왜 |
|---|---|---|
| 진입점 | `commands/checkup.md` | 사용자가 매번 같은 설명을 타이핑하지 않게 |
| 사실 | `bin/mh-changes` | LLM 이 세면 매번 다르게 센다 |
| 절차 | `skills/checkup/SKILL.md` | 판단 기준이 세션마다 흔들리지 않게 |
| 가드레일 | `hooks/guard.py` | 되돌릴 수 없는 사고를 실행 전에 막게 |

그리고 하네스도 코드라서 `test/run-tests.sh` 로 테스트한다 (30개).

---

## 흐름

```
 사용자: /checkup
    │
    ▼
 ① commands/checkup.md          ← 진입점
    │   frontmatter 의 !`...` 가 스크립트를 먼저 실행해서
    │   결과를 프롬프트에 붙인다. LLM 은 이미 사실을 손에 들고 시작한다.
    ▼
 ② bin/mh-changes               ← 사실 수집 (LLM 관여 없음)
    │   MH_CHANGES_PROTO: 1
    │   BRANCH: main
    │   INSERTIONS: 120
    │   SECRET_SUSPECT: 1
    │   MH_CHANGES_OK
    ▼
 ③ skills/checkup/SKILL.md      ← 절차·판단
    │   "SECRET_SUSPECT 가 0 이 아니면 그것부터 보고한다"
    │   "TOUCHED_TOP_DIRS 가 섞였으면 커밋을 나누자고 제안한다"
    │   숫자는 다시 세지 않는다. 판단만 한다.
    ▼
 ④ 사용자가 커밋 실행
    │
    ▼
 ⑤ hooks/guard.py               ← 가드레일 (실행 직전)
        main 브랜치 커밋 → 차단
        git push --force  → 차단
```

---

## 네 가지 교훈

### 1. 검증 가능한 것은 LLM 에게 시키지 않는다

`bin/mh-changes` 가 하는 일은 전부 세고 찾는 일이다. 판단이 없다.

LLM 에게 "몇 줄 바뀌었어?"를 물으면 매번 조금씩 다르게 답한다.
`git diff --shortstat` 은 언제나 같은 숫자를 준다.

> **경계선:** 셀 수 있으면 스크립트. 셀 수 없으면 LLM.
> "120줄 바뀜"은 스크립트. "이건 한 커밋으로 묶어도 된다"는 LLM.

이 원칙 하나가 하네스 품질의 대부분을 결정한다.

### 2. 출력은 `KEY: value` 로 준다

```
INSERTIONS: 120          ← LLM 이 그대로 읽는다
```
```
총 120줄이 추가되었습니다   ← LLM 이 요약하다가 118 로 바꾼다
```

산문으로 주면 LLM 이 다시 가공한다. 가공하면 숫자가 변한다.
`MH_CHANGES_PROTO: 1` / `MH_CHANGES_OK` 는 봉투다 —
앞줄로 버전을 알고, 끝줄이 없으면 스크립트가 죽은 것을 안다.

### 3. 스킬은 프롬프트가 아니라 절차서다

`SKILL.md` 를 열어 보면 "당신은 유능한 개발자입니다" 같은 문장이 없다.
대신 **순서**와 **판단 기준**과 **하지 말 것**이 있다.

```
❌  "좋은 커밋 메시지를 작성해주세요"
✅  "git log --oneline -10 으로 이 저장소의 기존 스타일을 먼저 본다.
     접두사를 쓰는 저장소면 쓰고, 한국어로 쓰는 저장소면 한국어로 쓴다."
```

역할 부여는 잘 안 듣는다. 절차는 듣는다.

### 4. 훅은 협상 대상이 아니다

`SKILL.md` 에 "main 에 직접 커밋하지 마라"라고 써두면 **대체로** 지킨다.
대체로. 사용자가 재촉하면 LLM 은 스스로를 설득할 수 있다.

`hooks/guard.py` 는 프롬프트가 아니라 코드다. 설득되지 않는다.

> **훅을 남발하지 마라.** 되돌릴 수 있는 일은 스킬에 맡기고,
> 되돌릴 수 없는 일만 훅으로 막는다. 훅이 많으면 에이전트가 아무 일도 못 한다.

그리고 훅은 **샌드박스가 아니다.** 정규식이지 셸 파서가 아니라서
변수 확장이나 별칭으로 우회된다. 실수를 막는 과속방지턱이지 보안 경계가 아니다.
(이 한계는 `guard.py` 주석에도 적혀 있다 — 학생이 직접 뚫어보게 해도 좋다.)

---

## 설치

### 수강생 절차

**1. VS Code 설치** — [code.visualstudio.com](https://code.visualstudio.com). 1.94.0 이상.

**2. Claude Code 확장 설치** — `Ctrl+Shift+X` → `Claude Code` 검색 → **Install**.

**3. 로그인** — 유료 Claude 구독(Pro·Max·Team·Enterprise) 또는 Console 계정. API 키는 필요 없다.

**4. 하네스 설치** — VS Code 통합 터미널(`` Ctrl+` ``)에서 두 줄:

```bash
claude plugin marketplace add choki0715/mini-harness
claude plugin install mini-harness@mini-harness-demo
```

**5. 플러그인 로드** — 채팅창에 `/reload-plugins`.

**6. 실습**

```
/mini-harness:demo
/mini-harness:checkup /tmp/checkup-demo
```

**`git clone` 은 필요 없다.** 실습 저장소 생성기(`mh-demo-repo`)가 플러그인의
`bin/` 에 들어 있고, 플러그인의 `bin/` 은 켜져 있는 동안 PATH 에 올라간다.
`/mini-harness:demo` 가 그것을 부른다.

> `claude` 명령은 확장을 깔아도 PATH 에 생기지 않는다. 확장은 채팅 패널용
> CLI 를 내부에 따로 갖고 있을 뿐이다. 4번을 쓰려면
> [CLI 를 따로 설치](https://code.claude.com/docs/en/setup)해야 한다.
> CLI 없이 가려면 아래 `install.sh` 경로를 쓴다.

### 플러그인으로 설치하려면 — 터미널이 필요하다

플러그인 관리 명령은 **대화형 패널을 여는 명령**이라, VS Code 확장의 채팅 패널에서는
동작하지 않는다. `/plugin` 이나 `/plugins` 를 치면 이렇게 나온다:

```
… opens an interactive panel and isn't available in this environment.
  Run it from the Claude Code terminal instead.
```

**기능이 없는 게 아니라 그 세션이 패널을 못 여는 것이다.** 터미널에서는 된다.

| 어디서 | 무엇을 |
|---|---|
| VS Code 통합 터미널 | `claude plugin marketplace add …` — 대화창을 안 띄우는 셸 명령. 제일 간단하다 |
| 터미널에서 `claude` 실행 후 | `/plugin marketplace add …` — 대화형 TUI |
| 확장 설정 **Use Terminal** 켜기 | 채팅 패널이 CLI 형태로 바뀌어 `/plugin` 이 동작한다 |

셸에서:

```bash
claude plugin marketplace add choki0715/mini-harness
claude plugin install mini-harness@mini-harness-demo
```

설치 후 커맨드 이름에 플러그인 이름이 붙는다: `/mini-harness:checkup`.

> `claude` 명령은 확장을 깔아도 PATH 에 생기지 않는다. 확장은 채팅 패널용 CLI 를
> 내부에 따로 갖고 있을 뿐이다. 셸에서 쓰려면
> [CLI 를 따로 설치](https://code.claude.com/docs/en/setup)한다.
> **수업에서는 이 의존성을 피하려고 위의 `install.sh` 경로를 기본으로 쓴다.**

### 걷어내기

```bash
rm ~/.claude/commands/checkup.md ~/.claude/skills/checkup   # install.sh 로 깐 경우
claude plugin uninstall mini-harness@mini-harness-demo      # 플러그인으로 깐 경우
claude plugin marketplace remove mini-harness-demo
```

**여러 경로로 동시에 설치하지 않는다.** 커맨드가 중복된다.

### 훅은 실습 저장소에서만 돈다

훅은 설치하면 **모든 프로젝트, 모든 세션**에서 돈다.
이 예제의 가드레일은 `main`/`master` 커밋을 막으므로, 범위가 없으면
평소 main 에서 작업하는 저장소의 커밋까지 막힌다. **수업 자료가 실무를 막는다.**

그래서 `guard.py` 는 **스스로 대상인지 확인하고 아니면 조용히 비켜선다.**

```
저장소 루트에 .mini-harness-demo 가 있다   → 가드레일 동작
환경변수 MINI_HARNESS_GUARD=1              → 가드레일 동작
둘 다 아니다                                → 아무것도 하지 않는다
```

`mh-demo-repo`(플러그인 `bin/`)가 실습 저장소에 그 마커를 만든다.
그래서 전역으로 설치해도 실무 저장소는 영향이 없다.

> **가드레일에는 범위를 준다.**
>
> 이 예제의 첫 버전에는 이게 없었다. "훅은 협상 대상이 아니다"라는 교훈이
> 흐려질까 봐 뺐는데, 설치해 보니 작성자 본인의 저장소 네 곳에서
> 커밋이 막혔다. 범위를 주는 것과 설득되지 않는 것은 다른 이야기다 —
> **어디를 지킬지는 설계로 정하고, 지키기로 한 곳에서는 타협하지 않는다.**

### 걷어내기

```bash
claude plugin uninstall mini-harness@mini-harness-demo    # 플러그인
claude plugin marketplace remove mini-harness-demo        # 마켓플레이스
rm ~/.claude/commands/checkup.md ~/.claude/skills/checkup  # install.sh 로 깐 경우
```

확장에서는 `/plugins` → 토글로 끄거나 마켓플레이스 탭의 휴지통 아이콘.

**여러 경로로 동시에 설치하지 않는다.** 커맨드가 중복된다.

## 직접 해보기

```bash
# 1. 실습 저장소를 만든다 — 학생 전원이 똑같은 상태에서 시작한다
mh-demo-repo

# 2. LLM 없이 스크립트만 먼저 돌려본다
cd /tmp/checkup-demo && ~/mini-harness/mini-harness/bin/mh-changes

# 3. 이제 Claude Code 에서
/checkup
```

2번을 먼저 시키는 게 중요하다. **하네스의 절반은 LLM 없이 도는 코드**라는 걸
눈으로 보고 나면, 3번에서 LLM 이 무엇을 더한 것인지가 분명해진다.

실습 저장소에는 함정이 하나 심어져 있다. `docs/setup.md` 의 비밀번호는
**untracked 파일**에 있어서 `git diff HEAD` 로는 보이지 않는다.
이 예제의 첫 버전은 실제로 이걸 놓쳤다 (`test/run-tests.sh` 에 회귀 테스트가 있다).

### 테스트

```bash
./test/run-tests.sh     # 30개
```

스킬(마크다운)은 출력이 매번 달라 테스트하기 어렵다.
하지만 스크립트와 훅은 결정적이라 전부 테스트할 수 있다.
**하네스에서 스크립트로 뺀 면적이 넓어질수록 테스트할 수 있는 면적도 넓어진다.**
이게 스크립트로 빼는 두 번째 이유다 (첫 번째는 숫자가 흔들리지 않는 것).

### 학생 과제로 좋은 것

1. `mh-changes` 에 **새 사실 하나**를 추가한다 (예: 가장 크게 바뀐 파일)
   → 스킬에 그 판단 규칙도 같이 추가해야 값이 생긴다는 걸 체감한다
2. `guard.py` 의 정규식을 **우회해 본다**
   → 훅이 보안 경계가 아니라는 걸 손으로 확인한다
3. 스킬에서 "커밋을 나누는 기준"을 **자기 팀 기준으로** 바꾼다
   → 하네스는 팀의 관습을 코드로 굳히는 도구라는 걸 안다

---

## 구조

```
mini-harness/
├── README.md                      ← 지금 읽는 문서
├── LICENSE
├── install.sh                     ← /plugin 없는 환경용
├── test/
│   └── run-tests.sh               ← 30개. 하네스도 코드다
├── .claude-plugin/
│   └── marketplace.json           ← 이 저장소가 마켓플레이스
└── mini-harness/                  ← 플러그인 본체
    ├── .claude-plugin/plugin.json
    ├── commands/
    │   ├── checkup.md             ① 진입점
    │   └── demo.md                실습 저장소 만들기
    ├── bin/
    │   ├── mh-changes             ② 사실 수집
    │   └── mh-demo-repo           실습 저장소 생성 (PATH 에 올라감)
    ├── skills/checkup/SKILL.md    ③ 절차·판단
    └── hooks/
        ├── hooks.json             ④ 훅 등록
        └── guard.py                  가드레일
```

---

## 여기서 다루지 않은 것

의도적으로 뺐다. 파일 4개라는 크기를 지키기 위해서다.

- **서브에이전트** — 격리된 컨텍스트에서 같은 작업을 반복시키는 장치.
  실물 예: 문항 하나를 전 학생 답안에 대해 같은 기준으로 채점하는 에이전트
- **라우터 스킬** — 커맨드가 10개를 넘어가면 "어느 걸 써야 하나"가 문제가 된다.
  gstack 은 `/gstack` 하나가 요청을 61개 스킬로 분배한다
- **세션 상태** — gstack 은 모든 스킬이 같은 스크립트로 시작해 상태 라인을 받는다.
  스킬이 늘어날수록 이 공통 진입점의 값이 커진다
- **템플릿 생성** — gstack 의 `SKILL.md` 는 손으로 쓰지 않는다. `.tmpl` 에서 생성한다.
  스킬 4개엔 과하고, 60개엔 필수다

**규모가 커지고 나서 도입한다.** 처음부터 넣으면 배보다 배꼽이 커진다.
