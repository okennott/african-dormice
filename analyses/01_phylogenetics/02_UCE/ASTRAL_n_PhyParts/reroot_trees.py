#!/usr/bin/env python3
"""
reroot_trees.py

Batch reroot Newick/Nexus trees listed in a file, using outgroups.

Positional usage (pipeline-compatible):
  reroot_trees.py outgroups.txt trees.lst outdir logfile

trees.lst:
  - one path per line (blank lines ignored)

Outputs:
  - rooted trees written to outdir/ with the SAME basename as input
  - logfile written as TSV with columns:
      tree_file   status   outgroups_present  chosen  message

Exit codes:
  0  success (all trees processed)
  1  at least one tree failed (see logfile)
  2  usage/input error

Dependencies:
  - ete3 (pip install ete3)
"""

from __future__ import annotations

import os
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
        for tok in line.split(","):
            tok = tok.strip()
            if tok:
                outgroups.append(tok)
    seen = set()
    uniq = []
    for o in outgroups:
        if o not in seen:
            uniq.append(o)
            seen.add(o)
    return uniq


def extract_newick(text: str) -> str:
    text = re.sub(r"\[[^][]*\]", "", text)  # remove annotations
    text = text.replace("''", "")
    text = text.replace("\x00", "")
    text = re.sub(r"\s+", " ", text).strip()

    i = text.find("(")
    j = text.rfind(";")
    if i != -1 and j != -1 and j > i:
        text = text[i : j + 1]
    return text.strip()


def parse_tree(newick: str) -> Tree:
    last_err: Exception | None = None
    for fmt in (1, 0, 3, 5, 2, 100):
        try:
            return Tree(newick, format=fmt)
        except Exception as e:
            last_err = e
    raise RuntimeError(f"Could not parse tree with ete3. Last error: {last_err}") from last_err


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print("Usage: reroot_trees.py outgroups.txt trees.lst outdir logfile", file=sys.stderr)
        return 2

    outgroups_path = Path(argv[1])
    list_path = Path(argv[2])
    outdir = Path(argv[3])
    log_path = Path(argv[4])

    if not outgroups_path.is_file():
        print(f"ERROR: outgroups file not found: {outgroups_path}", file=sys.stderr)
        return 2
    if not list_path.is_file():
        print(f"ERROR: trees list file not found: {list_path}", file=sys.stderr)
        return 2

    outgroups = read_outgroups(outgroups_path)
    paths = [Path(p.strip()) for p in list_path.read_text().splitlines() if p.strip()]

    outdir.mkdir(parents=True, exist_ok=True)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    log_lines = []
    n_ok = 0
    n_fail = 0

    # header
    log_lines.append("tree_file\tstatus\toutgroups_present\tchosen\tmessage\n")

    for p in paths:
        if not p.is_file():
            n_fail += 1
            log_lines.append(f"{p}\tfail\t\t\tmissing input file\n")
            continue

        try:
            raw = p.read_text(encoding="utf-8", errors="ignore")
            nwk = extract_newick(raw)
            t = parse_tree(nwk)

            tips = {leaf.name for leaf in t.iter_leaves()}
            present = [o for o in outgroups if o in tips]

            chosen = "none"
            if present:
                try:
                    if len(present) == 1:
                        chosen = present[0]
                        t.set_outgroup(present[0])
                    else:
                        chosen = "common_ancestor"
                        t.set_outgroup(t.get_common_ancestor(present))
                except Exception as e:
                    # Keep tree but record rooting failure
                    log_lines.append(
                        f"{p.name}\twarn\t{','.join(present)}\t{chosen}\trooting failed: {e}\n"
                    )

            out_path = outdir / p.name
            t.write(outfile=str(out_path), format=1)
            n_ok += 1

            # if no warning was recorded above, write ok row
            log_lines.append(
                f"{p.name}\tok\t{','.join(present) if present else 'none'}\t{chosen}\twrote {out_path}\n"
            )

        except Exception as e:
            n_fail += 1
            log_lines.append(f"{p.name}\tfail\t\t\t{e}\n")

    log_path.write_text("".join(log_lines), encoding="utf-8")

    print(f"Rerooted trees: ok={n_ok} fail={n_fail} outdir={outdir} log={log_path}")

    # Non-zero exit if any failures (pipeline can stop loudly)
    return 0 if n_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))