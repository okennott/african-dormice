# 01 — Phylogenetic Inference

This directory contains scripts and configuration for maximum-likelihood (ML) and Bayesian phylogenetic inference using both the cytochrome B (CYTB) mitochondrial marker and ultraconserved elements (UCE).

## Subdirectories

| Directory | Dataset | Methods |
|---|---|---|
| `01_CYTB/` | Cytochrome B | IQ-TREE2 (ML), BEAST2 (Bayesian) |
| `02_UCE/` | Ultraconserved elements | IQ-TREE2 gene trees → ASTRAL species tree + PhyParts discordance |

## Datasets

- **CYTB full** — 341 sequences covering all sampled *Graphiurus* spp. and outgroups (`data/CYTB/CYTB_full_NT_N341.fas`)
- **CYTB thinned** — 130 sequences, subsampled for computational efficiency (`data/CYTB/CYTB_thinned_NT_N130.fas`)
- **UCE** — 1,155 loci at ≥95% taxon coverage with ≥10% parsimony-informative sites (PIC); aligned, trimmed, and cleaned via `phyluce`

## Recommended Execution Order

1. Run CYTB ML tree (`01_CYTB/ML_IQTREE/`)
2. Run CYTB Bayesian inference (`01_CYTB/BI_beast/`)
3. Run UCE gene trees and ASTRAL species tree (`02_UCE/`)
4. Use output trees as input to `../../02_divergence_dating/`
