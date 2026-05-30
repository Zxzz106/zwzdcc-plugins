"""Poll batch status and download Markdown results from MinerU API v4."""

import json
import os
import shutil
import sys
import time
import zipfile
from pathlib import Path
from tempfile import NamedTemporaryFile

import requests

from .pdf_utils import merge_markdown

API_BASE = os.environ.get("MINERU_API_BASE", "https://mineru.net")
API_KEY = os.environ.get("MINERU_API_KEY", "")
RESULTS_URL = f"{API_BASE}/api/v4/extract-results/batch"


def build_headers():
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }


JSONL_PATH = Path.cwd() / ".mineru_processing.jsonl"


def read_jsonl(path):
    if not path.exists():
        return []
    entries = []
    for line in path.read_text().strip().splitlines():
        if line.strip():
            entries.append(json.loads(line))
    return entries


def write_jsonl(path, entries):
    if entries:
        path.write_text("\n".join(json.dumps(e) for e in entries) + "\n")
    elif path.exists():
        path.unlink()


def poll(batch_id, timeout, interval, debug):
    url = f"{RESULTS_URL}/{batch_id}"
    deadline = time.time() + timeout
    while time.time() < deadline:
        if debug:
            print(f"  [DEBUG] GET {url}", file=sys.stderr)
        resp = requests.get(url, headers=build_headers(), timeout=30)
        if debug:
            print(f"  [DEBUG] Response {resp.status_code}: {resp.text[:2000]}", file=sys.stderr)
        resp.raise_for_status()
        result = resp.json()
        if result.get("code") != 0:
            raise RuntimeError(f"API error: {result.get('msg', result)}")

        data = result.get("data", {})
        extract_results = data.get("extract_result", [])

        all_done = True
        for r in extract_results:
            state = r.get("state", "pending")
            fname = r.get("file_name", "?")

            if state == "failed":
                raise RuntimeError(f"Processing failed for {fname}: {r.get('err_msg', 'unknown')}")
            if state != "done":
                all_done = False
                progress = r.get("extract_progress", {})
                if progress:
                    extracted = progress.get("extracted_pages", "?")
                    total = progress.get("total_pages", "?")
                    print(f"  {fname}: {extracted}/{total} pages")
                else:
                    print(f"  {fname}: {state}")

        if all_done and extract_results:
            return extract_results

        if not extract_results:
            print("  Waiting for results...")
        time.sleep(interval)

    raise TimeoutError(f"Timed out after {timeout}s")


def download_and_extract(extract_results, output_dir, file_names, debug):
    outputs = []
    for r in extract_results:
        url = r.get("full_zip_url")
        fname = r.get("file_name", "unknown")
        if not url:
            print(f"  No download URL for {fname}, skipping", file=sys.stderr)
            continue

        if debug:
            print(f"  [DEBUG] GET (zip) {url[:100]}...", file=sys.stderr)
        resp = requests.get(url, timeout=120)
        if debug:
            print(
                f"  [DEBUG] Response {resp.status_code}, size={len(resp.content)} bytes",
                file=sys.stderr,
            )
        resp.raise_for_status()

        with NamedTemporaryFile(suffix=".zip", delete=False) as tmp:
            tmp.write(resp.content)
            tmp_path = tmp.name

        if file_names and len(extract_results) == 1:
            folder_name = Path(file_names[0]).stem
        else:
            folder_name = Path(fname).stem
        extract_dir = output_dir / folder_name
        extract_dir.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(tmp_path, "r") as zf:
            zf.extractall(extract_dir)
        outputs.append(extract_dir)
        print(f"  -> {extract_dir}/")

        os.unlink(tmp_path)
    return outputs


def merge_split_outputs(entry, output_dir, debug):
    """Merge chunk outputs for split PDFs into a single directory per original file."""
    files = entry.get("files", [])
    split_files = [f for f in files if "original" in f]
    if not split_files:
        return None

    groups = {}
    for f in split_files:
        original = f["original"]
        groups.setdefault(original, []).append(f)

    merged_dirs = []
    for original_name, chunk_entries in groups.items():
        original_stem = Path(original_name).stem
        chunk_entries.sort(key=lambda x: x.get("chunk_index", 0))

        chunk_dirs = []
        for ce in chunk_entries:
            chunk_dir_name = Path(ce["name"]).stem
            chunk_dir = output_dir / chunk_dir_name
            if chunk_dir.is_dir():
                chunk_dirs.append(chunk_dir)
            else:
                print(f"  Warning: expected chunk dir {chunk_dir} not found", file=sys.stderr)

        if not chunk_dirs:
            print(f"  Warning: no chunk dirs found for {original_name}, skipping merge", file=sys.stderr)
            continue

        if debug:
            print(f"  [DEBUG] Merging {len(chunk_dirs)} chunks for {original_name} -> {original_stem}/",
                  file=sys.stderr)

        merge_dir = merge_markdown(chunk_dirs, output_dir, original_stem)
        merged_dirs.append(merge_dir)

        for d in chunk_dirs:
            shutil.rmtree(d)

    return merged_dirs
