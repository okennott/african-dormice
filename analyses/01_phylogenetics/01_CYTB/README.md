# 01_CYTB — Cytochrome B Phylogenetics

Phylogenetic inference from the mitochondrial cytochrome B (CYTB) gene across all sampled *Graphiurus* specimens and Gliridae outgroups.

## Datasets

| File | Sequences | Description |
|---|---|---|
| `data/CYTB/CYTB_full_NT_N341.fas` | 341 | Full dataset — all specimens and outgroups |
| `data/CYTB/CYTB_thinned_NT_N130.fas` | 130 | Thinned dataset — ≤95% pairwise similarity |
| `data/CYTB/CYTB_thinned_AA_N130.fas` | 130 | Amino acid translation of thinned dataset |

## Directory Structure

```
01_CYTB/
├── ML_IQTREE/        # Maximum-likelihood inference (IQ-TREE2)
│   ├── graphiurus_cytb_alignment_full.sh
│   └── graphiurus_cytb_alignment_reduced.sh
└── BI_beast/         # Bayesian inference (BEAST2)
    ├── graphiurus_cytb_alignment_full.xml
    └── graphiurus_cytb_alignment_reduced.xml
```

## ML Analysis (IQ-TREE2)

Scripts: `ML_IQTREE/graphiurus_cytb_alignment_full.sh` and `*_reduced.sh`

Key settings:
- Model selection: `-m MFP` (ModelFinder Plus)
- Bootstrap: `--ufboot 1000` (ultrafast bootstrap)
- Branch support: `--alrt 1000` (SH-like approximate likelihood ratio test)

```bash
# Run from the ML_IQTREE/ directory
bash graphiurus_cytb_alignment_full.sh
bash graphiurus_cytb_alignment_reduced.sh
```

## Bayesian Analysis (BEAST2)

XML configuration files in `BI_beast/` include embedded alignments, taxon sets, clock models, and tree priors. Run with BEAST v2.7.

```bash
beast BI_beast/graphiurus_cytb_alignment_full.xml
beast BI_beast/graphiurus_cytb_alignment_reduced.xml
```

## Outputs

Raw MCMC outputs (`.log`, `.trees`, `.ops`) are excluded by `.gitignore` but are fully reproducible. Final consensus trees should be summarized with TreeAnnotator after confirming convergence in Tracer (ESS > 200 for all parameters).
