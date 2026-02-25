# oh-my-longfor Decisions

## Architecture Decisions
- Shell-only: no compiled binary, no Node.js/Python runtime for oml itself
- YAML parsing: use `python3 -c 'import yaml; ...'` or `yq` if available, fallback to grep/sed
- JSON generation: use `jq` if available, fallback to `python3 -c 'import json; ...'`, last resort printf/echo
- Git: shallow clones (`--depth 1`) by default for speed
- Conflict resolution: personal overrides always win over team defaults

## Manifest Format (Task 1 defines this)
```yaml
version: "1"
mcps:
  - name: context7
    type: remote
    url: "https://mcp.context7.com/sse"
    headers:
      Authorization: "Bearer {env:CONTEXT7_API_KEY}"
skills:
  repos:
    - repo: "https://github.com/example/skills-repo"
      branch: main
      subdir: "skills/"
      auth: null  # null = public, "ssh" = use SSH key, "token" = use GITHUB_TOKEN
env:
  - name: CONTEXT7_API_KEY
    description: "Context7 API key for MCP access"
    required: true
omo_overrides:
  agents: {}
  models: {}
  disabled_mcps: []
  disabled_skills: []
```

## Config Output Formats
- opencode.json: `{ "$schema": "https://opencode.ai/config.json", "mcp": {...}, "skills": { "paths": [...] } }`
- oh-my-opencode.jsonc: Standard oh-my-opencode format with team overrides

## skills.paths Validation (TODO: determine in Task 1)
- PRIMARY: Use `skills.paths` in opencode.json if it works
- FALLBACK: Create symlinks from `~/.config/opencode/skills/<name>` to cloned repo dirs

## [2026-02-25] Skills Integration: Symlinks (not skills.paths)
- Decision: Use symlinks to ~/.claude/skills/ instead of skills.paths
- Reason: skills.paths doesn't work in OpenCode 1.2.13 (tested and confirmed)
- Implementation: lib/config.sh creates symlinks during config generation
- Cleanup: Tracked in ~/.oml/config/symlinks.txt, removed on oml update/uninstall
- Forward-compat: Still include skills.paths in generated opencode.json
