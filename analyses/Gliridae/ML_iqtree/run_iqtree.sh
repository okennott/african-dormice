#!/usr/bin/env bash
set -euo pipefail

# --- INPUTS ---------------------------------------------------------------
aln="aln.fas"                   #  alignment
base=$(basename "$aln" .fas)
outgroups="outSimosciurusnebouxii_NC050023_SciuridaeSciurinae"              

# Control total CPU use when launching 4 jobs in parallel:
# Each job gets ~1/4 of available cores (min 1).
cores_total=$(nproc || echo 4)
cores_each=$(( cores_total / 4 )); [[ $cores_each -lt 1 ]] && cores_each=1

# --- OUTPUT LAYOUT --------------------------------------------------------
mkdir -p _u_run_/{ML,QC}

# --- CODON PARTITION FILE (1st/2nd/3rd positions) -------------------------
# IQ-TREE accepts both RAxML-style and NEXUS partitions. This is RAxML-style.
cat > _u_run_/codon.partitions <<'PARTS'
DNA, c1 = 1-1140\3
DNA, c2 = 2-1140\3
DNA, c3 = 3-1140\3
PARTS
# (1-3\3, 2-3\3, 3-3\3 pattern is the standard codon-position split.)

# --- OPTIONAL DATA QC (matched-pairs symmetry tests) ----------------------
# Writes *.symtest.csv and exits. Useful to inspect compositional heterogeneity.
iqtree3 -s "$aln" --symtest-only -pre "_u_run_/QC/${base}"

# --- COMMON OPTIONS -------------------------------------------------------
common="-s $aln -bb 5000 -bnni -alrt 1000 -allnni -seed 12345 -safe -redo --prefix"

# Partitioned model: let ModelFinder search per-partition models and merge if warranted.
# Use edge-proportional branch lengths (-spp) so codon positions can have different rates.
part_model="-p _u_run_/codon.partitions -m MFP+MERGE"

# Unpartitioned model: standard ModelFinder over the whole gene.
unpart_model="-m MFP"

# --- FOUR PARALLEL RUNS ---------------------------------------------------
# 1) Partitioned + Outgroup
iqtree3 $common "_u_run_/${base}.part_out" $part_model -o "$outgroups" -nt $cores_each &

# 2) Partitioned + No Outgroup (unrooted output)
iqtree3 $common "_u_run_/${base}.part_nout"  $part_model -nt $cores_each &

# 3) Unpartitioned + Outgroup
iqtree3 $common "_u_run_/${base}.unpart_out" $unpart_model -o "$outgroups" -nt $cores_each &

# 4) Unpartitioned + No Outgroup
iqtree3 $common "_u_run_/${base}.unpart_nout" $unpart_model -nt $cores_each &

wait
echo "All four IQ-TREE runs finished. See _u_run_/"
