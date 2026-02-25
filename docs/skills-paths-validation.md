# `skills.paths` Validation Research

## Summary

**Result: NOT WORKS (in OpenCode 1.2.13)**

The `skills.paths` configuration field exists in OpenCode's JSON schema but does **not** currently load skills from custom paths.

## Test Setup

- **OpenCode Version**: 1.2.13
- **Test Date**: 2026-02-25
- **Platform**: macOS (darwin)

### Test Skill Structure
```
/tmp/oml-test-skills/
└── test-skill/
    └── SKILL.md
```

**SKILL.md frontmatter:**
```yaml
---
name: test-skill
description: Validation test skill
---
```

### Test Config
```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": {
    "paths": ["/tmp/oml-test-skills"]
  }
}
```

## Test Results

| Test | Config Location | skills.paths in config? | test-skill discovered? |
|------|-----------------|------------------------|------------------------|
| 1 | `OPENCODE_CONFIG` env var | YES | **NO** |
| 2 | `~/.config/opencode/opencode.json` | YES | **NO** |

**Conclusion: `skills.paths` does NOT work as expected in OpenCode 1.2.13.**

## OpenCode Schema Definition

The `skills.paths` field IS in the official schema at `https://opencode.ai/config.json`:
```json
{
  "skills": {
    "description": "Additional skill folder paths",
    "type": "object",
    "properties": {
      "paths": {
        "description": "Additional paths to skill folders",
        "type": "array",
        "items": { "type": "string" }
      },
      "urls": {
        "description": "URLs to fetch skills from",
        "type": "array",
        "items": { "type": "string" }
      }
    }
  }
}
```

The field is defined but appears to not be implemented in the current version, or may be intended for future use.

## Default Skill Locations (Confirmed Working)

OpenCode scans these directories automatically:
- `~/.claude/skills/` — Claude Code skills
- `~/.agents/skills/` — oh-my-opencode agent skills

## Fallback Strategy: Symlinks

Since `skills.paths` doesn't work, `oml` will use symlinks to integrate cloned skill repos into OpenCode:

```bash
# For each skill directory in a cloned repo:
ln -sf ~/.oml/repos/team-skills/skills/my-skill ~/.claude/skills/my-skill
```

### Symlink Creation Logic

```bash
# In lib/config.sh: oml_generate_opencode_config()
# For each cloned skill repo, create symlinks:
for skill_dir in ~/.oml/repos/<repo-name>/skills/*/; do
    skill_name=$(basename "$skill_dir")
    skill_link=~/.claude/skills/"$skill_name"
    if [ ! -L "$skill_link" ]; then
        ln -sf "$skill_dir" "$skill_link"
    fi
done
```

### Cleanup on `oml update`

```bash
# Remove stale symlinks before regenerating
find ~/.claude/skills/ -type l -name '*' | while read link; do
    if [[ "$link" == *"/.oml/repos/"* ]]; then
        rm "$link"
    fi
done
```

## Recommendation for `oml` Implementation

1. **Generate `opencode.json` with both `skills.paths` AND symlinks** — forward-compatible for when OpenCode implements `skills.paths`, while symlinks ensure it works today.
2. **Track symlinks** in `~/.oml/config/symlinks.txt` so they can be cleaned up on update/uninstall.
3. **Symlink target**: `~/.claude/skills/<name>` (confirmed scanned by OpenCode).

## Notes on `skills.urls`

`skills.urls` was not tested (would require hosting SKILL.md files at accessible URLs). For team use, the git-clone + symlink approach is preferable.
