#!/usr/bin/env bash
#
# oh-my-longfor uninstaller
# Removes oml itself while preserving AI tools (opencode/claude-code/codex) and their configurations

set -euo pipefail

# ── Logging ───────────────────────────────────────────────────────────────────
oml_info()    { printf '\033[1;34m==>\033[0m %b\n' "$1"; }
oml_success() { printf '\033[1;32m==>\033[0m %b\n' "$1"; }
oml_warn()    { printf '\033[1;33m==>\033[0m %b\n' "$1"; }
oml_error()   { printf '\033[1;31m==> Error:\033[0m %b\n' "$1" >&2; }

# ── Remove skill symlinks (but preserve source skills in ~/.oml/skills) ───────
_remove_skill_symlinks() {
  local skill_dirs=(
    "$HOME/.config/opencode/skills"
    "$HOME/.claude/skills"
    "$HOME/.codex/skills"
  )
  
  for skill_dir in "${skill_dirs[@]}"; do
    if [ -d "$skill_dir" ]; then
      oml_info "Removing skill symlinks from $skill_dir..."
      find "$skill_dir" -maxdepth 1 -type l -delete 2>/dev/null || true
    fi
  done
}

# ── Main Uninstallation ───────────────────────────────────────────────────────
main() {
  oml_info "Starting uninstallation of oh-my-longfor (oml)..."
  oml_info "AI tools (opencode/claude-code/codex) and their configs will be preserved."
  printf "\n"

  # 1. Remove skill symlinks (preserve source skills for manual backup)
  _remove_skill_symlinks

  # 2. Remove OML Home
  local oml_home="${OML_HOME:-$HOME/.oml}"
  if [ -d "$oml_home" ]; then
    oml_warn "About to remove $oml_home (contains team configs and skill sources)"
    oml_warn "If you want to keep skill sources, backup ~/.oml/skills/ now."
    printf "\n"
    
    if [ -t 0 ]; then
      printf "Continue with removal? [y/N] "
      read -r answer
      if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        oml_info "Uninstallation cancelled."
        exit 0
      fi
    fi
    
    oml_info "Removing $oml_home..."
    rm -rf "$oml_home"
  fi

  oml_success "oh-my-longfor (oml) has been uninstalled!"
  
  # Determine current shell RC to tell user to reload
  local current_shell
  current_shell="$(basename "$SHELL" 2>/dev/null || echo "bash")"
  
  printf "\n"
  oml_warn "IMPORTANT: Manual cleanup required!"
  oml_warn "Please open your shell configuration (e.g., ~/.zshrc or ~/.bashrc) and remove lines containing:"
  oml_warn "  - oh-my-longfor"
  oml_warn "  - ~/.oml"
  oml_warn "  - OML_HOME"
  printf "\n"
  oml_info "Your AI tools (opencode/claude-code/codex) and their configurations remain intact."
  oml_info "After cleanup, restart your terminal or run: exec \"$current_shell\" -l"
}

main "$@"
