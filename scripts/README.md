# Scripts

Reusable utility scripts shared across multiple analyses. Analysis-specific scripts (e.g., IQ-TREE shell scripts, BioGeoBEARS R scripts) live within their respective `analyses/` subdirectories; this folder contains tools that are called from multiple analyses or used for data preprocessing.

## Subdirectories

| Directory | Language | Purpose |
|---|---|---|
| `morphology/` | R | Statistical analysis of morphometric and trait data |
| `utility-scripts/` | Python | Sequence file manipulation (renaming, subsampling) |

## Top-Level Scripts

| Script | Description |
|---|---|
| `UCE_pipeline.sh` | Full UCE phylogenomics pipeline from SPAdes assemblies to aligned loci (requires `phyluce` conda environment) |

### `UCE_pipeline.sh`

End-to-end pipeline for UCE data processing:

1. Assembly quality assessment (per-sample FASTA statistics)
2. Match contigs to UCE probe set
3. Generate match count matrix
4. Extract UCE loci FASTA
5. Per-taxon FASTA explosion
6. MAFFT alignment
7. Edge trimming and Gblocks cleaning
8. Taxon name cleaning and renaming

**Requirements:** `phyluce` (conda), configured `taxon-set.conf` and UCE probe FASTA

```bash
conda activate phyluce
bash scripts/UCE_pipeline.sh
```
