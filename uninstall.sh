#!/usr/bin/env bash

set -euo pipefail

# ── Logging ───────────────────────────────────────────────────────────────────
oml_info()    { printf '\033[1;34m==>\033[0m %b\n' "$1"; }
oml_success() { printf '\033[1;32m==>\033[0m %b\n' "$1"; }
oml_warn()    { printf '\033[1;33m==>\033[0m %b\n' "$1"; }
oml_error()   { printf '\033[1;31m==> Error:\033[0m %b\n' "$1" >&2; }

# ── Remove RC Injections ──────────────────────────────────────────────────────
_remove_rc_injections() {
  local rc_file="$1"
  if [ ! -f "$rc_file" ]; then return 0; fi

  oml_info "Cleaning up $rc_file..."
  
  local tmpfile
  tmpfile="$(mktemp)"

  awk '/# oml: / { skip=1; next } skip > 0 { skip--; next } { print }' "$rc_file" > "$tmpfile"

  # Remove specific source lines that might have lost their marker
  local tmpfile2
  tmpfile2="$(mktemp)"
  grep -v -E "source .*env\.oml" "$tmpfile" | grep -v "OPENCODE_CONFIG=" > "$tmpfile2" || true
  
  if cmp -s "$rc_file" "$tmpfile2"; then
    rm -f "$tmpfile" "$tmpfile2"
    return 0
  fi

  cp "$tmpfile2" "$rc_file"
  rm -f "$tmpfile" "$tmpfile2"
  oml_success "Cleaned $rc_file"
}

# ── Main Uninstallation ───────────────────────────────────────────────────────
main() {
  oml_info "Starting uninstallation of oh-my-longfor, OpenCode, and oh-my-opencode..."

  # 1. Clean RC files
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$rc" ]; then
      _remove_rc_injections "$rc"
    fi
  done

  # 2. Remove OpenCode binaries and config
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

  # 3. Remove oh-my-opencode package
  if command -v bun >/dev/null 2>&1; then
    oml_info "Removing oh-my-opencode via bun..."
    bun remove -g oh-my-opencode >/dev/null 2>&1 || true
  fi
  if [ -f "$HOME/.bun/bin/oh-my-opencode" ]; then
    rm -f "$HOME/.bun/bin/oh-my-opencode"
  fi

  # 4. Remove OML Home
  local oml_home="${OML_HOME:-$HOME/.oml}"
  if [ -d "$oml_home" ]; then
    oml_info "Removing $oml_home..."
    rm -rf "$oml_home"
  fi

  oml_success "Uninstallation complete!"
  
  # Determine current shell RC to tell user to reload
  local current_shell
  current_shell="$(basename "$SHELL" 2>/dev/null || echo "bash")"
  
  oml_warn "Please restart your terminal or run: exec \"$current_shell\" -l"
}

main "$@"
