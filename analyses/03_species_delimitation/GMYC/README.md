# GMYC — Generalized Mixed Yule Coalescent

Species delimitation using the GMYC model applied to an ultrametric (time-calibrated) CYTB tree.

## Script

| Script | Description |
|---|---|
| `gmyc.R` | GMYC analysis using the `splits` R package |

## Method

GMYC fits a mixed model to a time-calibrated (ultrametric) phylogeny, detecting the transition from between-species (Yule) to within-species (coalescent) branching dynamics. Each cluster above the threshold is treated as a putative species.

Reference: Pons, J. et al. (2006). Sequence-Based Species Delimitation for the DNA Taxonomy of Undescribed Insects. *Systematic Biology*, 55(4), 595–609.

## Requirements

- `splits` R package (install from: `install.packages("splits")`)
- Ultrametric input tree (from BEAST2 divergence dating; see `../../02_divergence_dating/`)

## Usage

```r
# Install splits if needed
# install.packages("splits")

source("GMYC/gmyc.R")
```

Ensure the path to the ultrametric BEAST tree is set correctly in `gmyc.R` before running.
