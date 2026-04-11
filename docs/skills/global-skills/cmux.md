---
name: cmux
description: Use this skill when the user wants to control the cmux app from the terminal, inspect or manipulate windows, workspaces, panes, or surfaces, send terminal input, read terminal output, open or use cmux browser surfaces, or manage workspace memos. Prefer this skill whenever the task can be solved with `cmux` or `cmux-dev` instead of manual UI clicking.
tools: Bash, Read, Grep
---

# cmux CLI

Use the cmux CLI to control the running cmux app over its Unix socket.

## Executable choice

- Prefer `cmux-dev` when it exists and the task targets a tagged Debug build or local development session.
- Otherwise use `cmux`.
- If unsure which executable is active, check `command -v cmux-dev || command -v cmux`.

## Working rules

- Inspect before mutating. Start with `current-workspace`, `tree --all`, `list-workspaces`, or `list-panes`.
- Prefer explicit handles such as `window:1`, `workspace:2`, `pane:3`, and `surface:4` over bare numeric indexes.
- When the user names a specific workspace, pane, or surface, pass the matching `--workspace`, `--pane`, or `--surface` flag explicitly.
- For browser work that should happen inside cmux, use cmux browser panes or surfaces instead of external browser tooling.
- For workspace memo content, use the CLI. Opening the memo surface itself is currently a UI action, not a CLI command.

## Typical workflow

1. Resolve the executable:

```bash
CMUX="$(command -v cmux-dev || command -v cmux)"
```

2. Inspect the current state:

```bash
"$CMUX" current-workspace
"$CMUX" tree --all
"$CMUX" list-panes
```

3. Apply a targeted command with explicit refs:

```bash
"$CMUX" focus-pane --pane pane:2 --workspace workspace:1
"$CMUX" send --surface surface:3 --workspace workspace:1 "pytest -q"
```

## High-value commands

- Layout and discovery:
  `tree --all`, `identify`, `list-windows`, `list-workspaces`, `list-panes`
- Workspace control:
  `new-workspace`, `select-workspace`, `rename-workspace`, `close-workspace`
- Pane and surface control:
  `new-pane`, `new-surface`, `new-split`, `focus-pane`, `close-surface`
- Terminal I/O:
  `read-screen`, `send`, `send-key`
- Browser:
  `new-pane --type browser`, `new-surface --type browser`
- Workspace Memo:
  `workspace-memo get`, `workspace-memo set`, `workspace-memo append`, `workspace-memo clear`
- Global Memo (앱 전역):
  `global-memo get`, `global-memo set`, `global-memo append`, `global-memo clear`
- Folder Memo (프로젝트/폴더별):
  `folder-memo get`, `folder-memo set`, `folder-memo append`, `folder-memo clear`
- History (전역, ~/Documents/cmux/history.json):
  `history add`, `history list`, `history summary`, `history clear`, `history open`

## Memo notes

### Workspace Memo
- `workspace-memo set` replaces the memo.
- `workspace-memo append` appends to the existing memo and inserts one newline if needed.
- There is currently no CLI command that opens the memo surface UI.

### Global Memo
- `global-memo get/set/append/clear` — 모든 workspace에서 공유되는 전역 메모.
- UI: 사이드바 하단 푸터의 메모 아이콘 버튼 → 팝오버로 편집.
- 저장: UserDefaults (`cmux.globalMemo`).

### Folder Memo
- `folder-memo get/set/append/clear [--directory <path>]` — 프로젝트(폴더) 단위 메모.
- `--directory` 생략 시 현재 작업 디렉토리(cwd)를 기본값으로 사용.
- UI: 사이드바 폴더 그룹 헤더의 메모 아이콘으로 존재 여부 확인.
- 저장: UserDefaults (`cmux.folderMemos` dictionary, key=directory path).

### 메모 계층 활용 지침 (도메인 지식 플라이휠)

삽질/되돌림/교훈을 적절한 레벨에 축적하여 반복을 방지합니다:

| 교훈 범위 | 저장 위치 | 시점 |
|-----------|-----------|------|
| 이 코드베이스 특화 (파일 구조, 규칙, pitfall) | `folder-memo` | build 삽질 직후, feedback 분류 후 |
| 프로젝트 무관 범용 (기술 스택, 설계 패턴) | `global-memo` | build 삽질 직후, feedback 분류 후 |
| 현재 작업 진행 상황 | `workspace-memo` | 각 phase 완료마다 |

**읽는 시점:** dev-flow 초기화, plan 시작, build 시작 시 반드시 `folder-memo get` + `global-memo get` 실행.
**쓰는 시점:** 삽질 발생 직후 (나중에 모아서 하면 디테일 날아감), ship 완료 후, feedback 분류 후.

## History notes

- `history add --type <type> --summary <text> [--phase <phase>] [--tags <t1,t2>]` — 전역 이력에 항목 추가
- `history list [--type X] [--phase X] [--tag X] [--cwd .] [--since 7d] [--limit N]` — 필터링 조회
- `history summary` — 전체 요약 (한 줄)
- `history open` — History 패널을 현재 workspace에 열기
- History는 workspace가 아닌 앱 전역에 저장됨 (workspace 닫혀도 유지)
- type: decision, task, feedback, pattern, phase, note
- `--cwd .`은 현재 workspace의 cwd로 필터링

## Reference

For the fuller command map and examples, read [references/cli-reference.md](references/cli-reference.md).
