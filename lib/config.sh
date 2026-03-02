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

# Generate ~/.config/opencode/opencode.json from manifest + personal overrides
# Also creates symlinks in ~/.claude/skills/ and ~/.config/opencode/skills/ for skill discovery
# Usage: oml_generate_opencode_config <manifest-path>
oml_generate_opencode_config() {
  local manifest_file="$1"
  local config_dir="$HOME/.config/opencode"
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

// Add plugins from manifest
if (manifest.plugins && Array.isArray(manifest.plugins) && manifest.plugins.length > 0) {
  config.plugin = manifest.plugins;
}

fs.writeFileSync(outputPath, JSON.stringify(config, null, 2) + '\n');
const count = Object.keys(teamMcps).length;
const pluginCount = config.plugin ? config.plugin.length : 0;
console.log(`Generated ${outputPath}\n  MCPs: ${count}\n  Plugins: ${pluginCount}`);
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

# Generate ~/.oml/config/claude.json and symlink to ~/.claude.json
# Usage: oml_generate_claude_config <manifest-path>
oml_generate_claude_config() {
  local manifest_file="$1"
  local config_dir="${OML_HOME}/config"
  local output_file="${config_dir}/claude.json"

  if ! command -v bun >/dev/null 2>&1; then return 1; fi
  if [ ! -f "$manifest_file" ]; then return 1; fi

  mkdir -p "$config_dir"
  local override_mcps_file="${OML_HOME}/overrides/mcps.yaml"
  oml_info "Generating claude.json from manifest..."

  local tmp_manifest tmp_override
  tmp_manifest=$(mktemp) tmp_override=$(mktemp)
  bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null || true
  if [ -f "$override_mcps_file" ]; then
    bunx -y js-yaml "$override_mcps_file" > "$tmp_override" 2>/dev/null || true
  else
    echo "{}" > "$tmp_override"
  fi

  bun - "$tmp_manifest" "$tmp_override" "$output_file" << 'BUNEOF'
const fs = require('fs');
let manifest = {}; try { manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); } catch (e) {}
let override = {}; try { override = JSON.parse(fs.readFileSync(process.argv[3], 'utf8')); } catch (e) {}

const mcpServers = {};
const allMcps = [...(manifest.mcps || []), ...(override.mcps || [])];

for (const mcp of allMcps) {
  if (!mcp.name) continue;
  if (mcp.enabled === false) {
    delete mcpServers[mcp.name];
    continue;
  }
  
  const entry = {};
  if (mcp.type === 'local' || mcp.command) {
    const parts = (mcp.command || '').trim().split(/\s+/);
    entry.command = parts[0];
    entry.args = parts.slice(1);
    if (mcp.environment) entry.env = mcp.environment;
  } else {
    // Claude might not fully support remote HTTP MCPs in the same json struct,
    // but we map it gracefully if possible.
    continue; // skipping URL based for now as Claude CLI focuses on local stdio
  }
  mcpServers[mcp.name] = entry;
}

const config = Object.keys(mcpServers).length > 0 ? { mcpServers } : {};
fs.writeFileSync(process.argv[4], JSON.stringify(config, null, 2) + '\n');
console.log(`Generated ${process.argv[4]} (Claude MCPs: ${Object.keys(mcpServers).length})`);
BUNEOF

  rm -f "$tmp_manifest" "$tmp_override"
  
  # create symlink for claude
  local target_link="$HOME/.claude.json"
  if [ ! -L "$target_link" ] || [ "$(readlink "$target_link")" != "$output_file" ]; then
    rm -f "$target_link"
    ln -s "$output_file" "$target_link"
    oml_success "Symlinked ~/.claude.json -> $output_file"
  fi
}

# Generate ~/.oml/config/codex.toml and symlink to ~/.codex/config.toml
# Usage: oml_generate_codex_config <manifest-path>
oml_generate_codex_config() {
  local manifest_file="$1"
  local config_dir="${OML_HOME}/config"
  local output_file="${config_dir}/codex.toml"

  if ! command -v bun >/dev/null 2>&1; then return 1; fi
  if [ ! -f "$manifest_file" ]; then return 1; fi

  mkdir -p "$config_dir"
  local override_mcps_file="${OML_HOME}/overrides/mcps.yaml"
  oml_info "Generating codex.toml from manifest..."

  local tmp_manifest tmp_override
  tmp_manifest=$(mktemp) tmp_override=$(mktemp)
  bunx -y js-yaml "$manifest_file" > "$tmp_manifest" 2>/dev/null || true
  if [ -f "$override_mcps_file" ]; then
    bunx -y js-yaml "$override_mcps_file" > "$tmp_override" 2>/dev/null || true
  else
    echo "{}" > "$tmp_override"
  fi

  bun - "$tmp_manifest" "$tmp_override" "$output_file" << 'BUNEOF'
const fs = require('fs');
let manifest = {}; try { manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); } catch (e) {}
let override = {}; try { override = JSON.parse(fs.readFileSync(process.argv[3], 'utf8')); } catch (e) {}

const mcpServers = {};
const allMcps = [...(manifest.mcps || []), ...(override.mcps || [])];

for (const mcp of allMcps) {
  if (!mcp.name) continue;
  if (mcp.enabled === false) {
    delete mcpServers[mcp.name];
    continue;
  }
  
  const entry = {};
  if (mcp.type === 'local' || mcp.command) {
    entry.command = mcp.command; // Codex usually expects string
    if (mcp.environment) entry.env = mcp.environment;
  } else if (mcp.url) {
    entry.url = mcp.url;
  }
  mcpServers[mcp.name] = entry;
}

// Generate TOML string manually since bun doesn't bundle a toml writer
let tomlLines = ['# oh-my-longfor generated codex config\n'];
for (const [name, srv] of Object.entries(mcpServers)) {
  tomlLines.push(`[mcp_servers.${name}]`);
  if (srv.command) {
    // Escape quotes in command
    tomlLines.push(`command = "${srv.command.replace(/"/g, '\\"')}"`);
  } else if (srv.url) {
    tomlLines.push(`url = "${srv.url.replace(/"/g, '\\"')}"`);
  }
  if (srv.env && Object.keys(srv.env).length > 0) {
    tomlLines.push('env = {');
    const envEntries = Object.entries(srv.env).map(([k,v]) => `  "${k}" = "${v}"`);
    tomlLines.push(envEntries.join(',\n'));
    tomlLines.push('}');
  }
  tomlLines.push('');
}

fs.writeFileSync(process.argv[4], tomlLines.join('\n'));
console.log(`Generated ${process.argv[4]} (Codex MCPs: ${Object.keys(mcpServers).length})`);
BUNEOF

  rm -f "$tmp_manifest" "$tmp_override"
  
  # create symlink for codex
  local codex_dir="$HOME/.codex"
  mkdir -p "$codex_dir"
  local target_link="$codex_dir/config.toml"
  if [ ! -L "$target_link" ] || [ "$(readlink "$target_link")" != "$output_file" ]; then
    rm -f "$target_link"
    ln -s "$output_file" "$target_link"
    oml_success "Symlinked ~/.codex/config.toml -> $output_file"
  fi
}

# Generate all configs in one call: opencode.json + oh-my-opencode.jsonc + env template + claude + codex
# Usage: oml_generate_all_configs <manifest-path>
oml_generate_all_configs() {
  local manifest_file="$1"
  oml_generate_opencode_config "$manifest_file"
  oml_generate_omo_config "$manifest_file"
  oml_generate_claude_config "$manifest_file"
  oml_generate_codex_config "$manifest_file"
  oml_generate_env_template "$manifest_file"
}
