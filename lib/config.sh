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

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to generate opencode.json"
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

  local tmp_manifest
  tmp_manifest=$(mktemp)
  if ! bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null; then
    oml_error "Invalid YAML in manifest: $manifest_file"
    rm -f "$tmp_manifest"
    return 1
  fi

  local tmp_override
  tmp_override=$(mktemp)
  if [ -f "$override_mcps_file" ]; then
    if ! bunx -y js-yaml "$override_mcps_file" > "$tmp_override" 2>/dev/null; then
      oml_error "Invalid YAML in overrides: $override_mcps_file"
      rm -f "$tmp_manifest" "$tmp_override"
      return 1
    fi
  else
    echo "{}" > "$tmp_override"
  fi

  bun - "$tmp_manifest" "$tmp_override" "$output_file" << 'BUNEOF'
const fs = require('fs');

const manifestPath = process.argv[2];
const overridePath = process.argv[3];
const outputPath = process.argv[4];

let manifest = {};
try { manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8')); } catch (e) {}

let override = {};
try { override = JSON.parse(fs.readFileSync(overridePath, 'utf8')); } catch (e) {}

const teamMcps = {};
for (const mcp of manifest.mcps || []) {
  if (!mcp.name) continue;
  
  const entry = { type: mcp.type || 'remote' };
  
  if (entry.type === 'local') {
    if (mcp.command) entry.command = mcp.command;
    if (mcp.environment) entry.environment = mcp.environment;
  } else {
    entry.url = mcp.url || '';
    if (mcp.headers) entry.headers = mcp.headers;
  }
  
  if (mcp.enabled !== undefined) entry.enabled = mcp.enabled;
  if (mcp.timeout !== undefined) entry.timeout = mcp.timeout;
  
  teamMcps[mcp.name] = entry;
}

for (const mcp of override.mcps || []) {
  if (!mcp.name) continue;
  const entry = {};
  for (const [k, v] of Object.entries(mcp)) {
    if (k !== 'name') entry[k] = v;
  }
  teamMcps[mcp.name] = entry;
}

const config = {
  $schema: 'https://opencode.ai/config.json',
  mcp: teamMcps
};

fs.writeFileSync(outputPath, JSON.stringify(config, null, 2) + '\n');
const count = Object.keys(teamMcps).length;
console.log(`Generated ${outputPath}\n  MCPs: ${count}`);
BUNEOF

  rm -f "$tmp_manifest" "$tmp_override"
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

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to generate oh-my-opencode.jsonc"
    return 1
  fi

  if [ ! -f "$manifest_file" ]; then
    oml_error "Manifest file not found: $manifest_file"
    return 1
  fi

  mkdir -p "$config_dir"

  local override_omo_file="${OML_HOME}/overrides/omo.yaml"

  oml_info "Generating oh-my-opencode.jsonc from manifest..."

  local tmp_manifest
  tmp_manifest=$(mktemp)
  if ! bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null; then
    oml_error "Invalid YAML in manifest: $manifest_file"
    rm -f "$tmp_manifest"
    return 1
  fi

  local tmp_override
  tmp_override=$(mktemp)
  if [ -f "$override_omo_file" ]; then
    if ! bunx -y js-yaml "$override_omo_file" > "$tmp_override" 2>/dev/null; then
      oml_error "Invalid YAML in overrides: $override_omo_file"
      rm -f "$tmp_manifest" "$tmp_override"
      return 1
    fi
  else
    echo "{}" > "$tmp_override"
  fi

  bun - "$tmp_manifest" "$tmp_override" "$output_file" << 'BUNEOF'
const fs = require('fs');

const manifestPath = process.argv[2];
const overridePath = process.argv[3];
const outputPath = process.argv[4];

let manifest = {};
try { manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8')); } catch (e) {}

let userOverrides = {};
try { userOverrides = JSON.parse(fs.readFileSync(overridePath, 'utf8')); } catch (e) {}

const omo_overrides = manifest.omo_overrides || {};

const config = {
  $schema: 'https://raw.githubusercontent.com/drrcknlsn/oh-my-opencode/main/schema.json',
  agents: omo_overrides.agents || {},
  models: omo_overrides.models || {},
  disabled_mcps: omo_overrides.disabled_mcps || [],
  disabled_skills: omo_overrides.disabled_skills || [],
};

for (const key of ['agents', 'models']) {
  if (userOverrides[key]) {
    config[key] = { ...config[key], ...userOverrides[key] };
  }
}

for (const key of ['disabled_mcps', 'disabled_skills']) {
  if (userOverrides[key] && Array.isArray(userOverrides[key])) {
    const combined = [...(config[key] || []), ...userOverrides[key]];
    config[key] = [...new Set(combined)]; // deduplicate
  }
}

let outContent = '// oh-my-longfor generated oh-my-opencode config\n';
outContent += '// Regenerated by: oml update\n';
outContent += '// Edit ~/.oml/overrides/omo.yaml for personal overrides.\n';
outContent += JSON.stringify(config, null, 2) + '\n';

fs.writeFileSync(outputPath, outContent);
console.log(`Generated ${outputPath}`);
BUNEOF

  rm -f "$tmp_manifest" "$tmp_override"
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
