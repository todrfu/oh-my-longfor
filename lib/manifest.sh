#!/usr/bin/env bash
# oh-my-longfor manifest parser utilities
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Parse a YAML manifest file and extract structured data
# Uses python3 if available, falls back to yq, then to basic grep/sed
# Usage: oml_parse_manifest <manifest-path>
# Outputs: Sets MANIFEST_* variables and arrays
oml_parse_manifest() {
  local manifest_file="$1"

  if [ ! -f "$manifest_file" ]; then
    oml_error "Manifest file not found: $manifest_file"
    return 1
  fi

  if command -v python3 &>/dev/null; then
    _oml_parse_manifest_python "$manifest_file"
  elif command -v yq &>/dev/null; then
    _oml_parse_manifest_yq "$manifest_file"
  else
    oml_warn "Neither python3 nor yq found. Using basic YAML parser (limited support)."
    _oml_parse_manifest_basic "$manifest_file"
  fi
}

# Parse manifest using python3 (preferred method)
_oml_parse_manifest_python() {
  local manifest_file="$1"

  python3 - "$manifest_file" << 'PYEOF'
import sys
import yaml
import json

manifest_path = sys.argv[1]
try:
    with open(manifest_path) as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f'[oml] ERROR: Invalid YAML in manifest: {e}', file=sys.stderr)
    sys.exit(1)
if data is None:
    print('[oml] ERROR: Manifest file is empty or invalid', file=sys.stderr)
    sys.exit(1)

# Output as shell-sourceable variables
mcps = data.get('mcps', [])
skills_repos = data.get('skills', {}).get('repos', [])
env_vars = data.get('env', [])

print(f"MANIFEST_VERSION='{data.get('version', '1')}'")
print(f"MANIFEST_MCP_COUNT='{len(mcps)}'")
print(f"MANIFEST_SKILL_REPO_COUNT='{len(skills_repos)}'")
print(f"MANIFEST_ENV_COUNT='{len(env_vars)}'")

# Output MCPs as JSON for shell consumption
print(f"MANIFEST_MCPS='{json.dumps(mcps)}'")
print(f"MANIFEST_SKILL_REPOS='{json.dumps(skills_repos)}'")
print(f"MANIFEST_ENV_VARS='{json.dumps(env_vars)}'")

# Output individual MCP names for iteration
for i, mcp in enumerate(mcps):
    name = mcp.get('name', '')
    url = mcp.get('url', '')
    print(f"MANIFEST_MCP_{i}_NAME='{name}'")
    print(f"MANIFEST_MCP_{i}_URL='{url}'")

# Output skill repo URLs for cloning
for i, repo in enumerate(skills_repos):
    repo_url = repo.get('repo', '')
    branch = repo.get('branch', 'main')
    subdir = repo.get('subdir', 'skills/')
    auth = repo.get('auth', 'null')
    print(f"MANIFEST_SKILL_REPO_{i}_URL='{repo_url}'")
    print(f"MANIFEST_SKILL_REPO_{i}_BRANCH='{branch}'")
    print(f"MANIFEST_SKILL_REPO_{i}_SUBDIR='{subdir}'")
    print(f"MANIFEST_SKILL_REPO_{i}_AUTH='{auth}'")
PYEOF
}

# Parse manifest using yq (fallback)
_oml_parse_manifest_yq() {
  local manifest_file="$1"

  local version mcp_count repo_count env_count
  version="$(yq '.version // "1"' "$manifest_file")"
  mcp_count="$(yq '.mcps | length' "$manifest_file")"
  repo_count="$(yq '.skills.repos | length' "$manifest_file")"
  env_count="$(yq '.env | length' "$manifest_file")"

  echo "MANIFEST_VERSION='$version'"
  echo "MANIFEST_MCP_COUNT='$mcp_count'"
  echo "MANIFEST_SKILL_REPO_COUNT='$repo_count'"
  echo "MANIFEST_ENV_COUNT='$env_count'"
}

# Basic grep/sed YAML parser (minimal fallback)
_oml_parse_manifest_basic() {
  local manifest_file="$1"

  oml_warn "Using basic YAML parser — complex YAML features may not parse correctly"

  local version
  version="$(grep '^version:' "$manifest_file" | head -1 | sed "s/version: *//; s/'//g; s/\"//g; s/ *$//")"
  echo "MANIFEST_VERSION='${version:-1}'"

  local mcp_count
  mcp_count="$(grep -c '  - name:' "$manifest_file" 2>/dev/null || echo "0")"
  echo "MANIFEST_MCP_COUNT='$mcp_count'"
}

# Get a list of skill repo URLs from manifest
# Usage: oml_get_skill_repo_urls <manifest-path>
# Outputs: one URL per line
oml_get_skill_repo_urls() {
  local manifest_file="$1"

  if ! command -v python3 &>/dev/null; then
    oml_error "python3 is required for skill repo extraction"
    return 1
  fi

  python3 - "$manifest_file" << 'PYEOF'
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
    print(repo.get('repo', ''))
PYEOF
}

# Get all env var names from manifest
# Usage: oml_get_env_var_names <manifest-path>
# Outputs: one var name per line
oml_get_env_var_names() {
  local manifest_file="$1"

  if ! command -v python3 &>/dev/null; then
    grep 'name:' "$manifest_file" | sed 's/.*name: *//' | grep '^[A-Z]' | tr -d "'"
    return
  fi

  python3 - "$manifest_file" << 'PYEOF'
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
for ev in data.get('env', []):
    print(ev.get('name', ''))
PYEOF
}
