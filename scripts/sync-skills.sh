#!/usr/bin/env bash
set -euo pipefail

# docs/skills/ 의 정의 파일들을 실제 Claude Code 설치 경로에 동기화합니다.
#
# 소스 구조:
#   docs/skills/global-skills/<name>.md   → ~/.claude/skills/<name>/SKILL.md
#   docs/skills/global-commands/<name>.md → ~/.claude/commands/<name>.md
#   docs/skills/project-skills/<name>.md  → .claude/skills/<name>.md
#   docs/skills/project-commands/<name>.md→ .claude/commands/<name>.md
#
# Usage:
#   ./scripts/sync-skills.sh           # 전체 동기화
#   ./scripts/sync-skills.sh --dry-run # 변경사항만 출력
#   ./scripts/sync-skills.sh --diff    # diff 보기

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs/skills"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
GLOBAL_COMMANDS_DIR="$HOME/.claude/commands"
PROJECT_SKILLS_DIR="$REPO_ROOT/.claude/skills"
PROJECT_COMMANDS_DIR="$REPO_ROOT/.claude/commands"

DRY_RUN=0
SHOW_DIFF=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --diff)    SHOW_DIFF=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/sync-skills.sh [options]

docs/skills/ 의 스킬/커맨드 정의를 Claude Code 설치 경로에 동기화합니다.

Options:
  --dry-run   실제 복사 없이 변경사항만 출력
  --diff      변경되는 파일의 diff 출력
  -h, --help  도움말
EOF
      exit 0
      ;;
    *) echo "error: unknown option $1" >&2; exit 1 ;;
  esac
done

UPDATED=0
SKIPPED=0
CREATED=0

sync_file() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [[ ! -f "$src" ]]; then
    return
  fi

  local dst_dir
  dst_dir="$(dirname "$dst")"

  if [[ -f "$dst" ]]; then
    if diff -q "$src" "$dst" >/dev/null 2>&1; then
      SKIPPED=$((SKIPPED + 1))
      return
    fi
    if [[ "$SHOW_DIFF" -eq 1 ]]; then
      echo "--- $label ---"
      diff -u "$dst" "$src" || true
      echo ""
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [update] $label"
      echo "           $src → $dst"
    else
      mkdir -p "$dst_dir"
      cp "$src" "$dst"
      echo "  [update] $label"
    fi
    UPDATED=$((UPDATED + 1))
  else
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [create] $label"
      echo "           $src → $dst"
    else
      mkdir -p "$dst_dir"
      cp "$src" "$dst"
      echo "  [create] $label"
    fi
    CREATED=$((CREATED + 1))
  fi
}

echo "=== Sync skills & commands ==="
echo ""

# --- Global skills: docs/skills/global-skills/<name>.md → ~/.claude/skills/<name>/SKILL.md ---
echo "Global skills (→ ~/.claude/skills/):"
if [[ -d "$DOCS_DIR/global-skills" ]]; then
  for src in "$DOCS_DIR/global-skills/"*.md; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src" .md)"
    sync_file "$src" "$GLOBAL_SKILLS_DIR/$name/SKILL.md" "$name"
  done
else
  echo "  (no source: $DOCS_DIR/global-skills/)"
fi

# --- Global commands: docs/skills/global-commands/<name>.md → ~/.claude/commands/<name>.md ---
echo ""
echo "Global commands (→ ~/.claude/commands/):"
if [[ -d "$DOCS_DIR/global-commands" ]]; then
  for src in "$DOCS_DIR/global-commands/"*.md; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    sync_file "$src" "$GLOBAL_COMMANDS_DIR/$name" "$name"
  done
else
  echo "  (no source: $DOCS_DIR/global-commands/)"
fi

# --- Project skills: docs/skills/project-skills/<name>.md → .claude/skills/<name>.md ---
echo ""
echo "Project skills (→ .claude/skills/):"
if [[ -d "$DOCS_DIR/project-skills" ]]; then
  for src in "$DOCS_DIR/project-skills/"*.md; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    sync_file "$src" "$PROJECT_SKILLS_DIR/$name" "$name"
  done
else
  echo "  (no source: $DOCS_DIR/project-skills/)"
fi

# --- Project commands: docs/skills/project-commands/<name>.md → .claude/commands/<name>.md ---
echo ""
echo "Project commands (→ .claude/commands/):"
if [[ -d "$DOCS_DIR/project-commands" ]]; then
  for src in "$DOCS_DIR/project-commands/"*.md; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    sync_file "$src" "$PROJECT_COMMANDS_DIR/$name" "$name"
  done
else
  echo "  (no source: $DOCS_DIR/project-commands/)"
fi

echo ""
echo "=== Done ==="
echo "  created: $CREATED"
echo "  updated: $UPDATED"
echo "  unchanged: $SKIPPED"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "(dry-run: no files were modified)"
fi
