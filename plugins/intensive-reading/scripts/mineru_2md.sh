#!/usr/bin/env bash
set -euo pipefail

API_KEY="${MINERU_API_KEY:-}"
API_BASE="${MINERU_API_BASE:-https://mineru.net}"
BATCH_URL="${API_BASE}/api/v4/file-urls/batch"
RESULTS_URL="${API_BASE}/api/v4/extract-results/batch"

TIMEOUT=300
POLL_INTERVAL=5
MODEL="vlm"
LANGUAGE="ch"
DEBUG=false
OUTPUT_DIR="."
FILES=()

usage() {
    cat <<'EOF'
Usage: mineru_2md [OPTIONS] FILE...

Convert PDF files to Markdown via MinerU API v4.

Options:
  -o, --output-dir DIR    Output directory (default: .)
  -t, --timeout SEC       Max wait seconds (default: 300)
  -p, --poll-interval SEC Status check interval (default: 5)
  -m, --model MODEL       Model: vlm|pipeline (default: vlm)
  -l, --language LANG     Language: ch|en (default: ch)
  -d, --debug             Verbose output
  -h, --help              Show this help
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -t|--timeout)    TIMEOUT="$2"; shift 2 ;;
        -p|--poll-interval) POLL_INTERVAL="$2"; shift 2 ;;
        -m|--model)      MODEL="$2"; shift 2 ;;
        -l|--language)   LANGUAGE="$2"; shift 2 ;;
        -d|--debug)      DEBUG=true; shift ;;
        -h|--help)       usage ;;
        --) shift; FILES+=("$@"); break ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *)  FILES+=("$1"); shift ;;
    esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Error: no input files" >&2
    usage
fi

if [[ -z "$API_KEY" ]]; then
    echo "Error: MINERU_API_KEY is not set" >&2
    exit 1
fi

for cmd in curl jq unzip uuidgen; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found" >&2
        exit 1
    fi
done

AUTH="Authorization: Bearer ${API_KEY}"
CONTENT_JSON="Content-Type: application/json"

# Resolve output dir
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
mkdir -p "$OUTPUT_DIR"

# --- Upload phase ---

echo "Uploading ${#FILES[@]} file(s) to MinerU API..." >&2

# Resolve and validate input paths
resolved_files=()
for f in "${FILES[@]}"; do
    f="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
    if [[ ! -f "$f" ]]; then
        echo "Error: file not found: $f" >&2
        exit 1
    fi
    resolved_files+=("$f")
done
FILES=("${resolved_files[@]}")

# Build files metadata (name + data_id) and JSON payload
file_meta_json="[]"
file_names=()
file_ids=()
for f in "${FILES[@]}"; do
    name="$(basename "$f")"
    data_id="$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d -)"
    file_names+=("$name")
    file_ids+=("$data_id")
    file_meta_json="$(jq --arg n "$name" --arg d "$data_id" \
        '. + [{"name": $n, "data_id": $d}]' <<<"$file_meta_json")"
done

payload="$(jq -n \
    --argjson files "$file_meta_json" \
    --arg model "$MODEL" \
    --arg lang "$LANGUAGE" \
    '{files: $files, model_version: $model, language: $lang}')"

if $DEBUG; then
    echo "  [DEBUG] POST ${BATCH_URL}" >&2
    echo "  [DEBUG] Body: $(jq -c . <<<"$payload")" >&2
fi

resp="$(curl -sS --max-time 30 \
    -H "$CONTENT_JSON" -H "$AUTH" \
    -d "$payload" "$BATCH_URL")"

if $DEBUG; then
    echo "  [DEBUG] Response: ${resp:0:2000}" >&2
fi

code="$(jq -r '.code' <<<"$resp")"
if [[ "$code" != "0" ]]; then
    msg="$(jq -r '.msg // "unknown"' <<<"$resp")"
    echo "Error: API error: $msg" >&2
    exit 1
fi

batch_id="$(jq -r '.data.batch_id' <<<"$resp")"

# Upload each file to its presigned URL
i=0
for f in "${FILES[@]}"; do
    url="$(jq -r ".data.file_urls[$i]" <<<"$resp")"
    if $DEBUG; then
        echo "  [DEBUG] PUT ${url:0:80}..." >&2
    fi
    curl -sSf --max-time 120 -X PUT --data-binary "@$f" "$url"
    echo "  Uploaded: ${file_names[$i]}" >&2
    i=$((i + 1))
done

# Print manifest to stdout
jq -n \
    --arg batch_id "$batch_id" \
    --argjson files "$file_meta_json" \
    '{batch_id: $batch_id, files: $files}'

# --- Download phase ---

echo "" >&2
echo "Waiting for conversion (batch_id: ${batch_id})..." >&2

deadline="$(($(date +%s) + TIMEOUT))"
extract_results_json=""

while true; do
    now="$(date +%s)"
    if ((now >= deadline)); then
        echo "Error: timed out after ${TIMEOUT}s" >&2
        exit 1
    fi

    if $DEBUG; then
        echo "  [DEBUG] GET ${RESULTS_URL}/${batch_id}" >&2
    fi
    resp=""
    _poll_attempt=0
    while [[ $_poll_attempt -lt 2 ]]; do
        if resp="$(curl -sS --max-time 30 -H "$AUTH" "${RESULTS_URL}/${batch_id}")"; then
            break
        fi
        _poll_attempt=$((_poll_attempt + 1))
        if [[ $_poll_attempt -lt 2 ]]; then
            echo "  Poll request failed, retrying (${_poll_attempt}/2)..." >&2
            sleep 2
        fi
    done
    if [[ -z "$resp" ]]; then
        echo "Error: polling request failed after 2 attempts" >&2
        exit 1
    fi
    if $DEBUG; then
        echo "  [DEBUG] Response: ${resp:0:2000}" >&2
    fi

    code="$(jq -r '.code' <<<"$resp")"
    if [[ "$code" != "0" ]]; then
        msg="$(jq -r '.msg // "unknown"' <<<"$resp")"
        echo "Error: API error: $msg" >&2
        exit 1
    fi

    extract_results_json="$(jq -c '.data.extract_result // []' <<<"$resp")"
    if [[ "$extract_results_json" == "[]" ]]; then
        echo "  Waiting for results..." >&2
        sleep "$POLL_INTERVAL"
        continue
    fi

    all_done=true
    count="$(jq 'length' <<<"$extract_results_json")"
    ri=0
    while [[ $ri -lt $count ]]; do
        state="$(jq -r ".[$ri].state" <<<"$extract_results_json")"
        fname="$(jq -r ".[$ri].file_name // \"?\"" <<<"$extract_results_json")"

        if [[ "$state" == "failed" ]]; then
            err="$(jq -r ".[$ri].err_msg // \"unknown\"" <<<"$extract_results_json")"
            echo "Error: processing failed for $fname: $err" >&2
            exit 1
        fi

        if [[ "$state" != "done" ]]; then
            all_done=false
            extracted="$(jq -r ".[$ri].extract_progress.extracted_pages // \"?\"" <<<"$extract_results_json")"
            total="$(jq -r ".[$ri].extract_progress.total_pages // \"?\"" <<<"$extract_results_json")"
            if [[ "$extracted" != "?" ]] && [[ "$total" != "?" ]]; then
                echo "  $fname: $extracted/$total pages" >&2
            else
                echo "  $fname: $state" >&2
            fi
        fi
        ri=$((ri + 1))
    done

    if $all_done; then
        break
    fi
    sleep "$POLL_INTERVAL"
done

# --- Extract phase ---

echo "Downloading and extracting..." >&2

outputs=()
count="$(jq 'length' <<<"$extract_results_json")"
ri=0
while [[ $ri -lt $count ]]; do
    url="$(jq -r ".[$ri].full_zip_url // \"\"" <<<"$extract_results_json")"
    fname="$(jq -r ".[$ri].file_name // \"unknown\"" <<<"$extract_results_json")"

    if [[ -z "$url" ]]; then
        echo "  No download URL for $fname, skipping" >&2
        ri=$((ri + 1))
        continue
    fi

    # Determine folder name
    if [[ "$count" -eq 1 ]] && [[ ${#file_names[@]} -eq 1 ]]; then
        folder_name="${file_names[0]%.*}"
    else
        folder_name="${fname%.*}"
    fi

    extract_dir="${OUTPUT_DIR}/${folder_name}"
    mkdir -p "$extract_dir"

    if $DEBUG; then
        echo "  [DEBUG] GET (zip) ${url:0:100}..." >&2
    fi

    tmp_zip="$(mktemp "${TMPDIR:-/tmp}/mineru_2md_XXXXXXXX.zip")"
    curl -sSf --max-time 120 -o "$tmp_zip" "$url"
    if $DEBUG; then
        size="$(wc -c < "$tmp_zip" | tr -d ' ')"
        echo "  [DEBUG] Response 200, size=${size} bytes" >&2
    fi

    unzip -o -q "$tmp_zip" -d "$extract_dir"
    rm -f "$tmp_zip"
    outputs+=("$extract_dir")
    echo "  -> ${extract_dir}/" >&2

    ri=$((ri + 1))
done

if [[ ${#outputs[@]} -eq 0 ]]; then
    echo "No markdown files were produced." >&2
    exit 1
fi

echo "Done. ${#outputs[@]} folder(s) saved." >&2
