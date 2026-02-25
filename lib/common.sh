#!/usr/bin/env bash
# oh-my-longfor common utilities
set -euo pipefail

# Default OML home directory
OML_HOME="${OML_HOME:-$HOME/.oml}"
OML_LOCK_FILE="${OML_HOME}/.lock"
export OML_VERSION="0.1.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
export BOLD='\033[1m'
NC='\033[0m' # No Color

# Print an info message
oml_info() {
  printf "${BLUE}[oml]${NC} %s\n" "$*"
}

# Print a warning message
oml_warn() {
  printf "${YELLOW}[oml] WARNING:${NC} %s\n" "$*" >&2
}

# Print an error message
oml_error() {
  printf "${RED}[oml] ERROR:${NC} %s\n" "$*" >&2
}

# Print a success message
oml_success() {
  printf "${GREEN}[oml] ✓${NC} %s\n" "$*"
}

# Detect the current platform (darwin/linux)
oml_detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

# Check that required dependencies are installed
# Usage: oml_check_deps git curl bun
oml_check_deps() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    oml_error "Missing required dependencies: ${missing[*]}"
    oml_error "Please install them and try again."
    return 1
  fi
  return 0
}

# Acquire the oml concurrency lock
# Usage: oml_lock_acquire
oml_lock_acquire() {
  local lock_dir
  lock_dir="$(dirname "$OML_LOCK_FILE")"
  mkdir -p "$lock_dir"

  if [ -f "$OML_LOCK_FILE" ]; then
    local existing_pid
    existing_pid="$(cat "$OML_LOCK_FILE" 2>/dev/null || echo "")"
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
      oml_error "Another oml process is running (PID: $existing_pid). Please wait."
      return 1
    else
      # Stale lock — remove it
      oml_warn "Removing stale lock file (PID: $existing_pid)"
      rm -f "$OML_LOCK_FILE"
    fi
  fi

  echo "$$" > "$OML_LOCK_FILE"
  return 0
}

# Release the oml concurrency lock
# Usage: oml_lock_release
oml_lock_release() {
  if [ -f "$OML_LOCK_FILE" ]; then
    local lock_pid
    lock_pid="$(cat "$OML_LOCK_FILE" 2>/dev/null || echo "")"
    if [ "$lock_pid" = "$$" ]; then
      rm -f "$OML_LOCK_FILE"
    fi
  fi
}
