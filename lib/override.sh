#!/usr/bin/env bash
# oh-my-longfor personal override mechanism
# Provides: user-level MCP/skill additions that survive oml update
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Default OML home (should be sourced from common.sh)
OML_HOME="${OML_HOME:-$HOME/.oml}"
OML_OVERRIDES_DIR="${OML_HOME}/overrides"

# Initialize override files if they don't exist
# Usage: oml_override_init
oml_override_init() {
  mkdir -p "$OML_OVERRIDES_DIR"

  if [ ! -f "${OML_OVERRIDES_DIR}/mcps.yaml" ]; then
    cat >"${OML_OVERRIDES_DIR}/mcps.yaml" <<'EOF'
# oh-my-longfor Personal MCP Overrides
# Add your personal MCPs here. These are MERGED on top of the team config.
# When the same MCP name exists in team config AND here, YOUR definition wins.
#
# Format:
#   - name: my-mcp
#     type: remote
#     url: "https://my-mcp.example.com/sse"
#     headers:
#       Authorization: "Bearer {env:MY_MCP_TOKEN}"
mcps: []
EOF
  fi

  if [ ! -f "${OML_OVERRIDES_DIR}/skills.yaml" ]; then
    cat >"${OML_OVERRIDES_DIR}/skills.yaml" <<'EOF'
# oh-my-longfor Personal Skill Repo Overrides
# Add your personal skill repos here. These are APPENDED to the team config.
#
# Format:
#   - repo: "https://github.com/you/your-skills"
#     branch: main
#     subdir: "skills/"
#     auth: null
repos: []
EOF
  fi

  if [ ! -f "${OML_OVERRIDES_DIR}/omo.yaml" ]; then
    cat >"${OML_OVERRIDES_DIR}/omo.yaml" <<'EOF'
# oh-my-longfor Personal oh-my-opencode Overrides
# These are deep-merged on top of team oh-my-opencode settings.
# YOUR values win on conflict.
#
# Example:
#   agents:
#     oracle:
#       model: "gpt-4o"
agents: {}
models: {}
disabled_mcps: []
disabled_skills: []
EOF
  fi
}

# Add a personal MCP override
# Usage: oml_override_add_mcp <name> <json-definition>
# Example: oml_override_add_mcp my-mcp '{"type":"remote","url":"https://my.example.com"}'
oml_override_add_mcp() {
  local name="$1"
  local json_def="$2"

  oml_override_init

  if ! command -v python3 >/dev/null 2>&1; then
    oml_error "python3 is required to modify override files"
    return 1
  fi

  python3 - "${OML_OVERRIDES_DIR}/mcps.yaml" "$name" "$json_def" << 'PYEOF'
import sys
import yaml
import json

override_file = sys.argv[1]
mcp_name      = sys.argv[2]
mcp_def_json  = sys.argv[3]

with open(override_file) as f:
    data = yaml.safe_load(f) or {}

mcps = data.get('mcps', [])
mcp_def = json.loads(mcp_def_json)
mcp_def['name'] = mcp_name

# Replace existing entry with same name, or append
existing = next((i for i, m in enumerate(mcps) if m.get('name') == mcp_name), None)
if existing is not None:
    mcps[existing] = mcp_def
    print(f"Updated override: {mcp_name}")
else:
    mcps.append(mcp_def)
    print(f"Added override: {mcp_name}")

data['mcps'] = mcps
with open(override_file, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
PYEOF

  oml_success "Override saved. Run 'oml update' to apply."
}

# Add a personal skill repo override
# Usage: oml_override_add_skill_repo <git-url> [branch]
oml_override_add_skill_repo() {
  local repo_url="$1"
  local branch="${2:-main}"

  oml_override_init

  if ! command -v python3 >/dev/null 2>&1; then
    oml_error "python3 is required to modify override files"
    return 1
  fi

  python3 - "${OML_OVERRIDES_DIR}/skills.yaml" "$repo_url" "$branch" << 'PYEOF'
import sys
import yaml

override_file = sys.argv[1]
repo_url      = sys.argv[2]
branch        = sys.argv[3]

with open(override_file) as f:
    data = yaml.safe_load(f) or {}

repos = data.get('repos', [])

# Don't add duplicate
if any(r.get('repo') == repo_url for r in repos):
    print(f"Already exists: {repo_url}")
    sys.exit(0)

repos.append({'repo': repo_url, 'branch': branch, 'subdir': 'skills/', 'auth': None})
data['repos'] = repos

with open(override_file, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

print(f"Added skill repo: {repo_url}")
PYEOF

  oml_success "Override saved. Run 'oml update' to apply."
}

# Remove an override entry by type and name
# Usage: oml_override_remove <mcp|skill> <name-or-url>
oml_override_remove() {
  local override_type="$1"
  local identifier="$2"

  oml_override_init

  if ! command -v python3 >/dev/null 2>&1; then
    oml_error "python3 is required to modify override files"
    return 1
  fi

  case "$override_type" in
    mcp)
      python3 - "${OML_OVERRIDES_DIR}/mcps.yaml" "$identifier" << 'PYEOF'
import sys
import yaml

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}

before = len(data.get('mcps', []))
data['mcps'] = [m for m in data.get('mcps', []) if m.get('name') != sys.argv[2]]
after = len(data['mcps'])

with open(sys.argv[1], 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

if before > after:
    print(f"Removed MCP override: {sys.argv[2]}")
else:
    print(f"No MCP override found with name: {sys.argv[2]}")
PYEOF
      ;;
    skill)
      python3 - "${OML_OVERRIDES_DIR}/skills.yaml" "$identifier" << 'PYEOF'
import sys
import yaml

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}

before = len(data.get('repos', []))
data['repos'] = [r for r in data.get('repos', []) if r.get('repo') != sys.argv[2]]
after = len(data['repos'])

with open(sys.argv[1], 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

if before > after:
    print(f"Removed skill repo override: {sys.argv[2]}")
else:
    print(f"No skill repo override found: {sys.argv[2]}")
PYEOF
      ;;
    *)
      oml_error "Unknown override type: $override_type (expected: mcp or skill)"
      return 1
      ;;
  esac
}

# List all personal overrides
# Usage: oml_override_list
oml_override_list() {
  oml_override_init

  if ! command -v python3 >/dev/null 2>&1; then
    oml_error "python3 is required to read override files"
    return 1
  fi

  python3 - "${OML_OVERRIDES_DIR}/mcps.yaml" "${OML_OVERRIDES_DIR}/skills.yaml" << 'PYEOF'
import sys
import yaml

with open(sys.argv[1]) as f:
    mcp_data = yaml.safe_load(f) or {}
with open(sys.argv[2]) as f:
    skill_data = yaml.safe_load(f) or {}

mcps  = mcp_data.get('mcps', [])
repos = skill_data.get('repos', [])

print("Personal Overrides:")
print("")

if mcps:
    print("  MCP Overrides:")
    for m in mcps:
        print(f"    - {m.get('name')} ({m.get('url', 'no url')})")
else:
    print("  MCP Overrides: (none)")

print("")

if repos:
    print("  Skill Repo Overrides:")
    for r in repos:
        print(f"    - {r.get('repo')} (branch: {r.get('branch', 'main')})")
else:
    print("  Skill Repo Overrides: (none)")
PYEOF
}

# Merge personal MCP overrides into a list of MCPs from the team manifest
# Usage: oml_merge_mcp_overrides <team-mcps-json>
# Outputs: merged JSON array of MCPs (personal overrides win on conflict)
oml_merge_mcp_overrides() {
  local team_mcps_json="$1"

  oml_override_init

  if ! command -v python3 >/dev/null 2>&1; then
    echo "$team_mcps_json"
    return
  fi

  python3 - "${OML_OVERRIDES_DIR}/mcps.yaml" "$team_mcps_json" << 'PYEOF'
import sys
import yaml
import json

with open(sys.argv[1]) as f:
    override_data = yaml.safe_load(f) or {}

team_mcps     = json.loads(sys.argv[2])
override_mcps = override_data.get('mcps', [])

# Build merged dict: team first, then personal overrides win
merged = {m['name']: m for m in team_mcps}
for m in override_mcps:
    merged[m['name']] = m

print(json.dumps(list(merged.values()), indent=2))
PYEOF
}

# Get personal skill repos as JSON array for inclusion in config
# Usage: oml_get_override_skill_repos
# Outputs: JSON array of skill repo objects
oml_get_override_skill_repos() {
  oml_override_init

  if ! command -v python3 >/dev/null 2>&1; then
    echo "[]"
    return
  fi

  python3 - "${OML_OVERRIDES_DIR}/skills.yaml" << 'PYEOF'
import sys
import yaml
import json

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}

print(json.dumps(data.get('repos', []), indent=2))
PYEOF
}
