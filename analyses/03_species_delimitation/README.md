# 03 — Species Delimitation

Automated species delimitation of *Graphiurus* using four complementary methods applied to the CYTB dataset. The study recovered 24 molecular operational taxonomic units (MOTUs) across two major clades (West African and pan-sub-Saharan).

## Methods

| Method | Tool | Basis | Reference |
|---|---|---|---|
| ASAP | [asap-web](https://bioinfo.mnhn.fr/abi/public/asap/) | Barcode gap + model-based | Puillandre et al. 2021 |
| BCUT | BCUT | Bootstrap congruence units | – |
| mPTP | [mPTP](https://github.com/Pas-Kapli/mptp) | Poisson tree processes (ML) | Kapli et al. 2017 |
| GMYC | ape / GMYC (R) | Yule / coalescent threshold | Pons et al. 2006 |

All methods were applied to a rooted CYTB ML tree. Results were compared and a consensus of 24 MOTUs was used in downstream analyses.

## Directory Structure

```
03_species_delimitation/
├── ASAP/
│   ├── Full.fas                          # Full CYTB alignment input
│   ├── Full.Partition_1.txt (×20)        # 20 alternative ASAP partitions
│   ├── Full.Partition_1.csv (×20)        # Corresponding CSV tables
│   └── asap.log                          # ASAP run log
├── BCUT/
│   ├── bcut.R                            # Main branch-cutting analysis script
│   └── branchcutting.R                   # Utility functions for branch cutting
├── GMYC/
│   └── gmyc.R                            # GMYC analysis (splits R package)
└── mPTP/
    ├── run_mptp_ml.sh                    # mPTP ML delimitation
    └── run_mptp_mcmc.sh                  # mPTP MCMC delimitation
```

## Results Summary

ASAP generated 20 alternative partitions; the top-scoring partition and a consensus across all four methods support **24 MOTUs** forming two reciprocally monophyletic clades:
- **West African clade:** 3 MOTUs
- **Pan-sub-Saharan clade:** 21 MOTUs

## Running the Analyses

**ASAP** was run via the web interface at https://bioinfo.mnhn.fr/abi/public/asap/ using the K80 substitution model. Results are archived in `ASAP/`.

**BCUT:**
```r
source("BCUT/bcut.R")
```

**GMYC** (requires ultrametric BEAST tree and `splits` R package):
```r
source("GMYC/gmyc.R")
```

**mPTP** (requires rooted ML tree and mPTP binary):
```bash
bash mPTP/run_mptp_ml.sh    # ML delimitation
bash mPTP/run_mptp_mcmc.sh  # MCMC delimitation
```
