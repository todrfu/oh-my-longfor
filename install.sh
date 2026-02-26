#!/usr/bin/env bash
# oh-my-longfor install.sh — Team AI dev environment bootstrap
# Usage: bash install.sh <team-config-git-url-or-path>
# Or:    curl -fsSL https://internal.company.com/oml/install.sh | bash -s -- <url>
set -euo pipefail

OML_HOME="${OML_HOME:-$HOME/.oml}"
OML_REPO_DIR="${OML_HOME}/repos"
OML_CONFIG_DIR="${OML_HOME}/config"
OML_OVERRIDES_DIR="${OML_HOME}/overrides"
OML_ENV_DIR="${OML_HOME}/env"
OML_BIN_DIR="${OML_HOME}/bin"

# Resolve the directory where this script lives (handles curl|bash case)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" 2>/dev/null && pwd || echo "")"

# ── Logging ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
_info()    { printf "${BLUE}[oml]${NC} %s\n" "$*"; }
_warn()    { printf "${YELLOW}[oml] WARNING:${NC} %s\n" "$*" >&2; }
_error()   { printf "${RED}[oml] ERROR:${NC} %s\n" "$*" >&2; }
_success() { printf "${GREEN}[oml] ✓${NC} %s\n" "$*"; }

# ── Source lib functions if available ────────────────────────────────────────
_source_libs() {
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/lib" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/common.sh"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/manifest.sh"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/git.sh"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/skills.sh"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/config.sh"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/env.sh"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/override.sh"
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/backup.sh"
    return 0
  fi
  return 1
}

# Override lib functions with inline versions when sourced from curl|bash
if ! _source_libs; then
  # Fallback: define minimal wrappers so rest of script works
  oml_info()           { _info "$@"; }
  oml_warn()           { _warn "$@"; }
  oml_error()          { _error "$@"; }
  oml_success()        { _success "$@"; }
  oml_detect_platform(){ case "$(uname -s)" in Darwin) echo "darwin";; Linux) echo "linux";; *) echo "unknown";; esac; }
  oml_check_deps()     { for cmd in "$@"; do command -v "$cmd" >/dev/null 2>&1 || { _error "Missing: $cmd"; return 1; }; done; }
  oml_lock_acquire()   { mkdir -p "$OML_HOME"; echo "$$" >"${OML_HOME}/.lock"; }
  oml_lock_release()   { rm -f "${OML_HOME}/.lock"; }
  oml_git_clone()      { git clone --depth 1 --branch "${3:-main}" "$1" "$2"; }
  oml_git_clone_or_pull() { if [ -d "$2/.git" ]; then git -C "$2" pull --ff-only; else mkdir -p "$(dirname "$2")"; oml_git_clone "$1" "$2" "${3:-main}"; fi; }
fi

# ── Banner ────────────────────────────────────────────────────────────────────
_print_banner() {
  printf "\n"
  printf '%s\n' "${BLUE}╔═══════════════════════════════════════╗${NC}"
  printf '%s\n' "${BLUE}║   oh-my-longfor (oml) installer       ║${NC}"
  printf '%s\n' "${BLUE}║   Team AI Dev Environment Bootstrap   ║${NC}"
  printf '%s\n' "${BLUE}╚═══════════════════════════════════════╝${NC}"
  printf "\n"
}

# ── Platform detection ────────────────────────────────────────────────────────
_check_platform() {
  local platform
  platform="$(oml_detect_platform)"
  if [ "$platform" = "unknown" ]; then
    oml_warn "Unrecognized platform: $(uname -s). Proceeding anyway..."
  else
    oml_info "Platform: $platform"
  fi
}

# ── Detect interactive terminal ───────────────────────────────────────────────
_is_interactive() {
  [ -t 0 ]
}

# ── Install bun if missing ────────────────────────────────────────────────────
_ensure_bun() {
  if command -v bun >/dev/null 2>&1; then
    oml_success "bun found: $(bun --version 2>/dev/null || echo 'unknown version')"
    return 0
  fi

  oml_warn "bun not found."
  if _is_interactive; then
    printf "%s" "Install bun now? [y/N] "
    read -r answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
      oml_error "bun is required. Install it from https://bun.sh and re-run."
      return 1
    fi
  else
    oml_info "Non-interactive mode: installing bun automatically."
  fi

  oml_info "Installing bun..."
  curl -fsSL https://bun.sh/install | bash
  # Reload PATH
  export PATH="$HOME/.bun/bin:$PATH"
  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun install failed. Please install manually: https://bun.sh"
    return 1
  fi
  oml_success "bun installed."
}

# ── Install OpenCode if missing ───────────────────────────────────────────────
_ensure_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    oml_success "opencode found: $(opencode --version 2>/dev/null || echo 'unknown version')"
    return 0
  fi

  oml_info "Installing opencode..."
  if command -v bun >/dev/null 2>&1; then
    bun install -g opencode@latest
  elif command -v npm >/dev/null 2>&1; then
    npm install -g opencode@latest
  else
    oml_error "Neither bun nor npm found. Install one first."
    return 1
  fi
  oml_success "opencode installed."
}

# ── Install oh-my-opencode if missing ────────────────────────────────────────
_ensure_omo() {
  if command -v oh-my-opencode >/dev/null 2>&1 || \
     [ -f "${HOME}/.config/opencode/oh-my-opencode.json" ]; then
    oml_success "oh-my-opencode detected."
    return 0
  fi

  oml_info "Setting up oh-my-opencode plugin..."
  # oh-my-opencode is a plugin — configured in opencode.json
  oml_info "oh-my-opencode will be configured as an OpenCode plugin."
  return 0
}

# ── Idempotent PATH addition ──────────────────────────────────────────────────
_add_to_path() {
  local bin_dir="$1"
  local rc_file="$2"
  local marker="# oml: PATH"

  if [ ! -f "$rc_file" ]; then return 0; fi

  # Skip if exact path already configured
  if grep -qF "export PATH=\"${bin_dir}:" "$rc_file" 2>/dev/null; then
    oml_info "PATH already configured in $rc_file"
    return 0
  fi

  # Remove stale oml PATH entry (different OML_HOME)
  if grep -qF "$marker" "$rc_file" 2>/dev/null; then
    local tmpfile
    tmpfile="$(mktemp)"
    awk -v m="$marker" 'index($0,m){skip=1;next} skip>0{skip--;next} {print}' "$rc_file" > "$tmpfile"
    cp "$tmpfile" "$rc_file"
    rm -f "$tmpfile"
    oml_info "Updating PATH in $rc_file"
  fi

  cat >>"$rc_file" <<EOF

# oml: PATH — added by oh-my-longfor installer
export PATH="${bin_dir}:\$PATH"
EOF
  oml_success "Added $bin_dir to PATH in $rc_file"
}

# ── Idempotent env var addition ───────────────────────────────────────────────
_add_env_var() {
  local var_name="$1"
  local var_value="$2"
  local rc_file="$3"
  local marker="# oml: ${var_name}"

  if [ ! -f "$rc_file" ]; then return 0; fi

  # Skip if exact value already configured
  if grep -qF "export ${var_name}=\"${var_value}\"" "$rc_file" 2>/dev/null; then
    oml_info "$var_name already configured in $rc_file"
    return 0
  fi

  # Remove stale oml entry (different value)
  if grep -qF "$marker" "$rc_file" 2>/dev/null; then
    local tmpfile
    tmpfile="$(mktemp)"
    awk -v m="$marker" 'index($0,m){skip=1;next} skip>0{skip--;next} {print}' "$rc_file" > "$tmpfile"
    cp "$tmpfile" "$rc_file"
    rm -f "$tmpfile"
    oml_info "Updating $var_name in $rc_file"
  fi

  cat >>"$rc_file" <<EOF

# oml: ${var_name} — added by oh-my-longfor installer
export ${var_name}="${var_value}"
EOF
  oml_success "Set $var_name in $rc_file"
}

# ── Configure shell rc files ──────────────────────────────────────────────────
_configure_shell() {
  local bin_dir="$1"
  local config_file="$2"

  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$rc" ]; then
      _add_to_path "$bin_dir" "$rc"
      _add_env_var "OPENCODE_CONFIG" "$config_file" "$rc"
    fi
  done

  # If no rc file exists yet, create .bashrc as fallback
  if [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ]; then
    touch "$HOME/.bashrc"
    _add_to_path "$bin_dir" "$HOME/.bashrc"
    _add_env_var "OPENCODE_CONFIG" "$config_file" "$HOME/.bashrc"
  fi
}

# ── Install oml bin ────────────────────────────────────────────────────────────
_install_oml_bin() {
  mkdir -p "$OML_BIN_DIR"

  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/bin/oml" ]; then
    cp "$SCRIPT_DIR/bin/oml" "$OML_BIN_DIR/oml"
    chmod +x "$OML_BIN_DIR/oml"
    oml_success "Installed oml to $OML_BIN_DIR/oml"
  else
    oml_warn "bin/oml not found in $SCRIPT_DIR — skipping oml binary install"
    oml_warn "You may need to reinstall from a full repo checkout."
  fi
}

# ── Main install flow ─────────────────────────────────────────────────────────
main() {
  local team_config_url="${1:-}"

  _print_banner

  if [ -z "$team_config_url" ]; then
    _error "Usage: bash install.sh <team-config-git-url-or-local-path>"
    _error "Example: bash install.sh https://github.com/your-org/team-config"
    _error "Example: bash install.sh ./example-team-config"
    exit 1
  fi

  _check_platform
  oml_info "Team config: $team_config_url"
  oml_info "OML home: $OML_HOME"
  printf "\n"

  # ── Step 1: Check prerequisites ──────────────────────────────────────────────
  oml_info "Checking prerequisites..."
  oml_check_deps git curl python3

  # ── Step 2: Install runtime dependencies ────────────────────────────────────
  _ensure_bun
  _ensure_opencode
  _ensure_omo

  # ── Step 3: Acquire lock ─────────────────────────────────────────────────────
  oml_lock_acquire || exit 1
  trap 'oml_lock_release' EXIT INT TERM

  # ── Step 4: Create directory structure ──────────────────────────────────────
  oml_info "Creating ~/.oml/ directory structure..."
  mkdir -p "$OML_REPO_DIR" "$OML_CONFIG_DIR" "$OML_OVERRIDES_DIR" "$OML_ENV_DIR" "$OML_BIN_DIR"
  touch "$OML_REPO_DIR/.gitkeep"

  # ── Step 5: Clone or update team-config repo ────────────────────────────────
  local team_config_dest="${OML_REPO_DIR}/team-config"
  oml_info "Cloning team config..."

  if [[ "$team_config_url" == /* ]] || [[ "$team_config_url" == ./* ]]; then
    # Local path: copy instead of clone
    local abs_path
    abs_path="$(cd "$team_config_url" 2>/dev/null && pwd || echo "$team_config_url")"
    if [ -d "$team_config_dest" ]; then
      rm -rf "$team_config_dest"
    fi
    cp -r "$abs_path" "$team_config_dest"
    oml_success "Copied local team config: $abs_path → $team_config_dest"
  else
    oml_git_clone_or_pull "$team_config_url" "$team_config_dest" "main"
  fi

  local manifest_file="${team_config_dest}/manifest.yaml"
  if [ ! -f "$manifest_file" ]; then
    oml_error "manifest.yaml not found in team config: $manifest_file"
    oml_error "Make sure your team-config repo has a manifest.yaml file."
    exit 1
  fi

  # ── Step 6: Clone skill repositories ────────────────────────────────────────
  oml_info "Syncing skill repositories..."
  if command -v oml_sync_skills >/dev/null 2>&1; then
    oml_sync_skills "$manifest_file" || oml_warn "Some skill repos could not be cloned (check errors above)"
    oml_create_skill_symlinks || oml_warn "Could not create skill symlinks"
  else
    oml_warn "lib/skills.sh not available — skipping skill repo sync"
  fi

  # ── Step 7: Initialize personal overrides ───────────────────────────────────
  oml_info "Initializing personal overrides..."
  if command -v oml_override_init >/dev/null 2>&1; then
    oml_override_init
  fi

  # ── Step 8: Generate configs ─────────────────────────────────────────────────
  oml_info "Generating OpenCode configuration..."
  if command -v oml_generate_opencode_config >/dev/null 2>&1; then
    oml_generate_opencode_config "$manifest_file"
    oml_generate_omo_config "$manifest_file"
  else
    oml_warn "lib/config.sh not available — skipping config generation"
  fi

  # ── Step 9: Generate .env template ──────────────────────────────────────────
  oml_info "Generating .env template..."
  if command -v oml_generate_env_template >/dev/null 2>&1; then
    oml_generate_env_template "$manifest_file"
  else
    oml_warn "lib/env.sh not available — skipping .env template generation"
  fi

  # ── Step 10: Install oml bin ─────────────────────────────────────────────────
  _install_oml_bin

  # ── Step 11: Configure shell ─────────────────────────────────────────────────
  oml_info "Configuring shell..."
  _configure_shell "$OML_BIN_DIR" "${OML_CONFIG_DIR}/opencode.json"

  # ── Step 12: Release lock ────────────────────────────────────────────────────
  oml_lock_release

  # ── Summary ──────────────────────────────────────────────────────────────────
  printf "\n"
  printf '%s\n' "${GREEN}═══════════════════════════════════════════════════════${NC}"
  printf '%s\n' "${GREEN}  ✓ oh-my-longfor installed successfully!               ${NC}"
  printf '%s\n' "${GREEN}═══════════════════════════════════════════════════════${NC}"
  printf "\n"
  oml_info "Next steps:"
  oml_info "  1. Reload your shell: source ~/.zshrc  (or ~/.bashrc)"
  oml_info "  2. Fill in API keys:  cp ~/.oml/env/.env.template ~/.env.oml && edit ~/.env.oml"
  oml_info "  3. Source your env:   echo '[ -f ~/.env.oml ] && source ~/.env.oml' >> ~/.zshrc"
  oml_info "  4. Check status:      oml status"
  oml_info "  5. Verify setup:      oml doctor"
  printf "\n"
  oml_info "Team config: $team_config_url"
  oml_info "Config dir:  $OML_CONFIG_DIR"
  oml_info "Env template: ${OML_ENV_DIR}/.env.template"
  printf "\n"
}

main "$@"
