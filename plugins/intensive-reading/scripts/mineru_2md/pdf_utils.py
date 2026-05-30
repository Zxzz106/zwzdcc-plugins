"""PDF utilities for page counting, splitting, and file preparation."""

import re
import shutil
import sys
import tempfile
import uuid
from pathlib import Path

from pypdf import PdfReader, PdfWriter


def get_page_count(pdf_path):
    try:
        reader = PdfReader(str(pdf_path))
        return len(reader.pages)
    except Exception:
        return -1


def split_pdf(pdf_path, pages_per_chunk=150, threshold=200):
    """Split a PDF into chunks if it exceeds the page threshold.

    Args:
        pdf_path: Path to the source PDF.
        pages_per_chunk: Number of pages per output chunk (default 150).
        threshold: Only split if page count exceeds this value (default 200).

    Returns:
        List of (temp_path, chunk_name, chunk_index) tuples.
        Empty list if no split is needed.
    """
    page_count = get_page_count(pdf_path)
    if page_count < 0:
        raise RuntimeError(f"Cannot read PDF: {pdf_path}")
    if page_count <= threshold:
        return []

    reader = PdfReader(str(pdf_path))
    stem = pdf_path.stem
    chunks = []

    for chunk_idx, start_page in enumerate(range(0, page_count, pages_per_chunk)):
        end_page = min(start_page + pages_per_chunk, page_count)
        chunk_name = f"mineru-md-part{chunk_idx + 1:03d}_{stem}.pdf"

        writer = PdfWriter()
        for p in range(start_page, end_page):
            writer.add_page(reader.pages[p])

        chunk_path = Path(tempfile.gettempdir()) / chunk_name
        with open(chunk_path, "wb") as f:
            writer.write(f)

        print(f"  Chunk {chunk_idx + 1}: {chunk_name} (pages {start_page + 1}-{end_page})", file=sys.stderr)
        chunks.append((chunk_path, chunk_name, chunk_idx))

    return chunks


def prepare_files(raw_paths):
    """Resolve and validate file paths, splitting oversized PDFs.

    Args:
        raw_paths: List of Path objects for input files.

    Returns:
        (file_paths, file_meta, temp_files) where:
        - file_paths: list of Path objects to upload (may include chunk files)
        - file_meta: list of dicts with name, data_id, path [+ original, chunk_index]
        - temp_files: list of Path objects to clean up after upload
    """
    file_paths = []
    file_meta = []
    temp_files = []

    for p in raw_paths:
        if not p.exists():
            print(f"Error: file not found: {p}", file=sys.stderr)
            sys.exit(1)

        page_count = get_page_count(p)
        if page_count < 0:
            print(f"  Warning: cannot read page count for {p.name}, uploading as-is", file=sys.stderr)
            file_paths.append(p)
            file_meta.append({
                "name": p.name, "data_id": uuid.uuid4().hex, "path": str(p),
            })
        elif page_count > 200:
            print(f"  Splitting {p.name} ({page_count} pages) into 150-page chunks...", file=sys.stderr)
            chunks = split_pdf(p)
            for chunk_path, chunk_name, chunk_idx in chunks:
                file_paths.append(chunk_path)
                file_meta.append({
                    "name": chunk_name,
                    "data_id": uuid.uuid4().hex,
                    "path": str(chunk_path),
                    "original": p.name,
                    "chunk_index": chunk_idx,
                })
                temp_files.append(chunk_path)
        else:
            file_paths.append(p)
            file_meta.append({
                "name": p.name, "data_id": uuid.uuid4().hex, "path": str(p),
            })

    return file_paths, file_meta, temp_files


def merge_markdown(chunk_dirs, output_dir, original_stem):
    """Merge full.md from chunk output directories into a single output directory.

    Image references in each chunk's markdown are rewritten from relative paths
    to absolute paths pointing at the chunk directory, so the merged file's
    images stay linked to their source files.

    Args:
        chunk_dirs: Ordered list of chunk output directories (each containing full.md).
        output_dir: Parent directory where the merged output will be created.
        original_stem: The stem name for the merged output directory.

    Returns:
        Path to the merged output directory.
    """
    merge_dir = output_dir / original_stem
    merge_dir.mkdir(parents=True, exist_ok=True)

    parts = []
    for chunk_dir in chunk_dirs:
        md_file = chunk_dir / "full.md"
        if not md_file.exists():
            continue
        text = md_file.read_text(encoding="utf-8")
        # Rewrite relative image paths to absolute paths pointing at chunk dir
        text = re.sub(
            r'!\[([^\]]*)\]\(((?!https?://|/)[^)]+)\)',
            lambda m: f'![{m.group(1)}]({chunk_dir / m.group(2)})',
            text,
        )
        parts.append(text)

    merged_md = merge_dir / "full.md"
    merged_md.write_text("\n\n".join(parts), encoding="utf-8")

    # Copy images from the first chunk (common resources like layout.json, etc.)
    for chunk_dir in chunk_dirs:
        for item in chunk_dir.iterdir():
            if item.name == "full.md":
                continue
            dest = merge_dir / item.name
            if item.is_dir():
                if not dest.exists():
                    shutil.copytree(item, dest)
            else:
                if not dest.exists():
                    shutil.copy2(item, dest)

    return merge_dir
