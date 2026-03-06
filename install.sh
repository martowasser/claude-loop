#!/usr/bin/env bash
set -euo pipefail

# claude-orchestrator installer
# Drops orchestration agents and config into any project's .claude/ directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"
CLAUDE_DIR="$TARGET_DIR/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"

echo "claude-orchestrator: installing into $TARGET_DIR"
echo ""

# Check if target is a valid directory
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: $TARGET_DIR is not a directory"
  exit 1
fi

# Create .claude/agents/ if it doesn't exist
mkdir -p "$AGENTS_DIR"

# Copy agent definitions
AGENTS=(researcher implementer reviewer planner)
for agent in "${AGENTS[@]}"; do
  src="$SCRIPT_DIR/.claude/agents/$agent.md"
  dest="$AGENTS_DIR/$agent.md"

  if [ -f "$dest" ]; then
    echo "  SKIP  agents/$agent.md (already exists)"
  else
    cp "$src" "$dest"
    echo "  ADD   agents/$agent.md"
  fi
done

# Copy orchestration rules
ORCH_SRC="$SCRIPT_DIR/.claude/orchestration.md"
ORCH_DEST="$CLAUDE_DIR/orchestration.md"

if [ -f "$ORCH_DEST" ]; then
  echo "  SKIP  orchestration.md (already exists)"
else
  cp "$ORCH_SRC" "$ORCH_DEST"
  echo "  ADD   orchestration.md"
fi

# Add @import to CLAUDE.md if not already present
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"
IMPORT_LINE='@import .claude/orchestration.md'

if [ -f "$CLAUDE_MD" ]; then
  if grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
    echo "  SKIP  CLAUDE.md (import already present)"
  else
    echo "" >> "$CLAUDE_MD"
    echo "$IMPORT_LINE" >> "$CLAUDE_MD"
    echo "  ADD   @import to CLAUDE.md"
  fi
else
  echo "$IMPORT_LINE" > "$CLAUDE_MD"
  echo "  ADD   CLAUDE.md with @import"
fi

# Symlink claude-loop into the project (or user's PATH)
LOOP_SRC="$SCRIPT_DIR/claude-loop"
LOOP_DEST="$TARGET_DIR/claude-loop"

if [ -f "$LOOP_DEST" ]; then
  echo "  SKIP  claude-loop (already exists)"
else
  cp "$LOOP_SRC" "$LOOP_DEST"
  chmod +x "$LOOP_DEST"
  echo "  ADD   claude-loop"
fi

# Add claude-loop and state file to gitignore
GITIGNORE="$TARGET_DIR/.gitignore"
for entry in ".claude/state.md" ".claude/progress.md" ".claude/progress_*.md" ".claude/signal" ".claude/feedback.md" ".claude/scratch/" ".claude/loop.pid" ".claude/loop.log" ".claude/agent-memory-local/" "claude-loop"; do
  if [ -f "$GITIGNORE" ] && grep -qF "$entry" "$GITIGNORE"; then
    :
  else
    echo "$entry" >> "$GITIGNORE"
    echo "  ADD   $entry to .gitignore"
  fi
done

echo ""
echo "Done. Installed:"
echo "  .claude/agents/researcher.md   — read-only codebase explorer (Sonnet)"
echo "  .claude/agents/implementer.md  — code writer in isolated worktree (Sonnet)"
echo "  .claude/agents/reviewer.md     — code reviewer and test runner (Sonnet)"
echo "  .claude/agents/planner.md      — architectural planner (Opus)"
echo "  .claude/orchestration.md       — orchestration rules (@imported into CLAUDE.md)"
echo "  claude-loop                    — infinite session runner"
echo ""
echo "Two ways to use:"
echo ""
echo "  1. Interactive:  claude          (orchestrator mode via CLAUDE.md)"
echo "  2. Autonomous:   ./claude-loop \"your task here\""
