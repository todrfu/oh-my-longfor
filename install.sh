#!/usr/bin/env bash
# oh-my-longfor install.sh — Team AI dev environment bootstrap
# Usage: bash install.sh <team-config-git-url | local-dir | manifest.yaml>
# Or:    curl -fsSL https://your-host/install.sh | bash -s -- <url>
set -euo pipefail

OML_HOME="${OML_HOME:-$HOME/.oml}"
OML_REPO_DIR="${OML_HOME}/repos"
OML_CONFIG_DIR="${OML_HOME}/config"
OML_OVERRIDES_DIR="${OML_HOME}/overrides"
OML_ENV_DIR="${OML_HOME}/env"
OML_BIN_DIR="${OML_HOME}/bin"

# URL to THIS installer repo — used for self-bootstrap in curl|bash mode.
# Override with: OML_SELF_REPO=https://your-host/oh-my-longfor bash install.sh ...
OML_SELF_REPO="${OML_SELF_REPO:-https://github.com/your-org/oh-my-longfor}"
OML_SELF_BRANCH="${OML_SELF_BRANCH:-main}"

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

# ── Self-bootstrap lib files when running via curl|bash ──────────────────────
# In curl|bash mode, BASH_SOURCE[0] is /dev/stdin, so SCRIPT_DIR resolves to
# /dev — which has no lib/. This function clones the oml repo itself into
# $OML_HOME/.bootstrap so all lib/ functions become available.
_bootstrap_script_dir() {
  # Already have a valid local script dir with lib/
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/lib" ]; then
    return 0
  fi

  oml_info "curl|bash mode detected — fetching oml library from $OML_SELF_REPO ..."
  local bootstrap_dir="${OML_HOME}/.bootstrap"
  mkdir -p "$OML_HOME"

  if [ -d "${bootstrap_dir}/.git" ]; then
    git -C "$bootstrap_dir" pull --ff-only --quiet 2>/dev/null || true
  else
    git clone --depth 1 --branch "$OML_SELF_BRANCH" --quiet \
      "$OML_SELF_REPO" "$bootstrap_dir" 2>/dev/null || {
      oml_warn "Could not clone oml repo ($OML_SELF_REPO) — some features will be skipped."
      oml_warn "Override: OML_SELF_REPO=<url> bash install.sh ..."
      return 1
    }
  fi

  if [ ! -d "$bootstrap_dir/lib" ]; then
    oml_warn "Cloned oml repo but lib/ not found — skipping self-bootstrap"
    return 1
  fi

  SCRIPT_DIR="$bootstrap_dir"
  _source_libs
  oml_success "oml library loaded from bootstrap."
}

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

# ── Install bun if missing (required for oh-my-opencode via bunx) ─────────────
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
}

# ── Install oh-my-opencode if missing ────────────────────────────────────────
_ensure_omo() {
  # Detection: oh-my-opencode registers itself as a plugin in opencode.json
  local oc_json="$HOME/.config/opencode/opencode.json"
  if [ -f "$oc_json" ] && grep -q '"oh-my-opencode"' "$oc_json" 2>/dev/null; then
    oml_success "oh-my-opencode already installed."
    return 0
  fi

  oml_info "Installing oh-my-opencode plugin..."
  # oh-my-opencode is installed via bunx (requires bun, installed above)
  # --no-tui: non-interactive mode
  # --claude=no --gemini=no --copilot=no: safe defaults; user can reconfigure later
  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to install oh-my-opencode. Run _ensure_bun first."
    return 1
  fi
  bunx oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=no
  oml_success "oh-my-opencode installed. Run 'bunx oh-my-opencode install' to configure AI subscriptions."
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

# ── Install oml bin + lib ─────────────────────────────────────────────────────
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

  # Also install lib/ so 'oml' commands work outside the source directory.
  # bin/oml resolves lib at ~/.oml/lib/ when not run from the repo root.
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/lib" ]; then
    local lib_dest="${OML_HOME}/lib"
    rm -rf "$lib_dest"
    cp -r "$SCRIPT_DIR/lib" "$lib_dest"
    oml_success "Installed lib/ to $lib_dest"
  else
    oml_warn "lib/ not found in $SCRIPT_DIR — 'oml' subcommands may not work"
    oml_warn "Try: bash install.sh <url>  (from a full repo checkout or via curl|bash)"
  fi
}

# ── Post-install summary ──────────────────────────────────────────────────────
_print_summary() {
  local manifest_file="$1"

  printf "\n"
  printf '%s\n' "${GREEN}═══════════════════════════════════════════════════════${NC}"
  printf '%s\n' "${GREEN}  ✓ oh-my-longfor installed successfully!               ${NC}"
  printf '%s\n' "${GREEN}═══════════════════════════════════════════════════════${NC}"
  printf "\n"

  # Dynamic section: show what was configured from manifest
  if command -v python3 >/dev/null 2>&1 && [ -f "$manifest_file" ]; then
    python3 - "$manifest_file" << 'PYEOF'
import sys
try:
    import yaml
except ImportError:
    sys.exit(0)
try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)
except Exception:
    sys.exit(0)
if not data:
    sys.exit(0)

BLUE = '\033[0;34m'
YELLOW = '\033[1;33m'
NC = '\033[0m'

mcps        = data.get('mcps', []) or []
skill_repos = data.get('skills', {}).get('repos', []) or []
env_vars    = data.get('env', []) or []
required_ev = [v for v in env_vars if v.get('required', True)]
optional_ev = [v for v in env_vars if not v.get('required', True)]

if mcps:
    print(f"{BLUE}[oml]{NC} MCPs configured ({len(mcps)}):")
    for m in mcps:
        print(f"  \u2022 {m.get('name', '?')}")
    print()
else:
    print(f"{BLUE}[oml]{NC} MCPs: (none configured in manifest)")

if skill_repos:
    print(f"{BLUE}[oml]{NC} Skill repos ({len(skill_repos)}):")
    for r in skill_repos:
        print(f"  \u2022 {r.get('repo', '?')}  (branch: {r.get('branch', 'main')})")
    print()
else:
    print(f"{BLUE}[oml]{NC} Skill repos: (none configured in manifest)")

if required_ev:
    print(f"{YELLOW}[oml] \u26a0  API keys you must fill in:{NC}")
    for v in required_ev:
        name = v.get('name', '')
        desc = v.get('description', '')
        print(f"  \u2022 {name}")
        if desc:
            print(f"    {desc}")
    print()

if optional_ev:
    print(f"{BLUE}[oml]{NC} Optional env vars (for full functionality):")
    for v in optional_ev:
        name = v.get('name', '')
        desc = v.get('description', '')
        print(f"  \u2022 {name}")
        if desc:
            print(f"    {desc}")
    print()
PYEOF
  fi

  printf '%s\n' "${BLUE}[oml]${NC} ─── Next Steps ──────────────────────────────────────────────"
  printf "\n"
  printf '%s\n' "  ${YELLOW}1. Reload your shell${NC}"
  printf '%s\n' "       source ~/.zshrc   # or ~/.bashrc"
  printf "\n"
  printf '%s\n' "  ${YELLOW}2. Fill in your API keys${NC}"
  printf '%s\n' "       cp ${OML_ENV_DIR}/.env.template ~/.env.oml"
  printf '%s\n' "       \$EDITOR ~/.env.oml"
  printf '%s\n' "       echo '[ -f ~/.env.oml ] && source ~/.env.oml' >> ~/.zshrc"
  printf "\n"
  printf '%s\n' "  ${YELLOW}3. Configure oh-my-opencode AI subscriptions${NC}"
  printf '%s\n' "       bunx oh-my-opencode install"
  printf '%s\n' "       # Choose which AI providers you have (Claude, Gemini, Copilot)"
  printf "\n"
  printf '%s\n' "  ${YELLOW}4. Verify everything works${NC}"
  printf '%s\n' "       oml doctor"
  printf '%s\n' "       oml status"
  printf "\n"
  printf '%s\n' "  Config:       ${OML_CONFIG_DIR}/opencode.json"
  printf '%s\n' "  Env template: ${OML_ENV_DIR}/.env.template"
  printf '%s\n' "  Skills dirs:  ${HOME}/.claude/skills/ , ${HOME}/.config/opencode/skills/"
  printf "\n"
}

# ── Main install flow ─────────────────────────────────────────────────────────
main() {
  local team_config_url="${1:-}"

  _print_banner

  if [ -z "$team_config_url" ]; then
    _error "Usage: bash install.sh <team-config-source>"
    _error ""
    _error "Accepted sources:"
    _error "  Remote git repo:  bash install.sh https://github.com/your-org/team-config"
    _error "  Local directory:  bash install.sh ./example-team-config"
    _error "  Local manifest:   bash install.sh ./manifest.yaml"
    _error "  Local manifest:   bash install.sh /absolute/path/to/manifest.yaml"
    _error ""
    _error "curl one-liner:"
    _error "  curl -fsSL https://your-host/install.sh | bash -s -- https://github.com/your-org/team-config"
    exit 1
  fi

  _check_platform
  oml_info "Team config: $team_config_url"
  oml_info "OML home: $OML_HOME"
  printf "\n"

  # ── Step 1: Check prerequisites ──────────────────────────────────────────────
  oml_info "Checking prerequisites..."
  oml_check_deps git curl python3

  # ── Step 1b: Bootstrap lib files (curl|bash mode) ────────────────────────────
  _bootstrap_script_dir || true

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

  # ── Step 5: Load team-config (git repo | local dir | local manifest file) ────
  local team_config_dest="${OML_REPO_DIR}/team-config"
  local manifest_file=""
  oml_info "Loading team config..."

  if [[ "$team_config_url" == *.yaml ]] || [[ "$team_config_url" == *.yml ]]; then
    # ── Mode A: Direct path to a manifest.yaml file ──────────────────────────
    local file_dir file_base abs_manifest
    file_dir="$(dirname "$team_config_url")"
    file_base="$(basename "$team_config_url")"
    if [[ "$team_config_url" == /* ]]; then
      abs_manifest="$team_config_url"
    else
      abs_manifest="$(cd "$file_dir" 2>/dev/null && pwd || echo "$file_dir")/${file_base}"
    fi
    if [ ! -f "$abs_manifest" ]; then
      oml_error "Manifest file not found: $abs_manifest"
      exit 1
    fi
    mkdir -p "$team_config_dest"
    cp "$abs_manifest" "${team_config_dest}/manifest.yaml"
    oml_success "Using local manifest: $abs_manifest"
    manifest_file="${team_config_dest}/manifest.yaml"

  elif [[ "$team_config_url" == /* ]] || [[ "$team_config_url" == ./* ]]; then
    # ── Mode B: Local directory containing manifest.yaml ─────────────────────
    local abs_path
    abs_path="$(cd "$team_config_url" 2>/dev/null && pwd || echo "$team_config_url")"
    if [ -d "$team_config_dest" ]; then
      rm -rf "$team_config_dest"
    fi
    cp -r "$abs_path" "$team_config_dest"
    oml_success "Copied local team config: $abs_path → $team_config_dest"
    manifest_file="${team_config_dest}/manifest.yaml"

  else
    # ── Mode C: Remote git repository ─────────────────────────────────────────
    oml_git_clone_or_pull "$team_config_url" "$team_config_dest" "main"
    manifest_file="${team_config_dest}/manifest.yaml"
  fi

  if [ ! -f "$manifest_file" ]; then
    oml_error "manifest.yaml not found: $manifest_file"
    oml_error "Make sure your source has a manifest.yaml file."
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
  _print_summary "$manifest_file"
}

main "$@"
