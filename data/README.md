# Data

This directory contains version-controlled processed sequence data used as inputs to the phylogenetic analyses. Large raw files (FASTQ reads, assembly intermediates) are deposited externally — see [DATA.md](../DATA.md) for accession details.

## Contents

| Directory | Description | Key files |
|---|---|---|
| `CYTB/` | Aligned cytochrome B sequences | 341-taxon full set; 130-taxon thinned set |
| `UCE/` | Assembled and trimmed UCE loci | 4,452 cleaned alignments; SPAdes assemblies |

## Accession Numbers

Raw sequence data (FASTQ reads and assembled contigs) are deposited in NCBI GenBank/SRA under accession numbers **PX513364–PX513453**. Processed alignments, the accepted manuscript, and supplementary materials are archived on Zenodo at https://doi.org/10.5281/zenodo.17336599.

## Notes

- All alignment files in `CYTB/` were produced with MAFFT and are ready for direct use in IQ-TREE2, MrBayes, or BEAST2
- UCE alignments in `UCE/aligned_trimmed_cleannames_N4452/` are edge-trimmed and have clean taxon names compatible with all downstream scripts
- The `UCE/alignment_files.zip` archive (~149 MB) contains the same loci in compressed form for convenience
