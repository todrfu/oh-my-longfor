# oh-my-longfor: Team AI Dev Environment Bootstrap Tool

## TL;DR

> **Quick Summary**: Build a shell-based team bootstrap tool ("oml") that composes oh-my-opencode + OpenCode native config + git repos to enable one-command onboarding of MCPs, skills, and commands for new developers.
> 
> **Deliverables**:
> - `install.sh` — Bootstrap script (curl | bash) that installs everything
> - `oml` — CLI wrapper for update, status, doctor, and override management
> - Team config repo structure definition (manifest format in YAML)
> - `.env.template` generator for API keys
> - Generated `opencode.json` with team MCPs + `skills.paths`
> - Personal override mechanism (user-local additions)
> 
> **Estimated Effort**: Medium (3-5 days implementation)
> **Parallel Execution**: YES — 4 waves
> **Critical Path**: Task 1 (manifest schema) → Task 3 (install.sh) → Task 6 (oml CLI) → Task 8 (integration test)

---

## Context

### Original Request
The team has curated 25-50 MCPs, skills, and commands for their AI dev workflow using OpenCode + oh-my-opencode, spread across multiple git repos. New hires must manually consult multiple docs to set up their environment. The user wants an "oh-my-zsh"-style one-click installer to solve onboarding, config assembly, secret templating, and update management.

### Interview Summary
**Key Discussions**:
- **Tool**: OpenCode (sst/opencode) with oh-my-opencode already in use
- **MCP types**: All Remote/SSE (no local server builds needed → config-only)
- **Distribution**: Shell script installer (curl | bash pattern)
- **Customization**: Flexible — shared base + personal overrides
- **Secrets**: Local .env files, tool generates template
- **Config source**: Single team-config git repo with manifest
- **Skills**: External repos, each containing multiple skills
- **Updates**: Manual `oml update` command
- **Platforms**: macOS + Linux
- **Scope**: OpenCode only, internal first

**Research Findings**:
- oh-my-opencode (34K★) exists but lacks team config management
- ruler (2.5K★) distributes configs to 30+ tools but no version pinning
- Smithery.ai is MCP marketplace but no team-level management
- OpenCode has native `.well-known/opencode` for org defaults
- **Critical**: OpenCode schema includes undocumented `skills.paths` and `skills.urls` — allows pointing config at cloned repo directories directly (no symlinking!)

### Metis Review
**Identified Gaps** (addressed):
- **`skills.paths` must be validated first** — it's in the schema but undocumented. Task 1 includes validation.
- **Git auth for private repos** — manifes supports `auth` field for private skill repos
- **Concurrency lock** — prevent simultaneous installs/updates via lockfile
- **Conflict resolution** — when team base and personal overrides collide on same key
- **Rollback** — if update breaks config, user can roll back
- **`oml doctor`** — diagnostic command to verify all dependencies and configs are correct

---

## Work Objectives

### Core Objective
Create a shell-based team bootstrap and sync tool that reads a YAML manifest from a team-config git repo, clones skill repositories, generates OpenCode + oh-my-opencode configurations, templates .env files, and provides update/status/doctor commands — all composing existing tools rather than replacing them.

### Concrete Deliverables
- `install.sh` — One-line bootstrap: `curl -fsSL https://internal.company.com/oml/install.sh | bash`
- `oml` — Shell CLI with subcommands: `install`, `update`, `status`, `doctor`, `override`, `env`
- `manifest.yaml` schema — Defines team MCPs, skill repos, required env vars, oh-my-opencode overrides
- `~/.oml/` directory structure — repos, config, backups, overrides
- Generated `opencode.json` — MCPs + `skills.paths` pointing to cloned repos
- Generated `oh-my-opencode.jsonc` — Team agent/model/skill config
- `.env.template` — Lists all required API keys with descriptions

### Definition of Done
- [ ] `curl -fsSL <url>/install.sh | bash` on a clean macOS/Linux machine results in a fully configured OpenCode environment
- [ ] `oml update` pulls latest from all repos and regenerates configs without losing personal overrides
- [ ] `oml doctor` detects and reports missing dependencies, unconfigured API keys, stale repos
- [ ] Personal overrides survive team config updates
- [ ] Rollback works: `oml rollback` restores previous config

### Must Have
- Shell-only implementation (bash/zsh, no compiled binary, no Node.js runtime dependency for oml itself)
- macOS + Linux support (POSIX-compatible where possible)
- Team manifest defines all MCPs, skill repos, env vars in one YAML file
- Config generation uses OpenCode's native `skills.paths` if validated (fallback to symlinks)
- Personal override layer that merges on top of team base
- `.env.template` generation with descriptions of each required key
- Idempotent install (running install.sh twice doesn't break anything)
- Concurrency lock to prevent simultaneous installs/updates
- Backup before every config regeneration

### Must NOT Have (Guardrails)
- **No compiled binary** — pure shell script, no Go/Rust/Node runtime for the tool itself
- **No secret injection** — tool creates .env template, user fills in values manually
- **No MCP hosting** — tool configures existing Remote/SSE MCPs, doesn't run servers
- **No agent orchestration** — oh-my-opencode handles this, oml doesn't touch agent logic
- **No cross-tool support** — OpenCode only, no Cursor/Claude Code/Windsurf
- **No GUI/web portal** — CLI only
- **No auto-update on launch** — manual `oml update` only
- **No npm/pip package management** — if an MCP needs local deps, that's out of scope
- **No over-engineering** — this is a thin shell wrapper, not a platform

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (new project, shell script)
- **Automated tests**: None (shell script project — QA scenarios are primary verification)
- **Framework**: N/A
- **Primary verification**: Agent-executed QA scenarios using Bash and interactive_bash

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Shell scripts**: Use Bash — run commands, check exit codes, verify file existence
- **Config generation**: Use Bash — run oml commands, read generated files, assert content
- **Cross-platform**: Use Bash — test on macOS natively (Linux via Docker if available)

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — can all start immediately):
├── Task 1: Manifest schema design + skills.paths validation [quick]
├── Task 2: Example team-config repo scaffold [quick]
├── Task 3: Directory structure + core shell utilities [quick]

Wave 2 (Core features — after Wave 1):
├── Task 4: install.sh bootstrap script (depends: 1, 3) [unspecified-high]
├── Task 5: Config generator — opencode.json + oh-my-opencode.jsonc (depends: 1, 3) [deep]
├── Task 6: Skill repo cloner + syncer (depends: 1, 3) [unspecified-high]
├── Task 7: .env template generator (depends: 1, 3) [quick]

Wave 3 (CLI + overrides — after Wave 2):
├── Task 8: oml CLI wrapper — update, status, doctor (depends: 4, 5, 6, 7) [deep]
├── Task 9: Personal override mechanism (depends: 5) [unspecified-high]
├── Task 10: Backup + rollback system (depends: 5) [quick]

Wave 4 (Verification):
├── Task 11: End-to-end integration test (depends: 8, 9, 10) [deep]

Wave FINAL (Independent review, parallel):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real QA — full install on clean environment (unspecified-high)
├── Task F4: Scope fidelity check (deep)

Critical Path: Task 1 → Task 5 → Task 8 → Task 11 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 4 (Wave 2)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 4, 5, 6, 7 | 1 |
| 2 | — | 4 | 1 |
| 3 | — | 4, 5, 6, 7 | 1 |
| 4 | 1, 2, 3 | 8 | 2 |
| 5 | 1, 3 | 8, 9 | 2 |
| 6 | 1, 3 | 8 | 2 |
| 7 | 1, 3 | 8 | 2 |
| 8 | 4, 5, 6, 7 | 11 | 3 |
| 9 | 5 | 11 | 3 |
| 10 | 5 | 11 | 3 |
| 11 | 8, 9, 10 | F1-F4 | 4 |
| F1-F4 | 11 | — | FINAL |

### Agent Dispatch Summary

- **Wave 1 (3)**: T1 → `quick`, T2 → `quick`, T3 → `quick`
- **Wave 2 (4)**: T4 → `unspecified-high`, T5 → `deep`, T6 → `unspecified-high`, T7 → `quick`
- **Wave 3 (3)**: T8 → `deep`, T9 → `unspecified-high`, T10 → `quick`
- **Wave 4 (1)**: T11 → `deep`
- **FINAL (4)**: F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

> Task details follow. Each task includes: What to do, Must NOT do, Agent Profile, Parallelization, References, Acceptance Criteria, and QA Scenarios.

- [ ] 1. Manifest Schema Design + `skills.paths` Validation

  **What to do**:
  - Design the YAML manifest schema (`manifest.yaml`) that teams use to define their environment
  - Schema must support: MCPs (name, type, url, headers, env vars), skill repos (git URL, branch, subdir), required env vars (name, description, required/optional), oh-my-opencode overrides (agents, models, disabled MCPs/skills)
  - Create a JSON Schema file (`manifest.schema.yaml`) for validation
  - **CRITICAL**: Validate that OpenCode's `skills.paths` config actually works:
    1. Create a temporary directory `/tmp/oml-test-skills/my-test-skill/`
    2. Place a valid `SKILL.md` file in it (with frontmatter: name, description)
    3. Create a test `opencode.json` with `"skills": { "paths": ["/tmp/oml-test-skills"] }`
    4. Start OpenCode with this config, verify the skill appears in the skill list
    5. If `skills.paths` works → document as primary strategy
    6. If `skills.paths` does NOT work → document symlink fallback strategy
  - Also validate `skills.urls` if time permits (could enable remote skill loading without git clone)

  **Must NOT do**:
  - Don't over-engineer the schema — keep it minimal, extend later
  - Don't add fields for Cursor/Claude Code/other tools
  - Don't implement manifest parsing yet (that's Task 5)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Schema design is a focused file-creation task, validation is a simple test
  - **Skills**: []
    - No special skills needed — this is YAML/JSON schema work + manual OpenCode testing

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5, 6, 7 (all need to know the manifest format)
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - OpenCode config schema: `https://opencode.ai/config.json` — the live schema containing `skills.paths` and `skills.urls` definitions
  - oh-my-opencode config: `~/.config/opencode/oh-my-opencode.jsonc` — the existing config format to understand what fields to expose in manifest

  **External References**:
  - OpenCode docs: `https://opencode.ai/docs/config/` — config precedence and format
  - YAML Schema: Use standard YAML 1.2 with JSON Schema validation
  - oh-my-zsh `.zshrc` pattern — inspiration for manifest structure (simple, declarative)

  **Acceptance Criteria**:
  - [ ] `manifest.schema.yaml` file created with JSON Schema validation rules
  - [ ] Example `manifest.yaml` file created showing all supported fields
  - [ ] `skills.paths` validation result documented (WORKS / DOES NOT WORK + evidence)
  - [ ] If `skills.paths` works: screenshot or terminal output showing skill discovered from custom path
  - [ ] If `skills.paths` doesn't work: symlink fallback strategy documented

  **QA Scenarios:**

  ```
  Scenario: Manifest schema is valid and parseable
    Tool: Bash
    Preconditions: manifest.schema.yaml and example manifest.yaml exist
    Steps:
      1. Run: python3 -c "import yaml; yaml.safe_load(open('example-team-config/manifest.yaml'))" 
      2. Verify exit code is 0
      3. Run: python3 -c "import yaml; data=yaml.safe_load(open('example-team-config/manifest.yaml')); assert 'mcps' in data; assert 'skills' in data; assert 'env' in data; print('Schema valid')"
    Expected Result: Both commands exit 0, 'Schema valid' printed
    Failure Indicators: Python raises yaml.YAMLError or KeyError
    Evidence: .sisyphus/evidence/task-1-manifest-schema.txt

  Scenario: skills.paths validation on OpenCode
    Tool: Bash
    Preconditions: OpenCode installed, test skill directory created
    Steps:
      1. Run: mkdir -p /tmp/oml-test-skills/test-skill && echo '---\nname: test-skill\ndescription: Validation test\n---\n## Test skill' > /tmp/oml-test-skills/test-skill/SKILL.md
      2. Run: echo '{"$schema":"https://opencode.ai/config.json","skills":{"paths":["/tmp/oml-test-skills"]}}' > /tmp/oml-test-opencode.json
      3. Run: OPENCODE_CONFIG=/tmp/oml-test-opencode.json opencode --help (or equivalent to list available skills)
      4. Check if 'test-skill' appears in skill output
    Expected Result: test-skill is discovered by OpenCode from the custom path
    Failure Indicators: test-skill not in skill list, or OpenCode ignores skills.paths entirely
    Evidence: .sisyphus/evidence/task-1-skills-paths-validation.txt
  ```

  **Commit**: YES (group with Tasks 2, 3)
  - Message: `feat(oml): scaffold manifest schema, example repo, and core utils`
  - Files: `manifest.schema.yaml`, `example-team-config/manifest.yaml`, `docs/skills-paths-validation.md`

- [ ] 2. Example Team-Config Repository Scaffold

  **What to do**:
  - Create an `example-team-config/` directory that serves as a template for teams to fork
  - Include a complete `manifest.yaml` using the schema from Task 1
  - Include a `README.md` explaining each section and how to customize
  - Example content should demonstrate:
    - 3-5 example Remote/SSE MCPs (context7, sentry, etc. with placeholder URLs)
    - 2-3 example skill repo references (public GitHub repos with skills)
    - 5-8 example env vars with descriptions (API keys for the example MCPs)
    - oh-my-opencode overrides (agent model preferences, disabled items)
  - Include a `.gitignore` for the team-config repo

  **Must NOT do**:
  - Don't include real API keys or company-specific URLs
  - Don't include more than one profile/variant (keep it simple for the example)
  - Don't implement any shell scripts here (that's other tasks)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Creating template files with example content is straightforward
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 4 (install.sh needs the example to test against)
  - **Blocked By**: None (can start immediately, will align with Task 1's schema once available)

  **References**:

  **Pattern References**:
  - oh-my-zsh's `.zshrc` template — inspiration for simple, well-commented config
  - Homebrew Bundle's `Brewfile` — declarative list of things to install

  **External References**:
  - oh-my-opencode config format: `oh-my-opencode.jsonc` with `$schema` field
  - OpenCode MCP config: `{ "type": "remote", "url": "...", "headers": {...} }` format

  **Acceptance Criteria**:
  - [ ] `example-team-config/manifest.yaml` exists and is valid YAML
  - [ ] `example-team-config/README.md` exists with clear setup instructions
  - [ ] Manifest includes at least 3 MCP definitions, 2 skill repos, 5 env vars
  - [ ] All example URLs use placeholder domains (example.com, not real services)

  **QA Scenarios:**

  ```
  Scenario: Example manifest is complete and documented
    Tool: Bash
    Preconditions: example-team-config/ directory exists
    Steps:
      1. Run: ls example-team-config/ — verify manifest.yaml and README.md exist
      2. Run: grep -c 'type: remote' example-team-config/manifest.yaml — count MCP entries
      3. Run: grep -c 'repo:' example-team-config/manifest.yaml — count skill repo entries
      4. Run: grep -c 'name:' example-team-config/manifest.yaml | head — count env var entries
    Expected Result: manifest.yaml has ≥3 MCPs, ≥2 skill repos, ≥5 env vars
    Failure Indicators: File missing, counts below minimums
    Evidence: .sisyphus/evidence/task-2-example-repo.txt
  ```

  **Commit**: YES (group with Tasks 1, 3)
  - Message: `feat(oml): scaffold manifest schema, example repo, and core utils`
  - Files: `example-team-config/`

- [ ] 3. Directory Structure + Core Shell Utilities

  **What to do**:
  - Design and create the `~/.oml/` directory structure:
    ```
    ~/.oml/
    ├── bin/oml              # CLI entry point (created in Task 8)
    ├── repos/               # Git clones of skill repos + team-config
    │   └── .gitkeep
    ├── config/              # Generated configs
    │   ├── opencode.json    # Generated MCP + skills.paths config
    │   └── oh-my-opencode.jsonc  # Generated oh-my-opencode config
    ├── overrides/           # Personal override files
    │   ├── mcps.yaml        # User's additional MCPs
    │   └── skills.yaml      # User's additional skill repos
    ├── backups/             # Config backups before regeneration
    ├── env/                 # Environment files
    │   └── .env.template    # Generated template
    └── .lock                # Concurrency lock file
    ```
  - Create `lib/` directory with core shell utilities:
    - `lib/common.sh` — logging (info, warn, error, success with colors), platform detection (macOS/Linux), dependency checks (git, curl, bun/bunx), lockfile management (acquire/release with PID check)
    - `lib/manifest.sh` — YAML manifest parser using `python3 -c 'import yaml; ...'` or `yq` if available (fallback: simple grep/sed for flat YAML)
    - `lib/git.sh` — git clone/pull helpers with branch support, shallow clone for speed, error handling for auth failures
  - All shell files must start with `#!/usr/bin/env bash` and `set -euo pipefail`
  - All functions must be documented with a one-line comment explaining purpose

  **Must NOT do**:
  - Don't require Python or yq as hard dependencies (manifest parser should gracefully degrade)
  - Don't use macOS-only commands (e.g., use `date -u` not `gdate`)
  - Don't hardcode any paths — use `$OML_HOME` (defaults to `$HOME/.oml`)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Creating directory structure and utility functions is well-defined work
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 4, 5, 6, 7 (all source `lib/*.sh`)
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - oh-my-zsh's `lib/` directory — `lib/cli.zsh`, `lib/git.zsh` — modular shell library pattern
  - nvm's `nvm.sh` — POSIX-compatible shell utility patterns, platform detection

  **External References**:
  - ShellCheck: `https://www.shellcheck.net/` — all shell code must pass shellcheck
  - POSIX sh compatibility: avoid bashisms where possible, but bash 4+ is acceptable

  **Acceptance Criteria**:
  - [ ] `lib/common.sh` exists with: `oml_info`, `oml_warn`, `oml_error`, `oml_success`, `oml_detect_platform`, `oml_check_deps`, `oml_lock_acquire`, `oml_lock_release`
  - [ ] `lib/manifest.sh` exists with: `oml_parse_manifest` (returns structured data from YAML)
  - [ ] `lib/git.sh` exists with: `oml_git_clone`, `oml_git_pull`, `oml_git_clone_or_pull`
  - [ ] All `.sh` files pass `shellcheck` with no errors
  - [ ] Functions work on both macOS and Linux (no platform-specific commands without fallback)

  **QA Scenarios:**

  ```
  Scenario: Core utilities are shellcheck-clean and functional
    Tool: Bash
    Preconditions: lib/*.sh files exist
    Steps:
      1. Run: shellcheck lib/common.sh lib/manifest.sh lib/git.sh
      2. Run: source lib/common.sh && oml_info 'test message'
      3. Run: source lib/common.sh && oml_detect_platform
      4. Run: source lib/common.sh && oml_check_deps git curl
    Expected Result: shellcheck passes, functions output correctly, platform detected as 'darwin' or 'linux'
    Failure Indicators: shellcheck errors, function not found, platform detection fails
    Evidence: .sisyphus/evidence/task-3-core-utils.txt

  Scenario: YAML manifest parsing works without hard deps
    Tool: Bash
    Preconditions: lib/manifest.sh and a test manifest.yaml exist
    Steps:
      1. Create a minimal test manifest.yaml with 1 MCP and 1 skill repo
      2. Run: source lib/manifest.sh && oml_parse_manifest test-manifest.yaml
      3. Verify output contains parsed MCP name and skill repo URL
    Expected Result: Parser extracts MCPs and skill repos from YAML
    Failure Indicators: Parse fails, empty output, Python/yq not found and no fallback
    Evidence: .sisyphus/evidence/task-3-manifest-parser.txt
  ```

  **Commit**: YES (group with Tasks 1, 2)
  - Message: `feat(oml): scaffold manifest schema, example repo, and core utils`
  - Files: `lib/common.sh`, `lib/manifest.sh`, `lib/git.sh`

- [ ] 4. Bootstrap `install.sh` Script

  **What to do**:
  - Create the main `install.sh` bootstrap script that users run via `curl -fsSL <url>/install.sh | bash`
  - Script flow:
    1. Print welcome banner with version
    2. Detect platform (macOS/Linux) using `lib/common.sh`
    3. Check prerequisites: `git`, `curl`, `bun` (or `npm`/`npx` as fallback)
    4. If `bun` not found, offer to install it: `curl -fsSL https://bun.sh/install | bash`
    5. Check if OpenCode is installed, if not: install via `bun install -g opencode` or official method
    6. Check if oh-my-opencode is installed, if not: `bunx oh-my-opencode install`
    7. Accept team-config repo URL as argument or prompt: `install.sh <team-config-git-url>`
    8. Acquire lock (`oml_lock_acquire`)
    9. Clone team-config repo to `~/.oml/repos/team-config/`
    10. Parse `manifest.yaml` to discover skill repos and MCPs
    11. Invoke skill cloner (Task 6) to clone all skill repos
    12. Invoke config generator (Task 5) to generate `opencode.json` and `oh-my-opencode.jsonc`
    13. Invoke env template generator (Task 7) to create `.env.template`
    14. Create `~/.oml/overrides/` with empty override files
    15. Add `~/.oml/bin` to PATH in `~/.bashrc` and `~/.zshrc` (with duplicate check)
    16. Set `OPENCODE_CONFIG=~/.oml/config/opencode.json` in shell rc files
    17. Release lock
    18. Print summary: what was installed, what env vars need to be set, next steps
  - Script must be idempotent: running twice should detect existing install and update instead
  - Script must be pipe-safe: work with `curl | bash` (no stdin prompts unless interactive terminal detected)

  **Must NOT do**:
  - Don't install Python/Node/other runtimes beyond bun
  - Don't auto-fill API keys or secrets
  - Don't modify existing OpenCode configs outside `~/.oml/` (only set env vars to point to oml's configs)
  - Don't require root/sudo

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Complex shell scripting with multiple stages, error handling, and platform compatibility
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6, 7)
  - **Blocks**: Task 8 (CLI wrapper uses install.sh internals)
  - **Blocked By**: Tasks 1, 2, 3 (needs schema, example repo, and utilities)

  **References**:

  **Pattern References**:
  - oh-my-zsh `install.sh`: `https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh` — the gold standard for curl|bash installers
  - nvm `install.sh`: `https://github.com/nvm-sh/nvm/blob/master/install.sh` — PATH setup patterns
  - bun install script: `https://bun.sh/install` — modern installer pattern

  **API/Type References**:
  - `lib/common.sh` (from Task 3) — logging, platform detection, dep checks, lockfile
  - `lib/manifest.sh` (from Task 3) — YAML manifest parser
  - `lib/git.sh` (from Task 3) — git clone/pull helpers
  - `manifest.schema.yaml` (from Task 1) — manifest format definition

  **Acceptance Criteria**:
  - [ ] `install.sh` exists and is executable (`chmod +x`)
  - [ ] Running `bash install.sh <team-config-url>` on clean env creates `~/.oml/` structure
  - [ ] OpenCode + oh-my-opencode are verified/installed
  - [ ] Team-config repo cloned to `~/.oml/repos/team-config/`
  - [ ] PATH and OPENCODE_CONFIG added to shell rc files (no duplicates on re-run)
  - [ ] Script is idempotent: second run detects existing install, updates instead of failing
  - [ ] Script works with `curl | bash` (no interactive prompts when piped)

  **QA Scenarios:**

  ```
  Scenario: Fresh install from curl pipe
    Tool: Bash
    Preconditions: No ~/.oml/ directory exists, git and bun are available
    Steps:
      1. Run: rm -rf ~/.oml  (ensure clean state)
      2. Run: bash install.sh ./example-team-config (use local example as team-config)
      3. Run: ls -la ~/.oml/ — verify directory structure
      4. Run: ls ~/.oml/repos/team-config/manifest.yaml — verify team config cloned
      5. Run: cat ~/.oml/config/opencode.json — verify generated config exists
      6. Run: grep 'OPENCODE_CONFIG' ~/.zshrc || grep 'OPENCODE_CONFIG' ~/.bashrc
    Expected Result: All directories created, config generated, env var set in rc file
    Failure Indicators: Missing directories, no config file, PATH not added
    Evidence: .sisyphus/evidence/task-4-fresh-install.txt

  Scenario: Idempotent re-run
    Tool: Bash
    Preconditions: oml already installed from previous scenario
    Steps:
      1. Run: bash install.sh ./example-team-config (second run)
      2. Run: grep -c 'OPENCODE_CONFIG' ~/.zshrc — should be exactly 1 (no duplicate)
      3. Run: ls ~/.oml/repos/ — repos should still exist
    Expected Result: No errors, no duplicate PATH entries, existing config updated
    Failure Indicators: Duplicate entries in rc files, error on existing directory
    Evidence: .sisyphus/evidence/task-4-idempotent.txt
  ```

  **Commit**: YES
  - Message: `feat(oml): add bootstrap install.sh script`
  - Files: `install.sh`

- [ ] 5. Config Generator — `opencode.json` + `oh-my-opencode.jsonc`

  **What to do**:
  - Create `lib/config.sh` with functions to generate OpenCode and oh-my-opencode configuration files
  - `oml_generate_opencode_config()` — reads manifest.yaml and generates `~/.oml/config/opencode.json`:
    - Assembles `mcp` section from manifest's MCP definitions (Remote/SSE entries with URLs, headers, env var substitution)
    - Assembles `skills.paths` section pointing to each cloned skill repo's skills directory (if `skills.paths` validated in Task 1)
    - If `skills.paths` not supported: creates symlinks from `~/.config/opencode/skills/<name>` to cloned repo paths
    - Includes `$schema` reference for IDE support
    - Handles `{env:VAR_NAME}` substitution syntax for env vars in MCP headers/URLs
  - `oml_generate_omo_config()` — reads manifest.yaml and generates `~/.oml/config/oh-my-opencode.jsonc`:
    - Assembles agent model preferences from manifest
    - Sets `skills.sources` paths pointing to cloned repos
    - Applies `disabled_mcps` and `disabled_skills` from manifest
  - Both generators must merge with personal overrides (from `~/.oml/overrides/`) if they exist
  - Both generators must create a backup of existing config before overwriting (to `~/.oml/backups/`)

  **Must NOT do**:
  - Don't hardcode any MCP URLs — everything comes from manifest
  - Don't resolve env vars — keep `{env:VAR}` syntax for OpenCode to resolve at runtime
  - Don't modify configs outside `~/.oml/config/`
  - Don't add configs for tools other than OpenCode and oh-my-opencode

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex data transformation (YAML → JSON), merge logic with overrides, conditional paths (skills.paths vs symlinks)
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6, 7)
  - **Blocks**: Tasks 8, 9 (CLI and overrides use config generator)
  - **Blocked By**: Tasks 1, 3 (needs schema format and utilities)

  **References**:

  **Pattern References**:
  - `manifest.schema.yaml` (from Task 1) — defines MCP and skills structure to read from
  - `lib/manifest.sh` (from Task 3) — YAML parser to extract data
  - `lib/common.sh` (from Task 3) — logging and platform utilities

  **API/Type References**:
  - OpenCode config schema: `https://opencode.ai/config.json` — target output format
  - oh-my-opencode config: `oh-my-opencode.jsonc` schema — target output format
  - MCP entry format: `{ "type": "remote", "url": "...", "headers": { "Authorization": "Bearer {env:TOKEN}" } }`
  - skills.paths format: `{ "skills": { "paths": ["/absolute/path/to/skills"] } }`

  **External References**:
  - `jq` for JSON generation: use `jq` if available, fallback to `python3 -c 'import json; ...'`, last resort: printf/echo

  **Acceptance Criteria**:
  - [ ] `lib/config.sh` exists with `oml_generate_opencode_config` and `oml_generate_omo_config`
  - [ ] Generated `opencode.json` is valid JSON with `$schema`, `mcp`, and `skills.paths` sections
  - [ ] Generated `oh-my-opencode.jsonc` is valid JSONC with agent and skills config
  - [ ] MCP entries use `{env:VAR}` syntax for secrets (not literal values)
  - [ ] Backup of previous config is created in `~/.oml/backups/` with timestamp
  - [ ] Config generation is idempotent (same manifest → same output)

  **QA Scenarios:**

  ```
  Scenario: Generate valid opencode.json from manifest
    Tool: Bash
    Preconditions: manifest.yaml parsed, skill repos cloned to ~/.oml/repos/
    Steps:
      1. Run: source lib/config.sh && oml_generate_opencode_config ~/.oml/repos/team-config/manifest.yaml
      2. Run: python3 -c "import json; json.load(open('$HOME/.oml/config/opencode.json'))" — validate JSON
      3. Run: python3 -c "import json; d=json.load(open('$HOME/.oml/config/opencode.json')); assert 'mcp' in d; assert 'skills' in d; print(json.dumps(d, indent=2))"
      4. Verify MCP entries contain 'type: remote' and URLs
      5. Verify skills.paths entries point to existing directories
    Expected Result: Valid JSON with MCP and skills sections, no literal secrets
    Failure Indicators: Invalid JSON, missing sections, literal API keys instead of {env:} syntax
    Evidence: .sisyphus/evidence/task-5-opencode-config.txt

  Scenario: Config backup created on regeneration
    Tool: Bash
    Preconditions: ~/.oml/config/opencode.json already exists from previous generation
    Steps:
      1. Run: cp ~/.oml/config/opencode.json ~/.oml/config/opencode.json.pre-test
      2. Run: source lib/config.sh && oml_generate_opencode_config ~/.oml/repos/team-config/manifest.yaml
      3. Run: ls ~/.oml/backups/ — verify backup file exists with timestamp
    Expected Result: Backup file created in ~/.oml/backups/ before overwrite
    Failure Indicators: No backup created, backup directory empty
    Evidence: .sisyphus/evidence/task-5-config-backup.txt
  ```

  **Commit**: YES (group with Tasks 6, 7)
  - Message: `feat(oml): add config generator, skill syncer, env templater`
  - Files: `lib/config.sh`

- [ ] 6. Skill Repository Cloner + Syncer

  **What to do**:
  - Create `lib/skills.sh` with functions to manage skill repositories
  - `oml_sync_skills()` — reads skill repo list from manifest and ensures all are cloned/updated:
    1. Parse `skills.repos[]` from manifest (each has: `repo` (git URL), `branch` (default: main), `subdir` (default: skills/))
    2. For each repo:
       - If not cloned: `git clone --depth 1 --branch <branch> <url> ~/.oml/repos/<repo-name>/`
       - If already cloned: `git -C ~/.oml/repos/<repo-name>/ pull --ff-only`
       - If pull fails (diverged): warn user, don't force-update
    3. Verify each cloned repo has the expected `subdir/` with SKILL.md files
    4. Return list of skill directories for config generator to use in `skills.paths`
  - `oml_list_skills()` — lists all discovered skills across all repos
  - `oml_skill_status()` — shows git status of each skill repo (clean/dirty/behind)
  - Handle git auth failures gracefully: if a repo requires auth, show clear error with instructions
  - Use shallow clones (`--depth 1`) for speed, with option to do full clone if needed

  **Must NOT do**:
  - Don't `git push` to any repo (read-only access)
  - Don't `git reset --hard` or force-update (warn on conflicts)
  - Don't store git credentials (user must have ssh keys or credential helper configured)
  - Don't clone repos to locations outside `~/.oml/repos/`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Git operations with error handling, branch management, and status tracking
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 7)
  - **Blocks**: Task 8 (CLI uses sync functions)
  - **Blocked By**: Tasks 1, 3 (needs manifest format and git utilities)

  **References**:

  **Pattern References**:
  - `lib/git.sh` (from Task 3) — base git clone/pull helpers to build on
  - oh-my-zsh's plugin update mechanism: `$ZSH/tools/upgrade.sh` — how it pulls updates

  **API/Type References**:
  - Manifest `skills.repos[]` format: `{ repo: "git@...", branch: "main", subdir: "skills/" }`
  - OpenCode skills directory structure: `<repo>/<subdir>/<skill-name>/SKILL.md`

  **Acceptance Criteria**:
  - [ ] `lib/skills.sh` exists with `oml_sync_skills`, `oml_list_skills`, `oml_skill_status`
  - [ ] Skills are cloned to `~/.oml/repos/<repo-name>/` with correct branch
  - [ ] Shallow clones used by default (`--depth 1`)
  - [ ] Pull updates work for already-cloned repos
  - [ ] Auth failures produce clear error message (not cryptic git error)
  - [ ] `oml_list_skills` shows all SKILL.md files across all repos

  **QA Scenarios:**

  ```
  Scenario: Clone skill repos from manifest
    Tool: Bash
    Preconditions: manifest.yaml has at least 1 public skill repo defined
    Steps:
      1. Run: source lib/skills.sh && oml_sync_skills ~/.oml/repos/team-config/manifest.yaml
      2. Run: ls ~/.oml/repos/ — verify repo directories exist
      3. Run: find ~/.oml/repos/ -name 'SKILL.md' — verify skill files found
      4. Run: source lib/skills.sh && oml_list_skills
    Expected Result: Repos cloned, SKILL.md files present, list shows all skills
    Failure Indicators: Clone fails, no SKILL.md files, empty skill list
    Evidence: .sisyphus/evidence/task-6-skill-clone.txt

  Scenario: Update already-cloned repos
    Tool: Bash
    Preconditions: Skill repos already cloned from previous scenario
    Steps:
      1. Run: source lib/skills.sh && oml_sync_skills ~/.oml/repos/team-config/manifest.yaml
      2. Verify: no errors, repos updated (or 'already up to date' message)
      3. Run: source lib/skills.sh && oml_skill_status
    Expected Result: Repos pulled successfully, status shows 'clean' for all
    Failure Indicators: Pull errors, force-reset warnings
    Evidence: .sisyphus/evidence/task-6-skill-update.txt
  ```

  **Commit**: YES (group with Tasks 5, 7)
  - Message: `feat(oml): add config generator, skill syncer, env templater`
  - Files: `lib/skills.sh`

- [ ] 7. `.env` Template Generator

  **What to do**:
  - Create `lib/env.sh` with functions to generate environment variable templates
  - `oml_generate_env_template()` — reads `env[]` section from manifest and generates `~/.oml/env/.env.template`:
    ```bash
    # oh-my-longfor Environment Variables
    # Generated by oml on 2026-02-25
    # Copy this file to ~/.env.oml and fill in your values
    #
    # Required API Keys:
    SENTRY_TOKEN=          # Sentry authentication token (required for MCP)
    CONTEXT7_API_KEY=      # Context7 API key (optional, free tier available)
    OPENAI_API_KEY=        # OpenAI API key (required for oracle agent model)
    #
    # Optional:
    GITHUB_TOKEN=          # GitHub personal access token (for private repos)
    ```
  - `oml_check_env()` — checks which required env vars are set and which are missing
    - Reads current shell environment
    - Compares against manifest's `env[]` list
    - Reports: ✅ set / ❌ missing for each var
    - Does NOT read or display actual values (security)
  - `oml_env_source_line()` — generates the line to add to shell rc: `[ -f ~/.env.oml ] && source ~/.env.oml`
  - Generates instructions for how to use: copy template, fill in values, source in shell

  **Must NOT do**:
  - Don't include actual API key values anywhere
  - Don't read or display values of existing env vars (only show set/unset status)
  - Don't auto-source the env file without user consent

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file generation and env var checking
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6)
  - **Blocks**: Task 8 (CLI uses env functions)
  - **Blocked By**: Tasks 1, 3 (needs manifest format and utilities)

  **References**:

  **Pattern References**:
  - `.env.example` convention from Node.js ecosystem — template with empty values and comments
  - Docker Compose `.env` pattern — key=value format with comments

  **API/Type References**:
  - Manifest `env[]` format: `{ name: "SENTRY_TOKEN", description: "...", required: true/false }`

  **Acceptance Criteria**:
  - [ ] `lib/env.sh` exists with `oml_generate_env_template`, `oml_check_env`, `oml_env_source_line`
  - [ ] Generated `.env.template` lists all env vars from manifest with descriptions
  - [ ] Required vs optional vars are clearly marked
  - [ ] `oml_check_env` correctly reports set/unset status without showing values
  - [ ] Template includes header with generation date and usage instructions

  **QA Scenarios:**

  ```
  Scenario: Generate .env template from manifest
    Tool: Bash
    Preconditions: manifest.yaml with env vars defined
    Steps:
      1. Run: source lib/env.sh && oml_generate_env_template ~/.oml/repos/team-config/manifest.yaml
      2. Run: cat ~/.oml/env/.env.template
      3. Verify: file contains all env var names from manifest
      4. Verify: no actual values are present (all empty after =)
      5. Verify: descriptions are present as comments
    Expected Result: Template file with all vars, descriptions, no actual values
    Failure Indicators: Missing vars, values present, no descriptions
    Evidence: .sisyphus/evidence/task-7-env-template.txt

  Scenario: Check env var status
    Tool: Bash
    Preconditions: .env.template generated, some env vars set in current shell
    Steps:
      1. Run: export TEST_VAR_1=value1  (simulate one set var)
      2. Run: source lib/env.sh && oml_check_env ~/.oml/repos/team-config/manifest.yaml
      3. Verify: output shows ✅ for set vars and ❌ for missing vars
      4. Verify: no actual values are displayed
    Expected Result: Clear set/unset status for each var, no values shown
    Failure Indicators: Values displayed, or all shown as missing/set regardless
    Evidence: .sisyphus/evidence/task-7-env-check.txt
  ```

  **Commit**: YES (group with Tasks 5, 6)
  - Message: `feat(oml): add config generator, skill syncer, env templater`
  - Files: `lib/env.sh`

- [ ] 8. `oml` CLI Wrapper — update, status, doctor

  **What to do**:
  - Create `bin/oml` as the main CLI entry point (shell script, not compiled binary)
  - Subcommands:
    - `oml install [team-config-url]` — runs full install flow (delegates to install.sh internals)
    - `oml update` — pulls latest team-config, re-syncs skill repos, regenerates all configs
      1. Acquire lock
      2. `git pull` team-config repo
      3. Re-run `oml_sync_skills` for all skill repos
      4. Re-run `oml_generate_opencode_config` and `oml_generate_omo_config`
      5. Re-run `oml_generate_env_template` (in case new env vars added)
      6. Merge personal overrides
      7. Print summary of what changed
      8. Release lock
    - `oml status` — shows current state:
      - Team-config repo: branch, last commit, clean/dirty
      - Skill repos: count, branches, any behind/dirty
      - Config files: exist/missing, last generated timestamp
      - Env vars: set/unset status
      - Personal overrides: count of additions
    - `oml doctor` — diagnostic checks:
      - git available? bun/bunx available? opencode installed? oh-my-opencode installed?
      - Team-config repo accessible? All skill repos clonable?
      - Generated configs valid JSON? Required env vars set?
      - `~/.oml/` directory structure intact?
      - Each check: ✅ pass / ❌ fail with fix suggestion
    - `oml env` — shows env var status (delegates to `oml_check_env`)
    - `oml version` — prints oml version
    - `oml help` — shows usage
  - Use `case` statement for subcommand routing
  - Source all `lib/*.sh` files at startup
  - Exit with appropriate codes: 0 success, 1 user error, 2 system error

  **Must NOT do**:
  - Don't implement `oml override` here (that's Task 9)
  - Don't implement `oml rollback` here (that's Task 10)
  - Don't add subcommands not listed above
  - Don't require sudo for any subcommand

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: CLI design with multiple subcommands, integration of all previous lib functions, error handling
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (with Tasks 9, 10 — but 9 and 10 can start early since they only depend on Task 5)
  - **Blocks**: Task 11 (integration test)
  - **Blocked By**: Tasks 4, 5, 6, 7 (needs all lib functions and install.sh)

  **References**:

  **Pattern References**:
  - oh-my-zsh's `omz` CLI: `https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/omz.sh` — subcommand pattern
  - All `lib/*.sh` files from Tasks 3, 5, 6, 7 — functions to orchestrate
  - `install.sh` from Task 4 — install flow to reuse in `oml install`

  **Acceptance Criteria**:
  - [ ] `bin/oml` exists and is executable
  - [ ] `oml update` pulls latest and regenerates configs without losing overrides
  - [ ] `oml status` shows comprehensive state information
  - [ ] `oml doctor` runs all diagnostic checks with clear pass/fail output
  - [ ] `oml env` shows env var status
  - [ ] `oml help` shows usage for all subcommands
  - [ ] Unknown subcommands show helpful error
  - [ ] Exit codes are correct (0 for success, non-zero for errors)

  **QA Scenarios:**

  ```
  Scenario: oml update pulls latest and regenerates
    Tool: Bash
    Preconditions: oml fully installed with team-config and skill repos
    Steps:
      1. Run: oml update
      2. Verify: exit code is 0
      3. Run: oml status — all items should show green/up-to-date
      4. Verify: ~/.oml/config/opencode.json was regenerated (check timestamp)
    Expected Result: Update completes, configs regenerated, status green
    Failure Indicators: Non-zero exit, stale configs, error messages
    Evidence: .sisyphus/evidence/task-8-oml-update.txt

  Scenario: oml doctor detects issues
    Tool: Bash
    Preconditions: oml installed, one env var intentionally unset
    Steps:
      1. Run: unset SOME_REQUIRED_VAR (if one exists)
      2. Run: oml doctor
      3. Verify: output shows ✅ for deps and ❌ for missing env var
      4. Verify: fix suggestion is shown for the failure
    Expected Result: Doctor identifies the missing var and suggests fix
    Failure Indicators: All checks pass (false positive), or crash on missing var
    Evidence: .sisyphus/evidence/task-8-oml-doctor.txt

  Scenario: oml handles unknown subcommands gracefully
    Tool: Bash
    Steps:
      1. Run: oml nonexistent-command
      2. Verify: exit code is non-zero
      3. Verify: output includes 'Unknown command' and usage help
    Expected Result: Helpful error message with available commands listed
    Failure Indicators: Cryptic error, crash, or silent success
    Evidence: .sisyphus/evidence/task-8-oml-unknown-cmd.txt
  ```

  **Commit**: YES (group with Tasks 9, 10)
  - Message: `feat(oml): add oml CLI, personal overrides, backup/rollback`
  - Files: `bin/oml`

- [ ] 9. Personal Override Mechanism

  **What to do**:
  - Create `lib/override.sh` with functions to manage personal overrides
  - Override concept: users can add their own MCPs, skill repos, and oh-my-opencode preferences ON TOP of the team base, and these survive `oml update`
  - File structure:
    - `~/.oml/overrides/mcps.yaml` — additional MCPs (same format as manifest)
    - `~/.oml/overrides/skills.yaml` — additional skill repo references
    - `~/.oml/overrides/omo.yaml` — oh-my-opencode preference overrides
  - Functions:
    - `oml_merge_overrides()` — called by config generator (Task 5) during generation:
      1. Read team manifest MCPs + user override MCPs → merge (user wins on conflict)
      2. Read team manifest skills + user override skills → append (no conflict possible)
      3. Read team omo config + user omo overrides → deep merge (user wins on conflict)
    - `oml_override_add_mcp <name> <json>` — adds an MCP to user overrides
    - `oml_override_add_skill_repo <url> <branch>` — adds a skill repo to user overrides
    - `oml_override_remove <type> <name>` — removes an override entry
    - `oml_override_list` — shows all personal overrides
  - Add `oml override` subcommand to `bin/oml` (Task 8 creates the CLI, this task adds the subcommand)
  - Conflict resolution: personal overrides always win (user intent is explicit)

  **Must NOT do**:
  - Don't modify team-config repo (overrides are local only)
  - Don't delete team-level entries (user can only ADD or OVERRIDE, not remove team MCPs)
  - Don't create complex merge strategies — simple key-wins-on-conflict

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: YAML merge logic with conflict resolution needs careful implementation
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (can start as soon as Task 5 is complete)
  - **Parallel Group**: Wave 3 (with Tasks 8, 10)
  - **Blocks**: Task 11 (integration test)
  - **Blocked By**: Task 5 (needs config generator to integrate with)

  **References**:

  **Pattern References**:
  - oh-my-zsh's `custom/` directory — user overrides that survive updates
  - Docker Compose override pattern: `docker-compose.yml` + `docker-compose.override.yml`
  - `lib/config.sh` (from Task 5) — config generator to integrate merge into

  **Acceptance Criteria**:
  - [ ] `lib/override.sh` exists with all listed functions
  - [ ] Personal MCP overrides appear in generated `opencode.json` after `oml update`
  - [ ] Personal skill repos are cloned and appear in `skills.paths`
  - [ ] Overrides survive `oml update` (not deleted or overwritten)
  - [ ] `oml override list` shows all personal additions
  - [ ] Conflict resolution: user override wins when same MCP name exists in both team and personal

  **QA Scenarios:**

  ```
  Scenario: Add personal MCP that survives update
    Tool: Bash
    Preconditions: oml installed with team config
    Steps:
      1. Run: oml override add-mcp my-personal-mcp '{"type":"remote","url":"https://my-mcp.example.com"}'
      2. Run: oml override list — verify my-personal-mcp appears
      3. Run: oml update — trigger full config regeneration
      4. Run: python3 -c "import json; d=json.load(open('$HOME/.oml/config/opencode.json')); assert 'my-personal-mcp' in d['mcp']; print('Override survived')"
    Expected Result: Personal MCP persists through update cycle
    Failure Indicators: Override lost after update, merge error, invalid JSON output
    Evidence: .sisyphus/evidence/task-9-override-survives.txt

  Scenario: Personal override wins on conflict with team config
    Tool: Bash
    Preconditions: Team manifest has MCP named 'shared-mcp' with url-A
    Steps:
      1. Run: oml override add-mcp shared-mcp '{"type":"remote","url":"https://my-custom-url.example.com"}'
      2. Run: oml update
      3. Run: python3 -c "import json; d=json.load(open('$HOME/.oml/config/opencode.json')); assert d['mcp']['shared-mcp']['url'] == 'https://my-custom-url.example.com'; print('User wins')"
    Expected Result: User's URL used instead of team's URL for conflicting MCP
    Failure Indicators: Team URL used instead, or both entries present causing error
    Evidence: .sisyphus/evidence/task-9-override-conflict.txt
  ```

  **Commit**: YES (group with Tasks 8, 10)
  - Message: `feat(oml): add oml CLI, personal overrides, backup/rollback`
  - Files: `lib/override.sh`

- [ ] 10. Backup + Rollback System

  **What to do**:
  - Create `lib/backup.sh` with functions for config backup and rollback
  - `oml_backup_create()` — called before every config regeneration:
    1. Creates timestamped backup directory: `~/.oml/backups/<YYYY-MM-DD-HHMMSS>/`
    2. Copies current `opencode.json`, `oh-my-opencode.jsonc`, `.env.template` into it
    3. Keeps last 5 backups, auto-removes older ones
  - `oml_rollback()` — restores previous config:
    1. Lists available backups with timestamps
    2. If no argument: restores the most recent backup
    3. If argument given: restores specific backup by timestamp
    4. Copies backup files back to `~/.oml/config/`
    5. Prints what was restored
  - `oml_backup_list()` — shows available backups with timestamps and sizes
  - Add `oml rollback` and `oml backup list` subcommands to `bin/oml`

  **Must NOT do**:
  - Don't backup skill repo contents (too large) — only config files
  - Don't keep more than 5 backups (disk space)
  - Don't make backup/rollback complex — simple file copy is sufficient

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file copy/restore operations
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (can start as soon as Task 5 is complete)
  - **Parallel Group**: Wave 3 (with Tasks 8, 9)
  - **Blocks**: Task 11 (integration test)
  - **Blocked By**: Task 5 (needs config generator to integrate with)

  **References**:

  **Pattern References**:
  - Time Machine / git stash metaphor — simple snapshot + restore
  - `lib/config.sh` (from Task 5) — knows which files to backup

  **Acceptance Criteria**:
  - [ ] `lib/backup.sh` exists with `oml_backup_create`, `oml_rollback`, `oml_backup_list`
  - [ ] Backup created automatically during `oml update`
  - [ ] `oml rollback` restores previous config and configs are functional
  - [ ] Max 5 backups retained, oldest auto-removed
  - [ ] `oml backup list` shows available backups with timestamps

  **QA Scenarios:**

  ```
  Scenario: Backup created on update, rollback restores it
    Tool: Bash
    Preconditions: oml installed with working config
    Steps:
      1. Run: cat ~/.oml/config/opencode.json | md5sum > /tmp/before-hash.txt
      2. Run: oml update (triggers backup + regeneration)
      3. Run: ls ~/.oml/backups/ — verify new backup directory exists
      4. Run: oml rollback
      5. Run: cat ~/.oml/config/opencode.json | md5sum > /tmp/after-hash.txt
      6. Run: diff /tmp/before-hash.txt /tmp/after-hash.txt
    Expected Result: Hash matches — rollback restored exact previous config
    Failure Indicators: Different hashes, no backup directory, rollback error
    Evidence: .sisyphus/evidence/task-10-backup-rollback.txt

  Scenario: Only 5 backups retained
    Tool: Bash
    Preconditions: oml installed
    Steps:
      1. Run: for i in $(seq 1 7); do oml update; sleep 1; done  (create 7 backups)
      2. Run: ls ~/.oml/backups/ | wc -l
    Expected Result: Exactly 5 backup directories (oldest 2 auto-removed)
    Failure Indicators: More than 5 backups, or removal error
    Evidence: .sisyphus/evidence/task-10-backup-limit.txt
  ```

  **Commit**: YES (group with Tasks 8, 9)
  - Message: `feat(oml): add oml CLI, personal overrides, backup/rollback`
  - Files: `lib/backup.sh`

- [ ] 11. End-to-End Integration Test

  **What to do**:
  - Perform a comprehensive end-to-end verification of the entire oml tool
  - Test flow:
    1. Start from clean state: `rm -rf ~/.oml` (backup first if needed)
    2. Run full install with example team-config
    3. Verify all components are working together
    4. Test the full lifecycle: install → status → add override → update → doctor → rollback
    5. Test edge cases: re-install (idempotent), invalid manifest, network failure simulation
  - This is NOT writing test code — it's running the actual tool and verifying behavior
  - Capture ALL evidence (terminal output, file contents, screenshots)

  **Must NOT do**:
  - Don't create a test framework — just run commands and verify
  - Don't skip any QA scenario — execute every one
  - Don't fake results — run on actual system

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Comprehensive testing requiring careful execution and evidence capture
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (sequential, after all other tasks)
  - **Blocks**: Final Verification Wave
  - **Blocked By**: Tasks 8, 9, 10 (needs all CLI features)

  **References**:

  **Pattern References**:
  - All previous task QA scenarios — re-execute them in sequence as an integrated flow
  - `bin/oml` (from Task 8) — the CLI to test
  - `install.sh` (from Task 4) — the installer to test
  - `example-team-config/` (from Task 2) — test input

  **Acceptance Criteria**:
  - [ ] Full install from clean state succeeds
  - [ ] `oml status` shows all green
  - [ ] `oml doctor` passes all checks
  - [ ] Personal overrides work and survive update
  - [ ] Rollback restores previous config
  - [ ] Re-install (idempotent) works without errors
  - [ ] All evidence files captured to `.sisyphus/evidence/`

  **QA Scenarios:**

  ```
  Scenario: Complete lifecycle test
    Tool: Bash
    Preconditions: Clean system (no ~/.oml/)
    Steps:
      1. Run: rm -rf ~/.oml
      2. Run: bash install.sh ./example-team-config
      3. Verify: oml status — all green
      4. Verify: oml doctor — all pass (except maybe env vars not set)
      5. Run: oml override add-mcp test-mcp '{"type":"remote","url":"https://test.example.com"}'
      6. Run: oml update
      7. Verify: test-mcp still in config after update
      8. Run: oml rollback
      9. Verify: config restored to pre-update state
      10. Run: bash install.sh ./example-team-config (re-install)
      11. Verify: no errors, no duplicates
    Expected Result: All 11 steps complete without errors
    Failure Indicators: Any step fails or produces unexpected output
    Evidence: .sisyphus/evidence/task-11-e2e-lifecycle.txt

  Scenario: Error handling — invalid manifest
    Tool: Bash
    Preconditions: oml installed
    Steps:
      1. Create invalid manifest: echo 'invalid: yaml: [broken' > /tmp/bad-manifest.yaml
      2. Run: bash install.sh /tmp/bad-team-config (with bad manifest)
      3. Verify: clear error message about invalid manifest
      4. Verify: existing ~/.oml/ config NOT corrupted
    Expected Result: Clear error, no corruption of existing config
    Failure Indicators: Silent failure, partial install, corrupted config
    Evidence: .sisyphus/evidence/task-11-e2e-error-handling.txt
  ```

  **Commit**: YES
  - Message: `test(oml): verify end-to-end integration`
  - Files: `.sisyphus/evidence/`

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `shellcheck` on all `.sh` files. Check for: unquoted variables, missing error handling, non-POSIX constructs that break Linux, hardcoded paths, missing `set -euo pipefail`. Check AI slop: excessive comments, over-abstraction, unused functions.
  Output: `ShellCheck [PASS/FAIL] | POSIX [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real QA — Full Install on Clean Environment** — `unspecified-high`
  Start from a clean state (no `~/.oml/`). Execute `install.sh` with the example team-config. Verify: all repos cloned, configs generated, .env template created, `oml status` shows green, `oml doctor` passes, `oml update` works, personal overrides work, rollback works. Save evidence.
  Output: `Install [PASS/FAIL] | Update [PASS/FAIL] | Doctor [PASS/FAIL] | Override [PASS/FAIL] | Rollback [PASS/FAIL] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual implementation. Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| After Task(s) | Commit Message | Key Files |
|---------------|---------------|-----------|
| 1, 2, 3 | `feat(oml): scaffold manifest schema, example repo, and core utils` | `manifest.schema.yaml`, `example-team-config/`, `lib/*.sh` |
| 4 | `feat(oml): add bootstrap install.sh script` | `install.sh` |
| 5, 6, 7 | `feat(oml): add config generator, skill syncer, env templater` | `lib/config.sh`, `lib/skills.sh`, `lib/env.sh` |
| 8, 9, 10 | `feat(oml): add oml CLI, personal overrides, backup/rollback` | `bin/oml`, `lib/override.sh`, `lib/backup.sh` |
| 11 | `test(oml): add end-to-end integration verification` | `.sisyphus/evidence/` |

---

## Success Criteria

### Verification Commands
```bash
# From clean state:
curl -fsSL <url>/install.sh | bash    # Expected: "✓ oml installed successfully"
oml status                              # Expected: all green checkmarks
oml doctor                              # Expected: "All checks passed" or specific fixable warnings
oml update                              # Expected: "Updated N repos, regenerated config"
oml env                                 # Expected: shows .env.template with descriptions
oml override add-mcp my-mcp '{"type":"remote","url":"https://..."}'  # Expected: personal MCP added
oml rollback                            # Expected: previous config restored
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] `install.sh` is idempotent (run twice = same result)
- [ ] macOS + Linux compatible (no macOS-only commands)
- [ ] Personal overrides survive `oml update`
- [ ] Backup created before every config regeneration
- [ ] `.env.template` lists all required keys from manifest
