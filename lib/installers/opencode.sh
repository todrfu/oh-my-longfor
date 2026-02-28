#!/usr/bin/env bash

# ── Install OpenCode (with reinstall confirmation if exists) ──────────────────
_ensure_opencode() {
  local should_install=true
  
  if command -v opencode >/dev/null 2>&1; then
    local version
    version="$(opencode --version 2>/dev/null || echo 'unknown version')"
    oml_warn "opencode is already installed: $version"
    
    if _is_interactive; then
      printf "%s" "Reinstall opencode? [y/N] " >/dev/tty
      if ! read -r answer </dev/tty; then
        echo
        oml_error "Installation aborted by user."
        exit 130
      fi
      if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        oml_info "Skipping opencode installation."
        should_install=false
      fi
    else
      oml_info "Non-interactive mode: skipping opencode reinstallation."
      should_install=false
    fi
  fi

  if [ "$should_install" = true ]; then
    oml_info "Installing opencode via official installer..."
    # opencode ships as a standalone binary — does NOT require bun or npm
    # Official installer: https://opencode.ai/install
    curl -fsSL https://opencode.ai/install | bash
    # Reload PATH (installer places binary in ~/.opencode/bin)
    export PATH="$HOME/.opencode/bin:$PATH"
    if ! command -v opencode >/dev/null 2>&1; then
      oml_error "opencode install failed. Please install manually: https://opencode.ai"
      return 1
    fi
    oml_success "opencode installed."
  else
    oml_success "Using existing opencode installation."
  fi
}

# ── Install oh-my-opencode (with reinstall confirmation if exists) ────────────
_ensure_omo() {
  # Detection: oh-my-opencode registers itself as a plugin in opencode.json
  local oc_json="$HOME/.config/opencode/opencode.json"
  local should_install=true
  
  if [ -f "$oc_json" ] && grep -q '"oh-my-opencode"' "$oc_json" 2>/dev/null; then
    oml_warn "oh-my-opencode is already installed."
    
    if _is_interactive; then
      printf "%s" "Reinstall oh-my-opencode? [y/N] " >/dev/tty
      if ! read -r answer </dev/tty; then
        echo
        oml_error "Installation aborted by user."
        exit 130
      fi
      if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        oml_info "Skipping oh-my-opencode installation."
        should_install=false
      fi
    else
      oml_info "Non-interactive mode: skipping oh-my-opencode reinstallation."
      should_install=false
    fi
  fi

  if [ "$should_install" = false ]; then
    oml_success "Using existing oh-my-opencode installation."
    return 0
  fi

  # Ensure bun is installed (automatic, no confirmation)
  _ensure_bun || return 1

  oml_info "Installing oh-my-opencode plugin..."
  if _is_interactive; then
    if [ "$_OML_STDIN_WAS_TTY" = true ]; then
      # Normal mode (bash install.sh): stdin is already a real TTY
      bunx oh-my-opencode install
    elif command -v script >/dev/null 2>&1; then
      # curl|bash mode: TUI needs a pty for raw keyboard input.
      # Use script(1) to allocate a real pseudo-terminal.
      oml_info "Allocating pty for interactive TUI..."
      if script -q /dev/null true </dev/null >/dev/null 2>&1; then
        script -q /dev/null bunx oh-my-opencode install </dev/tty
      else
        script -q -c "bunx oh-my-opencode install" /dev/null </dev/tty
      fi
      # Restore terminal after script(1) — it may leave raw/noecho mode
      stty sane 2>/dev/null || true
    else
      # Fallback: try /dev/tty redirect (may not support raw input)
      bunx oh-my-opencode install </dev/tty >/dev/tty 2>&1
    fi
  else
    # Non-interactive: safe defaults, user can reconfigure later
    bunx oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=no
  fi
  oml_success "oh-my-opencode installed."
}

# ── Main Entrypoint for Tool Installation ──────────────────────────────────────
_install_tool() {
  _ensure_opencode
  _ensure_omo
}
