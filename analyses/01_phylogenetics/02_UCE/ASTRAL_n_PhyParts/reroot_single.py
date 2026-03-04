#!/usr/bin/env python3
"""
reroot_single.py

Reroot a single Newick/Nexus tree using one or more outgroup taxa.

Positional usage (pipeline-compatible):
  reroot_single.py outgroups.txt intree.tre outtree.tre

Outgroups file:
  - One taxon per line (blank lines and lines starting with # ignored)
  - Comma-separated taxa per line are allowed

Behavior:
  - If exactly 1 outgroup is present in the tree: root on that leaf.
  - If >1 are present: root on their common ancestor (may be deep if non-monophyletic).
  - If none present: tree is written unchanged (but still cleaned).

Dependencies:
  - ete3  (pip install ete3)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from ete3 import Tree


def read_outgroups(path: Path) -> list[str]:
    outgroups: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # allow comma-separated
        for tok in line.split(","):
            tok = tok.strip()
            if tok:
                outgroups.append(tok)
    # preserve order, unique
    seen = set()
    uniq = []
    for o in outgroups:
        if o not in seen:
            uniq.append(o)
            seen.add(o)
    return uniq


def extract_newick(text: str) -> str:
    """
    Best-effort extraction of a Newick string from arbitrary text.
    - Removes bracket annotations: [ ... ]
    - Slices from first '(' to last ';' if possible
    """
    text = re.sub(r"\[[^][]*\]", "", text)  # remove annotations
    text = text.replace("\x00", "")         # strip NULs if present
    text = re.sub(r"\s+", " ", text).strip()

    i = text.find("(")
    j = text.rfind(";")
    if i != -1 and j != -1 and j > i:
        text = text[i : j + 1]
    return text.strip()


def parse_tree(newick: str) -> Tree:
    """
    Try multiple ete3 formats to parse diverse outputs.
    """
    last_err: Exception | None = None
    for fmt in (1, 0, 3, 5, 2, 100):
        try:
            return Tree(newick, format=fmt)
        except Exception as e:
            last_err = e
    raise RuntimeError(f"Could not parse tree with ete3. Last error: {last_err}") from last_err


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print("Usage: reroot_single.py outgroups.txt intree.tre outtree.tre", file=sys.stderr)
        return 2

    outgroups_path = Path(argv[1])
    tree_in = Path(argv[2])
    tree_out = Path(argv[3])

    if not outgroups_path.is_file():
        print(f"ERROR: outgroups file not found: {outgroups_path}", file=sys.stderr)
        return 2
    if not tree_in.is_file():
        print(f"ERROR: input tree not found: {tree_in}", file=sys.stderr)
        return 2

    outgroups = read_outgroups(outgroups_path)
    raw = tree_in.read_text(encoding="utf-8", errors="ignore")
    nwk = extract_newick(raw)

    try:
        t = parse_tree(nwk)
    except Exception as e:
        print(f"ERROR: failed to parse tree '{tree_in}': {e}", file=sys.stderr)
        return 1

    tipset = {leaf.name for leaf in t.iter_leaves()}
    present = [o for o in outgroups if o in tipset]

    chosen = None
    if present:
        try:
            chosen = present[0] if len(present) == 1 else "common_ancestor"
            og_node = present[0] if len(present) == 1 else t.get_common_ancestor(present)
            t.set_outgroup(og_node)
        except Exception as e:
            print(
                f"WARNING: outgroup rooting failed for '{tree_in}' "
                f"(present={present}); writing unrooted cleaned tree. Error: {e}",
                file=sys.stderr,
            )

    tree_out.parent.mkdir(parents=True, exist_ok=True)
    # format=1 keeps branch lengths and internal node names if present
    t.write(outfile=str(tree_out), format=1)

    msg = f"Rerooted {tree_in} -> {tree_out}"
    if present:
        msg += f" | outgroups_present={','.join(present)} | chosen={chosen}"
    else:
        msg += " | outgroups_present=none | chosen=none"
    print(msg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))