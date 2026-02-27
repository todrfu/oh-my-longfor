#!/usr/bin/env bash
# oh-my-longfor git helper utilities
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Default OML home (should be sourced from common.sh)
OML_HOME="${OML_HOME:-$HOME/.oml}"

# Clone a git repository (shallow clone by default)
# Usage: oml_git_clone <url> <dest-dir> [branch]
oml_git_clone() {
  local url="$1"
  local dest="$2"
  local branch="${3:-main}"

  oml_info "Cloning $url → $dest (branch: $branch)"

  if git clone --depth 1 --branch "$branch" "$url" "$dest" 2>&1; then
    oml_success "Cloned $url"
  else
    oml_error "Failed to clone $url"
    oml_error "Check that the URL is correct and you have access."
    return 1
  fi
}

# Pull latest changes in an already-cloned repository
# Usage: oml_git_pull <repo-dir>
oml_git_pull() {
  local repo_dir="$1"

  if [ ! -d "$repo_dir/.git" ]; then
    oml_error "Not a git repository: $repo_dir"
    return 1
  fi

  oml_info "Pulling latest changes in $repo_dir"

  local git_output
  if git_output=$(git -C "$repo_dir" pull --ff-only 2>&1); then
    oml_success "Updated $repo_dir"
  else
    # Distinguish network errors from actual divergence
    if echo "$git_output" | grep -qiE 'SSL_|Could not resolve host|Connection refused|Network is unreachable|Failed to connect|unable to access|Connection timed out'; then
      oml_warn "Network error pulling $repo_dir — using existing local copy."
      oml_warn "If you need the latest version, check your network/proxy and retry."
    else
      oml_warn "Could not fast-forward pull in $repo_dir (may have diverged)"
      oml_warn "Run: git -C $repo_dir status — for details"
      oml_warn "Skipping update for this repo to preserve your changes."
    fi
    return 0  # Don't fail — just warn and continue
  fi
}

# Clone if not exists, pull if already cloned
# Usage: oml_git_clone_or_pull <url> <dest-dir> [branch]
oml_git_clone_or_pull() {
  local url="$1"
  local dest="$2"
  local branch="${3:-main}"

  if [ -d "$dest/.git" ]; then
    # Already a git repository — pull latest changes
    oml_git_pull "$dest"
  elif [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    # Directory exists but is not a git repo (e.g., failed previous install)
    oml_warn "Non-git directory exists: $dest"
    oml_warn "Removing stale directory to proceed with fresh clone..."
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    oml_git_clone "$url" "$dest" "$branch"
  else
    # Directory doesn't exist or is empty — clone
    mkdir -p "$(dirname "$dest")"
    oml_git_clone "$url" "$dest" "$branch"
  fi
}
