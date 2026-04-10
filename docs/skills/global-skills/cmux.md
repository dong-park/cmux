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
- Memo:
  `workspace-memo get`, `workspace-memo set`, `workspace-memo append`, `workspace-memo clear`
- History (전역, ~/Documents/cmux/history.json):
  `history add`, `history list`, `history summary`, `history clear`, `history open`

## Memo notes

- `workspace-memo set` replaces the memo.
- `workspace-memo append` appends to the existing memo and inserts one newline if needed.
- There is currently no CLI command that opens the memo surface UI.

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
