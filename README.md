# oh-my-longfor (oml)

> **团队 AI 开发环境一键引导工具**
> 一条命令，让新成员完成 OpenCode + MCP + Skills 的全套配置。

---

## 目录

- [它解决什么问题](#它解决什么问题)
- [工作原理](#工作原理)
- [角色一：团队管理员（首次搭建）](#角色一团队管理员首次搭建)
- [角色二：团队成员（安装使用）](#角色二团队成员安装使用)
- [manifest.yaml 完整说明](#manifestyaml-完整说明)
- [oml 命令参考](#oml-命令参考)
- [个人覆盖（Override）](#个人覆盖override)
- [更新与同步](#更新与同步)
- [备份与回滚](#备份与回滚)
- [环境变量管理](#环境变量管理)
- [目录结构参考](#目录结构参考)
- [常见问题](#常见问题)
- [开发与贡献](#开发与贡献)

---

## 它解决什么问题

每个新入职的开发者都需要手动配置：OpenCode 安装、MCP 服务器连接、Skills 仓库克隆、API Key 填写……费时费力且容易出错。

**oml 的方案：** 管理员把团队配置放到一个 Git 仓库（`manifest.yaml`），成员只需运行一条命令，所有配置自动完成。

```
管理员维护                         成员执行
──────────────────────────────     ────────────────────────────────────
github.com/your-org/team-config    curl -fsSL .../install.sh | bash -s -- <repo-url>
  └── manifest.yaml                ↓
      • MCPs 列表                   自动安装 opencode + oh-my-opencode
      • Skills 仓库                 自动克隆 Skills 仓库
      • 环境变量定义                 自动生成 opencode.json（含 MCPs）
                                   自动生成 API Key 填写模板
```

---

## 工作原理

```
~/.oml/                              ← oml 工作目录
├── repos/team-config/               ← 团队配置仓库（git clone）
│   └── manifest.yaml
├── repos/<skill-repo>/              ← Skills 仓库（自动克隆）
├── config/
│   ├── opencode.json                ← OpenCode 主配置（MCPs，自动生成）
│   └── oh-my-opencode.jsonc         ← oh-my-opencode 配置（自动生成）
├── env/.env.template                ← API Key 填写模板（自动生成）
├── overrides/                       ← 个人覆盖（不受 oml update 影响）
│   ├── mcps.yaml
│   ├── skills.yaml
│   └── omo.yaml
├── lib/                             ← oml 内部库文件
├── bin/oml                          ← oml CLI 可执行文件
└── backups/                         ← 自动备份（最多保留 5 个）
```

**关键机制：**
- `OPENCODE_CONFIG=~/.oml/config/opencode.json` 自动写入 `~/.zshrc`，OpenCode 读取该配置
- Skills 在 `~/.claude/skills/` 创建软链接，供 oh-my-opencode 发现
- 每次 `oml update` 前自动备份，支持 `oml rollback` 回滚

---

## 角色一：团队管理员（首次搭建）

> **只需执行一次**，之后团队成员即可使用。

### 第 1 步：创建 team-config 仓库

基于本项目的 `example-team-config/` 目录创建你的团队配置仓库：

```bash
# 方式 A：复制 example-team-config 并推送到你的 Git 服务器
cp -r example-team-config/ my-team-config/
cd my-team-config/
# 编辑 manifest.yaml（见第 2 步）
git init && git add . && git commit -m "init: team oml config"
git remote add origin https://github.com/your-org/team-config
git push -u origin main
```

### 第 2 步：编辑 manifest.yaml

打开 `manifest.yaml`，按你的团队实际需求修改：

```yaml
version: "1"

mcps:
  - name: context7
    type: remote
    url: "https://mcp.context7.com/sse"
    headers:
      Authorization: "Bearer {env:CONTEXT7_API_KEY}"   # 不要写真实 key！

skills:
  repos:
    - repo: "https://github.com/your-org/team-skills"
      branch: main
      auth: null   # 公开仓库填 null，私有仓库填 token 或 ssh

env:
  - name: CONTEXT7_API_KEY
    description: "从 https://context7.com/settings 获取（免费）"
    required: true
```

> 完整的 `manifest.yaml` 字段说明见 [manifest.yaml 完整说明](#manifestyaml-完整说明)。

### 第 3 步：Fork 并部署 oh-my-longfor（可选）

如果你的团队在内网环境，需要 Fork 本仓库并部署到内网：

```bash
# Fork 后，在分发命令前设置 OML_SELF_REPO
OML_SELF_REPO=https://内网地址/oh-my-longfor \
  curl -fsSL https://内网地址/install.sh | bash -s -- <team-config-url>
```

> **为什么需要 `OML_SELF_REPO`？**
> 通过 `curl | bash` 运行时，脚本无法访问自身的 `lib/` 目录，因此会自动 clone `OML_SELF_REPO` 来获取库文件。默认值为 `https://github.com/your-org/oh-my-longfor`，请替换为你的实际地址。

### 第 4 步：分发安装命令

把以下命令发给所有团队成员：

```bash
curl -fsSL https://raw.githubusercontent.com/your-org/oh-my-longfor/main/install.sh \
  | bash -s -- https://github.com/your-org/team-config
```

---

## 角色二：团队成员（安装使用）

### 安装

#### 方式 1：curl 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/your-org/oh-my-longfor/main/install.sh \
  | bash -s -- https://github.com/your-org/team-config
```

安装过程自动完成：
- ✅ 安装 bun（如未安装）
- ✅ 安装 opencode（官方二进制安装器）
- ✅ 安装 oh-my-opencode 插件
- ✅ 克隆 Skills 仓库
- ✅ 生成 `opencode.json`（含所有 MCPs）
- ✅ 生成 API Key 填写模板
- ✅ 配置 `$PATH` 和 `OPENCODE_CONFIG`

#### 方式 2：本地目录

```bash
git clone https://github.com/your-org/team-config
bash path/to/oh-my-longfor/install.sh ./team-config
```

#### 方式 3：只有 manifest.yaml 文件

```bash
bash path/to/oh-my-longfor/install.sh ./manifest.yaml
# 或绝对路径
bash path/to/oh-my-longfor/install.sh /path/to/manifest.yaml
```

### 安装完成后的必做步骤

```bash
# 1. 重新加载 shell，让 PATH 和 OPENCODE_CONFIG 生效
source ~/.zshrc   # 或 source ~/.bashrc

# 2. 查看需要填写哪些 API Key（安装结束时也会显示）
oml env

# 3. 填写 API Key
cp ~/.oml/env/.env.template ~/.env.oml
$EDITOR ~/.env.oml    # 填入各 MCP 需要的 API Key

# 4. 让环境变量自动加载（只需设置一次）
echo '[ -f ~/.env.oml ] && source ~/.env.oml' >> ~/.zshrc
source ~/.zshrc

# 5. 配置 oh-my-opencode 的 AI 订阅（Claude / Gemini / Copilot）
bunx oh-my-opencode install
# 交互式选择你有哪些 AI 订阅

# 6. 验证所有配置正确
oml doctor
```

### 开始使用

```bash
# 启动 OpenCode
opencode

# 查看当前状态
oml status
```

---

## manifest.yaml 完整说明

```yaml
# ─── 版本号（固定填 "1"）────────────────────────────────────────────────────
version: "1"


# ─── MCPs（Model Context Protocol 服务器）────────────────────────────────────
# 配置团队共用的 Remote/SSE MCPs。
# 这里的配置会写入每个成员的 ~/.oml/config/opencode.json。
mcps:
  - name: context7              # MCP 唯一名称（小写字母、数字、连字符）
    type: remote                # 目前固定填 remote
    url: "https://mcp.context7.com/sse"   # SSE 端点地址
    headers:
      Authorization: "Bearer {env:CONTEXT7_API_KEY}"
      # ↑ 使用 {env:VAR_NAME} 引用环境变量，OpenCode 运行时自动替换
      # ！永远不要在这里写真实的 API Key！

  - name: github
    type: remote
    url: "https://api.githubcopilot.com/mcp/sse"
    headers:
      Authorization: "Bearer {env:GITHUB_TOKEN}"
      X-GitHub-Api-Version: "2022-11-28"

  - name: sentry
    type: remote
    url: "https://mcp.sentry.io/sse"
    headers:
      Authorization: "Bearer {env:SENTRY_TOKEN}"


# ─── Skills（技能仓库）────────────────────────────────────────────────────────
# 配置存放 OpenCode Skills 的 Git 仓库。
# 安装时会自动 clone 到 ~/.oml/repos/，并在 ~/.claude/skills/ 创建软链接。
skills:
  repos:
    - repo: "https://github.com/your-org/team-skills"   # 仓库地址
      branch: main          # 分支（默认 main）
      subdir: "skills/"     # 技能文件所在的子目录（默认 skills/）
      auth: null            # 认证方式：
                            #   null  = 公开仓库，无需认证
                            #   token = 使用 GITHUB_TOKEN 环境变量
                            #   ssh   = 使用 SSH Key（需配置 ~/.ssh/）

    - repo: "https://github.com/your-org/private-skills"
      branch: main
      subdir: "skills/"
      auth: token           # 私有仓库，使用 GITHUB_TOKEN


# ─── 环境变量定义 ─────────────────────────────────────────────────────────────
# 告知成员需要配置哪些 API Key。
# 安装时自动生成 ~/.oml/env/.env.template 模板文件，
# 成员复制后填入自己的值。
env:
  - name: CONTEXT7_API_KEY
    description: "Context7 API key。从 https://context7.com/settings 获取（免费）"
    required: true            # true = 必填（缺少时 oml doctor 会报警告）

  - name: GITHUB_TOKEN
    description: "GitHub Personal Access Token。在 https://github.com/settings/tokens 创建，需要 repo 权限"
    required: true

  - name: SENTRY_TOKEN
    description: "Sentry Auth Token。在 https://sentry.io/settings/account/api/auth-tokens/ 创建"
    required: true

  - name: OPENAI_API_KEY
    description: "OpenAI API Key，用于 oracle agent 调用 GPT-4。从 https://platform.openai.com/api-keys 获取"
    required: false           # false = 可选（没有也不影响基本功能）

  - name: ANTHROPIC_API_KEY
    description: "Anthropic API Key，用于 Claude 模型调用。从 https://console.anthropic.com/settings/keys 获取"
    required: false


# ─── oh-my-opencode 覆盖配置（可选）─────────────────────────────────────────
# 团队级别的 oh-my-opencode 配置。
# 成员可以通过 ~/.oml/overrides/omo.yaml 进行个人覆盖。
omo_overrides:
  agents:
    # 覆盖某个 agent 默认使用的模型
    oracle:
      model: "gpt-4o"
  models: {}
  disabled_mcps: []      # 在 oh-my-opencode 层面禁用某些 MCP（填 MCP name）
  disabled_skills: []    # 在 oh-my-opencode 层面禁用某些 Skill（填 skill 名）
```

### Skills 仓库结构

每个 Skills 仓库的目录结构如下：

```
your-skills-repo/
└── skills/                  ← manifest.yaml 中 subdir 指定的目录
    ├── code-review/
    │   └── SKILL.md         ← OpenCode 识别的 skill 文件
    ├── vue-best-practices/
    │   └── SKILL.md
    └── api-design/
        └── SKILL.md
```

---

## oml 命令参考

### 安装与更新

```bash
# 首次安装（3 种输入方式）
oml install https://github.com/your-org/team-config    # 远程 Git 仓库
oml install ./team-config                              # 本地目录
oml install ./manifest.yaml                            # 本地 manifest 文件

# 拉取最新团队配置并重新生成所有配置
oml update
```

### 状态与诊断

```bash
# 查看当前状态：team config 状态、skill 仓库、config 文件、env vars
oml status

# 诊断模式：检查依赖、文件完整性、env vars，并给出修复建议
oml doctor

# 仅查看 API Key 设置情况（哪些已设置 / 哪些缺失）
oml env
```

### 个人覆盖

```bash
oml override list                                      # 查看当前个人覆盖
oml override add-mcp <name> '<json>'                   # 添加个人 MCP
oml override add-skill-repo <git-url> [branch]         # 添加个人 Skill 仓库
oml override remove mcp <name>                         # 删除 MCP 覆盖
oml override remove skill <url>                        # 删除 Skill 仓库覆盖
```

### 备份与回滚

```bash
oml backup list                    # 列出所有备份
oml rollback                       # 恢复最近一次备份
oml rollback 2026-02-25-143022     # 恢复指定时间点的备份
```

### 其他

```bash
oml version                        # 查看版本号
oml help                           # 查看帮助
```

---

## 个人覆盖（Override）

个人覆盖存储在 `~/.oml/overrides/`，**`oml update` 不会覆盖这些文件**，适合添加个人私有工具。

### 添加个人 MCP

```bash
# 添加一个本地 MCP
oml override add-mcp my-local-mcp '{"type":"remote","url":"http://localhost:3000/sse"}'

# 添加带认证的 MCP
oml override add-mcp my-private-mcp '{
  "type": "remote",
  "url": "https://my-private-mcp.example.com/sse",
  "headers": {"Authorization": "Bearer {env:MY_MCP_TOKEN}"}
}'

# 查看已添加的覆盖
oml override list

# 应用覆盖（重新生成配置）
oml update
```

**MCP 覆盖规则：** 如果个人 MCP 名称与团队配置中的名称相同，**个人配置完全替换团队配置**（适合覆盖端点 URL 或认证方式）。

### 添加个人 Skill 仓库

```bash
# 添加你自己的 skill 仓库
oml override add-skill-repo https://github.com/you/my-skills

# 指定分支
oml override add-skill-repo https://github.com/you/my-skills dev

# 删除
oml override remove skill https://github.com/you/my-skills
```

**Skill 仓库覆盖规则：** 个人仓库**追加**到团队仓库列表（不替换）。

### 直接编辑覆盖文件

覆盖文件都是标准 YAML，可以直接编辑：

```bash
$EDITOR ~/.oml/overrides/mcps.yaml      # 个人 MCP 覆盖
$EDITOR ~/.oml/overrides/skills.yaml    # 个人 Skill 仓库覆盖
$EDITOR ~/.oml/overrides/omo.yaml       # 个人 oh-my-opencode 覆盖
```

编辑后运行 `oml update` 使配置生效。

---

## 更新与同步

当管理员更新了 `manifest.yaml`（新增 MCP、更新 Skill 仓库等），团队成员运行：

```bash
oml update
```

这会自动完成：

1. `git pull` 拉取最新 `manifest.yaml`
2. 克隆/更新 Skill 仓库
3. 备份当前配置文件
4. 重新生成 `opencode.json` 和 `oh-my-opencode.jsonc`
5. 更新 `.env.template`（新增的 API Key 会出现在模板里）

> **你的个人设置不受影响：**
> - `~/.oml/overrides/` — 个人覆盖配置
> - `~/.env.oml` — 你填写的 API Key
> - oh-my-opencode 的订阅配置

---

## 备份与回滚

每次 `oml update` 执行前，oml 自动备份当前的配置文件（最多保留 5 个备份）。

```bash
# 查看备份列表
oml backup list
#   2026-02-26-094512  (24K)
#   2026-02-25-143022  (24K)

# 恢复最近一次备份
oml rollback

# 恢复指定时间点
oml rollback 2026-02-25-143022
```

备份内容包括：
- `~/.oml/config/opencode.json`
- `~/.oml/config/oh-my-opencode.jsonc`
- `~/.oml/env/.env.template`

---

## 环境变量管理

```bash
# 查看哪些 API Key 已设置、哪些缺失
oml env
# 输出示例：
#   ✅ set    GITHUB_TOKEN (required)
#   ❌ missing CONTEXT7_API_KEY (required)
#   ❌ missing OPENAI_API_KEY (optional)
```

**推荐的 API Key 管理方式：**

```bash
# 1. 生成填写模板（含所有需要的 key 和获取方式说明）
cp ~/.oml/env/.env.template ~/.env.oml

# 2. 填写你的 key
$EDITOR ~/.env.oml

# 3. 自动加载到 shell（只需设置一次）
echo '[ -f ~/.env.oml ] && source ~/.env.oml' >> ~/.zshrc
source ~/.zshrc

# 4. 验证
oml env
```

---

## 目录结构参考

```
~/.oml/
├── bin/
│   └── oml                         ← oml CLI 可执行文件
├── lib/                            ← oml 内部库文件（自动安装）
│   ├── common.sh
│   ├── manifest.sh
│   ├── git.sh
│   ├── skills.sh
│   ├── config.sh
│   ├── env.sh
│   ├── override.sh
│   └── backup.sh
├── repos/
│   ├── team-config/                ← 团队配置仓库（git clone）
│   │   └── manifest.yaml
│   ├── team-skills/                ← 克隆的 Skill 仓库
│   └── .bootstrap/                 ← curl|bash 模式的临时仓库（可删除）
├── config/
│   ├── opencode.json               ← OpenCode 主配置（含 MCPs，自动生成）
│   └── oh-my-opencode.jsonc        ← oh-my-opencode 配置（自动生成）
├── env/
│   └── .env.template               ← API Key 填写模板（自动生成）
├── overrides/
│   ├── mcps.yaml                   ← 个人 MCP 覆盖
│   ├── skills.yaml                 ← 个人 Skill 仓库覆盖
│   └── omo.yaml                    ← 个人 oh-my-opencode 覆盖
└── backups/                        ← 自动备份（最多保留 5 个）
    ├── 2026-02-26-094512/
    └── 2026-02-25-143022/

~/.claude/
└── skills/                         ← oml 管理的 Skill 软链接目录
    ├── code-review -> ~/.oml/repos/team-skills/skills/code-review/
    └── ...
```

---

## 常见问题

### Q：安装完成后运行 `oml` 报错 "lib/ not found"？

重新运行安装命令即可（会自动覆盖安装）：

```bash
bash install.sh <your-team-config-url>
```

### Q：`curl | bash` 模式下提示 "Could not clone oml repo"？

需要设置 `OML_SELF_REPO` 为你的 oml 仓库地址：

```bash
OML_SELF_REPO=https://github.com/your-org/oh-my-longfor \
  curl -fsSL https://your-host/install.sh | bash -s -- <team-config-url>
```

### Q：安装 oh-my-opencode 时出错？

`bunx oh-my-opencode install` 需要访问 npm。安装完成后可以随时重新运行配置订阅：

```bash
bunx oh-my-opencode install
# 选择你有的 AI 订阅（Claude / Gemini / Copilot）
```

### Q：私有 Skill 仓库 clone 失败？

在 `manifest.yaml` 中设置 `auth: token`，并确保 `GITHUB_TOKEN` 已设置：

```yaml
skills:
  repos:
    - repo: "https://github.com/your-org/private-skills"
      auth: token   # 使用 GITHUB_TOKEN 环境变量
```

确认 Token 已设置：

```bash
echo $GITHUB_TOKEN   # 应该有输出
oml env              # 查看所有 env vars 状态
```

### Q：`opencode` 没有读取到我的 MCP 配置？

确认 `OPENCODE_CONFIG` 环境变量已生效：

```bash
echo $OPENCODE_CONFIG   # 应该输出 ~/.oml/config/opencode.json
cat ~/.oml/config/opencode.json   # 查看生成的配置内容
```

如果变量未设置，重新加载 shell：

```bash
source ~/.zshrc   # 或 source ~/.bashrc
```

### Q：如何添加自己的私人 MCP，同时不影响团队配置？

使用个人覆盖：

```bash
oml override add-mcp my-tool '{"type":"remote","url":"http://localhost:4000/sse"}'
oml update   # 重新生成配置
```

### Q：如何完全卸载？

```bash
# 1. 删除 oml 工作目录
rm -rf ~/.oml

# 2. 删除 skill 软链接
rm -rf ~/.claude/skills

# 3. 从 shell rc 文件中删除 oml 相关行
# 找到并删除包含 "# oml:" 注释的行（PATH 和 OPENCODE_CONFIG 配置）
grep -n "oml:" ~/.zshrc   # 查看哪些行需要删除
```

### Q：在 CI/CD 中使用？

非交互式环境下，oml 自动安装所有依赖（不弹出询问）：

```bash
OML_SELF_REPO=https://github.com/your-org/oh-my-longfor \
  curl -fsSL https://your-host/install.sh \
  | bash -s -- https://github.com/your-org/team-config
```

---

## 开发与贡献

本项目使用纯 Bash 编写，兼容 macOS 和 Linux。

### 本地开发

```bash
# 克隆仓库
git clone https://github.com/your-org/oh-my-longfor
cd oh-my-longfor

# 本地测试安装（使用 example-team-config 作为测试配置）
bash install.sh ./example-team-config

# 代码风格检查
shellcheck install.sh bin/oml lib/*.sh

# 测试 CLI（安装后）
~/.oml/bin/oml help
~/.oml/bin/oml doctor
~/.oml/bin/oml status
```

### 编码约定

- 所有 `.sh` 文件以 `#!/usr/bin/env bash` + `set -euo pipefail` 开头
- 不使用 `sed -i`（macOS 和 Linux 行为不一致），改用 `awk + tmpfile`
- 路径全部使用 `$OML_HOME` 变量，不硬编码
- 用户可见的错误信息通过 `oml_error()` 输出到 stderr
- 所有写入 shell rc 文件的操作必须幂等（重复运行不产生重复配置）

### 项目结构

```
oh-my-longfor/
├── install.sh                   ← 一键安装脚本（入口）
├── bin/
│   └── oml                      ← CLI 主程序
├── lib/
│   ├── common.sh                ← 日志、锁、平台检测
│   ├── manifest.sh              ← manifest.yaml 解析
│   ├── git.sh                   ← Git 操作封装
│   ├── skills.sh                ← Skill 仓库管理
│   ├── config.sh                ← opencode.json 生成
│   ├── env.sh                   ← .env.template 生成
│   ├── override.sh              ← 个人覆盖管理
│   └── backup.sh                ← 备份与回滚
├── manifest.schema.yaml         ← manifest.yaml JSON Schema
└── example-team-config/         ← 模板仓库（管理员 Fork 这个）
    ├── manifest.yaml
    └── README.md
```
