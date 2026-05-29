# zwzdcc-plugins

Personal Claude Code plugin marketplace.

## Plugins

### intensive-reading

Automated academic paper annotation pipeline. Produces layered, additive Chinese annotations so a reader can progress from surface comprehension to deep understanding without switching between sources.

| Phase | Agent | What it does |
|-------|-------|-------------|
| 0 | Main | Initialize work directory, copy source and rules |
| 1 | `phase1-cleaner` | OCR artifact cleanup, heading normalization, section split |
| 2 | `phase2-surveyor` | Domain survey, prerequisite primers, terminology glossary, appendices |
| 3 | `phase3-annotator` (×N) | Parallel per-section translation + annotation with five marker types |
| 4 | Main | Merge all annotated sections |
| 5 | `phase5-auditor` | Cross-section consistency audit and fix |
| — | Main | Copy final output alongside source paper |

Annotations preserve all original content. Five markers: prerequisite theory (`▶`), paragraph analysis (`▷`), key concepts (`◆`), cautions (`※`), extensions (`→`).

### academic-writing-check

Check academic writing for common issues: overclaiming, rhetorical inflation, citation accuracy, formatting, terminology, and structural consistency. Reports violations by category with line references and suggested corrections.

### grill-me

Interview the user relentlessly about a plan or design until reaching shared understanding, walking down each branch of the decision tree one question at a time.

## Install

```bash
claude plugin marketplace add Zxzz106/zwzdcc-plugins
claude plugins install intensive-reading@zwzdcc-plugins
claude plugins install academic-writing-check@zwzdcc-plugins
claude plugins install grill-me@zwzdcc-plugins
```

Restart Claude Code after installation.

## Usage

```
intensive reading of path/to/paper.md   # Annotate academic papers
academic writing check                  # Review academic writing
grill me                                # Stress-test a plan or design
```

intensive-reading supports `.md` files directly, PDFs via `mineru_2md` extraction, and URLs via WebFetch. Output lands alongside the source paper as `intensive-<basename>.md`.

## Requirements

- Claude Code ≥ v2.1.63
- Tavily MCP (optional — enables deeper research during survey and annotation)
