#!/usr/bin/env bash
export COMPILE_USE_ANTHROPIC="true"

MEMORY_DIR="$HOME/dev/agentic-memory-compiler"

if [[ ! -d "$MEMORY_DIR" ]]; then
  echo "ERROR: agentic-memory-compiler not found at $MEMORY_DIR"
  exit 1
fi

cd "$MEMORY_DIR"
exec uv run python scripts/compile.py "$@"
