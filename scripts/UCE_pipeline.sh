#!/bin/bash
# UCE Phylogenomics Pipeline
# Requires: phyluce, mafft, gblocks, iqtree
# Input: 
#   - Assembled contigs in 3_UCE_spades_assembly_contigs/
#   - UCE probe set: uce-5k-probes.fasta
#   - Taxon configuration: 5_taxon-set.conf
conda activate phyluce
set -euo pipefail  # Enable strict error checking
exec > >(tee -a pipeline.log) 2>&1  # Log all output

####################
# Configuration
####################
THREADS=12                   # Default CPU threads
FILTER_THREADS=16            # Threads for filtering steps
UCE_PROBES="uce-5k-probes.fasta"  # UCE probe file
TAXON_CONFIG="5_taxon-set.conf"   # Taxon configuration

####################
# Initialize Directories
####################
mkdir -p {logs,4_uce-search-results,5_taxon-set,6_sequence-alignment,7_concatenatedalignment,8_MLtrees}

echo "========================================"
echo "Starting UCE Pipeline | $(date)"
echo "========================================"

######################################
# 1: Assembly Quality Assessment
######################################
echo "STEP 1: Checking assembly quality..."
for i in 3_spades-assemblies-contigs/*.fasta; do
    echo "Processing ${i##*/}..."
    phyluce_assembly_get_fasta_lengths --input "$i" --csv >> logs/assembly_stats.csv
done
echo "Assembly stats saved to logs/assembly_stats.csv"

######################################
# 2: Match Contigs to UCE Probes
######################################
echo -e "\nSTEP 2: Matching contigs to UCE probes..."
phyluce_assembly_match_contigs_to_probes \
    --contigs 3_spades-assemblies-contigs \
    --probes "uce-5k-probes.fasta" \
    --output 4_uce-search-results \
    --log-path logs

######################################
# 3: Generate Match Counts
######################################
echo -e "\nSTEP 3: Generating UCE match counts..."
phyluce_assembly_get_match_counts \
    --locus-db 4_uce-search-results/probe.matches.sqlite \
    --taxon-list-config 5_taxon-set-conf/5_taxon-set.conf \
    --taxon-group 'all' \
    --incomplete-matrix \
    --output 5_taxon-set/5_match_counts.conf \
    --log-path logs

######################################
# 4: Extract UCE Loci FASTA
######################################
echo -e "\nSTEP 4: Extracting UCE loci sequences..."
phyluce_assembly_get_fastas_from_match_counts \
    --contigs 3_spades-assemblies-contigs \
    --locus-db 4_uce-search-results/probe.matches.sqlite \
    --match-count-output 5_taxon-set/5_match_counts.conf \
    --output 5_taxon-set/5_uce_loci.fasta \
    --incomplete-matrix 5_taxon-set/5_incomplete_matrix.txt \
    --log-path logs

######################################
# 5: Explode to Per-Taxon FASTA
######################################
echo -e "\nSTEP 5: Creating per-taxon FASTA files..."
phyluce_assembly_explode_get_fastas_file \
    --input 5_taxon-set/5_uce_loci.fasta \
    --output 5_taxon-set/5_exploded_fastas \
    --by-taxon

######################################
# 6: Multiple Sequence Alignment
######################################
echo -e "\nSTEP 6: Performing sequence alignment (MAFFT)..."
mkdir -p 6_seq-al
phyluce_align_seqcap_align \
    --fasta 5_taxon-set/5_uce_loci.fasta \
    --output 6_seq-al/6_seq_aligned \
	--output-format fasta \
    --taxa 59 \
    --aligner mafft \
    --cores 2 \
    --incomplete-matrix \
    --log-path logs

######################################
# 7: Alignment Quality Assessment
######################################
echo -e "\nSTEP 7: Generating alignment statistics..."
phyluce_align_get_align_summary_data \
    --alignments 6_seq-al/6_seq_aligned \
    --input-format fasta \
    --output-stats 6_seq-al/6_seq_aligned/alignment_summary.csv \
    --show-taxon-counts \
    --cores 2 \
    --log-path logs

######################################
# 8: Trim Alignments with Gblocks
######################################
echo -e "\nSTEP 8: Trimming alignments (Gblocks)..."
phyluce_align_get_gblocks_trimmed_alignments_from_untrimmed \
    --alignments 6_seq-al/6_seq_aligned \
    --output 6_seq-al/6_seq_aligned_trimmed \
    --cores 2 \
    --log-path logs

######################################
# 9: Clean Locus Names
######################################
echo -e "\nSTEP 9: Cleaning locus names..."
phyluce_align_remove_locus_name_from_nexus_lines \
    --alignments 6_seq-al/6_seq_aligned_trimmed \
    --output 6_seq-al/6_seq_aligned_trimmed_cleannames \
	--input-format nexus \
	--output-format fasta \
    --cores 2 \
    --log-path logs

######################################
# 10: Filter by Taxon Completeness
######################################
echo -e "\nSTEP 10: Filtering loci by taxon completeness..."
# Loop over the thresholds [percentages]
for percent in 50 70 80 90 95; do
    # Set the output directory dynamically based on the percentage
    phyluce_align_get_only_loci_with_min_taxa \
        --alignments 6_seq-al/6_seq_aligned_trimmed_cleannames \
		--input-format fasta \
        --taxa 59 \
        --percent 0.$percent \
        --output 6_seq-al/6_seq_aligned_trimmed_cleannames_${percent}p \
        --cores 2 \
        --log-path logs
done

######################################
# 11: Concatenate Alignments
######################################
echo -e "\nSTEP 11: Concatenating alignments..."
# Process filtered datasets
for percent in 0 50 70 80 90 95; do
    phyluce_align_concatenate_alignments \
        --alignments 6_seq-al/6_seq_aligned_trimmed_cleannames_${percent}p \
		--input-format fasta \
		--input-format fasta \
        --output 6_seq-al/6_seq_aligned_trimmed_cleannames_concat_${percent}p \
        --nexus \
        --log-path logs
done

# Process filtered datasets
for percent in 50 70 80 90 95; do
    phyluce_align_concatenate_alignments \
        --alignments 6_seq-al/6_seq_aligned_trimmed_cleannames_${percent}p \
		--input-format fasta \
        --output 6_seq-al/6_seq_aligned_trimmed_cleannames_concat_${percent}p_phy \
        --phylip \
        --log-path logs
done


# Process full dataset (100%)
phyluce_align_concatenate_alignments \
    --alignments 6_seq-al/6_seq_aligned_trimmed_cleannames \
	--input-format fasta \
    --output 6_seq-al/6_seq_aligned_trimmed_cleannames_concat_100p \
    --phylip \
    --log-path logs
	
phyluce_align_concatenate_alignments \
    --alignments 6_seq-al/6_seq_aligned_trimmed_cleannames \
	--input-format fasta \
    --output 6_seq-al/6_seq_aligned_trimmed_cleannames_concat_100p \
    --nexus \
    --log-path logs
######################################
# 12: Phylogenetic Inference
######################################
echo -e "\nSTEP 12: Building ML trees (IQ-TREE)..."
mkdir -p 7_MLtrees

# Build trees for filtered datasets
echo -e "\nSTEP 12: Building ML trees (IQ-TREE)..."
mkdir -p 7_MLtrees

# Build trees for filtered datasets
for percent in 50 70 80 90 95; do
    iqtree2 \
        -s 6_seq-al/6_seq_aligned_trimmed_cleannames_concat_${percent}p_phy/*.phylip \
        -m GTR+G \
        -B 1000 \
        -nt AUTO \
        -pre 7_MLtrees/6_seq_aligned_trimmed_cleannames_concat_${percent}p \
        -redo \
        -safe
done

# Build tree for full dataset
iqtree2 \
    -s "7_concatenatedalignment/full_dataset/full_dataset.phylip" \
    -m GTR+G \
    -bb 1000 \
    -nt "$THREADS" \
    -pre "8_MLtrees/full_dataset" \
    -redo \
    -safe

echo "========================================"
echo "Pipeline completed successfully! | $(date)"
echo "Results in 8_MLtrees/"
echo "========================================"