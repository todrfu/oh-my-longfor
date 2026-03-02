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
OML_SELF_REPO="${OML_SELF_REPO:-https://github.com/todrfu/oh-my-longfor}"
OML_SELF_BRANCH="${OML_SELF_BRANCH:-main}"

# Resolve the directory where this script lives (handles curl|bash case)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" 2>/dev/null && pwd || echo "")"

# Record whether stdin is a real TTY (before any child process runs).
# In curl|bash mode stdin is a pipe; TUI programs need script(1) to get a pty.
_OML_STDIN_WAS_TTY=false
[ -t 0 ] && _OML_STDIN_WAS_TTY=true

# ── Logging ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; GRAY='\033[0;90m'; NC='\033[0m'
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

  # Always refresh bootstrap sources to avoid stale lib/ scripts on user machines.
  # Previously we reused ~/.oml/.bootstrap and silently ignored pull failures,
  # which could leave users on outdated installers.
  if [ -d "$bootstrap_dir" ]; then
    rm -rf "$bootstrap_dir"
  fi

  git clone --depth 1 --branch "$OML_SELF_BRANCH" --quiet \
    "$OML_SELF_REPO" "$bootstrap_dir" 2>/dev/null || {
    oml_warn "Could not clone oml repo ($OML_SELF_REPO) — some features will be skipped."
    oml_warn "Override: OML_SELF_REPO=<url> bash install.sh ..."
    return 1
  }

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
  printf '%b\n' "${BLUE}╔═══════════════════════════════════════╗${NC}"
  printf '%b\n' "${BLUE}║   oh-my-longfor (oml) installer       ║${NC}"
  printf '%b\n' "${BLUE}║   Team AI Dev Environment Bootstrap   ║${NC}"
  printf '%b\n' "${BLUE}╚═══════════════════════════════════════╝${NC}"
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
  # Case 1: stdin is directly a TTY (normal: bash install.sh / oml install)
  [ -t 0 ] && return 0
  # Case 2: curl|bash — stdin is the curl pipe, but the controlling terminal
  # (/dev/tty) is still accessible for per-command redirects.
  # IMPORTANT: do NOT exec 0</dev/tty here — that permanently replaces stdin,
  # which breaks bash -s (it can no longer read subsequent script lines).
  if ([ -t 1 ] || [ -t 2 ]) && [ -e /dev/tty ]; then
    return 0
  fi
  return 1
}

# ── Detect the user's primary shell rc file ───────────────────────────────
_detect_rc_file() {
  case "${SHELL##*/}" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) echo "$HOME/.bashrc" ;;
    *)    echo "$HOME/.bashrc" ;;
  esac
}

# ── Install bun if missing (automatic, no confirmation) ───────────────────────
_ensure_bun() {
  if command -v bun >/dev/null 2>&1; then
    oml_success "bun found: $(bun --version 2>/dev/null || echo 'unknown version')"
    return 0
  fi

  oml_info "bun not found. Installing bun..."
  curl -fsSL https://bun.sh/install | bash
  # Reload PATH
  export PATH="$HOME/.bun/bin:$PATH"
  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun install failed. Please install manually: https://bun.sh"
    return 1
  fi
  oml_success "bun installed."
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
  printf '%b\n' "${GREEN}═══════════════════════════════════════════════════════${NC}"
  printf '%b\n' "${GREEN}  ✓ oh-my-longfor installed successfully!               ${NC}"
  printf '%b\n' "${GREEN}═══════════════════════════════════════════════════════${NC}"
  printf "\n"

  # Dynamic section: show what was configured from manifest
  if command -v bun >/dev/null 2>&1 && [ -f "$manifest_file" ]; then
    local tmp_manifest
    tmp_manifest=$(mktemp)
    if bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null; then
      bun - "$tmp_manifest" << 'BUNEOF' || true
const fs = require('fs');
let data = {};
try { data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); } catch(e) { process.exit(0); }

const BLUE   = '\x1b[0;34m';
const YELLOW = '\x1b[1;33m';
const GRAY   = '\x1b[0;90m';  // Dim gray for descriptions
const NC     = '\x1b[0m';

const mcps      = data.mcps || [];
const skillRepos = (data.skills && data.skills.repos) || [];
const envVars   = data.env || [];
const requiredEv = envVars.filter(v => v.required !== false);
const optionalEv = envVars.filter(v => v.required === false);

if (mcps.length > 0) {
  console.log(`${BLUE}[oml]${NC} MCPs configured (${mcps.length}):`);
  for (const m of mcps) console.log(`  \u2022 ${m.name || '?'}`);
  console.log('');
} else {
  console.log(`${BLUE}[oml]${NC} MCPs: (none configured in manifest)`);
}

if (skillRepos.length > 0) {
  console.log(`${BLUE}[oml]${NC} Skill repos (${skillRepos.length}):`);
  for (const r of skillRepos) console.log(`  \u2022 ${r.repo || '?'}  (branch: ${r.branch || 'main'})`);
  console.log('');
} else {
  console.log(`${BLUE}[oml]${NC} Skill repos: (none configured in manifest)`);
}

if (requiredEv.length > 0) {
  console.log(`${YELLOW}[oml] \u26a0  API keys you must fill in:${NC}`);
  for (const v of requiredEv) {
    console.log(`  \u2022 ${v.name || ''}`);
    if (v.description) console.log(`    ${GRAY}${v.description}${NC}`);
  }
  console.log('');
}

if (optionalEv.length > 0) {
  console.log(`${BLUE}[oml]${NC} Optional env vars (for full functionality):`);
  for (const v of optionalEv) {
    console.log(`  \u2022 ${v.name || ''}`);
    if (v.description) console.log(`    ${GRAY}${v.description}${NC}`);
  }
  console.log('');
}
BUNEOF
    fi
    rm -f "$tmp_manifest"
  fi

  _rc_file="$(_detect_rc_file)"
  printf "\n"
  printf '%b\n' "┌─ ${RED}Next Steps${NC} ──────────────────────────────────────────────────────┐"
  printf '%b\n' "│"
  printf '%b\n' "│  ${GREEN}1. ⚙️  Update your shell configuration manually:${NC}"
  printf '%b\n' "│     Add the following to your ${RED}${_rc_file}${NC}:"
  printf '%b\n' "│"
  printf '%b\n' "│     # oh-my-longfor environment"
  printf '%b\n' "│     export PATH=\"${OML_BIN_DIR}:\$PATH\""
  
  if [ "${OML_TOOL:-opencode}" = "opencode" ]; then
    printf '%b\n' "│     export PATH=\"\$HOME/.opencode/bin:\$PATH\""
  elif [ "${OML_TOOL}" = "claude" ]; then
    printf '%b\n' "│     export PATH=\"\$HOME/.local/bin:\$PATH\""
  elif [ "${OML_TOOL}" = "codex" ]; then
    printf '%b\n' "│     # Ensure your bun bin dir is in path if installed via bun"
    printf '%b\n' "│     export PATH=\"\$HOME/.bun/bin:\$PATH\""
  fi
  
  printf '%b\n' "│     [ -f \"${OML_ENV_DIR}/.env.oml\" ] && source \"${OML_ENV_DIR}/.env.oml\""
  printf '%b\n' "│"
  printf '%b\n' "│  ${GREEN}2. Fill in your API keys in:${NC}"
  printf '%b\n' "│     ${OML_ENV_DIR}/.env.oml"
  printf '%b\n' "│"
  printf '%b\n' "│  ${GREEN}3. Restart your terminal or run:${NC}"
  printf '%b\n' "│     source ${_rc_file}"
  printf '%b\n' "│"
  
  if [ "${OML_TOOL:-opencode}" = "opencode" ]; then
    printf '%b\n' "│  ${GREEN}4. Configure oh-my-opencode AI subscriptions (optional)${NC}"
    printf '%b\n' "│     bunx oh-my-opencode install"
    printf '%b\n' "│"
    printf '%b\n' "│  ${GREEN}5. Verify everything works (optional)${NC}"
  else
    printf '%b\n' "│  ${GREEN}4. Verify everything works (optional)${NC}"
  fi
  
  printf '%b\n' "│     oml doctor"
  printf '%b\n' "│     oml status"
  printf '%b\n' "│"
  printf '%b\n' "│ ─────────────────────────────────────────────────────────────────"
  printf '%b\n' "│"
  
  if [ "${OML_TOOL:-opencode}" = "opencode" ]; then
    printf '%b\n' "│  ${BLUE}Config:${NC}       ${HOME}/.config/opencode/opencode.json"
    printf '%b\n' "│  ${BLUE}Skills dirs:${NC}  ${HOME}/.config/opencode/skills/"
  elif [ "${OML_TOOL}" = "claude" ]; then
    printf '%b\n' "│  ${BLUE}Config:${NC}       ${HOME}/.claude.json"
    printf '%b\n' "│  ${BLUE}Skills dirs:${NC}  ${HOME}/.claude/skills/"
  elif [ "${OML_TOOL}" = "codex" ]; then
    printf '%b\n' "│  ${BLUE}Config:${NC}       ${HOME}/.codex/config.toml"
    printf '%b\n' "│  ${BLUE}Skills dirs:${NC}  ${HOME}/.codex/skills/"
  fi
  
  printf '%b\n' "│  ${BLUE}Env template:${NC} ${OML_ENV_DIR}/.env.template"
  printf '%b\n' "│"
  printf '%b\n' "└──────────────────────────────────────────────────────────────────┘"
  printf "\n"
}

# ── Cleanup on exit ───────────────────────────────────────────────────────────
# Registered at the very start of main() via 'trap _cleanup EXIT'.
_cleanup() {
  oml_lock_release 2>/dev/null || true
}

# ── Main install flow ─────────────────────────────────────────────────────────
main() {
  local team_config_url="${1:-}"

  trap '_cleanup' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  _print_banner

  if [ -z "$team_config_url" ]; then
    oml_info "No team config provided. Proceeding with vanilla installation."
    team_config_url="vanilla"
  fi
  _check_platform
  oml_info "Team config: $team_config_url"
  oml_info "OML home: $OML_HOME"
  printf "\n"

  # ── Step 1: Check prerequisites ──────────────────────────────────────────────
  oml_info "Checking prerequisites..."
  oml_check_deps git curl

  # ── Step 1b: Bootstrap lib files (curl|bash mode) ────────────────────────────
  _bootstrap_script_dir || true

  # ── Step 2: Install runtime dependencies ────────────────────────────────────
  oml_info "Selecting AI development tool to install..."
  if [ -z "${OML_TOOL:-}" ]; then
    if _is_interactive; then
      printf "%b\n" "Which tool would you like to install?" >/dev/tty
      printf "%b\n" "  1) opencode  (default)" >/dev/tty
      printf "%b\n" "  2) claude" >/dev/tty
      printf "%b\n" "  3) codex" >/dev/tty
      printf "%s" "Select [1-3] " >/dev/tty
      if ! read -r choice </dev/tty; then
        echo
        oml_error "Installation aborted by user."
        exit 130
      fi
      case "$choice" in
        2) OML_TOOL="claude" ;;
        3) OML_TOOL="codex" ;;
        *) OML_TOOL="opencode" ;;
      esac
    else
      OML_TOOL="opencode"
    fi
  fi

  oml_info "Selected tool: $OML_TOOL"
  local installer_script="$SCRIPT_DIR/lib/installers/${OML_TOOL}.sh"
  if [ -f "$installer_script" ]; then
    source "$installer_script"
    _install_tool || {
      oml_error "Failed to install $OML_TOOL"
      exit 1
    }
  else
    oml_error "Installer for $OML_TOOL not found at $installer_script"
    exit 1
  fi

  # ── Step 3: Acquire lock ─────────────────────────────────────────────────────
  oml_lock_acquire || exit 1

  # ── Step 4: Create directory structure ──────────────────────────────────────
  oml_info "Creating ~/.oml/ directory structure..."
  mkdir -p "$OML_REPO_DIR" "$OML_CONFIG_DIR" "$OML_OVERRIDES_DIR" "$OML_ENV_DIR" "$OML_BIN_DIR"
  touch "$OML_REPO_DIR/.gitkeep"

  # ── Step 5: Load team-config (git repo | local dir | local manifest file) ────
  local team_config_dest="${OML_REPO_DIR}/team-config"
  local manifest_file=""
  oml_info "Loading team config..."

  if [ "$team_config_url" = "vanilla" ]; then
    # ── Mode 0: Vanilla (no team config) ──────────────────────────────────────
    mkdir -p "$team_config_dest"
    cat > "${team_config_dest}/manifest.yaml" << 'EOF'
version: "1"
mcps: []
skills:
  repos: []
env: []
EOF
    oml_success "Scaffolded vanilla manifest"
    manifest_file="${team_config_dest}/manifest.yaml"

  elif [[ "$team_config_url" == *.yaml ]] || [[ "$team_config_url" == *.yml ]]; then
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
    oml_create_skill_symlinks "$manifest_file" || oml_warn "Could not create skill symlinks"
  else
    oml_warn "lib/skills.sh not available — skipping skill repo sync"
  fi

  # ── Step 7: Initialize personal overrides ───────────────────────────────────
  oml_info "Initializing personal overrides..."
  if command -v oml_override_init >/dev/null 2>&1; then
    oml_override_init
  fi

  # ── Step 8: Generate configs ─────────────────────────────────────────────────
  # These are non-fatal: config can be regenerated later via 'oml update'
  oml_info "Generating OpenCode configuration..."
  if command -v oml_generate_opencode_config >/dev/null 2>&1; then
    oml_generate_opencode_config "$manifest_file" \
      || oml_warn "Failed to generate opencode.json (non-fatal, run 'oml update' to retry)"
    oml_generate_omo_config "$manifest_file" \
      || oml_warn "Failed to generate oh-my-opencode config (non-fatal, run 'oml update' to retry)"
  else
    oml_warn "lib/config.sh not available — skipping config generation"
  fi

  # ── Step 9: Generate .env template ──────────────────────────────────────────
  oml_info "Generating .env template..."
  if command -v oml_generate_env_template >/dev/null 2>&1; then
    oml_generate_env_template "$manifest_file" \
      || oml_warn "Failed to generate .env template (non-fatal)"
  else
    oml_warn "lib/env.sh not available — skipping .env template generation"
  fi

  # ── Step 9b: Auto-copy env template for team installs ────────────────────────
  if [ "$team_config_url" != "vanilla" ] && command -v oml_setup_env_file >/dev/null 2>&1; then
    oml_setup_env_file \
      || oml_warn "Failed to create env file (non-fatal)"
  fi

  # ── Step 10: Install oml bin ─────────────────────────────────────────────────
  _install_oml_bin || oml_warn "Failed to install oml binary (non-fatal)"

  # ── Step 11: Release lock ────────────────────────────────────────────
  oml_lock_release

  # ── Step 13: Clean up bootstrap cache ─────────────────────────────────
  local bootstrap_dir="${OML_HOME}/.bootstrap"
  if [ -d "$bootstrap_dir" ]; then
    rm -rf "$bootstrap_dir"
    oml_info "Cleaned up bootstrap cache."
  fi

  # ── Summary ──────────────────────────────────────────────────────────────
  _print_summary "$manifest_file"

  exit 0
}

main "$@"
