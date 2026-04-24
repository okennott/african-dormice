# Data Documentation

This document describes the data files included in this repository, their origins, formats, and how they were generated.

---

## External Data Deposits

Raw sequence data (FASTQ reads and assembled FASTA contigs) generated in this study are deposited in:

- **NCBI GenBank / SRA:** Accession numbers PX513364–PX513453
- **Zenodo:** Processed alignments (CYTB and UCE), accepted manuscript, and supplementary materials — https://doi.org/10.5281/zenodo.17336599

Analysis scripts and processed data are also included directly in this repository (see below).

---

## Data Sources

### Sequence Data

| Dataset | Type | Coverage | Location in repo |
|---|---|---|---|
| CYTB | Mitochondrial gene (cytochrome B) | All *Graphiurus* spp. + outgroups | `data/CYTB/` |
| UCE | Ultraconserved elements (5k probe set) | Reduced taxon set | `data/UCE/` |

**UCE probe set:** Tetrapod UCE 5k probe set (Faircloth et al. 2012). Probe file: `uce-5k-probes.fasta`.

**UCE assemblies** were generated with SPAdes v3.x via the `phyluce` pipeline. Raw assemblies are in `data/UCE/UCE_spades_assembly_contigs/` (one FASTA per sample).

### Morphological / Trait Data

Morphological trait data were compiled from two primary sources:

| Source | Abbreviation | Reference |
|---|---|---|
| Mammal Diversity Database v2.3 | MDD | Mammal Diversity Database (2024). www.mammaldiversity.org |
| Handbook of the Mammals of the World, Vol. 6 | HMW | Wilson & Mittermeier (2016). Lynx Edicions, Barcelona |

The ETL pipeline (`analyses/05_morphology/etl_gliridae.py`) integrates these sources into normalized tables. Input CSVs:

- `MDD_v2.3_6836species_Gliridae.csv` — MDD extract filtered to Gliridae
- `hmw-volume-6-gliridae.csv` — HMW trait table for Gliridae

These input CSVs are **not redistributed** in this repository due to data licensing. Researchers wishing to reproduce the morphological analyses should obtain the source data directly from MDD and HMW and format them according to the column schemas described in the ETL script docstring.

---

## Repository Data Files

### `data/CYTB/`

Processed and aligned cytochrome B sequences.

| File pattern | Format | Description |
|---|---|---|
| `*.fasta` | FASTA | Aligned sequences (MAFFT or MUSCLE) |
| `*.nex` | NEXUS | Alignment with partition model for MrBayes |
| `*.phy` | PHYLIP | Alignment for IQ-TREE |

### `data/UCE/`

| File / Folder | Format | Description |
|---|---|---|
| `UCE_spades_assembly_contigs/` | FASTA | Per-sample SPAdes contig assemblies |
| `*.fasta` (in analysis subdirs) | FASTA | Aligned UCE loci (incomplete matrices) |

### `analyses/05_morphology/gliridae_taxonomy_db/`

| File | Format | Description |
|---|---|---|
| `gliridae.duckdb` | DuckDB | Integrated taxonomy + traits database |
| `renv.lock` | JSON | Exact R package versions for reproducibility |

### Controlled Vocabulary

`config/gliridae_controlled_vocabulary.yml` (if present) — standardized terms for habitat, diet, and activity pattern fields used in the morphological ETL pipeline.

---

## File Size Notes

Several files are large (>10 MB) due to the nature of UCE and phylogenetic data:

| Path | Approx. size | Notes |
|---|---|---|
| `data/UCE/UCE_spades_assembly_contigs/` | 11–17 MB per sample | SPAdes FASTA assemblies |
| `analyses/02_divergence_dating/UCE/` | ~12 MB | BEAST2 XML input |
| `manuscript/supplementary/` | ~272 MB | Figures and tables (PDF/XLSX) |

These files are tracked in the repository directly. If cloning is slow, consider using `git clone --depth 1` for a shallow clone.

---

## Reproducing the Analyses

The full analysis workflow proceeds in the order of the `analyses/` subdirectory numbering (01 → 06). See `README.md` for setup instructions and per-analysis guidance.

All intermediate outputs are reproducible from the input data and scripts. Output directories (trees, log files, etc.) are excluded from version control via `.gitignore`.
