#!/usr/bin/env bash
# oh-my-longfor skills manager
# Synchronizes skill repositories and creates necessary symlinks
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=lib/git.sh
# source "$(dirname "${BASH_SOURCE[0]}")/git.sh"

# Default OML home (should be sourced from common.sh)
OML_HOME="${OML_HOME:-$HOME/.oml}"

# Read the skills configuration from manifest and sync all repos
# Usage: oml_sync_skills <manifest-path>
oml_sync_skills() {
  local manifest_file="$1"

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to parse the manifest"
    return 1
  fi

  if [ ! -f "$manifest_file" ]; then
    oml_error "Manifest file not found: $manifest_file"
    return 1
  fi

  oml_info "Synchronizing skill repositories..."

  local tmp_manifest
  tmp_manifest=$(mktemp)
  if ! bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null; then
    oml_error "Invalid YAML in manifest: $manifest_file"
    rm -f "$tmp_manifest"
    return 1
  fi

  # Also get personal overrides
  local override_file="${OML_HOME}/overrides/skills.yaml"
  local tmp_override
  tmp_override=$(mktemp)
  if [ -f "$override_file" ]; then
    bunx -y js-yaml "$override_file" > "$tmp_override" 2>/dev/null || echo '{"repos":[]}' > "$tmp_override"
  else
    echo '{"repos":[]}' > "$tmp_override"
  fi

  local any_failures=0
  
  # Parse repos into a flat text list format: repo_url|branch|subdir|auth
  # Read line by line in bash to process each repo
  while IFS='|' read -r repo_url branch _subdir auth; do
    [ -z "$repo_url" ] && continue

    oml_info "Syncing skill repo: $repo_url (branch: $branch)"
    
    # Generate a safe folder name from the repo URL
    # Use "owner--repo" format to avoid collisions (e.g. anthropics/skills vs antfu/skills)
    local repo_name
    local _repo_base _repo_owner
    _repo_base=$(basename "$repo_url" .git)
    _repo_owner=$(basename "$(dirname "$repo_url")")
    repo_name="${_repo_owner}--${_repo_base}"
    local target_dir="${OML_HOME}/repos/${repo_name}"

    if [ -d "${target_dir}/.git" ]; then
      oml_git_pull "$target_dir" "$auth" || {
        oml_warn "Failed to pull $repo_name"
        any_failures=1
      }
    else
      oml_git_clone "$repo_url" "$target_dir" "$branch" "$auth" || {
        oml_warn "Failed to clone $repo_name"
        any_failures=1
      }
    fi
  done < <(bun - "$tmp_manifest" "$tmp_override" << 'BUNEOF'
const fs = require('fs');
let manifest = { skills: { repos: [] } };
try { manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); } catch(e) {}

let override = { repos: [] };
try { override = JSON.parse(fs.readFileSync(process.argv[3], 'utf8')); } catch(e) {}

const repos = (manifest.skills && manifest.skills.repos) || [];
const overrideRepos = override.repos || [];

// Merge and deduplicate by repo URL
const merged = new Map();
for (const r of repos) {
  if (r.repo) merged.set(r.repo, r);
}
for (const r of overrideRepos) {
  if (r.repo) merged.set(r.repo, r); // personal overrides win
}

for (const r of merged.values()) {
  const branch = r.branch || 'main';
  const subdir = r.subdir || 'skills/';
  const auth = r.auth || 'null';
  console.log(`${r.repo}|${branch}|${subdir}|${auth}`);
}
BUNEOF
  )

  rm -f "$tmp_manifest" "$tmp_override"

  if [ "$any_failures" -eq 0 ]; then
    oml_success "All skill repositories synchronized."
    return 0
  else
    oml_warn "Some skill repositories failed to sync."
    return 1
  fi
}

# Symlink all discovered skills into standard discovery paths
# Usage: oml_create_skill_symlinks
oml_create_skill_symlinks() {
  local claude_target_dir="$HOME/.claude/skills"
  local opencode_target_dir="$HOME/.config/opencode/skills"
  local codex_target_dir="$HOME/.codex/skills"
  
  mkdir -p "$claude_target_dir"
  mkdir -p "$opencode_target_dir"
  mkdir -p "$codex_target_dir"

  # Clean existing symlinks managed by oml to prevent dead links
  oml_remove_skill_symlinks

  local count=0

  # Find all SKILL.md files in the repos directory
  if [ -d "${OML_HOME}/repos" ]; then
    # We look for any directory containing a SKILL.md file
    while IFS= read -r -d '' skill_md; do
      local skill_dir
      skill_dir="$(dirname "$skill_md")"
      local skill_name
      skill_name="$(basename "$skill_dir")"
      
      # Extract repo_name from path (e.g. from "${OML_HOME}/repos/owner--repo/...")
      local rel_path="${skill_dir#${OML_HOME}/repos/}"
      local repo_name="${rel_path%%/*}"
      
      # Determine safe link name to avoid collision across repos
      local safe_skill_name="$skill_name"
      if [ -e "${claude_target_dir}/${skill_name}" ] || [ -L "${claude_target_dir}/${skill_name}" ] || \
         [ -e "${opencode_target_dir}/${skill_name}" ] || [ -L "${opencode_target_dir}/${skill_name}" ] || \
         [ -e "${codex_target_dir}/${skill_name}" ] || [ -L "${codex_target_dir}/${skill_name}" ]; then
        # If a link already exists from another repo, prefix with repo name
        safe_skill_name="${repo_name}--${skill_name}"
      fi

      # Symlink to ~/.claude/skills/
      local claude_link_path="${claude_target_dir}/${safe_skill_name}"
      if [ ! -e "$claude_link_path" ] && [ ! -L "$claude_link_path" ]; then
        ln -s "$skill_dir" "$claude_link_path"
      fi

      # Symlink to ~/.config/opencode/skills/
      local opencode_link_path="${opencode_target_dir}/${safe_skill_name}"
      if [ ! -e "$opencode_link_path" ] && [ ! -L "$opencode_link_path" ]; then
        ln -s "$skill_dir" "$opencode_link_path"
      fi
      
      # Symlink to ~/.codex/skills/
      local codex_link_path="${codex_target_dir}/${safe_skill_name}"
      if [ ! -e "$codex_link_path" ] && [ ! -L "$codex_link_path" ]; then
        ln -s "$skill_dir" "$codex_link_path"
      fi
      
      ((count++))
    done < <(find "${OML_HOME}/repos" -type f -name "SKILL.md" -print0)
  fi

  if [ "$count" -gt 0 ]; then
    oml_success "Symlinked $count skills to discovery paths (opencode, claude, codex)"
  else
    oml_info "No skills found to symlink"
  fi
}

# Remove all oml-managed symlinks
# Usage: oml_remove_skill_symlinks
oml_remove_skill_symlinks() {
  local claude_target_dir="$HOME/.claude/skills"
  local opencode_target_dir="$HOME/.config/opencode/skills"
  local codex_target_dir="$HOME/.codex/skills"
  local count=0

  for target_dir in "$claude_target_dir" "$opencode_target_dir" "$codex_target_dir"; do
    if [ -d "$target_dir" ]; then
      # Only remove symlinks that point into ~/.oml/repos
      for link in "$target_dir"/*; do
        if [ -L "$link" ]; then
          local target
          target="$(readlink "$link")"
          if [[ "$target" == "${OML_HOME}/repos/"* ]]; then
            rm -f "$link"
            ((count++))
          fi
        fi
      done
    fi
  done
  
  [ "$count" -gt 0 ] && oml_info "Removed $count old skill symlinks"
}

# Show the status of synchronized skill repos
# Usage: oml_skill_status
oml_skill_status() {
  local repos_dir="${OML_HOME}/repos"
  if [ ! -d "$repos_dir" ]; then
    return 0
  fi

  local found=false
  for d in "$repos_dir"/*; do
    if [ -d "$d/.git" ] && [ "$(basename "$d")" != "team-config" ]; then
      found=true
      local branch
      branch="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

      
      # Count skills (directories with SKILL.md)
      local skill_count=0
      if count_str=$(find "$d" -name "SKILL.md" 2>/dev/null | wc -l); then
        skill_count=$((count_str + 0))
      fi
      
      # shellcheck disable=SC2059
      printf "  \033[0;32m✓\033[0m  %-20s [%s] (%d skills)\n" "$(basename "$d")" "$branch" "$skill_count"
    fi
  done
  
  if [ "$found" = false ]; then
    echo "  (No skill repositories synced)"
  fi
}
