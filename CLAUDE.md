# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Personal Claude Code plugin marketplace (`zwzdcc-plugins`). Contains three plugins: `intensive-reading`, `academic-writing-check`, and `grill-me`.

## Repository structure

```
zwzdcc-plugins/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   ├── intensive-reading/          # Paper annotation pipeline (agents + skill)
│   ├── academic-writing-check/     # Academic writing review (skill only)
│   └── grill-me/                   # Design interrogation (skill only)
├── CLAUDE.md
└── README.md
```

Each plugin has its own `.claude-plugin/plugin.json`. Skill-only plugins contain just `skills/<name>/SKILL.md`. The intensive-reading plugin also includes `agents/` for its pipeline sub-agents.

To add a new plugin: create `plugins/<name>/` with its own `.claude-plugin/plugin.json`, then add an entry to the `plugins` array in `marketplace.json`.

## Conventions

- UTF-8, LF line endings, 4-space indent
- Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`)
- Test by installing plugin locally and running against a real paper

## Key constraints

- Sub-agents cannot spawn sub-agents (max delegation depth = 1)
- Agent file changes require session restart to take effect
- Permission inheritance: sub-agents inherit parent mode; parent `bypassPermissions` overrides all
- Phase 0/4 and all verification steps run in the main agent (not delegable to sub-agents)

## Plugin: intensive-reading

### Agent model assignments

| Agent | Model | Rationale |
|-------|-------|-----------|
| phase0-initializer | haiku | Mechanical initialization — path derivation, PDF extraction, work directory setup |
| phase1-cleaner | haiku | Mechanical OCR cleanup — cheap, no domain reasoning |
| phase2-surveyor | sonnet | Paper comprehension required for terminology and argument mapping |
| phase3-annotator | sonnet | Deep annotation — physical interpretation of equations, theoretical context |
| phase5-auditor | sonnet | Cross-section consistency checking and fix generation |
| phase6-html | haiku | Mechanical pandoc conversion — cheap, no domain reasoning |

### Workflow

1. Edit files under `plugins/intensive-reading/`
2. Install and test locally:
   ```bash
   claude plugin marketplace add /Users/admin/Code/PROJECT/intensive-reading
   claude plugins install intensive-reading@zwzdcc-plugins
   ```
   Or from GitHub after push:
   ```bash
   claude plugin marketplace add Zxzz106/zwzdcc-plugins
   claude plugins install intensive-reading@zwzdcc-plugins
   ```
3. Restart Claude Code session
4. Test with: `intensive reading of path/to/paper.md`
