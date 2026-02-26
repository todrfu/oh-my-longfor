#!/usr/bin/env bash
# oh-my-longfor manifest parsing utilities
# Helpers to extract info from manifest.yaml
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Uses bunx js-yaml to parse and extract properties
# Note: Complex config assembly should happen in config.sh, this is for basic extraction

# Extract all environment variable names that are required
# Usage: oml_manifest_get_required_env_vars <manifest-path>
# Output: Space-separated list of UPPER_SNAKE_CASE variable names
oml_manifest_get_required_env_vars() {
  local manifest_file="$1"

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to parse manifest"
    return 1
  fi

  local tmp_manifest
  tmp_manifest=$(mktemp)
  if ! bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null; then
    rm -f "$tmp_manifest"
    return 1
  fi

  bun - "$tmp_manifest" << 'BUNEOF'
const fs = require('fs');

let manifest = {};
try { manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); } catch(e) {}

const envVars = manifest.env || [];
const required = envVars.filter(v => v.required !== false && v.name).map(v => v.name);

console.log(required.join(' '));
BUNEOF

  rm -f "$tmp_manifest"
}

# Ensure all required env vars from manifest are set in the current environment
# Usage: oml_manifest_check_env <manifest-path>
# Exit: 0 if all set, 1 if any missing
oml_manifest_check_env() {
  local manifest_file="$1"
  local required_vars
  required_vars="$(oml_manifest_get_required_env_vars "$manifest_file" || echo "")"
  
  if [ -z "$required_vars" ]; then
    return 0 # No required vars
  fi

  local missing=()
  for var in $required_vars; do
    # Using indirect expansion to check if variable is set and not empty
    if [ -z "${!var:-}" ]; then
      missing+=("$var")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    oml_error "Missing required environment variables defined in manifest:"
    for var in "${missing[@]}"; do
      oml_error "  - $var"
    done
    oml_error "Please configure them in ~/.env.oml and source it, or export them directly."
    return 1
  fi

  return 0
}

# Extract the team skills repository URL (first one defined)
# Usage: oml_manifest_get_team_skills_repo <manifest-path>
# Output: repo URL or empty string
oml_manifest_get_team_skills_repo() {
  local manifest_file="$1"

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  if ! command -v bun >/dev/null 2>&1; then
    return 1
  fi

  local tmp_manifest
  tmp_manifest=$(mktemp)
  if ! bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null; then
    rm -f "$tmp_manifest"
    return 1
  fi

  bun - "$tmp_manifest" << 'BUNEOF'
const fs = require('fs');

let manifest = {};
try { manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); } catch(e) {}

const repos = (manifest.skills && manifest.skills.repos) || [];
if (repos.length > 0 && repos[0].repo) {
  console.log(repos[0].repo);
}
BUNEOF

  rm -f "$tmp_manifest"
}
