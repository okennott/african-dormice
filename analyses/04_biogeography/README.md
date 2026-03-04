# 04 — Biogeographic Reconstruction

Ancestral-area reconstruction across *Graphiurus* using BioGeoBEARS, testing six dispersal-extinction-cladogenesis (DEC) models. Analyses were run on both the CYTB and UCE time-calibrated trees. Results indicate a *Graphiurus* origin in the Upper Guinean rainforest, followed by jump dispersal across sub-Saharan Africa.

## Scripts

| Script | Dataset | Output directory |
|---|---|---|
| `run_biogeobears_cytb.R` | CYTB timetree | `Output_CYTB/` |
| `run_biogeobears_uce.R` | UCE timetree | `Output_UCE_fStates/newScript/` |

Both scripts are fully automated pipelines that load the phylogeny and geography matrix, fit all six models, and save results and figures.

## Geographic State Files

Two geographic coding schemes were used:

**Regional states** (10 areas, A–J):
- A: Ethiopian Highlands
- B: Somali-Maasai
- C: Upper Guinean Forest
- D: Congolian Forest
- E: East African Montane
- F: Southern Africa
- G: West African Savanna
- H: Central Africa
- I: Madagascar (outgroup)
- J: Palearctic (outgroup)

**Biome states** (8 biomes, A–H): forest, savanna, rocky/cliffs, and combinations.

| File | Taxa | Areas | Scheme |
|---|---|---|---|
| `geography_file_CYTB_regionalStates.txt` | 46 | 10 | Regional |
| `geography_file_CYTB_biomeStates.txt` | 46 | 8 | Biome |
| `geography_file_UCE_regionalStates.txt` | smaller | 10 | Regional |
| `geography_file_UCE_biomeStates.txt` | smaller | 8 | Biome |

Geography files are in PHYLIP format (binary presence/absence matrix).

## Models Tested

All six BioGeoBEARS model variants were fitted and compared by AIC:

| Model | Jump dispersal (+J) |
|---|---|
| DEC | DEC+J |
| DIVALIKE | DIVALIKE+J |
| BAYAREALIKE | BAYAREALIKE+J |

## Running the Analysis

```r
# Edit the USER INPUT section at the top of each script, then run:
Rscript run_biogeobears_cytb.R
Rscript run_biogeobears_uce.R
```

**Dependencies:** `BioGeoBEARS`, `ape`, `parallel`

**Runtime:** Several minutes per model on a standard desktop (multicore via `parallel::detectCores()`).

## Outputs

Per-model:
- `.Rdata` file with fitted model object
- 2-page PDF with ancestral range pie charts (ML estimates on each node)
- AIC comparison table (`AIC_table.csv`)
- Run log: `Output_CYTB/biogeobears_run.log`
