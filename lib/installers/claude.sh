#!/usr/bin/env bash

# ── Install Claude Code CLI (with reinstall confirmation if exists) ────────────
_ensure_claude() {
  local should_install=true
  
  if command -v claude >/dev/null 2>&1; then
    local version
    version="$(claude --version 2>/dev/null || echo 'unknown version')"
    oml_warn "claude code cli is already installed: $version"
    
    if _is_interactive; then
      printf "%s" "Reinstall claude code cli? [y/N] " >/dev/tty
      if ! read -r answer </dev/tty; then
        echo
        oml_error "Installation aborted by user."
        exit 130
      fi
      if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        oml_info "Skipping claude code cli installation."
        should_install=false
      fi
    else
      oml_info "Non-interactive mode: skipping claude code cli reinstallation."
      should_install=false
    fi
  fi

  if [ "$should_install" = true ]; then
    oml_info "Installing claude code cli via official installer..."
    curl -fsSL https://claude.ai/install.sh | bash
    
    # The installer puts 'claude' in ~/.local/bin. 
    # We update the current session PATH so the installer can verify the installation.
    export PATH="$HOME/.local/bin:$PATH"
    
    # Persistent shell RC modification is now done manually by the user 
    # as instructed in the final summary.

    if ! command -v claude >/dev/null 2>&1; then
      oml_warn "Claude code cli was installed but 'claude' command is not in the current shell context."
      oml_warn "You may need to restart your terminal or reload your shell profile."
    else
      oml_success "claude code cli installed."
    fi
  else
    oml_success "Using existing claude code cli installation."
  fi
}

# ── Main Entrypoint for Tool Installation ──────────────────────────────────────
_install_tool() {
  _ensure_claude
}
