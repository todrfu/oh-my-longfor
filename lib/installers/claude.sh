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
      read -r answer </dev/tty
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
    
    # The installer puts 'claude' in ~/.local/bin, but doesn't update shell RC files.
    # Update current session PATH.
    export PATH="$HOME/.local/bin:$PATH"
    
    # Persistently add ~/.local/bin to shell rc files using oml helper
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
      if [ -f "$rc" ]; then
        _add_to_path "$HOME/.local/bin" "$rc"
      fi
    done

    # Fallback if no rc files exist yet
    if [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ]; then
      touch "$HOME/.bashrc"
      _add_to_path "$HOME/.local/bin" "$HOME/.bashrc"
    fi

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
