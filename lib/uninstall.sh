#!/usr/bin/env bash

set -euo pipefail

# ── Logging ───────────────────────────────────────────────────────────────────
oml_info()    { printf '\033[1;34m==>\033[0m %b\n' "$1"; }
oml_success() { printf '\033[1;32m==>\033[0m %b\n' "$1"; }
oml_warn()    { printf '\033[1;33m==>\033[0m %b\n' "$1"; }
oml_error()   { printf '\033[1;31m==> Error:\033[0m %b\n' "$1" >&2; }

# ── Main Uninstallation ───────────────────────────────────────────────────────
main() {
  oml_info "Starting uninstallation of oh-my-longfor, OpenCode, and oh-my-opencode..."

  # 1. Remove OpenCode binaries and config
  local opencode_dirs=(
    "$HOME/.opencode"
    "$HOME/.config/opencode"
    "$HOME/.claude/skills"
  )
  for dir in "${opencode_dirs[@]}"; do
    if [ -d "$dir" ] || [ -L "$dir" ]; then
      oml_info "Removing $dir..."
      rm -rf "$dir"
    fi
  done

  # 2. Remove oh-my-opencode package
  if command -v bun >/dev/null 2>&1; then
    oml_info "Removing oh-my-opencode via bun..."
    bun remove -g oh-my-opencode >/dev/null 2>&1 || true
  fi
  if [ -f "$HOME/.bun/bin/oh-my-opencode" ]; then
    rm -f "$HOME/.bun/bin/oh-my-opencode"
  fi

  # 3. Remove OML Home
  local oml_home="${OML_HOME:-$HOME/.oml}"
  if [ -d "$oml_home" ]; then
    oml_info "Removing $oml_home..."
    rm -rf "$oml_home"
  fi

  oml_success "Uninstallation complete!"
  
  # Determine current shell RC to tell user to reload
  local current_shell
  current_shell="$(basename "$SHELL" 2>/dev/null || echo "bash")"
  
  printf "\n"
  oml_warn "IMPORTANT: Manual cleanup required!"
  oml_warn "Please open your shell configuration (e.g., ~/.zshrc or ~/.bashrc) and remove lines containing:"
  oml_warn "  - oh-my-longfor"
  oml_warn "  - opencode"
  oml_warn "  - ~/.oml"
  printf "\n"
  oml_info "After that, restart your terminal or run: exec \"$current_shell\" -l"
}

main "$@"
