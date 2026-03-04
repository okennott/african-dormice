# scripts/utility-scripts — Data Manipulation Utilities

General-purpose Python and R utilities for sequence file manipulation, renaming, and subsampling. These tools are called from multiple analysis pipelines and are designed to be run standalone from the command line.

## Python Scripts

### `rename_MSA_sequences.py`

Recursively renames sequence headers in alignment files using a tab-separated mapping file.

**Supported formats:** FASTA, PHYLIP (strict classical), NEXUS
**Dependency:** Biopython ≥ 1.80

```bash
python rename_MSA_sequences.py \
  --input  alignments/ \
  --map    renaming_map.txt \
  --format fasta \
  --inplace           # edit files in place (omit to write copies)
```

Mapping file format (`renaming_map.txt`):
```
old_name_1 - new_name_1
old_name_2 - new_name_2
```

---

### `rename_sequences_across_MSAs.py`

Batch version of the above — renames sequences consistently across a directory of multiple alignment files. Useful after taxon-name standardization.

```bash
python rename_sequences_across_MSAs.py \
  --dir alignments/ \
  --map renaming_map.txt \
  --ext fasta
```

---

### `randomly_subsample_MSAs.py`

Randomly samples a fixed number of sequences from one or more alignment files. Supports a reproducibility seed.

```bash
python randomly_subsample_MSAs.py \
  --input  alignments/ \
  --n      50 \
  --seed   42 \
  --output subsampled/
```

---

### `rename_treetip_labels.py`

Renames tip labels in Newick-format phylogenetic tree files using a mapping file. Useful for producing publication-ready tree figures with full taxon names.

```bash
python rename_treetip_labels.py \
  --tree  input.nwk \
  --map   renaming_map.txt \
  --output renamed.nwk
```

---

## R Scripts

### `00_colors.R`

Defines the standard color palette used across all manuscript figures. Source at the top of any plotting script to ensure consistent styling:

```r
source("scripts/utility-scripts/00_colors.R")
# Exposes: MOTU_COLORS, CLADE_COLORS, REGION_COLORS, etc.
```
