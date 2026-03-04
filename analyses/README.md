# Analyses

This directory contains all analysis workflows for the *Graphiurus* phylogenomics study, organized in the order of execution.

| Step | Directory | Method(s) | Input |
|---|---|---|---|
| 1 | `01_phylogenetics/` | IQ-TREE2, BEAST2, MrBayes, ASTRAL | `data/CYTB/`, `data/UCE/` |
| 2 | `02_divergence_dating/` | BEAST2 (relaxed clock) | Trees from step 1 |
| 3 | `03_species_delimitation/` | ASAP, BCUT, mPTP, GMYC | CYTB alignment + tree |
| 4 | `04_biogeography/` | BioGeoBEARS (R) | Dated tree from step 2 |
| 5 | `05_morphology/` | PCA, LDA, clustering (R + Python) | MDD / HMW trait data |
| 6 | `06_genetic_diversity/` | DnaSP, MEGA, popART | CYTB alignment |
| – | `Gliridae/` | IQ-TREE2, BEAST2, DnaSP | Family-level CYTB |

Each subdirectory contains its own `README.md` with dataset-specific instructions.
