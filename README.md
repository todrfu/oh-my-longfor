[English](README.md) | [中文](README.zh-CN.md)
# oh-my-longfor (oml)

> **The declarative bootstrap & configuration manager for OpenCode.**
> Install bun, opencode, oh-my-opencode, MCP servers, and Skills with a single command.

[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)]()

`oh-my-longfor` (oml) is a zero-dependency shell tool that bootstraps a complete AI development environment. It seamlessly provisions OpenCode, the oh-my-opencode plugin, and dynamically configures Model Context Protocol (MCP) servers and reusable agent skills based on a declarative `manifest.yaml`.

---

## 🚀 Features

- **Zero-Dependency Bootstrap**: Written in pure `bash`. Only requires `curl` and `git` to run.
- **Toolchain Management**: Automatically installs `bun`, `opencode` (via official binaries), and the `oh-my-opencode` plugin if they are missing. Supports **macOS** (Intel & Apple Silicon) and **Linux** (x86\_64 & arm64). Windows is not supported.
- **Declarative Configuration**: Define your MCP servers, Skill repositories, and required API keys in a simple `manifest.yaml`.
- **Vanilla or Team Modes**: Use it standalone as a quick installer, or point it to a remote Git repository to sync configurations across multiple machines or a development team.
- **Local Overrides**: Add personal MCP servers or skills without altering the shared configuration.
- **Safe Operations**: Automatic backups before every update. Easy rollbacks.
- **Idempotent Shell Configuration**: Automatically injects `OPENCODE_CONFIG` and `$PATH` into your `.zshrc` / `.bashrc` without duplicate entries.

---

## 📦 Installation & Quick Start

You can install `oh-my-longfor` in one of two modes:

### Mode 1: Vanilla Installation (Standalone)

Perfect if you just want to quickly install the `opencode` toolchain and set up a clean, local configuration framework. No remote configuration is pulled.

```bash
OML_SELF_REPO=https://github.com/todrfu/oh-my-longfor \
  curl -fsSL https://raw.githubusercontent.com/todrfu/oh-my-longfor/main/install.sh | bash
```
*(Note: You must set `OML_SELF_REPO` to the repository URL so the installer can download its dependencies. Replace the URLs with your actual repository if you have forked this project).*

### Mode 2: Dotfiles / Team Installation (Sync Mode)

If you have a remote Git repository containing a `manifest.yaml` file (e.g., team dotfiles or your personal configurations), pass the repository URL as an argument:

```bash
OML_SELF_REPO=https://github.com/todrfu/oh-my-longfor \
  curl -fsSL https://raw.githubusercontent.com/todrfu/oh-my-longfor/main/install.sh \
  | bash -s -- https://gitlab.com/your-org/team-config
```


### Mode 3: Local Development / Direct Clone

If you have cloned the `oh-my-longfor` repository directly (e.g., for development or testing), you can run `install.sh` directly from your local copy:

```bash
# Clone the repo
git clone https://github.com/todrfu/oh-my-longfor.git
cd oh-my-longfor

# Run with vanilla mode (no team config)
./install.sh

# Or with a team config URL
./install.sh https://gitlab.com/your-org/team-config

# Or with a local manifest file
./install.sh ./my-local-config/manifest.yaml
```

The installer automatically detects that it's running from a local directory and uses the `lib/` and `bin/oml` from the current directory.


### Post-Installation Steps

After the installation finishes, the script will **automatically reload your shell** (via `exec "$SHELL" -l`), so your new configuration is active immediately.

Next, you may need to:

1. **Add your required API Keys:**
   `oh-my-longfor` sets up a centralized environment file. Edit it to add any API keys your team's `manifest.yaml` requires:
   ```bash
   nano ~/.oml/env/.env.oml
   ```
   *(Run `oml env` if you aren't sure which keys are required).*

2. **Configure your AI subscriptions (Claude / Gemini / Copilot, etc.):**
   Set up your preferred LLM provider for OpenCode:
   ```bash
   bunx oh-my-opencode install
   ```

3. **Verify the installation:**
   ```bash
   oml doctor
   oml status
   ```

---

## 🛠 Configuration (manifest.yaml)

When using Mode 2 (or manually creating a manifest in Mode 1), `oh-my-longfor` relies on a declarative `manifest.yaml`.

Here is a complete example:

```yaml
version: "1"

# ─── MCP Servers ────────────────────────────────────────────
# Two transport types are supported:
#   remote — SSE/HTTP servers (hosted, no local install required)
#   local  — stdio servers that run as a local process (npx, uv, etc.)
mcps:
  # Remote MCP: SSE transport, authenticated via HTTP header
  - name: context7
    type: remote
    url: "https://mcp.context7.com/sse"
    headers:
      Authorization: "Bearer {env:CONTEXT7_API_KEY}"  # Resolved at runtime

  # Local MCP: stdio transport via npx (Node.js)
  # 'command' is an array — first element is the executable, rest are arguments
  - name: sequential-thinking
    type: local
    command: ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"]

  # Local MCP: stdio transport via uv (Python)
  # - name: my-python-mcp
  #   type: local
  #   command: ["uv", "run", "my-mcp-server"]
  #   environment:                     # Optional env vars passed to the process
  #     MY_API_KEY: "{env:MY_API_KEY}"

# ─── Agent Skills ───────────────────────────────────────────
# Repositories are cloned to ~/.oml/repos/ and symlinked for discovery
skills:
  repos:
    - repo: "https://gitlab.com/your-org/shared-skills"
      branch: main          # Default: main
      subdir: "skills/"     # Default: skills/
      auth: null            # Options: null (public), token (uses GITHUB_TOKEN), ssh

# ─── Environment Variables ────────────────────────────────────
# Defines required/optional API keys. Generates a ~/.oml/env/.env.template file.
env:
  - name: CONTEXT7_API_KEY
    description: "Get your key from https://context7.com/settings"
    required: true

# ─── oh-my-opencode Overrides (Optional) ─────────────────────────
omo_overrides:
  agents:
    oracle:
      model: "gpt-4o"
  disabled_mcps: []
  disabled_skills: []
```

---

## 💻 CLI Reference

The `oml` CLI tool manages your local environment after installation.

### Sync & Updates

```bash
# Pull the latest configuration from your team/remote config and regenerate JSON files
oml update
```

### Diagnostics & Status

```bash
# Display the current state of repositories, configs, and env vars
oml status

# Run diagnostic checks with automatic fix suggestions
oml doctor

# Check which required API keys are set or missing
oml env
```

### Local Overrides

You can add personal MCPs or Skill repositories that will *not* be overwritten when you run `oml update`.

```bash
# List current personal overrides
oml override list

# Add a personal MCP server
oml override add-mcp my-local-mcp '{"type":"remote","url":"http://localhost:3000/sse"}'

# Add a personal Skill repository
oml override add-skill-repo https://github.com/you/my-skills main

# Remove an override
oml override remove mcp my-local-mcp
```

*Note: You can also manually edit the YAML files in `~/.oml/overrides/`.*

### Backups & Rollbacks

Before every `oml update` or configuration regeneration, `oh-my-longfor` creates a backup (up to 5 are kept).

```bash
# List available backups
oml backup list

# Restore the most recent backup
oml rollback

# Restore a specific timestamp
oml rollback 2026-02-25-143022
```

---

## 📁 Architecture & Directory Structure

`oh-my-longfor` installs entirely into `~/.oml/` and keeps your home directory clean.

```
~/.oml/
├── bin/
│   └── oml                         ← CLI executable (added to $PATH)
├── lib/                            ← Bash library functions
├── repos/
│   ├── team-config/                ← Cloned config repository (if Mode 2)
│   └── team-skills/                ← Cloned skill repositories
├── config/
│   ├── opencode.json               ← Generated OpenCode config
│   └── oh-my-opencode.jsonc        ← Generated OMO config
├── env/
│   └── .env.template               ← Generated API key template
├── overrides/                      ← Your personal override configs
└── backups/                        ← Automatic backups (timestamped)

# Symlinks created automatically for skill discovery:
~/.claude/skills/
~/.config/opencode/skills/
```

- OpenCode resolves the config via `OPENCODE_CONFIG=~/.oml/config/opencode.json` (injected into shell rc).
- Skills are symlinked to standard locations to ensure they are discovered by both OpenCode's native loader and Claude Code.

---

## ❓ FAQ

**Q: How do I manage API Keys securely?**
Run `oml env` to see required keys. The installer automatically copies the template to `~/.oml/env/.env.oml` and configures your shell to source it. You just need to edit it:
```bash
nano ~/.oml/env/.env.oml
```

**Q: `curl | bash` fails with "Could not clone oml repo"?**
Ensure you prefix the command with `OML_SELF_REPO` pointing to the script's repository URL.

**Q: How do I completely uninstall?**
You can use the provided uninstallation script to cleanly remove `oh-my-longfor`, `opencode`, and `oh-my-opencode` from your system (including RC injections and global packages):
```bash
curl -fsSL https://raw.githubusercontent.com/todrfu/oh-my-longfor/main/uninstall.sh | bash
```

---

## 🛠 Development

This project uses `shellcheck` to enforce bash best practices.

```bash
# Run tests
shellcheck install.sh bin/oml lib/*.sh
```

- All `.sh` files must use `#!/usr/bin/env bash` and `set -euo pipefail`.
- No `sed -i` (avoid macOS/Linux cross-platform differences; use `awk` + temporary files instead).
- Path configuration should always reference `$OML_HOME`, never hardcode `~/.oml/`.
