[English](README.md) | [中文](README.zh-CN.md)

# oh-my-longfor (oml)

> **OpenCode 的声明式引导与配置管理工具。**
> 只需一条命令，即可安装 bun、opencode、oh-my-opencode、MCP 服务器和 Skills。

[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)]()

`oh-my-longfor`（oml）是一个零依赖的 Shell 工具，用于引导完整的 AI 开发环境。它可以一键安装 OpenCode、oh-my-opencode 插件，并根据声明式的 `manifest.yaml` 动态配置 Model Context Protocol (MCP) 服务器和可复用的 Agent Skills。

---

## 🚀 特性

- **零依赖引导**：纯 `bash` 编写，仅需 `curl` 和 `git` 即可运行。
- **工具链管理**：自动检测并安装缺失的 `bun`、`opencode`（官方二进制）和 `oh-my-opencode` 插件。支持 **macOS**（Intel & Apple Silicon）和 **Linux**（x86\_64 & arm64）。不支持 Windows。
- **声明式配置**：在简洁的 `manifest.yaml` 中定义 MCP 服务器、Skill 仓库和所需的 API Key。
- **纯净模式或团队模式**：既可作为快速安装工具独立使用，也可指向远程 Git 仓库以在多台机器或开发团队间同步配置。
- **本地覆盖**：无需修改共享配置，即可添加个人的 MCP 服务器或 Skills。
- **安全操作**：每次更新前自动备份，支持轻松回滚。
- **幂等 Shell 配置**：自动将 `OPENCODE_CONFIG` 和 `$PATH` 注入 `.zshrc` / `.bashrc`，不会产生重复条目。

---

## 📦 安装与快速开始

`oh-my-longfor` 支持两种安装模式：

### 模式一：纯净安装（独立使用）

如果你只是想快速安装 `opencode` 工具链并搭建一个干净的本地配置框架，不需要拉取任何远程配置：

```bash
OML_SELF_REPO=https://github.com/todrfu/oh-my-longfor \
  curl -fsSL https://raw.githubusercontent.com/todrfu/oh-my-longfor/main/install.sh | bash
```
*（注：执行安装时必须通过 `OML_SELF_REPO` 指定仓库地址。请将 URL 路径替换为你实际 fork 的仓库地址）*

### 模式二：配置同步（Dotfiles / 团队安装）

如果你有包含 `manifest.yaml` 文件的远程 Git 仓库（例如团队配置或个人 dotfiles），将仓库 URL 作为参数传入：

```bash
OML_SELF_REPO=https://github.com/todrfu/oh-my-longfor \
  curl -fsSL https://raw.githubusercontent.com/todrfu/oh-my-longfor/main/install.sh \
  | bash -s -- https://gitlab.com/your-org/team-config

# or local config
OML_SELF_REPO=https://github.com/todrfu/oh-my-longfor \
  curl -fsSL https://raw.githubusercontent.com/todrfu/oh-my-longfor/main/install.sh \
  | bash -s -- ./your_path/manifest.yaml
```


### 模式三：本地开发 / 直接克隆

如果你已经克隆了 `oh-my-longfor` 仓库（例如用于开发或测试），可以直接从本地副本运行 `install.sh`：

```bash
# 克隆仓库
git clone https://github.com/todrfu/oh-my-longfor.git
cd oh-my-longfor

#  vanilla 模式运行（无团队配置）
./install.sh

# 或指定团队配置仓库
./install.sh https://gitlab.com/your-org/team-config

# 或指定本地 manifest 文件
./install.sh ./my-local-config/manifest.yaml
```

安装器会自动检测当前是本地目录运行，并使用当前目录下的 `lib/` 和 `bin/oml`。

### 安装后步骤

安装完成后，脚本会**自动重新加载你的 Shell**（通过 `exec "$SHELL" -l`），所以新配置会立即生效。

接下来，你可能还需要进行以下操作：

1. **添加必须的 API Key：**
   `oh-my-longfor` 设置了一个集中的环境变量文件。如果你团队的 `manifest.yaml` 需要用到某些 API Key，请编辑该文件并填入对应的值：
   ```bash
   vim ~/.oml/env/.env.oml
   ```
   *(如果不确定需要哪些 Key，可以运行 `oml env` 查看)。*

2. **配置你的 AI 订阅（Claude / Gemini / Copilot 等）：**
   为 OpenCode 设置你偏好的大语言模型提供商：
   ```bash
   bunx oh-my-opencode install
   ```

3. **验证安装：**
   ```bash
   oml doctor
   oml status
   ```

---

## 🛠 配置（manifest.yaml）

使用模式二（或在模式一中手动创建 manifest）时，`oh-my-longfor` 依赖声明式的 `manifest.yaml`。

完整示例如下：

```yaml
version: "1"

# ─── MCP 服务器 ────────────────────────────────────────────
# 支持两种传输方式：
#   remote — SSE/HTTP 服务（远程托管，无需本地安装）
#   local  — stdio 服务（本地进程，通过 npx/uv 等启动）
mcps:
  # 远程 MCP：SSE 传输，通过 HTTP Header 认证
  - name: context7
    type: remote
    url: "https://mcp.context7.com/sse"
    headers:
      Authorization: "Bearer {env:CONTEXT7_API_KEY}"  # 运行时自动解析

  # 本地 MCP：stdio 传输，通过 npx 启动（Node.js）
  # command 为数组，第一个元素是可执行文件，其余为参数
  - name: sequential-thinking
    type: local
    command: ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"]

  # 本地 MCP：stdio 传输，通过 uv 启动（Python）
  # - name: my-python-mcp
  #   type: local
  #   command: ["uv", "run", "my-mcp-server"]
  #   environment:                     # 传递给进程的环境变量（可选）
  #     MY_API_KEY: "{env:MY_API_KEY}"

# ─── Agent Skills ───────────────────────────────────────────
# 仓库会被克隆到 ~/.oml/repos/，并创建软链接以便发现
skills:
  repos:
    - repo: "https://gitlab.com/your-org/shared-skills"
      branch: main          # 默认：main
      subdir: "skills/"     # 默认：skills/
      auth: null            # 选项：null（公开）、token（使用 GITHUB_TOKEN）、ssh

# ─── 环境变量 ────────────────────────────────────
# 定义必需/可选的 API Key。生成 ~/.oml/env/.env.template 文件。
env:
  - name: CONTEXT7_API_KEY
    description: "从 https://context7.com/settings 获取密鑰"
    required: true

# ─── oh-my-opencode 覆盖配置（可选） ─────────────────────────
omo_overrides:
  agents:
    oracle:
      model: "gpt-4o"
  disabled_mcps: []
  disabled_skills: []
```

---

## 💻 CLI 参考

安装后，`oml` CLI 工具负责管理本地环境。

### 同步与更新

```bash
# 从团队/远程配置拉取最新配置并重新生成 JSON 文件
oml update
```

### 诊断与状态

```bash
# 显示仓库、配置和环境变量的当前状态
oml status

# 运行诊断检查并提供修复建议
oml doctor

# 查看已设置或缺失的必需 API Key
oml env
```

### 本地覆盖

你可以添加个人的 MCP 或 Skill 仓库，运行 `oml update` 时不会被覆盖。

```bash
# 查看当前的个人覆盖配置
oml override list

# 添加个人 MCP 服务器
oml override add-mcp my-local-mcp '{"type":"remote","url":"http://localhost:3000/sse"}'

# 添加个人 Skill 仓库
oml override add-skill-repo https://github.com/you/my-skills main

# 移除覆盖配置
oml override remove mcp my-local-mcp
```

*注：你也可以直接编辑 `~/.oml/overrides/` 目录下的 YAML 文件。*

### 备份与回滚

每次执行 `oml update` 或配置重新生成前，`oh-my-longfor` 会创建备份（最多保留 5 个）。

```bash
# 列出可用备份
oml backup list

# 恢复最近一次备份
oml rollback

# 恢复指定时间点的备份
oml rollback 2026-02-25-143022
```

---

## 📁 架构与目录结构

`oh-my-longfor` 完全安装到 `~/.oml/` 目录，保持你的主目录整洁。

```
~/.oml/
├── bin/
│   └── oml                         ← CLI 可执行文件（已加入 $PATH）
├── lib/                            ← Bash 库函数
├── repos/
│   ├── team-config/                ← 克隆的配置仓库（模式二）
│   └── team-skills/                ← 克隆的 Skill 仓库
├── config/
│   ├── opencode.json               ← 生成的 OpenCode 配置
│   └── oh-my-opencode.jsonc        ← 生成的 OMO 配置
├── env/
│   └── .env.template               ← 生成的 API Key 模板
├── overrides/                      ← 个人覆盖配置
└── backups/                        ← 自动备份（按时间戳）

# 自动创建的 Skill 软链接：
~/.claude/skills/
~/.config/opencode/skills/
```

- OpenCode 通过 `OPENCODE_CONFIG=~/.oml/config/opencode.json` 解析配置（通过 Shell rc 注入）。
- Skills 被软链接到标准位置，以确保 OpenCode 原生加载器和 Claude Code 都能发现它们。

---

## ❓ 常见问题

**Q：如何安全管理 API Key？**
运行 `oml env` 查看所需的 Key。安装器已自动将模板复制为 `~/.oml/env/.env.oml`，并配置了你的 Shell 在启动时自动加载它。你只需编辑该文件即可：
```bash
vim ~/.oml/env/.env.oml
```

**Q：`curl | bash` 失败提示 "Could not clone oml repo"？**
确保在命令前正确设置了 `OML_SELF_REPO` 环境变量，指向安装脚本所在的仓库 URL。

**Q：如何完全卸载？**
你可以直接运行内置的卸载命令，干净地从系统中移除 `oh-my-longfor`、`opencode` 和 `oh-my-opencode`（包括环境变量注入和全局包）：
```bash
oml uninstall
```
*（如果你当前环境无法使用 oml 命令，也可以执行：`curl -fsSL https://raw.githubusercontent.com/todrfu/oh-my-longfor/main/uninstall.sh | bash`）*

---

## 🛠 开发

本项目使用 `shellcheck` 强制执行 bash 最佳实践。

```bash
# 运行测试
shellcheck install.sh bin/oml lib/*.sh
```

- 所有 `.sh` 文件必须使用 `#!/usr/bin/env bash` 和 `set -euo pipefail`。
- 不使用 `sed -i`（避免 macOS/Linux 跨平台差异；使用 `awk` + 临时文件代替）。
- 路径配置应始终引用 `$OML_HOME`，不要硬编码 `~/.oml/`。
