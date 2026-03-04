# BCUT — Branch Cutting Species Delimitation

Species delimitation using a branch-cutting approach applied to the *Graphiurus* CYTB phylogeny.

## Scripts

| Script | Description |
|---|---|
| `bcut.R` | Main analysis — applies branch-cutting threshold to ML tree |
| `branchcutting.R` | Utility functions (branch length thresholding, clade extraction) |

## Method

Branch cutting delimits species by severing branches that exceed a threshold branch length in the ML phylogram, treating the resulting subtrees as putative species. The threshold is typically derived from bootstrap support distributions or user-defined heuristics.

## Usage

```r
# Run from the BCUT/ directory (or set working directory accordingly)
source("BCUT/bcut.R")
```

Ensure the input tree file path is correctly set at the top of `bcut.R` before running.
