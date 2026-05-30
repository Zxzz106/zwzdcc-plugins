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
AFTER_BODY="${WORK_DIR}/pandoc-after-body.html"

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
  position: relative;
  left: 130px;
  padding: 1.5em 2em;
  font-family: "Times New Roman", "SimSun", "宋体", serif;
  font-size: 11pt;
  line-height: 1.7;
  color: #222;
  transition: left 0.25s ease;
}
nav#TOC {
  position: fixed;
  left: 0;
  top: 0;
  width: 260px;
  height: 100vh;
  overflow-y: auto;
  padding: 2.5em 1em 1.2em 1em;
  background: #f8f8f8;
  border-right: 1px solid #ddd;
  font-size: 10pt;
  line-height: 1.5;
  z-index: 1;
  transition: transform 0.25s ease;
}
body.toc-collapsed nav#TOC {
  transform: translateX(-260px);
}
body.toc-collapsed {
  left: 0;
}
#toc-toggle {
  position: fixed;
  left: 8px;
  top: 8px;
  z-index: 2;
  width: 28px;
  height: 28px;
  border: 1px solid #ccc;
  border-radius: 4px;
  background: #f8f8f8;
  cursor: pointer;
  font-size: 14px;
  line-height: 26px;
  text-align: center;
  padding: 0;
  color: #555;
}
nav#TOC > ul {
  padding-left: 0;
  list-style: none;
}
nav#TOC ul {
  padding-left: 1em;
  list-style: none;
}
nav#TOC a {
  color: #555;
  text-decoration: none;
  display: block;
  padding: 0.15em 0;
  transition: color 0.15s;
}
nav#TOC a:hover {
  color: #222;
}
nav#TOC a.active {
  color: #1a6dad;
  font-weight: bold;
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
@media (max-width: 800px) {
  nav#TOC {
    position: static;
    width: auto;
    height: auto;
    max-height: 40vh;
    border-right: none;
    border-bottom: 1px solid #ddd;
    margin-bottom: 1em;
    transform: none;
    padding-top: 1.2em;
  }
  body {
    left: 0;
    padding: 1em;
  }
  body.toc-collapsed {
    left: 0;
  }
  body.toc-collapsed nav#TOC {
    transform: none;
    max-height: 0;
    overflow: hidden;
    padding: 0;
    border-bottom: none;
  }
  #toc-toggle {
    position: static;
    margin-bottom: 0.5em;
  }
}
</style>
EOF
echo "  written: ${HEADER} ($(wc -c < "$HEADER" | tr -d ' ') bytes)"

# 3. Write scroll-spy JS (after-body)
echo "--- JS scroll-spy ---"
cat > "$AFTER_BODY" << 'EOF'
<script>
(function() {
  var toc = document.querySelector('nav#TOC');
  if (!toc) return;

  // Toggle button
  var btn = document.createElement('button');
  btn.id = 'toc-toggle';
  btn.textContent = '☰';
  btn.title = 'Toggle navigation';
  document.body.insertBefore(btn, toc);

  var collapsed = false;
  btn.addEventListener('click', function() {
    collapsed = !collapsed;
    if (collapsed) {
      document.body.classList.add('toc-collapsed');
      btn.textContent = '▶';
    } else {
      document.body.classList.remove('toc-collapsed');
      btn.textContent = '☰';
    }
  });

  // Scroll-spy
  var tocLinks = toc.querySelectorAll('a[href]');
  if (tocLinks.length === 0) return;

  var headingMap = {};
  tocLinks.forEach(function(a) {
    var href = a.getAttribute('href');
    if (href && href[0] === '#') {
      var el = document.getElementById(href.slice(1));
      if (el) headingMap[href] = a;
    }
  });

  var current = null;
  var observer = new IntersectionObserver(function(entries) {
    entries.forEach(function(e) {
      if (e.isIntersecting) {
        if (current) current.classList.remove('active');
        current = headingMap['#' + e.target.id];
        if (current) current.classList.add('active');
      }
    });
  }, { rootMargin: '-20% 0px -70% 0px', threshold: 0 });

  Object.keys(headingMap).forEach(function(href) {
    var el = document.getElementById(href.slice(1));
    if (el) observer.observe(el);
  });
})();
</script>
EOF
echo "  written: ${AFTER_BODY} ($(wc -c < "$AFTER_BODY" | tr -d ' ') bytes)"

# 4. Run pandoc
echo "--- pandoc ---"
echo "  --standalone --embed-resources --mathjax --toc"
echo "  --resource-path=${PAPER_DIR}"
echo "  --include-in-header=${HEADER}"
echo "  --include-after-body=${AFTER_BODY}"
echo ""

pandoc "$INPUT" \
  -o "$OUTPUT" \
  --standalone \
  --embed-resources \
  --resource-path="${PAPER_DIR}" \
  --mathjax \
  --toc \
  --include-in-header="$HEADER" \
  --include-after-body="$AFTER_BODY" \
  --metadata title="${BASENAME}"

# 5. Verify output
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

# 6. Log
echo "Phase 6: HTML conversion done → intensive-${BASENAME}.html" >> "${WORK_DIR}/_log"

# 7. Summary
echo ""
echo "--- summary ---"
echo "  input:  $(wc -c < "$INPUT" | tr -d ' ') bytes"
echo "  output: ${OUT_SIZE} bytes"
echo "  status: OK"
echo ""
echo "Self-contained HTML with fixed sidebar navigation, scroll-spy highlighting, collapsible TOC, embedded images, and MathJax rendering."
