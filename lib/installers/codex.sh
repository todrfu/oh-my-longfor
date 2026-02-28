#!/usr/bin/env bash

# ── Install Codex CLI (with reinstall confirmation if exists) ──────────────────
_ensure_codex() {
  local should_install=true
  
  if command -v codex >/dev/null 2>&1; then
    local version
    version="$(codex --version 2>/dev/null || echo 'unknown version')"
    oml_warn "codex cli is already installed: $version"
    
    if _is_interactive; then
      printf "%s" "Reinstall codex cli? [y/N] " >/dev/tty
      if ! read -r answer </dev/tty; then
        echo
        oml_error "Installation aborted by user."
        exit 130
      fi
      if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        oml_info "Skipping codex cli installation."
        should_install=false
      fi
    else
      oml_info "Non-interactive mode: skipping codex cli reinstallation."
      should_install=false
    fi
  fi

  if [ "$should_install" = true ]; then
    # Codex requires bun (or npm) to install
    _ensure_bun || return 1
    
    oml_info "Installing codex cli via bun..."
    # Note: Using codex-cli as the package name based on documentation
    if bun install -g @openai/codex-cli; then
      oml_success "codex cli installed."
    else
      oml_error "codex cli install failed. Please install manually."
      return 1
    fi
  else
    oml_success "Using existing codex cli installation."
  fi
}

# ── Main Entrypoint for Tool Installation ──────────────────────────────────────
_install_tool() {
  _ensure_codex
}
