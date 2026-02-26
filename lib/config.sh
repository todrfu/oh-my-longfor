#!/usr/bin/env bash
# oh-my-longfor config generator
# Generates opencode.json and oh-my-opencode.jsonc from manifest + overrides
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=lib/override.sh
# source "$(dirname "${BASH_SOURCE[0]}")/override.sh"
# shellcheck source=lib/backup.sh
# source "$(dirname "${BASH_SOURCE[0]}")/backup.sh"

# Default OML home (should be sourced from common.sh)
OML_HOME="${OML_HOME:-$HOME/.oml}"

# Generate ~/.oml/config/opencode.json from manifest + personal overrides
# Also creates symlinks in ~/.claude/skills/ and ~/.config/opencode/skills/ for skill discovery
# Usage: oml_generate_opencode_config <manifest-path>
oml_generate_opencode_config() {
  local manifest_file="$1"
  local config_dir="${OML_HOME}/config"
  local output_file="${config_dir}/opencode.json"

  if ! command -v python3 >/dev/null 2>&1; then
    oml_error "python3 is required to generate opencode.json"
    return 1
  fi

  if [ ! -f "$manifest_file" ]; then
    oml_error "Manifest file not found: $manifest_file"
    return 1
  fi

  mkdir -p "$config_dir"

  # Create backup before overwriting
  oml_backup_create

  local override_mcps_file="${OML_HOME}/overrides/mcps.yaml"

  oml_info "Generating opencode.json from manifest..."

  python3 - "$manifest_file" "$output_file" "$override_mcps_file" << 'PYEOF'
import sys
import yaml
import json
import os
manifest_path  = sys.argv[1]
output_path    = sys.argv[2]
override_file  = sys.argv[3]

try:
    with open(manifest_path) as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f'[oml] ERROR: Invalid YAML in manifest: {e}', file=sys.stderr)
    sys.exit(1)
if data is None:
    print('[oml] ERROR: Manifest file is empty or invalid', file=sys.stderr)
    sys.exit(1)

# ── MCPs ──────────────────────────────────────────────────────────────────────────────
team_mcps = {}
for mcp in data.get('mcps', []):
    name = mcp.get('name')
    if not name:
        continue
    mcp_type = mcp.get('type', 'remote')
    if mcp_type == 'local':
        # stdio transport: command is an array, optional environment dict
        entry = {'type': 'local'}
        if 'command' in mcp:
            entry['command'] = mcp['command']
        if 'environment' in mcp:
            entry['environment'] = mcp['environment']
    else:
        # remote/SSE transport
        entry = {
            'type': 'remote',
            'url':  mcp.get('url', ''),
        }
        if 'headers' in mcp:
            entry['headers'] = mcp['headers']
    if 'enabled' in mcp:
        entry['enabled'] = mcp['enabled']
    if 'timeout' in mcp:
        entry['timeout'] = mcp['timeout']
    team_mcps[name] = entry

# Apply personal overrides (user wins on conflict)
if os.path.isfile(override_file):
    with open(override_file) as f:
        override_data = yaml.safe_load(f) or {}
    for mcp in override_data.get('mcps', []):
        name = mcp.get('name')
        if not name:
            continue
        entry = {k: v for k, v in mcp.items() if k != 'name'}
        team_mcps[name] = entry

# ── Assemble config ───────────────────────────────────────────────────────────
config = {
    '$schema': 'https://opencode.ai/config.json',
    'mcp': team_mcps,
}

with open(output_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print(f"Generated {output_path}")
print(f"  MCPs: {len(team_mcps)}")
PYEOF

  oml_success "Generated opencode.json"

  # Create skill symlinks in ~/.claude/skills/ and ~/.config/opencode/skills/
  if command -v oml_create_skill_symlinks >/dev/null 2>&1; then
    oml_create_skill_symlinks
  fi
}

# Generate ~/.oml/config/oh-my-opencode.jsonc from manifest + personal overrides
# Usage: oml_generate_omo_config <manifest-path>
oml_generate_omo_config() {
  local manifest_file="$1"
  local config_dir="${OML_HOME}/config"
  local output_file="${config_dir}/oh-my-opencode.jsonc"

  if ! command -v python3 >/dev/null 2>&1; then
    oml_error "python3 is required to generate oh-my-opencode.jsonc"
    return 1
  fi

  if [ ! -f "$manifest_file" ]; then
    oml_error "Manifest file not found: $manifest_file"
    return 1
  fi

  mkdir -p "$config_dir"

  local override_omo_file="${OML_HOME}/overrides/omo.yaml"
  local repos_dir="${OML_HOME}/repos"

  oml_info "Generating oh-my-opencode.jsonc from manifest..."

  python3 - "$manifest_file" "$output_file" "$override_omo_file" "$repos_dir" << 'PYEOF'
import sys
import yaml
import json
import os

manifest_path  = sys.argv[1]
output_path    = sys.argv[2]
override_file  = sys.argv[3]
repos_dir      = sys.argv[4]

try:
    with open(manifest_path) as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f'[oml] ERROR: Invalid YAML in manifest: {e}', file=sys.stderr)
    sys.exit(1)
if data is None:
    print('[oml] ERROR: Manifest file is empty or invalid', file=sys.stderr)
    sys.exit(1)

omo_overrides = data.get('omo_overrides', {}) or {}

# Start with team base config
config = {
    '$schema': 'https://raw.githubusercontent.com/drrcknlsn/oh-my-opencode/main/schema.json',
    'agents': dict(omo_overrides.get('agents', {}) or {}),
    'models': dict(omo_overrides.get('models', {}) or {}),
    'disabled_mcps':    list(omo_overrides.get('disabled_mcps', []) or []),
    'disabled_skills':  list(omo_overrides.get('disabled_skills', []) or []),
}

# Apply personal omo overrides (deep merge, user wins)
if os.path.isfile(override_file):
    with open(override_file) as f:
        user_overrides = yaml.safe_load(f) or {}
    for key in ('agents', 'models'):
        if user_overrides.get(key):
            config[key].update(user_overrides[key])
    for key in ('disabled_mcps', 'disabled_skills'):
        if user_overrides.get(key):
            # Merge lists, deduplicate
            combined = list(set(config.get(key, []) + list(user_overrides[key])))
            config[key] = combined

with open(output_path, 'w') as f:
    # Write as JSONC with a header comment
    f.write('// oh-my-longfor generated oh-my-opencode config\n')
    f.write('// Regenerated by: oml update\n')
    f.write('// Edit ~/.oml/overrides/omo.yaml for personal overrides.\n')
    json.dump(config, f, indent=2)
    f.write('\n')

print(f"Generated {output_path}")
PYEOF

  oml_success "Generated oh-my-opencode.jsonc"
}

# Generate all configs in one call: opencode.json + oh-my-opencode.jsonc + env template
# Usage: oml_generate_all_configs <manifest-path>
oml_generate_all_configs() {
  local manifest_file="$1"
  oml_generate_opencode_config "$manifest_file"
  oml_generate_omo_config "$manifest_file"
  oml_generate_env_template "$manifest_file"
}
