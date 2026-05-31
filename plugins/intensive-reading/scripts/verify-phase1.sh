#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <WORK_DIR>" >&2
    exit 1
fi

WORK_DIR="$1"
err() { echo "FAIL: $1" >&2; exit 2; }

[ -d "$WORK_DIR" ] || err "WORK_DIR does not exist: ${WORK_DIR}"

SECTIONS="${WORK_DIR}/_sections.txt"
HIERARCHY="${WORK_DIR}/hierarchy.md"

[ -f "$SECTIONS" ] || err "_sections.txt missing"
[ -f "$HIERARCHY" ] || err "hierarchy.md missing"

HIER_LINES=$(wc -l < "$HIERARCHY" | tr -d ' ')
echo "hierarchy.md: ${HIER_LINES} lines"

# Parse _sections.txt, validate each split file exists and is non-empty
prev_end=0
total_split_lines=0
count=0
errors=0

while IFS=: read -r x range name; do
    count=$((count + 1))
    start="${range%%-*}"
    end="${range##*-}"

    # Range integrity
    if [ "$start" -ne "$((prev_end + 1))" ]; then
        echo "  [✗] gap/overlap at ${x}.md: expected start $((prev_end + 1)), got ${start}"
        errors=$((errors + 1))
    fi
    prev_end="$end"

    # File existence and non-empty
    split_file="${WORK_DIR}/${x}.md"
    if [ ! -f "$split_file" ]; then
        echo "  [✗] ${x}.md missing"
        errors=$((errors + 1))
    elif [ ! -s "$split_file" ]; then
        echo "  [✗] ${x}.md is empty"
        errors=$((errors + 1))
    else
        slines=$(wc -l < "$split_file" | tr -d ' ')
        total_split_lines=$((total_split_lines + slines))
        echo "  [✓] ${x}.md  lines ${start}-${end}  (${slines} lines)  ${name}"
    fi

    # Section start must be a heading in hierarchy.md
    heading_line=$(sed -n "${start}p" "$HIERARCHY")
    if ! echo "$heading_line" | grep -qE '^#{1,6} '; then
        echo "  [✗] ${x}.md start line ${start} is not a heading: '${heading_line}'"
        errors=$((errors + 1))
    fi
done < "$SECTIONS"

# Last section must end at EOF
if [ "$prev_end" != "$HIER_LINES" ]; then
    echo "  [✗] last section ends at ${prev_end}, hierarchy.md has ${HIER_LINES} lines"
    errors=$((errors + 1))
fi

# Line coverage
if [ "$total_split_lines" -ne "$HIER_LINES" ]; then
    echo "  [✗] split files sum to ${total_split_lines} lines, hierarchy.md has ${HIER_LINES}"
    errors=$((errors + 1))
else
    echo "  [✓] line coverage: ${total_split_lines}/${HIER_LINES}"
fi

echo ""

if [ "$errors" -gt 0 ]; then
    echo "FAIL: ${errors} verification error(s) found — fix _sections.txt and re-split"
    exit 2
else
    echo "PASS: ${count} sections, coverage valid"
    # Append to log
    echo "Phase 1-verify: ${count} sections, coverage validated" >> "${WORK_DIR}/_log"
fi
