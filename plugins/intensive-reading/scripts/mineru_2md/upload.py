"""Upload PDF files to MinerU API v4."""

import json
import os
import sys
from pathlib import Path

import requests

from .pdf_utils import prepare_files

API_BASE = os.environ.get("MINERU_API_BASE", "https://mineru.net")
API_KEY = os.environ.get("MINERU_API_KEY", "")
BATCH_URL = f"{API_BASE}/api/v4/file-urls/batch"


def build_headers():
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }


def request_upload_urls(file_meta, model_version, language, debug):
    payload = {
        "files": [{"name": f["name"], "data_id": f["data_id"]} for f in file_meta],
        "model_version": model_version,
        "language": language,
    }
    if debug:
        print(f"  [DEBUG] POST {BATCH_URL}", file=sys.stderr)
        print(f"  [DEBUG] Body: {json.dumps(payload, indent=2)}", file=sys.stderr)
    resp = requests.post(BATCH_URL, headers=build_headers(), json=payload, timeout=30)
    if debug:
        print(f"  [DEBUG] Response {resp.status_code}: {resp.text[:2000]}", file=sys.stderr)
    resp.raise_for_status()
    result = resp.json()
    if result.get("code") != 0:
        raise RuntimeError(f"API error: {result.get('msg', result)}")
    return result["data"]["batch_id"], result["data"]["file_urls"]


def upload_files(file_paths, file_urls, debug):
    for path, url in zip(file_paths, file_urls):
        if debug:
            print(f"  [DEBUG] PUT {url[:80]}...", file=sys.stderr)
        with open(path, "rb") as f:
            resp = requests.put(url, data=f, timeout=120)
            if debug:
                print(f"  [DEBUG] Response {resp.status_code}", file=sys.stderr)
            resp.raise_for_status()
        print(f"  Uploaded: {path.name}", file=sys.stderr)
