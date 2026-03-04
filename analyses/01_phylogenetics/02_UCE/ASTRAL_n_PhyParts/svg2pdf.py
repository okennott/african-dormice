#!/usr/bin/env python3
"""
svg2pdf.py

Standalone SVG -> PDF converter for pipelines.

Backwards-compatible positional usage:
  python3 svg2pdf.py input.svg output.pdf [dpi]

Recommended flag usage:
  python3 svg2pdf.py --in input.svg --out output.pdf --dpi 2400 --engine auto

Engines:
  - cairosvg  (pip install cairosvg)  [recommended for headless servers]
  - inkscape  (system install)        [vector PDF; dpi mostly irrelevant]

Notes:
  - For Inkscape export to PDF, DPI is usually not meaningful because PDF is vector.
    DPI may matter only for rasterized filters/embedded bitmaps.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def have_cairosvg() -> bool:
    try:
        import cairosvg  # noqa: F401
        return True
    except Exception:
        return False


def convert_with_cairosvg(svg: Path, pdf: Path, dpi: int) -> None:
    import cairosvg
    cairosvg.svg2pdf(url=str(svg), write_to=str(pdf), dpi=dpi)


def find_inkscape(explicit: str | None = None) -> str | None:
    if explicit:
        p = Path(explicit)
        return str(p) if p.exists() else None
    return shutil.which("inkscape")


def inkscape_major_version(inkscape_bin: str) -> int | None:
    try:
        out = subprocess.check_output([inkscape_bin, "--version"], stderr=subprocess.STDOUT)
        s = out.decode("utf-8", errors="ignore").strip()
        # e.g. "Inkscape 1.2.2 (....)"
        parts = s.split()
        for i, tok in enumerate(parts):
            if tok.lower() == "inkscape" and i + 1 < len(parts):
                v = parts[i + 1].split(".")[0]
                return int(v)
        # fallback: first numeric token
        for tok in parts:
            if tok and tok[0].isdigit():
                return int(tok.split(".")[0])
    except Exception:
        return None
    return None


def convert_with_inkscape(svg: Path, pdf: Path, inkscape_bin: str) -> None:
    major = inkscape_major_version(inkscape_bin) or 1
    if major < 1:
        cmd = [inkscape_bin, "--without-gui", f"--export-pdf={pdf}", str(svg)]
    else:
        cmd = [inkscape_bin, f"--export-filename={pdf}", str(svg)]
    subprocess.run(cmd, check=True)


def parse_args(argv: list[str]) -> argparse.Namespace:
    # Support positional legacy call:
    #   svg2pdf.py input.svg output.pdf [dpi]
    if len(argv) >= 3 and not argv[1].startswith("-"):
        svg = argv[1]
        pdf = argv[2]
        dpi = int(argv[3]) if len(argv) >= 4 else 300
        return argparse.Namespace(
            svg=svg, pdf=pdf, dpi=dpi, engine="auto", inkscape=None
        )

    p = argparse.ArgumentParser(description="Convert SVG to PDF.")
    p.add_argument("--in", dest="svg", required=True, help="Input SVG path")
    p.add_argument("--out", dest="pdf", required=True, help="Output PDF path")
    p.add_argument("--dpi", type=int, default=300, help="DPI for cairosvg (default 300)")
    p.add_argument(
        "--engine",
        choices=["auto", "cairosvg", "inkscape"],
        default="auto",
        help="Conversion engine (default auto)",
    )
    p.add_argument("--inkscape", default=None, help="Path to inkscape binary (optional)")
    return p.parse_args(argv[1:])


def main(argv: list[str]) -> int:
    ns = parse_args(argv)
    svg = Path(ns.svg)
    pdf = Path(ns.pdf)
    dpi = int(ns.dpi)

    if not svg.is_file() or svg.stat().st_size == 0:
        print(f"ERROR: input SVG not found or empty: {svg}", file=sys.stderr)
        return 2

    pdf.parent.mkdir(parents=True, exist_ok=True)

    engine = ns.engine
    if engine == "auto":
        engine = "cairosvg" if have_cairosvg() else "inkscape"

    try:
        if engine == "cairosvg":
            if not have_cairosvg():
                print("ERROR: cairosvg not installed. Try: pip install cairosvg", file=sys.stderr)
                return 1
            convert_with_cairosvg(svg, pdf, dpi)
        else:
            inkscape_bin = find_inkscape(ns.inkscape)
            if not inkscape_bin:
                print("ERROR: inkscape not found in PATH (or --inkscape invalid).", file=sys.stderr)
                return 1
            convert_with_inkscape(svg, pdf, inkscape_bin)

    except subprocess.CalledProcessError as e:
        print(f"ERROR: inkscape conversion failed: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"ERROR: conversion failed: {e}", file=sys.stderr)
        return 1

    if not pdf.is_file() or pdf.stat().st_size == 0:
        print(f"ERROR: output PDF not created: {pdf}", file=sys.stderr)
        return 1

    print(f"Converted {svg} -> {pdf} (engine={engine})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))