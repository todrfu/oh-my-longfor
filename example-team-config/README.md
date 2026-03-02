# Team Config Repository

This repository is a template for your team's [oh-my-longfor](https://github.com/example/oh-my-longfor) configuration.

## Quick Setup

1. **Fork this repository** to your organization
2. **Edit `manifest.yaml`** to add your team's MCPs, skills, and env vars
3. **Share the repo URL** with your team — they run:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/example/oh-my-longfor/main/install.sh | bash -s -- <your-repo-url>
   ```

## Manifest Structure

The `manifest.yaml` file defines everything your team needs:

### MCPs (Model Context Protocol Servers)

```yaml
mcps:
  - name: context7          # Unique ID for this MCP
    type: remote            # Always "remote" for Remote/SSE MCPs
    url: "https://mcp.context7.com/sse"   # SSE endpoint
    headers:
      Authorization: "Bearer {env:CONTEXT7_API_KEY}"  # {env:VAR} = secret from env
```

> **Security**: Never put actual API keys in this file. Use `{env:VAR_NAME}` placeholders — OpenCode resolves these from the user's environment.

### Skills

```yaml
skills:
  repos:
    - repo: "https://github.com/your-org/team-skills"  # Git URL
      branch: main                                      # Branch (default: main)
      subdir: "skills/"                                # Skills directory (default: skills/)
      auth: null                                       # null=public, ssh=SSH key, token=GITHUB_TOKEN
      # Optional: Control which skills are installed
      # includes: ["skill-a", "skill-b"]               # Whitelist: ONLY install these skills
      # excludes: ["skill-c"]                          # Blacklist: Install all EXCEPT these
```

Each skill repo should contain directories with `SKILL.md` files:
```
team-skills/
└── skills/
    ├── my-skill-1/
    │   └── SKILL.md
    └── my-skill-2/
        └── SKILL.md
```

**Filtering Skills:**
- Use `includes` to install ONLY specific skills (whitelist approach)
- Use `excludes` to install all EXCEPT specific skills (blacklist approach)  
- If both are specified, `includes` takes precedence
- If neither is specified, ALL skills from the repo will be installed

**Filter Examples:**

```yaml
# Example 1: Only install Vue ecosystem skills
skills:
  repos:
    - repo: "https://github.com/your-org/frontend-skills"
      includes: ["vue", "nuxt", "vite", "pinia"]

# Example 2: Install all except deprecated skills
    - repo: "https://github.com/your-org/backend-skills"
      excludes: ["legacy-api", "deprecated-tool"]

# Example 3: Multiple repos with different filters
    - repo: "https://github.com/company/shared-skills"
      includes: ["fastapi", "postgres"]  # Backend team only needs these
```

**Important Notes:**
- Skill names must match directory names exactly (case-sensitive)
- Run `oml update` after changing filters to apply changes
- Personal overrides in `~/.oml/overrides/skills.yaml` take precedence

### Environment Variables

```yaml
env:
  - name: CONTEXT7_API_KEY          # Variable name (UPPER_SNAKE_CASE)
    description: "Context7 API key" # Human-readable description with instructions
    required: true                  # true = required, false = optional
```

### oh-my-opencode Overrides

```yaml
omo_overrides:
  agents:              # Override agent model preferences
    oracle:
      model: "gpt-4o"
  disabled_mcps: []    # MCPs to disable for this team
  disabled_skills: []  # Skills to disable for this team
```

## Customization Guide

1. **Add your MCPs**: Replace the example MCPs with your team's actual Remote/SSE MCPs
2. **Add your skill repos**: Replace the example repos with your team's actual skill repositories
3. **Update env vars**: Add all API keys and tokens your MCPs require, with helpful descriptions
4. **Set overrides**: Customize oh-my-opencode behavior for your team

## Personal Overrides

Team members can add personal MCPs and skills without modifying this repo:
```bash
oml override add-mcp my-personal-mcp '{"type":"remote","url":"https://..."}'
oml override add-skill-repo https://github.com/me/my-skills
oml override list
```

Personal overrides survive `oml update` and are stored in `~/.oml/overrides/`.

## Updating the Team Config

1. Push changes to this repo
2. All team members run: `oml update`

That's it — oml pulls the latest manifest and regenerates all configs automatically.
