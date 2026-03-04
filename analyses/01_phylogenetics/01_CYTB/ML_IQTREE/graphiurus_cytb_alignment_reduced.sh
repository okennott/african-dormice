#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# IQ-TREE 3 run script (Graphiurus CYTB - REDUNDANCY-FILTERED alignment)
#
# Usage:
#   chmod +x run_iqtree_graphiurus_cytb_red.sh
#   ./run_iqtree_graphiurus_cytb_red.sh                 # uses default input
#   ./run_iqtree_graphiurus_cytb_red.sh path/to/aln.fas # override input
#
# Optional environment overrides:
#   IQTREE_THREADS=AUTO|8
#   IQTREE_SEED=12345
#   IQTREE_BOOTSTRAPS=1000
#   IQTREE_ALRT=1000
#   IQTREE_NINIT=100
#   IQTREE_NSTOP=200
# -----------------------------------------------------------------------------

ALIGNMENT="${1:-graphiurus_cytb_red.fas}"
OUTGROUP="NC002369_Palearctic_Sciurinae"

OUTDIR="graphiurus_cytb_red"
PREFIX="${OUTDIR}/graphiurus_cytb_red"

THREADS="${IQTREE_THREADS:-AUTO}"
SEED="${IQTREE_SEED:-12345}"
BOOTSTRAPS="${IQTREE_BOOTSTRAPS:-1000}"
ALRT="${IQTREE_ALRT:-1000}"
NINIT="${IQTREE_NINIT:-100}"
NSTOP="${IQTREE_NSTOP:-200}"

if ! command -v iqtree3 >/dev/null 2>&1; then
  echo "ERROR: iqtree3 not found in PATH. Please install IQ-TREE 3 or load your module/env." >&2
  exit 127
fi

if [[ ! -s "$ALIGNMENT" ]]; then
  echo "ERROR: Alignment file not found or empty: $ALIGNMENT" >&2
  exit 2
fi

mkdir -p "$OUTDIR"

LOG="${PREFIX}.run.log"

{
  echo "# ----------------------------------------------------------------------------"
  echo "# IQ-TREE 3 run log"
  echo "# Date:        $(date -Is)"
  echo "# Working dir: $(pwd)"
  echo "# Host:        $(hostname 2>/dev/null || echo "NA")"
  echo "# User:        $(whoami 2>/dev/null || echo "NA")"
  echo "# iqtree3:     $(iqtree3 --version 2>&1 | head -n 1 || echo "version unavailable")"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "# Alignment:   $ALIGNMENT"
    echo "# SHA256:      $(sha256sum "$ALIGNMENT" | awk '{print $1}')"
  else
    echo "# Alignment:   $ALIGNMENT (sha256sum not available)"
  fi
  echo "# ----------------------------------------------------------------------------"
  echo "# Command:"
  echo "iqtree3 \\"
  echo "  -s \"$ALIGNMENT\" \\"
  echo "  -o \"$OUTGROUP\" \\"
  echo "  -m MFP -mset GTR \\"
  echo "  -B \"$BOOTSTRAPS\" --bnni \\"
  echo "  -alrt \"$ALRT\" \\"
  echo "  --ninit \"$NINIT\" --nstop \"$NSTOP\" \\"
  echo "  -T \"$THREADS\" \\"
  echo "  --seed \"$SEED\" \\"
  echo "  --prefix \"$PREFIX\" \\"
  echo "  --redo"
  echo "# ----------------------------------------------------------------------------"
} | tee "$LOG"

# NOTE: --redo will overwrite previous outputs sharing the same prefix.
iqtree3 \
  -s "$ALIGNMENT" \
  -o "$OUTGROUP" \
  -m MFP -mset GTR \
  -B "$BOOTSTRAPS" --bnni \
  -alrt "$ALRT" \
  --ninit "$NINIT" --nstop "$NSTOP" \
  -T "$THREADS" \
  --seed "$SEED" \
  --prefix "$PREFIX" \
  --redo \
  2>&1 | tee -a "$LOG"