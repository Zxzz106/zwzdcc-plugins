#!/usr/bin/env python3
"""mineru_2md — Convert PDF files to Markdown via the MinerU API v4."""

import argparse
import json
import os
import sys
from pathlib import Path

from .pdf_utils import prepare_files
from .upload import request_upload_urls, upload_files
from .download import (
    JSONL_PATH,
    download_and_extract,
    merge_split_outputs,
    poll,
    read_jsonl,
    write_jsonl,
)

API_KEY = os.environ.get("MINERU_API_KEY", "")


def main():
    parser = argparse.ArgumentParser(
        description="Convert PDF files to Markdown via MinerU API v4"
    )
    parser.add_argument("files", nargs="+", type=str, help="PDF file(s) to convert")
    parser.add_argument(
        "-o", "--output-dir", type=str, default=None,
        help="Output directory (default: current dir)",
    )
    parser.add_argument(
        "-t", "--timeout", type=int, default=300,
        help="Max seconds to wait for conversion (default: 300)",
    )
    parser.add_argument(
        "-p", "--poll-interval", type=int, default=5,
        help="Seconds between status checks (default: 5)",
    )
    parser.add_argument(
        "-m", "--model", type=str, default="vlm",
        choices=["vlm", "pipeline"],
        help="Model version (default: vlm)",
    )
    parser.add_argument(
        "-l", "--language", type=str, default="ch",
        choices=["ch", "en"],
        help="Document language (default: ch)",
    )
    parser.add_argument(
        "-d", "--debug", action="store_true",
        help="Print request details",
    )
    args = parser.parse_args()

    if not API_KEY:
        print("Error: MINERU_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    raw_paths = [Path(f).resolve() for f in args.files]
    file_paths, file_meta, temp_files = prepare_files(raw_paths)

    output_dir = Path(args.output_dir).resolve() if args.output_dir else Path.cwd()
    output_dir.mkdir(parents=True, exist_ok=True)

    # Upload phase
    print(f"Uploading {len(file_meta)} file(s) to MinerU API...", file=sys.stderr)
    batch_id, file_urls = request_upload_urls(file_meta, args.model, args.language, args.debug)
    upload_files(file_paths, file_urls, args.debug)

    # Clean up temp chunk files
    for tf in temp_files:
        try:
            tf.unlink(missing_ok=True)
        except Exception:
            pass

    def _manifest_entry(m):
        entry = {"name": m["name"], "data_id": m["data_id"], "path": m["path"]}
        if "original" in m:
            entry["original"] = m["original"]
            entry["chunk_index"] = m["chunk_index"]
        return entry

    manifest = {
        "batch_id": batch_id,
        "files": [_manifest_entry(m) for m in file_meta],
    }
    print(json.dumps(manifest, indent=2))

    with open(JSONL_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(manifest) + "\n")

    # Download phase
    print(f"\nWaiting for conversion (batch_id: {batch_id})...", file=sys.stderr)
    file_names = [f["name"] for f in manifest["files"]]
    extract_results = poll(batch_id, args.timeout, args.poll_interval, args.debug)

    print("Downloading and extracting...", file=sys.stderr)
    outputs = download_and_extract(extract_results, output_dir, file_names, args.debug)

    merged = merge_split_outputs(manifest, output_dir, args.debug)
    if merged is not None:
        split_stems = {Path(f["name"]).stem for f in manifest["files"] if "original" in f}
        non_split = [o for o in outputs if o.name not in split_stems]
        outputs = non_split + merged

    entries = read_jsonl(JSONL_PATH)
    entries = [e for e in entries if e.get("batch_id") != batch_id]
    write_jsonl(JSONL_PATH, entries)

    if not outputs:
        print("No markdown files were produced.", file=sys.stderr)
        sys.exit(1)

    print(f"Done. {len(outputs)} folder(s) saved.", file=sys.stderr)


if __name__ == "__main__":
    main()
