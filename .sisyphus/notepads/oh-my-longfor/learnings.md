# oh-my-longfor Learnings

## Project Overview
Shell-based team bootstrap tool ("oml") for OpenCode + oh-my-opencode environment management.
Pure shell script (bash), macOS + Linux, no compiled binaries.

## Key Technical Decisions
- Shell-only implementation (bash/zsh, POSIX-compatible where possible)
- All MCPs are Remote/SSE type (no local server builds needed)
- Config distribution via `skills.paths` in OpenCode (if validated) or symlinks as fallback
- Team manifest in YAML, personal overrides in separate YAML files
- `~/.oml/` as the home directory for all oml data
- Python3 for YAML parsing (with grep/sed fallback), jq for JSON generation (python3 fallback)

## File Structure
```
oh-my-longfor/
├── install.sh              # Bootstrap script
├── bin/oml                 # CLI entry point
├── lib/
│   ├── common.sh           # Logging, platform detection, dep checks, lockfile
│   ├── manifest.sh         # YAML manifest parser
│   ├── git.sh              # Git clone/pull helpers
│   ├── config.sh           # OpenCode + oh-my-opencode config generators
│   ├── skills.sh           # Skill repo cloner + syncer
│   ├── env.sh              # .env template generator
│   ├── override.sh         # Personal override management
│   └── backup.sh           # Backup + rollback
├── manifest.schema.yaml    # JSON Schema for manifest validation
├── example-team-config/
│   ├── manifest.yaml       # Example manifest
│   └── README.md           # Setup guide
└── docs/
    └── skills-paths-validation.md  # skills.paths research findings
```

## Runtime Directory (~/.oml/)
```
~/.oml/
├── bin/oml              # CLI (symlinked from project)
├── repos/               # Git clones of skill repos + team-config
├── config/              # Generated configs
│   ├── opencode.json
│   └── oh-my-opencode.jsonc
├── overrides/           # Personal override files
│   ├── mcps.yaml
│   ├── skills.yaml
│   └── omo.yaml
├── backups/             # Timestamped config backups (max 5)
├── env/
│   └── .env.template    # Generated template
└── .lock                # Concurrency lock file
```

## Shell Coding Standards
- All .sh files: `#!/usr/bin/env bash` + `set -euo pipefail`
- All functions: one-line comment explaining purpose
- No hardcoded paths — use `$OML_HOME` (defaults to `$HOME/.oml`)
- All scripts must pass shellcheck with no errors
- No macOS-only commands (use `date -u`, not `gdate`)
- POSIX-compatible where possible, bash 4+ acceptable

## [2026-02-25] Task 1: Manifest Schema + skills.paths Validation
- skills.paths DOES NOT WORK in OpenCode 1.2.13 (field in schema but not implemented)
- Default skill scan directories: ~/.claude/skills/ and ~/.agents/skills/
- FALLBACK STRATEGY: Create symlinks from ~/.claude/skills/<name> -> ~/.oml/repos/<repo>/skills/<name>
- Manifest format validated: version, mcps[], skills.repos[], env[], omo_overrides
- MCP format: {name, type: remote, url, headers: {key: "{env:VAR}"}}
- Skill repo format: {repo, branch: main, subdir: "skills/", auth: null/ssh/token}
- Env format: {name, description, required: bool}
- Evidence: .sisyphus/evidence/task-1-*

## [2026-02-25] Task 2: Example Team-Config Repository Scaffold
- Created example-team-config/ with manifest.yaml (5 MCPs, 2 skill repos, 7 env vars)
- Created example-team-config/README.md with clear setup guide
- Created example-team-config/.gitignore
- All URLs are placeholder domains (example.com, context7.com, etc.)

## [2026-02-25] Task 1+2 Critical Insight: Config Generation Strategy
- opencode.json MUST use symlink approach, not skills.paths (skills.paths non-functional)
- Generated opencode.json should still include skills.paths for forward-compatibility
- Track all created symlinks in ~/.oml/config/symlinks.txt for cleanup
- Symlink target: ~/.claude/skills/<name> -> ~/.oml/repos/<repo>/skills/<name>

## [2026-02-25] Task 3: Core Shell Utilities
- lib/common.sh: oml_info/warn/error/success (colors), oml_detect_platform, oml_check_deps, oml_lock_acquire/release
- lib/manifest.sh: oml_parse_manifest (python3/yq/grep fallback), outputs MANIFEST_* variables via eval
- lib/git.sh: oml_git_clone (--depth 1), oml_git_pull (--ff-only, warns on diverged), oml_git_clone_or_pull
- shellcheck warning: avoid unused variables — export OML_VERSION, remove or comment BOLD
- All files pass shellcheck with no warnings
- Manifest parser tested: 5 MCPs, 2 repos, 7 env vars from example manifest
