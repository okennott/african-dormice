#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# UCE phylogenomics pipeline
#
# Steps:
#   1) Infer per-locus ML gene trees with IQ-TREE 3
#   2) Reroot gene trees using an outgroup list
#   3) Infer a species tree with ASTRAL
#   4) Reroot the species tree using the same outgroup list
#   5) Compute gCF and sCF on the species tree
#      after mapping gene-tree tips to MOTU names
#   6) Run PhyParts + pie charts
#
#
# =============================================================================

# ----------------------------- Usage -----------------------------------------
usage() {
  cat <<'EOF'
Usage:
  # simplest (environment variables):
  ALIGN_DIR="path/to/locus_alignments" \
  OUTGROUP_FILE="path/to/outgroup.txt" \
  MOTU_MAP="path/to/motu_map.txt" \
  ASTRAL_JAR="path/to/astral.jar" \
  ASTRAL_LIB_DIR="path/to/astral_lib" \
  ./uce_astral_gcf_phyparts_pipeline.sh

Recommended for gCF + sCF:
  SCF_QUARTETS=100 \
  ALIGN_DIR="path/to/locus_alignments" \
  OUTGROUP_FILE="outgroup.txt" \
  MOTU_MAP="motu_map.txt" \
  ASTRAL_JAR="astral.jar" \
  ASTRAL_LIB_DIR="astral_lib" \
  ./uce_astral_gcf_phyparts_pipeline.sh

Outputs:
  results/<RUN_ID>/
    gene_trees_raw/
    gene_trees_rooted/
    astral/
    cf/                  (gCF/sCF outputs)
    phyparts/
    figures/
    logs/

Required inputs (set these env vars):
  ALIGN_DIR         Directory containing per-locus alignments (FASTA/PHYLIP/etc.)
  OUTGROUP_FILE     Text file listing outgroup taxon/taxa (one per line)
  MOTU_MAP          Mapping file: MOTU: sample1, sample2, sample3 ...
  ASTRAL_JAR        Path to ASTRAL jar
  ASTRAL_LIB_DIR    Path to ASTRAL lib directory (for classpath deps)

Optional inputs:
  LABELS_FILE       CSV used by phyloscripts piecharts (--taxon_subst)

Helper scripts (paths are configurable):
  REROOT_TREES_PY   reroot_trees.py
  REROOT_SINGLE_PY  reroot_single.py
  SVG2PDF_PY        svg2pdf.py

EOF
}

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
  usage
  exit 0
fi

# ----------------------------- Locate script dir -----------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------- Config (I/O stubs) ----------------------------
# REQUIRED INPUTS: default to empty => must be provided by the user.
ALIGN_DIR="${ALIGN_DIR:-""}"                 # e.g. data/uce_alignments/
ALIGN_PATTERN="${ALIGN_PATTERN:-"*.fasta"}"  # e.g. *.fasta, *.fa, *.fas
OUTGROUP_FILE="${OUTGROUP_FILE:-""}"         # e.g. config/outgroup.txt
MOTU_MAP="${MOTU_MAP:-""}"                   # e.g. config/motu_map.txt
ASTRAL_JAR="${ASTRAL_JAR:-""}"               # e.g. tools/astral/astral.jar
ASTRAL_LIB_DIR="${ASTRAL_LIB_DIR:-""}"       # e.g. tools/astral/lib/

# Input (needed for the pie chart labeling step, if used)
LABELS_FILE="${LABELS_FILE:-""}"             # e.g. config/labels.csv

# Helper scripts
REROOT_TREES_PY="${REROOT_TREES_PY:-"$SCRIPT_DIR/scripts/reroot_trees.py"}"
REROOT_SINGLE_PY="${REROOT_SINGLE_PY:-"$SCRIPT_DIR/scripts/reroot_single.py"}"
SVG2PDF_PY="${SVG2PDF_PY:-"$SCRIPT_DIR/scripts/svg2pdf.py"}"

# Tools
IQTREE_BIN="${IQTREE_BIN:-"iqtree3"}"
JAVA_BIN="${JAVA_BIN:-"java"}"
PYTHON_BIN="${PYTHON_BIN:-"python3"}"
GIT_BIN="${GIT_BIN:-"git"}"

# Compute resources
THREADS="${THREADS:-"AUTO"}"     # IQ-TREE 3 manual uses -T AUTO
JAVA_XMX="${JAVA_XMX:-"8g"}"     # ASTRAL/PhyParts Java memory

# IQ-TREE settings (gene trees)
IQTREE_MODEL="${IQTREE_MODEL:-"MFP"}"
UFBoot="${UFBoot:-1000}"         # IQ-TREE 3: -B
ALRT="${ALRT:-1000}"
IQTREE_SAFE="${IQTREE_SAFE:-1}"  # 1=>--safe
KEEP_IDENT="${KEEP_IDENT:-1}"    # 1=>--keep-ident

# Concordance factors
# If SCF_QUARTETS > 0, compute sCF via likelihood using --scfl (recommended in docs).
SCF_QUARTETS="${SCF_QUARTETS:-0}"      # e.g. 100
CF_VERBOSE="${CF_VERBOSE:-1}"          # 1=>--cf-verbose
CF_SEED="${CF_SEED:-12345}"            # reproducible quartet sampling

# Run organization
RUN_ROOT="${RUN_ROOT:-"results"}"
RUN_ID="${RUN_ID:-"$(date +%Y%m%d_%H%M%S)"}"
RUN_DIR="$RUN_ROOT/$RUN_ID"

RAW_TREES_DIR="$RUN_DIR/gene_trees_raw"
ROOTED_TREES_DIR="$RUN_DIR/gene_trees_rooted"
ASTRAL_DIR="$RUN_DIR/astral"
CF_DIR="$RUN_DIR/cf"
PHYPARTS_OUT_DIR="$RUN_DIR/phyparts"
FIG_DIR="$RUN_DIR/figures"
LOG_DIR="$RUN_DIR/logs"

# Optional tool auto-fetch/build
FETCH_TOOLS="${FETCH_TOOLS:-0}"
TOOLS_DIR="${TOOLS_DIR:-"$RUN_DIR/tools"}"
PHYPARTS_DIR="$TOOLS_DIR/phyparts"
PHYLOSCRIPTS_DIR="$TOOLS_DIR/phyloscripts"
PHYPARTS_JAR="${PHYPARTS_JAR:-"$PHYPARTS_DIR/target/phyparts-0.0.1-SNAPSHOT-jar-with-dependencies.jar"}"
PYPARTSPIE="${PYPARTSPIE:-"$PHYLOSCRIPTS_DIR/phypartspiecharts/phypartspiecharts.py"}"
SVG_NAME="${SVG_NAME:-"phyparts_pies.svg"}"

mkdir -p "$RUN_DIR" "$RAW_TREES_DIR" "$ROOTED_TREES_DIR" \
         "$ASTRAL_DIR" "$CF_DIR" "$PHYPARTS_OUT_DIR" "$FIG_DIR" "$LOG_DIR"

# ----------------------------- Small helpers --------------------------------
die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency in PATH: $1"; }

stage_file() { echo "$RUN_DIR/.stage_$1.done"; }
stage_complete() { [[ -f "$(stage_file "$1")" ]]; }
mark_stage() { date -Iseconds >"$(stage_file "$1")"; }

# ----------------------------- Pre-flight checks -----------------------------
# Required inputs must be set
[[ -n "$ALIGN_DIR" ]]      || die "ALIGN_DIR is not set. See --help."
[[ -n "$OUTGROUP_FILE" ]]  || die "OUTGROUP_FILE is not set. See --help."
[[ -n "$MOTU_MAP" ]]       || die "MOTU_MAP is not set. See --help."
[[ -n "$ASTRAL_JAR" ]]     || die "ASTRAL_JAR is not set. See --help."
[[ -n "$ASTRAL_LIB_DIR" ]] || die "ASTRAL_LIB_DIR is not set. See --help."

# Tools available?
need "$IQTREE_BIN"
need "$JAVA_BIN"
need "$PYTHON_BIN"
need "$GIT_BIN"

# Input existence
[[ -d "$ALIGN_DIR" ]]     || die "Alignment directory not found: $ALIGN_DIR"
[[ -s "$OUTGROUP_FILE" ]] || die "Outgroup file missing/empty: $OUTGROUP_FILE"
[[ -s "$MOTU_MAP" ]]      || die "MOTU map missing/empty: $MOTU_MAP"
[[ -s "$ASTRAL_JAR" ]]    || die "ASTRAL jar missing/empty: $ASTRAL_JAR"
[[ -d "$ASTRAL_LIB_DIR" ]] || echo "WARNING: ASTRAL_LIB_DIR not found: $ASTRAL_LIB_DIR (classpath may fail)" >&2

# Helper scripts existence
[[ -s "$REROOT_TREES_PY" ]]  || die "Missing reroot helper: $REROOT_TREES_PY"
[[ -s "$REROOT_SINGLE_PY" ]] || die "Missing reroot helper: $REROOT_SINGLE_PY"

# Optional: for piechart/pdf extras
if [[ ! -s "$SVG2PDF_PY" ]]; then
  echo "WARNING: svg2pdf helper not found at $SVG2PDF_PY (PDF rendering may be skipped)" >&2
fi

# Record provenance
PROV="$RUN_DIR/run_provenance.txt"
{
  echo "date: $(date -Is)"
  echo "cwd:  $(pwd)"
  echo "host: $(hostname 2>/dev/null || echo NA)"
  echo "iqtree: $($IQTREE_BIN --version 2>&1 | head -n 1 || true)"
  echo "java:   $($JAVA_BIN -version 2>&1 | head -n 1 || true)"
  echo "python: $($PYTHON_BIN --version 2>&1 || true)"
  echo "ALIGN_DIR=$ALIGN_DIR"
  echo "ALIGN_PATTERN=$ALIGN_PATTERN"
  echo "OUTGROUP_FILE=$OUTGROUP_FILE"
  echo "MOTU_MAP=$MOTU_MAP"
  echo "ASTRAL_JAR=$ASTRAL_JAR"
  echo "ASTRAL_LIB_DIR=$ASTRAL_LIB_DIR"
  echo "THREADS=$THREADS"
  echo "IQTREE_MODEL=$IQTREE_MODEL"
  echo "UFBoot=$UFBoot"
  echo "ALRT=$ALRT"
  echo "SCF_QUARTETS=$SCF_QUARTETS"
} > "$PROV"

# =============================================================================
# Step 1: ML gene trees (per locus)
# =============================================================================
ALN_LIST="$RUN_DIR/alignments.lst"
find "$ALIGN_DIR" -maxdepth 1 -type f -name "$ALIGN_PATTERN" | sort > "$ALN_LIST"
ALN_COUNT="$(wc -l < "$ALN_LIST" | tr -d ' ')"
[[ "$ALN_COUNT" -ge 1 ]] || die "No alignments matched: dir=$ALIGN_DIR pattern=$ALIGN_PATTERN"

if stage_complete gene_trees; then
  echo "[1/6] Gene trees (IQ-TREE 3)... skip (stage complete)"
else
  echo "[1/6] Gene trees (IQ-TREE 3) on $ALN_COUNT loci..."
  GENE_LOG="$LOG_DIR/iqtree_gene_trees.log"
  : >"$GENE_LOG"

  while IFS= read -r aln; do
    stem="$(basename "$aln")"
    stem="${stem%.*}"  # remove extension
    prefix="$RAW_TREES_DIR/$stem"

    if [[ -s "$prefix.treefile" ]]; then
      echo "skip existing: $stem" >>"$GENE_LOG"
      continue
    fi

    # Build IQ-TREE options cleanly
    opts=( -s "$aln"
           -m "$IQTREE_MODEL"
           -B "$UFBoot"
           --alrt "$ALRT"
           -T "$THREADS"
           --prefix "$prefix" )

    [[ "$IQTREE_SAFE" -eq 1 ]]  && opts+=( --safe )
    [[ "$KEEP_IDENT" -eq 1 ]]   && opts+=( --keep-ident )

    # Run
    echo "running: $stem" >>"$GENE_LOG"
    "$IQTREE_BIN" "${opts[@]}" >>"$GENE_LOG" 2>&1
  done < "$ALN_LIST"

  ls "$RAW_TREES_DIR"/*.treefile 2>/dev/null | sort > "$RAW_TREES_DIR/trees.lst" || true
  TREE_COUNT="$(wc -l < "$RAW_TREES_DIR/trees.lst" | tr -d ' ' || echo 0)"
  [[ "$TREE_COUNT" -ge 1 ]] || die "No gene trees produced in $RAW_TREES_DIR"

  mark_stage gene_trees
fi

ls "$RAW_TREES_DIR"/*.treefile 2>/dev/null | sort > "$RAW_TREES_DIR/trees.lst" || true
TREE_COUNT="$(wc -l < "$RAW_TREES_DIR/trees.lst" | tr -d ' ' || echo 0)"
[[ "$TREE_COUNT" -ge 1 ]] || die "No gene trees produced (post-check)"

# =============================================================================
# Step 2: Reroot gene trees
# =============================================================================
if stage_complete reroot_gene_trees; then
  echo "[2/6] Reroot gene trees... skip (stage complete)"
else
  echo "[2/6] Reroot gene trees..."
  REROOT_LOG="$LOG_DIR/reroot_gene_trees.log"
  : >"$REROOT_LOG"

  "$PYTHON_BIN" "$REROOT_TREES_PY" \
    "$OUTGROUP_FILE" \
    "$RAW_TREES_DIR/trees.lst" \
    "$ROOTED_TREES_DIR" \
    "$REROOT_LOG" || {
      echo "----- reroot log -----" >&2
      cat "$REROOT_LOG" >&2 || true
      die "Rerooting step failed"
    }

  mark_stage reroot_gene_trees
fi

find "$ROOTED_TREES_DIR" -maxdepth 1 -type f \( -name "*.treefile" -o -name "*.tre" \) | sort > "$ROOTED_TREES_DIR/trees_rooted.lst"
ROOTED_COUNT="$(wc -l < "$ROOTED_TREES_DIR/trees_rooted.lst" | tr -d ' ')"
[[ "$ROOTED_COUNT" -ge 1 ]] || die "No rooted trees found in $ROOTED_TREES_DIR"

# =============================================================================
# Step 3: ASTRAL species tree
# =============================================================================
ASTRAL_IN="$ASTRAL_DIR/all_genes.concatenated.tre"
ASTRAL_TREE="$ASTRAL_DIR/species_tree.tre"
ASTRAL_MAP="$ASTRAL_DIR/motu_map.filtered"
ASTRAL_LOG="$LOG_DIR/astral.log"

if stage_complete astral; then
  echo "[3/6] ASTRAL... skip (stage complete)"
else
  echo "[3/6] ASTRAL species tree..."

  # Concatenate rooted gene trees into one file (one Newick per line, ended by ;)
  : >"$ASTRAL_IN"
  while IFS= read -r treefile; do
    sed 's/;*$//;s/$/;/' "$treefile" >>"$ASTRAL_IN"
    echo >>"$ASTRAL_IN"
  done < "$ROOTED_TREES_DIR/trees_rooted.lst"

  # Filter MOTU map to taxa present in gene trees (prevents ASTRAL mapping failures)
  "$PYTHON_BIN" - "$ASTRAL_IN" "$MOTU_MAP" "$ASTRAL_MAP" <<'PY'
import re, sys
tree_path, map_path, out_path = sys.argv[1:]
taxa = set(re.findall(r"[^\s,:();]+", open(tree_path).read()))
out = []
for line in open(map_path):
    line = line.strip()
    if not line or line.startswith("#") or ":" not in line:
        continue
    species, samples = line.split(":", 1)
    kept = []
    for raw in samples.split(","):
        s = raw.strip()
        if not s:
            continue
        simple = s.split("_", 1)[0]
        if s in taxa:
            kept.append(s)
        elif simple in taxa:
            kept.append(simple)
    if kept:
        out.append(f"{species.strip()}: {', '.join(kept)}\n")
open(out_path, "w").writelines(out)
PY

  [[ -s "$ASTRAL_MAP" ]] || die "Filtered MOTU map is empty: $ASTRAL_MAP (check MOTU_MAP formatting vs taxa names)"

  : >"$ASTRAL_LOG"
  echo "Running ASTRAL..." | tee -a "$ASTRAL_LOG"

  "$JAVA_BIN" -Xmx"$JAVA_XMX" -cp "$ASTRAL_JAR:$ASTRAL_LIB_DIR/*" phylonet.coalescent.CommandLine \
    -i "$ASTRAL_IN" \
    -o "$ASTRAL_TREE" \
    -a "$ASTRAL_MAP" >>"$ASTRAL_LOG" 2>&1

  [[ -s "$ASTRAL_TREE" ]] || die "ASTRAL output missing/empty: $ASTRAL_TREE"

  mark_stage astral
fi

# =============================================================================
# Step 4: Reroot species tree
# =============================================================================
SPECIES_ROOTED="$ASTRAL_DIR/species_tree_rooted.tre"

if stage_complete reroot_species_tree; then
  echo "[4/6] Reroot species tree... skip (stage complete)"
else
  echo "[4/6] Reroot species tree..."
  "$PYTHON_BIN" "$REROOT_SINGLE_PY" \
    "$OUTGROUP_FILE" \
    "$ASTRAL_TREE" \
    "$SPECIES_ROOTED" || die "Could not reroot species tree"
  mark_stage reroot_species_tree
fi

[[ -s "$SPECIES_ROOTED" ]] || die "Rooted species tree missing/empty: $SPECIES_ROOTED"

# =============================================================================
# Step 5: IQ-TREE concordance factors (gCF + sCF)
# =============================================================================
CF_LOG="$LOG_DIR/iqtree_cf.log"
GCF_MAPPED="$CF_DIR/gene_trees_motu.tre"

if stage_complete cf; then
  echo "[5/6] Concordance factors... skip (stage complete)"
else
  echo "[5/6] Concordance factors (gCF${SCF_QUARTETS:+ + sCF})..."
  : >"$CF_LOG"

  # Map gene-tree tips to MOTUs (species) and strip internal node labels.
  # Requires ete3 inside python environment.
  "$PYTHON_BIN" - "$ROOTED_TREES_DIR/trees_rooted.lst" "$ASTRAL_MAP" "$ASTRAL_TREE" "$GCF_MAPPED" <<'PY'
import sys, re
from ete3 import Tree

list_path, map_path, species_tree_path, out_path = sys.argv[1:]

# Allowed taxa come from the species tree (ensures consistency)
species_newick = open(species_tree_path).read()
ALLOWED = set(re.findall(r"[^\s,:();]+", species_newick))

# Build sample->species map (allow exact and prefix before underscore)
label_map = {}
for line in open(map_path):
    if ":" not in line:
        continue
    sp, rest = line.split(":", 1)
    sp = sp.strip()
    for tok in rest.split(","):
        s = tok.strip()
        if not s:
            continue
        label_map[s] = sp
        label_map[s.split("_", 1)[0]] = sp

def clean_newick(nw: str) -> str:
    nw = nw.strip()
    if not nw:
        return ""
    if not nw.endswith(";"):
        nw += ";"
    # remove internal node labels after ')'
    nw = re.sub(r"\)\s*([^,():;]+)", ")", nw)
    nw = re.sub(r"\[.*?\]", "", nw)
    nw = re.sub(r"\s+", "", nw)
    return nw

mapped = []
for tree_path in open(list_path):
    tree_path = tree_path.strip()
    if not tree_path:
        continue
    nw = clean_newick(open(tree_path).read())
    if not nw:
        continue
    # parse (format fallback)
    try:
        t = Tree(nw, format=1)
    except Exception:
        t = Tree(nw, format=0)

    seen = set()
    for leaf in list(t):
        name = getattr(leaf, "name", "") or ""
        name = name.strip()
        if not name or name == "NoName":
            leaf.detach()
            continue
        sp = label_map.get(name) or label_map.get(name.split("_", 1)[0])
        if sp is None:
            leaf.detach()
            continue
        if sp in seen:
            leaf.detach()
            continue
        leaf.name = sp
        seen.add(sp)

    # collapse unifurcations after pruning
    changed = True
    while changed:
        changed = False
        for n in list(t.traverse("postorder")):
            if (not n.is_leaf()) and len(n.children) == 1:
                child = n.children[0]
                try:
                    child.dist += getattr(n, "dist", 0.0) or 0.0
                except Exception:
                    pass
                if n.up is None:
                    child.up = None
                    t = child
                    changed = True
                    break
                else:
                    try:
                        n.delete()
                    except Exception:
                        parent = n.up
                        child.up = parent
                        try:
                            parent.children.remove(n)
                        except Exception:
                            pass
                        parent.add_child(child)
                    changed = True

    if len(t.get_leaves()) < 3:
        continue
    leaf_names = {lf.name for lf in t.iter_leaves()}
    if not leaf_names or any((not x or x not in ALLOWED) for x in leaf_names):
        continue

    nw_out = t.write(format=9).strip(";") + ";"
    if "()" in nw_out or "(:"
 in nw_out or ",:" in nw_out:
        continue
    try:
        _ = Tree(nw_out, format=1)
    except Exception:
        continue
    mapped.append(nw_out)

open(out_path, "w").write("\n".join(mapped))
PY

  [[ -s "$GCF_MAPPED" ]] || die "No mapped gene trees produced for CF: $GCF_MAPPED"

  # Build IQ-TREE CF command
  cf_cmd=( "$IQTREE_BIN"
           -t "$ASTRAL_TREE"
           --gcf "$GCF_MAPPED"
           --prefix "$CF_DIR/cf"
           -T "$THREADS"
           -seed "$CF_SEED" )

  [[ "$CF_VERBOSE" -eq 1 ]] && cf_cmd+=( --cf-verbose )

  # sCF via likelihood: requires alignments provided (directory)
  # IQ-TREE 3 manual shows: --scfl <N> with -p <ALN_DIR> for per-locus alignments.
  if [[ "$SCF_QUARTETS" -gt 0 ]]; then
    cf_cmd+=( --scfl "$SCF_QUARTETS" -p "$ALIGN_DIR" )
  fi

  echo "Running: ${cf_cmd[*]}" >>"$CF_LOG"
  "${cf_cmd[@]}" >>"$CF_LOG" 2>&1

  mark_stage cf
fi

# =============================================================================
# Step 6: PhyParts + pie charts
# =============================================================================
PHY_LOG="$LOG_DIR/phyparts.log"

if stage_complete phyparts; then
  echo "[6/6] PhyParts + pies... skip (stage complete)"
else
  echo "[6/6] PhyParts + pies..."
  : >"$PHY_LOG"

  if [[ ! -s "$PHYPARTS_JAR" || ! -s "$PYPARTSPIE" ]]; then
    if [[ "$FETCH_TOOLS" -eq 1 ]]; then
      mkdir -p "$TOOLS_DIR"

      if [[ ! -d "$PHYPARTS_DIR" ]]; then
        echo "[tools] Cloning/building PhyParts..." | tee -a "$PHY_LOG"
        "$GIT_BIN" clone --depth 1 https://bitbucket.org/blackrim/phyparts.git "$PHYPARTS_DIR" >>"$PHY_LOG" 2>&1
        (cd "$PHYPARTS_DIR" && ./mvn_cmdline.sh) >>"$PHY_LOG" 2>&1
      fi

      if [[ ! -d "$PHYLOSCRIPTS_DIR" ]]; then
        echo "[tools] Cloning phyloscripts..." | tee -a "$PHY_LOG"
        "$GIT_BIN" clone --depth 1 https://github.com/mossmatters/phyloscripts "$PHYLOSCRIPTS_DIR" >>"$PHY_LOG" 2>&1
      fi
    else
      echo "WARNING: PhyParts/phyloscripts not found and FETCH_TOOLS=0." | tee -a "$PHY_LOG"
      echo "         Set PHYPARTS_JAR and PYPARTSPIE, or run with FETCH_TOOLS=1 to auto-fetch." | tee -a "$PHY_LOG"
      mark_stage phyparts
      goto_summary=1
    fi
  fi

  if [[ "${goto_summary:-0}" -ne 1 ]]; then
    [[ -s "$PHYPARTS_JAR" ]] || die "PhyParts jar still missing: $PHYPARTS_JAR"
    [[ -s "$PYPARTSPIE" ]]   || die "Piechart script still missing: $PYPARTSPIE"

    echo "[phyparts] Running..." | tee -a "$PHY_LOG"
    "$JAVA_BIN" -Xmx"$JAVA_XMX" -jar "$PHYPARTS_JAR" \
      -a 1 \
      -d "$ROOTED_TREES_DIR" \
      -m "$SPECIES_ROOTED" \
      -o "$PHYPARTS_OUT_DIR/output_1phyparts" \
      -b 33 \
      -v >>"$PHY_LOG" 2>&1

    if [[ -n "$LABELS_FILE" && -s "$LABELS_FILE" ]]; then
      echo "[pies] Generating SVG (with labels.csv)..." | tee -a "$PHY_LOG"
      if ! "$PYTHON_BIN" "$PYPARTSPIE" \
        --svg_name "$SVG_NAME" \
        --taxon_subst "$LABELS_FILE" \
        "$SPECIES_ROOTED" \
        "$PHYPARTS_OUT_DIR/output_1phyparts" \
        "$ROOTED_COUNT" >>"$PHY_LOG" 2>&1; then
        echo "WARNING: Pie chart SVG generation failed (likely ete3 TreeStyle backend)." | tee -a "$PHY_LOG"
      fi
    else
      echo "NOTE: LABELS_FILE not provided; generating pies without taxon substitution is skipped here." | tee -a "$PHY_LOG"
      echo "      Set LABELS_FILE=<path/to/labels.csv> for labeled pies." | tee -a "$PHY_LOG"
    fi

    # Render PDF if SVG exists and svg2pdf helper exists
    if [[ -s "$PHYPARTS_OUT_DIR/$SVG_NAME" && -s "$SVG2PDF_PY" ]]; then
      echo "[pies] Rendering PDF..." | tee -a "$PHY_LOG"
      "$PYTHON_BIN" "$SVG2PDF_PY" "$PHYPARTS_OUT_DIR/$SVG_NAME" "$FIG_DIR/phyparts_pies.pdf" 2400 \
        >>"$PHY_LOG" 2>&1 || echo "WARNING: PDF render failed; see logs." | tee -a "$PHY_LOG"
    fi

    mark_stage phyparts
  fi
fi

# =============================================================================
# Summary
# =============================================================================
cat <<EOF
Run complete: $RUN_DIR
  Alignments found:        $ALN_COUNT
  Gene trees produced:     $TREE_COUNT
  Rooted gene trees:       $ROOTED_COUNT

  ASTRAL species tree:     $ASTRAL_TREE
  Rooted species tree:     $SPECIES_ROOTED

  Concordance factors:
    Tree:                  $CF_DIR/cf.cf.tree
    Stats:                 $CF_DIR/cf.cf.stat

  PhyParts output (if run): $PHYPARTS_OUT_DIR/output_1phyparts
  Pies SVG (if made):       $PHYPARTS_OUT_DIR/$SVG_NAME
  Pies PDF (if made):       $FIG_DIR/phyparts_pies.pdf

Logs:
  $LOG_DIR
EOF