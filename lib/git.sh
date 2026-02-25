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

  if git -C "$repo_dir" pull --ff-only 2>&1; then
    oml_success "Updated $repo_dir"
  else
    oml_warn "Could not fast-forward pull in $repo_dir (may have diverged)"
    oml_warn "Run: git -C $repo_dir status — for details"
    oml_warn "Skipping update for this repo to preserve your changes."
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
    oml_git_pull "$dest"
  else
    mkdir -p "$(dirname "$dest")"
    oml_git_clone "$url" "$dest" "$branch"
  fi
}
