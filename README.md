# African Dormice: Phylogenomics and Systematic Revision of *Graphiurus* (Gliridae)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Journal: MPE](https://img.shields.io/badge/Journal-Mol.%20Phylogenet.%20Evol.-blue)](https://doi.org/10.1016/j.ympev.2026.108549)

This repository contains all analysis scripts, configuration files, and processed data associated with the systematic revision and phylogenomic study of African Dormice (*Graphiurus*; family Gliridae), published in *Molecular Phylogenetics and Evolution* (2026).

> **Citation:** Onditi, K.O. et al. (2026). Diversification and biogeographic history of African dormice (genus *Graphiurus*) revealed by ultraconserved elements and mitochondrial data. *Molecular Phylogenetics and Evolution*, 217, 108549. https://doi.org/10.1016/j.ympev.2026.108549

---

## Repository Structure

```
african-dormice/
├── analyses/              # All analysis workflows
│   ├── 01_phylogenetics/  # CYTB and UCE phylogenetic inference
│   ├── 02_divergence_dating/ # BEAST2 and MCMCtree timetrees
│   ├── 03_species_delimitation/ # ASAP, BCUT, mPTP, GMYC
│   ├── 04_biogeography/   # BioGeoBEARS ancestral area reconstruction
│   ├── 05_morphology/     # Morphometric analysis and taxonomy database
│   ├── 06_genetic_diversity/ # Haplotype networks, DnaSP, popART
│   └── Gliridae/          # Family-level analyses
├── config/                # Path and tool configuration
│   ├── paths.yaml.example # Template — copy to paths.yaml and edit locally
│   └── directory_structure.yaml
├── data/                  # Processed sequence alignments and assemblies
│   ├── CYTB/              # Cytochrome B alignments
│   └── UCE/               # UCE assemblies and alignments
│   └── metadata.csv       # combined metadata file for all samples used in the study (CSV)
├── manuscript/            # Publication materials
│   ├── accepted/          # Accepted manuscript (PDF + DOCX)
│   ├── supplementary/     # Supplementary figures and tables
│   └── biblio/            # Bibliography files
└── scripts/               # Reusable utility scripts
    ├── morphology/        # R scripts for morphometric analysis
    ├── phylogenetics/     # Pipeline shell scripts
    └── utility-scripts/   # Sequence renaming and MSA utilities
```

---

## Requirements

### System Tools

The following external bioinformatics tools must be installed and available on your `PATH` (or configured in `config/paths.yaml`):

| Tool | Version | Purpose |
|---|---|---|
| [IQ-TREE2](http://www.iqtree.org/) | ≥ 2.2 | Maximum-likelihood phylogenetic inference |
| [BEAST2](https://www.beast2.org/) | ≥ 2.7 | Bayesian divergence dating |
| [MrBayes](https://nbisweden.github.io/MrBayes/) | ≥ 3.2 | Bayesian phylogenetic inference |
| [ASTRAL](https://github.com/smirarab/ASTRAL) | 5.7.8 | Coalescent-based species tree |
| [PhyParts](https://bitbucket.org/blackrim/phyparts) | – | Gene tree discordance |
| [phyluce](https://phyluce.readthedocs.io/) | ≥ 1.7 | UCE data processing (Conda) |
| [PAML/MCMCtree](http://abacus.gene.ucl.ac.uk/software/paml.html) | ≥ 4.9 | Relaxed-clock divergence dating |
| [AMAS](https://github.com/marekborowiec/AMAS) | – | Multiple sequence alignment stats |
| Java | ≥ 11 | Required by ASTRAL and PhyParts |
| Python | ≥ 3.9 | Utility scripts and ETL pipeline |
| R | ≥ 4.5 | Morphometric analysis |

### Python Dependencies

```bash
pip install -r requirements.txt
```

Key packages: `pandas`, `numpy`, `biopython`, `ete3`, `pyyaml`, `duckdb`, `cairosvg`, `openpyxl`.

### R Dependencies

The R environment is managed with [`renv`](https://rstudio.github.io/renv/). To restore the exact package versions used in the study:

```r
# In R, from the analyses/05_morphology/gliridae_taxonomy_db/ directory:
renv::restore()
```

Key packages: `tidyverse`, `MASS`, `vegan`, `cluster`, `dendextend`, `ggrepel`, `patchwork`.

---

## Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/okennott/african-dormice.git
   cd african-dormice
   ```

2. **Configure local paths:**
   ```bash
   cp config/paths.yaml.example config/paths.yaml
   ```
   Open `config/paths.yaml` and set the paths to your local data directory and any external tool locations not on your `PATH`.

3. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Install R dependencies** (from within the morphology project):
   ```bash
   Rscript -e "renv::restore()" --vanilla
   ```

5. **Install phyluce** (via Conda, required for UCE pipeline):
   ```bash
   conda create -n phyluce phyluce
   conda activate phyluce
   ```

---

## Analysis Workflows

### 1. Phylogenetic Inference

**Cytochrome B (CYTB):**
- Alignments: `data/CYTB/`
- Scripts: `analyses/01_phylogenetics/01_CYTB/`
- Run IQ-TREE2 and MrBayes for ML and Bayesian inference

**Ultraconserved Elements (UCE):**
- Assemblies: `data/UCE/UCE_spades_assembly_contigs/`
- Full pipeline: `scripts/UCE_pipeline.sh`
- ASTRAL + PhyParts: `analyses/01_phylogenetics/02_UCE/ASTRAL_n_PhyParts/run_pipeline.sh`

### 2. Divergence Dating

- BEAST2 XML files: `analyses/02_divergence_dating/`

### 3. Species Delimitation

- Scripts: `analyses/03_species_delimitation/`
- Methods: ASAP, bPTP (via web server), mPTP, GMYC

### 4. Biogeographic Reconstruction

- Scripts: `analyses/04_biogeography/`
- Tool: BioGeoBEARS (R package)

### 5. Morphometric Analysis

- ETL pipeline: `analyses/05_morphology/etl_gliridae.py`
  - Inputs: MDD and HMW trait data CSVs
  - Outputs: normalized tables (CSV/Parquet) + DuckDB database
- R analysis scripts: `scripts/morphology/`

### 6. Genetic Diversity

- Analyses: `analyses/06_genetic_diversity/`
- Tools: DnaSP, MEGA, popART

---

## Data

Raw sequence data (FASTQ reads and assembled contigs) are deposited in NCBI GenBank/SRA under accession numbers **PX513364–PX513453**. Processed alignments, the accepted manuscript, and supplementary materials are archived on Zenodo: https://doi.org/10.5281/zenodo.17336599. Analysis scripts and processed alignment files are also available in this repository under `data/`.

Morphological trait data are derived from:
- **MDD** — Mammal Diversity Database v2.3 (Wilson & Reeder; https://www.mammaldiversity.org/)
- **HMW** — Handbook of the Mammals of the World, Vol. 6 (Lynx Edicions)

See [DATA.md](DATA.md) for a full description of data files, formats, and provenance.

---

## Repository Validation

A CI workflow (`.github/workflows/validate_paths.yml`) runs on every push and pull request to check that no absolute local paths have been accidentally committed. To run the validation locally:

```bash
Rscript visualization/R/00_validate_setup.R
```

If it reports path issues, replace absolute paths with relative paths or `get_data_path()` / `get_repo_path()` helper calls, and ensure `config/paths.yaml` is **not** committed (it is gitignored by design).

---

## License

Code and scripts in this repository are released under the [MIT License](LICENSE) — Copyright (c) 2026 Onditi, Kenneth Otieno.

Sequence data and figures are subject to the terms of the associated publication. See the journal's open access and data policy for redistribution rights. See [DATA.md](DATA.md) for data provenance and reuse guidance.

---

## Contact

For questions about the analyses or data, please open a GitHub Issue or contact the corresponding author via the published paper.
