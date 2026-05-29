# intensive-reading Plugin Development

## Project

Develop the intensive-reading plugin — a Claude Code plugin that bundles pre-defined sub-agents for academic paper annotation. The plugin automates a 6-phase pipeline: OCR cleanup, domain survey, parallel annotation, merge, audit, and finalize.

## Conventions

- UTF-8, LF line endings, 4-space indent
- Agent files under `agents/` — flat `.md` with YAML frontmatter
- Skill files under `skills/intensive-reading/` — `SKILL.md` + `rules.md`
- Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`)
- Test by installing plugin locally and running against a real paper

## Key constraints

- Sub-agents cannot spawn sub-agents (max delegation depth = 1)
- Agent file changes require session restart to take effect
- Permission inheritance: sub-agents inherit parent mode; parent `bypassPermissions` overrides all
- Phase 0/4 and all verification steps run in the main agent (not delegable to sub-agents)

## File roles

| File | Role |
|------|------|
| `plan.md` | Implementation plan and architecture decisions |
| `knowledge.md` | Domain knowledge about Claude Code plugin/agent/skill system |
| `.claude-plugin/plugin.json` | Plugin manifest |
| `agents/*.md` | Pre-defined sub-agent definitions |
| `skills/intensive-reading/SKILL.md` | Orchestration logic and pipeline control flow |
| `skills/intensive-reading/rules.md` | Annotation conventions (shared across all agents) |

## Agent model assignments

| Agent | Model | Rationale |
|-------|-------|-----------|
| phase1-cleaner | haiku | Mechanical OCR cleanup — cheap, no domain reasoning |
| phase2-surveyor | sonnet | Paper comprehension required for terminology and argument mapping |
| phase3-annotator | sonnet | Deep annotation — physical interpretation of equations, theoretical context |
| phase5-auditor | sonnet | Cross-section consistency checking and fix generation |

## Workflow

1. Edit agent/skill files
2. Install plugin: copy or symlink to Claude Code plugins path
3. Restart Claude Code session
4. Test with: `intensive reading of path/to/paper.md`
