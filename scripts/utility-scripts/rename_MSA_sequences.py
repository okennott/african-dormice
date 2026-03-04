#!/usr/bin/env python3
"""
rename_msa_headers.py  –  recursively rename selected IDs in FASTA, PHYLIP,
                          or NEXUS alignments (Biopython ≥1.80 required)
"""
import argparse, re, sys
from pathlib import Path
from Bio import AlignIO

# ------------------------------------------------------------------ helpers ---
def load_map(path):
    """Return dict {old:new} from a 'old - new' mapping file."""
    regex = re.compile(r'^\s*([^\s#]+)\s*-\s*([^\s#]+)')
    mapping = {}
    with open(path) as fh:
        for ln, line in enumerate(fh, 1):
            m = regex.match(line)
            if m:
                mapping[m.group(1)] = m.group(2)
            elif line.strip() and not line.lstrip().startswith("#"):
                sys.exit(f"Bad mapping at {path}:{ln} → {line.strip()}")
    return mapping

EXT_FORMAT = {
    ".fasta": "fasta", ".fa": "fasta", ".fas": "fasta", ".aln": "fasta",
    ".phy": "phylip-relaxed", ".phylip": "phylip-relaxed",
    ".nex": "nexus", ".nexus": "nexus"
}

def process_alignment(fpath, fmt, mapping, inplace, strict_phylip):
    """Rename records in one alignment file; return True if changed."""
    align = AlignIO.read(fpath, fmt)
    changed = False
    for rec in align:
        if rec.id in mapping:
            new = mapping[rec.id]
            rec.id = rec.name = new
            rec.description = new
            changed = True

    if not changed:
        return False

    outpath = fpath if inplace else fpath.with_suffix(fpath.suffix + ".renamed")

    # If user asked for strict PHYLIP, overwrite format
    out_fmt = "phylip" if strict_phylip and fmt.startswith("phylip") else fmt
    AlignIO.write(align, outpath, out_fmt)
    return True

# -------------------------------------------------------------------- main ---
def main():
    ap = argparse.ArgumentParser(
        description="Recursively rename selected IDs in FASTA/PHYLIP/NEXUS files."
    )
    ap.add_argument("-r", "--root", required=True,
                    help="Directory containing alignments (searched recursively)")
    ap.add_argument("-m", "--map", required=True,
                    help="TXT file with 'old - new' pairs")
    ap.add_argument("--inplace", action="store_true",
                    help="Overwrite originals instead of writing *.renamed copies")
    ap.add_argument("--strict-phylip", action="store_true",
                    help="Write classical 10‑char PHYLIP instead of relaxed")
    args = ap.parse_args()

    mapping = load_map(args.map)
    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        sys.exit(f"{root} is not a directory")

    total = changed = 0
    for p in root.rglob("*"):
        ext = p.suffix.lower()
        fmt = EXT_FORMAT.get(ext)
        if fmt:
            total += 1
            if process_alignment(
                    p, fmt, mapping, args.inplace, args.strict_phylip):
                changed += 1

    print(f"Scanned {total} files → renamed headers in {changed}")

if __name__ == "__main__":
    main()
