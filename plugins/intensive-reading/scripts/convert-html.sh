#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: $0 <PAPER_DIR> <BASENAME> <WORK_DIR>" >&2
    exit 1
fi

PAPER_DIR="$1"
BASENAME="$2"
WORK_DIR="$3"

INPUT="${PAPER_DIR}/intensive-${BASENAME}.md"
OUTPUT="${PAPER_DIR}/intensive-${BASENAME}.html"
HEADER="${WORK_DIR}/pandoc-header.html"

# 0. Check pandoc availability
if ! command -v pandoc &>/dev/null; then
    echo "ERROR: pandoc not found. Install pandoc and retry: https://pandoc.org/installing.html" >&2
    exit 5
fi

echo "=== Phase 6: HTML Conversion ==="
echo "PAPER_DIR: ${PAPER_DIR}"
echo "BASENAME:   ${BASENAME}"
echo "WORK_DIR:   ${WORK_DIR}"
echo ""

# 1. Verify input exists
echo "--- verify input ---"
if [ ! -f "$INPUT" ]; then
    echo "ERROR: input file not found: ${INPUT}" >&2
    exit 2
fi
echo "  input: ${INPUT} ($(wc -c < "$INPUT" | tr -d ' ') bytes)"

# 2. Write CSS header
echo "--- CSS header ---"
cat > "$HEADER" << 'EOF'
<style>
body {
  max-width: 44em;
  margin: 0 auto;
  padding: 1.5em;
  font-family: "Times New Roman", "SimSun", "宋体", serif;
  font-size: 11pt;
  line-height: 1.7;
  color: #222;
}
img {
  max-width: 100%;
  height: auto;
  display: block;
  margin: 1em auto;
}
figure {
  max-width: 100%;
  margin: 1.5em 0;
  text-align: center;
}
table {
  border-collapse: collapse;
  width: 100%;
  margin: 1em 0;
  font-size: 10pt;
}
th, td {
  border: 1px solid #999;
  padding: 0.4em 0.6em;
  vertical-align: top;
}
th {
  background: #f0f0f0;
}
</style>
EOF
echo "  written: ${HEADER} ($(wc -c < "$HEADER" | tr -d ' ') bytes)"

# 3. Run pandoc
echo "--- pandoc ---"
echo "  --standalone --embed-resources --mathjax --toc"
echo "  --resource-path=${PAPER_DIR}"
echo "  --include-in-header=${HEADER}"
echo ""

pandoc "$INPUT" \
  -o "$OUTPUT" \
  --standalone \
  --embed-resources \
  --resource-path="${PAPER_DIR}" \
  --mathjax \
  --toc \
  --include-in-header="$HEADER" \
  --metadata title="${BASENAME}" 2>&1

# 4. Verify output
echo ""
echo "--- verify output ---"
if [ ! -f "$OUTPUT" ]; then
    echo "ERROR: pandoc did not produce output: ${OUTPUT}" >&2
    exit 3
fi
OUT_SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
if [ "$OUT_SIZE" -eq 0 ]; then
    echo "ERROR: output file is empty: ${OUTPUT}" >&2
    exit 4
fi
echo "  output: ${OUTPUT} (${OUT_SIZE} bytes)"

# 5. Log
echo "Phase 6: HTML conversion done → intensive-${BASENAME}.html" >> "${WORK_DIR}/_log"

# 6. Summary
echo ""
echo "--- summary ---"
echo "  input:  $(wc -c < "$INPUT" | tr -d ' ') bytes"
echo "  output: ${OUT_SIZE} bytes"
echo "  status: OK"
echo ""
echo "Self-contained HTML with embedded images, MathJax rendering, and responsive typography."
