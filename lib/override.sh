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
    cat >"${OML_OVERRIDES_DIR}/mcps.yaml" <<'YAML_EOF'
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
YAML_EOF
  fi

  if [ ! -f "${OML_OVERRIDES_DIR}/skills.yaml" ]; then
    cat >"${OML_OVERRIDES_DIR}/skills.yaml" <<'YAML_EOF'
# oh-my-longfor Personal Skill Repo Overrides
# Add your personal skill repos here. These are APPENDED to the team config.
#
# Format:
#   - repo: "https://github.com/you/your-skills"
#     branch: main
#     subdir: "skills/"
#     auth: null
repos: []
YAML_EOF
  fi

  if [ ! -f "${OML_OVERRIDES_DIR}/omo.yaml" ]; then
    cat >"${OML_OVERRIDES_DIR}/omo.yaml" <<'YAML_EOF'
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
YAML_EOF
  fi
}

# Add a personal MCP override
# Usage: oml_override_add_mcp <name> <json-definition>
# Example: oml_override_add_mcp my-mcp '{"type":"remote","url":"https://my.example.com"}'
oml_override_add_mcp() {
  local name="$1"
  local json_def="$2"

  oml_override_init

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to modify override files"
    return 1
  fi

  local override_file="${OML_OVERRIDES_DIR}/mcps.yaml"
  local tmp_override
  tmp_override=$(mktemp)
  
  if ! bunx -y js-yaml "$override_file" > "$tmp_override" 2>/dev/null; then
    echo '{"mcps":[]}' > "$tmp_override"
  fi

  local tmp_out
  tmp_out=$(mktemp)

  bun - "$tmp_override" "$name" "$json_def" "$tmp_out" << 'BUNEOF'
const fs = require('fs');

const overrideFile = process.argv[2];
const mcpName      = process.argv[3];
const mcpDefJson   = process.argv[4];
const outJsonFile  = process.argv[5];

let data = { mcps: [] };
try { data = JSON.parse(fs.readFileSync(overrideFile, 'utf8')); } catch (e) {}

if (!data.mcps) data.mcps = [];

let mcpDef = {};
try { mcpDef = JSON.parse(mcpDefJson); } catch(e) { 
  console.error("Invalid JSON provided for MCP definition");
  process.exit(1);
}

mcpDef.name = mcpName;

const existingIndex = data.mcps.findIndex(m => m.name === mcpName);
if (existingIndex !== -1) {
  data.mcps[existingIndex] = mcpDef;
  console.log(`Updated override: ${mcpName}`);
} else {
  data.mcps.push(mcpDef);
  console.log(`Added override: ${mcpName}`);
}

fs.writeFileSync(outJsonFile, JSON.stringify(data, null, 2));
BUNEOF

  if bunx -y js-yaml "$tmp_out" > "$override_file" 2>/dev/null; then
    oml_success "Override saved. Run 'oml update' to apply."
  fi
  
  rm -f "$tmp_override" "$tmp_out"
}

# Add a personal skill repo override
# Usage: oml_override_add_skill_repo <git-url> [branch]
oml_override_add_skill_repo() {
  local repo_url="$1"
  local branch="${2:-main}"

  oml_override_init

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to modify override files"
    return 1
  fi

  local override_file="${OML_OVERRIDES_DIR}/skills.yaml"
  local tmp_override
  tmp_override=$(mktemp)
  
  if ! bunx -y js-yaml "$override_file" > "$tmp_override" 2>/dev/null; then
    echo '{"repos":[]}' > "$tmp_override"
  fi

  local tmp_out
  tmp_out=$(mktemp)

  bun - "$tmp_override" "$repo_url" "$branch" "$tmp_out" << 'BUNEOF'
const fs = require('fs');

const overrideFile = process.argv[2];
const repoUrl      = process.argv[3];
const branch       = process.argv[4];
const outJsonFile  = process.argv[5];

let data = { repos: [] };
try { data = JSON.parse(fs.readFileSync(overrideFile, 'utf8')); } catch (e) {}

if (!data.repos) data.repos = [];

const exists = data.repos.some(r => r.repo === repoUrl);
if (exists) {
  console.log(`Already exists: ${repoUrl}`);
  process.exit(0);
}

data.repos.push({ repo: repoUrl, branch: branch, subdir: 'skills/', auth: null });
console.log(`Added skill repo: ${repoUrl}`);

fs.writeFileSync(outJsonFile, JSON.stringify(data, null, 2));
BUNEOF

  if [ -s "$tmp_out" ] && bunx -y js-yaml "$tmp_out" > "$override_file" 2>/dev/null; then
    oml_success "Override saved. Run 'oml update' to apply."
  fi
  
  rm -f "$tmp_override" "$tmp_out"
}

# Remove an override entry by type and name
# Usage: oml_override_remove <mcp|skill> <name-or-url>
oml_override_remove() {
  local override_type="$1"
  local identifier="$2"

  oml_override_init

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to modify override files"
    return 1
  fi

  local override_file tmp_override tmp_out
  
  case "$override_type" in
    mcp)
      override_file="${OML_OVERRIDES_DIR}/mcps.yaml"
      tmp_override=$(mktemp)
      bunx -y js-yaml "$override_file" > "$tmp_override" 2>/dev/null || echo '{"mcps":[]}' > "$tmp_override"
      tmp_out=$(mktemp)
      
      bun - "$tmp_override" "$identifier" "$tmp_out" << 'BUNEOF'
const fs = require('fs');
const inFile = process.argv[2];
const target = process.argv[3];
const outFile = process.argv[4];

let data = { mcps: [] };
try { data = JSON.parse(fs.readFileSync(inFile, 'utf8')); } catch(e) {}
if (!data.mcps) data.mcps = [];

const before = data.mcps.length;
data.mcps = data.mcps.filter(m => m.name !== target);
const after = data.mcps.length;

if (before > after) {
  console.log(`Removed MCP override: ${target}`);
} else {
  console.log(`No MCP override found with name: ${target}`);
}

fs.writeFileSync(outFile, JSON.stringify(data, null, 2));
BUNEOF

      if bunx -y js-yaml "$tmp_out" > "$override_file" 2>/dev/null; then
        : # written successfully
      fi
      rm -f "$tmp_override" "$tmp_out"
      ;;
      
    skill)
      override_file="${OML_OVERRIDES_DIR}/skills.yaml"
      tmp_override=$(mktemp)
      bunx -y js-yaml "$override_file" > "$tmp_override" 2>/dev/null || echo '{"repos":[]}' > "$tmp_override"
      tmp_out=$(mktemp)
      
      bun - "$tmp_override" "$identifier" "$tmp_out" << 'BUNEOF'
const fs = require('fs');
const inFile = process.argv[2];
const target = process.argv[3];
const outFile = process.argv[4];

let data = { repos: [] };
try { data = JSON.parse(fs.readFileSync(inFile, 'utf8')); } catch(e) {}
if (!data.repos) data.repos = [];

const before = data.repos.length;
data.repos = data.repos.filter(r => r.repo !== target);
const after = data.repos.length;

if (before > after) {
  console.log(`Removed skill repo override: ${target}`);
} else {
  console.log(`No skill repo override found: ${target}`);
}

fs.writeFileSync(outFile, JSON.stringify(data, null, 2));
BUNEOF

      if bunx -y js-yaml "$tmp_out" > "$override_file" 2>/dev/null; then
        : # written successfully
      fi
      rm -f "$tmp_override" "$tmp_out"
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

  if ! command -v bun >/dev/null 2>&1; then
    oml_error "bun is required to read override files"
    return 1
  fi

  local mcp_file="${OML_OVERRIDES_DIR}/mcps.yaml"
  local skill_file="${OML_OVERRIDES_DIR}/skills.yaml"
  
  local tmp_mcp tmp_skill
  tmp_mcp=$(mktemp)
  tmp_skill=$(mktemp)
  
  bunx -y js-yaml "$mcp_file" > "$tmp_mcp" 2>/dev/null || echo '{"mcps":[]}' > "$tmp_mcp"
  bunx -y js-yaml "$skill_file" > "$tmp_skill" 2>/dev/null || echo '{"repos":[]}' > "$tmp_skill"

  bun - "$tmp_mcp" "$tmp_skill" << 'BUNEOF'
const fs = require('fs');

const mcpFile = process.argv[2];
const skillFile = process.argv[3];

let mcpData = { mcps: [] };
let skillData = { repos: [] };

try { mcpData = JSON.parse(fs.readFileSync(mcpFile, 'utf8')); } catch(e) {}
try { skillData = JSON.parse(fs.readFileSync(skillFile, 'utf8')); } catch(e) {}

const mcps = mcpData.mcps || [];
const repos = skillData.repos || [];

console.log('Personal Overrides:\n');

if (mcps.length > 0) {
  console.log('  MCP Overrides:');
  for (const m of mcps) {
    console.log(`    - ${m.name} (${m.url || 'local command'})`);
  }
} else {
  console.log('  MCP Overrides: (none)');
}

console.log('');

if (repos.length > 0) {
  console.log('  Skill Repo Overrides:');
  for (const r of repos) {
    console.log(`    - ${r.repo} (branch: ${r.branch || 'main'})`);
  }
} else {
  console.log('  Skill Repo Overrides: (none)');
}
BUNEOF

  rm -f "$tmp_mcp" "$tmp_skill"
}

# Merge personal MCP overrides into a list of MCPs from the team manifest
# Usage: oml_merge_mcp_overrides <team-mcps-json>
# Outputs: merged JSON array of MCPs (personal overrides win on conflict)
oml_merge_mcp_overrides() {
  local team_mcps_json="$1"

  oml_override_init

  if ! command -v bun >/dev/null 2>&1; then
    echo "$team_mcps_json"
    return
  fi

  local override_file="${OML_OVERRIDES_DIR}/mcps.yaml"
  local tmp_override
  tmp_override=$(mktemp)
  bunx -y js-yaml "$override_file" > "$tmp_override" 2>/dev/null || echo '{"mcps":[]}' > "$tmp_override"

  bun - "$tmp_override" "$team_mcps_json" << 'BUNEOF'
const fs = require('fs');

const overrideFile = process.argv[2];
const teamMcpsStr = process.argv[3];

let overrideData = { mcps: [] };
try { overrideData = JSON.parse(fs.readFileSync(overrideFile, 'utf8')); } catch(e) {}

let teamMcps = [];
try { teamMcps = JSON.parse(teamMcpsStr); } catch(e) {}

const overrideMcps = overrideData.mcps || [];

const merged = {};
for (const m of teamMcps) {
  if (m.name) merged[m.name] = m;
}

for (const m of overrideMcps) {
  if (m.name) merged[m.name] = m;
}

console.log(JSON.stringify(Object.values(merged), null, 2));
BUNEOF

  rm -f "$tmp_override"
}

# Get personal skill repos as JSON array for inclusion in config
# Usage: oml_get_override_skill_repos
# Outputs: JSON array of skill repo objects
oml_get_override_skill_repos() {
  oml_override_init

  if ! command -v bun >/dev/null 2>&1; then
    echo "[]"
    return
  fi

  local override_file="${OML_OVERRIDES_DIR}/skills.yaml"
  local tmp_override
  tmp_override=$(mktemp)
  bunx -y js-yaml "$override_file" > "$tmp_override" 2>/dev/null || echo '{"repos":[]}' > "$tmp_override"

  bun - "$tmp_override" << 'BUNEOF'
const fs = require('fs');
const overrideFile = process.argv[2];

let data = { repos: [] };
try { data = JSON.parse(fs.readFileSync(overrideFile, 'utf8')); } catch(e) {}

console.log(JSON.stringify(data.repos || [], null, 2));
BUNEOF

  rm -f "$tmp_override"
}
