#!/usr/bin/env bash
# oh-my-longfor skill repository cloner and syncer
# Provides: cloning/updating skill repos, listing skills, symlink management
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=lib/git.sh
# source "$(dirname "${BASH_SOURCE[0]}")/git.sh"

# Default OML home (should be sourced from common.sh)
OML_HOME="${OML_HOME:-$HOME/.oml}"

# Sync all skill repos defined in manifest: clone if missing, pull if present
# Usage: oml_sync_skills <manifest-path>
oml_sync_skills() {
  local manifest_file="$1"
  local repos_dir="${OML_HOME}/repos"

  if ! command -v python3 >/dev/null 2>&1; then
    oml_error "python3 is required to parse the manifest"
    return 1
  fi

  if [ ! -f "$manifest_file" ]; then
    oml_error "Manifest file not found: $manifest_file"
    return 1
  fi

  mkdir -p "$repos_dir"

  # Extract repo data from manifest and process each repo
  python3 - "$manifest_file" << 'PYEOF' | while IFS='|' read -r repo_url branch subdir auth; do
import sys
import yaml

try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f'[oml] ERROR: Invalid YAML in manifest: {e}', file=sys.stderr)
    sys.exit(1)
if data is None:
    print('[oml] ERROR: Manifest file is empty or invalid', file=sys.stderr)
    sys.exit(1)

for repo in data.get('skills', {}).get('repos', []):
    repo_url = repo.get('repo', '')
    branch   = repo.get('branch', 'main')
    subdir   = repo.get('subdir', 'skills/')
    auth     = str(repo.get('auth') or 'null')
    if repo_url:
        print(f"{repo_url}|{branch}|{subdir}|{auth}")
PYEOF
    if [ -z "$repo_url" ]; then continue; fi

    # Derive a directory name from the repo URL
    local repo_name
    repo_name="$(basename "$repo_url" .git)"
    local dest_dir="${repos_dir}/${repo_name}"

    # Set up auth environment if needed
    _oml_setup_git_auth "$auth"

    # Clone or pull the repo
    if [ -d "${dest_dir}/.git" ]; then
      oml_git_pull "$dest_dir" || oml_warn "Could not update $repo_name — continuing"
    else
      oml_git_clone "$repo_url" "$dest_dir" "$branch" || {
        oml_error "Failed to clone $repo_url"
        oml_error "If this is a private repo, set auth: token or auth: ssh in manifest"
        continue
      }
    fi

    # Verify expected skills subdir exists
    local skills_subdir="${dest_dir}/${subdir}"
    if [ ! -d "$skills_subdir" ]; then
      oml_warn "Expected skills directory not found: $skills_subdir"
      oml_warn "Check that subdir: '$subdir' is correct in your manifest"
    else
      local skill_count
      skill_count="$(find "$skills_subdir" -name 'SKILL.md' -maxdepth 2 | wc -l | tr -d ' ')"
      oml_success "Synced $repo_name (${skill_count} skills in ${subdir})"
    fi
  done
}

# Configure git authentication based on auth type
# Usage: _oml_setup_git_auth <auth-type>
_oml_setup_git_auth() {
  local auth="$1"
  case "$auth" in
    token)
      if [ -z "${GITHUB_TOKEN:-}" ]; then
        oml_warn "auth: token requires GITHUB_TOKEN to be set in environment"
      fi
      ;;
    ssh)
      if ! ssh-add -l >/dev/null 2>&1; then
        oml_warn "auth: ssh — no SSH keys loaded in ssh-agent. Run: ssh-add ~/.ssh/id_rsa"
      fi
      ;;
    null|"")
      : # public repo, no auth needed
      ;;
    *)
      oml_warn "Unknown auth type: $auth (expected: null, ssh, or token)"
      ;;
  esac
}

# List all SKILL.md files discovered across all cloned skill repos
# Usage: oml_list_skills
oml_list_skills() {
  local repos_dir="${OML_HOME}/repos"

  if [ ! -d "$repos_dir" ]; then
    oml_warn "No repos directory found at $repos_dir — run 'oml install' first"
    return 0
  fi

  local found=0
  while IFS= read -r skill_file; do
    local skill_dir
    skill_dir="$(dirname "$skill_file")"
    local skill_name
    skill_name="$(basename "$skill_dir")"
    local repo_name
    repo_name="$(echo "$skill_dir" | sed "s|${repos_dir}/||" | cut -d/ -f1)"
    printf "  %-30s  %s\n" "$skill_name" "($repo_name)"
    found=$((found + 1))
  done < <(find "$repos_dir" -name 'SKILL.md' -maxdepth 4 2>/dev/null | sort)

  if [ "$found" -eq 0 ]; then
    oml_warn "No skills found. Run 'oml install' to clone skill repos."
  else
    echo ""
    oml_info "Total: $found skills"
  fi
}

# Show git status for each cloned skill repo
# Usage: oml_skill_status
oml_skill_status() {
  local repos_dir="${OML_HOME}/repos"

  if [ ! -d "$repos_dir" ]; then
    oml_warn "No repos directory at $repos_dir"
    return 0
  fi

  local repo_dir
  for repo_dir in "$repos_dir"/*/; do
    if [ ! -d "${repo_dir}/.git" ]; then continue; fi
    local repo_name
    repo_name="$(basename "$repo_dir")"
    local status_out
    status_out="$(git -C "$repo_dir" status --short 2>&1)"
    local branch
    branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    if [ -z "$status_out" ]; then
      printf "  ${GREEN}✓${NC}  %-25s  branch: %s\n" "$repo_name" "$branch"
    else
      printf "  ${YELLOW}~${NC}  %-25s  branch: %s (modified)\n" "$repo_name" "$branch"
    fi
  done
}

# Create symlinks from ~/.claude/skills/<name> to cloned skill directories
# This is required because skills.paths in OpenCode 1.2.13 does not work
# Usage: oml_create_skill_symlinks
oml_create_skill_symlinks() {
  local repos_dir="${OML_HOME}/repos"
  local symlinks_file="${OML_HOME}/config/symlinks.txt"
  local claude_skills_dir="${HOME}/.claude/skills"

  mkdir -p "$(dirname "$symlinks_file")" "$claude_skills_dir"
  : >"$symlinks_file"  # Clear existing symlinks list

  while IFS= read -r skill_file; do
    local skill_dir
    skill_dir="$(dirname "$skill_file")"
    local skill_name
    skill_name="$(basename "$skill_dir")"
    local link_target="${claude_skills_dir}/${skill_name}"

    # Remove existing symlink if it points elsewhere
    if [ -L "$link_target" ]; then
      local current_target
      current_target="$(readlink "$link_target")"
      if [ "$current_target" != "$skill_dir" ]; then
        oml_warn "Overwriting existing symlink: $link_target → $current_target"
        rm "$link_target"
      fi
    elif [ -e "$link_target" ]; then
      oml_warn "Skipping $skill_name: $link_target exists and is not a symlink"
      continue
    fi

    if [ ! -L "$link_target" ]; then
      ln -sf "$skill_dir" "$link_target"
      oml_info "Linked skill: $skill_name"
    fi

    # Track the symlink for cleanup
    echo "$link_target" >>"$symlinks_file"
  done < <(find "$repos_dir" -name 'SKILL.md' -maxdepth 4 2>/dev/null | sort)
}

# Remove all oml-managed symlinks from ~/.claude/skills/
# Usage: oml_remove_skill_symlinks
oml_remove_skill_symlinks() {
  local symlinks_file="${OML_HOME}/config/symlinks.txt"

  if [ ! -f "$symlinks_file" ]; then
    return 0
  fi

  while IFS= read -r link_path; do
    if [ -L "$link_path" ]; then
      rm "$link_path"
      oml_info "Removed symlink: $link_path"
    fi
  done <"$symlinks_file"

  rm -f "$symlinks_file"
}
