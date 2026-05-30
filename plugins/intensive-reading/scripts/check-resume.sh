#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <SOURCE_FILE>" >&2
    echo "  SOURCE_FILE: absolute path to the paper (.md or .pdf)" >&2
    exit 1
fi

SOURCE_FILE="$1"

# --- input validation ---
err() { echo "ERROR: $1" >&2; exit 2; }

[ -n "$SOURCE_FILE" ] || err "SOURCE_FILE must not be empty"
[ -f "$SOURCE_FILE" ] || err "SOURCE_FILE does not exist: '${SOURCE_FILE}'"

# Derive BASENAME and PAPER_DIR from the source file
case "$SOURCE_FILE" in
    *.md)
        BASENAME="$(basename "$SOURCE_FILE" .md)"
        PAPER_DIR="$(cd "$(dirname "$SOURCE_FILE")" && pwd)"
        ;;
    *.pdf)
        BASENAME="$(basename "$SOURCE_FILE" .pdf)"
        ORIG_FILE_DIR="$(cd "$(dirname "$SOURCE_FILE")" && pwd)"
        PAPER_DIR="${ORIG_FILE_DIR}/${BASENAME}"
        ;;
    *)
        err "SOURCE_FILE must end in .md or .pdf: '${SOURCE_FILE}'"
        ;;
esac

[[ "$BASENAME" != */* ]] || err "BASENAME must not contain path separators: '${BASENAME}'"
[[ "$BASENAME" != intensive-* ]] || err "BASENAME starts with 'intensive-' — use the original source filename, not the annotated output"

WORK_DIR="${PAPER_DIR}/intensive-${BASENAME}"

# Header
echo "=== interrupt-resume check ==="
echo "SOURCE_FILE: ${SOURCE_FILE}"
echo "BASENAME:    ${BASENAME}"
echo "PAPER_DIR:   ${PAPER_DIR}"
echo "WORK_DIR:    ${WORK_DIR}"
echo ""

# --- sentinel inventory ---
echo "--- sentinel files ---"
check_file() { if [ -f "$1" ]; then echo "  [✓] $2"; else echo "  [✗] $2"; fi; }
check_dir()  { if [ -d "$1" ]; then echo "  [✓] $2"; else echo "  [✗] $2"; fi; }

check_dir  "$WORK_DIR"                            "WORK_DIR"
check_file "${WORK_DIR}/_sections.txt"            "_sections.txt"
check_file "${WORK_DIR}/0.md"                     "0.md (first split file)"
check_file "${WORK_DIR}/prepend.md"               "prepend.md"
check_file "${WORK_DIR}/merged.md"                "merged.md"
check_file "${WORK_DIR}/audit.md"                 "audit.md"
check_file "${PAPER_DIR}/intensive-${BASENAME}.md"  "intensive-${BASENAME}.md (export)"
check_file "${PAPER_DIR}/intensive-${BASENAME}.html" "intensive-${BASENAME}.html (phase6)"
echo ""

# Phase 3 status (only when relevant: prepend exists but merged missing)
if [ -f "${WORK_DIR}/prepend.md" ] && [ ! -f "${WORK_DIR}/merged.md" ] && [ -f "${WORK_DIR}/_sections.txt" ]; then
    echo "--- Phase 3 per-file status (_log) ---"
    while IFS=: read -r x _ name; do
        if grep -qE "^done ${x}\.md" "${WORK_DIR}/_log" 2>/dev/null; then
            echo "  [done]   ${x}.md  ${name}"
        elif grep -qE "^FAILED ${x}\.md" "${WORK_DIR}/_log" 2>/dev/null; then
            echo "  [FAILED] ${x}.md  ${name}"
        elif grep -qE "^started ${x}\.md" "${WORK_DIR}/_log" 2>/dev/null; then
            echo "  [started] ${x}.md  ${name}  ← incomplete, re-spawn"
        else
            echo "  [  -  ]  ${x}.md  ${name}  ← not started"
        fi
    done < "${WORK_DIR}/_sections.txt"
    echo ""
fi

# --- verdict ---
echo "--- verdict ---"

if [ ! -d "$WORK_DIR" ]; then
    echo "Phase 0: WORK_DIR does not exist — spawn phase0-initializer."
elif [ ! -f "${WORK_DIR}/_sections.txt" ]; then
    echo "Phase 1: _sections.txt missing — run OCR cleanup and split."
elif [ ! -f "${WORK_DIR}/0.md" ]; then
    echo "Phase 1 (redo): _sections.txt exists but 0.md missing — delete _sections.txt and re-run."
elif [ ! -f "${WORK_DIR}/prepend.md" ]; then
    echo "Phase 2: prepend.md missing — run survey."
elif [ ! -f "${WORK_DIR}/merged.md" ]; then
    # Count completion
    total=0; done_or_failed=0
    while IFS=: read -r x _ _; do
        total=$((total + 1))
        if grep -qE "^done ${x}\.md|^FAILED ${x}\.md" "${WORK_DIR}/_log" 2>/dev/null; then
            done_or_failed=$((done_or_failed + 1))
        fi
    done < "${WORK_DIR}/_sections.txt"
    if [ "$total" -gt 0 ] && [ "$done_or_failed" -eq "$total" ]; then
        echo "Phase 4: all ${total} sections complete — merge annotated files."
    else
        echo "Phase 3: ${done_or_failed}/${total} sections complete — spawn annotators for remaining."
    fi
elif [ ! -f "${WORK_DIR}/audit.md" ]; then
    echo "Phase 5: audit.md missing — run audit and fix."
elif [ ! -f "${PAPER_DIR}/intensive-${BASENAME}.md" ]; then
    echo "Export: cp audit.md → intensive-${BASENAME}.md."
elif [ ! -f "${PAPER_DIR}/intensive-${BASENAME}.html" ]; then
    echo "Phase 6: run pandoc HTML conversion."
else
    echo "DONE: all phases complete."
fi
