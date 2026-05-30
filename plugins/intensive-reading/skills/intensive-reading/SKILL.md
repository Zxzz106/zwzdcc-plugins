---
name: intensive-reading
description: >
  Use when the user asks for intensive or annotated reading of academic papers,
  literature review assistance, deep understanding of technical documents, or
  requests explanations of complex papers with theoretical background.
  Triggers: 精读, intensive reading, annotated reading, help me understand
  this paper, explain this paper, requests for equation explanations or
  theoretical background on academic content.
---

# Intensive Reading

## Overview

Produce layered, additive annotations on academic papers so a reader can progress from surface comprehension to deep understanding without switching between sources. Annotations preserve all original content and add theoretical context, equation interpretation, and structural navigation aids.

Core principle: copy the source file, then edit the copy. Annotations are insertions into the copy — never replacements of the original. The original file is never touched.

## When to Use

Use for: 精读, intensive reading, annotated reading, deep understanding of papers, equation/theory explanations.
Do NOT use for: simple summaries, "what does paper X say about Y", one-paragraph answers.

## Variables

All variables are provided by `phase0-initializer`, which handles both `.md` and `.pdf` inputs uniformly. The main agent does not derive paths — it uses the returned values directly.

| Variable | Value | Meaning |
|----------|-------|---------|
| `BASENAME` | source filename without extension | The raw paper filename. |
| `PAPER_DIR` | directory containing the source file | All pipeline inputs and outputs live here. |
| `WORK_DIR` | `${PAPER_DIR}/intensive-${BASENAME}` | All pipeline artifacts live here. |
| `MD_OUTPUT` | `${PAPER_DIR}/intensive-${BASENAME}.md` | Exported annotated markdown. |
| `HTML_OUTPUT` | `${PAPER_DIR}/intensive-${BASENAME}.html` | Phase 6 pandoc conversion. |

`BASENAME` identifies the original source throughout the pipeline. The `intensive-` prefix appears only in derived paths (`WORK_DIR`, `MD_OUTPUT`, `HTML_OUTPUT`) — never on `BASENAME` itself.

## Preconditions

The user must provide an `.md` or `.pdf` file. If neither, ask for one.

All path derivation and initialization is handled by `phase0-initializer` (Phase 0). The main agent spawns it, receives the variable table, and uses those values for all subsequent phases.

## Annotation Conventions

All annotation rules — marker definitions, length guidelines, output format, language rules (including English term loanwords), equation/figure/table annotation requirements, coverage rules, and writing guidance — are defined in `rules.md` (copied to `intensive-${BASENAME}/_rules.md` in Phase 0). All sub-agents (Phases 2/3/5) must follow `_rules.md` as the single source of truth.

Summary of the five markers:

| Marker | Type | Purpose |
|--------|------|---------|
| `▶ 理论补充` | Prerequisite theory | Background knowledge needed before reading the passage (in prepend.md only) |
| `▷ 解析` | Paragraph analysis | What it claims, how it connects, why it matters (mandatory per annotation unit) |
| `◆ 关键概念` | Key concept | First occurrence of a domain-specific term — one-sentence definition |
| `※ 注意` | Caution | Pitfall, limitation, hidden assumption, common misunderstanding |
| `→ 延伸` | Extension | Related work, alternative approach, further reading |

Annotations are always in Chinese. Original text stays in its language.

## Research Tools

Search is encouraged whenever it improves annotation quality. If a concept is unfamiliar, a standard is unclear, or a cited method needs more context — search. Err on the side of searching.

**Use `WebSearch`** for: looking up unfamiliar concepts, standards, methods, fact-checking, finding recent related work, or historical context of a technique.

**Rule:** Do not spend more than 3 searches per unfamiliar concept. If information remains unclear after 3 attempts, flag it with `※ 注意` and move on.

## Core Methodology

All work happens within `intensive-${BASENAME}/`, located in the same directory as the source paper. `phase0-initializer` creates this directory. All supporting files (`_survey.md`, `_audit.md`, per-section files, etc.) live here. Phase 4 merges into `merged.md`; Phase 5 audits and fixes into `audit.md`; the main agent copies `audit.md` to the final output `intensive-${BASENAME}.md` alongside the source paper.

**Sub-agent spawning rule:** Always pass `run_in_background: false` when spawning any sub-agent. Every phase must complete before the next begins (except Phase 3 parallel annotators, which still run in foreground — the main agent waits for all before proceeding).

### Interrupt-Resume

Every phase follows copy-then-edit: each output file is either a copy of a previous artifact or newly written to completion. No phase modifies a file from a prior phase in place. This means a session crash or interrupt leaves the work directory in a deterministic state — completed phases have their sentinel files intact, incomplete phases do not.

**On any fresh start, before executing Phase 0, the main agent runs the resume check script:**
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-resume.sh" "<absolute path to source file>"
   ```
   The script derives `PAPER_DIR` and `BASENAME` from the source file path, validates inputs (rejects files with `intensive-` prefix or unsupported extensions, confirms source file exists), inventories sentinel files, reports per-file Phase 3 status, and prints a verdict. The main agent reads the verdict and proceeds to the indicated phase.

   The verdict cases:

```
1. ${WORK_DIR} does not exist
   → Spawn phase0-initializer, then continue to Phase 1.

2. ${WORK_DIR} exists, _sections.txt missing
   → Phase 0 complete. Run Phase 1.

3. _sections.txt and 0.md exist, prepend.md missing
   → Phase 1 complete (split files present). Run Phase 2.
3a. _sections.txt exists but 0.md missing
   → Phase 1 crashed mid-split. Delete _sections.txt and re-run Phase 1.

4. prepend.md exists, merged.md missing
   → Phase 2 and Phase 3 (partial) complete. Run Phase 3 for uncompleted X.md only.
   Read _sections.txt to enumerate expected X values (0 through N+1).
   grep _log for '^done\|^FAILED' — these mark files that need no further action.
   For each X without a done or FAILED entry: spawn a Phase 3 sub-agent.
   For each X with a done or FAILED entry: skip.

5. Every X in _sections.txt has a done or FAILED entry in _log, merged.md missing
   → Phase 3 complete. Run Phase 4. If any X has only a FAILED entry, note it in the final report but proceed — Phase 5 will catch missing coverage.

6. merged.md exists, audit.md missing
   → Phase 4 complete. Run Phase 5.

7. audit.md exists, intensive-${BASENAME}.md missing
   → Phase 5 complete. Run Export.

8. intensive-${BASENAME}.md exists, intensive-${BASENAME}.html missing
   → Export complete. Run Phase 6.

9. intensive-${BASENAME}.html exists
   → All phases complete. Report done.
```

**Signal priority by phase:**

- Phase 0/1/2/4/5/Export/6: sentinel file existence is authoritative. A phase could crash after writing output but before logging; the output file is the ground truth. Use `_log` only as a secondary confirmation.
- Phase 3: `_log` is authoritative for per-file completion. The sub-agent writes `echo "done X.md" >> _log` as its final step. File existence of `annotated_X.md` alone does not guarantee completion (a partial write from a crashed agent could leave a corrupt file). Trust `done` entries in `_log`, but after confirming each `done` entry, verify `annotated_X.md` exists and its size exceeds `X.md` (annotations add content — a smaller or equal-sized file is a partial write).

**Phase 3 partial resume detail:** The main agent reads `_sections.txt` to enumerate `{0, 1, ..., N+1}`. It runs `grep '^done\|^FAILED' _log` to identify files needing no further action. For each X without a `done` or `FAILED` entry, it spawns a Phase 3 sub-agent. If `annotated_X.md` exists for a file without a `done` entry, delete it before spawning (it is a partial write). Files with `done` or `FAILED` entries are left untouched. After the new batch completes, every X must have either a `done` or `FAILED` entry in `_log`.

No phase ever overwrites a completed output file. A resume from any point produces the same result as an uninterrupted run.

### Phase 0: Initialize (Sub-Agent)

Spawn the predefined agent `phase0-initializer`. Pass the absolute path to the source file and `${CLAUDE_PLUGIN_ROOT}`.

The agent handles both `.md` and `.pdf` inputs:
- `.pdf`: runs MinerU API extraction, renames output, derives all paths
- `.md`: validates the file, derives all paths

It creates `${WORK_DIR}`, copies `original.md` and `_rules.md`, initializes `_log`, and returns a standardized variable table (`BASENAME`, `PAPER_DIR`, `WORK_DIR`, source file path, final output path, HTML output path).

The main agent receives the variable table and uses those values for all subsequent phases — no further path derivation is needed.

**Important:** Do NOT modify the original source file. All work happens inside `${WORK_DIR}`. Sub-agents receive the absolute path `${WORK_DIR}` and reference all files relative to it.

### Phase 1: Clean OCR Artifacts (Sub-Agent)

Spawn the predefined agent `phase1-cleaner`. Pass `${WORK_DIR}` as the only context — all procedures (artifact cleanup, heading normalization, manifest creation, file splitting) are defined in the agent.

### Phase 2: Survey (Sub-Agent)

Spawn the predefined agent `phase2-surveyor`. Pass `${WORK_DIR}`. The agent reads `_rules.md` + `hierarchy.md`, writes `_survey.md`, `prepend.md`, `appendix.md`, and appends to `_log`.

**Phase 2-verify (main agent):** After the Phase 2 sub-agent completes, verify the outputs:

1. `_survey.md` contains at least 20 terms, each with abbreviation | full English name | Chinese translation.
2. `prepend.md` has at least 3 primers, each 5–12 Chinese sentences.
3. `appendix.md` has Appendix A (Theory Index), Appendix B (Key Values), Appendix C (Glossary — filled from survey).
4. If any check fails, fix the file or re-spawn Phase 2 before proceeding to Phase 3.
5. Append to log: `echo "Phase 2-verify: survey validated" >> _log`.

### Phase 3: Translate and Annotate (Parallel Sub-Agents)

Spawn one `phase3-annotator` agent per file `X.md` (X = 0, 1, 2, ..., N+1). ALL agents run in parallel — each file is independent, no shared state.

**Main agent procedure:**

1. Read `_sections.txt` to enumerate all X values.
2. For each X, write `echo "started X.md" >> _log` to mark in-progress.
3. Spawn all `phase3-annotator` agents simultaneously. Each prompt: `WORK_DIR=<path> X=<N> SECTION_NAME=<name>`. The agent reads `_rules.md`, `_survey.md`, `prepend.md`, `X.md`, then produces `annotated_X.md` and signals `done X.md` in `_log`.
4. After all return, verify: `grep -c '^done\|^FAILED' _log` equals the total number of split files. For each `done X.md`, verify `annotated_X.md` exists and `wc -c annotated_X.md` > `wc -c X.md` (annotations add content). If any file missing, re-spawn only that one (max 2 retries per file; if still failing, flag with `echo "FAILED X.md after 3 attempts" >> _log` and continue — Phase 5 will catch missing coverage).
5. Append: `echo "Phase 3: N files processed (M failed)" >> _log` (M = count of FAILED entries; M = 0 if all succeeded).

### Phase 4: Merge (Main Agent)

1. **Merge.** Concatenate files in order per `_sections.txt`:

```bash
cat "${WORK_DIR}/prepend.md" "${WORK_DIR}/annotated_0.md" ... "${WORK_DIR}/annotated_{N+1}.md" "${WORK_DIR}/appendix.md" > "${WORK_DIR}/merged.md"
```

`prepend.md` is always first, `appendix.md` always last.

2. **Verify structure:**
   - Total line count ≥ sum of source files (no truncation).
   - Every heading from `hierarchy.md` appears in `merged.md` — no headings lost during merge. The merged count will be larger (prepend + appendix headings added), not equal.
3. Append to log: `echo "Phase 4: merged to merged.md" >> _log`.

### Phase 5: Audit and Fix (Sub-Agent)

Spawn the predefined agent `phase5-auditor`. Pass `${WORK_DIR}`. The agent copies `merged.md` to `audit.md`, runs the audit checklist, fixes all issues, verifies with diff, and appends to `_log`.

### Export (Main Agent)

```bash
cp "${WORK_DIR}/audit.md" "${PAPER_DIR}/intensive-${BASENAME}.md"
echo "Export: cp audit.md → intensive-${BASENAME}.md" >> "${WORK_DIR}/_log"
```

Report the file path and document structure. Do NOT output the full document inline.

### Phase 6: HTML Conversion (Sub-Agent)

Spawn the predefined agent `phase6-html`. Pass `${CLAUDE_PLUGIN_ROOT}`, `${PAPER_DIR}`, `${BASENAME}`, and `${WORK_DIR}`. The agent calls `convert-html.sh` to produce a standalone HTML file with math rendering and table of contents.

If the sub-agent reports failure, read the pandoc error output. Attempt a targeted fix directly on `audit.md`. Record the fix in `${WORK_DIR}/_audit_additional.md` for traceability. Then re-run Export and Phase 6. If the second attempt also fails, report the error to the user — do not loop further.

## Output Structure

The final `intensive-${BASENAME}.md` follows this per-paragraph format:

```
[Original paragraph text.]

[Chinese translation in plain text.]

> ▷ 解析：[paragraph analysis]
```

## File Layout

All work happens in `intensive-${BASENAME}/` alongside the source paper:

```
intensive-${BASENAME}/
  original.md        # Phase 0: raw copy
  _rules.md          # Phase 0: copied from skill
  _log               # Phase 0: init, then all phases append
  clean.md           # Phase 1: OCR-cleaned
  hierarchy.md       # Phase 1: heading-normalized copy of clean.md
  _sections.txt      # Phase 1: file manifest
  0.md               # Phase 1: pre-body (abstract)
  1.md               # Phase 1: section 1
  ...
  {N+1}.md           # Phase 1: post-body admin
  _survey.md         # Phase 2: argument map, terminology, equation, domain inventories
  prepend.md         # Phase 2: reading guide + primers
  appendix.md        # Phase 2: appendices A/B/C
  annotated_0.md     # Phase 3: annotated pre-body
  annotated_1.md     # Phase 3: annotated section 1
  ...
  annotated_{N+1}.md # Phase 3: annotated post-body
  merged.md          # Phase 4: merged draft
  audit.md           # Phase 5: audited and fixed copy
  _audit.md          # Phase 5: issue list
  pandoc-header.html     # Phase 6: CSS for pandoc --include-in-header
  pandoc-after-body.html # Phase 6: JS for pandoc --include-after-body
  _audit_additional.md   # Phase 6 failure: fix record (main agent)
intensive-${BASENAME}.md   # Export: cp audit.md → alongside source paper
intensive-${BASENAME}.html # Phase 6: pandoc conversion
```

### Agent Assignments

| Phase | Agent | Action |
|-------|-------|--------|
| 0 | `phase0-initializer` | Handle `.md` or `.pdf`: extract PDF if needed, derive paths, `mkdir`, copy `original.md` and `_rules.md`, init `_log`, return variable table |
| 1 | `phase1-cleaner` | OCR cleanup + heading normalization + manifest + split |
| 2 | `phase2-surveyor` | Read `_rules.md` + `hierarchy.md`, write `_survey.md`, `prepend.md`, `appendix.md` |
| 2-verify | Main | Validate survey outputs (term counts, primer length, appendix sections) |
| 3 | `phase3-annotator` × N | Parallel: one per `X.md`, read rules + survey + prepend + source, produce `annotated_X.md` |
| 3-verify | Main | Check `_log` for all `done` lines, re-spawn missing |
| 4 | Main | Merge files with `cat` → `merged.md`, verify structure |
| 5 | `phase5-auditor` | `cp merged.md audit.md`, audit + fix in `audit.md`, diff |
| Export | Main | `cp audit.md` → `intensive-${BASENAME}.md`, append to `_log`, report path |
| 6 | `phase6-html` | Run pandoc on `intensive-${BASENAME}.md` → `intensive-${BASENAME}.html` |

## Quality Checklist

Before delivering the intensive reading document, verify:

- [ ] All original paper content is preserved (Abstract through References)
- [ ] 100% coverage confirmed by Phase 5 audit: (a) every annotation unit has translation + `▷ 解析`; (b) every numbered equation has `▷ 解析`; (c) every figure/table caption has translation
- [ ] Prerequisite theory section covers every domain boundary identified in Survey
- [ ] Every equation has a physical interpretation (not just variable renaming)
- [ ] Every figure and table caption is translated
- [ ] Five annotation markers are used consistently
- [ ] Appendix A (Theory Index), Appendix B (Key Values), Appendix C (Glossary) are complete
- [ ] All annotations are in Chinese, with common English loanwords preserved per the Language rule
- [ ] No summarization has displaced original content
- [ ] The document can be read linearly by someone with undergraduate STEM background

## Red Flags — STOP and Fix

- "I'll just explain the main ideas" — You are summarizing, not annotating.
- "The reader probably knows this already" — Assume nothing beyond undergraduate STEM.
- "This equation is standard" — Explain it physically.
- "The abstract covers the main points" — Annotate the whole paper.
- "I can skip Phase 2, I already read it" — Survey is a structured task, not passive reading.
- "I can produce the annotations in a single pass" — Survey → Primers → Annotate → Appendices → Audit → Fix. Each depends on the prior.
- "I'll skip the appendices" — Theory Index, Key Values, and Glossary are required navigation aids.
- Spawning a sub-agent with `run_in_background: true` — All sub-agents must run in foreground. The pipeline is sequential; each phase depends on the prior.
