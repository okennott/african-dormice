# mPTP — Multi-rate Poisson Tree Processes

Species delimitation using mPTP (multi-rate Poisson Tree Processes) in both maximum-likelihood (ML) and MCMC modes.

## Scripts

| Script | Mode | Description |
|---|---|---|
| `run_mptp_ml.sh` | ML | Fast ML species delimitation |
| `run_mptp_mcmc.sh` | MCMC | Bayesian species delimitation with uncertainty |

## Method

mPTP models speciation as a Poisson process, fitting separate rates for between-species (macroevolutionary) and within-species (population-level) branching events. It accommodates variation in within-species diversity across lineages.

Reference: Kapli, P. et al. (2017). Multi-rate Poisson tree processes for single-locus species delimitation under maximum likelihood and MCMC. *Bioinformatics*, 33(11), 1630–1638.

## Requirements

- mPTP binary: https://github.com/Pas-Kapli/mptp
- Rooted ML input tree

## Usage

Edit the tree file path and output settings at the top of each script, then:

```bash
# ML mode (fast)
bash mPTP/run_mptp_ml.sh

# MCMC mode (slower, provides credible intervals)
bash mPTP/run_mptp_mcmc.sh
```
